<div id="main" class="col-md-9" role="main">

# Tune YES / MAYBE thresholds from labelled data

<div class="ref-description section level2">

Chooses cutoffs for `np_tier()` on a validation set. `yes` is the lowest
score whose auto-accept precision still meets `target_precision` (so YES
stays trustworthy while auto-deciding as many records as possible);
`maybe` is the lowest score that still captures `min_recall` of true
matches (anything below is safe to drop to NO). `yes` is never below
`maybe`.

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
np_tune_thresholds(score, label, target_precision = 0.98, min_recall = 0.95)
```

</div>

</div>

<div class="section level2">

## Arguments

-   score, label:

    Scores and truth on the validation set.

-   target_precision:

    Minimum precision required of the YES tier.

-   min_recall:

    Fraction of true matches the MAYBE floor must retain.

</div>

<div class="section level2">

## Value

Named numeric `c(yes=, maybe=)`, with achieved metrics attached as
attribute `metrics`.

</div>

</div>
