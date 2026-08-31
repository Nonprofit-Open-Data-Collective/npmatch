#!/usr/bin/env Rscript
# QC the research output: do the recovered EINs actually exist, and do the
# `match` calls line up with a same-state BMF record?
suppressPackageStartupMessages({library(data.table)})

D <- "data-dev"; out <- file.path(D, "no-research")
a <- rbindlist(list(fread(file.path(out, "FINDINGS-STAGE1-NO-500.csv"), colClasses = "character"),
                    fread(file.path(out, "FINDINGS-STAGE2-NO-500.csv"), colClasses = "character")))
idx <- as.data.table(readRDS(file.path(D, "BMF-NAME-INDEX.rds")))
setkey(idx, ein)

e <- a[ein_found != ""]
cat("rows carrying an EIN:", nrow(e), "\n")

e <- merge(e, unique(idx[, .(ein, bmf_name = name, bmf_city = city,
                             bmf_state = state, bmf_active = active)], by = "ein"),
           by.x = "ein_found", by.y = "ein", all.x = TRUE, sort = FALSE)

cat("\n--- EIN exists in unified BMF? ---\n")
print(table(present = !is.na(e$bmf_name), e$determination))

cat("\n--- for determination == match: state agreement ---\n")
m <- e[determination == "match" & !is.na(bmf_name)]
cat("match rows with a BMF record:", nrow(m), "of", nrow(e[determination == "match"]), "\n")
print(table(state_matches = m$bmf_state == m$sam_state, m$confidence))

cat("\n--- matches whose EIN is NOT in the BMF (should be ~0) ---\n")
bad <- e[determination == "match" & is.na(bmf_name)]
if (nrow(bad)) print(bad[, .(uei, sam_name, sam_state, ein_found, confidence, resolving_tier)]) else cat("none\n")

cat("\n--- matches on an INACTIVE BMF record ---\n")
print(table(m$bmf_active, m$stage))

cat("\n--- same EIN assigned to more than one UEI ---\n")
dup <- e[determination == "match", .N, by = ein_found][N > 1]
if (nrow(dup)) {
  print(merge(dup, e[determination == "match", .(ein_found, uei, sam_name, sam_state)],
              by = "ein_found")[order(-N, ein_found)])
} else cat("none\n")

cat("\n--- ProPublica availability (429s) ---\n")
a[, pp429 := grepl("429", sources)]
print(table(a$pp429, a$stage))

cat("\n--- cross-state matches (worth a human look) ---\n")
xs <- m[bmf_state != sam_state, .(uei, sam_name, sam_state, ein_found, bmf_name, bmf_state, confidence)]
cat(nrow(xs), "cross-state matches\n"); if (nrow(xs)) print(head(xs, 25))

fwrite(e[, .(uei, stage, sam_name, sam_state, ein_found, determination, confidence,
             resolving_tier, bmf_name, bmf_city, bmf_state, bmf_active)],
       file.path(out, "QC-EIN-CHECK.csv"))
