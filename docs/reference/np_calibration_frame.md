<div id="main" class="col-md-9" role="main">

# Build a labelling frame for threshold / weight calibration

<div class="ref-description section level2">

Draws a tier-stratified sample of queries from a tiered result and lays
out their candidate matches (top-k by score plus the best name-only and
best address-only views) as one row per candidate, ready to label.
Sampling across YES / MAYBE / NO — not just the review pile — is what
lets `np_tune_thresholds()` estimate the cutoffs well near the boundary.

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
np_calibration_frame(
  tiered,
  per_tier = c(YES = 120, MAYBE = 250, NO = 120),
  k = 3,
  seed = 1
)
```

</div>

</div>

<div class="section level2">

## Arguments

-   tiered:

    An `np_tiered` result from `np_match()` / `np_cascade()` (its scored
    candidate pairs must be attached as `attr(tiered, "pairs")`).

-   per_tier:

    Named integer cap of queries to sample from each tier.

-   k:

    Candidates to surface per query. Default 3.

-   seed:

    Sampling seed.

</div>

<div class="section level2">

## Value

A data frame (class `np_calibration`) of candidate rows with an empty
`label` column.

</div>

<div class="section level2">

## Details

Each row carries both records' display fields, the per-field
similarities, the combined `score`, the query's tier / pass / margin,
whether the candidate was the chosen overall match, and an empty `label`
column. A labeller (human or LLM) sets `label = TRUE` on the correct
candidate for a query and `FALSE` on the rest (all `FALSE` if none is
correct). Feed the result back with `np_label()`, then `np_benchmark()`
/ `np_tune_thresholds()`.

</div>

</div>
