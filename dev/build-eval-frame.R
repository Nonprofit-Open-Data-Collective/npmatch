#!/usr/bin/env Rscript
# ============================================================================
# build-eval-frame.R  —  one-pass build of the shareable evaluation dataset
#
# Produces three archival artifacts over the 1,502-case labeled set
# (1,000 random + 502 hard), matched against the UNIFIED BMF (active+inactive):
#
#   1. data-dev/EVAL-FRAME-1502-MERGED.csv  — candidate-level rich frame
#         (np_route review schema: similarities, veto, USS_/BMF_/SAM_ context)
#         JOINED with the ground-truth master. The colleague-facing deliverable
#         and the archival superset.
#   2. data-dev/MATCH-REPORT-1502.csv       — query-level: current algo tier/pick
#         vs. ground truth (recall / precision / specificity, FP, FN) split by
#         sample_type and outcome_class.
#   3. data-dev/TRAINING-PAIRS-1502.csv     — model-training projection: one row
#         per scored candidate pair (features + boolean label). A SUBSET of (1).
#
# Checkpointed: the expensive cascade result is cached to RES-EVAL-UNIFIED.rds
# and the raw np_route frame to EVAL-FRAME-UNIFIED-RAW.rds; delete those to force
# a rebuild. Re-running only redoes the fast join/report/projection stages.
# ============================================================================
suppressWarnings(suppressMessages({library(data.table)}))
t0 <- proc.time()["elapsed"]
say <- function(...) cat(sprintf(...), "\n")

PKG <- "C:/Users/jdlec/Dropbox/00 - URBAN/00-GITHUB/npmatch"
DD  <- file.path(PKG, "data-dev")
RAW <- file.path(PKG, "data-raw")
REF_CSV <- file.path(RAW, "bmf_unified_geocoded.csv")

RES_RDS   <- file.path(DD, "RES-EVAL-UNIFIED.rds")        # checkpoint: cascade result
FRAME_RDS <- file.path(DD, "EVAL-FRAME-UNIFIED-RAW.rds")  # checkpoint: np_route review frame
MASTER    <- file.path(DD, "GROUNDTRUTH-MASTER-1502.csv")
OUT_MERGED <- file.path(DD, "EVAL-FRAME-1502-MERGED.csv")
OUT_REPORT <- file.path(DD, "MATCH-REPORT-1502.csv")
OUT_PAIRS  <- file.path(DD, "TRAINING-PAIRS-1502.csv")

suppressWarnings(suppressMessages(devtools::load_all(PKG, quiet = TRUE)))

digits <- function(x) gsub("[^0-9]", "", x)
snake  <- function(nm) { nm <- tolower(nm); nm <- gsub("[^a-z0-9]+", "_", nm); gsub("^_|_$", "", nm) }

# ---- ground-truth master + query id sets --------------------------------------
M <- fread(MASTER, colClasses = "character")
rand_uei <- M[sample_type == "random", uei]
hard_uei <- M[sample_type == "hard",   uei]
say("master: %d rows (%d random, %d hard)", nrow(M), length(rand_uei), length(hard_uei))

# ============================ STAGE A: cascade =================================
if (file.exists(RES_RDS) && file.exists(FRAME_RDS)) {
  say("[checkpoint] loading cached cascade result + frame")
  res   <- readRDS(RES_RDS)
  frame <- readRDS(FRAME_RDS)
} else {
  # ---- raw SAM queries (1,502): random from RANDOM-1K, hard from ALL-NONPROFITS
  load_sam <- function(f) { d <- fread(file.path(DD, f), colClasses = "character"); setnames(d, snake(names(d))); d }
  q_rand <- load_sam("RANDOM-1K.csv")
  q_all  <- load_sam("ALL-NONPROFITS.CSV")
  q_hard <- q_all[unique_entity_id %in% hard_uei]
  qy <- rbind(q_rand[unique_entity_id %in% rand_uei], q_hard, fill = TRUE)
  qy <- qy[!duplicated(unique_entity_id)]
  stopifnot(all(M$uei %in% qy$unique_entity_id))
  say("queries assembled: %d (all 1,502 present: %s)", nrow(qy), all(M$uei %in% qy$unique_entity_id))

  # ---- unified reference (3.69M) with active flag joined from the name index
  say("reading unified BMF ... (large)")
  ref_raw <- fread(REF_CSV, colClasses = list(character = "ein"))
  idx <- as.data.table(readRDS(file.path(DD, "BMF-NAME-INDEX.rds")))
  idx[, eind := digits(ein)]; act <- idx[!duplicated(eind), .(eind, active)]
  ref_raw[, eind := digits(ein)]
  ref_raw[act, on = "eind", active := i.active]
  ref_raw[is.na(active), active := FALSE]
  ref_raw[, eind := NULL]
  say("unified reference: %d rows | active: %d | inactive: %d",
      nrow(ref_raw), sum(ref_raw$active), sum(!ref_raw$active))

  ref <- np_reference(ref_raw, np_map_bmf(active_col = "active"))
  say("running cascade (this is the ~hour step) ...")
  res <- np_cascade(qy, ref, query_map = np_map_sam(), verbose = TRUE)
  saveRDS(res, RES_RDS); say("[checkpoint] saved %s", basename(RES_RDS))

  # ---- rich review frame (candidate-level). Slim raw BMF to columns np_route needs.
  tok <- tryCatch(readRDS(file.path(DD, "TOKEN-IDF.rds")), error = function(e) NULL)
  frame <- np_route(res, bmf = ref_raw, sam = qy, token_idf = tok)$review
  saveRDS(frame, FRAME_RDS); say("[checkpoint] saved %s (%d rows x %d cols)",
                                 basename(FRAME_RDS), nrow(frame), ncol(frame))
  rm(ref_raw, ref, qy, q_all, q_rand, q_hard); gc()
}

