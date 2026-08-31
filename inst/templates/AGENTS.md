# Orchestrating run {{run_id}}

Instructions for an agent driving this run end to end. Work one stage at a time
and check `RUN-STATUS.md` between stages.

## Ground rules

- **Never edit a stage's outputs by hand.** Re-run the stage function.
- **Never delete `interim/`** until `04_final` is complete — the cascade result
  and scored pairs there are expensive and are not regenerable cheaply.
- Everything under `batches/` is derived. Safe to delete and rebuild.
- Write logs to the stage's `logs/`, not to the console only.
- Record every input and output in `manifest.csv` via `np_manifest_add()`.

## Order of operations

1. **`00_bmf`** — confirm `SOURCE.md` names a reference vintage and that
   `SIGNATURE.txt` still matches `np_normalize_signature()` on the cached
   bundle. A mismatch means the cache drifted from the current normalization
   code: rebuild it before matching, or the run is not reproducible.
2. **`00_sams`** — put the SAM extract in `00_sams/raw/` (paste it, or use
   `np_fetch_sam()`), then filter to nonprofits. Output: `sam_query.csv`.
3. **`01_stage1`** — run the cascade. Outputs: `stage1_yes`, `stage1_maybe`,
   `stage1_no`, `stage1_k_candidates`. Read `STAGE1-REPORT.md` before moving on.
4. **`02_stage2`** — adjudicate `stage1_maybe`. Follow `02_stage2/PROMPT.md`.
   Inputs are in `batches/slim/`; write one decision file per shard to
   `batches/decisions/`. Outputs: `stage2_yes`, `stage2_no`.
5. **`03_stage3`** — research the NO cases. Follow `03_stage3/PROMPT.md`. By
   default this consumes both `stage1_no` and `stage2_no`; it can be
   constrained to stage 1 only. Outputs: `stage3_yes`, `stage3_no`,
   `stage3_research_findings`.
6. **`04_final`** — roll up. Outputs: `crosswalk.csv`, `eval_frame.csv`.

## Stopping conditions

Stop and report rather than improvising if any of these hold:

- `SIGNATURE.txt` does not match the cached reference bundle.
- A stage's expected outputs are present but its row counts do not reconcile
  with the previous stage (e.g. `stage2_yes` + `stage2_no` != `stage1_maybe`).
- A batch queued for an LLM stage returns no output file. Record which, and do
  not silently drop it — an unreturned batch is a hole in the results, not a
  zero.
