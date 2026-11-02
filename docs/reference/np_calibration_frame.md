# Build a labelling frame for threshold / weight calibration

Draws a tier-stratified sample of queries from a tiered result and lays
out their candidate matches (top-k by score plus the best name-only and
best address-only views) as one row per candidate, ready to label.
Sampling across YES / MAYBE / NO — not just the review pile — is what
lets
[`np_tune_thresholds()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_tune_thresholds.md)
estimate the cutoffs well near the boundary.

## Usage

``` r
np_calibration_frame(
  tiered,
  per_tier = c(YES = 120, MAYBE = 250, NO = 120),
  k = 3,
  seed = 1
)
```

## Arguments

- tiered:

  An `np_tiered` result from
  [`np_match()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_match.md)
  /
  [`np_cascade()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_cascade.md)
  (its scored candidate pairs must be attached as
  `attr(tiered, "pairs")`).

- per_tier:

  Named integer cap of queries to sample from each tier.

- k:

  Candidates to surface per query. Default 3.

- seed:

  Sampling seed.

## Value

A data frame (class `np_calibration`) of candidate rows with an empty
`label` column.

## Details

Each row carries both records' display fields, the per-field
similarities, the combined `score`, the query's tier / pass / margin,
whether the candidate was the chosen overall match, and an empty `label`
column. A labeller (human or LLM) sets `label = TRUE` on the correct
candidate for a query and `FALSE` on the rest (all `FALSE` if none is
correct). Feed the result back with
[`np_label()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_label.md),
then
[`np_benchmark()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_benchmark.md)
/
[`np_tune_thresholds()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_tune_thresholds.md).
