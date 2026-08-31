#!/usr/bin/env Rscript
# Project full-pool cost from the measured pilot telemetry.
suppressPackageStartupMessages({library(data.table)})

D <- "data-dev"; out <- file.path(D, "no-research")
t  <- fread(file.path(out, "agent-telemetry.csv"))
sd_ <- fread(file.path(out, "FINDINGS-SEED.csv"), colClasses = "character")
p1 <- nrow(fread(file.path(out, "POOL-STAGE1-NO.csv")))
p2 <- nrow(fread(file.path(out, "POOL-STAGE2-NO.csv")))

r <- t[kind == "research"]
cat("=== measured, research agents (", nrow(r), "agents /", sum(r$cases), "cases ) ===\n")
cat(sprintf("tokens/agent : mean %s  median %s  p90 %s\n",
            format(round(mean(r$tokens)), big.mark=","), format(round(median(r$tokens)), big.mark=","),
            format(round(quantile(r$tokens, .9)), big.mark=",")))
cat(sprintf("tokens/case  : mean %s\n", format(round(sum(r$tokens)/sum(r$cases)), big.mark=",")))
cat(sprintf("secs/agent   : mean %.0f  median %.0f  p90 %.0f\n",
            mean(r$secs), median(r$secs), quantile(r$secs, .9)))
cat(sprintf("tool calls/agent: mean %.1f\n", mean(r$tool_uses)))

## share of each pool that needs the web tiers, measured on the samples
w1 <- sd_[.src == "stage1", mean(web == "TRUE")]
w2 <- sd_[.src == "stage2", mean(web == "TRUE")]
cat(sprintf("\nweb-needed share: stage1 %.1f%%  stage2 %.1f%%\n", 100*w1, 100*w2))

N   <- 8L        # cases per agent
CONC <- 20L      # concurrent subagent cap
tok_a  <- mean(r$tokens); sec_a <- mean(r$secs)

est <- function(label, cases) {
  ag <- ceiling(cases / N)
  data.table(scope = label, cases = cases, agents = ag,
             tokens_M = round(ag * tok_a / 1e6, 1),
             hours_at_20 = round(ag / CONC * sec_a / 3600, 1),
             hours_at_50 = round(ag / 50 * sec_a / 3600, 1))
}
E <- rbindlist(list(
  est("stage 2 only (highest yield)",      round(p2 * w2)),
  est("stage 1 only",                      round(p1 * w1)),
  est("both stages, web cases only",       round(p1*w1 + p2*w2)),
  est("both stages, EVERY case via agent", p1 + p2)))
cat("\n=== projected full-pool cost ===\n"); print(E)

cat(sprintf("\nTier-1 gate alone settles %s of %s cases (%.0f%%) at ~zero marginal cost.\n",
            format(round(p1*(1-w1) + p2*(1-w2)), big.mark=","),
            format(p1+p2, big.mark=","),
            100*(p1*(1-w1)+p2*(1-w2))/(p1+p2)))

## expected yield, from measured match rates
m1 <- 71/500; m2 <- 142/500
cat(sprintf("\nexpected recoveries: stage1 ~%s, stage2 ~%s, total ~%s\n",
            format(round(p1*m1, -1), big.mark=","), format(round(p2*m2, -1), big.mark=","),
            format(round(p1*m1 + p2*m2, -1), big.mark=",")))
cat(sprintf("stage-2 yield per agent-hour is %.1fx stage-1 (%.3f vs %.3f matches/case)\n",
            m2/m1, m2, m1))
fwrite(E, file.path(out, "COST-ESTIMATE.csv"))
