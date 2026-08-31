#!/usr/bin/env Rscript
# Validate per-shard decision files and emit the list of shards still pending
# (missing or invalid). A shard counts as DONE only when its decision file:
#   - exists and has the exact header,
#   - has one row per UEI in the shard (no missing/extra UEIs),
#   - uses decision in {YES,NO} and confidence in {high,medium,low},
#   - for YES rows, best_ein is one of that UEI's candidate EINs (no hallucinated EIN).
# Writes pending.txt (one base per line) and validation-report.csv.

suppressWarnings(suppressPackageStartupMessages(library(data.table)))

REVIEW   <- "data-dev/run-2026MAY/llm-review"
SLIM_DIR <- file.path(REVIEW, "slim")
DEC_DIR  <- file.path(REVIEW, "decisions")
HEADER   <- c("uei","best_ein","llm_decision","llm_confidence","llm_reason")

man <- fread(file.path(REVIEW, "manifest.csv"), colClasses = "character")
man[, n_uei := as.integer(n_uei)]

check_one <- function(base, n_uei_expected) {
  dp <- file.path(DEC_DIR, sprintf("decision-%s.csv", base))
  if (!file.exists(dp)) return(list(ok = FALSE, why = "missing", n = 0L, yes = 0L, no = 0L))
  d <- tryCatch(fread(dp, colClasses = "character"), error = function(e) NULL)
  if (is.null(d)) return(list(ok = FALSE, why = "unreadable", n = 0L, yes = 0L, no = 0L))
  if (!identical(names(d), HEADER))
    return(list(ok = FALSE, why = "bad-header", n = nrow(d), yes = 0L, no = 0L))
  # valid uei -> candidate EIN set from the slim shard
  sl <- fread(file.path(SLIM_DIR, sprintf("slim-%s.csv", base)), colClasses = "character")
  ueis <- unique(sl$uei)
  dec_ueis <- unique(d$uei)
  if (!setequal(dec_ueis, ueis))
    return(list(ok = FALSE, why = sprintf("uei-mismatch(dec=%d,exp=%d)", length(dec_ueis), length(ueis)),
                n = nrow(d), yes = 0L, no = 0L))
  if (anyDuplicated(d$uei))
    return(list(ok = FALSE, why = "duplicate-uei", n = nrow(d), yes = 0L, no = 0L))
  if (!all(d$llm_decision %in% c("YES","NO")))
    return(list(ok = FALSE, why = "bad-decision", n = nrow(d), yes = 0L, no = 0L))
  # confidence is required for YES (accepted match); NO rows may leave it blank
  yc <- tolower(d[llm_decision == "YES", llm_confidence])
  if (!all(yc %in% c("high","medium","low")))
    return(list(ok = FALSE, why = "bad-confidence-yes", n = nrow(d), yes = 0L, no = 0L))
  # YES rows must reference a real candidate EIN for that UEI
  ein_by_uei <- split(sl$ein, sl$uei)
  yes <- d[llm_decision == "YES"]
  bad_ein <- FALSE
  if (nrow(yes)) {
    bad_ein <- any(mapply(function(u, e) !(e %in% ein_by_uei[[u]]),
                          yes$uei, yes$best_ein))
  }
  if (isTRUE(bad_ein))
    return(list(ok = FALSE, why = "hallucinated-ein", n = nrow(d),
                yes = nrow(yes), no = sum(d$llm_decision=="NO")))
  list(ok = TRUE, why = "ok", n = nrow(d),
       yes = sum(d$llm_decision=="YES"), no = sum(d$llm_decision=="NO"))
}

res <- lapply(seq_len(nrow(man)), function(i) {
  r <- check_one(man$base[i], man$n_uei[i])
  data.frame(base = man$base[i], ok = r$ok, why = r$why,
             rows = r$n, yes = r$yes, no = r$no, stringsAsFactors = FALSE)
})
rep <- rbindlist(res)
fwrite(rep, file.path(REVIEW, "validation-report.csv"))

pending <- rep[ok == FALSE, base]
writeLines(pending, file.path(REVIEW, "pending.txt"))

done <- sum(rep$ok)
cat(sprintf("VALIDATION: %d/%d shards done | %d pending | YES=%s NO=%s\n",
            done, nrow(rep), length(pending),
            format(sum(rep$yes), big.mark=","), format(sum(rep$no), big.mark=",")))
if (length(pending)) {
  bad <- rep[ok == FALSE & why != "missing"]
  if (nrow(bad)) { cat("INVALID (not just missing):\n"); print(bad[, .(base, why, rows)]) }
  cat("PENDING_BASES:", paste(pending, collapse=","), "\n")
} else {
  cat("ALL SHARDS VALID\n")
}
