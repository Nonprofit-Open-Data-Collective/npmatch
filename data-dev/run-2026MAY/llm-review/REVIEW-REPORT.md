# 2026-MAY MAYBE review — LLM adjudication report

- generated: 2026-08-26 22:02:00
- shards adjudicated: 5
- decision rows: 902 (across shards) -> 893 unique UEIs (9 dup registrations collapsed)
- conflicting duplicate UEIs (disagreeing dup rows, kept best): 0

## Decisions

- YES (LLM-accepted match): 534  (59.8%)
    - high confidence:   393
    - medium confidence: 128
    - low confidence:    13
- NO (no credible candidate): 359  (40.2%)

## Crosswalk

- auto-YES (match run):       6,875  (from 6,875 rows; dup UEIs collapsed)
- + LLM-YES added (net):      534  (of 534 LLM-YES; rest were already auto-YES UEIs)
- = augmented crosswalk:      7,409  (one row per source UEI)

## Outputs

- `DECISIONS-ALL.csv` — every MAYBE UEI: decision, best_ein, confidence, reason
- `CROSSWALK-AUGMENTED-2026MAY.csv` — auto-YES + LLM-YES (`source` column; LLM rows carry confidence + reason)
