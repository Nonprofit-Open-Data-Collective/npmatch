# Merge stage-2 (LLM / human) adjudication decisions back onto the candidate-level
# review frame. np_route() makes no LLM calls -- the review frame is the hand-off
# *into* adjudication -- so the decisions come back as a separate artifact and
# have to be joined. The join is not column-for-column: decisions are query-level
# (one row per source id) while the review frame is candidate-level (several rows
# per source id), so the decision replicates across a query's candidates and the
# per-row answer is which candidate was chosen.

.np_dec_required <- c("uei", "best_ein", "llm_decision", "llm_confidence", "llm_reason")

# Accept a data frame, a single CSV, or a directory of per-shard decision-*.csv.
.np_as_decisions_df <- function(x) {
  if (is.data.frame(x)) return(as.data.frame(x))
  if (!is.character(x) || length(x) != 1L)
    stop("`decisions` must be a data frame, a path to a CSV, or a directory ",
         "of decision-*.csv shards.", call. = FALSE)
  if (dir.exists(x)) {
    f <- list.files(x, pattern = "^decision-.*[.]csv$", full.names = TRUE)
    if (!length(f))
      stop("no decision-*.csv files found in: ", x, call. = FALSE)
    keep <- c(.np_dec_required, ".shard")
    parts <- lapply(f, function(p) {
      d <- utils::read.csv(p, colClasses = "character", check.names = FALSE)
      miss <- setdiff(.np_dec_required, names(d))
      if (length(miss))
        stop("decision shard '", basename(p), "' is missing column(s): ",
             paste(miss, collapse = ", "), call. = FALSE)
      d$.shard <- sub("[.]csv$", "", sub("^decision-", "", basename(p)))
      d[, keep, drop = FALSE]
    })
    return(do.call(rbind, parts))
  }
  if (!file.exists(x)) stop("file not found: ", x, call. = FALSE)
  utils::read.csv(x, colClasses = "character", check.names = FALSE)
}

# One row per query id. Prefer a YES over a NO, then higher confidence -- the
# same precedence the run-level merge uses when a duplicate source registration
# was adjudicated in more than one shard.
.np_collapse_decisions <- function(dec) {
  rank <- c(high = 3L, medium = 2L, low = 1L)
  r <- unname(rank[dec$llm_confidence]); r[is.na(r)] <- 0L
  ord <- ifelse(dec$llm_decision == "YES", 10L, 0L) + r
  yes <- dec$llm_decision == "YES"
  nd <- tapply(dec$llm_decision, dec$uei, function(v) length(unique(v)))
  ny <- tapply(seq_len(nrow(dec)), dec$uei,
               function(i) length(unique(dec$best_ein[i][yes[i]])))
  conflict <- names(nd)[nd > 1L | ny > 1L]
  dec <- dec[order(dec$uei, -ord), , drop = FALSE]
  list(dec = dec[!duplicated(dec$uei), , drop = FALSE], conflict = conflict)
}

