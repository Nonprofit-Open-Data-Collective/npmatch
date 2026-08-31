#!/usr/bin/env Rscript
# Final case-count plan, computed from the ACTUAL refreshed pipeline:
# the live escape hatch, the live efile index, and the post-refresh match rates.
suppressPackageStartupMessages({library(data.table)})
out <- "data-dev/no-research"

seed <- fread(file.path(out, "FINDINGS-SEED.csv"), colClasses = "character")
f1   <- fread(file.path(out, "FINDINGS-STAGE1-NO-500.csv"), colClasses = "character")
f2   <- fread(file.path(out, "FINDINGS-STAGE2-NO-500.csv"), colClasses = "character")
tele <- fread(file.path(out, "agent-telemetry.csv"))[kind == "research"]

POOL <- data.table(stage = c("stage1","stage2"), cases = c(34335L, 6525L))
N <- 8L; CONC <- 20L
TOK_A <- mean(tele$tokens); SEC_A <- mean(tele$secs)

## ---- measured shares, from the live seed --------------------------------
sh <- seed[, .(sampled = .N, web = sum(web == "TRUE"), gated = sum(web == "FALSE")),
           by = .(stage = .src)]
sh[, web_share := web / sampled]
POOL <- merge(POOL, sh[, .(stage, web_share)], by = "stage")
POOL[, to_research := round(cases * web_share)]
POOL[, settled_free := cases - to_research]

cat("=== 1. TOTAL CASES ===\n")
print(POOL[, .(stage, cases)]); cat("TOTAL:", format(sum(POOL$cases), big.mark=","), "\n")

cat("\n=== 2. SETTLED BY CODE (never reaches an agent) ===\n")
g <- seed[web == "FALSE", .N, by = .(stage = .src, entity_gate)]
g <- dcast(g, entity_gate ~ stage, value.var = "N", fill = 0)
g[, pooled := round(stage1 * POOL[stage=="stage1"]$cases / 500 +
                    stage2 * POOL[stage=="stage2"]$cases / 500)]
print(g[order(-pooled)])
cat("TOTAL settled free:", format(sum(POOL$settled_free), big.mark=","),
    sprintf(" (%.0f%% of pool)\n", 100*sum(POOL$settled_free)/sum(POOL$cases)))

cat("\n=== 3. SENT TO RESEARCH, by why ===\n")
r <- seed[web == "TRUE", .N, by = .(stage = .src, web_reason)]
r <- dcast(r, web_reason ~ stage, value.var = "N", fill = 0)
r[, pooled := round(stage1 * POOL[stage=="stage1"]$cases / 500 +
                    stage2 * POOL[stage=="stage2"]$cases / 500)]
print(r[order(-pooled)])
TR <- sum(POOL$to_research)
cat("TOTAL to research:", format(TR, big.mark=","),
    sprintf(" (%.0f%% of pool)\n", 100*TR/sum(POOL$cases)))
cat("  of which un-gated only because of the escape hatch (efile domain / 2L):",
    format(r[web_reason %chin% c("efile_990_filer_shares_this_website",
                                 "sam_2L_flag_unreliable")][, sum(pooled)], big.mark=","), "\n")

cat("\n=== 4. TOKENS AND COST ===\n")
AG <- ceiling(TR / N); TOK <- AG * TOK_A
cat(sprintf("agents (8 cases each) : %s\n", format(AG, big.mark=",")))
cat(sprintf("tokens/agent measured : %s   tokens/case: %s\n",
            format(round(TOK_A), big.mark=","), format(round(TOK_A/N), big.mark=",")))
cat(sprintf("TOTAL TOKENS          : %.0f M\n", TOK/1e6))
cat(sprintf("wall clock @%d conc    : %.1f h   (@50: %.1f h)\n",
            CONC, AG/CONC*SEC_A/3600, AG/50*SEC_A/3600))
for (m in list(c("claude-opus-5",25), c("claude-sonnet-5",10), c("claude-haiku-4-5",5)))
  cat(sprintf("  %-18s $%s\n", m[1],
              format(round(TOK/1e6*as.numeric(m[2])), big.mark=",")))
cat(sprintf("plus Phase 2 prefetch: ~%.1f h single-threaded, 0 tokens\n",
            TR*0.9/2.5/3600))

cat("\n=== 5. EXPECTED YIELD (post-refresh pilot rates) ===\n")
m1 <- nrow(f1[determination=="match"])/500; m2 <- nrow(f2[determination=="match"])/500
cat(sprintf("stage1 match rate %.1f%%  ->  ~%s matches\n", 100*m1,
            format(round(POOL[stage=="stage1"]$cases*m1, -1), big.mark=",")))
cat(sprintf("stage2 match rate %.1f%%  ->  ~%s matches\n", 100*m2,
            format(round(POOL[stage=="stage2"]$cases*m2, -1), big.mark=",")))
tot <- POOL[stage=="stage1"]$cases*m1 + POOL[stage=="stage2"]$cases*m2
cat(sprintf("TOTAL expected recoveries: ~%s\n", format(round(tot, -1), big.mark=",")))
cat(sprintf("cost per match: opus $%.2f | sonnet $%.2f\n",
            TOK/1e6*25/tot, TOK/1e6*10/tot))
fwrite(POOL, file.path(out, "FINAL-PLAN-COUNTS.csv"))
