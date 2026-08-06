suppressMessages(library(data.table))
base <- "C:/Users/jdlec/Dropbox/00 - URBAN/00-GITHUB/npmatch"
rg <- fread(file=file.path(base,"data-dev/RANDOM-GROUNDTRUTH.csv"), colClasses="character")
hg <- fread(file=file.path(base,"data-dev/HARD-GROUNDTRUTH.csv"), colClasses="character")
mm <- function(d) sub(":.*","",d)

cat("################  WHOLE TRAINING SET: FP / FN  ################\n\n")

## ---------- RANDOM 1,000 ----------
rg[, tier := algo_tier][, det := mm(gt_det)]
cat("=== RANDOM sample (n =", nrow(rg), ") ===\n")
cat("algo tier:\n"); print(table(rg$tier))
cat("final determination:\n"); print(sort(table(rg$det), decreasing=TRUE))
r_match  <- rg$det=="match"
r_fn <- rg$tier %in% c("NO","MAYBE","ZERO_CAND") & r_match
cat(sprintf("\nFALSE NEGATIVES (match exists, algo NO/MAYBE/ZERO): %d\n", sum(r_fn)))
print(table(rg$tier[r_fn]))
cat(sprintf("YES auto-accepted: %d  (QC-estimated FP rate ~2%% -> ~%d FPs)\n",
    sum(rg$tier=="YES"), round(0.02*sum(rg$tier=="YES"))))

## ---------- HARD 502 ----------
hg[, tier := algo_tier][, det := mm(gt_det)]
cat("\n=== HARD sample (n =", nrow(hg), ") ===\n")
cat("algo tier:\n"); print(table(hg$tier))
cat("final determination:\n"); print(sort(table(hg$det), decreasing=TRUE))
h_match <- hg$det=="match"
h_fn <- hg$tier %in% c("NO","MAYBE") & h_match
h_fp <- hg$tier=="YES" & hg$pick_correct=="FALSE"
cat(sprintf("\nFALSE NEGATIVES (match exists, algo NO/MAYBE): %d\n", sum(h_fn)))
print(table(hg$tier[h_fn]))
cat(sprintf("FALSE POSITIVES (algo YES but pick wrong): %d of %d YES = %.1f%%\n",
    sum(h_fp), sum(hg$tier=="YES"), 100*sum(h_fp)/sum(hg$tier=="YES")))

## ---------- COMBINED ----------
cat("\n################  HEADLINE NUMBERS  ################\n")
tot_fn <- sum(r_fn)+sum(h_fn)
cat(sprintf("Confirmed FALSE NEGATIVES (active-BMF match the algo missed): %d\n", tot_fn))
cat(sprintf("  random %d + hard %d\n", sum(r_fn), sum(h_fn)))
# FN rate = missed matches / all queries that truly have an active-BMF match
r_truematch <- sum(r_match); h_truematch <- sum(h_match)
cat(sprintf("Coverage (recall) on queries with a real active-BMF match:\n"))
cat(sprintf("  random: %d/%d found by algo YES-tier = %.1f%% (FN rate %.1f%%)\n",
    r_truematch-sum(r_fn), r_truematch, 100*(r_truematch-sum(r_fn))/r_truematch, 100*sum(r_fn)/r_truematch))
cat(sprintf("  hard:   %d/%d = %.1f%% (FN rate %.1f%%)  [hard set is enriched for difficulty]\n",
    h_truematch-sum(h_fn), h_truematch, 100*(h_truematch-sum(h_fn))/h_truematch, 100*sum(h_fn)/h_truematch))
cat(sprintf("\nFALSE POSITIVE rate on auto-accepted YES: hard %.1f%% | random ~2%% (QC)\n",
    100*sum(h_fp)/sum(hg$tier=="YES")))
cat(sprintf("\nStill cant_determine (escalation queue): counted in determinations above;\n"))
cat("  these are mostly real orgs whose EIN didn't surface in one web pass (add to FN if confirmed).\n")
