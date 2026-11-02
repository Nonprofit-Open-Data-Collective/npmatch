# Benchmark scoring methods by cross-validation

Compares the candidate scorers on a labelled set so the "best" combiner
can be chosen empirically. The unsupervised methods (`weighted`, `em`)
are scored on the full candidate set; `model` uses out-of-fold
predictions to avoid optimism. Each method is then evaluated at
thresholds tuned on the same labels, so the comparison reflects how the
tiering would actually behave.

## Usage

``` r
np_benchmark(
  pairs,
  methods = c("weighted", "em", "model"),
  k = 5,
  config = np_config(),
  engine = "logit",
  target_precision = 0.98,
  min_recall = 0.95,
  seed = 1L
)
```

## Arguments

- pairs:

  A labelled `np_pairs` frame.

- methods:

  Which scorers to compare.

- k:

  Number of CV folds for the supervised `model` method.

- config:

  An
  [`np_config()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_config.md)
  (supplies weights for `weighted`).

- engine:

  Training engine for `model` (see
  [`np_train()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_train.md)).

- target_precision, min_recall:

  Passed to
  [`np_tune_thresholds()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_tune_thresholds.md).

- seed:

  Fold-assignment seed.

## Value

A data frame, one row per method, with AUC and tuned-threshold
precision/recall/coverage. Out-of-fold scores are attached as attribute
`scores`.
