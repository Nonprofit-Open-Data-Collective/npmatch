# Stratified sample of query ids by tier (bounded per tier).
.np_stratified_ids <- function(tiered, per_tier, seed) {
  by <- split(as.character(tiered$.id), as.character(tiered$tier))
  out <- character(0)
  for (i in seq_along(per_tier)) {
    t <- names(per_tier)[i]
    ids <- by[[t]]
    if (is.null(ids) || !length(ids)) next
    n <- min(per_tier[[t]], length(ids))
    set.seed(seed + i)
    out <- c(out, if (n < length(ids)) sample(ids, n) else ids)
  }
  out
}

#' Build a labelling frame for threshold / weight calibration
#'
#' Draws a tier-stratified sample of queries from a tiered result and lays out
#' their candidate matches (top-k by score plus the best name-only and best
#' address-only views) as one row per candidate, ready to label. Sampling across
#' YES / MAYBE / NO — not just the review pile — is what lets
#' [np_tune_thresholds()] estimate the cutoffs well near the boundary.
#'
#' Each row carries both records' display fields, the per-field similarities, the
#' combined `score`, the query's tier / pass / margin, whether the candidate was
#' the chosen overall match, and an empty `label` column. A labeller (human or
#' LLM) sets `label = TRUE` on the correct candidate for a query and `FALSE` on
#' the rest (all `FALSE` if none is correct). Feed the result back with
#' [np_label()], then [np_benchmark()] / [np_tune_thresholds()].
#'
#' @param tiered An `np_tiered` result from [np_match()] / [np_cascade()] (its
#'   scored candidate pairs must be attached as `attr(tiered, "pairs")`).
#' @param per_tier Named integer cap of queries to sample from each tier.
#' @param k Candidates to surface per query. Default 3.
#' @param seed Sampling seed.
#' @return A data frame (class `np_calibration`) of candidate rows with an empty
#'   `label` column.
#' @export
np_calibration_frame <- function(tiered,
                                 per_tier = c(YES = 120, MAYBE = 250, NO = 120),
                                 k = 3, seed = 1) {
  pairs <- attr(tiered, "pairs")
  if (is.null(pairs))
    stop("np_calibration_frame() needs the scored pairs; pass an np_match()/np_cascade() result.",
         call. = FALSE)

  ids <- .np_stratified_ids(tiered, per_tier, seed)
  cand <- .np_candidates(pairs, k = k, ids = ids)

  m <- match(cand$.id, as.character(tiered$.id))
  cand$query_tier  <- as.character(tiered$tier)[m]
  cand$query_pass  <- if (!is.null(tiered$pass)) tiered$pass[m] else NA_character_
  cand$query_score <- tiered$overall_score[m]
  cand$query_margin <- tiered$overall_margin[m]
  cand$n_close     <- if (!is.null(tiered$n_close)) tiered$n_close[m] else NA_integer_
  cand$tie         <- if (!is.null(tiered$tie)) tiered$tie[m] else NA
  cand$is_overall  <- cand$.ein == tiered$overall_ein[m]
  cand$label <- NA

  # order for review: by query, chosen candidate first, then by score
  cand <- cand[order(cand$.id, -cand$is_overall, -cand$score), , drop = FALSE]
  rownames(cand) <- NULL
  structure(cand, class = c("np_calibration", "data.frame"))
}

#' Extract vetoed pairs for auditing and training
#'
#' Returns every candidate pair a veto rule fired on — the pairs [np_select()]
#' otherwise drops (hard) or demotes (soft). During development this lets you
#' confirm each rule fires only on genuine non-matches, and it seeds the training
#' set with rule-flagged negatives. Hard vetoes are auto-labelled `FALSE`
#' (do-not-match by rule); soft vetoes get `label = NA` (inherently ambiguous —
#' review them). If a hard-vetoed row is actually a true match, the rule is too
#' aggressive.
#'
#' @param pairs A vetoed `np_pairs` frame (after [np_veto()]).
#' @return A data frame (class `np_veto_audit`) with `.id`, `.ein`, display
#'   names, `score`, `severity`, `veto_rule`, and an auto `label`.
#' @export
np_veto_audit <- function(pairs) {
  df <- as.data.frame(pairs)
  if (is.null(df$veto)) df$veto <- FALSE
  if (is.null(df$veto_soft)) df$veto_soft <- FALSE
  hit <- df$veto | df$veto_soft
  v <- df[hit, , drop = FALSE]
  out <- data.frame(
    .id = v$.id, .ein = v$.ein,
    name_x = v$name_x, name_y = v$name_y,
    score = if (!is.null(v$score)) v$score else NA_real_,
    severity = ifelse(v$veto, "hard", "soft"),
    veto_rule = ifelse(v$veto, v$veto_reason, v$veto_soft_reason),
    label = ifelse(v$veto, FALSE, NA),          # hard = non-match; soft = review
    stringsAsFactors = FALSE)
  rownames(out) <- NULL
  structure(out, class = c("np_veto_audit", "data.frame"))
}

#' @export
print.np_veto_audit <- function(x, ...) {
  cat("<np_veto_audit>", nrow(x), "vetoed pairs\n")
  if (nrow(x)) {
    rules <- table(x$veto_rule)
    for (r in names(rules)) cat(sprintf("  %-22s %d\n", r, rules[[r]]))
  }
  invisible(x)
}

#' @export
print.np_calibration <- function(x, ...) {
  nq <- length(unique(x$.id))
  cat("<np_calibration>", nrow(x), "candidate rows for", nq, "queries\n")
  if (!is.null(x$query_tier))
    cat("  sampled tiers:", paste(names(table(x$query_tier)),
        table(x$query_tier), sep = "=", collapse = "  "), "\n")
  cat("  fill the `label` column TRUE/FALSE, then np_label() -> np_benchmark()\n")
  invisible(x)
}
