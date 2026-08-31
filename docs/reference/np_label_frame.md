# Build a labelling frame for training and evaluation

Emits candidate pairs in a flat, review-ready form so a human or an LLM
can apply a `label` (TRUE match / FALSE non-match). The result feeds two
goals: calibrating tier thresholds, and training the supervised combiner
used by
[`np_score()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_score.md)
`method = "model"`. It is the same schema the refinement hand-off will
use.

## Usage

``` r
np_label_frame(pairs, k = 3)
```

## Arguments

- pairs:

  Scored + vetoed `np_pairs`.

- k:

  Number of top-scoring candidates to keep per query. Default 3.

## Value

A data frame (class `np_labelframe`) with per-field similarities,
`score`, veto info, a `candidate_type` (why the pair was kept), and an
empty `label` column to be filled in.

## Details

To make labelling efficient it keeps, per query, the top-`k` scoring
pairs plus the best name-only and best address-only pairs (so the
eventual training set contains hard negatives near the decision
boundary, not just easy ones).
