# 01_stage1 — probabilistic cascade

The reclin-based matcher. Blocks candidates, scores them, applies vetoes, picks
one per query, and sorts the result into YES / MAYBE / NO.

```
sam_query.csv ─▶ np_block ─▶ np_compare ─▶ np_score ─▶ np_veto ─▶ np_select ─▶ np_tier
                                                                                  │
                            ┌─────────────────────────────────────────────────────┤
                            ▼                     ▼                               ▼
                      stage1_yes            stage1_maybe                    stage1_no
                     (accepted)            (→ 02_stage2)                  (→ 03_stage3)
```

## Outputs

| file | grain | goes to |
|---|---|---|
| `stage1_yes.csv` | one row per UEI | `04_final` |
| `stage1_maybe.csv` | one row per UEI | `02_stage2` |
| `stage1_no.csv` | one row per UEI | `03_stage3` |
| `stage1_k_candidates.csv` | one row per surfaced candidate | joins to any of the above by `uei` |
| `STAGE1-REPORT.md` | per-pass cascade table, tier counts, timings | |
| `STAGE1-STATS.csv` | per-chunk tally | |

The three outcome files share the standard schema and differ only in `outcome`.
Near-miss information for a NO — what it almost matched and at what score —
lives in `stage1_k_candidates`, not in `stage1_no`.

## Zero-candidate queries

A query for which blocking surfaced nothing at all is a different failure from
one whose candidates all scored below the floor. Those rows are `stage1_no`
with `reason = no_candidates` and no entry in `stage1_k_candidates`. Keeping
them distinct is what makes blocking recall measurable.

## Subdirectories

- `batches/` — per-chunk outputs; `batches/shards/` holds the LLM-sized review
  parts handed to stage 2.
- `interim/` — the cascade result and scored pairs (`res-NN.rds`,
  `pairs-NN.rds`) and `batch-index.csv`. **Expensive; do not delete** until
  `04_final` is complete. Without them the candidate sets cannot be rebuilt
  except by re-running the match.
- `logs/` — `run-<timestamp>.log`, `.err`, `progress.log`, `_STATUS.txt`.

The run is resumable: a chunk counts as done when its per-chunk report exists.
