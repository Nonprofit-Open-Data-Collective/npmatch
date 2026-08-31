# NOV-2025 MAYBE review — LLM adjudication report

- generated: 2026-08-16 06:59:40
- shards adjudicated: 133
- decision rows: 18,498 (across shards) -> 18,204 unique UEIs (294 dup registrations collapsed)
- conflicting duplicate UEIs (disagreeing dup rows, kept best): 32

## Decisions

- YES (LLM-accepted match): 12,038  (66.1%)
    - high confidence:   8,870
    - medium confidence: 3,089
    - low confidence:    79
- NO (no credible candidate): 6,166  (33.9%)

## Crosswalk

- auto-YES (match run):       114,746  (from 116,354 rows; dup UEIs collapsed)
- + LLM-YES added (net):      12,038  (of 12,038 LLM-YES; rest were already auto-YES UEIs)
- = augmented crosswalk:      126,784  (one row per source UEI)

## Outputs

- `DECISIONS-ALL.csv` — every MAYBE UEI: decision, best_ein, confidence, reason
- `CROSSWALK-AUGMENTED-2025NOV.csv` — auto-YES + LLM-YES (`source` column; LLM rows carry confidence + reason)
