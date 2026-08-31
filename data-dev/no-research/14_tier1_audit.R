#!/usr/bin/env Rscript
# Audit the Tier-1 gate: send a stratified sample of cases the gate settled WITHOUT
# a web check through the full research pipeline, and measure how often it was wrong.
suppressPackageStartupMessages({library(data.table)})
set.seed(20260826)

D <- "data-dev"; out <- file.path(D, "no-research")
dir.create(file.path(out, "audit-batches"), showWarnings = FALSE)
dir.create(file.path(out, "audit-out"),     showWarnings = FALSE)

a <- fread(file.path(out, "FINDINGS-SEED.csv"), colClasses = "character")
g <- a[web == "FALSE"]                       # settled by code, never web-checked
cat("Tier-1-settled cases available:", nrow(g), "\n")
print(table(g$entity_gate, g$.src))

TARGET <- 160L
# proportional, with a floor of 16 so the small gates are actually measurable
sz <- g[, .N, by = entity_gate]
sz[, take := pmax(16L, round(TARGET * N / sum(N)))]
sz[, take := pmin(take, N)]
s <- rbindlist(lapply(seq_len(nrow(sz)), function(i)
  g[entity_gate == sz$entity_gate[i]][sample(.N, sz$take[i])]))
s <- s[sample(.N)]
cat("\naudit sample:", nrow(s), "\n"); print(table(s$entity_gate))

s[, batch := sprintf("%02d", (seq_len(.N) - 1L) %/% 8L + 1L)]
fwrite(s[, .(uei, batch, entity_gate, gate_determination = determination,
             gate_confidence = confidence, sam_name)],
       file.path(out, "audit-index.csv"))

blk <- function(l, x) if (!is.na(x) && nzchar(x)) sprintf("- %s: %s\n", l, x) else ""
for (b in unique(s$batch)) {
  d <- s[batch == b]
  txt <- sprintf("# Tier-1 audit batch %s  (%d cases)\n\n", b, nrow(d))
  for (i in seq_len(nrow(d))) {
    x <- d[i]
    txt <- paste0(txt, sprintf("\n## CASE %d of %d\n", i, nrow(d)),
      blk("uei", x$uei), blk("run", x$run), blk("no_stage", x$stage),
      blk("SAM legal name", x$sam_name), blk("SAM dba", x$sam_dba),
      blk("SAM address", paste(na.omit(c(x$sam_street1, x$sam_street2)), collapse = " ")),
      blk("SAM city/state/zip", paste(x$sam_city, x$sam_state, x$sam_zip)),
      blk("SAM mailing", paste(na.omit(c(x$sam_mail_street, x$sam_mail_city,
                                         x$sam_mail_state, x$sam_mail_zip)), collapse = " ")),
      blk("SAM url", x$sam_url),
      blk("SAM entity structure", x$sam_entity_structure),
      blk("SAM state of incorporation", x$sam_state_incorp),
      blk("SAM business types", x$sam_bus_type),
      blk("SAM primary NAICS", x$sam_naics),
      blk("SAM contact", paste(na.omit(c(x$sam_poc_first, x$sam_poc_last, x$sam_poc_title)), collapse = " ")),
      blk("Tier-1 full-BMF name lookup", x$bmf_lookup),
      blk("Stage-2: candidates the LLM saw", x$candidates),
      blk("Stage-2: LLM rejection reason", x$llm_reason))
  }
  writeLines(txt, file.path(out, "audit-batches", sprintf("audit-%s.md", b)))
}
cat("batches:", length(unique(s$batch)), "\n")
