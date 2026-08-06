# Human-readable explanation of why each query landed in its tier.
.np_route_reason <- function(tiered, yes, maybe, min_margin) {
  s <- tiered$decision_score
  tier <- as.character(tiered$tier)
  mg <- tiered$overall_margin
  ru <- tiered$runner_up_score
  va <- tiered$views_agree
  vs <- tiered$overall_veto_soft
  vr <- tiered$overall_veto_reason
  ne <- tiered$name_ein; ae <- tiered$addr_ein
  vapply(seq_len(nrow(tiered)), function(i) {
    if (tier[i] == "YES")
      return(sprintf("auto-accepted (score %.2f >= %.2f, margin %.2f)", s[i], yes,
                     if (is.null(mg)) NA_real_ else mg[i]))
    if (tier[i] == "NO")
      return(sprintf("best score %.2f below review floor %.2f", s[i], maybe))
    parts <- character(0)
    if (s[i] >= yes && !is.null(mg) && !is.na(mg[i]) && mg[i] < min_margin)
      parts <- c(parts, sprintf("near-tie: runner-up %.2f (margin %.2f)", ru[i], mg[i]))
    if (s[i] < yes && s[i] >= maybe)
      parts <- c(parts, sprintf("score %.2f in review band [%.2f, %.2f)", s[i], maybe, yes))
    if (isTRUE(vs[i]))
      parts <- c(parts, paste0("soft veto: ", vr[i]))
    if (isFALSE(va[i]))
      parts <- c(parts, sprintf("name/address views differ (name->%s, addr->%s)",
                                ne[i], ae[i]))
    if (!length(parts)) parts <- "held for review"
    paste(parts, collapse = "; ")
  }, character(1))
}

# Rename pipeline columns to the human-facing review schema. Explicit map for the
# match-summary and name/address progression fields; a generic `_x`/`_y` ->
# source/reference swap for the remaining display, geo and veto-feature columns.
.np_rename_review <- function(nm, source, reference, id_label) {
  s <- source; r <- reference
  m <- c(
    ".id" = id_label, ".ein" = "ein",
    "name_sim" = "name_similarity", "addr_sim" = "addr_similarity", "score" = "total_score",
    # name match summary
    "name_x" = paste0("match_name_", s),     "name_y" = paste0("match_name_", r),
    "name_ver_x" = paste0("match_version_", s), "name_ver_y" = paste0("match_version_", r),
    "name_match_type" = "match_type", "name_freq" = "normalized_match_count",
    # name cleaning progression
    "name_raw_x" = paste0("name_", s, "_raw_main"), "name_raw_y" = paste0("name_", r, "_raw_main"),
    "dba_x" = paste0("name_", s, "_raw_dba"),  "dba_y" = paste0("name_", r, "_raw_dba"),
    "division_x" = paste0("name_", s, "_raw_division"),
    "division_y" = paste0("name_", r, "_raw_division"),
    "name_key_x" = paste0("name_", s, "_normalized"), "name_key_y" = paste0("name_", r, "_normalized"),
    "name_form_x" = paste0("name_", s, "_org_type"),  "name_form_y" = paste0("name_", r, "_org_type"),
    "name_tok_x" = paste0("name_", s, "_tokenized"),  "name_tok_y" = paste0("name_", r, "_tokenized"),
    # address similarity + normalized
    "street_key" = "street_similarity", "city" = "city_similarity", "zip5" = "zip_similarity",
    "street_norm_x" = paste0("street_", s, "_normalized"),
    "street_norm_y" = paste0("street_", r, "_normalized")
  )
  out <- nm
  hit <- nm %in% names(m); out[hit] <- unname(m[nm[hit]])
  keep <- out == nm                                   # untouched: display/geo/features
  out[keep] <- sub("_x$", paste0("_", s), out[keep])
  out[keep] <- sub("_y$", paste0("_", r), out[keep])
  out
}

