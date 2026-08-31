#!/usr/bin/env Rscript
# Parish schools resolve to their PARISH's EIN, not their DIOCESE's.
#
# A Catholic parish elementary school is usually not separately incorporated:
# the parish is the legal entity behind the SAM registration and holds the
# employer EIN. Matching the school to that parish is a legitimate federated
# match, the same shape as a Salvation Army corps resolving to its territorial
# HQ. Reaching past the parish to the diocesan group-ruling EIN is not -- that
# EIN covers hundreds of unrelated subordinates and says nothing about which
# one the registrant is.
#
# This flags school/academy `match` rows whose recovered EIN belongs to a BMF
# record named as a diocese or archdiocese. Those are the errors. Rows whose
# EIN resolves to a named parish are correct and are left alone.
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

bmf <- fread(file.path(out, "BMF-GREP.tsv"), sep = "\t", header = FALSE,
             colClasses = "character", quote = "", fill = TRUE)
setnames(bmf, 1:2, c("ein","bmf_name"))
bmf <- unique(bmf[, .(ein, bmf_name)])

school <- d[determination == "match" & ein_found != "" &
            grepl("SCHOOL|ACADEMY|HIGH", toupper(sam_name))]
school <- merge(school, bmf, by.x = "ein_found", by.y = "ein", all.x = TRUE)

## the parish/diocese reasoning is what puts a row in scope at all
ctx <- grepl("parish|diocese|diocesan|archdiocese|group exemption",
             paste(school$notes, school$sources), ignore.case = TRUE)
## a diocese-level BMF name is the defect; a named parish is fine
dio <- grepl("^(THE )?(ROMAN CATHOLIC )?(ARCH)?DIOCESE|CATHOLIC (BISHOP|CHARITIES)",
             toupper(school$bmf_name))

cat("output files:", length(files), "\n")
cat(sprintf("school/academy match rows with an EIN: %d\n", nrow(school)))
cat(sprintf("  reached via parish/diocesan reasoning: %d\n", sum(ctx)))
cat(sprintf("  EIN resolves to a DIOCESE-level BMF name: %d  <- errors\n", sum(dio, na.rm = TRUE)))
cat(sprintf("  EIN not found in BMF-GREP at all: %d\n", sum(is.na(school$bmf_name))))

bad <- school[which(dio | is.na(bmf_name))]
if (nrow(bad)) {
  fwrite(bad[, .(batch, uei, sam_name, ein_found, bmf_name, confidence, notes)],
         file.path(out, "QC-PARISH-SCHOOL-EINS.csv"))
  cat("\nwrote QC-PARISH-SCHOOL-EINS.csv -- re-adjudicate these rows.\n")
} else {
  cat("\nno diocese-level EINs attached to school rows; nothing to re-adjudicate.\n")
}
