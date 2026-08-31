#!/usr/bin/env Rscript
# Verify that every output file carries exactly the UEIs of its source batch.
#
# This catches a failure class that NOTHING else does. Row counts, field counts
# and taxonomy checks all pass on a row whose `uei` is simply wrong -- and a
# wrong uei silently detaches the research from the case it was done for, while
# leaving the real case with no result at all. run-0136 carried DPZ7X229HKA5,
# a UEI that appears nowhere in the 40,860-case frame, in place of DQ5DL8BVJHN7.
suppressPackageStartupMessages({library(data.table)})
out <- "data-dev/no-research"

idx <- fread(file.path(out, "run-batch-index.csv"), colClasses = "character")
setnames(idx, tolower(names(idx)))
src <- idx[, .(want = list(sort(uei))), by = batch]

files <- list.files(file.path(out, "run-out"), "^run-[0-9]+[.]tsv$", full.names = TRUE)
cat("output files:", length(files), "\n")

bad <- rbindlist(lapply(files, function(f) {
  b <- sub("^run-", "", tools::file_path_sans_ext(basename(f)))
  w <- src[batch == b]
  if (!nrow(w)) return(data.table(batch = b, issue = "no such batch in index",
                                  detail = ""))
  got <- tryCatch({
    x <- fread(f, sep = "\t", colClasses = "character", quote = "", fill = TRUE)
    sort(x[[1]][nzchar(x[[1]])])
  }, error = function(e) character(0))
  want <- w$want[[1]]
  if (identical(got, want)) return(NULL)
  data.table(batch = b, issue = "uei set mismatch",
             detail = paste0("missing=", paste(setdiff(want, got), collapse = ","),
                             " ; extra=", paste(setdiff(got, want), collapse = ",")))
}), fill = TRUE)

if (!nrow(bad)) { cat("all files carry exactly their source UEIs\n"); quit(status = 0) }
cat("\n!! ", nrow(bad), " files with a UEI-set mismatch\n", sep = "")
print(bad)

## an "extra" uei that is nowhere in the frame is an invented identifier
allu <- unique(idx$uei)
ext <- unlist(lapply(strsplit(sub(".*extra=", "", bad$detail), ","), trimws))
ext <- ext[nzchar(ext)]
inv <- setdiff(ext, allu)
cat("\ninvented UEIs (absent from the whole frame):", length(inv), "\n")
if (length(inv)) print(inv)
fwrite(bad, file.path(out, "QC-UEI-MISMATCH.csv"))
cat("\nwrote QC-UEI-MISMATCH.csv -- re-run these batches\n")
