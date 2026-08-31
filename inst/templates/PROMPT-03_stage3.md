# Stage 3 — research instructions

Run {{run_id}}. These are cases the matcher rejected. Your job is to determine
what each source organization actually is, and whether a BMF match exists that
the matcher missed.

## Your input

One packet from `batches/packets/`. Each case carries the SAM record (name, DBA,
address, URL, entity structure, business types, point of contact), why it was
flagged for research, any local BMF name-lookup hits, and — for cases that came
from stage 2 — the candidate slate the adjudicator saw and rejected.

## Determination taxonomy — exactly one per case

| value | when |
|---|---|
| `match` | a BMF EIN is the same organization; record it in `ein_found` |
| `not_a_nonprofit` | for-profit, government unit, individual, or otherwise not a 501(c) filer |
| `nonprofit_not_in_bmf` | a real nonprofit absent from this BMF vintage; record the EIN if you found one |
| `cant_determine` | evidence insufficient — say what is missing in `notes` |

A `match` must resolve to an EIN **present in the reference**. A real EIN that is
not in this BMF vintage is `nonprofit_not_in_bmf`, not `match` — record the EIN
there anyway.

## Research ladder — escalate only as far as needed

1. **tier 1** — the local BMF and efile indexes. Free; try for every case.
2. **tier 2** — the cached ProPublica extract. Already fetched. **Do not query
   the API.**
3. **tier 3** — general web search. Must carry a real citation.

Record the tier that actually settled it, not the highest one you touched.

## Your output

One TSV per packet, to `batches/out/run-<NNNN>.tsv`, tab-separated, this header
first:

```
uei	sam_name	run	stage	ein_found	determination	resolving_tier	confidence	sources	judgement	notes
```

- one row per case in your packet — every case, including the ones you could not
  resolve
- `sources` — semicolon-separated and specific: `bmf_grep`, `efile_xwalk:<ein>`,
  `propublica_cache`, `web:<url>`. **State negative results explicitly**, e.g.
  `bmf_grep: no name hit; propublica_cache: 0 results`
- `judgement` — one sentence: why it is not a match, or what the true match is
- `notes` — what a reviewer would need, including what is missing on a `low` or
  `cant_determine`
- **no tab or newline characters inside any field** — replace with spaces or
  semicolons

## Column alignment — the failure that field counts do not catch

A row can have exactly 11 fields and still be wrong. The common slip is
**omitting `ein_found` instead of leaving it empty** when there is no EIN:
everything after it shifts left one position, the row still has 11 fields, and
the error survives every count-based check.

Write an empty field for every value you do not have. Before finishing, verify
one row by eye: field 5 is `ein_found` (often empty), field 6 is the
determination, field 7 is `tier1`/`tier2`/`tier3`. **If field 6 reads `tier1`,
the row is shifted and must be rewritten.**

Write the file even if some cases came back empty. Reply with one line: packet
number, rows written, counts by determination. Do not paste the rows.
