#!/usr/bin/env Rscript
# Find `nonprofit_not_in_bmf` rows that may rest on name shape alone.
#
# `nonprofit_not_in_bmf` is a positive claim: this IS a real nonprofit, it is
# merely absent from the BMF. It should rest on evidence the org actually
# operates as one -- a mission statement, a state charity registration, a grant
# listing, board/volunteer language, a donation page. "Foundation", "Institute",
# "Project" and "Org" in a name are NOT evidence; for-profits use all of them.
#
# I introduced this defect myself. A prompt change at batch 1739 told agents to
# prefer `nonprofit_not_in_bmf` over `cant_determine` for plausible-looking orgs
# with no web footprint. That was right for HOAs and fire departments, whose
# CLASS implies nonprofit status, and wrong as a general rule. The rate of
# low-confidence not_in_bmf tripled: 12.6% (18/143) in batches 1652-1738,
# 37.5% (63/168) in 1739-1804. Corrected in the prompt from batch 1805.
#
# The flagged set is for re-adjudication, not automatic reclassification -- many
# will be correct. Class-implied shapes are excluded since those are sound.
suppressPackageStartupMessages({library(data.table)})
out <- "data-dev/no-research"

files <- list.files(file.path(out, "run-out"), "^run-[0-9]+[.]tsv$", full.names = TRUE)
NEED <- c("uei","sam_name","ein_found","determination","confidence","sources","notes")
d <- rbindlist(lapply(files, function(f) {
  x <- tryCatch(fread(f, sep = "\t", colClasses = "character", quote = "", fill = TRUE),
                error = function(e) NULL)
  if (is.null(x) || !nrow(x)) return(NULL)
  for (n in setdiff(NEED, names(x))) x[[n]] <- ""
  x[, ..NEED][, batch := sub("^run-", "", tools::file_path_sans_ext(basename(f)))]
}), fill = TRUE)

## shapes whose CLASS implies nonprofit status -- absence of a footprint is
## expected and not_in_bmf is the right call regardless of confidence
CLASS_OK <- paste(c("FIRE (DEPT|DEPARTMENT|CO|COMPANY)","VOLUNTEER FIRE","RESCUE SQUAD",
                    "AMBULANCE","EMS","WATER (ASSN|ASSOCIATION|DISTRICT|CO)",
                    "HOMEOWNERS","PROPERTY OWNERS","RESIDENTS ASSN","HOA",
                    "CHURCH","MINISTR","PARISH","SYNAGOGUE","MOSQUE","TEMPLE",
                    "VFW","AMERICAN LEGION","GRANGE","PTA","PTO","BOOSTER",
                    "CEMETERY","LIONS CLUB","ROTARY","KIWANIS"), collapse = "|")

d[, class_implied := grepl(CLASS_OK, toupper(sam_name))]
d[, cited_web := grepl("web:", sources, fixed = TRUE)]

thin <- d[determination == "nonprofit_not_in_bmf" &
          confidence == "low" & ein_found == "" & !class_implied]

cat("output files:", length(files), "\n")
cat(sprintf("nonprofit_not_in_bmf rows: %d\n", sum(d$determination == "nonprofit_not_in_bmf")))
cat(sprintf("  low-confidence, no EIN, not a class-implied shape: %d\n", nrow(thin)))

cat("\n--- rate by batch range (the 1739 prompt change) ---\n")
d[, bnum := as.integer(batch)]
rng <- function(lo, hi) {
  s <- d[bnum %between% c(lo, hi) & determination == "nonprofit_not_in_bmf"]
  if (!nrow(s)) return(invisible(NULL))
  cat(sprintf("  %d-%d: %d not_in_bmf, %d low (%.1f%%)\n", lo, hi, nrow(s),
              sum(s$confidence == "low"), 100 * mean(s$confidence == "low")))
}
rng(1652, 1738); rng(1739, 1804); rng(1805, 2589)

fwrite(thin[, .(batch, uei, sam_name, confidence, cited_web, notes)],
       file.path(out, "QC-THIN-NOT-IN-BMF.csv"))
cat("\nwrote QC-THIN-NOT-IN-BMF.csv -- re-adjudicate these rows,\n",
    "do NOT bulk-reclassify them; many will be correct.\n", sep = "")
