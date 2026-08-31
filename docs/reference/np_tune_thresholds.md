# Tune YES / MAYBE thresholds from labelled data

Chooses cutoffs for
[`np_tier()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_tier.md)
on a validation set. `yes` is the lowest score whose auto-accept
precision still meets `target_precision` (so YES stays trustworthy while
auto-deciding as many records as possible); `maybe` is the lowest score
that still captures `min_recall` of true matches (anything below is safe
to drop to NO). `yes` is never below `maybe`.

## Usage

``` r
np_tune_thresholds(score, label, target_precision = 0.98, min_recall = 0.95)
```

## Arguments

- score, label:

  Scores and truth on the validation set.

- target_precision:

  Minimum precision required of the YES tier.

- min_recall:

  Fraction of true matches the MAYBE floor must retain.

## Value

Named numeric `c(yes=, maybe=)`, with achieved metrics attached as
attribute `metrics`.
