#!/usr/bin/env Rscript
# Full-pool projection, revised: corrected pool (2026MAY stage-2 included),
# the audited Tier-1 gate fix, and per-model cost.
suppressPackageStartupMessages({library(data.table)})

D <- "data-dev"; out <- file.path(D, "no-research")
tele <- fread(file.path(out, "agent-telemetry.csv"))[kind == "research"]
sd_  <- fread(file.path(out, "FINDINGS-SEED.csv"), colClasses = "character")

TOK_A  <- mean(tele$tokens)        # tokens per 8-case agent
SEC_A  <- mean(tele$secs)
N      <- 8L
CONC   <- 20L

## ---- pools (2026MAY stage-2 = 359, per the run tallies) ------------------
P <- data.table(
  run   = c("2025NOV","2026MAY","2025NOV","2026MAY"),
  stage = c("stage1","stage1","stage2","stage2"),
  cases = c(31540L,   2795L,    6166L,    359L))
cat("=== pool ===\n"); print(dcast(P, run ~ stage, value.var = "cases"))
cat("TOTAL:", format(sum(P$cases), big.mark = ","), "\n")

## ---- web share, measured per stage --------------------------------------
w <- c(stage1 = sd_[.src == "stage1", mean(web == "TRUE")],
       stage2 = sd_[.src == "stage2", mean(web == "TRUE")])

## The audited gate fix: un-gate any case with a full-BMF name hit, OR SAM 2L,
## OR a website domain shared with a 990 efile filer. Measured against audit-v2
## truth this catches 8/8 false settles at 0.00% residual.
xw <- fread(file.path(out, "EFILE-XWALK.tsv"), sep="\t", colClasses="character", quote="")
dom <- function(u){u<-tolower(trimws(u));u<-sub("^[a-z]+://","",u);u<-sub("^www[0-9]?\\.","",u)
  u<-sub("[/?#].*$","",u);u<-sub(":.*$","",u);u<-sub("\\.+$","",u)
  u[!grepl("\\.",u)|nchar(u)<4]<-"";u}
gt <- sd_[web == "FALSE"]
gt[, sam_dom := dom(sam_url)]
dm <- unique(xw[web_domain != "", .(web_domain)])
gt[, f_dom := sam_dom != "" & sam_dom %chin% dm$web_domain]
UNGATE <- gt[, mean(bmf_lookup != "" | entity_gate == "not_tax_exempt_corp" | f_dom)]

P[, web_base  := cases * w[stage]]
P[, web_extra := cases * (1 - w[stage]) * UNGATE]
P[, web_total := web_base + web_extra]

cat(sprintf("\ngate fix moves %.1f%% of gated cases to the web queue\n", 100*UNGATE))
cat("=== web cases ===\n")
print(P[, .(run, stage, cases, web_base = round(web_base),
            web_extra = round(web_extra), web_total = round(web_total))])
cat(sprintf("\nweb cases: %s base + %s from the gate fix = %s\n",
            format(round(sum(P$web_base)), big.mark=","),
            format(round(sum(P$web_extra)), big.mark=","),
            format(round(sum(P$web_total)), big.mark=",")))
cat(sprintf("still settled free by the gate: %s (%.0f%% of pool)\n",
            format(round(sum(P$cases) - sum(P$web_total)), big.mark=","),
            100*(1 - sum(P$web_total)/sum(P$cases))))

## ---- cost by model -------------------------------------------------------
AG <- ceiling(sum(P$web_total) / N)
TOK <- AG * TOK_A
models <- data.table(
  model  = c("claude-opus-5","claude-sonnet-5","claude-haiku-4-5"),
  out_1M = c(25, 10, 5))
models[, agents := AG]
models[, tokens_M := round(TOK/1e6, 1)]
models[, cost_usd := round(TOK/1e6 * out_1M)]
models[, hours_at_20 := round(AG/CONC * SEC_A/3600, 1)]
models[, hours_at_50 := round(AG/50 * SEC_A/3600, 1)]
cat("\n=== full run, both stages ===\n"); print(models)

## ---- stage 2 first -------------------------------------------------------
s2 <- P[stage == "stage2", sum(web_total)]
a2 <- ceiling(s2 / N)
cat(sprintf("\n=== stage 2 only: %s cases, %s agents, %.0fM tok, %.1fh@20 ===\n",
            format(round(s2), big.mark=","), format(a2, big.mark=","),
            a2*TOK_A/1e6, a2/CONC*SEC_A/3600))
cat(sprintf("  opus $%.0f | sonnet $%.0f | haiku $%.0f\n",
            a2*TOK_A/1e6*25, a2*TOK_A/1e6*10, a2*TOK_A/1e6*5))

## ---- expected yield ------------------------------------------------------
m <- c(stage1 = 71/500, stage2 = 142/500)
P[, matches := cases * m[stage]]
## residual after the fix: audit v2 saw 0 false settles among 142 unflagged gated
## cases. Zero observed is not zero -- report the exact binomial upper bound.
res_hi <- binom.test(0, 142)$conf.int[2]
gate_loss_hi <- (sum(P$cases) - sum(P$web_total)) * res_hi
cat(sprintf("\nexpected matches: %s (stage1 %s, stage2 %s)\n",
            format(round(sum(P$matches), -1), big.mark=","),
            format(round(P[stage=="stage1", sum(matches)], -1), big.mark=","),
            format(round(P[stage=="stage2", sum(matches)], -1), big.mark=",")))
cat(sprintf("matches still lost inside the fixed gate: 0 observed, upper bound ~%s (%.1f%%)\n",
            format(round(gate_loss_hi), big.mark=","), 100*res_hi))
cat(sprintf("  (unfixed gate would lose ~%s, per the 4.8%% audit-v2 rate)\n",
            format(round((sum(P$cases)-sum(P$web_total))*0.048, -1), big.mark=",")))
cat(sprintf("cost per match: opus $%.2f | sonnet $%.2f\n",
            TOK/1e6*25/sum(P$matches), TOK/1e6*10/sum(P$matches)))
fwrite(models, file.path(out, "COST-ESTIMATE.csv"))
