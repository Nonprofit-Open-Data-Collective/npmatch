#!/usr/bin/env Rscript
# Attach a per-UEI token/cost column to the three result tables.
#
# IMPORTANT: the billable unit is the AGENT, not the case. An agent handles 8 cases
# in one context, so a per-case figure is an ALLOCATION (batch tokens / cases in
# batch), not a measurement. Cases the Tier-1 gate settled cost no agent tokens at
# all. Columns are named *_alloc to keep that honest.
suppressPackageStartupMessages({library(data.table)})

D <- "data-dev"; out <- file.path(D, "no-research")

OPUS5_OUT <- 25 / 1e6   # $/token, claude-opus-5 output
tele <- rbindlist(list(fread(file.path(out, "agent-telemetry.csv")),
                       fread(file.path(out, "audit-telemetry.csv"))))
tele[, tok_per_case := tokens / cases]

per <- function(k, b) {
  v <- tele$tok_per_case[tele$kind == k & tele$batch == suppressWarnings(as.integer(b))]
  if (!length(v)) 0 else v[1]
}

add_cols <- function(dt, tok) {
  dt[, agent_tokens_alloc := round(tok)]
  dt[, est_usd_alloc := round(tok * OPUS5_OUT, 4)]
  dt[]
}

## ---- audit table ---------------------------------------------------------
au <- fread(file.path(out, "AUDIT-TIER1-SCORED.csv"), colClasses = "character")
ai <- fread(file.path(out, "audit-index.csv"), colClasses = "character")
drop <- intersect(c("batch","agent_tokens_alloc","est_usd_alloc"), names(au))
if (length(drop)) au[, (drop) := NULL]
au <- merge(au, ai[, .(uei, batch)], by = "uei", all.x = TRUE, sort = FALSE)
au[, agent_tokens_alloc := vapply(batch, function(b) per("audit", b), 0)]
au[, est_usd_alloc := round(agent_tokens_alloc * OPUS5_OUT, 4)]
au[, agent_tokens_alloc := round(agent_tokens_alloc)]
fwrite(au, file.path(out, "AUDIT-TIER1-SCORED.csv"))
cat("audit rows:", nrow(au), " total tokens:", format(sum(au$agent_tokens_alloc), big.mark=","),
    sprintf(" ($%.2f)\n", sum(au$est_usd_alloc)))

## ---- findings tables -----------------------------------------------------
wi <- fread(file.path(out, "web-batch-index.csv"), colClasses = "character")
vi <- fread(file.path(out, "verify-index.csv"), colClasses = "character")

annotate <- function(path) {
  f <- fread(path, colClasses = "character")
  # drop anything a previous run of this script added, so re-running is idempotent
  drop <- intersect(c("web_batch","verify_batch","agent_tokens_alloc","est_usd_alloc"), names(f))
  if (length(drop)) f[, (drop) := NULL]
  f <- merge(f, wi[, .(uei, web_batch = batch)], by = "uei", all.x = TRUE, sort = FALSE)
  f <- merge(f, vi[, .(uei, verify_batch = batch)], by = "uei", all.x = TRUE, sort = FALSE)
  f[, research_tokens_alloc := ifelse(is.na(web_batch), 0,
        vapply(web_batch, function(b) if (is.na(b)) 0 else per("research", b), 0))]
  # verify batches are numbered 101..107 in the telemetry, 01..07 in the index
  f[, verify_tokens_alloc := ifelse(is.na(verify_batch), 0,
        vapply(verify_batch, function(b)
          if (is.na(b)) 0 else per("verify", 100L + as.integer(b)), 0))]
  f[, agent_tokens_alloc := round(research_tokens_alloc + verify_tokens_alloc)]
  f[, est_usd_alloc := round(agent_tokens_alloc * OPUS5_OUT, 4)]
  f[, c("research_tokens_alloc","verify_tokens_alloc") := NULL]
  fwrite(f, path)
  f
}
f1 <- annotate(file.path(out, "FINDINGS-STAGE1-NO-500.csv"))
f2 <- annotate(file.path(out, "FINDINGS-STAGE2-NO-500.csv"))

a <- rbindlist(list(f1, f2))
cat("\n=== allocated cost per case, by how it was resolved ===\n")
print(a[, .(cases = .N,
            mean_tokens = round(mean(agent_tokens_alloc)),
            total_tokens = sum(agent_tokens_alloc),
            total_usd = round(sum(est_usd_alloc), 2)),
        by = .(settled = ifelse(web == "TRUE", "agent-researched", "Tier-1 gate (free)"))])

cat("\n=== cost per RECOVERED MATCH ===\n")
m <- a[determination == "match"]
cat(sprintf("matches: %d | total spend on all 1,000 cases: $%.2f | $%.2f per match found\n",
            nrow(m), sum(a$est_usd_alloc), sum(a$est_usd_alloc) / nrow(m)))
cat(sprintf("stage1: %d matches, $%.2f/match | stage2: %d matches, $%.2f/match\n",
            nrow(f1[determination == "match"]),
            sum(f1$est_usd_alloc)/nrow(f1[determination == "match"]),
            nrow(f2[determination == "match"]),
            sum(f2$est_usd_alloc)/nrow(f2[determination == "match"])))
