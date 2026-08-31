#!/usr/bin/env Rscript
# Add the BMF_ / SAM_ context columns to the 2026-MAY slim shards.
#
# np_route() was run for this batch without bmf=/sam=, so the shards carry 65
# columns instead of the ~150 the NOV-2025 run had -- no NTEE, subsection,
# ruling year, assets/revenue, affiliation, or NAICS for the adjudicator to
# reason over.
#
# We do NOT re-route to fix that. np_run_batches() persists CSVs only, so the
# scored pairs for this run are gone, and re-running the cascade would (a) cost
# a full re-match and (b) produce a DIFFERENT MAYBE set, because block.R and
# select.R both changed after this run (IDF corpus size; .ein tiebreak). That
# would desynchronize the shards from the crosswalk they were produced with.
#
# np_bmf_review_fields() and np_sam_review_fields() are pure per-key lookups, so
# the identical columns can be joined straight onto the existing shards. Same
# result, no re-match, existing outputs stay valid.

suppressWarnings(suppressPackageStartupMessages(library(data.table)))
suppressMessages(devtools::load_all(".", quiet = TRUE))

BASE     <- "data-dev/run-2026MAY"
SLIM_DIR <- file.path(BASE, "llm-review", "slim")
BMF_CSV  <- "data-raw/bmf_unified_geocoded_2026-08-20.csv"
SAM_CSV  <- "data-dev/FRESH-NEW-2026MAY.CSV"

# EINs are written with a dash in the shards and may be bare digits in the BMF.
norm_ein <- function(x) {
  d <- gsub("[^0-9]", "", as.character(x))
  ifelse(nzchar(d), formatC(as.numeric(d), width = 9, format = "d", flag = "0"), NA_character_)
}

# Final adjudication column set: NOV's slim columns + the BMF context that bears
# on organisational identity (what type of org, how big, part of a group ruling).
FINAL <- c(
  "uei", "ein",
  "is_top_candidate", "num_of_candidates", "total_score",
  "name_similarity", "addr_similarity",
  "candidate_type", "match_layer", "pass",
  "match_decision", "decision_reason",
  "veto", "veto_reason", "veto_soft", "veto_soft_reason",
  "name_uss_raw_main", "name_uss_raw_dba", "name_uss_raw_division",
  "name_bmf_raw_main", "name_bmf_raw_dba", "name_bmf_raw_division",
  "street_similarity", "city_similarity", "zip_similarity",
  "street_uss", "street_bmf", "city_uss", "city_bmf",
  "state_uss", "state_bmf", "zip5_uss", "zip5_bmf",
  "bmf_active",
  "BMF_ntee_clean", "BMF_subsection", "BMF_is_foundation", "BMF_rule_year",
  "BMF_assets", "BMF_revenue", "BMF_form_990", "BMF_affiliation",
  "BMF_group_exemption_number", "BMF_group_exemption_is_member", "BMF_in_care_of",
  "SAM_entity_structure_label", "SAM_primary_naics", "SAM_entity_url",
  "SAM_bus_type_nonprofit", "SAM_poc_first_name", "SAM_poc_last_name",
  "SAM_poc_title", "SAM_entity_start_date"
)

slim_files <- sort(
list.files(SLIM_DIR, pattern = "^slim-.*[.]csv$", full.names = TRUE))
stopifnot(length(slim_files) > 0)
shards <- lapply(slim_files, fread, colClasses = "character", showProgress = FALSE)
names(shards) <- basename(slim_files)

want_ein <- unique(norm_ein(unlist(lapply(shards, `[[`, "ein"))))
want_uei <- unique(unlist(lapply(shards, `[[`, "uei")))
cat(sprintf("shards: %d | distinct EIN: %s | distinct UEI: %s\n",
            length(shards), format(length(want_ein), big.mark = ","),
            format(length(want_uei), big.mark = ",")))

# --- BMF context ---------------------------------------------------------------
BMF_COLS <- c("ein", "ntee_code_clean", "nteev2", "subsection_code",
              "foundation_code_definition", "ruling_date", "ruling_date_ym_str",
              "accounting_period", "asset_amount", "revenue_amount",
              "filing_requirement_code_definition", "pf_filing_requirement_code",
              "pf_filing_requirement_code_definition", "affiliation_code",
              "affiliation_code_definition", "group_exemption_number",
              "group_exemption_is_member", "in_care_of_name_clean")
cat("reading BMF context columns ...\n")
bmf <- fread(BMF_CSV, select = BMF_COLS, colClasses = "character", showProgress = FALSE)
bmf[, .k := norm_ein(ein)]
bmf <- bmf[.k %in% want_ein]
bmf <- bmf[!duplicated(.k)]
cat(sprintf("  BMF rows matched: %s of %s wanted EINs\n",
            format(nrow(bmf), big.mark = ","), format(length(want_ein), big.mark = ",")))
bf <- as.data.table(np_bmf_review_fields(bmf))
bf[, .k := norm_ein(ein)][, ein := NULL]

# --- SAM context ---------------------------------------------------------------
cat("reading SAM source ...\n")
sam <- fread(SAM_CSV, colClasses = "character", showProgress = FALSE)
sf <- as.data.table(np_sam_review_fields(sam))
sf <- sf[uei %in% want_uei]
sf <- sf[!duplicated(uei)]
cat(sprintf("  SAM rows matched: %s of %s wanted UEIs\n",
            format(nrow(sf), big.mark = ","), format(length(want_uei), big.mark = ",")))

# --- join and rewrite ----------------------------------------------------------
for (nm in names(shards)) {
  d <- shards[[nm]]
  d[, .k := norm_ein(ein)]
  d <- merge(d, bf, by = ".k", all.x = TRUE, sort = FALSE)
  d <- merge(d, sf, by = "uei", all.x = TRUE, sort = FALSE)
  d[, .k := NULL]
  # keep a focused set: the NOV slim columns plus the BMF context that actually
  # bears on org identity. The 65 SAM_bus_type_* booleans are dropped except
  # nonprofit -- they dilute attention without informing the judgement.
  keep <- intersect(FINAL, names(d))
  d <- d[, ..keep]
  fwrite(d, file.path(SLIM_DIR, nm))
  cat(sprintf("  %-26s %4d rows, %3d cols\n", nm, nrow(d), ncol(d)))
}
cat("done\n")
