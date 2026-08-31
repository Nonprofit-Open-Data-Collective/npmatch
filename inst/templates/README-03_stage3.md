# 03_stage3 — LLM research of NO

Stage 1 and stage 2 both produce NO. This stage researches them to find matches
the matcher missed, and to classify the rest.

By default it consumes **both** `01_stage1/stage1_no.csv` and
`02_stage2/stage2_no.csv`. It can be constrained to stage 1 alone. The `stage`
column on every row records which it came from, so the two are always separable
downstream.

The agent instructions are in `PROMPT.md`.

## Determination taxonomy

| value | meaning | rolls up as |
|---|---|---|
| `match` | a BMF EIN is the same organization | `stage3_yes` |
| `not_a_nonprofit` | not a 501(c) filer at all | `stage3_no` |
| `nonprofit_not_in_bmf` | real nonprofit, absent from this BMF vintage | `stage3_no` |
| `cant_determine` | evidence insufficient | `stage3_no` |

Three different failures share `stage3_no`, so `reason` carries the specific
determination. The full record — sources, judgement, resolving tier, gates —
is in `stage3_research_findings.csv`, joined by `uei`.

## The screen comes before the research

Many NO cases are settled deterministically without any lookup: foreign
addresses, for-profit legal forms, government units, sole proprietors. Those get
a determination, high confidence, and are never queued. Only what survives the
screen is researched, which is what makes the stage affordable.

An escape hatch overrides the screen when there is contrary evidence — a BMF
name hit, an unreliable structure flag, or a 990 filer sharing the website.

## Research ladder

Escalate only as far as needed, and record where the answer came from:

1. **tier 1** — local BMF and efile indexes. Free. Try for every case.
2. **tier 2** — cached ProPublica. Already fetched; do not re-query.
3. **tier 3** — general web search. Must carry a citation.

## Subdirectories

- `batches/packets/` — agent inputs; `batches/out/` — agent outputs.
- `interim/` — pools, seed frame, queues. `interim/cache/` holds the ProPublica
  cache, which is keyed by EIN, accumulates across runs and is rate-limited:
  **carry it forward, do not regenerate it.**
- `logs/` — telemetry (tokens, tool uses, seconds per batch) and prefetch logs.
