# Run stage 3 - LLM research of the NO cases

Resumable, like
[`np_stage2_run()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_stage2_run.md),
because a research agent sits in the middle:

## Usage

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

## Arguments

- project:

  Project root. Defaults to
  [`np_project_root()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_project_root.md).

- sources:

  Which stages' NO files to research. Default both; pass `"stage1_no"`
  to research only what the matcher rejected outright.

- source_data:

  Optional frame of source attributes (the prepared SAM query) keyed by
  `uei`, to enrich the packets beyond name alone.

- bmf_index:

  Optional data frame with an `ein` column (and optionally `name`) used
  both for the escape hatch and to enforce the `match` constraint on
  collection.

- efile_domains:

  Optional character vector of web domains known to belong to 990
  filers, for the escape hatch.

- packet_size:

  Cases per research packet. Default 8.

- rules:

  Entity-gate rules. Defaults to
  [`np_gate_rules()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_gate_rules.md).

- verbose:

  Print progress. Default `TRUE`.

## Value

Invisibly: the findings once results exist, otherwise the seed frame.

## Details

- **First call** — pools the NO cases from the stages named in
  `sources`, applies the
  [`np_entity_gate()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_entity_gate.md)
  screen, settles what it can deterministically, and writes research
  packets to `03_stage3/batches/packets/`. Point an agent at
  `03_stage3/PROMPT.md`; it writes one `run-<NNNN>.tsv` per packet to
  `03_stage3/batches/out/`.

- **Second call** — folds those results onto the seed and writes
  `stage3_yes`, `stage3_no` and `stage3_research_findings`.

## What the screen settles for free

Foreign registrants, for-profit legal forms, government units and sole
proprietors get a determination and high confidence without any lookup.
An escape hatch overrides the screen where there is contrary evidence —
a hit in `bmf_index`, an unreliable SAM 2L flag, or a 990 filer sharing
the registrant website (`efile_domains`) — so a seeded case with a
reason to doubt it is still researched.

## The `match` constraint

A `match` must resolve to an EIN the reference actually contains. An EIN
that is real but absent from this reference vintage is reclassified to
`nonprofit_not_in_bmf` with the EIN retained, because a match the
crosswalk cannot join is not a match.

## See also

[`np_entity_gate()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_entity_gate.md),
[`np_stage2_run()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_stage2_run.md),
[`np_final_run()`](https://nonprofit-open-data-collective.github.io/npmatch/reference/np_final_run.md).
