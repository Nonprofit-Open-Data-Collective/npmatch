# The rank-deficient fit in np_benchmark()

`devtools::test()` reports one warning, and has for as long as the benchmark
test has existed:

```
1. np_benchmark compares methods and separates matches ('test-train.R:58:3')
   - prediction from rank-deficient fit; attr(*, "non-estim") has doubtful cases
```

This note records what it is, why it is not a modelling defect, and the thing
about it that is worth fixing — which is not the warning itself but the silence
either side of it.

## 1. Where it comes from

Not from the full fit. On the whole labelled fixture the design is full rank:

| | |
|---|---|
| labelled pairs (`np_test_labeled_pairs()`) | 24 |
| positives | 4 |
| features (`attr(pairs, "cmp_cols")`) | 4 — `name_key`, `street_key`, `city`, `zip5` |
| constant columns | none |
| `np_train(p)` | rank 5 of 5 terms, no aliased coefficients |
| `predict()` on that model | no warning |

It comes from **one cross-validation fold**. `np_benchmark(p, k = 3)` splits the
24 rows three ways and fits on each 16-row remainder:

| fold | train rows | positives | glm rank | aliased | predict |
|---|---|---|---|---|---|
| 1 | 16 | 3 | 5 of 5 | — | clean |
| 2 | 16 | **2** | **3 of 5** | `street_key`, `zip5` | **warns** |
| 3 | 16 | 3 | 5 of 5 | — | clean |

With two positives left in the training half, `street_key` and `zip5` are
collinear with the remaining terms inside that subset, `glm` aliases their
coefficients to `NA`, and `stats::predict.glm()` warns when it scores the
held-out fold because some of those rows' predictions depend on a dropped term.

So it is a property of a 24-row fixture cut three ways, not of `np_benchmark()`
and not of the real training data (304k scored pairs, where the four
similarities are not collinear). Reproduce it with `dev/probe-rank-deficiency.R`.

## 2. What the warning is actually telling us

`predict.glm()` does not return wrong numbers here. It fits using the estimable
terms and flags the rows whose prediction is not identified — that is the
`attr(*, "non-estim")` part. For those rows the score is arbitrary with respect
to the dropped feature. The number looks ordinary; only the attribute says it
is not trustworthy, and nothing in npmatch reads that attribute.

## 3. The real defect is the silence around it

[`np_train()`](../R/train.R) already suppresses warnings at fit time:

```r
fit <- suppressWarnings(
  stats::glm(y ~ ., data = cbind(y = y, x), family = stats::binomial())
)
```

That was presumably to quiet `glm.fit: fitted probabilities numerically 0 or 1`
on well-separated data, which is expected and harmless here. But it also
swallows the rank-deficiency report at the one place that knows the coefficient
names. The consequence:

* a model fitted on a caller's own labelled data can drop terms silently;
* `np_score(method = "model")` then returns scores that look ordinary;
* the only surviving signal is a `predict()` warning with no names in it, raised
  once per prediction call rather than once per model.

A dropped feature is exactly the quiet failure this package treats as a stop
condition elsewhere — the normalizer signature check, and `addr_freq` counted
over a slice. A similarity column that is constant because the field is empty
in the caller's source (no DBA anywhere, no street on one side) produces it, and
that is a realistic input, not a fixture artifact.

## 4. Why not just suppress it in `predict.np_model()`

Tempting, and wrong as the whole fix:

* **It is global.** `predict.np_model()` is the only path from a model to
  scores, so `np_benchmark()`, `np_score(method = "model")` and
  `np_calibration_frame()` all lose the report together.
* **It removes the last signal**, given that `np_train()` already suppresses the
  fit-time one. Rank deficiency would become completely unobservable.
* **It is indiscriminate.** A bare `suppressWarnings()` around `predict()` also
  swallows `newdata` level mismatches and NA coercions — anything predict emits.

Suppression is right only for the *expected* case, narrowed to the message and
placed where the expectation lives: k-fold on a set small enough that a fold can
degenerate.

## 5. Plan

**Inspect first.**

1. Run `dev/probe-rank-deficiency.R` after any change to the compared-field set
   (`attr(pairs, "cmp_cols")`), since adding a similarity column changes which
   folds degenerate. Record the per-fold table above.
2. Fit on the real 304k training projection (`np_source_urls()`'s
   `training_pairs`) and confirm `coef(fit)` has no `NA` there. If it does, this
   stops being a fixture question and the aliased feature needs removing from
   the default set.