#' Merge adjudication decisions onto a review frame
#'
#' Joins the query-level YES/NO decisions produced by the stage-2 review (LLM
#' subagents or human reviewers) back onto the candidate-level review frame from
#' [np_route()], and derives which candidate the adjudicator actually chose.
#'
#' [np_route()] makes no LLM or network calls: its `review` frame is the hand-off
#' *into* adjudication, and the decisions come back as a separate artifact. This
#' is the join that closes that loop.
#'
#' @section Grain:
#' Decisions are **query-level** — one row per source id. The review frame is
#' **candidate-level** — several rows per source id, one per surfaced EIN. The
#' decision columns therefore replicate across all of a query's candidate rows,
#' and the per-row answer is `llm_selected`: `TRUE` on the single candidate the
#' adjudicator picked. It is the stage-2 analogue of `is_top_candidate`, and
#' comparing the two shows where adjudication overrode the pipeline's pick.
#'
#' @section Unadjudicated rows are NA, not FALSE:
#' A decision file normally covers the MAYBE tier only, so queries that were
#' auto-accepted or auto-rejected have no decision row. Their decision columns
#' and `llm_selected` come back `NA` — meaning *not adjudicated*, which is not
#' the same as rejected. Guard with `%in% TRUE` (or `isTRUE()`) rather than
#' letting `NA` propagate when filtering.
#'
#' @section Duplicate source registrations:
#' A source id matched in more than one compute chunk can be adjudicated in more
#' than one shard. Those rows are collapsed to one, preferring a YES over a NO
#' and then higher confidence — the same precedence the run-level merge uses.
#' Ids whose duplicate rows genuinely disagreed are recorded in the `conflicts`
#' attribute of the result, and warned about unless `quiet = TRUE`.
#'
#' @param review The candidate-level frame: an `np_routing` from [np_route()]
#'   (its `review` element is used), a review frame / data frame, or a path to a
#'   CSV of one.
#' @param decisions The adjudication result: a data frame, a path to a merged
#'   decisions CSV, or a path to a **directory** of per-shard `decision-*.csv`
#'   files (read and stacked, with a `.shard` column recording the source file).
#'   Must carry `uei`, `best_ein`, `llm_decision`, `llm_confidence`,
#'   `llm_reason`.
#' @param id Column naming the query key in `review`. Default `"uei"`; the
#'   decision side is always keyed on `uei`. Set this when [np_route()] was
#'   called with a different `id_label`.
#' @param ein Column naming the candidate key in `review`. Default `"ein"`.
#' @param prefix Prefix for the added columns. Default `"llm_"`, giving
#'   `llm_decision`, `llm_confidence`, `llm_reason`, `llm_best_ein`, and
#'   `llm_selected`. Use e.g. `"human_"` to merge a second, independent pass
#'   alongside the first without collision.
#' @param quiet Suppress the merge summary message and warnings. Default `FALSE`.
#' @return `review` with five columns appended, in its original row order and
#'   class. Carries a `decision_merge` attribute: a list of `n_decisions`,
#'   `n_ids`, `n_collapsed`, `n_matched` (review rows that got a decision),
#'   `n_unmatched_ids` (decision ids absent from the frame), and `conflicts`.
#' @seealso [np_route()] for producing the review frame, [np_as_prompt()] for
#'   rendering one case for an adjudicator, and [np_evaluate()] for scoring the
#'   merged result against labels.
#' @examples
#' review <- data.frame(
#'   uei = c("A1", "A1", "B2", "C3"),
#'   ein = c("11-1111111", "22-2222222", "33-3333333", "44-4444444"),
#'   name_uss = c("Alpha", "Alpha", "Beta", "Gamma"),
#'   stringsAsFactors = FALSE
#' )
#' decisions <- data.frame(
#'   uei            = c("A1", "B2"),
#'   best_ein       = c("22-2222222", ""),
#'   llm_decision   = c("YES", "NO"),
#'   llm_confidence = c("high", "medium"),
#'   llm_reason     = c("same org; address confirms", "no credible candidate"),
#'   stringsAsFactors = FALSE
#' )
#' merged <- np_merge_decisions(review, decisions)
#' merged[, c("uei", "ein", "llm_decision", "llm_selected")]
#' # C3 was never adjudicated -> NA, not FALSE
#' @export
np_merge_decisions <- function(review, decisions, id = "uei", ein = "ein",
                               prefix = "llm_", quiet = FALSE) {
  rev <- .np_as_review_df(review)
  dec <- .np_as_decisions_df(decisions)

  if (!is.character(prefix) || length(prefix) != 1L || !nzchar(prefix))
    stop("`prefix` must be a non-empty string.", call. = FALSE)
  for (nm in c(id, ein))
    if (!nm %in% names(rev))
      stop("`review` has no column '", nm, "'. Columns: ",
           paste(utils::head(names(rev), 12), collapse = ", "), call. = FALSE)
  miss <- setdiff(.np_dec_required, names(dec))
  if (length(miss))
    stop("`decisions` is missing column(s): ", paste(miss, collapse = ", "),
         call. = FALSE)
  if (!nrow(dec)) stop("`decisions` has no rows.", call. = FALSE)

  dec$uei            <- trimws(as.character(dec$uei))
  dec$best_ein       <- trimws(as.character(dec$best_ein))
  dec$llm_decision   <- toupper(trimws(as.character(dec$llm_decision)))
  dec$llm_confidence <- tolower(trimws(as.character(dec$llm_confidence)))
  bad <- setdiff(unique(dec$llm_decision), c("YES", "NO"))
  if (length(bad))
    stop("`decisions$llm_decision` must be YES or NO; found: ",
         paste(utils::head(bad, 5), collapse = ", "), call. = FALSE)

  n_decisions <- nrow(dec)
  co  <- .np_collapse_decisions(dec)
  dec <- co$dec

  key <- trimws(as.character(rev[[id]]))
  i   <- match(key, dec$uei)
  got <- !is.na(i)

  p <- function(s) paste0(prefix, s)
  rev[[p("decision")]]   <- dec$llm_decision[i]
  rev[[p("confidence")]] <- dec$llm_confidence[i]
  rev[[p("reason")]]     <- dec$llm_reason[i]
  rev[[p("best_ein")]]   <- dec$best_ein[i]

  # NA where the query was never adjudicated -- not FALSE, which would read as
  # "the adjudicator rejected this candidate".
  sel <- rep(NA, nrow(rev))
  sel[got] <- dec$llm_decision[i[got]] == "YES" &
    nzchar(dec$best_ein[i[got]]) &
    trimws(as.character(rev[[ein]][got])) == dec$best_ein[i[got]]
  rev[[p("selected")]] <- sel

  stats <- list(n_decisions = n_decisions, n_ids = nrow(dec),
                n_collapsed = n_decisions - nrow(dec),
                n_matched = sum(got),
                n_unmatched_ids = sum(!dec$uei %in% key),
                conflicts = co$conflict)
  attr(rev, "decision_merge") <- stats

  if (!quiet) {
    message(sprintf(
      "merged %s decision(s) -> %s id(s)%s; %s of %s review rows adjudicated, %s selected",
      format(n_decisions, big.mark = ","), format(nrow(dec), big.mark = ","),
      if (stats$n_collapsed) sprintf(" (%d duplicate collapsed)", stats$n_collapsed) else "",
      format(sum(got), big.mark = ","), format(nrow(rev), big.mark = ","),
      format(sum(sel %in% TRUE), big.mark = ",")))
    if (length(co$conflict))
      warning(length(co$conflict), " id(s) had disagreeing duplicate decisions; ",
              "kept the best per id. See attr(x, 'decision_merge')$conflicts.",
              call. = FALSE)
    if (stats$n_unmatched_ids)
      warning(stats$n_unmatched_ids, " decision id(s) are not in the review frame.",
              call. = FALSE)
  }
  rev
}
