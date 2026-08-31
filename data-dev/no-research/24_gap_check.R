#!/usr/bin/env Rscript
# The new escape hatch un-gates cases the pilot never researched. How many, and
# how many already have an answer from the two blind audit passes?
suppressPackageStartupMessages({library(data.table)})
out <- "data-dev/no-research"

seed <- fread(file.path(out, "FINDINGS-SEED.csv"), colClasses = "character")
f1   <- fread(file.path(out, "FINDINGS-STAGE1-NO-500.csv"), colClasses = "character")
f2   <- fread(file.path(out, "FINDINGS-STAGE2-NO-500.csv"), colClasses = "character")
old  <- rbindlist(list(f1, f2), fill = TRUE)[, .(uei, old_web = web, old_det = determination)]

a <- merge(seed[, .(uei, .src, entity_gate, web_reason, web, sam_name)], old, by = "uei")
new_web <- a[web == "TRUE" & old_web == "FALSE"]
cat("cases newly un-gated by the escape hatch:", nrow(new_web), "\n")
print(new_web[, .N, by = .(web_reason, .src)][order(-N)])

## which already have a blind answer from audit v1 / v2?
have <- character(0)
p <- file.path(out, "AUDIT-V1-VS-V2.csv")
if (file.exists(p)) {
  vv <- fread(p, colClasses = "character")
  have <- vv[!is.na(v2_det) & v2_det != ""]$uei
}
new_web[, already_answered := uei %chin% have]
cat("\nof those, already researched blind in the gate audit:",
    sum(new_web$already_answered), "\n")
gap <- new_web[already_answered == FALSE]
cat("still needing research:", nrow(gap), sprintf(" (~%d agents)\n", ceiling(nrow(gap)/8)))
print(gap[, .N, by = .(entity_gate, web_reason)][order(-N)])

fwrite(gap[, .(uei, sam_name)], file.path(out, "QUEUE-GAP.csv"))
cat("\nwrote QUEUE-GAP.csv\n")
