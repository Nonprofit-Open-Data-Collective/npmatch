<div id="main" class="col-md-9" role="main">

# Benchmark scoring methods by cross-validation

<div class="ref-description section level2">

Compares the candidate scorers on a labelled set so the "best" combiner
can be chosen empirically. The unsupervised methods (`weighted`, `em`)
are scored on the full candidate set; `model` uses out-of-fold
predictions to avoid optimism. Each method is then evaluated at
thresholds tuned on the same labels, so the comparison reflects how the
tiering would actually behave.

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

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

</div>

</div>

<div class="section level2">

## Arguments

-   pairs:

    A labelled `np_pairs` frame.

-   methods:

    Which scorers to compare.

-   k:

    Number of CV folds for the supervised `model` method.

-   config:

    An `np_config()` (supplies weights for `weighted`).

-   engine:

    Training engine for `model` (see `np_train()`).

-   target_precision, min_recall:

    Passed to `np_tune_thresholds()`.

-   seed:

    Fold-assignment seed.

</div>

<div class="section level2">

## Value

A data frame, one row per method, with AUC and tuned-threshold
precision/recall/coverage. Out-of-fold scores are attached as attribute
`scores`.

</div>

</div>
