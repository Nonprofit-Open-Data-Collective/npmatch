# 04_final — rollup

Generated, not authored. Every file here is rebuilt from the stage outputs by
the rollup functions; nothing is edited in place.

```r
np_rollup_matches()   # rbind stage{1,2,3}_yes            -> crosswalk.csv
np_rollup_eval()      # + k_candidates + research_findings -> eval_frame.csv
np_final_report()     #                                    -> FINAL-REPORT.md
```

## Outputs

| file | what |
|---|---|
| `crosswalk.csv` | the deliverable linkage table: every matched UEI, one row each |
| `eval_frame.csv` | candidate-level evaluation frame with outcomes and context |
| `FINAL-REPORT.md` | end-to-end funnel, per-stage contribution, precision/recall |
| `FINAL-STATS.csv` | the funnel as data |

"Crosswalk" is used **only** here, for the published artifact. Everywhere else
the term is `matches`, to keep partial and final results from sounding alike.

## What the rollup must preserve

- `decided_by` — which stage produced each match. A stage-3 match found by web
  search is not the same evidence as an auto-accepted stage-1 match, and
  downstream users need to be able to filter on that.
- `confidence` and low-confidence flags.
- Many-to-one EINs. Federated networks legitimately resolve many UEIs to one
  parent EIN. Those rows are correct, but they behave differently from 1:1
  matches and must be flagged rather than silently collapsed.
- Unresolved cases. A queued case that returned nothing is a hole, not a NO.
