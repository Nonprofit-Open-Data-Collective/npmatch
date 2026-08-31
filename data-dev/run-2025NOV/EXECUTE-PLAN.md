# NOV-2025 full match — execute plan

Match the **165k SAM nonprofit registrations** (`ALL-NONPROFITS.CSV`) against the
**unified IRS BMF** and produce an accepted crosswalk plus LLM-sized review
shards. The run is **batched, checkpointed, and resumable** — if it is
interrupted (crash, reboot, `Ctrl-C`), just launch it again and it continues
from the last finished chunk.

---

## 1. What is being matched

| | |
|---|---|
| **Query (source)** | `data-dev/run-2025NOV/ALL-NONPROFITS.CSV` — **166,614 rows** (165k SAM nonprofit registrations, raw SAM headers) |
| **Reference** | `data-dev/NORM-BMF-UNIFIED.rds` — **3,687,435** normalized BMF orgs, with prebuilt `name_freq`, `token_idf`, and blocking `ref_index` |
| **Engine** | `npmatch::np_run_batches()` → per-chunk `np_cascade()` (hier scoring) → `np_route()` |

The reference `.rds` is **already the exact cache bundle** `np_run_batches()`
uses (`reference / name_freq / token_idf / ref_index`), so the run **skips all
one-time reference normalization and indexing** and goes straight to matching.

## 2. Run parameters (in `RUN.R`)

| knob | value | why |
|---|---|---|
| `COMPUTE_SIZE` | **2500** rows/chunk → **67 chunks** | memory-bound; proven safe in prior runs |
| `REVIEW_SIZE` | **250** queries/shard | one LLM-validation job per shard |
| `SEED` | **1** | deterministic shuffle → chunk membership is identical on every resume |
| `THREADS` | **14** of 16 | leave headroom for OS / Dropbox |
| `METHOD` | `hier` | hierarchical name+geo scoring |

**Estimated runtime:** ~0.3 s/row compute in prior runs → **≈ 14–16 h** wall
clock for 67 chunks. The first chunk finishes in ~10–15 min; check the log then
for a real ETA.

## 3. How to start

From the repo root (`.../00-GITHUB/npmatch`):

```bash
"/c/Program Files/R/R-4.5.1/bin/Rscript.exe" data-dev/run-2025NOV/RUN.R
```

To run detached with a log (PowerShell — this is how the driver was launched):

```powershell
$log = "data-dev/run-2025NOV/logs/run-<timestamp>.log"
Start-Process -FilePath "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" `
  -ArgumentList "data-dev/run-2025NOV/RUN.R" `
  -RedirectStandardOutput $log -RedirectStandardError "$log.err" `
  -WindowStyle Hidden -PassThru
```

The launcher records the OS process id in `run.pid`.

## 4. How to resume after an interruption

**Just run the same command again.** `RUN.R` scans for `report-NN.md` files
(written *last* for each chunk, so their presence means that chunk fully
committed its crosswalk + review + shards) and runs only the chunks that are
missing. Finished chunks are never redone. The reference cache is reloaded once;
no normalization is repeated.

- A chunk interrupted mid-way leaves **no** `report-NN.md`, so it is simply
  rerun cleanly from the start of that chunk.
- Chunk membership is fixed by `SEED = 1`, so chunk *N* is always the same rows.

## 5. Monitoring progress

```bash
# chunks finished out of 67
ls data-dev/run-2025NOV/report-*.md | wc -l

# live driver milestones
tail -n 40 data-dev/run-2025NOV/progress.log

# live per-chunk detail (YES/MAYBE/NO, timing) from the engine
tail -n 60 data-dev/run-2025NOV/logs/run-*.log

# one-line current state
cat data-dev/run-2025NOV/_STATUS.txt
```

## 6. Outputs

Per chunk (`NN` = 01..67):

| file | contents |
|---|---|
| `crosswalk-NN.csv` | accepted (YES) matches for the chunk |
| `review-NN.csv` | full MAYBE queue for the chunk |
| `review-NN-partKK.csv` | MAYBE hand-off **shards** (~250 queries) for LLM/human review |
| `report-NN.md` | per-chunk tally + cascade breakdown (**= chunk-done marker**) |

Run-level (written by the engine, refreshed each invocation):

- `batch-index.csv` — `uei -> chunk` manifest (reproducibility)
- `run-summary.csv` — engine summary for the **most recent** invocation only

Final merge (written by `RUN.R` **only when all 67 chunks are complete**):

- `CROSSWALK-ALL-2025NOV.csv` — all accepted matches, concatenated
- `MASTER-SUMMARY.csv` — per-chunk tally parsed from every `report-NN.md`
- `RUN-REPORT.md` — totals (YES / MAYBE / NO, coverage, time) + output index

## 7. Notes / gotchas

- **Dropbox:** this folder lives under Dropbox. Consider pausing Dropbox sync
  during the run to avoid file-lock contention while many small CSVs are
  written. Outputs total only ~40 MB, so disk is not a concern.
- **`run-summary.csv` is overwritten** each invocation — do **not** rely on it
  across resumes. `MASTER-SUMMARY.csv` (rebuilt from the per-chunk reports at the
  end) is the authoritative per-chunk tally.
- The unified reference has no active/inactive flag populated (`active` is `NA`),
  so accepted matches are to the unified BMF without an active-status column.
- Do not change `SEED` or `COMPUTE_SIZE` mid-run — that would re-partition the
  chunks and desynchronize resume detection.
