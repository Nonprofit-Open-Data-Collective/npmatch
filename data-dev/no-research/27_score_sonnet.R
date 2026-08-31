#!/usr/bin/env Rscript
# Sonnet 5 vs Opus 5 on the same 167 gate-audit cases, same packets, same brief.
# The only variable is the model.
#
# Gate 1 (decisive): finds >= 7 of the 8 known false settles.
# Gate 2: >= 85% determination agreement with the Opus v2 pass.
# Gate 3: no EIN disagreement where both call `match`.
# Gate 4: tokens/case within ~25% of Opus's 10,805.
suppressPackageStartupMessages({library(data.table)})
out <- "data-dev/no-research"

## fill=TRUE matters: a row written with 10 fields instead of 11 (a dropped
## trailing `notes`) makes fread stop early and silently discard the REST of the
## file. Count the ragged files -- schema compliance is itself a model-quality
## signal worth reporting, not just a parsing nuisance.
## Count RAGGED ROWS directly -- a row with fewer than 11 tab-separated fields.
## Do not infer this from fread warnings: fread warns for several reasons and
## that over-counts. This is a real model-quality signal, so measure it exactly.
RAGGED <- new.env(); RAGGED$rows <- 0L; RAGGED$files <- character(0)
count_ragged <- function(p) {
  ln <- readLines(p, warn = FALSE); ln <- ln[-1]; ln <- ln[nzchar(ln)]
  sum(vapply(strsplit(ln, "\t", fixed = TRUE), length, 0L) != 11L)
}
rd <- function(dir, pat) {
  f <- list.files(file.path(out, dir), pat, full.names = TRUE)
  x <- rbindlist(lapply(f, function(p) {
    nr <- count_ragged(p)
    if (nr > 0) { RAGGED$rows <- RAGGED$rows + nr
                  RAGGED$files <- c(RAGGED$files, sprintf("%s(%d)", basename(p), nr)) }
    d <- tryCatch(fread(p, sep = "\t", colClasses = "character", quote = "",
                        fill = TRUE),
                  error = function(e) {cat("PARSE FAIL:", basename(p), "\n"); NULL})
    if (is.null(d) || !nrow(d)) return(NULL)
    need <- c("uei","ein_found","determination","resolving_tier","confidence","sources")
    for (n in setdiff(need, names(d))) d[[n]] <- ""
    d[, ..need]
  }), fill = TRUE)
  unique(x, by = "uei")
}
op <- rd("audit2-out", "^audit2-[0-9]+[.]tsv$")
op_ragged <- RAGGED$rows; RAGGED$rows <- 0L; RAGGED$files <- character(0)
sn <- rd("sonnet-out", "^sonnet-[0-9]+[.]tsv$")
cat("================ GATE 0 — schema compliance ================\n")
cat(sprintf("Opus   ragged rows (fields != 11): %d of 167\n", op_ragged))
cat(sprintf("Sonnet ragged rows (fields != 11): %d of 167  -> %s\n", RAGGED$rows,
            if (RAGGED$rows == 0) "PASS" else "FAIL (recoverable with fill=TRUE)"))
if (RAGGED$rows) cat("  ", paste(RAGGED$files, collapse = ", "), "\n")
setnames(op, 2:6, paste0("op_", names(op)[2:6]))
setnames(sn, 2:6, paste0("sn_", names(sn)[2:6]))

idx <- fread(file.path(out, "audit-index.csv"), colClasses = "character")
a <- merge(idx[, .(uei, entity_gate, sam_name)], op, by = "uei")
a <- merge(a, sn, by = "uei", all.x = TRUE)
cat("cases: ", nrow(a), " | scored by Sonnet: ",
    sum(!is.na(a$sn_determination) & a$sn_determination != ""), "\n", sep = "")
miss <- a[is.na(sn_determination) | sn_determination == ""]
if (nrow(miss)) { cat("MISSING from Sonnet:", nrow(miss), "\n"); print(miss[, .(uei, sam_name)]) }
a <- a[!is.na(sn_determination) & sn_determination != ""]

TRUTH <- a[op_determination == "match"]
cat("\n================ GATE 1 — the decisive one ================\n")
found <- TRUTH[sn_determination == "match"]
cat(sprintf("known false settles (Opus v2): %d\n", nrow(TRUTH)))
cat(sprintf("Sonnet also calls `match`    : %d  -> %s\n", nrow(found),
            if (nrow(found) >= 7) "PASS" else "FAIL"))
print(TRUTH[, .(org = substr(sam_name, 1, 34), gate = entity_gate,
                opus_ein = op_ein_found, sonnet = sn_determination,
                sonnet_ein = sn_ein_found, sn_conf = sn_confidence)])

cat("\n================ GATE 2 — agreement ================\n")
NOEIN <- c("not_a_nonprofit", "nonprofit_not_in_bmf")
a[, agree := op_determination == sn_determination]
a[, same_verdict := agree | (op_determination %chin% NOEIN & sn_determination %chin% NOEIN)]
cat(sprintf("exact determination agreement : %d/%d = %.1f%%  -> %s\n",
            sum(a$agree), nrow(a), 100*mean(a$agree),
            if (mean(a$agree) >= .85) "PASS" else "FAIL"))
cat(sprintf("same verdict (NO-label swaps forgiven): %.1f%%\n", 100*mean(a$same_verdict)))
cat("\nconfusion (rows = Opus, cols = Sonnet):\n")
print(table(opus = a$op_determination, sonnet = a$sn_determination))

cat("\n================ GATE 3 — EIN agreement ================\n")
both <- a[op_determination == "match" & sn_determination == "match" &
          op_ein_found != "" & sn_ein_found != ""]
cat(sprintf("both call match with an EIN: %d | same EIN: %d -> %s\n",
            nrow(both), sum(both$op_ein_found == both$sn_ein_found),
            if (nrow(both) == 0 || all(both$op_ein_found == both$sn_ein_found))
              "PASS" else "FAIL"))
if (nrow(both) && any(both$op_ein_found != both$sn_ein_found))
  print(both[op_ein_found != sn_ein_found, .(sam_name, op_ein_found, sn_ein_found)])

cat("\n=== false POSITIVES: Sonnet says match where Opus did not ===\n")
fp <- a[sn_determination == "match" & op_determination != "match"]
cat(nrow(fp), "cases\n")
if (nrow(fp)) print(fp[, .(org = substr(sam_name,1,36), opus = op_determination,
                           sonnet_ein = sn_ein_found, conf = sn_confidence)])

cat("\n================ GATE 4 — tokens ================\n")
tp <- file.path(out, "sonnet-telemetry.csv")
if (file.exists(tp)) {
  s <- fread(tp)
  tc <- sum(s$tokens) / sum(s$cases)
  cat(sprintf("Sonnet tokens/case: %s vs Opus 10,805 (%+.0f%%) -> %s\n",
              format(round(tc), big.mark = ","), 100*(tc/10805 - 1),
              if (abs(tc/10805 - 1) <= .25) "PASS" else "CHECK"))
  cat(sprintf("repriced full run: %s agents x %s tok = %.0f M -> $%s at sonnet-5\n",
              format(2393, big.mark=","), format(round(tc*8), big.mark=","),
              2393*tc*8/1e6, format(round(2393*tc*8/1e6*10), big.mark=",")))
} else cat("sonnet-telemetry.csv not written yet\n")

cat("\n=== resolving tier ===\n")
print(table(opus = a$op_resolving_tier, sonnet = a$sn_resolving_tier))
fwrite(a, file.path(out, "SONNET-VS-OPUS.csv"))