# Rename + order the review columns into the information hierarchy: (1) match
# strength + outcome, (2) name match summary, (3) name cleaning progression,
# (4) address (similarity -> raw -> normalized/geo), (5) imported BMF fields,
# then every remaining generated feature/stat.
.np_review_layout <- function(df, source, reference, id_label) {
  if (all(c("name_sim", "name_key") %in% names(df))) df$name_key <- NULL  # dup of name_similarity
  names(df) <- .np_rename_review(names(df), source, reference, id_label)
  s <- source; r <- reference
  front <- c(
    id_label, "ein",
    # (1) match strength + outcome
    "name_similarity", "addr_similarity", "candidate_type", "total_score",
    "num_of_candidates", "is_top_candidate", "match_decision", "match_layer",
    "decision_reason", "veto", "veto_reason", "veto_soft", "veto_soft_reason", "notes",
    # (2) name match summary
    paste0("match_name_", s), paste0("match_version_", s),
    paste0("match_name_", r), paste0("match_version_", r),
    "match_type", "normalized_match_count",
    # (3) name cleaning progression
    paste0("name_", s, "_raw_main"), paste0("name_", s, "_raw_dba"),
    paste0("name_", s, "_raw_division"),
    paste0("name_", s, "_normalized"), paste0("name_", s, "_org_type"),
    paste0("name_", s, "_tokenized"),
    paste0("name_", r, "_raw_main"), paste0("name_", r, "_raw_dba"),
    paste0("name_", r, "_raw_division"),
    paste0("name_", r, "_normalized"), paste0("name_", r, "_org_type"),
    paste0("name_", r, "_tokenized"),
    # (4) address: similarity -> raw -> normalized/geo
    "street_similarity", "city_similarity", "zip_similarity",
    paste0("street_", s), paste0("street_", r),
    paste0("city_", s),   paste0("city_", r),
    paste0("state_", s),  paste0("state_", r),
    paste0("zip5_", s),   paste0("zip5_", r),
    paste0("street_", s, "_normalized"), paste0("street_", r, "_normalized"),
    "geo_stnum", "geo_zip9", "geo_zip5", "geo_zip3", "geo_state", "geo_pobox")
  # derived fields first (front-ordered, then any remaining derived features),
  # then every imported field (BMF_ / SAM_) at the very end.
  imported <- grep("^(BMF|SAM)_", names(df), value = TRUE)
  fp <- intersect(front, names(df))
  derived_rest <- setdiff(names(df), c(fp, imported))
  df[, c(fp, derived_rest, imported), drop = FALSE]
}

# Join optional passthrough columns from a source/reference dataset by key,
# suffixing them so their provenance is explicit. Appended after the features.
.np_join_extra <- function(rev, id_col, data, key, cols, suffix) {
  if (is.null(data) || !length(cols)) return(rev)
  data <- as.data.frame(data)
  if (is.null(key)) key <- id_col
  if (!key %in% names(data))
    stop(sprintf("extra-column join key '%s' not in the supplied %s data", key, suffix),
         call. = FALSE)
  miss <- setdiff(cols, names(data))
  if (length(miss))
    stop(sprintf("extra %s columns not found: %s", suffix, paste(miss, collapse = ", ")),
         call. = FALSE)
  add <- data[match(rev[[id_col]], data[[key]]), cols, drop = FALSE]
  if (!is.null(suffix) && nzchar(suffix)) names(add) <- paste0(cols, "_", suffix)
  rownames(add) <- NULL
  cbind(rev, add)
}

