#!/usr/bin/env Rscript
# ===========================================================================
# Build STAGE-03-SECONDARY-REVIEW.xlsx: every UEI whose group in the by_state
# review workbooks has a row with a blank is_best_candidate, plus all of that
# UEI's other rows, with the blank stage-1 attributes filled in.
#
# The blank rows are the synthetic rows the final rollup adds:
#   * stage3_research -- an EIN stage 3 found that stage 1 never surfaced
#                        (np_final_run(), R/final.R)
#   * none            -- a registrant stage 1 surfaced no candidate for
#                        (added by the combined 2025NOV + 2026MAY build)
# Both carry NA for every candidate-level column, by construction.
#
# Fill sources, in order of preference -- only blank cells are filled:
#   1. stage 1's own scored pairs (01_stage1/interim/pairs-*.rds), verbatim,
#      when stage 1 scored the (UEI, EIN) pair but did not shortlist it
#   2. np_normalize / np_compare / np_score / np_veto against the same
#      reference cache stage 1 used, when stage 1 never generated the pair
#   3. the run's 00_sams/sam_query.csv, normalized as stage 1 does, for the
#      SAM-side fields (the only side a `none` row has)
#
# Writes the all-states workbook, one workbook per state (same state grouping
# as review/by_state) under review/stage3_by_state/, and a zip of those.
#
# Steps are cached in <run>/review/_secondary-review-work/; pass --fresh to
# redo them. Rough cost: load ~5 min, scan ~15 min, recompute ~3 min.
#
# Usage:  Rscript stage3-secondary-review.R [--fresh]
# ===========================================================================

suppressMessages({ library(data.table); library(openxlsx) })

