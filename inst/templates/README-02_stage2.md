# 02_stage2 — LLM adjudication of MAYBE

Stage 1 routes to MAYBE when the score lands in the review band, when the margin
over the runner-up is thin, when a soft veto fired, or when the name and address
views disagree. This stage decides those cases.

The agent instructions are in `PROMPT.md`. Nothing here calls a model
automatically — the review frame is the hand-off *into* adjudication and the
decisions come back as separate files.

## Flow

```
stage1_maybe + stage1_k_candidates
        │
        ▼
   batches/slim/slim-*.csv        adjudicator inputs (one shard per job)
        │
        ▼   [ follow PROMPT.md ]
   batches/decisions/decision-*.csv   one per shard: uei, best_ein, decision,
        │                             confidence, reason
        ▼
   stage2_yes.csv  ·  stage2_no.csv
```

## Outputs

| file | what |
|---|---|
| `stage2_yes.csv` | adjudicator accepted a candidate; `ein` is the pick |
| `stage2_no.csv` | no credible candidate; `ein` blank, `reason` carries why |
| `STAGE2-REPORT.md` | YES/NO split, confidence mix, duplicate conflicts |
| `STAGE2-STATS.csv` | per-shard validation and tally |

`stage2_yes` + `stage2_no` must equal `stage1_maybe`. If it does not, a shard
was lost — find it before rolling up.

## Duplicate registrations

A UEI matched in more than one compute chunk can be adjudicated twice. Those
rows collapse to one, preferring YES over NO and then higher confidence. Genuine
disagreements are recorded rather than hidden — check the report for them.
