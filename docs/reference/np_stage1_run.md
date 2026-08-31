# Run stage 1 - the probabilistic cascade

Matches the prepared source against the reference and writes the four
stage-1 outputs: `stage1_yes`, `stage1_maybe`, `stage1_no` (all in the
shared
[`np_stage_schema()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_stage_schema.md),
one row per source id) and `stage1_k_candidates` (one row per surfaced
candidate, joined to any of them by `uei`).

## Usage

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

## Arguments

- query:

  The prepared source frame, or a path to one. Defaults to
  `00_sams/sam_query.csv` in the project.

- reference:

  The reference BMF: raw data frame,
  [`np_reference()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_reference.md),
  or pre-normalized reference. May be `NULL` when `cache` holds a built
  bundle.

- project:

  Project root. Defaults to
  [`np_project_root()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_project_root.md).

- cache:

  Optional `.rds` bundle of the normalized reference, passed to
  [`np_run_batches()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_run_batches.md).

- compute_size, review_size, seed, method, config:

  Passed to
  [`np_run_batches()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_run_batches.md).

- k:

  Candidates surfaced per query in `stage1_k_candidates`. Default 3.

- query_map, reference_map:

  Schema maps for the source and reference, passed to
  [`np_run_batches()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_run_batches.md).
  Default to
  [`np_map_sam()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_maps.md)
  /
  [`np_map_bmf()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_maps.md).

- bmf_context, sam_context:

  Optional raw frames whose `BMF_` / `SAM_` context columns are joined
  onto the candidate frame.

- only:

  Optional chunk numbers, for a partial or resumed run.

- verbose:

  Print progress. Default `TRUE`.

## Value

The consolidated outcome frame, invisibly.

## Details

Work is delegated to
[`np_run_batches()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_run_batches.md),
which normalizes the reference once and chunks the query. Unlike a bare
[`np_run_batches()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_run_batches.md)
call this runner keeps everything: the review frame spans **all three
tiers**, the NO tier is written rather than dropped, and each chunk's
cascade result and scored pairs are persisted to `interim/`. Those pairs
are the only record of what blocking surfaced; without them a later
evaluation frame cannot be built except by re-running the match against
a possibly-changed candidate set.

## See also

[`np_project_init()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_project_init.md),
[`np_stage2_run()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_stage2_run.md),
[`np_run_batches()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_run_batches.md).
