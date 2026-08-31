#!/usr/bin/env Rscript
# Fold the full-run agent TSVs back onto FULL-SEED and emit the deliverables.
#
# This is the production sibling of 06_merge_findings.R, which merged the
# 1,000-row pilot from `agent-out/batch-*.tsv`. This one reads the 2,589-batch
# production run from `run-out/run-*.tsv` and merges onto FULL-SEED.csv.
# Do not point 06 at run-out/ -- its seed and its expected counts are the pilot's.
suppressPackageStartupMessages({library(data.table)})

D <- "data-dev"; out <- file.path(D, "no-research")
seed  <- fread(file.path(out, "FULL-SEED.csv"),       colClasses = "character")
queue <- fread(file.path(out, "run-batch-index.csv"), colClasses = "character")

tsv <- list.files(file.path(out, "run-out"), "^run-[0-9]+[.]tsv$", full.names = TRUE)
cat("run files:", length(tsv), " (expect 2589)\n")

## A row written with fewer than 11 tab-separated fields (usually a dropped
## trailing `notes`) makes a strict fread STOP EARLY and silently discard the
## rest of that file -- benchmarking lost 21 cases that way without saying so.
## Always fill=TRUE, and count the ragged rows out loud.
## COUNT TABS, NOT strsplit() PIECES. strsplit("a\tb\t", "\t") returns 2, not 3 --
## it drops trailing empty strings. The brief tells agents to write `notes` even
## when empty, so a legitimate 11-field row ends in a tab and strsplit sees 10.
## 06_merge_findings.R has this bug and over-reports ragged rows: on this corpus
## it claimed 3,556 ragged rows across 1,040 files, and the true count is 0.
## awk's NF counts correctly, which is why the agents' own `awk NF` checks passed.
NFIELD <- 11L
count_ragged <- function(p) {
  ln <- readLines(p, warn = FALSE)
  if (length(ln) < 2) return(0L)
  ln <- ln[-1]; ln <- ln[nzchar(ln)]
  nf <- vapply(gregexpr("\t", ln, fixed = TRUE),
               function(m) if (m[1] == -1L) 1L else length(m) + 1L, 0L)
  sum(nf != NFIELD)
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
cat("rows read:", nrow(res), " unique UEIs:", uniqueN(res$uei), "\n")
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
cat("rows total:", nrow(a), "\n")
cat("queued for research:", nrow(queue), " researched:", sum(a$researched), "\n")
miss <- setdiff(queue$uei, res$uei)
cat("MISSING agent rows:", length(miss), "\n")
if (length(miss)) print(queue[uei %chin% miss][, .N, by = .(batch, stage, web_reason)])
extra <- setdiff(res$uei, queue$uei)
cat("UEIs written but NOT queued (agent invented or mistyped):", length(extra), "\n")
if (length(extra)) print(head(res[uei %chin% extra, .(uei, batch_file)], 25))
cat("blank determination:", sum(a$researched & a$determination == ""), "\n")
bad <- a[researched == TRUE & !determination %chin% TAX]
cat("off-taxonomy determination:", nrow(bad), "\n"); if (nrow(bad)) print(unique(bad$determination))
badein <- a[ein_found != "" & !grepl("^[0-9]{2}-?[0-9]{7}$", ein_found)]
cat("malformed EIN:", nrow(badein), "\n"); if (nrow(badein)) print(head(badein[, .(uei, ein_found)], 25))
a[ein_found != "", ein_found := sub("^([0-9]{2})([0-9]{7})$", "\\1-\\2", ein_found)]
cat("blank confidence:", sum(a$researched & a$confidence == ""),
    " blank sources:",   sum(a$researched & a$sources   == ""), "\n")
badtier <- a[researched == TRUE & resolving_tier == "tier3" & !grepl("web:", sources, fixed = TRUE)]
cat("tier3 rows with no web: citation:", nrow(badtier), "\n")

## ---- a match must resolve to an EIN the reference actually contains ------
## `match` means the crosswalk can use this EIN. An EIN that is real but absent
## from the pinned unified BMF is by definition `nonprofit_not_in_bmf` -- the
## taxonomy says to record the EIN there anyway. Reclassify deterministically
## rather than leaving a match the crosswalk cannot join.
idx <- as.data.table(readRDS(file.path(D, "BMF-NAME-INDEX.rds")))
bad_match <- a$determination == "match" & a$ein_found != "" & !(a$ein_found %chin% idx$ein)
cat("matches whose EIN is absent from the unified BMF:", sum(bad_match), "\n")
if (any(bad_match)) {
  fwrite(a[bad_match, .(uei, sam_name, ein_found, confidence, notes)],
         file.path(out, "QC-MATCH-EIN-NOT-IN-BMF.csv"))
  a[bad_match, `:=`(
    determination = "nonprofit_not_in_bmf",
    notes = paste0(notes, " ;; RECLASSIFIED: agent called this a match but ",
                   ein_found, " is not in the pinned unified BMF, so it cannot be ",
                   "a crosswalk match. EIN retained as a real filer outside the BMF."))]
}

## ---- federated_parent flag ----------------------------------------------
## Federated networks legitimately resolve many distinct UEIs to ONE parent EIN:
## Salvation Army corps -> territorial HQ, VOA and National Church Residences
## housing properties, Good Samaritan facilities, charter-school networks,
## nonprofit-conversion LLC stacks. Those rows are correct and are emitted as
## they stand -- but a many-to-one EIN behaves differently downstream from a
## 1:1 match, so it is flagged rather than hidden. This does NOT change
## `determination`.
FED_MIN <- 8L   # threshold; check it against the fan-out table printed below
m   <- a[determination == "match" & ein_found != ""]
cnt <- m[, .(n_uei = uniqueN(uei)), by = ein_found][order(-n_uei)]
cat("\n=== EINs claimed by many distinct UEIs (top 25) ===\n")
print(head(cnt, 25))
cat("\nEINs by fan-out size:\n"); print(table(cut(cnt$n_uei, c(0,1,2,4,7,15,50,Inf))))
fed <- cnt[n_uei >= FED_MIN, ein_found]
a[, federated_parent := determination == "match" & ein_found %chin% fed]
a[, federated_n_uei := 0L]
a[federated_parent == TRUE,
  federated_n_uei := cnt$n_uei[match(ein_found, cnt$ein_found)]]
cat("\nfederated_parent rows (EIN claimed by >=", FED_MIN, "UEIs):", sum(a$federated_parent),
    "across", length(fed), "parent EINs\n")

## ---- deliverables --------------------------------------------------------
keep <- c("uei","run","stage","no_origin","sam_name","sam_dba","sam_city","sam_state","sam_zip",
          "sam_url","sam_entity_structure","sam_state_incorp","sam_bus_type","sam_poc_title",
          "entity_gate","web","web_reason","rejected_ein","llm_confidence","llm_reason",
          "n_candidates","candidates","bmf_lookup",
          "ein_found","determination","resolving_tier","confidence","sources","judgement","notes",
          "federated_parent","federated_n_uei","researched")
keep <- intersect(keep, names(a))
f1 <- a[stage == "stage1", ..keep]; f2 <- a[stage == "stage2", ..keep]
fwrite(f1, file.path(out, "FINDINGS-STAGE1-NO-FULL.csv"))
fwrite(f2, file.path(out, "FINDINGS-STAGE2-NO-FULL.csv"))
cat("\nwrote FINDINGS-STAGE1-NO-FULL.csv (", nrow(f1), " rows) and ",
    "FINDINGS-STAGE2-NO-FULL.csv (", nrow(f2), " rows)\n", sep = "")

r <- a[researched == TRUE]
cat("\n=== determination x stage (researched only) ===\n"); print(table(r$determination, r$stage))
cat("\n=== confidence x stage ===\n");                      print(table(r$confidence, r$stage))
cat("\n=== resolving tier x stage ===\n");                  print(table(r$resolving_tier, r$stage))
cat("\n=== EIN recovered ===\n");                           print(table(r$ein_found != "", r$stage))
cat("\n=== determination x web_reason stratum ===\n");      print(table(r$web_reason, r$determination))
cat("\n=== recall recovery (determination == match) ===\n")
print(r[determination == "match", .N, by = .(stage, run)][order(stage, run)])
