#!/usr/bin/env Rscript
# Find rows that claim Tier 3 but show no evidence of a web search.
#
# WebSearch has a per-agent session quota. An agent that exhausts it partway
# through its assignment can fall back to writing `cant_determine` for the rest
# -- rows that are indistinguishable from real exhaustive determinations by
# every structural check: 11 fields, valid taxonomy, valid tier, right UEI.
#
# Asking agents to self-report caught some of it (run-1169 volunteered). It did
# NOT catch run-1141, which silently wrote five unsearched `cant_determine`s.
# The reliable signal is documentary: resolving_tier == "tier3" with no
# `web:<url>` anywhere in `sources`. A genuine Tier-3 dead end still cites the
# searches it ran; a skipped one has nothing to cite.
suppressPackageStartupMessages({library(data.table)})
out <- "data-dev/no-research"

files <- list.files(file.path(out, "run-out"), "^run-[0-9]+[.]tsv$", full.names = TRUE)
cat("output files:", length(files), "\n")

NEED <- c("uei","sam_name","ein_found","determination","resolving_tier","sources")
d <- rbindlist(lapply(files, function(f) {
  x <- tryCatch(fread(f, sep = "\t", colClasses = "character", quote = "", fill = TRUE),
                error = function(e) NULL)
  if (is.null(x) || !nrow(x)) return(NULL)
  for (n in setdiff(NEED, names(x))) x[[n]] <- ""
  x[, ..NEED][, batch := sub("^run-", "", tools::file_path_sans_ext(basename(f)))]
}), fill = TRUE)

d[, cited_web := grepl("web:", sources, fixed = TRUE)]
d[, t3 := resolving_tier == "tier3"]

cat("\n--- tier3 rows without a web citation ---\n")
cat(sprintf("  %d of %d tier3 rows (%.1f%%)\n",
            sum(d$t3 & !d$cited_web), sum(d$t3),
            100 * sum(d$t3 & !d$cited_web) / max(sum(d$t3), 1)))

## the dangerous subset: an unsearched row that ALSO gave up
bad <- d[determination == "cant_determine" & t3 & !cited_web]
cat(sprintf("\n  cant_determine + tier3 + no web citation: %d of %d cant_determine (%.1f%%)\n",
            nrow(bad), sum(d$determination == "cant_determine"),
            100 * nrow(bad) / max(sum(d$determination == "cant_determine"), 1)))

by_batch <- bad[, .N, by = batch][order(-N)]
cat("\n--- batches to re-run (>=2 unsearched give-ups) ---\n")
print(by_batch[N >= 2])

fwrite(by_batch[N >= 2, .(batch)], file.path(out, "RERUN-TIER3-EVIDENCE.csv"))
fwrite(bad, file.path(out, "QC-UNSEARCHED-CANT-DETERMINE.csv"))
cat("\nwrote RERUN-TIER3-EVIDENCE.csv and QC-UNSEARCHED-CANT-DETERMINE.csv\n")
cat("NOTE: a `match` or `not_a_nonprofit` with no web citation is usually fine --\n",
    "it was settled at Tier 1/2 and the tier field is just mislabelled. The\n",
    "actionable population is the cant_determine subset above.\n", sep = "")