3. Check whether any shipped review frame was scored by a rank-deficient model:
   `np_model` does not currently record its rank, which is itself the gap.

**Then fix, smallest first.**

1. **Report once, at the fit.** Have `np_train()` keep the suppression but
   inspect the result: store `rank`, `n_terms` and the aliased names on the
   `np_model`, print them in `print.np_model()`, and warn once naming them.
   This is the change that matters; it turns an anonymous per-prediction warning
   into a named per-model one.
2. **Narrow the suppression at predict.** With (1) in place, muffle only the
   rank-deficiency message in `predict.np_model()` — matched on the condition,
   not a blanket `suppressWarnings()` — so a genuine `newdata` problem still
   surfaces.
3. **Make the benchmark account for it.** Add a column to `np_benchmark()`'s
   frame counting folds whose fit was rank-deficient, so a degenerate split is
   visible in the result rather than in the console.
4. **Leave the fixture alone** unless (2) proves awkward. The 24-row fixture
   with a degenerate fold is a useful regression case: it is the only place the
   suite exercises the aliased path at all. If it has to change, prefer
   `k = 2` over adding positives, which would weaken the other assertions.

**Verify.** `expect_silent()` (or `expect_no_warning()`) around the
`np_benchmark()` call in `test-train.R:57`, plus a new test that a deliberately
collinear feature set makes `np_train()` warn and records the aliased name on
the model.

## 6. Status

**Done, 2026-11-03.** Section 5's plan is implemented, in the order it gives.

* **(1) Report once, at the fit.** `np_train()` keeps the `suppressWarnings()`
  around `glm()` — the "fitted probabilities numerically 0 or 1" case is still
  expected and still silent — but now inspects the result and records `rank`,
  `n_terms` and `aliased` on the `np_model`. `print.np_model()` shows them, and
  a single warning names the dropped terms. It is raised with the condition
  class `np_rank_deficient` rather than as a bare message, so §5's "matched on
  the condition, not a blanket suppressWarnings()" is literal: a caller muffles
  the class, not a substring.
* **(2) Narrow the suppression at predict.** `predict.np_model()` muffles only
  `predict.lm()`'s "prediction from rank-deficient fit" — by text, since that
  warning is stats' own and carries no class — and lets `newdata` problems and
  NA coercions through as before.
* **(3) Make the benchmark account for it.** `np_benchmark()` muffles the
  per-fold `np_rank_deficient` condition and reports instead: a
  `rank_deficient_folds` column (`NA` on the unsupervised rows) and a
  `rank_deficient` attribute, one entry per affected fold, naming the terms it
  dropped.
* **(4) Fixture untouched.** The 24-row fixture still degenerates at fold 2 and
  is still the regression case. The "every fold full rank" test builds its own
  well-conditioned 40-row frame rather than changing the shared fixture — note
  that §5's suggested `k = 2` fallback would not have worked: at `k = 2` *both*
  folds drop `zip5`, and at `k = 5` folds 1 and 4 do.
* **Verify.** `expect_silent()` now wraps the `np_benchmark()` call in
  `test-train.R`, as §5 asks, plus tests that a duplicated feature column makes
  `np_train()` warn with the right class and record the aliased name. Suite:
  `FAIL 0 | WARN 0 | PASS 706`.

### Correction to §5's "inspect first", step 2

Step 2 said to fit on the real `training_pairs` projection and "confirm
`coef(fit)` has no `NA` there". **It does have NAs.** Fitting a logistic model
on all 11 numeric non-target columns of `TRAINING-PAIRS-1502.csv` (304,274
rows, 1,168 positives) gives rank 9 of 12 terms and aliases three:

| term | why |
|---|---|
| `geo_zip9` | constant across all 304,274 rows |
| `geo_pobox` | constant across all 304,274 rows |
| `geo_zip5` | `cor(zip_sim, geo_zip5) = 1.000` |

This does **not** trigger step 2's conclusion that "the aliased feature needs
removing from the default set", because those are the columns of the exported
training projection, not `attr(pairs, "cmp_cols")` — the compared-field set is
`name_key`, `street_key`, `city`, `zip5`, and the full fixture fit on it is
rank 5 of 5. But it does retire the framing that this is only a 24-row fixture
curiosity: a reader who follows the classifier vignette and fits on that file
gets three terms dropped, silently before this change. Whether the projection
should ship constant and duplicated columns at all is a separate question for
whoever regenerates it.
