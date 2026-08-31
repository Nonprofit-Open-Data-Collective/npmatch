#!/usr/bin/env Rscript
# Score gate audit v2 (cached ProPublica + efile index) and compare to v1.
# Same 167 cases, same blind packets; v2 adds the two new assets and removes 429s.
suppressPackageStartupMessages({library(data.table)})

out <- "data-dev/no-research"
idx <- fread(file.path(out, "audit-index.csv"), colClasses = "character")
v1  <- fread(file.path(out, "AUDIT-TIER1-SCORED.csv"), colClasses = "character")

f <- list.files(file.path(out, "audit2-out"), "^audit2-[0-9]+[.]tsv$", full.names = TRUE)
v2 <- rbindlist(lapply(f, function(p) {
  x <- tryCatch(fread(p, sep="\t", colClasses="character", quote=""),
                error=function(e){cat("PARSE FAIL:", basename(p), "\n"); NULL})
  if (is.null(x) || !nrow(x)) return(NULL)
  need <- c("uei","ein_found","determination","resolving_tier","confidence","sources","judgement","notes")
  for (n in setdiff(need, names(x))) x[[n]] <- ""
  x[, ..need]
}), fill = TRUE)
v2 <- unique(v2, by = "uei")
setnames(v2, c("ein_found","determination","confidence","resolving_tier","sources"),
         c("v2_ein","v2_det","v2_conf","v2_tier","v2_sources"))

a <- merge(idx[, .(uei, entity_gate, gate_determination, sam_name)],
           v2, by = "uei", all.x = TRUE)
a <- merge(a, v1[, .(uei, v1_det = audit_determination, v1_ein = audit_ein)],
           by = "uei", all.x = TRUE)
cat("cases:", nrow(a), " scored in v2:", sum(!is.na(a$v2_det) & a$v2_det != ""), "\n")
a <- a[!is.na(v2_det) & v2_det != ""]

NOEIN <- c("not_a_nonprofit","nonprofit_not_in_bmf")
n <- nrow(a)
k1 <- sum(a$v1_det == "match"); k2 <- sum(a$v2_det == "match")
ci <- function(k) binom.test(k, n)$conf.int

cat("\n=== FALSE-SETTLE RATE: v1 vs v2 (same 167 cases) ===\n")
cat(sprintf("v1 (live ProPublica, 75 cases lost to 429): %d/%d = %.1f%%  (95%% CI %.1f-%.1f%%)\n",
            k1, n, 100*k1/n, 100*ci(k1)[1], 100*ci(k1)[2]))
cat(sprintf("v2 (cached Tier 2 + efile index)          : %d/%d = %.1f%%  (95%% CI %.1f-%.1f%%)\n",
            k2, n, 100*k2/n, 100*ci(k2)[1], 100*ci(k2)[2]))

cat("\n=== agreement between the two independent passes ===\n")
a[, agree := v1_det == v2_det]
cat(sprintf("exact determination agreement: %d/%d = %.1f%%\n", sum(a$agree), n, 100*mean(a$agree)))
a[, same_verdict := (v1_det %chin% NOEIN & v2_det %chin% NOEIN) | agree]
cat(sprintf("same verdict (NO-label swaps forgiven)   : %.1f%%\n", 100*mean(a$same_verdict)))
both <- a[v1_det == "match" & v2_det == "match"]
cat(sprintf("both called match: %d | same EIN: %d\n", nrow(both), sum(both$v1_ein == both$v2_ein)))

cat("\n=== matches found by each pass ===\n")
print(a[v1_det == "match" | v2_det == "match",
        .(org = substr(sam_name,1,36), gate = entity_gate,
          v1 = v1_det, v2 = v2_det, v1_ein, v2_ein, v2_conf)][order(org)])

cat("\n=== v2-only finds (missed by v1) ===\n")
n2 <- a[v2_det == "match" & v1_det != "match"]
cat(nrow(n2), "cases\n")
if (nrow(n2)) print(n2[, .(org = substr(sam_name,1,40), gate = entity_gate,
                           ein = v2_ein, conf = v2_conf, tier = v2_tier)])

cat("\n=== v1-only finds (not reproduced by v2) ===\n")
n1 <- a[v1_det == "match" & v2_det != "match"]
cat(nrow(n1), "cases\n")
if (nrow(n1)) print(n1[, .(org = substr(sam_name,1,40), v1_ein, v2_says = v2_det, conf = v2_conf)])

cat("\n=== which tier settled v2 (was: tier2 unusable for 45% of v1) ===\n")
print(a[, .N, by = v2_tier][order(-N)])
cat("cases citing a 429 in v2:", sum(grepl("429", a$v2_sources)), "\n")
cat("cases citing the efile index in v2:",
    sum(grepl("efile", a$v2_sources, ignore.case = TRUE)), "\n")
cat("cases citing the ProPublica cache in v2:",
    sum(grepl("propublica_cache|propublica cache", a$v2_sources, ignore.case = TRUE)), "\n")

fwrite(a, file.path(out, "AUDIT-V1-VS-V2.csv"))
