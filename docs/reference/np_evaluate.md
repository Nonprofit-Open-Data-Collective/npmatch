<div id="main" class="col-md-9" role="main">

# Evaluate scored pairs against known labels

<div class="ref-description section level2">

Pair-level classification metrics for a linkage scorer: threshold-free
AUC plus precision / recall / F1 / accuracy at a decision threshold.
Positives are true matches.

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
np_evaluate(score, label, threshold = 0.5)
```

</div>

</div>

<div class="section level2">

## Arguments

-   score:

    Numeric predicted match scores.

-   label:

    Truth (logical / 0-1 / character).

-   threshold:

    Decision threshold; predict match when `score >= threshold`.

</div>

<div class="section level2">

## Value

A one-row data frame of metrics.

</div>

</div>
