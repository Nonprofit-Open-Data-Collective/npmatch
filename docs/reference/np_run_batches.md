<div id="main" class="col-md-9" role="main">

# Run stage-1 matching in batches against a shared reference

<div class="ref-description section level2">

Drives the full stage-1 cascade (`np_cascade()`) over a large source in
`np_batch()` chunks, normalizing the reference **once** and reusing it
(plus the `name_freq` / `token_idf` tables) for every chunk — turning
the \~one-time reference normalization into exactly that. For each batch
it writes an accepted crosswalk (YES picks), a review queue (the MAYBE
hand-off for LLM/human validation, from `np_route()`), and a short
per-batch report; it accumulates a run summary across batches.

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
np_run_batches(
  query,
  reference,
  compute_size = NULL,
  review_size = 250L,
  size = NULL,
  out_dir = ".",
  only = NULL,
  config = np_config(),
  method = "hier",
  query_map = np_map_sam(),
  reference_map = np_map_bmf(),
  seed = 1L,
  cache = NULL,
  sam_context = NULL,
  bmf_context = NULL,
  review_tiers = "MAYBE",
  save_interim = NULL,
  threads = NULL,
  addr_freq = NULL,
  verbose = TRUE
)
```

</div>

</div>

<div class="section level2">

## Arguments

-   query:

    Raw source data frame (e.g. a SAM nonprofit subset). Raw uppercase
    SAM headers are normalized to the names `np_map_sam()` expects; an
    `np_query` is used as-is.

-   reference:

    The reference (the BMF, in the shipped deployment): a raw data
    frame, an `np_reference()`, a pre-normalized reference (the latter
    two skip the corresponding step), or a matchdb reference from
    `matchdb::md_compile()` or `matchdb::md_reference()`, whose
    precomputed tables are used as they are (see `np_cascade()`).

-   compute_size:

    Queries per **compute chunk** — one `np_cascade()` call. This is the
    memory-bound knob (candidate pairs scale with chunk size); make it
    as large as memory allows to amortize the per-chunk pass machinery.
    `NULL` (default) runs the whole query in a single chunk ("match
    big").

-   review_size:

    **Review-file** size: the number of MAYBE queries written per review
    shard (`review-NN-partKK.csv`), sized to one LLM-validation job.
    Default 250. Decouples the LLM hand-off size from the compute chunk
    size.

-   size:

    Deprecated alias for `compute_size` (back-compat). Ignored if
    `compute_size` is given.

-   out_dir:

    Directory for the per-chunk outputs and the run summary. Created if
    needed.

-   only:

    Optional integer vector of compute-chunk numbers to run (e.g. `1` to
    run just the first chunk as a demo). Default: all chunks.

-   config, method:

    Passed to `np_cascade()`.

-   query_map, reference_map:

    Schema maps for raw inputs.

-   seed:

    Passed to `np_batch()` to shuffle before chunking.

-   cache:

    Optional `.rds` path to cache/reuse the normalized reference and its
    `name_freq`/`token_idf` tables, blocking `ref_index` and
    `addr_freq`. When the file exists it is used in place of
    `reference`. A cache written before a table existed gains that table
    on its next use.

-   sam_context:

    Optional raw SAM frame passed to `np_route()` (`sam =`) to add
    `SAM_`-prefixed context columns to the review queue.

-   bmf_context:

    Optional raw processed BMF passed to `np_route()` (`bmf =`) to add
    `BMF_`-prefixed context columns (NTEE, subsection, ruling year,
    assets, revenue) to the review queue.

-   review_tiers:

    Tiers to include in the per-chunk review frame, passed to
    `np_route()`. Default `"MAYBE"` — the human/LLM hand-off only. Pass
    `c("YES","MAYBE","NO")` for a candidate-level frame spanning every
    outcome, which is what an evaluation frame needs.

-   save_interim:

    Optional directory in which to persist, per chunk, the cascade
    result (`res-NN.rds`) and its scored candidate pairs
    (`pairs-NN.rds`). Without this they are discarded when the chunk
    ends, and the candidate sets cannot be rebuilt except by re-running
    the match.

-   threads:

    data.table thread count for the blocking joins / reads. Default
    `NULL` uses all detected cores for the run and restores the prior
    setting on exit; pass an integer to pin it, or `0` to leave the
    global setting untouched.

-   addr_freq:

    Optional precomputed `np_addr_freq()` table, passed to every
    `np_cascade()` call. Takes precedence over the one in a matchdb
    reference or the cache; otherwise counted once over the whole
    reference.

-   verbose:

    Print progress. Default `TRUE`.

</div>

<div class="section level2">

## Value

A data frame summarising each compute chunk (rows, YES/MAYBE/NO,
coverage, seconds, output paths, review-shard count), invisibly. Written
to `out_dir/run-summary.csv`.

</div>

<div class="section level2">

## Details

The reference is normalized once via `np_reference()` + `np_normalize()`
(or reused if already normalized). When `cache` is a path, the
normalized reference and its `name_freq`/`token_idf`, `ref_index` and
`addr_freq` tables are saved there and reloaded on the next run, so a
resumed or re-run job skips normalization entirely.

</div>

</div>
