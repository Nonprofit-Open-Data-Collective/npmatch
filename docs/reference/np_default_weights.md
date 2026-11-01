<div id="main" class="col-md-9" role="main">

# Default per-profile field weights

<div class="ref-description section level2">

Starting weights, richest-geo profiles lean less on the name. These are
deliberately hand-set defaults; the intended workflow is to *replace*
them with weights learned from a labelled training set (see `np_score()`
method `"em"` and the labelling-frame helpers).

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
np_default_weights()
```

</div>

</div>

<div class="section level2">

## Value

A named list suitable for the `weights` argument of `np_config()`.

</div>

</div>