# ============================ STAGE B: join + reports ==========================
frame <- as.data.table(frame)
id_col  <- if ("uei" %in% names(frame)) "uei" else names(frame)[1]
ein_col <- if ("ein" %in% names(frame)) "ein" else grep("ein", names(frame), value = TRUE)[1]
say("frame id col: %s | ein col: %s", id_col, ein_col)

# ---- (1) MERGED candidate-level frame: broadcast GT by uei, flag the true ein per row
gtcols <- c("sample_type","sam_name","gt_is_match","gt_outcome_class","gt_ein",
            "gt_ein_in_bmf","gt_ein_bmf_active","gt_method","gt_method_detail",
            "gt_confidence","gt_notes","labeled_by","label_date")
merged <- merge(frame, M[, c("uei", gtcols), with = FALSE],
                by.x = id_col, by.y = "uei", all.x = TRUE, sort = FALSE)
merged[, is_gt_ein := as.integer(!is.na(gt_ein) & gt_ein != "" &
                                  digits(get(ein_col)) == digits(gt_ein))]
fwrite(merged, OUT_MERGED)
say("[out] %s : %d rows x %d cols", basename(OUT_MERGED), nrow(merged), ncol(merged))

# ---- query-level current algo decision from the tiered result
res <- as.data.table(res)
ql <- res[, .(uei = as.character(.id),
              algo_tier = as.character(tier),
              algo_pick = overall_ein,
              algo_score = overall_score)]
D <- merge(M[, .(uei, sample_type, gt_is_match, gt_outcome_class, gt_ein)], ql, by = "uei", all.x = TRUE)
D[is.na(algo_tier), algo_tier := "ZERO_CAND"]
D[, gt_is_match := gt_is_match == "TRUE"]
D[, pick_is_gt := !is.na(algo_pick) & !is.na(gt_ein) & gt_ein != "" & digits(algo_pick) == digits(gt_ein)]
D[, surfaced := algo_tier %in% c("YES","MAYBE")]
# outcome per query
D[, result := fifelse(gt_is_match & pick_is_gt & algo_tier == "YES",   "TP_auto",
              fifelse(gt_is_match & pick_is_gt & algo_tier == "MAYBE", "TP_review",
              fifelse(gt_is_match & !pick_is_gt & surfaced,            "wrong_ein_surfaced",
              fifelse(gt_is_match & !surfaced,                          "FN_missed",
              fifelse(!gt_is_match & algo_tier == "YES",               "FP_yes",
              fifelse(!gt_is_match & algo_tier == "MAYBE",             "flagged_review",
                                                                        "TN_correct_no"))))))]
fwrite(D, OUT_REPORT)
say("[out] %s : %d rows", basename(OUT_REPORT), nrow(D))

# ---- (2) printed match report
report_block <- function(ds, lab) {
  n <- nrow(ds); m <- sum(ds$gt_is_match); nm <- sum(!ds$gt_is_match)
  auto <- sum(ds$result == "TP_auto"); rev <- sum(ds$result == "TP_review")
  say("\n===== %s (n=%d | %d linkable, %d non-linkable) =====", lab, n, m, nm)
  print(table(algo_tier = ds$algo_tier, gt = ifelse(ds$gt_is_match,"linkable","non-linkable")))
  say("  recall (auto YES):        %d/%d = %.1f%%", auto, m, 100*auto/max(m,1))
  say("  recall (auto+review):     %d/%d = %.1f%%", auto+rev, m, 100*(auto+rev)/max(m,1))
  yes <- ds[algo_tier == "YES"]
  say("  precision (YES picks):    %d/%d = %.1f%%", sum(yes$pick_is_gt), nrow(yes), 100*sum(yes$pick_is_gt)/max(nrow(yes),1))
  say("  specificity (non-link NO):%d/%d = %.1f%%", sum(!ds$gt_is_match & ds$algo_tier=="NO"), nm,
      100*sum(!ds$gt_is_match & ds$algo_tier=="NO")/max(nm,1))
}
say("\n################  MATCH REPORT  (current code vs ground truth, UNIFIED BMF)  ################")
for (s in c("random","hard")) report_block(D[sample_type == s], toupper(s))
report_block(D, "ALL 1,502")
say("\n--- result breakdown x sample_type ---")
print(dcast(D[, .N, .(result, sample_type)], result ~ sample_type, value.var = "N", fill = 0))
say("\n--- outcome_class x algo_tier (ALL) ---")
print(table(outcome = D$gt_outcome_class, tier = D$algo_tier))

# ---- (3) model-training projection: one row per scored candidate pair + label
pairs <- as.data.table(attr(res, "pairs"))
if (!is.null(pairs) && nrow(pairs)) {
  gtmap <- M[, .(uei, gt_ein_d = digits(gt_ein))]
  pairs[, uei := as.character(.id)]
  pairs <- merge(pairs, gtmap, by = "uei", all.x = TRUE)
  pairs[, label := as.integer(!is.na(gt_ein_d) & gt_ein_d != "" & digits(.ein) == gt_ein_d)]
  keep <- intersect(c("uei",".ein","name_sim","addr_sim","score","geo_state","geo_zip5",
                      "geo_zip9","geo_stnum","geo_pobox","pass","name_match_type","label"), names(pairs))
  fwrite(pairs[, ..keep], OUT_PAIRS)
  say("\n[out] %s : %d pairs (%d positive labels)", basename(OUT_PAIRS), nrow(pairs), sum(pairs$label))
} else say("\n[warn] no pairs attr on res; skipped training projection")

say("\nDONE in %.1f min", (proc.time()["elapsed"] - t0)/60)
