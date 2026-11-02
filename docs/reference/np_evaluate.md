# Evaluate scored pairs against known labels

Pair-level classification metrics for a linkage scorer: threshold-free
AUC plus precision / recall / F1 / accuracy at a decision threshold.
Positives are true matches.

## Usage

``` r
np_evaluate(score, label, threshold = 0.5)
```

## Arguments

- score:

  Numeric predicted match scores.

- label:

  Truth (logical / 0-1 / character).

- threshold:

  Decision threshold; predict match when `score >= threshold`.

## Value

A one-row data frame of metrics.
