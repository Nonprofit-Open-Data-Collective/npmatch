# Default per-profile field weights

Starting weights, richest-geo profiles lean less on the name. These are
deliberately hand-set defaults; the intended workflow is to *replace*
them with weights learned from a labelled training set (see
[`np_score()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_score.md)
method `"em"` and the labelling-frame helpers).

## Usage

``` r
np_default_weights()
```

## Value

A named list suitable for the `weights` argument of
[`np_config()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_config.md).
