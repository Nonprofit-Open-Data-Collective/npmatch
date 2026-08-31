#!/usr/bin/env Rscript
# Merge validated per-shard decisions into DECISIONS-ALL.csv, build the
# augmented crosswalk (auto-YES + LLM-YES, distinguished by `source`, carrying
# confidence + reasoning), and write REVIEW-REPORT.md. Run after validate.R
# reports 0 pending.

suppressWarnings(suppressPackageStartupMessages(library(data.table)))

BASE     <- "C:/Users/jdlec/Dropbox (Personal)/00 - URBAN/00-GITHUB/npmatch/data-dev/run-2025NOV"
REVIEW   <- file.path(BASE, "llm-review")
SLIM_DIR <- file.path(REVIEW, "slim")
DEC_DIR  <- file.path(REVIEW, "decisions")

# 1) all decisions -------------------------------------------------------------
# Some source UEIs appear in >1 shard (duplicate SAM registrations matched in
# more than one compute chunk). Collapse to one row per UEI, preferring a YES
# over a NO and higher confidence, and flag any UEI whose duplicates disagree.
dec_files <- list.files(DEC_DIR, pattern = "^decision-.*\\.csv$", full.names = TRUE)
dec_raw <- rbindlist(lapply(dec_files, function(f) {
  d <- fread(f, colClasses = "character")
  d[, base := sub("^decision-", "", sub("\\.csv$", "", basename(f)))]
  d
}), use.names = TRUE, fill = TRUE)
dec_raw[, llm_confidence := tolower(llm_confidence)]

n_raw <- nrow(dec_raw)
conf_rank <- c(high = 3L, medium = 2L, low = 1L)
dec_raw[, .ord := ifelse(llm_decision == "YES", 10L, 0L) +
          fifelse(is.na(conf_rank[llm_confidence]), 0L, conf_rank[llm_confidence])]
# conflict = a UEI whose duplicate rows disagree on decision or on YES-EIN
conflicts <- dec_raw[, .(nd = uniqueN(llm_decision),
                         ny = uniqueN(best_ein[llm_decision == "YES"])),
                     by = uei][nd > 1 | ny > 1, uei]
setorder(dec_raw, uei, -.ord)
dec <- dec_raw[!duplicated(uei)]
dec[, .ord := NULL]
fwrite(dec, file.path(REVIEW, "DECISIONS-ALL.csv"))
n_dupe_uei <- n_raw - nrow(dec)

# 2) name lookup from slim shards (uei+ein -> raw names) ------------------------
slim <- rbindlist(lapply(list.files(SLIM_DIR, pattern = "^slim-.*\\.csv$", full.names = TRUE),
                         fread, colClasses = "character"), use.names = TRUE, fill = TRUE)
names_lu <- unique(slim[, .(uei, ein,
                            name_uss = name_uss_raw_main,
                            name_bmf = name_bmf_raw_main)])

# 3) augmented crosswalk -------------------------------------------------------
xw <- fread(file.path(BASE, "CROSSWALK-ALL-2025NOV.csv"), colClasses = "character")
n_auto_raw <- nrow(xw)
xw <- xw[!duplicated(uei)]                       # collapse duplicate SAM registrations
xw_auto <- xw[, .(uei, name_uss, ein, name_bmf, score,
                  source = "auto_yes", llm_confidence = "", llm_reason = "")]

yes <- dec[llm_decision == "YES" & nzchar(best_ein)]
yes <- merge(yes, names_lu, by.x = c("uei", "best_ein"), by.y = c("uei", "ein"),
             all.x = TRUE, sort = FALSE)
xw_llm <- yes[, .(uei, name_uss, ein = best_ein, name_bmf, score = "",
                  source = "llm_review", llm_confidence, llm_reason)]

augmented <- rbindlist(list(xw_auto, xw_llm), use.names = TRUE)
# a dup registration can be auto-YES in one chunk and MAYBE->llm-YES in another;
# keep one row per UEI, preferring the auto-YES (match-run) row
augmented[, .src := fifelse(source == "auto_yes", 1L, 2L)]
setorder(augmented, uei, .src)
n_aug_raw <- nrow(augmented)
augmented <- augmented[!duplicated(uei)]
augmented[, .src := NULL]
fwrite(augmented, file.path(BASE, "CROSSWALK-AUGMENTED-2025NOV.csv"))

# 4) report --------------------------------------------------------------------
n_uei   <- length(unique(dec$uei))
n_yes   <- sum(dec$llm_decision == "YES")
n_no    <- sum(dec$llm_decision == "NO")
conf    <- table(factor(dec[llm_decision=="YES", llm_confidence],
                        c("high","medium","low")))
writeLines(c(
  "# NOV-2025 MAYBE review — LLM adjudication report",
  "",
  sprintf("- generated: %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
  sprintf("- shards adjudicated: %d", length(dec_files)),
  sprintf("- decision rows: %s (across shards) -> %s unique UEIs (%s dup registrations collapsed)",
          format(n_raw, big.mark=","), format(n_uei, big.mark=","), format(n_dupe_uei, big.mark=",")),
  sprintf("- conflicting duplicate UEIs (disagreeing dup rows, kept best): %d", length(conflicts)),
  "",
  "## Decisions",
  "",
  sprintf("- YES (LLM-accepted match): %s  (%.1f%%)", format(n_yes, big.mark=","), 100*n_yes/n_uei),
  sprintf("    - high confidence:   %s", format(conf[["high"]],   big.mark=",")),
  sprintf("    - medium confidence: %s", format(conf[["medium"]], big.mark=",")),
  sprintf("    - low confidence:    %s", format(conf[["low"]],    big.mark=",")),
  sprintf("- NO (no credible candidate): %s  (%.1f%%)", format(n_no, big.mark=","), 100*n_no/n_uei),
  "",
  "## Crosswalk",
  "",
  sprintf("- auto-YES (match run):       %s  (from %s rows; dup UEIs collapsed)",
          format(nrow(xw_auto), big.mark=","), format(n_auto_raw, big.mark=",")),
  sprintf("- + LLM-YES added (net):      %s  (of %s LLM-YES; rest were already auto-YES UEIs)",
          format(nrow(augmented) - nrow(xw_auto), big.mark=","), format(nrow(xw_llm), big.mark=",")),
  sprintf("- = augmented crosswalk:      %s  (one row per source UEI)", format(nrow(augmented), big.mark=",")),
  "",
  "## Outputs",
  "",
  "- `DECISIONS-ALL.csv` — every MAYBE UEI: decision, best_ein, confidence, reason",
  "- `CROSSWALK-AUGMENTED-2025NOV.csv` — auto-YES + LLM-YES (`source` column; LLM rows carry confidence + reason)"
), file.path(REVIEW, "REVIEW-REPORT.md"))

cat(sprintf("MERGE done: %s UEIs | YES=%s (H=%s M=%s L=%s) NO=%s | augmented xwalk=%s rows\n",
            format(n_uei, big.mark=","), format(n_yes, big.mark=","),
            conf[["high"]], conf[["medium"]], conf[["low"]],
            format(n_no, big.mark=","), format(nrow(augmented), big.mark=",")))
