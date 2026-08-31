#!/usr/bin/env Rscript
# Generate REPORT.md from the finished findings tables.
suppressPackageStartupMessages({library(data.table)})

D <- "data-dev"; out <- file.path(D, "no-research")
f1 <- fread(file.path(out, "FINDINGS-STAGE1-NO-500.csv"), colClasses = "character")
f2 <- fread(file.path(out, "FINDINGS-STAGE2-NO-500.csv"), colClasses = "character")
p1 <- fread(file.path(out, "POOL-STAGE1-NO.csv"), colClasses = "character")
p2 <- fread(file.path(out, "POOL-STAGE2-NO.csv"), colClasses = "character")
a  <- rbindlist(list(f1, f2))

pct <- function(n, d) sprintf("%.1f%%", 100 * n / d)
tab <- function(f, col) { t <- table(f[[col]]); t[order(-t)] }

L <- c("# NO-case research — 2025NOV + 2026MAY", "",
  sprintf("- generated: %s", format(Sys.Date())),
  sprintf("- protocol: `dev/RESEARCH-PROTOCOL.md` (Tier 1 local -> Tier 2 ProPublica -> Tier 3 web)"),
  sprintf("- sampling seed: 20260826"), "",
  "## Pools", "",
  "| stage | definition | pool | sampled |", "|---|---|---|---|",
  sprintf("| stage 1 | matcher dropped outright (not YES, not MAYBE) | %s | %s |",
          format(nrow(p1), big.mark = ","), format(nrow(f1), big.mark = ",")),
  sprintf("| stage 2 | LLM adjudication rejected the MAYBE (MAYBE -> NO) | %s | %s |",
          format(nrow(p2), big.mark = ","), format(nrow(f2), big.mark = ",")),
  "",
  sprintf("Stage-1 sample is stratified by run: %d from 2025NOV, %d from 2026MAY, proportional to pool.",
          sum(f1$run == "2025NOV"), sum(f1$run == "2026MAY")),
  "",
  "**The 2026MAY run has no stage-2 pool.** No LLM adjudication was ever run against its",
  "MAYBE queue, so every stage-2 case comes from 2025NOV. The 31 2026MAY cases that moved",
  "MAYBE -> NO did so through the address-gate re-run, not adjudication, and are tagged",
  "`no_origin = algorithm_regate` inside the stage-1 pool.", "",
  "## Outcome", "",
  "| determination | stage 1 | stage 2 |", "|---|---|---|")

for (d in c("match", "nonprofit_not_in_bmf", "not_a_nonprofit", "cant_determine")) {
  L <- c(L, sprintf("| `%s` | %d (%s) | %d (%s) |", d,
                    sum(f1$determination == d), pct(sum(f1$determination == d), nrow(f1)),
                    sum(f2$determination == d), pct(sum(f2$determination == d), nrow(f2))))
}

r1 <- sum(f1$determination == "match"); r2 <- sum(f2$determination == "match")
L <- c(L, "", "## The headline: how wrong is the NO bucket?", "",
  sprintf("- **stage 1: %s of NO cases are real matches** (%d/%d)", pct(r1, nrow(f1)), r1, nrow(f1)),
  sprintf("- **stage 2: %s of MAYBE -> NO cases are real matches** (%d/%d)", pct(r2, nrow(f2)), r2, nrow(f2)),
  "",
  sprintf("Scaled to the pools, that implies roughly **%s** recoverable matches sitting in stage-1 NO and **%s** in stage-2 NO — about **%s** additional crosswalk rows available from the NO bucket.",
          format(round(nrow(p1) * r1 / nrow(f1), -1), big.mark = ","),
          format(round(nrow(p2) * r2 / nrow(f2), -1), big.mark = ","),
          format(round(nrow(p1) * r1 / nrow(f1) + nrow(p2) * r2 / nrow(f2), -1), big.mark = ",")),
  "",
  "The two stages fail differently. Stage-1 NO is dominated by cases that *should* be NO —",
  sprintf("foreign registrants, individuals, for-profits (%s of the sample combined).",
          pct(sum(f1$entity_gate %in% c("foreign","individual","for_profit_form","not_tax_exempt_corp")), nrow(f1))),
  "Stage-2 NO is the expensive bucket: these cases already had a credible candidate slate, and",
  sprintf("the adjudicator rejected a correct match %s of the time.", pct(r2, nrow(f2))),
  "",
  "## Confidence and resolving tier", "",
  "| | stage 1 | stage 2 |", "|---|---|---|")