HERE <- normalizePath(dirname(sub("^--file=", "",
          grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), winslash = "/")
REPO <- normalizePath(file.path(HERE, "..", ".."), winslash = "/")
suppressMessages(pkgload::load_all(REPO, quiet = TRUE))

BASE  <- Sys.getenv("NPMATCH_RUN_DIR", file.path(REPO, "data-dev/runs/COMBINED_RESULTS"))
RUNS  <- dirname(BASE)                                  # holds 2025NOV/, 2026MAY/
RUN_IDS <- c("2025NOV", "2026MAY")
CACHE <- file.path(REPO, "data-dev/NORM-BMF-UNIFIED-v2.rds")   # what stage 1 used (see its logs)
STDIR <- file.path(BASE, "review", "by_state")
WORK  <- file.path(BASE, "review", "_secondary-review-work")
OUT   <- file.path(BASE, "review", "STAGE-03-SECONDARY-REVIEW.xlsx")
ST3DIR <- file.path(BASE, "review", "stage3_by_state")          # one workbook per state
ZIP   <- file.path(BASE, "review", "STAGE-03-SECONDARY-REVIEW_by_state.zip")
FRESH <- "--fresh" %in% commandArgs(TRUE)
dir.create(WORK, recursive = TRUE, showWarnings = FALSE)

msg   <- function(...) { cat(sprintf(...), "\n"); flush.console() }
blank <- function(v) is.na(v) | v == ""
cnt   <- function(x) format(x, big.mark = ",")
cached <- function(name, expr) {
  f <- file.path(WORK, paste0(name, ".rds"))
  if (!FRESH && file.exists(f)) { msg("[%s] reusing %s", name, basename(f)); return(readRDS(f)) }
  t0 <- Sys.time(); v <- expr; saveRDS(v, f)
  msg("[%s] done in %.1f min", name, as.numeric(difftime(Sys.time(), t0, units = "mins")))
  v
}

## ------------------------------------------- 1. load the state workbooks ----
# Read as text so ZIPs keep their leading zeros and nothing is re-typed.
sel <- cached("selection", {
  fs <- list.files(STDIR, pattern = "^eval_frame_.*[.]xlsx$", full.names = TRUE)
  all <- rbindlist(lapply(fs, function(f) {
    x <- as.data.table(readxl::read_excel(f, sheet = "eval_frame", col_types = "text"))
    x[, state_file := sub("^eval_frame_(.*)[.]xlsx$", "\\1", basename(f))]
    msg("  %-22s %7s rows", basename(f), cnt(nrow(x))); x
  }), use.names = TRUE, fill = TRUE)
  tu <- unique(all$uei[blank(all$is_best_candidate)])
  msg("  %s rows in %d files; %s UEIs have a blank is_best_candidate",
      cnt(nrow(all)), length(fs), cnt(length(tu)))
  all[uei %in% tu]
})
sel <- copy(sel)
syn <- sel[candidate_source != "cascade"]
tu  <- unique(syn$uei)
msg("selection: %s rows, %s UEIs (%s stage3_research, %s none)", cnt(nrow(sel)), cnt(length(tu)),
    cnt(sum(syn$candidate_source == "stage3_research")), cnt(sum(syn$candidate_source == "none")))

## ------------------------------- 2. scan stage 1's scored pairs per UEI ----
# Every pair stage 1 scored, before the top-k shortlist. Tells us, per UEI, how
# many pairs were scored / survived the hard veto, and whether the stage-3 EIN
# was among them (and at what rank).
keys <- syn[candidate_source == "stage3_research", paste(uei, ein)]
scan <- cached("scan", {
  hits <- list(); stats <- list()
  for (run in RUN_IDS) {
    fs <- sort(list.files(file.path(RUNS, run, "01_stage1", "interim"),
                          "^pairs-[0-9]+[.]rds$", full.names = TRUE))
    for (f in fs) {
      p <- as.data.table(readRDS(f))[.id %in% tu]
      if (!nrow(p)) next
      p[, score_rank := frank(-score, ties.method = "min"), by = .id]
      stats[[f]] <- p[, .(stage1_pairs_scored = .N, stage1_pairs_unvetoed = sum(!veto),
                          stage1_best_score = max(score)), by = .(uei = .id)]
      h <- p[paste(.id, .ein) %in% keys]
      if (nrow(h)) hits[[f]] <- h
      msg("  %s %s: %s pairs for target UEIs, %d stage-3 EINs found",
          run, basename(f), cnt(nrow(p)), nrow(h))
    }
  }
  S <- rbindlist(stats)[, .(stage1_pairs_scored = sum(stage1_pairs_scored),
                            stage1_pairs_unvetoed = sum(stage1_pairs_unvetoed),
                            stage1_best_score = max(stage1_best_score)), by = uei]
  list(hits = rbindlist(hits, fill = TRUE), stats = S)
})
msg("scan: %s of %s stage-3 EINs were scored by stage 1", cnt(nrow(scan$hits)), cnt(length(keys)))

## ------------------------------ 3. recompute the pairs stage 1 never saw ----
rcmp <- cached("recompute", {
  q <- rbindlist(lapply(RUN_IDS, function(run) {
    x <- fread(file.path(RUNS, run, "00_sams", "sam_query.csv"),
               colClasses = "character", showProgress = FALSE)
    setnames(x, .np_norm_headers(names(x)))
    x[unique_entity_id %in% tu]
  }), use.names = TRUE, fill = TRUE)
  q <- q[!duplicated(unique_entity_id)]
  msg("  SAM records found for %s of %s target UEIs", cnt(nrow(q)), cnt(length(tu)))
  qn <- np_normalize(np_query(as.data.frame(q), np_map_sam()))
  qn$.id <- as.character(qn$.id)

  msg("  loading %s ...", basename(CACHE))
  cc  <- readRDS(CACHE)
  ref <- cc$reference
  todo <- syn[candidate_source == "stage3_research" & !blank(ein) &
                !paste(uei, ein) %in% paste(scan$hits$.id, scan$hits$.ein), .(uei, ein)]
  rsub <- ref[ref$.ein %in% todo$ein, , drop = FALSE]
  cand <- merge(data.frame(uei = todo$uei, ein = todo$ein),
                data.frame(.y = seq_len(nrow(rsub)), ein = rsub$.ein), by = "ein")
  cand$.x <- match(cand$uei, qn$.id)
  not_in_ref <- setdiff(paste(todo$uei, todo$ein), paste(cand$uei, cand$ein))
  cand <- cand[!is.na(cand$.x), ]
  msg("  recomputing %s pairs (%d EINs absent from the reference)", cnt(nrow(todo)), length(not_in_ref))
  blk <- structure(data.frame(.x = cand$.x, .y = cand$.y), class = c("np_blocks", "data.frame"))
  pr <- np_veto(np_score(np_compare(qn, rsub, np_config(), candidates = blk,
                                    name_freq = cc$name_freq, token_idf = cc$token_idf),
                         np_config(), method = "hier"))
  rc <- as.data.table(as.data.frame(pr))
  rc[, pass := "not_blocked"]
  setorder(rc, .id, .ein, -score)
  rc <- rc[!duplicated(paste(.id, .ein))]   # best BMF row per EIN, as np_select would
  list(qn = qn, rc = rc, not_in_ref = not_in_ref, token_idf = cc$token_idf)
})
token_idf <- rcmp$token_idf

## ------------------------------------- 4. pair rows -> reviewer schema ----
# Mirrors np_route() + .np_candidates(): name_sim is the name_key similarity,
# addr_sim the mean of the address similarities, then .np_review_layout().
annotate_tok <- function(v) {
  maxidf <- max(token_idf, na.rm = TRUE)
  vapply(strsplit(ifelse(is.na(v), "", as.character(v)), "\\s+"), function(t) {
    t <- .np_collapse_initials(t)
    t <- t[nchar(t) >= 2 & !(t %in% np_stopwords())]
    if (!length(t)) return("")
    w <- token_idf[t]; w[is.na(w)] <- maxidf
    o <- order(-w); paste(sprintf("%s(%.1f)", t[o], w[o]), collapse = " ")
  }, character(1))
}
as_text <- function(dt) {
  dt[, names(dt) := lapply(.SD, function(v) { v <- as.character(v); v[v %in% c("NA", "NaN", "")] <- NA; v })]
}
to_review <- function(p) {
  p <- as.data.frame(p)
  p$name_sim <- p$name_key
  acols <- intersect(c("street_key", "city", "county", "zip5", "street_unit"), names(p))
  p$addr_sim <- rowMeans(p[, acols, drop = FALSE], na.rm = TRUE)
  p$name_tok_x <- annotate_tok(p$name_key_x); p$name_tok_y <- annotate_tok(p$name_key_y)
  for (c2 in intersect(c("name_sim", "addr_sim", "street_key", "city", "zip5"), names(p)))
    p[[c2]] <- round(as.numeric(p[[c2]]), 2)
  p$score <- round(as.numeric(p$score), 3)
  p$match_layer <- p$pass
  as_text(as.data.table(.np_review_layout(p, "uss", "bmf", "uei")))
}
hits <- copy(scan$hits)
rank_info <- hits[, .(uei = .id, ein = .ein, stage1_score_rank = score_rank)]
rv <- rbind(to_review(hits[, !"score_rank"])[, .fill := "stage1_pairs"],
            to_review(rcmp$rc)[, .fill := "recomputed"], fill = TRUE)

qn <- as.data.frame(rcmp$qn)
sam <- as_text(data.table(uei = qn$.id,
  match_name_uss = qn$name_full, name_uss_raw_main = qn$name, name_uss_raw_dba = qn$dba,
  name_uss_raw_division = qn$division, name_uss_normalized = qn$name_key,
  name_uss_org_type = qn$name_form, name_uss_tokenized = annotate_tok(qn$name_key),
  street_uss = qn$street, street_uss_normalized = qn$street_key, city_uss = qn$city,
  state_uss = qn$state, zip5_uss = qn$zip5,
  name_gen_uss = qn$name_gen, name_gen_rank_uss = qn$name_gen_rank,
  name_nums_uss = qn$name_nums, name_ord_uss = qn$name_ord, name_dir_uss = qn$name_dir))

## ------------------------------------------------------------ 5. fill ----
orig_cols <- setdiff(names(sel), "state_file")
sel[, .i := .I]
is_syn <- sel$candidate_source != "cascade"
filled <- matrix(FALSE, nrow(sel), length(orig_cols), dimnames = list(NULL, orig_cols))
put <- function(i, col, val) {                       # fill blanks only; record what was filled
  if (!col %in% orig_cols || !length(i)) return(invisible())
  if (length(val) == 1L) val <- rep(val, length(i))
  ok <- blank(sel[[col]][i]) & !blank(val)
  if (any(ok)) { set(sel, i[ok], col, as.character(val[ok])); filled[i[ok], col] <<- TRUE }
}

# (a) pair-level fields for the stage3_research rows
i_s3 <- which(sel$candidate_source == "stage3_research")
m <- match(paste(sel$uei, sel$ein)[i_s3], paste(rv$uei, rv$ein))
i_hit <- i_s3[!is.na(m)]; m <- m[!is.na(m)]
for (col in setdiff(intersect(names(rv), orig_cols), c("uei", "ein"))) put(i_hit, col, rv[[col]][m])
sel[, fill_source := NA_character_]
sel[i_hit, fill_source := rv$.fill[m]]

# (b) SAM-side fields for every synthetic row (no-op where (a) already filled them)
i_syn <- which(is_syn)
ms <- match(sel$uei[i_syn], sam$uei)
for (col in setdiff(names(sam), "uei")) put(i_syn, col, sam[[col]][ms])

# (c) UEI-level values, constant within a UEI, from its cascade rows
uei_cols <- c("size_uss", "match_decision", "decision_reason", "num_of_candidates")
sib <- sel[candidate_source == "cascade",
           lapply(.SD, function(v) { v <- v[!blank(v)]; if (length(v)) v[1] else NA_character_ }),
           by = uei, .SDcols = uei_cols]
mb <- match(sel$uei[i_syn], sib$uei)
for (col in uei_cols) put(i_syn, col, sib[[col]][mb])

# ... and for UEIs with no cascade row at all, stage 1 surfaced nothing
st <- scan$stats
n_scored <- st$stage1_pairs_scored[match(sel$uei, st$uei)]; n_scored[is.na(n_scored)] <- 0L
i_lone <- i_syn[is.na(mb)]
put(i_lone, "num_of_candidates", "0")
put(i_lone, "match_decision", "NO")
put(i_lone, "decision_reason", ifelse(n_scored[i_lone] > 0,
  "no candidate surfaced (every stage-1 pair was hard-vetoed)",
  "no candidate at all (stage-1 blocking generated no pairs)"))

# (d) synthetic-row markers. is_best_candidate = 0 on every synthetic row,
# MATCH or NO_MATCH: none of them was stage 1's pick.
i_none <- which(sel$candidate_source == "none")
put(i_syn,  "is_best_candidate", "0")
put(i_s3,   "candidate_type", "stage3_research")
put(i_none, "candidate_type", "none")
sel[is_syn & is.na(fill_source), fill_source := "sam_source"]
sel[!is_syn, fill_source := "original"]

## ---------------------------------------------- 6. stage-1 diagnostics ----
sel[st, on = "uei", `:=`(stage1_pairs_scored = i.stage1_pairs_scored,
                         stage1_pairs_unvetoed = i.stage1_pairs_unvetoed,
                         stage1_best_score = i.stage1_best_score)]
sel[is.na(stage1_pairs_scored), `:=`(stage1_pairs_scored = 0L, stage1_pairs_unvetoed = 0L)]
# fully_vetoed: stage 1 scored pairs for this UEI but the hard veto removed every
# one, so nothing could be surfaced. Constant across the UEI's rows. Flags a
# veto-rule question, not a merge one.
sel[, fully_vetoed := as.integer(stage1_pairs_scored > 0 & stage1_pairs_unvetoed == 0)]
sel[rank_info, on = c("uei", "ein"), stage1_score_rank := i.stage1_score_rank]
sel[candidate_source == "cascade", stage1_score_rank := NA]
sel[, stage1_pair_status := fcase(
  candidate_source == "cascade", "surfaced",
  candidate_source == "none", fifelse(stage1_pairs_scored > 0, "no_candidates_surfaced", "no_candidates"),
  paste(uei, ein) %in% rcmp$not_in_ref, "ein_not_in_bmf_reference",
  fill_source == "stage1_pairs" & veto %in% c("TRUE", "1"), "scored_vetoed",
  fill_source == "stage1_pairs", "scored_not_surfaced",
  fill_source == "recomputed", "not_blocked",
  default = NA_character_)]
sel[, filled_columns := apply(filled, 1, function(r) paste(names(r)[r], collapse = "; "))]
sel[filled_columns == "", filled_columns := NA]

msg("filled %s cells across %s rows", cnt(sum(filled)), cnt(sum(rowSums(filled) > 0)))
print(sel[candidate_source != "cascade", .N, by = .(candidate_source, stage1_pair_status)][order(candidate_source, -N)])
msg("fully_vetoed: %s UEIs (%s of them `none` rows)", cnt(uniqueN(sel[fully_vetoed == 1]$uei)),
    cnt(sum(sel$fully_vetoed == 1 & sel$candidate_source == "none")))
still <- vapply(orig_cols, function(cl) sum(blank(sel[[cl]][is_syn])), integer(1))
msg("columns still blank on some synthetic rows (by design: no EIN / no revenue / unmatched size_uss):")
print(still[still > 0])

## -------------------------------------------------- 7. order + types ----
setorder(sel[, .so := match(candidate_source, c("cascade", "stage3_research", "none"))],
         state_file, uei, .so, .i)
filled <- filled[sel$.i, , drop = FALSE]
sel[, c(".so", ".i") := NULL]
NEW_COLS <- c("state_file", "fill_source", "stage1_pair_status", "fully_vetoed", "stage1_score_rank",
              "stage1_pairs_scored", "stage1_pairs_unvetoed", "stage1_best_score", "filled_columns")
setcolorder(sel, c(setdiff(orig_cols, "_band"), NEW_COLS, "_band"))
sel[, `_band` := as.integer(cumsum(uei != shift(uei, fill = "\u0001")) %% 2L == 0L)]

KEEP_TEXT <- c("zip5_uss", "zip5_bmf", "uei", "ein", "final_ein", "llm_ein_found")
num_ok <- function(x) { v <- x[!blank(x)]
  length(v) > 0 && all(grepl("^[+-]?(\\d+\\.?\\d*|\\.\\d+)([eE][+-]?\\d+)?$", v)) }
chr <- names(sel)[vapply(sel, is.character, logical(1))]
num_cols <- setdiff(chr[vapply(sel[, ..chr], num_ok, logical(1))], KEEP_TEXT)
sel[, (num_cols) := lapply(.SD, as.numeric), .SDcols = num_cols]

## ----------------------------------------------------------- 8. write ----
HDR_FILL <- "#44546A"; NEW_FILL <- "#2E75B6"; BAND_FILL <- "#F2F2F2"; TOP_FILL <- "#FCE4D6"
hdr <- function(fill) createStyle(fgFill = fill, fontColour = "#FFFFFF", textDecoration = "bold",
                                  halign = "left", valign = "center", border = "TopBottomLeftRight",
                                  borderColour = "#2F3B4F")
fill_font <- createStyle(fontColour = "#1F4E9E", textDecoration = "italic")
wrap_top  <- createStyle(wrapText = TRUE, valign = "top")
SH <- "secondary_review"

# One workbook: the review sheet, an `about` sheet and a `summary` sheet. Used
# for the all-states file and for each per-state file; `scope` names the slice.
write_review <- function(dt, fl, path, scope) {
  dt <- copy(dt)
  # Parity on the rows actually written, so groups alternate within each file.
  dt[, `_band` := as.integer(cumsum(uei != shift(uei, fill = "\u0001")) %% 2L == 0L)]
  n <- nrow(dt); nc <- ncol(dt)

  wb <- createWorkbook()
  addWorksheet(wb, SH)
  writeData(wb, SH, dt, headerStyle = hdr(HDR_FILL), withFilter = TRUE)
  addStyle(wb, SH, hdr(NEW_FILL), rows = 1, cols = match(NEW_COLS, names(dt)), gridExpand = TRUE)
  freezePane(wb, SH, firstActiveRow = 2, firstActiveCol = 6)
  setColWidths(wb, SH, cols = 1:nc, widths = 14)
  setColWidths(wb, SH, cols = grep(paste0("name_|street|reason|notes|judgement|sources|web_|path|",
                                          "definition|tokenized|status_basis|filled_columns"), names(dt)),
               widths = 45)
  setColWidths(wb, SH, cols = 1, widths = 18)
  setColWidths(wb, SH, cols = nc, widths = 8, hidden = TRUE)
  # Filled cells get a font style; the row shading is conditional formatting,
  # which only sets the fill, so the two compose.
  for (cl in colnames(fl)) {
    r <- which(fl[, cl]); if (!length(r)) next
    addStyle(wb, SH, fill_font, rows = r + 1, cols = match(cl, names(dt)), gridExpand = TRUE, stack = TRUE)
  }
  band_ref <- paste0("$", int2col(nc)); top_ref <- paste0("$", int2col(match("is_final_ein", names(dt))))
  conditionalFormatting(wb, SH, cols = 1:nc, rows = 2:(n + 1), type = "expression",
                        rule = sprintf("%s2=1", top_ref), style = createStyle(bgFill = TOP_FILL))
  conditionalFormatting(wb, SH, cols = 1:nc, rows = 2:(n + 1), type = "expression",
                        rule = sprintf("AND(%s2=1,%s2<>1)", band_ref, top_ref),
                        style = createStyle(bgFill = BAND_FILL))

  sy <- dt[candidate_source != "cascade"]
  about <- data.frame(Item = c(
    "What this is", "Scope", "Rows", "How rows were chosen", "What was filled", "Blue italic text",
    "fill_source", "stage1_pair_status", "fully_vetoed", "stage1_score_rank",
    "stage1_pairs_scored / _unvetoed / stage1_best_score",
    "is_best_candidate on filled rows", "num_of_candidates on filled rows", "state_file",
    "filled_columns", "Shading", "Known issue", "Rebuild"),
    Detail = c(
    "Secondary review of the stage-3 merge: every UEI whose group in the by_state review workbooks has a row with a blank is_best_candidate, plus all other rows for that UEI.",
    scope,
    sprintf("%s rows, %s UEIs (%s rows with blank is_best_candidate: %s stage3_research + %s none; %s sibling cascade rows).",
            cnt(n), cnt(uniqueN(dt$uei)), cnt(nrow(sy)), cnt(sum(sy$candidate_source == "stage3_research")),
            cnt(sum(sy$candidate_source == "none")), cnt(sum(dt$candidate_source == "cascade"))),
    "Read from every eval_frame_<STATE>.xlsx in review/by_state. Every row with a blank is_best_candidate is a synthetic row added by the final rollup (stage3_research: an EIN stage 3 found that stage 1 never surfaced) or by the combined build (none: a registrant stage 1 surfaced no candidate for). Each UEI keeps the state it was assigned in review/by_state.",
    "Only cells that were blank are filled; no existing value was changed. Pair-level fields (similarities, scores, BMF-side names and address, geo flags, veto) come from stage 1's own scored pair files (01_stage1/interim/pairs-*.rds) when stage 1 scored the pair, or are recomputed with npmatch's np_normalize/np_compare/np_score/np_veto against the same reference cache stage 1 used (NORM-BMF-UNIFIED-v2.rds) when it did not. SAM-side fields come from each run's 00_sams/sam_query.csv, normalized the same way stage 1 does.",
    "Marks every cell that was blank and has been filled by this build.",
    "original = untouched cascade row; stage1_pairs = values taken verbatim from stage 1's scored pairs; recomputed = pair never generated by stage-1 blocking, features recomputed; sam_source = only SAM-side fields could be filled (no EIN on the row).",
    "surfaced = normal cascade candidate; scored_not_surfaced = stage 1 blocked and scored this EIN but it missed the shortlist (top 3 + best name + best address) - a SCORING miss; scored_vetoed = stage 1 scored this EIN but a hard veto removed it (see veto_reason) - a VETO miss; not_blocked = stage 1 never generated this pair - a BLOCKING miss; ein_not_in_bmf_reference = the EIN is not in the reference stage 1 searched; no_candidates = stage 1 generated no pairs for this UEI; no_candidates_surfaced = pairs were generated but every one was vetoed.",
    sprintf("1 when stage 1 scored at least one pair for the UEI and the hard veto removed every one, so nothing could be surfaced. Set on all of the UEI's rows. %s UEIs in this file. These are veto-rule questions, not merge ones - see veto_reason on the stage1 pairs.",
            cnt(uniqueN(dt[fully_vetoed == 1]$uei))),
    "For stage-1-scored stage3_research rows: where this EIN ranked by total_score among all pairs stage 1 scored for the UEI (1 = best).",
    "Per UEI, from stage 1's scored pair files: pairs scored, pairs that survived the hard veto, and the best total_score among them.",
    "0 on every filled row, MATCH or NO_MATCH - the row was not stage 1's pick (stage 1 never surfaced it).",
    "stage3_research rows carry the UEI's surfaced-candidate count (the same value as its cascade rows); rows for a UEI with no cascade row carry 0.",
    "Which by_state workbook the UEI came from.",
    "The list of columns filled on this row.",
    "Light orange = is_final_ein = 1 (THE MATCH for the UEI). Gray/white bands alternate per UEI (hidden _band column).",
    sprintf("%s stage3_research rows in this file are NO_MATCH with an EIN but a blank final_ein (the anomaly noted in dev/review-workbooks/README.md). They are included and filled like the others.",
            cnt(sum(sy$candidate_source == "stage3_research" & sy$final_outcome == "NO_MATCH"))),
    "Rscript dev/review-workbooks/stage3-secondary-review.R [--fresh]"),
    stringsAsFactors = FALSE)
  addWorksheet(wb, "about")
  writeData(wb, "about", about, headerStyle = hdr(HDR_FILL))
  setColWidths(wb, "about", cols = 1:2, widths = c(34, 120))
  addStyle(wb, "about", wrap_top, rows = 2:(nrow(about) + 1), cols = 1:2, gridExpand = TRUE)

  addWorksheet(wb, "summary")
  writeData(wb, "summary", headerStyle = hdr(HDR_FILL),
            sy[, .N, by = .(candidate_source, final_outcome, stage1_pair_status, fully_vetoed, fill_source)
               ][order(candidate_source, -N)])
  writeData(wb, "summary", sy[, .N, by = state_file][order(-N)], startCol = 8, headerStyle = hdr(HDR_FILL))
  setColWidths(wb, "summary", cols = 1:9, widths = c(18, 14, 26, 13, 14, 8, 2, 12, 10))

  # A workbook open in Excel is locked and openxlsx only warns; verify the write.
  before <- if (file.exists(path)) file.mtime(path) else NA
  ok <- tryCatch({ suppressWarnings(saveWorkbook(wb, path, overwrite = TRUE))
                   file.exists(path) && (is.na(before) || file.mtime(path) > before) },
                 error = function(e) FALSE)
  if (!ok) { path <- sub("\\.xlsx$", "-NEW.xlsx", path)
             msg("  ! target is locked (open in Excel) - writing %s instead", basename(path))
             saveWorkbook(wb, path, overwrite = TRUE) }
  path
}

## all states in one workbook
p <- write_review(sel, filled, OUT, "All states.")
msg("wrote %s (%.1f MB)", p, file.size(p) / 1e6)

## one workbook per state (the same grouping as review/by_state), then a zip
dir.create(ST3DIR, showWarnings = FALSE)
unlink(list.files(ST3DIR, "^STAGE-03-SECONDARY-REVIEW_.*[.]xlsx$", full.names = TRUE))
states <- sel[, .N, by = state_file][order(-N)]$state_file
paths <- vapply(states, function(g) {
  i <- which(sel$state_file == g)
  p <- write_review(sel[i], filled[i, , drop = FALSE],
                    file.path(ST3DIR, sprintf("STAGE-03-SECONDARY-REVIEW_%s.xlsx", g)),
                    sprintf("State file: %s (UEIs assigned to %s in review/by_state).", g, g))
  msg("  %-8s %6s rows  %5.1f MB", g, cnt(length(i)), file.size(p) / 1e6)
  p
}, character(1))
if (file.exists(ZIP)) file.remove(ZIP)
zip::zip(ZIP, files = basename(paths), root = ST3DIR)
msg("wrote %d state workbooks -> %s", length(paths), ST3DIR)
msg("zipped -> %s (%.1f MB)", ZIP, file.size(ZIP) / 1e6)
