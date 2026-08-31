#!/usr/bin/env Rscript
# Turn the Tier-1 screen into seeded findings rows, and emit the web-research work queue.
suppressPackageStartupMessages({library(data.table)})

D <- "data-dev"; out <- file.path(D, "no-research")
a <- rbindlist(list(fread(file.path(out, "TIER1-STAGE1-NO-500.csv"), colClasses = "character"),
                    fread(file.path(out, "TIER1-STAGE2-NO-500.csv"), colClasses = "character")),
               fill = TRUE)
a[, tier1_exact_same_state := tier1_exact_same_state == "TRUE"]
US <- c(state.abb, "DC", "PR", "VI", "GU", "AS", "MP", "FM", "MH", "PW")

## a foreign-addressed registrant incorporated in a US state may still hold a US EIN
a[, foreign_us_incorp := entity_gate == "foreign" & sam_state_incorp %in% US]

## ---- efile 990 index: does this org's website belong to a 990 filer? ------
## Audited on 167 gated cases: the BMF-hit OR 2L hatch alone catches 6 of 8 false
## settles; adding this domain condition catches 8 of 8, with 0 residual among the
## 142 unflagged. It is the only signal that reaches the for_profit_form misses.
EFILE <- file.path(out, "EFILE-XWALK.tsv")
dom <- function(u) {
  u <- tolower(trimws(u))
  u <- sub("^[a-z]+://", "", u); u <- sub("^www[0-9]?\\.", "", u)
  u <- sub("[/?#].*$", "", u);   u <- sub(":.*$", "", u); u <- sub("\\.+$", "", u)
  u[is.na(u) | !grepl("\\.", u) | nchar(u) < 4] <- ""
  u
}
a[, sam_domain := dom(sam_url)]
if (file.exists(EFILE)) {
  ex <- fread(EFILE, sep = "\t", select = c("ein","web_domain"),
              colClasses = "character", quote = "", showProgress = FALSE)
  ed <- ex[web_domain != ""]
  a[, efile_domain_hit := sam_domain != "" & sam_domain %chin% ed$web_domain]
  # carry the matching EINs so the research packet can show them
  hit <- merge(a[efile_domain_hit == TRUE, .(uei, sam_domain)], ed,
               by.x = "sam_domain", by.y = "web_domain", allow.cartesian = TRUE)
  hit <- hit[, .(efile_domain_eins = paste(unique(ein), collapse = ";")), by = uei]
  a <- merge(a, hit, by = "uei", all.x = TRUE, sort = FALSE)
  a[is.na(efile_domain_eins), efile_domain_eins := ""]
  cat("efile domain hits:", sum(a$efile_domain_hit), "of", nrow(a), "\n")
} else {
  a[, efile_domain_hit := FALSE]; a[, efile_domain_eins := ""]
  cat("\n!! EFILE-XWALK.tsv not found -- run 19_build_efile_xwalk.R.\n",
      "   The gate loses its strongest escape condition; expect ~2 of every 8\n",
      "   false settles (the for_profit_form ones) to go undetected.\n", sep = "")
}

## the single EIN behind an exact same-state name-key hit, if unambiguous
a[, tier1_ein := ""]
hit <- a$tier1_exact_same_state & a$bmf_lookup != ""
a[hit, tier1_ein := sub("^.*?name_key: ([0-9]{2}-[0-9]{7}).*$", "\\1", bmf_lookup)]
a[!grepl("^[0-9]{2}-[0-9]{7}$", tier1_ein), tier1_ein := ""]

## ---- seeded determinations ----------------------------------------------
a[, determination   := ""]
a[, ein_found       := ""]
a[, resolving_tier  := ""]
a[, confidence      := ""]
a[, sources         := ""]
a[, judgement       := ""]
a[, notes           := ""]

set_row <- function(dt, i, det, tier, conf, src, judg) {
  dt[i, `:=`(determination = det, resolving_tier = tier, confidence = conf,
             sources = src, judgement = judg)]
}

set_row(a, a$entity_gate == "individual", "not_a_nonprofit", "tier1", "high",
        "SAM entity structure 2J (sole proprietorship) + person-form legal name",
        "Registrant is an individual/sole proprietor, not an organization; no BMF entity can exist.")

set_row(a, a$entity_gate == "for_profit_form", "not_a_nonprofit", "tier1", "high",
        "SAM legal business name carries a for-profit legal form (LLC/LP/PLLC)",
        "For-profit legal form; not an IRS-recognized exempt organization.")

set_row(a, a$entity_gate == "government", "not_a_nonprofit", "tier1", "high",
        "SAM legal business name is a government unit (city/county/district/authority)",
        "Government unit, not a 501(c) filer; the BMF has no entry for the unit itself.")

set_row(a, a$entity_gate == "not_tax_exempt_corp", "not_a_nonprofit", "tier1", "medium",
        "SAM entity structure 2L = corporate entity, NOT tax exempt",
        "SAM itself reports the registrant as a non-tax-exempt corporation.")

set_row(a, a$entity_gate == "foreign" & !a$foreign_us_incorp, "nonprofit_not_in_bmf", "tier1", "high",
        "SAM physical address outside the US and its territories; no US state of incorporation",
        "Foreign entity, outside the scope of the IRS BMF; no US EIN expected.")

## ---- the audited escape hatch --------------------------------------------
## Never let the gate settle a case that shows any independent sign of being a
## filer: a full-BMF name-key hit, SAM's unreliable 2L flag, or a website domain
## shared with a 990 filer. Measured cost 14.7% of gated volume; measured benefit
## 8/8 false settles caught, 0 residual.
a[, escape := bmf_lookup != "" |
              entity_gate == "not_tax_exempt_corp" |
              efile_domain_hit]
a[escape == TRUE, `:=`(determination = "", resolving_tier = "", confidence = "",
                       sources = "", judgement = "")]

## ---- web research queue --------------------------------------------------
a[, web := determination == "" | tier1_exact_same_state | foreign_us_incorp]
a[, web_reason := fcase(
  tier1_exact_same_state, "confirm_tier1_exact_name_hit",
  foreign_us_incorp,      "foreign_address_but_us_incorporated",
  efile_domain_hit,       "efile_990_filer_shares_this_website",
  entity_gate == "not_tax_exempt_corp", "sam_2L_flag_unreliable",
  entity_gate == "church", "church_may_or_may_not_be_in_bmf",
  entity_gate == "tribal_government", "tribal_entity",
  default = "open_nonprofit_candidate")]

fwrite(a, file.path(out, "FINDINGS-SEED.csv"))

cat("\n=== seeded at Tier 1 (no web needed) ===\n")
print(table(a[determination != "" & !web]$determination, a[determination != "" & !web]$.src))
cat("\n=== web research queue ===\n")
print(table(a[web == TRUE]$web_reason, a[web == TRUE]$.src))
cat("\nTOTAL web cases:", sum(a$web), " | settled at tier1:", sum(!a$web), "\n")