#' Route a tiered result to accept / review / unmatched
#'
#' Turns an [np_tier()] / [np_match()] result into the three hand-off products of
#' the pipeline:
#'
#' * **`accepted`** the auto-matched crosswalk (YES tier),
#' * **`review`** a self-contained queue for the MAYBE tier — one row per
#'   surfaced candidate (top-k by score plus the best name-only and best
#'   address-only pairs). Columns lead with a curated decision block —
#'   `<id_label>, ein, name_<source>, name_<reference>, name_sim, addr_sim,
#'   score, decision, decision_layer, decision_reason, notes`, then the aligned
#'   address fields and per-field sims — followed by **every** remaining
#'   generated feature/stat, and finally any optional passthrough columns.
#' * **`unmatched`** the NO tier, each with its best near-miss for reference.
#'
#' The `review` queue is the same schema a human spreadsheet and an LLM prompt
#' both consume ([np_as_prompt()] renders one case as prompt text). No LLM or
#' network calls are made.
#'
#' @param tiered An `np_tiered` result (carries the scored pairs and config).
#' @param config An [np_config()] for the tier thresholds. Defaults to the config
#'   the result was tiered with.
#' @param pairs The scored candidate pairs. Defaults to those attached by
#'   [np_match()].
#' @param k Candidates to surface per review case. Default 3.
#' @param source Suffix for the query-side (source) columns, replacing `_x`.
#'   Default `"uss"` (USASpending). The source varies; the reference is the BMF.
#' @param reference Suffix for the candidate-side (reference) columns, replacing
#'   `_y`. Default `"bmf"`.
#' @param id_label Column name for the query key (`.id`), which is ambiguous.
#'   Default `"uei"` (Unique Entity Identifier). The reference key is `ein`.
#' @param bmf Optional raw processed BMF. When supplied, the default context
#'   fields from [np_bmf_review_fields()] (NTEE, 501(c) subsection, foundation
#'   flag, ruling year, assets, revenue, 990 form type) are joined onto each
#'   review row (`BMF_`-prefixed) and placed at the end, after the derived fields.
#' @param sam Optional raw SAM source frame. When supplied, [np_sam_review_fields()]
#'   context columns (entity start/fiscal dates, URL, structure + label, primary
#'   NAICS, POC name/title, and one boolean per business type) are joined onto
#'   each review row (`SAM_`-prefixed) and placed at the end.
#' @param review_tiers Which tiers to include in the `review` inspection frame.
#'   Default all three (`c("YES","MAYBE","NO")`) so `decision` shows the full
#'   YES/MAYBE/NO outcome; set to `"MAYBE"` for just the human-review hand-off.
#' @param token_idf Optional token -> IDF table from [np_token_idf()]. When given,
#'   the `name_*_tokenized` fields annotate each content token with its reference
#'   IDF (rarest first), exposing which tokens carry the match.
#' @param source_data,reference_data Optional data frames to pull extra
#'   passthrough columns from (e.g. award fields from the source, NTEE/ruling
#'   fields from the BMF). Joined by key onto each review row.
#' @param extra_source,extra_reference Character vectors of column names to carry
#'   through from `source_data` / `reference_data`. Appended, suffixed by
#'   `source` / `reference`, after the generated features.
#' @param source_key,reference_key Join keys in `source_data` / `reference_data`.
#'   Default to `id_label` and `"ein"` respectively.
#' @return An `np_routing` object: a list of `accepted`, `review`, `unmatched`,
#'   and a `summary` count vector.
#' @export
np_route <- function(tiered, config = attr(tiered, "config"),
                     pairs = attr(tiered, "pairs"), k = 3,
                     source = "uss", reference = "bmf", id_label = "uei",
                     bmf = NULL, sam = NULL, review_tiers = c("YES", "MAYBE", "NO"),
                     token_idf = NULL,
                     source_data = NULL, reference_data = NULL,
                     extra_source = NULL, extra_reference = NULL,
                     source_key = NULL, reference_key = "ein") {
  if (is.null(config)) config <- np_config()
  if (is.null(pairs))
    stop("np_route() needs the scored pairs; pass pairs= or use an np_match() result.",
         call. = FALSE)
  yes <- config$thresholds[["yes"]]; maybe <- config$thresholds[["maybe"]]

  tiered$route_reason <- .np_route_reason(tiered, yes, maybe, config$min_margin)
  tier <- as.character(tiered$tier)

  accepted <- tiered[tier == "YES",
    c(".id", "name_x", "overall_ein", "overall_name_y", "overall_score"), drop = FALSE]
  names(accepted) <- c(id_label, paste0("name_", source), "ein",
                       paste0("name_", reference), "score")
  rownames(accepted) <- NULL

  # review inspection frame: candidates for the requested tiers (default all).
  review_ids <- tiered$.id[tier %in% review_tiers]
  cand <- .np_candidates(pairs, k = k, ids = review_ids)
  qi <- match(cand$.id, tiered$.id)
  # (1) outcome block: decision = the algorithmic tier (YES/MAYBE/NO);
  #     is_top_candidate = 1 on the selected pick (blank on NO, where nothing
  #     clears the review floor); decision_layer = the blocking pass that found
  #     it (distinct from candidate_type, the surfacing view); reason = why held.
  cand$match_decision  <- as.character(tiered$tier[qi])
  cand$is_top_candidate <- as.integer(!is.na(qi) & cand$.ein == tiered$overall_ein[qi] &
                                       cand$match_decision %in% c("YES", "MAYBE"))
  cand$match_layer     <- if (!is.null(cand$pass)) as.character(cand$pass) else NA_character_
  cand$decision_reason <- tiered$route_reason[qi]
  cand$notes           <- rep(NA_character_, nrow(cand))
  # tokenized name: each content token annotated with its reference IDF (rarest
  # first), so the tokens the blocking leverages are visible. Falls back to the
  # collapsed-initials form when no token_idf table is supplied.
  annotate_tok <- function(v) {
    if (!length(v)) return(character(0))
    maxidf <- if (length(token_idf)) max(token_idf, na.rm = TRUE) else NA_real_
    vapply(strsplit(as.character(v), "\\s+"), function(t) {
      t <- .np_collapse_initials(t)
      if (is.null(token_idf)) return(paste(t, collapse = " "))
      t <- t[nchar(t) >= 2 & !(t %in% np_stopwords())]
      if (!length(t)) return("")
      w <- token_idf[t]; w[is.na(w)] <- maxidf            # unseen token = rarest
      ord <- order(-w)
      paste(sprintf("%s(%.1f)", t[ord], w[ord]), collapse = " ")
    }, character(1))
  }
  cand$name_tok_x <- annotate_tok(cand$name_key_x)
  cand$name_tok_y <- annotate_tok(cand$name_key_y)
  # number of surfaced candidate rows per query (the review group size)
  cand$num_of_candidates <- if (nrow(cand))
    stats::ave(seq_len(nrow(cand)), cand$.id, FUN = length) else integer(0)
  # round similarities for a scannable sheet
  if (nrow(cand)) {
    for (c2 in intersect(c("name_sim", "addr_sim", "street_key", "city", "zip5"), names(cand)))
      cand[[c2]] <- round(as.numeric(cand[[c2]]), 2)
    cand$score <- round(as.numeric(cand$score), 3)
  }

  # imported context fields (BMF_/SAM_-prefixed, already; joined without a suffix).
  # The layout places all imported fields at the very end, after derived features.
  if (!is.null(bmf)) {
    bf <- np_bmf_review_fields(bmf)
    cand <- .np_join_extra(cand, ".ein", bf, "ein", setdiff(names(bf), "ein"), NULL)
  }
  if (!is.null(sam)) {
    sf <- np_sam_review_fields(sam)
    cand <- .np_join_extra(cand, ".id", sf, "uei", setdiff(names(sf), "uei"), NULL)
  }

  review <- .np_review_layout(cand, source, reference, id_label)
  # arbitrary passthrough columns (appended after the generated features)
  if (!is.null(reference_data) && is.null(extra_reference))
    extra_reference <- setdiff(names(as.data.frame(reference_data)), reference_key)
  if (!is.null(source_data) && is.null(extra_source))
    extra_source <- setdiff(names(as.data.frame(source_data)),
                            if (is.null(source_key)) id_label else source_key)
  review <- .np_join_extra(review, id_label, source_data,
                           if (is.null(source_key)) id_label else source_key,
                           extra_source, source)
  review <- .np_join_extra(review, "ein", reference_data, reference_key,
                           extra_reference, reference)
  rownames(review) <- NULL
  review <- structure(review, class = c("np_review", "data.frame"),
                      source = source, reference = reference, id_label = id_label)

  unmatched <- tiered[tier == "NO",
    c(".id", "name_x", "overall_ein", "overall_name_y", "overall_score", "route_reason"),
    drop = FALSE]
  names(unmatched) <- c(id_label, paste0("name_", source), "best_ein",
                        paste0("best_name_", reference), "best_score", "decision_reason")
  rownames(unmatched) <- NULL

  out <- list(
    accepted  = accepted,
    review    = review,
    unmatched = unmatched,
    summary   = c(accepted = sum(tier == "YES"),
                  review = sum(tier == "MAYBE"),
                  unmatched = sum(tier == "NO"))
  )
  attr(out, "config") <- config
  attr(out, "source") <- source
  attr(out, "reference") <- reference
  attr(out, "id_label") <- id_label
  structure(out, class = "np_routing")
}

