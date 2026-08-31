#!/usr/bin/env Rscript
# Aggregate all NO cases from the 2025NOV and 2026MAY runs.
#   stage-1 NO : query UEIs the matcher dropped outright (not YES, not MAYBE)
#   stage-2 NO : MAYBE UEIs the LLM adjudication rejected (MAYBE -> NO)
suppressPackageStartupMessages({library(data.table)})

D <- "data-dev"
out <- file.path(D, "no-research")

## ---- 2025NOV -------------------------------------------------------------
nov_all   <- fread(file.path(D,"run-2025NOV","batch-index.csv"), colClasses="character")
nov_yes   <- fread(file.path(D,"run-2025NOV","CROSSWALK-ALL-2025NOV.csv"), colClasses="character")
nov_dec   <- fread(file.path(D,"run-2025NOV","llm-review","DECISIONS-ALL.csv"), colClasses="character")

nov_yes_u <- unique(nov_yes$uei)
nov_may_u <- unique(nov_dec$uei)                       # every MAYBE went to LLM review
nov_no1   <- setdiff(unique(nov_all$uei), union(nov_yes_u, nov_may_u))
nov_no2   <- unique(nov_dec[llm_decision=="NO"]$uei)

cat("2025NOV  queries:", length(unique(nov_all$uei)),
    " YES:", length(nov_yes_u), " MAYBE:", length(nov_may_u),
    " stage1-NO:", length(nov_no1), " stage2-NO:", length(nov_no2), "\n")

## ---- 2026MAY -------------------------------------------------------------
may_all <- fread(file.path(D,"run-2026MAY","batch-index.csv"), colClasses="character")
may_yes <- fread(file.path(D,"run-2026MAY","CROSSWALK-ALL-2026MAY.csv"), colClasses="character")

# MAYBE under the CURRENT (address-gated) gate: batch1-new + rest
may_rev_files <- c(file.path(D,"run-2026MAY","batch1-new","review-01.csv"),
                   list.files(file.path(D,"run-2026MAY","rest"), "^review-[0-9]+[.]csv$", full.names=TRUE))
may_may_u <- unique(unlist(lapply(may_rev_files, function(f)
  fread(f, select="uei", colClasses="character")$uei)))

# the superseded batch-1 gate, to identify the 31 regate MAYBE -> NO cases
may_old_may <- unique(fread(file.path(D,"run-2026MAY","review-01.csv"), select="uei", colClasses="character")$uei)
regate_no   <- setdiff(may_old_may, may_may_u)

may_yes_u <- unique(may_yes$uei)
may_no1   <- setdiff(unique(may_all$uei), union(may_yes_u, may_may_u))

cat("2026MAY  queries:", length(unique(may_all$uei)),
    " YES:", length(may_yes_u), " MAYBE:", length(may_may_u),
    " stage1-NO:", length(may_no1), " (of which regate MAYBE->NO:", length(regate_no), ")\n")

## ---- pools ---------------------------------------------------------------
pool1 <- rbindlist(list(
  data.table(uei=nov_no1, run="2025NOV", stage="stage1",
             no_origin=ifelse(nov_no1 %in% character(0), "", "algorithm")),
  data.table(uei=may_no1, run="2026MAY", stage="stage1",
             no_origin=fifelse(may_no1 %in% regate_no, "algorithm_regate", "algorithm"))
))
## ---- 2026MAY stage 2 -----------------------------------------------------
## The 2026MAY MAYBE queue WAS adjudicated (893 -> 534 YES / 359 NO), but those
## outputs are not in this working tree. Drop the decisions file at one of the
## paths below (needs columns: uei, llm_decision [, best_ein, llm_confidence,
## llm_reason]) and the stage-2 pool picks it up automatically.
may_dec_paths <- c(
  file.path(D,"run-2026MAY","llm-review","DECISIONS-ALL.csv"),
  file.path(D,"run-2026MAY","DECISIONS-ALL-2026MAY.csv"),
  file.path(D,"no-research","DECISIONS-ALL-2026MAY.csv"))
may_dec_file <- may_dec_paths[file.exists(may_dec_paths)][1]

if (!is.na(may_dec_file)) {
  may_dec <- fread(may_dec_file, colClasses="character")
  may_no2 <- unique(may_dec[llm_decision=="NO"]$uei)
  cat("2026MAY stage-2 decisions:", may_dec_file, "->", length(may_no2), "NO\n")
  if (length(may_no2) != 359)
    warning("expected 359 2026MAY stage-2 NO, got ", length(may_no2))
} else {
  may_no2 <- character(0)
  cat("\n!! 2026MAY stage-2 decisions NOT FOUND. Expected 359 NO cases are MISSING\n",
      "   from the stage-2 pool. Searched:\n   - ",
      paste(may_dec_paths, collapse="\n   - "), "\n", sep="")
}

pool2 <- rbindlist(list(
  data.table(uei=nov_no2, run="2025NOV", stage="stage2", no_origin="llm_maybe_to_no"),
  data.table(uei=may_no2, run="2026MAY", stage="stage2", no_origin="llm_maybe_to_no")))

fwrite(pool1, file.path(out,"POOL-STAGE1-NO.csv"))
fwrite(pool2, file.path(out,"POOL-STAGE2-NO.csv"))
cat("\nPOOL-STAGE1-NO:", nrow(pool1), " POOL-STAGE2-NO:", nrow(pool2), "\n")
