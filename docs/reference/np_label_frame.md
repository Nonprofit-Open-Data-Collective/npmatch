<div id="main" class="col-md-9" role="main">

# Build a labelling frame for training and evaluation

<div class="ref-description section level2">

Emits candidate pairs in a flat, review-ready form so a human or an LLM
can apply a `label` (TRUE match / FALSE non-match). The result feeds two
goals: calibrating tier thresholds, and training the supervised combiner
used by `np_score()` `method = "model"`. It is the same schema the
refinement hand-off will use.

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
np_label_frame(pairs, k = 3)
```

</div>

</div>

<div class="section level2">

## Arguments

-   pairs:

    Scored + vetoed `np_pairs`.

-   k:

    Number of top-scoring candidates to keep per query. Default 3.

</div>

<div class="section level2">

## Value

A data frame (class `np_labelframe`) with per-field similarities,
`score`, veto info, a `candidate_type` (why the pair was kept), and an
empty `label` column to be filled in.

</div>

<div class="section level2">

## Details

To make labelling efficient it keeps, per query, the top-`k` scoring
pairs plus the best name-only and best address-only pairs (so the
eventual training set contains hard negatives near the decision
boundary, not just easy ones).

</div>

</div>
