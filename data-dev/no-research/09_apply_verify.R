#!/usr/bin/env Rscript
# Apply the refutation verdicts to the findings and write the final deliverables.
suppressPackageStartupMessages({library(data.table)})

D <- "data-dev"; out <- file.path(D, "no-research")
f1 <- fread(file.path(out, "FINDINGS-STAGE1-NO-500.csv"), colClasses = "character")
f2 <- fread(file.path(out, "FINDINGS-STAGE2-NO-500.csv"), colClasses = "character")

vf <- list.files(file.path(out, "verify-out"), "^verify-[0-9]+[.]tsv$", full.names = TRUE)
v <- rbindlist(lapply(vf, fread, sep = "\t", colClasses = "character", quote = ""), fill = TRUE)
v <- unique(v, by = "uei")
cat("verify rows:", nrow(v), "\n"); print(table(v$verdict))

apply_v <- function(f) {
  f <- merge(f, v[, .(uei, verdict, corrected_ein, corrected_determination,
                      v_confidence = confidence, v_sources = sources, v_judgement = judgement)],
             by = "uei", all.x = TRUE, sort = FALSE)
  f[, verified := fifelse(is.na(verdict), "", verdict)]

  # refuted: take the corrected call
  r <- !is.na(f$verdict) & f$verdict == "refuted"
  f[r & corrected_determination != "", determination := corrected_determination]
  f[r, ein_found := corrected_ein]
  f[r, confidence := v_confidence]

  # uncertain: keep the EIN but stop calling it high confidence
  u <- !is.na(f$verdict) & f$verdict == "uncertain"
  f[u, confidence := "low"]

  # every verified row carries the refutation evidence alongside the original
  ver <- !is.na(f$verdict)
  f[ver, sources   := paste0(sources, " ;; VERIFY(", verdict, "): ", v_sources)]
  f[ver, judgement := paste0(judgement, " ;; VERIFY(", verdict, "): ", v_judgement)]

  f[, c("verdict","corrected_ein","corrected_determination",
        "v_confidence","v_sources","v_judgement") := NULL]
  f[]
}
f1 <- apply_v(f1); f2 <- apply_v(f2)

fwrite(f1, file.path(out, "FINDINGS-STAGE1-NO-500.csv"))
fwrite(f2, file.path(out, "FINDINGS-STAGE2-NO-500.csv"))

a <- rbindlist(list(f1, f2))
cat("\n=== FINAL determination x stage ===\n"); print(table(a$determination, a$stage))
cat("\n=== FINAL confidence x stage ===\n");    print(table(a$confidence, a$stage))
cat("\n=== resolving tier ===\n");              print(table(a$resolving_tier, a$stage))
cat("\n=== EIN recovered ===\n");               print(table(a$ein_found != "", a$stage))
cat("\n=== adversarially verified ===\n");      print(table(a$verified, a$stage))
cat("\nrows:", nrow(a), " blank determination:", sum(a$determination == ""),
    " blank sources:", sum(a$sources == ""), "\n")
