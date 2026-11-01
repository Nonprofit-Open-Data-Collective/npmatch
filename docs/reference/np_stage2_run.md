<div id="main" class="col-md-9" role="main">

# Run stage 2 - LLM adjudication of the MAYBE queue

<div class="ref-description section level2">

Resumable, because an adjudicator sits in the middle:

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
np_stage2_run(
  project = np_project_root(),
  shard_size = 250L,
  columns = .np_slim_cols,
  verbose = TRUE
)
```

</div>

</div>

<div class="section level2">

## Arguments

-   project:

    Project root. Defaults to `np_project_root()`.

-   shard_size:

    Source ids per adjudication shard. Default 250.

-   columns:

    Columns carried into the shard files. Defaults to the adjudication
    set; pass more to give the agent extra context.

-   verbose:

    Print progress. Default `TRUE`.

</div>

<div class="section level2">

## Value

Invisibly: the outcome frame once decisions exist, otherwise the
manifest of shards written.

</div>

<div class="section level2">

## Details

-   **First call** — reads `stage1_maybe` and `stage1_k_candidates`,
    writes shard files to `02_stage2/batches/slim/`, and stops. Point an
    agent at `02_stage2/PROMPT.md`; it writes one `decision-<shard>.csv`
    per shard to `02_stage2/batches/decisions/`.

-   **Second call** — collects those decisions, collapses duplicate
    source registrations, and writes `stage2_yes` / `stage2_no`.

Re-running after only some shards are adjudicated collects what is there
and reports which shards are still outstanding. An unreturned shard is a
hole in the results, not a set of NOs, so it is never silently treated
as one.

</div>

<div class="section level2">

## See also

<div class="dont-index">

`np_stage1_run()`, `np_merge_decisions()`, `np_stage_schema()`.

</div>

</div>

</div>
