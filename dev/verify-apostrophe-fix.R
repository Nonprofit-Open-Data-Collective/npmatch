#!/usr/bin/env Rscript
# Behavioural check on the .np_basic_clean punctuation fix.
NPM <- Sys.getenv("NPMATCH_DIR", "C:/Users/jlecy/Dropbox/00 - URBAN/00-GITHUB/npmatch")
suppressWarnings(suppressMessages(devtools::load_all(NPM, quiet = TRUE)))
bc <- npmatch:::.np_basic_clean

cases <- list(
  # possessives: apostrophe deleted, token stays whole
  c("BO'S PLACE",                    "BOS PLACE"),
  c("ST LUKE'S HOSPITAL",            "ST LUKES HOSPITAL"),
  c("CHILDREN'S MUSEUM OF NH",       "CHILDRENS MUSEUM OF NH"),
  c("L'ARCHE MOBILE",                "LARCHE MOBILE"),
  c("Sarah\u2019s Circle",           "SARAHS CIRCLE"),      # curly apostrophe
  # intra-word period: deleted (initialism joins)
  c("F.I.N.D.",                      "FIND"),
  c("U.S.A. TODAY FUND",             "USA TODAY FUND"),
  # period that already separates words: break preserved
  c("ST. LUKES HOSPITAL",            "ST LUKES HOSPITAL"),
  c("INC. OF AMERICA",               "INC OF AMERICA"),
  # every other mark still separates
  c("MID-ATLANTIC MINISTRIES",       "MID ATLANTIC MINISTRIES"),
  c("SMITH & JONES FUND",            "SMITH AND JONES FUND"),
  c("BOSTON VEDIC SOCIETY C/O EDWARD","BOSTON VEDIC SOCIETY C O EDWARD"),
  c("FOO (BAR) TRUST",               "FOO BAR TRUST"),
  # de-accenting still works
  c("NI\u00d1OS DEL SOL",            "NINOS DEL SOL")
)

ok <- TRUE
for (cs in cases) {
  got <- bc(cs[1])
  pass <- identical(got, cs[2])
  ok <- ok && pass
  cat(sprintf("  %-4s %-34s -> %-34s %s\n", if (pass) "PASS" else "FAIL",
              cs[1], got, if (pass) "" else paste("expected:", cs[2])))
}
cat(if (ok) "\nall behavioural cases pass\n" else "\nFAILURES ABOVE\n")
quit(status = if (ok) 0L else 1L)
