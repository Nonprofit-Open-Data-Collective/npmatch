#' Sort selected matches into YES / MAYBE / NO tiers
#'
#' Applies the `config` thresholds to each query's overall match. Two conditions
#' hold a high-scoring match back at MAYBE rather than auto-accepting it:
#' a **near-tie** with the runner-up (`overall_margin < min_margin` — genuine
#' ambiguity that a reviewer must resolve), and a **soft veto** (e.g. a
#' generation marker on one side only). View disagreement is *not* a gate: it is
#' a signal that expands the review candidate list (see [np_route()]), not a
#' reason to demote a clear, well-separated match.
#'
#' @param selection An `np_selection` from [np_select()].
#' @param config An [np_config()] supplying `thresholds` and `min_margin`.
#' @return `selection` with a `tier` factor (`YES` / `MAYBE` / `NO`) and the
#'   `decision_score` used, of class `np_tiered`.
#' @export
np_tier <- function(selection, config = np_config()) {
  yes   <- config$thresholds[["yes"]]
  maybe <- config$thresholds[["maybe"]]
  s <- selection$overall_score
  s[is.na(s)] <- 0

  tier <- ifelse(s >= yes, "YES", ifelse(s >= maybe, "MAYBE", "NO"))
  # hold back auto-YES on a near-tie with the runner-up (real ambiguity)
  if (!is.null(selection$overall_margin)) {
    ambiguous <- !is.na(selection$overall_margin) &
      selection$overall_margin < config$min_margin
    tier[tier == "YES" & ambiguous] <- "MAYBE"
  }
  # hold back auto-YES on a soft veto (e.g. generation marker on one side only)
  if (!is.null(selection$overall_veto_soft)) {
    soft <- !is.na(selection$overall_veto_soft) & selection$overall_veto_soft
    tier[tier == "YES" & soft] <- "MAYBE"
  }

  selection$decision_score <- s
  selection$tier <- factor(tier, levels = c("YES", "MAYBE", "NO"))
  out <- structure(selection, class = c("np_tiered", "data.frame"))
  attr(out, "config") <- config
  out
}

#' @export
summary.np_tiered <- function(object, ...) {
  tab <- table(object$tier)
  cat("<np_tiered>  profile:", attr(object, "profile"), "\n")
  cat("  queries:", nrow(object), "\n")
  for (t in names(tab)) cat(sprintf("  %-6s %d\n", t, tab[[t]]))
  invisible(tab)
}
