.np_as01 <- function(y) {
  if (is.logical(y)) return(as.integer(y))
  if (is.factor(y)) y <- as.character(y)
  if (is.character(y)) return(as.integer(y %in% c("1", "TRUE", "T", "yes", "YES", "match")))
  as.integer(y != 0)
}

#' Area under the ROC curve (Mann-Whitney form)
#'
#' @param score Numeric predicted scores.
#' @param label Truth: logical / 0-1 / "TRUE"/"FALSE".
#' @return Scalar AUC, or `NA` if a class is absent.
#' @export
np_auc <- function(score, label) {
  y <- .np_as01(label)
  ok <- !is.na(score) & !is.na(y)
  score <- score[ok]; y <- y[ok]
  pos <- score[y == 1]; neg <- score[y == 0]
  if (!length(pos) || !length(neg)) return(NA_real_)
  r <- rank(c(pos, neg))
  (sum(r[seq_along(pos)]) - length(pos) * (length(pos) + 1) / 2) /
    (length(pos) * length(neg))
}

#' Evaluate scored pairs against known labels
#'
#' Pair-level classification metrics for a linkage scorer: threshold-free AUC
#' plus precision / recall / F1 / accuracy at a decision threshold. Positives are
#' true matches.
#'
#' @param score Numeric predicted match scores.
#' @param label Truth (logical / 0-1 / character).
#' @param threshold Decision threshold; predict match when `score >= threshold`.
#' @return A one-row data frame of metrics.
#' @export
np_evaluate <- function(score, label, threshold = 0.5) {
  y <- .np_as01(label)
  ok <- !is.na(score) & !is.na(y)
  score <- score[ok]; y <- y[ok]
  pred <- score >= threshold
  tp <- sum(pred & y == 1); fp <- sum(pred & y == 0)
  fn <- sum(!pred & y == 1); tn <- sum(!pred & y == 0)
  prec <- if (tp + fp > 0) tp / (tp + fp) else NA_real_
  rec  <- if (tp + fn > 0) tp / (tp + fn) else NA_real_
  f1   <- if (!is.na(prec) && !is.na(rec) && prec + rec > 0)
            2 * prec * rec / (prec + rec) else NA_real_
  data.frame(
    n = length(y), n_pos = sum(y == 1), threshold = threshold,
    auc = np_auc(score, y),
    precision = prec, recall = rec, f1 = f1,
    accuracy = (tp + tn) / length(y)
  )
}

#' Tune YES / MAYBE thresholds from labelled data
#'
#' Chooses cutoffs for [np_tier()] on a validation set. `yes` is the lowest score
#' whose auto-accept precision still meets `target_precision` (so YES stays
#' trustworthy while auto-deciding as many records as possible); `maybe` is the
#' lowest score that still captures `min_recall` of true matches (anything below
#' is safe to drop to NO). `yes` is never below `maybe`.
#'
#' @param score,label Scores and truth on the validation set.
#' @param target_precision Minimum precision required of the YES tier.
#' @param min_recall Fraction of true matches the MAYBE floor must retain.
#' @return Named numeric `c(yes=, maybe=)`, with achieved metrics attached as
#'   attribute `metrics`.
#' @export
np_tune_thresholds <- function(score, label, target_precision = 0.98,
                               min_recall = 0.95) {
  y <- .np_as01(label)
  ok <- !is.na(score) & !is.na(y)
  score <- score[ok]; y <- y[ok]
  grid <- sort(unique(score))

  prec_at <- function(t) { p <- score >= t; tp <- sum(p & y == 1); fp <- sum(p & y == 0)
                           if (tp + fp > 0) tp / (tp + fp) else NA_real_ }
  rec_at  <- function(t) { tp <- sum(score >= t & y == 1); fn <- sum(score < t & y == 1)
                           if (tp + fn > 0) tp / (tp + fn) else 0 }

  precise <- vapply(grid, function(t) isTRUE(prec_at(t) >= target_precision), logical(1))
  yes <- if (any(precise)) min(grid[precise]) else max(grid) + 1e-6

  recall_ok <- vapply(grid, function(t) rec_at(t) >= min_recall, logical(1))
  maybe <- if (any(recall_ok)) max(grid[recall_ok]) else min(grid)
  if (maybe > yes) maybe <- yes

  out <- c(yes = yes, maybe = maybe)
  attr(out, "metrics") <- data.frame(
    yes = yes, maybe = maybe,
    yes_precision = prec_at(yes), yes_recall = rec_at(yes),
    maybe_recall = rec_at(maybe)
  )
  out
}
