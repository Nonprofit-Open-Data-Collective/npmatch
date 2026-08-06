# Training-set ground-truthing & FP/FN pipeline

Reproducible pipeline that takes the algorithmic match results, ground-truths every
query (algorithmic → local → web research), and computes the matcher's false-positive
and false-negative rates. Companion to [`dev/RESEARCH-PROTOCOL.md`](../RESEARCH-PROTOCOL.md)
and the Tier-1 screen in [`dev/tier1/`](../tier1).

All scripts read/write under `data-dev/` (git-ignored). Run with the project R:
`"C:/Program Files/R/R-4.4.2/bin/Rscript.exe" dev/research/<script>.R`

## Inputs (produced upstream, in `data-dev/`)
- `RES-1K-RANDOM.rds`, `RES-2K.rds` — cascade results (+ candidate `pairs` attribute) for the
  1,000-case random sample and the 2,000-case pool the 502 hard cases are drawn from.
- `BMF-NAME-INDEX.rds` — unified (active+inactive) BMF name index (see `dev/tier1/build_bmf_index.R`).
- `TOKEN-IDF.rds` — token → IDF weights.
- `CALIBRATION-LABELED-502.csv` — human labels for the hard set.
- `RANDOM-GROUNDTRUTH.csv`, `HARD-GROUNDTRUTH.csv` — per-query FP/FN scaffold (algo labels preserved).

## Pipeline

| # | Script | Purpose |
|---|--------|---------|
| 00 | `00_yes_qc.R` | QC a sample of auto-accepted YES → false-positive rate |
| 01 | `01_hard502_screen.R` | Tier-1 screen over the hard-502 → FP/FN scaffold + blocking-miss discovery |
| 02 | `02_build_pending.R` | Collect all still-unresolved queries into `PENDING-RESEARCH.csv` |
| 03 | `03_triage.R` | Free structural auto-classify (gov / credit-union / LLC-LP); emit web worklist |
| 04 | `04_local_match.R` | Same-state token-coverage match vs unified BMF → `LOCAL-MATCH2.csv` |
| 05 | `05_gate_idf.R` | IDF-gate the local matches (distinctive shared tokens only) → `GATE-IDF.csv` |
| 06 | `06_classify_residual.R` | Address-corroborated fuzzy + church/individual name rules |
| 07 | `07_finalize.R` | Combine firm determinations + mark the rest provisional-pending-web |
| 08 | `08_emit_worklist.R` | Order the residual (NO/ZERO first = highest FN value) → `VERIFY-WORKLIST.csv` |
| 09 | `09_record_batch.R` | **Template**: edit the `b` block per web-research batch; appends to `VERIFY-RESULTS.csv` |
| 10 | `10_final_fold.R` | Fold verified determinations into ground truth; check recovered EINs vs BMF (active/inactive/absent) |
| 11 | `11_final_summary.R` | Whole-training-set determination breakdown |
| 12 | `12_coverage_check.R` | For each active-BMF match the algo missed: was the true EIN a candidate? (blocking vs scoring failure) |

Steps 08–09 are the web-research loop: ProPublica is IP-blocked from this sandbox, so
verification uses `WebSearch` per org (NO/ZERO tier first). Each batch edits the `b` table in
`09_record_batch.R` and re-runs it; results checkpoint to `VERIFY-RESULTS.csv`.

## Key outputs (`data-dev/`)
- `VERIFY-RESULTS.csv` — per-org determination (match / not_a_nonprofit / nonprofit_not_in_bmf /
  cant_determine), recovered EIN, confidence, source, notes.
- `RANDOM-GROUNDTRUTH.csv`, `HARD-GROUNDTRUTH.csv` — updated with final `gt_det`/`gt_ein`, `is_fn`/`is_fp`.
- `RESIDUAL-260-FINAL.rds` — the 260 residual determinations + BMF-presence flag.

## Headline results (this run)
- **False positives** on auto-accepted YES: ~2–2.6% (hard 4/151; random ~2% QC).
- **False negatives**: 43 active-BMF matches the algo failed to auto-accept, of which
  **31 are genuine coverage failures** — 14 blocking misses (true EIN never generated as a
  candidate) + 17 NO-tier scoring demotions (right candidate existed but was demoted). The
  other 12 were surfaced as MAYBE (working as intended → human/LLM review).
- Blocking-miss patterns to fix in candidate generation: de-spacing (`STEP FORWARD`→`STEPFORWARD`),
  abbreviation expansion (`NE`→`Northeast`), typo tolerance (`ENVIROMENT`), rebrands/parents/dba,
  and not restricting to 501(c)(3) (e.g. a 501(c)(6) match).
