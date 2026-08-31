#!/usr/bin/env Rscript
# ==========================================================================
# NOV-2025 full match run  —  ALL-NONPROFITS.CSV  vs  unified BMF
# ==========================================================================
# Resumable, checkpointed batch driver. Safe to re-run: it detects which
# compute chunks are already finished (report-NN.md present) and only runs
# the rest. See EXECUTE-PLAN.md for the operator guide.
# --------------------------------------------------------------------------

suppressWarnings(suppressPackageStartupMessages({
  library(npmatch)
  library(data.table)
}))

## ---- configuration -------------------------------------------------------
REPO         <- "C:/Users/jdlec/Dropbox (Personal)/00 - URBAN/00-GITHUB/npmatch"
RUN_DIR      <- file.path(REPO, "data-dev/run-2025NOV")
QUERY_CSV    <- file.path(RUN_DIR, "ALL-NONPROFITS.CSV")
CACHE        <- file.path(REPO, "data-dev/NORM-BMF-UNIFIED.rds")  # prebuilt ref+idf+index bundle
COMPUTE_SIZE <- 2500L    # queries per compute chunk (memory-bound knob; proven size)
REVIEW_SIZE  <- 250L     # MAYBE queries per LLM review shard
SEED         <- 1L       # deterministic shuffle -> chunk membership is stable across resumes
THREADS      <- 14L      # leave 2 cores for the OS / Dropbox during the long run
METHOD       <- "hier"

PROGRESS <- file.path(RUN_DIR, "progress.log")
STATUS   <- file.path(RUN_DIR, "_STATUS.txt")

