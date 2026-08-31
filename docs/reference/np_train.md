# Train a supervised match combiner

Fits a classifier that maps the per-field similarity vector to a match
probability — the model consumed by
[`np_score()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_score.md)
`method = "model"`. The built-in engine is logistic regression; any
engine returning an object with a
`predict(obj, newdata, type = "response")` method can be supplied.

## Usage

``` r
np_train(pairs, engine = "logit", features = attr(pairs, "cmp_cols"))
```

## Arguments

- pairs:

  A labelled `np_pairs` frame (see
  [`np_label()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_label.md));
  rows with `NA` label are ignored.

- engine:

  `"logit"` (default) or a function `(x, y)` returning a fitted model,
  where `x` is the similarity data frame and `y` is 0/1.

- features:

  Similarity columns to use. Defaults to the compared fields.

## Value

An `np_model` object usable as `np_score(..., model = )`.
