#!/usr/bin/env Rscript
# Fold the agent TSVs back onto the seeded findings and emit the two deliverables.
suppressPackageStartupMessages({library(data.table)})

D <- "data-dev"; out <- file.path(D, "no-research")
seed <- fread(file.path(out, "FINDINGS-SEED.csv"), colClasses = "character")

tsv <- list.files(file.path(out, "agent-out"), "^batch-[0-9]+[.]tsv$", full.names = TRUE)
cat("agent files:", length(tsv), "\n")

## A row written with fewer than 11 tab-separated fields (usually a dropped
## trailing `notes`) makes a strict fread STOP EARLY and silently discard the
## rest of that file. Benchmarking measured 11 such rows in 167 from Sonnet and
## 0 from Opus, and a strict reader lost 21 cases without saying so.
## So: always fill=TRUE, and count the ragged rows out loud.
NFIELD <- 11L
count_ragged <- function(p) {
  ln <- readLines(p, warn = FALSE)
  if (length(ln) < 2) return(0L)
  ln <- ln[-1]; ln <- ln[nzchar(ln)]
  sum(vapply(strsplit(ln, "\t", fixed = TRUE), length, 0L) != NFIELD)
}
ragged <- vapply(tsv, count_ragged, 0L)
if (sum(ragged) > 0) {
  cat("\n!! RAGGED ROWS (fields != ", NFIELD, "): ", sum(ragged), " across ",
      sum(ragged > 0), " files\n", sep = "")
  print(data.table(file = basename(tsv)[ragged > 0], ragged_rows = ragged[ragged > 0]))
  cat("   Recovered with fill=TRUE; the short field is padded empty. Review those\n",
      "   rows if the missing field was not `notes`.\n", sep = "")
}

res <- rbindlist(lapply(tsv, function(f) {
  x <- tryCatch(fread(f, sep = "\t", colClasses = "character", quote = "", fill = TRUE),
                error = function(e) {cat("PARSE FAIL:", basename(f), conditionMessage(e), "\n"); NULL})
  if (is.null(x) || !nrow(x)) return(NULL)
  need <- c("uei","ein_found","determination","resolving_tier","confidence","sources","judgement","notes")
  for (n in setdiff(need, names(x))) x[[n]] <- ""
  x[, ..need][, batch_file := basename(f)]
}), fill = TRUE)
res <- unique(res, by = "uei")

## ---- overwrite the seeded rows the agents researched --------------------
setnames(res, setdiff(names(res), c("uei","batch_file")),
         paste0("w_", setdiff(names(res), c("uei","batch_file"))))
a <- merge(seed, res, by = "uei", all.x = TRUE, sort = FALSE)
for (f in c("ein_found","determination","resolving_tier","confidence","sources","judgement","notes")) {
  w <- paste0("w_", f)
  a[!is.na(get(w)) & get(w) != "", (f) := get(w)]
}
a[, researched := !is.na(batch_file)]

## ---- validation ----------------------------------------------------------
TAX <- c("match","not_a_nonprofit","nonprofit_not_in_bmf","cant_determine")
cat("\n--- validation ---\n")
cat("rows total:", nrow(a), " (expect 1000)\n")
cat("web cases expected:", sum(a$web == "TRUE"), " researched:", sum(a$researched), "\n")
miss <- a[web == "TRUE" & !researched]
cat("MISSING agent rows:", nrow(miss), "\n")
if (nrow(miss)) print(miss[, .(uei, .src, web_reason)])
cat("blank determination:", sum(a$determination == ""), "\n")
bad <- a[!determination %chin% TAX]
cat("off-taxonomy determination:", nrow(bad), "\n"); if (nrow(bad)) print(unique(bad$determination))
badein <- a[ein_found != "" & !grepl("^[0-9]{2}-?[0-9]{7}$", ein_found)]
cat("malformed EIN:", nrow(badein), "\n"); if (nrow(badein)) print(badein[, .(uei, ein_found)])
a[ein_found != "", ein_found := sub("^([0-9]{2})([0-9]{7})$", "\\1-\\2", ein_found)]
cat("blank confidence:", sum(a$confidence == ""), " blank sources:", sum(a$sources == ""), "\n")

## ---- a match must resolve to an EIN the reference actually contains ------
## `match` means the crosswalk can use this EIN. An EIN that is real but absent
## from the pinned unified BMF is by definition `nonprofit_not_in_bmf` -- the
## taxonomy says to record the EIN there anyway. Reclassify deterministically
## rather than leaving a match the crosswalk cannot join.
idx <- as.data.table(readRDS(file.path(D, "BMF-NAME-INDEX.rds")))
bad_match <- a$determination == "match" & a$ein_found != "" & !(a$ein_found %chin% idx$ein)
cat("matches whose EIN is absent from the unified BMF:", sum(bad_match), "\n")
if (any(bad_match)) {
  print(a[bad_match, .(uei, sam_name, ein_found, confidence)])
  a[bad_match, `:=`(
    determination = "nonprofit_not_in_bmf",
    notes = paste0(notes, " ;; RECLASSIFIED: agent called this a match but ",
                   ein_found, " is not in the pinned unified BMF, so it cannot be ",
                   "a crosswalk match. EIN retained as a real filer outside the BMF."))]
}

## ---- deliverables --------------------------------------------------------
keep <- c("uei","run","stage","no_origin","sam_name","sam_dba","sam_city","sam_state","sam_zip",
          "sam_url","sam_entity_structure","sam_bus_type","entity_gate","web","web_reason",
          "rejected_ein","llm_confidence","llm_reason","n_candidates","candidates","bmf_lookup",
          "ein_found","determination","resolving_tier","confidence","sources","judgement","notes")
keep <- intersect(keep, names(a))
f1 <- a[.src == "stage1", ..keep]; f2 <- a[.src == "stage2", ..keep]
fwrite(f1, file.path(out, "FINDINGS-STAGE1-NO-500.csv"))
fwrite(f2, file.path(out, "FINDINGS-STAGE2-NO-500.csv"))

cat("\n=== determination x stage ===\n");        print(table(a$determination, a$.src))
cat("\n=== confidence x stage ===\n");           print(table(a$confidence, a$.src))
cat("\n=== resolving tier x stage ===\n");       print(table(a$resolving_tier, a$.src))
cat("\n=== EIN recovered ===\n");                print(table(a$ein_found != "", a$.src))
cat("\n=== recall recovery (determination == match) ===\n")
print(a[determination == "match", .N, by = .(.src, run)])