prog <- function(fmt, ...) {
  line <- sprintf("[%s] %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
                  sprintf(fmt, ...))
  cat(line, "\n", sep = "")
  cat(line, "\n", sep = "", file = PROGRESS, append = TRUE)
}
set_status <- function(fmt, ...) writeLines(
  sprintf("[%s] %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), sprintf(fmt, ...)), STATUS)

## ---- preflight -----------------------------------------------------------
stopifnot(file.exists(QUERY_CSV), file.exists(CACHE))
prog("=== RUN.R start (pid unknown to R; see run.pid) ===")
prog("query : %s", QUERY_CSV)
prog("cache : %s", CACHE)
prog("params: compute_size=%d review_size=%d seed=%d threads=%d method=%s",
     COMPUTE_SIZE, REVIEW_SIZE, SEED, THREADS, METHOD)

## ---- load query & determine chunk plan -----------------------------------
q <- as.data.frame(fread(QUERY_CSV, colClasses = "character",
                         showProgress = FALSE), stringsAsFactors = FALSE)
N  <- nrow(q)
nb <- max(1L, as.integer(ceiling(N / COMPUTE_SIZE)))
prog("loaded %s query rows -> %d compute chunk(s) of ~%d",
     format(N, big.mark = ","), nb, COMPUTE_SIZE)

## ---- resume detection: a chunk is DONE iff its report-NN.md exists --------
report_path <- function(b) file.path(RUN_DIR, sprintf("report-%02d.md", b))
done      <- which(vapply(seq_len(nb), function(b) file.exists(report_path(b)), logical(1)))
remaining <- setdiff(seq_len(nb), done)
prog("resume check: %d/%d chunks already complete; %d remaining",
     length(done), nb, length(remaining))
if (length(remaining))
  prog("remaining chunks: %s",
       paste(range(remaining), collapse = "..") )

## ---- run the remaining chunks (single call; each chunk checkpoints on disk)
if (length(remaining)) {
  set_status("RUNNING: %d/%d chunks left", length(remaining), nb)
  prog("calling np_run_batches(only = %d chunk(s)) ...", length(remaining))
  t0 <- Sys.time()
  ok <- tryCatch({
    np_run_batches(
      query        = q,
      reference    = NULL,          # unused: cache exists, ref is read from CACHE
      compute_size = COMPUTE_SIZE,
      review_size  = REVIEW_SIZE,
      out_dir      = RUN_DIR,
      only         = remaining,
      cache        = CACHE,
      sam_context  = q,             # adds SAM_* context columns to the review queue
      seed         = SEED,
      method       = METHOD,
      threads      = THREADS,
      verbose      = TRUE)
    TRUE
  }, error = function(e) { prog("ERROR in np_run_batches: %s", conditionMessage(e)); FALSE })
  prog("np_run_batches returned after %.1f min (ok=%s)",
       as.numeric(difftime(Sys.time(), t0, units = "mins")), ok)
} else {
  prog("nothing to run; all chunks already complete")
}

## ---- re-check completion -------------------------------------------------
done2      <- which(vapply(seq_len(nb), function(b) file.exists(report_path(b)), logical(1)))
remaining2 <- setdiff(seq_len(nb), done2)

if (length(remaining2)) {
  set_status("INCOMPLETE: %d/%d chunks done. Re-run RUN.R to resume.",
             length(done2), nb)
  prog("INCOMPLETE: %d/%d chunks done. Re-run RUN.R to resume the rest (%s).",
       length(done2), nb, paste(range(remaining2), collapse = ".."))
  quit(save = "no", status = 0L)
}

## ==========================================================================
## FINAL MERGE  —  runs only when every chunk is complete
## ==========================================================================
prog("=== all %d chunks complete -> merging ===", nb)

# 1) master crosswalk (all YES picks)
xw_files <- file.path(RUN_DIR, sprintf("crosswalk-%02d.csv", seq_len(nb)))
xw_files <- xw_files[file.exists(xw_files)]
xw <- rbindlist(lapply(xw_files, fread, colClasses = "character"),
                use.names = TRUE, fill = TRUE)
fwrite(xw, file.path(RUN_DIR, "CROSSWALK-ALL-2025NOV.csv"))
prog("wrote CROSSWALK-ALL-2025NOV.csv (%s accepted rows)",
     format(nrow(xw), big.mark = ","))

# 2) master summary parsed from each report-NN.md (robust to resume boundaries)
num1 <- function(txt, pat) {
  m <- regmatches(txt, regexpr(pat, txt, perl = TRUE))
  if (!length(m)) return(NA_integer_)
  as.integer(gsub("\\D", "", m))
}
rows_list <- lapply(seq_len(nb), function(b) {
  r <- readLines(report_path(b), warn = FALSE)
  L <- function(key) { hit <- grep(key, r, fixed = TRUE, value = TRUE); if (length(hit)) hit[1] else "" }
  cov <- regmatches(L("- coverage:"),
                    regexpr("[0-9]+/[0-9]+", L("- coverage:")))
  rt  <- regmatches(L("- runtime:"), regexpr("[0-9.]+", L("- runtime:")))
  data.frame(
    batch    = b,
    rows     = num1(L("- rows:"),            "[0-9]+"),
    yes      = num1(L("- YES"),              "[0-9]+"),
    maybe    = num1(L("- MAYBE"),            "[0-9]+"),
    no       = num1(L("- NO:"),              "[0-9]+"),
    coverage = if (length(cov)) cov else NA_character_,
    runtime_min = if (length(rt)) as.numeric(rt) else NA_real_,
    stringsAsFactors = FALSE)
})
summ <- rbindlist(rows_list, use.names = TRUE, fill = TRUE)
fwrite(summ, file.path(RUN_DIR, "MASTER-SUMMARY.csv"))

tot_rows <- sum(summ$rows,  na.rm = TRUE)
tot_yes  <- sum(summ$yes,   na.rm = TRUE)
tot_may  <- sum(summ$maybe, na.rm = TRUE)
tot_no   <- sum(summ$no,    na.rm = TRUE)
tot_min  <- sum(summ$runtime_min, na.rm = TRUE)
n_shards <- length(list.files(RUN_DIR, pattern = "^review-[0-9]+-part[0-9]+\\.csv$"))

# 3) run report
writeLines(c(
  "# NOV-2025 full match — run report",
  "",
  sprintf("- generated: %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
  sprintf("- query: `ALL-NONPROFITS.CSV` (%s rows)", format(N, big.mark = ",")),
  sprintf("- reference: unified BMF via `NORM-BMF-UNIFIED.rds`"),
  sprintf("- compute chunks: %d (size ~%d) | review shards: %d (size ~%d)",
          nb, COMPUTE_SIZE, n_shards, REVIEW_SIZE),
  "",
  "## Totals",
  "",
  sprintf("- rows matched: %s", format(tot_rows, big.mark = ",")),
  sprintf("- YES (accepted crosswalk): %s  (%.1f%%)",
          format(tot_yes, big.mark = ","), 100 * tot_yes / tot_rows),
  sprintf("- MAYBE (review -> LLM/human): %s  (%.1f%%)",
          format(tot_may, big.mark = ","), 100 * tot_may / tot_rows),
  sprintf("- NO: %s  (%.1f%%)",
          format(tot_no, big.mark = ","), 100 * tot_no / tot_rows),
  sprintf("- total compute time (sum of chunks): %.1f min (%.1f h)",
          tot_min, tot_min / 60),
  "",
  "## Outputs",
  "",
  "- `CROSSWALK-ALL-2025NOV.csv` — all accepted (YES) matches",
  "- `review-NN-partKK.csv` — MAYBE hand-off shards (~250 queries each) for LLM/human validation",
  "- `MASTER-SUMMARY.csv` — per-chunk tally",
  "- `batch-index.csv` — uei -> chunk manifest"
), file.path(RUN_DIR, "RUN-REPORT.md"))

set_status("COMPLETE: %d/%d chunks. YES=%s MAYBE=%s NO=%s",
           nb, nb, format(tot_yes, big.mark=","),
           format(tot_may, big.mark=","), format(tot_no, big.mark=","))
prog("=== DONE. YES=%s MAYBE=%s NO=%s. See RUN-REPORT.md ===",
     format(tot_yes, big.mark=","), format(tot_may, big.mark=","),
     format(tot_no, big.mark=","))
