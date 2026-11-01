<div id="main" class="col-md-9" role="main">

# Run stage 1 - the probabilistic cascade

<div class="ref-description section level2">

Matches the prepared source against the reference and writes the four
stage-1 outputs: `stage1_yes`, `stage1_maybe`, `stage1_no` (all in the
shared `np_stage_schema()`, one row per source id) and
`stage1_k_candidates` (one row per surfaced candidate, joined to any of
them by `uei`).

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
np_stage1_run(
  query = NULL,
  reference = NULL,
  project = np_project_root(),
  cache = NULL,
  compute_size = 2500L,
  review_size = 250L,
  k = 3,
  seed = 1L,
  method = "hier",
  query_map = np_map_sam(),
  reference_map = np_map_bmf(),
  config = np_config(),
  bmf_context = NULL,
  sam_context = NULL,
  only = NULL,
  verbose = TRUE
)
```

</div>

</div>

<div class="section level2">

## Arguments

-   query:

    The prepared source frame, or a path to one. Defaults to
    `00_sams/sam_query.csv` in the project.

-   reference:

    The reference: raw data frame, `np_reference()`, a pre-normalized
    reference, or a matchdb reference from `matchdb::md_compile()` /
    `matchdb::md_reference()`, whose precomputed tables are used as they
    are (see `np_cascade()`). May be `NULL` when `cache` holds a built
    bundle.

-   project:

    Project root. Defaults to `np_project_root()`.

-   cache:

    Optional `.rds` bundle of the normalized reference, passed to
    `np_run_batches()`.

-   compute_size, review_size, seed, method, config:

    Passed to `np_run_batches()`.

-   k:

    Candidates surfaced per query in `stage1_k_candidates`. Default 3.

-   query_map, reference_map:

    Schema maps for the source and reference, passed to
    `np_run_batches()`. Default to `np_map_sam()` / `np_map_bmf()`.

-   bmf_context, sam_context:

    Optional raw frames whose `BMF_` / `SAM_` context columns are joined
    onto the candidate frame.

-   only:

    Optional chunk numbers, for a partial or resumed run.

-   verbose:

    Print progress. Default `TRUE`.

</div>

<div class="section level2">

## Value

The consolidated outcome frame, invisibly.

</div>

<div class="section level2">

## Details

Work is delegated to `np_run_batches()`, which normalizes the reference
once and chunks the query. Unlike a bare `np_run_batches()` call this
runner keeps everything: the review frame spans **all three tiers**, the
NO tier is written rather than dropped, and each chunk's cascade result
and scored pairs are persisted to `interim/`. Those pairs are the only
record of what blocking surfaced; without them a later evaluation frame
cannot be built except by re-running the match against a
possibly-changed candidate set.

</div>

<div class="section level2">

## See also

<div class="dont-index">

`np_project_init()`, `np_stage2_run()`, `np_run_batches()`.

</div>

</div>

</div>
