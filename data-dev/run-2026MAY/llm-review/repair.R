#!/usr/bin/env Rscript
# Deterministically repair the decision files that failed validation:
#   - robust parse: reason is the LAST field, so re-join everything after the
#     4th comma and swap embedded commas -> ';' (fixes comma-in-reason rows that
#     broke row counts / made fread stop early),
#   - normalize decision (UPPER) and confidence (lower; YES must be high/medium/low,
#     else 'low'; NO may stay blank),
#   - downgrade any YES whose best_ein is NOT among that UEI's candidate EINs to
#     NO (never promote an unverifiable EIN into the crosswalk).
# Reports any base whose UEI set still doesn't match the shard (would need re-run).

suppressWarnings(suppressPackageStartupMessages(library(data.table)))

REVIEW   <- "data-dev/run-2026MAY/llm-review"
SLIM_DIR <- file.path(REVIEW, "slim")
DEC_DIR  <- file.path(REVIEW, "decisions")
HEADER   <- "uei,best_ein,llm_decision,llm_confidence,llm_reason"

bases <- readLines(file.path(REVIEW, "pending.txt"))
bases <- bases[nzchar(bases)]
cat(sprintf("repairing %d bases: %s\n", length(bases), paste(bases, collapse=", ")))

for (base in bases) {
  dp <- file.path(DEC_DIR, sprintf("decision-%s.csv", base))
  raw <- readLines(dp, warn = FALSE)
  raw <- raw[nzchar(raw)]
  body <- raw[-1]                                   # drop header
  parse_line <- function(ln) {
    p <- strsplit(ln, ",", fixed = TRUE)[[1]]
    if (length(p) < 4) p <- c(p, rep("", 4 - length(p)))
    reason <- if (length(p) >= 5) paste(p[5:length(p)], collapse = "; ") else ""
    c(uei = trimws(p[1]), best_ein = trimws(p[2]),
      llm_decision = trimws(p[3]), llm_confidence = trimws(p[4]),
      llm_reason = trimws(gsub("\\s+", " ", reason)))
  }
  m <- do.call(rbind, lapply(body, parse_line))
  d <- as.data.table(m)

  d[, llm_decision   := toupper(llm_decision)]
  d[llm_decision %in% c("Y","YES"), llm_decision := "YES"]
  d[llm_decision %in% c("N","NO"),  llm_decision := "NO"]
  d[, llm_confidence := tolower(llm_confidence)]
  d[llm_confidence %in% c("moderate","mod","med"), llm_confidence := "medium"]
  d[llm_confidence %in% c("hi","strong"),           llm_confidence := "high"]

  # candidate EIN set per uei
  sl <- fread(file.path(SLIM_DIR, sprintf("slim-%s.csv", base)), colClasses = "character")
  ein_by_uei <- split(sl$ein, sl$uei)

  # downgrade off-candidate YES -> NO
  is_yes <- d$llm_decision == "YES"
  off <- is_yes & mapply(function(u,e) !(e %in% ein_by_uei[[u]]), d$uei, d$best_ein)
  n_down <- sum(off)
  if (n_down) {
    d[off, llm_reason    := paste0("[auto-repair off-candidate EIN downgraded to NO] ", llm_reason)]
    d[off, best_ein      := ""]
    d[off, llm_decision  := "NO"]
    d[off, llm_confidence:= ""]
  }
  # YES must carry a valid confidence
  bad_conf_yes <- d$llm_decision == "YES" & !(d$llm_confidence %in% c("high","medium","low"))
  if (any(bad_conf_yes)) d[bad_conf_yes, llm_confidence := "low"]

  # de-dup uei (keep first) and check against shard
  d <- d[!duplicated(uei)]
  exp_ueis <- unique(sl$uei)
  miss <- setdiff(exp_ueis, d$uei)
  extra <- setdiff(d$uei, exp_ueis)
  status <- if (length(miss) || length(extra)) "NEEDS-RERUN" else "ok"

  fwrite(d, dp, quote = TRUE)                        # quote so any residual ';' reasons are safe
  cat(sprintf("  %-12s rows=%d yes=%d no=%d downgraded=%d  [%s]%s\n",
              base, nrow(d), sum(d$llm_decision=="YES"), sum(d$llm_decision=="NO"),
              n_down, status,
              if (status!="ok") sprintf(" miss=%d extra=%d", length(miss), length(extra)) else ""))
}
cat("repair complete. Re-run validate.R to confirm.\n")
