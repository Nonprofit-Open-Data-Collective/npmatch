#!/usr/bin/env Rscript
# Slim the 133 MAYBE review shards down to the columns an adjudicator needs,
# so each subagent reads a compact, information-dense file (not 150 columns of
# tokenized/boolean noise). Idempotent: overwrites slim files each run.

suppressWarnings(suppressPackageStartupMessages(library(data.table)))

BASE      <- "C:/Users/jdlec/Dropbox (Personal)/00 - URBAN/00-GITHUB/npmatch/data-dev/run-2025NOV"
REVIEW    <- file.path(BASE, "llm-review")
SLIM_DIR  <- file.path(REVIEW, "slim")
dir.create(SLIM_DIR, recursive = TRUE, showWarnings = FALSE)

# columns the LLM adjudicator actually reasons over (kept if present)
KEEP <- c(
  "uei", "ein",
  "is_top_candidate", "num_of_candidates", "total_score",
  "name_similarity", "addr_similarity",
  "candidate_type", "match_layer", "pass",
  "match_decision", "decision_reason",
  "veto", "veto_reason", "veto_soft", "veto_soft_reason",
  # human-readable names
  "name_uss_raw_main", "name_uss_raw_dba", "name_uss_raw_division",
  "name_bmf_raw_main", "name_bmf_raw_dba", "name_bmf_raw_division",
  # geography
  "street_similarity", "city_similarity", "zip_similarity",
  "street_uss", "street_bmf", "city_uss", "city_bmf",
  "state_uss", "state_bmf", "zip5_uss", "zip5_bmf",
  # context
  "bmf_active", "SAM_entity_structure_label", "SAM_primary_naics",
  "SAM_entity_url", "SAM_bus_type_nonprofit"
)

shards <- list.files(BASE, pattern = "^review-[0-9]+-part[0-9]+\\.csv$", full.names = TRUE)
shards <- sort(shards)
cat(sprintf("found %d shards\n", length(shards)))

man <- vector("list", length(shards))
for (i in seq_along(shards)) {
  sp   <- shards[i]
  base <- sub("^review-", "", sub("\\.csv$", "", basename(sp)))   # e.g. "01-part01"
  d    <- fread(sp, colClasses = "character", showProgress = FALSE)
  keep <- intersect(KEEP, names(d))
  slim <- d[, ..keep]
  outp <- file.path(SLIM_DIR, sprintf("slim-%s.csv", base))
  fwrite(slim, outp)
  man[[i]] <- data.frame(
    base = base, shard = basename(sp), slim = basename(outp),
    n_uei = length(unique(slim$uei)), n_rows = nrow(slim),
    stringsAsFactors = FALSE)
}
manifest <- rbindlist(man)
fwrite(manifest, file.path(REVIEW, "manifest.csv"))
cat(sprintf("wrote %d slim files; total UEIs = %s; total candidate rows = %s\n",
            nrow(manifest), format(sum(manifest$n_uei), big.mark = ","),
            format(sum(manifest$n_rows), big.mark = ",")))
