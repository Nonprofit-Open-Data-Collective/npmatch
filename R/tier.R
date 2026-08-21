#' Sort selected matches into YES / MAYBE / NO tiers
#'
#' Applies the `config` thresholds to each query's overall match, then holds
#' back the high-scoring matches that are not safe to auto-accept.
#'
#' @details
#' The base tier is the score alone: `overall_score >= thresholds["yes"]` ->
#' YES, `>= thresholds["maybe"]` -> MAYBE, else NO. Two conditions then demote a
#' YES to MAYBE:
#'
#' * a **near-tie** with the runner-up (`overall_margin < min_margin`) — genuine
#'   ambiguity between two reference records that a reviewer must resolve;
#' * a **soft veto** — [np_veto()] flagged the selected pair with a rule whose
#'   severity is `"soft"`.
#'
#' View disagreement is *not* a gate: it is a signal that expands the review
#' candidate list (see [np_route()]), not a reason to demote a clear,
#' well-separated match.
#'
#' @section How vetoes reach this stage:
#' Vetoes are evaluated once, per candidate pair, by [np_veto()], and reach
#' `np_tier()` through [np_select()] in two different ways:
#'
#' * **hard** vetoes (`veto` / `veto_reason`) never get here. [np_select()]
#'   drops hard-vetoed pairs before picking the best candidate (unless it was
#'   called with `include_vetoed = TRUE`), so a hard veto removes that reference
#'   record from contention entirely. The query still gets a tier — computed
#'   from whatever candidate survives, which may be a weaker one, or NO if none
#'   does.
#' * **soft** vetoes (`veto_soft` / `veto_soft_reason`) stay eligible and are
#'   carried onto the selected row as `overall_veto_soft` /
#'   `overall_veto_reason`. `np_tier()` reads those two columns: a soft veto on
#'   the *selected* pair caps it at MAYBE. It never pushes a MAYBE down to NO,
#'   and a soft veto on a pair that was not selected has no effect.
#'
#' The soft rules in the shipped rule set are `affiliate_suffix` (the candidate
#' ends in a subordinate-affiliate token — FOUNDATION / ENDOWMENT / AUXILIARY /
#' BOOSTERS — that the query name does not carry, on an otherwise strong name
#' match) and `government_entity` (the query is a municipality, school district,
#' or special district). Both mean "plausible, but a human should look". See
#' [np_default_rules()] for the full set and the hard rules, and [np_route()]
#' for how the reason text is surfaced to reviewers.
#'
#' Note that the rule set is configurable, so which vetoes can fire depends on
#' `config$rules`; the description above is of [np_default_rules()].
#'
#' @param selection An `np_selection` from [np_select()].
#' @param config An [np_config()] supplying `thresholds` and `min_margin`.
#' @return `selection` with a `tier` factor (`YES` / `MAYBE` / `NO`) and the
#'   `decision_score` used, of class `np_tiered`.
#' @seealso [np_veto()] and [np_default_rules()] for the rules themselves;
#'   [np_route()] for what happens to each tier.
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
  # hold back auto-YES on a soft veto (affiliate suffix / government entity):
  # plausible enough to keep, not clean enough to accept unreviewed
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
