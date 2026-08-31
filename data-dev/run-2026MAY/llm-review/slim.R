#!/usr/bin/env Rscript
# Slim the 2026-MAY MAYBE review shards to the columns an adjudicator reasons
# over. Mirrors run-2025NOV/llm-review/slim.R with one difference: this run's
# shards live in TWO directories (batch1-new/ = the re-gated batch 1, rest/ =
# batches 2-5) whose file names collide (review-01-part01.csv exists in both),
# so the base name is prefixed with its source dir. Idempotent.

suppressWarnings(suppressPackageStartupMessages(library(data.table)))

BASE     <- "data-dev/run-2026MAY"
REVIEW   <- file.path(BASE, "llm-review")
SLIM_DIR <- file.path(REVIEW, "slim")
dir.create(SLIM_DIR, recursive = TRUE, showWarnings = FALSE)

# Source dirs and the prefix each contributes to a shard's base name.
SRC <- c(b1 = "batch1-new", r = "rest")

KEEP <- c(
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
  "bmf_active"
)

man <- list()
for (tag in names(SRC)) {
  dir_i  <- file.path(BASE, SRC[[tag]])
  shards <- sort(list.files(dir_i, pattern = "^review-[0-9]+-part[0-9]+[.]csv$",
                            full.names = TRUE))
  for (sp in shards) {
    base <- paste0(tag, "-", sub("^review-", "", sub("[.]csv$", "", basename(sp))))
    d    <- fread(sp, colClasses = "character", showProgress = FALSE)
    keep <- intersect(KEEP, names(d))
    slim <- d[, ..keep]
    outp <- file.path(SLIM_DIR, sprintf("slim-%s.csv", base))
    fwrite(slim, outp)
    man[[length(man) + 1L]] <- data.frame(
      base = base, src = SRC[[tag]], shard = basename(sp), slim = basename(outp),
      n_uei = length(unique(slim$uei)), n_rows = nrow(slim),
      stringsAsFactors = FALSE)
  }
}
manifest <- rbindlist(man)
fwrite(manifest, file.path(REVIEW, "manifest.csv"))

# UEIs that appear in more than one shard (duplicate SAM registrations matched
# in more than one compute chunk). They get adjudicated twice; the merge
# collapses them, preferring YES then higher confidence.
all_uei <- unlist(lapply(list.files(SLIM_DIR, pattern = "^slim-.*[.]csv$",
                                    full.names = TRUE),
                         function(f) unique(fread(f, colClasses = "character")$uei)))
dupes <- unique(all_uei[duplicated(all_uei)])

cat(sprintf("wrote %d slim files; %s unique UEIs (%s shard-level) across %s candidate rows\n",
            nrow(manifest), format(length(unique(all_uei)), big.mark = ","),
            format(sum(manifest$n_uei), big.mark = ","),
            format(sum(manifest$n_rows), big.mark = ",")))
cat(sprintf("UEIs appearing in >1 shard: %d%s\n", length(dupes),
            if (length(dupes)) paste0(" (", paste(dupes, collapse = ", "), ")") else ""))
print(manifest)
