#!/usr/bin/env Rscript
# Build refutation packets for the highest-risk matches: cross-state EIN assignments,
# which is where the federated / parent-sponsor trap shows up.
suppressPackageStartupMessages({library(data.table)})

D <- "data-dev"; out <- file.path(D, "no-research")
dir.create(file.path(out, "verify-batches"), showWarnings = FALSE)
dir.create(file.path(out, "verify-out"),     showWarnings = FALSE)

a <- rbindlist(list(fread(file.path(out, "FINDINGS-STAGE1-NO-500.csv"), colClasses = "character"),
                    fread(file.path(out, "FINDINGS-STAGE2-NO-500.csv"), colClasses = "character")))
idx <- as.data.table(readRDS(file.path(D, "BMF-NAME-INDEX.rds")))
bmf <- unique(idx[, .(ein, bmf_name = name, bmf_dba = dba, bmf_city = city,
                      bmf_state = state, bmf_zip = zip5, bmf_care_of = care_of,
                      bmf_sub = subsection, bmf_active = active)], by = "ein")

m <- merge(a[determination == "match" & ein_found != ""], bmf,
           by.x = "ein_found", by.y = "ein", all.x = TRUE, sort = FALSE)
v <- m[bmf_state != sam_state | is.na(bmf_state)]
setorder(v, sam_name)
v[, batch := sprintf("%02d", (seq_len(.N) - 1L) %/% 8L + 1L)]
cat("cross-state matches to verify:", nrow(v), "in", length(unique(v$batch)), "batches\n")

blk <- function(l, x) if (!is.na(x) && nzchar(x)) sprintf("- %s: %s\n", l, x) else ""

for (b in unique(v$batch)) {
  d <- v[batch == b]
  txt <- sprintf("# Refutation batch %s  (%d claimed matches)\n\n", b, nrow(d))
  for (i in seq_len(nrow(d))) {
    x <- d[i]
    txt <- paste0(txt, sprintf("\n## CLAIM %d of %d\n", i, nrow(d)),
      blk("uei", x$uei), blk("no_stage", x$stage),
      blk("SAM legal name", x$sam_name), blk("SAM dba", x$sam_dba),
      blk("SAM city/state/zip", paste(x$sam_city, x$sam_state, x$sam_zip)),
      blk("SAM url", x$sam_url),
      blk("CLAIMED EIN", x$ein_found),
      blk("BMF record for that EIN", sprintf("%s | dba=%s | %s, %s %s | c/o=%s | subsection=%s | active=%s",
          x$bmf_name, x$bmf_dba, x$bmf_city, x$bmf_state, x$bmf_zip,
          x$bmf_care_of, x$bmf_sub, x$bmf_active)),
      blk("stated confidence", x$confidence),
      blk("original sources", x$sources),
      blk("original judgement", x$judgement))
  }
  writeLines(txt, file.path(out, "verify-batches", sprintf("verify-%s.md", b)))
}
fwrite(v[, .(uei, batch, sam_name, sam_state, ein_found, bmf_name, bmf_state)],
       file.path(out, "verify-index.csv"))
