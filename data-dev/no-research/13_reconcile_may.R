#!/usr/bin/env Rscript
# Reconcile the 2026MAY NO count under every plausible definition.
suppressPackageStartupMessages({library(data.table)})
D <- "data-dev/run-2026MAY"

bi   <- fread(file.path(D, "batch-index.csv"), colClasses = "character")
yes  <- fread(file.path(D, "CROSSWALK-ALL-2026MAY.csv"), colClasses = "character")
rev_new  <- fread(file.path(D, "batch1-new", "review-01.csv"), select = "uei", colClasses = "character")
rev_old  <- fread(file.path(D, "review-01.csv"), select = "uei", colClasses = "character")
rest <- rbindlist(lapply(list.files(file.path(D, "rest"), "^review-[0-9]+[.]csv$", full.names = TRUE),
                         fread, select = "uei", colClasses = "character"))

u_all <- unique(bi$uei); u_yes <- unique(yes$uei)
u_may_new <- unique(c(rev_new$uei, rest$uei))     # current address-gated gate
u_may_old <- unique(c(rev_old$uei, rest$uei))     # superseded batch-1 gate

cat("--- inputs ---\n")
cat("batch-index rows:", nrow(bi), " unique UEIs:", length(u_all), "\n")
cat("crosswalk rows  :", nrow(yes), " unique YES :", length(u_yes), "\n")
cat("MAYBE unique (current gate):", length(u_may_new),
    " (superseded gate):", length(u_may_old), "\n\n")

cat("--- NO under each definition ---\n")
cat("A. unique UEI, current gate      :", length(setdiff(u_all, union(u_yes, u_may_new))), "\n")
cat("B. unique UEI, superseded gate   :", length(setdiff(u_all, union(u_yes, u_may_old))), "\n")
cat("C. unique non-YES (NO + MAYBE)   :", length(setdiff(u_all, u_yes)), "\n")

# per-run-summary tallies (row level, as the matcher reported them)
rs <- rbindlist(list(
  fread(file.path(D, "batch1-new", "run-summary.csv"))[, .(rows, yes, maybe, no, coverage)],
  fread(file.path(D, "rest", "run-summary.csv"))[, .(rows, yes, maybe, no, coverage)]))
cat("D. row-level NO from run-summary :", sum(rs$no), "\n")
cat("E. row-level NO + uncovered      :", sum(rs$no) + sum(rs$rows - rs$coverage), "\n")
cat("   (rows", sum(rs$rows), "yes", sum(rs$yes), "maybe", sum(rs$maybe),
    "no", sum(rs$no), "uncovered", sum(rs$rows - rs$coverage), ")\n")

cat("\n--- what is actually in the plan's pool ---\n")
p1 <- fread("data-dev/no-research/POOL-STAGE1-NO.csv", colClasses = "character")
print(p1[run == "2026MAY", .N, by = no_origin])
cat("2026MAY total in stage-1 pool:", nrow(p1[run == "2026MAY"]), "\n")

cat("\n--- 2026MAY MAYBE queue: never adjudicated ---\n")
cat("MAYBE UEIs awaiting a stage-2 pass:", length(u_may_new), "\n")
cat("at 2025NOV's 33.9% NO rate that would add ~",
    round(length(u_may_new) * 0.339), "stage-2 NO cases\n")