for (cf in c("high", "medium", "low"))
  L <- c(L, sprintf("| confidence `%s` | %d | %d |", cf, sum(f1$confidence == cf), sum(f2$confidence == cf)))
for (tr in c("tier1", "tier2", "tier3"))
  L <- c(L, sprintf("| resolved at `%s` | %d | %d |", tr, sum(f1$resolving_tier == tr), sum(f2$resolving_tier == tr)))

L <- c(L, "",
  sprintf("EINs recovered and recorded: **%d** (%d stage-1, %d stage-2). This exceeds the match count because a `nonprofit_not_in_bmf` case can still have a known EIN — an inactive/990-only filer or a state registration.",
          sum(a$ein_found != ""), sum(f1$ein_found != ""), sum(f2$ein_found != "")),
  "",
  "## Adversarial verification", "",
  sprintf("All %d matches whose EIN sat in a different state from the SAM record were re-run through a second agent instructed to **refute** them, hunting the federated / parent-sponsor trap (a local Section 202 property handed its national sponsor's EIN, a local corps handed a territorial EIN).",
          sum(a$verified != "")), "",
  sprintf("- confirmed: %d", sum(a$verified == "confirmed")),
  sprintf("- refuted: %d", sum(a$verified == "refuted")),
  sprintf("- uncertain (downgraded to low confidence): %d", sum(a$verified == "uncertain")), "",
  "The trap turned out to be rarer than expected: most cross-state assignments were",
  "single-purpose entities that genuinely hold their own EIN but are booked at a sponsor's",
  "mailing address, which is why the state disagreed.",
  "",
  "## Caveats", "",
  sprintf("- **ProPublica rate-limited.** Running 20 research agents concurrently drew HTTP 429s; %d cases (%d stage-1, %d stage-2) had Tier 2 unavailable and were settled on BMF grep plus general web instead. Those cases say so explicitly in `sources`. A serial re-run of just those would firm them up.",
          sum(grepl("429", a$sources)), sum(grepl("429", f1$sources)), sum(grepl("429", f2$sources))),
  sprintf("- **%d cases remain `cant_determine`** after all three tiers; `notes` records what was missing.",
          sum(a$determination == "cant_determine")),
  "- Determinations are agent research, not audited ground truth. The `sources` column carries",
  "  the actual URLs and greps behind each call so any row can be re-checked.",
  "",
  "## Files", "",
  "| file | what |", "|---|---|",
  "| `FINDINGS-STAGE1-NO-500.csv` | 500 stage-1 NO cases, researched |",
  "| `FINDINGS-STAGE2-NO-500.csv` | 500 stage-2 NO cases, researched |",
  "| `POOL-STAGE1-NO.csv` / `POOL-STAGE2-NO.csv` | the full NO pools these were drawn from |",
  "| `QC-EIN-CHECK.csv` | every recovered EIN cross-checked against the unified BMF |",
  "| `BMF-GREP.tsv` | flat 3.69M-row unified BMF used for Tier-1.5 grep |",
  "| `AGENT-BRIEF.md` / `VERIFY-BRIEF.md` | the instructions the research and refutation agents ran |",
  "| `01_*.R` .. `10_*.R` | the reproducible pipeline |",
  "",
  "### Key columns in the findings tables", "",
  "`ein_found`, `determination`, `resolving_tier`, `confidence`, `sources`, `judgement`, `notes`,",
  "`verified`. Stage-2 rows additionally carry `rejected_ein`, `llm_reason` and the full",
  "`candidates` slate the adjudicator saw, so a wrong rejection can be traced to its cause.")

writeLines(L, file.path(out, "REPORT.md"))
cat("wrote REPORT.md\n")
