<div id="main" class="col-md-9" role="main">

# Run stage 3 - LLM research of the NO cases

<div class="ref-description section level2">

Resumable, like `np_stage2_run()`, because a research agent sits in the
middle:

</div>

<div class="section level2">

## Usage

<div class="sourceCode">

``` r
np_stage3_run(
  project = np_project_root(),
  sources = c("stage1_no", "stage2_no"),
  source_data = NULL,
  bmf_index = NULL,
  efile_domains = NULL,
  packet_size = 8L,
  rules = np_gate_rules(),
  verbose = TRUE
)
```

</div>

</div>

<div class="section level2">

## Arguments

-   project:

    Project root. Defaults to `np_project_root()`.

-   sources:

    Which stages' NO files to research. Default both; pass `"stage1_no"`
    to research only what the matcher rejected outright.

-   source_data:

    Optional frame of source attributes (the prepared SAM query) keyed
    by `uei`, to enrich the packets beyond name alone.

-   bmf_index:

    Optional data frame with an `ein` column (and optionally `name`)
    used both for the escape hatch and to enforce the `match` constraint
    on collection.

-   efile_domains:

    Optional character vector of web domains known to belong to 990
    filers, for the escape hatch.

-   packet_size:

    Cases per research packet. Default 8.

-   rules:

    Entity-gate rules. Defaults to `np_gate_rules()`.

-   verbose:

    Print progress. Default `TRUE`.

</div>

<div class="section level2">

## Value

Invisibly: the findings once results exist, otherwise the seed frame.

</div>

<div class="section level2">

## Details

-   **First call** — pools the NO cases from the stages named in
    `sources`, applies the `np_entity_gate()` screen, settles what it
    can deterministically, and writes research packets to
    `03_stage3/batches/packets/`. Point an agent at
    `03_stage3/PROMPT.md`; it writes one `run-<NNNN>.tsv` per packet to
    `03_stage3/batches/out/`.

-   **Second call** — folds those results onto the seed and writes
    `stage3_yes`, `stage3_no` and `stage3_research_findings`.

</div>

<div class="section level2">

## What the screen settles for free

Foreign registrants, for-profit legal forms, government units and sole
proprietors get a determination and high confidence without any lookup.
An escape hatch overrides the screen where there is contrary evidence —
a hit in `bmf_index`, an unreliable SAM 2L flag, or a 990 filer sharing
the registrant website (`efile_domains`) — so a seeded case with a
reason to doubt it is still researched.

</div>

<div class="section level2">

## The `match` constraint

A `match` must resolve to an EIN the reference actually contains. An EIN
that is real but absent from this reference vintage is reclassified to
`nonprofit_not_in_bmf` with the EIN retained, because a match the
crosswalk cannot join is not a match.

</div>

<div class="section level2">

## See also

<div class="dont-index">

`np_entity_gate()`, `np_stage2_run()`, `np_final_run()`.

</div>

</div>

</div>
