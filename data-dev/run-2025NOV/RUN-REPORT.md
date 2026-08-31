# NOV-2025 full match — run report

- generated: 2026-08-15 16:04:16
- query: `ALL-NONPROFITS.CSV` (166,614 rows)
- reference: unified BMF via `NORM-BMF-UNIFIED.rds`
- compute chunks: 67 (size ~2500) | review shards: 133 (size ~250)

## Totals

- rows matched: 166,614
- YES (accepted crosswalk): 116,354  (69.8%)
- MAYBE (review -> LLM/human): 18,498  (11.1%)
- NO: 29,457  (17.7%)
- total compute time (sum of chunks): 281.0 min (4.7 h)

## Outputs

- `CROSSWALK-ALL-2025NOV.csv` — all accepted (YES) matches
- `review-NN-partKK.csv` — MAYBE hand-off shards (~250 queries each) for LLM/human validation
- `MASTER-SUMMARY.csv` — per-chunk tally
- `batch-index.csv` — uei -> chunk manifest