#' Render a review case as an LLM adjudication prompt
#'
#' Formats one query's review packet as self-contained prompt text: the source
#' organisation, the candidate BMF entities with their fields and similarities,
#' why it was flagged, and a JSON-output instruction. Pure string formatting — it
#' does not call any model. Use it to drive an LLM refinement step, or read it as
#' the human-facing summary of a case.
#'
#' @param routing An `np_routing` from [np_route()].
#' @param id A query `.id` present in the review queue.
#' @return A length-one character string.
#' @export
np_as_prompt <- function(routing, id) {
  rev <- routing$review
  src <- attr(routing, "source");   if (is.null(src)) src <- "uss"
  ref <- attr(routing, "reference"); if (is.null(ref)) ref <- "bmf"
  idl <- attr(routing, "id_label");  if (is.null(idl)) idl <- "uei"
  rows <- rev[rev[[idl]] == id, , drop = FALSE]
  if (nrow(rows) == 0) stop("No review case for ", idl, " = ", id, call. = FALSE)
  rows <- rows[order(-rows$score), , drop = FALSE]

  addr <- function(r, sfx) {
    paste(na.omit(c(r[[paste0("street_", sfx)]], r[[paste0("city_", sfx)]],
                    r[[paste0("state_", sfx)]], r[[paste0("zip5_", sfx)]])), collapse = ", ")
  }
  q <- rows[1, ]
  cand_lines <- vapply(seq_len(nrow(rows)), function(i) {
    r <- rows[i, ]
    sprintf("  [%d] EIN %s  %s\n      Address: %s\n      name_sim=%.2f  addr_sim=%.2f  score=%.2f%s",
            i, r$ein, r[[paste0("match_name_", ref)]], addr(r, ref),
            r$name_sim, ifelse(is.na(r$addr_sim), 0, r$addr_sim), r$score,
            if (isTRUE(r$veto_soft)) paste0("  [soft veto: ", r$veto_soft_reason, "]") else "")
  }, character(1))

  paste0(
    "You are adjudicating a nonprofit record-linkage match.\n\n",
    "SOURCE RECORD:\n",
    "  Name: ", q[[paste0("match_name_", src)]], "\n",
    "  Address: ", addr(q, src), "\n\n",
    "CANDIDATE MATCHES (IRS BMF):\n",
    paste(cand_lines, collapse = "\n"), "\n\n",
    "Flagged for review because: ", q$decision_reason, "\n\n",
    "Task: Decide which candidate, if any, is the SAME organisation as the source. ",
    "Treat differing generation suffixes (Jr/Sr), chapter/local numbers, and ordinals ",
    "as distinct organisations. If no candidate is the same entity, answer NONE.\n",
    "Respond as JSON: {\"ein\": \"<EIN or NONE>\", \"confidence\": <0-1>, \"reason\": \"<short>\"}"
  )
}

#' Render every review case as a prompt
#' @param routing An `np_routing`.
#' @return A named list of prompt strings, one per review query.
#' @export
np_as_prompts <- function(routing) {
  idl <- attr(routing, "id_label"); if (is.null(idl)) idl <- "uei"
  ids <- unique(routing$review[[idl]])
  stats::setNames(lapply(ids, function(i) np_as_prompt(routing, i)), ids)
}

#' @export
print.np_routing <- function(x, ...) {
  cat("<np_routing>\n")
  cat(sprintf("  accepted (YES):   %d\n", x$summary[["accepted"]]))
  cat(sprintf("  review   (MAYBE): %d queries, %d candidate rows\n",
              x$summary[["review"]], nrow(x$review)))
  cat(sprintf("  unmatched (NO):   %d\n", x$summary[["unmatched"]]))
  invisible(x)
}
