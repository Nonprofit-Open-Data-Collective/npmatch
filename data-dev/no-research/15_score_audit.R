#!/usr/bin/env Rscript
# Score the Tier-1 gate: blind re-research vs what the gate decided.
#
# The distinction that matters is NOT plain label agreement. Both `not_a_nonprofit`
# and `nonprofit_not_in_bmf` mean "no BMF EIN to be had" -- swapping between them
# costs no recall. A FALSE SETTLE is the gate closing a case that a researcher
# then resolves to a real EIN.
suppressPackageStartupMessages({library(data.table)})

D <- "data-dev"; out <- file.path(D, "no-research")
idx <- fread(file.path(out, "audit-index.csv"), colClasses = "character")

f <- list.files(file.path(out, "audit-out"), "^audit-[0-9]+[.]tsv$", full.names = TRUE)
a <- rbindlist(lapply(f, function(p) {
  x <- tryCatch(fread(p, sep = "\t", colClasses = "character", quote = ""),
                error = function(e) {cat("PARSE FAIL:", basename(p), "\n"); NULL})
  if (is.null(x) || !nrow(x)) return(NULL)
  need <- c("uei","ein_found","determination","resolving_tier","confidence","sources","judgement","notes")
  for (n in setdiff(need, names(x))) x[[n]] <- ""
  x[, ..need]
}), fill = TRUE)
a <- unique(a, by = "uei")
setnames(a, c("determination","confidence","ein_found"),
         c("audit_determination","audit_confidence","audit_ein"))

m <- merge(idx, a, by = "uei", all.x = TRUE)
cat("audited:", nrow(idx), " scored:", sum(!is.na(m$audit_determination)), "\n")
m <- m[!is.na(audit_determination) & audit_determination != ""]

NOEIN <- c("not_a_nonprofit", "nonprofit_not_in_bmf")
m[, outcome := fcase(
  audit_determination == "match",                                   "FALSE SETTLE (real EIN found)",
  audit_determination == "cant_determine",                          "unresolved on re-research",
  audit_determination == gate_determination,                        "exact agreement",
  audit_determination %chin% NOEIN & gate_determination %chin% NOEIN, "same verdict, different NO label",
  default = "other")]

cat("\n=== OUTCOME ===\n")
o <- m[, .N, by = outcome][order(-N)]
o[, pct := sprintf("%.1f%%", 100 * N / nrow(m))]
print(o)

fs <- m[audit_determination == "match"]
n <- nrow(m); k <- nrow(fs)
ci <- binom.test(k, n)$conf.int
cat(sprintf("\n=== FALSE-SETTLE RATE: %d/%d = %.1f%%  (95%% CI %.1f%% - %.1f%%) ===\n",
            k, n, 100*k/n, 100*ci[1], 100*ci[2]))

cat("\n=== by entity gate ===\n")
g <- m[, .(audited = .N,
           false_settle = sum(audit_determination == "match"),
           relabel = sum(audit_determination %chin% NOEIN & gate_determination %chin% NOEIN &
                         audit_determination != gate_determination),
           unresolved = sum(audit_determination == "cant_determine")), by = entity_gate]
g[, false_settle_pct := sprintf("%.1f%%", 100 * false_settle / audited)]
print(g[order(-false_settle)])

if (nrow(fs)) {
  cat("\n=== the false settles ===\n")
  print(fs[, .(entity_gate, sam_name = substr(sam_name, 1, 44),
               gate_said = gate_determination, ein = audit_ein, conf = audit_confidence)])
}

cat("\n=== projection to the full pool ===\n")
p1 <- nrow(fread(file.path(out, "POOL-STAGE1-NO.csv")))
p2 <- nrow(fread(file.path(out, "POOL-STAGE2-NO.csv")))
sd_ <- fread(file.path(out, "FINDINGS-SEED.csv"), colClasses = "character")
# the sample is 50/50 stage1/stage2 but the pool is ~84/16 -- weight by stage,
# never by the pooled sample mean.
g1 <- sd_[.src == "stage1", mean(web == "FALSE")]
g2 <- sd_[.src == "stage2", mean(web == "FALSE")]
gated_pool <- p1 * g1 + p2 * g2
cat(sprintf("gate settles: stage1 %.1f%% of %s, stage2 %.1f%% of %s -> %s cases (%.0f%% of pool)\n",
            100*g1, format(p1, big.mark = ","), 100*g2, format(p2, big.mark = ","),
            format(round(gated_pool), big.mark = ","), 100*gated_pool/(p1+p2)))
cat(sprintf("implied matches lost inside the gate: ~%s  (95%% CI %s - %s)\n",
            format(round(gated_pool * k/n), big.mark = ","),
            format(round(gated_pool * ci[1]), big.mark = ","),
            format(round(gated_pool * ci[2]), big.mark = ",")))

cat("\n=== ProPublica availability during the audit ===\n")
cat("cases with a 429 recorded:", sum(grepl("429", m$sources)), "of", nrow(m), "\n")

fwrite(m[, .(uei, entity_gate, sam_name, gate_determination, gate_confidence,
             audit_determination, audit_ein, audit_confidence, outcome,
             resolving_tier, sources, judgement, notes)],
       file.path(out, "AUDIT-TIER1-SCORED.csv"))
