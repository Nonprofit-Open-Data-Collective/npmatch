#!/usr/bin/env Rscript
# What punctuation actually survives in the NCCS BMF org_name_join, and how does
# npmatch's cleaner treat the same characters? Any character the BMF DELETES but
# npmatch turns into a SPACE is a silent exact-match failure.
suppressWarnings(suppressMessages(library(data.table)))
NPM <- Sys.getenv("NPMATCH_DIR", "C:/Users/jlecy/Dropbox/00 - URBAN/00-GITHUB/npmatch")
d <- fread(file.path(NPM, "data-raw", "bmf_2026_01_processed.csv"),
           select = c("org_name_raw", "org_name_join"), colClasses = "character",
           showProgress = FALSE)

cat("punctuation frequency in org_name_raw vs org_name_join:\n")
chars <- c("'", "\u2019", "-", ".", ",", "&", "/", "(", ")", "#", "+", "*", "\"", ";", ":")
for (ch in chars) {
  nraw <- sum(grepl(ch, d$org_name_raw, fixed = TRUE))
  njoin <- sum(grepl(ch, d$org_name_join, fixed = TRUE))
  cat(sprintf("  %-3s raw=%8d  join=%8d   %s\n", ch, nraw, njoin,
              if (nraw > 0 && njoin == 0) "<- DROPPED by NCCS" else ""))
}

cat("\nhow does NCCS collapse each one? (raw -> join on real records)\n")
show <- function(ch, n = 3) {
  i <- head(which(grepl(ch, d$org_name_raw, fixed = TRUE)), n)
  for (k in i) cat(sprintf("  %-28s -> %s\n", substr(d$org_name_raw[k], 1, 28),
                           substr(d$org_name_join[k], 1, 34)))
}
for (ch in c("'", "-", ".", "/", "&")) { cat(sprintf(" [%s]\n", ch)); show(ch) }
