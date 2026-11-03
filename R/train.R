#' Attach labels to candidate pairs
#'
#' Joins a labelled review sheet (as filled in from [np_label_frame()]) back onto
#' an `np_pairs` object by `(.id, .ein)`, adding a `label` column. Unlabelled
#' pairs get `NA`.
#'
#' @param pairs An `np_pairs` frame.
#' @param labels A data frame with columns `.id`, `.ein`, and `label`.
#' @return `pairs` with a `label` column (attributes preserved).
#' @export
np_label <- function(pairs, labels) {
  stopifnot(all(c(".id", ".ein", "label") %in% names(labels)))
  key_p <- paste(pairs$.id, pairs$.ein, sep = "\r")
  key_l <- paste(labels$.id, labels$.ein, sep = "\r")
  pairs$label <- labels$label[match(key_p, key_l)]
  pairs
}

#' Train a supervised match combiner
#'
#' Fits a classifier that maps the per-field similarity vector to a match
#' probability — the model consumed by [np_score()] `method = "model"`. The
#' built-in engine is logistic regression; any engine returning an object with a
#' `predict(obj, newdata, type = "response")` method can be supplied.
#'
#' If the fit cannot estimate every term -- because a similarity column is
#' constant in the labelled set, or two of them carry the same information --
#' `glm()` drops the collinear ones and the scores quietly stop depending on
#' them. `np_train()` reports that once, naming the dropped terms, with a
#' warning of class `np_rank_deficient`, and records `rank`, `n_terms` and
#' `aliased` on the model; `print()` shows them. The class is there so a
#' caller who expects the condition can muffle precisely it.
#'
#' @param pairs A labelled `np_pairs` frame (see [np_label()]); rows with `NA`
#'   label are ignored.
#' @param engine `"logit"` (default) or a function `(x, y)` returning a fitted
#'   model, where `x` is the similarity data frame and `y` is 0/1.
#' @param features Similarity columns to use. Defaults to the compared fields.
#' @return An `np_model` object usable as `np_score(..., model = )`. Alongside
#'   the fit it carries `rank`, `n_terms` and `aliased` -- the terms the fit
#'   dropped as collinear, empty when there were none. `rank` and `n_terms`
#'   are `NA` for a custom `engine` whose object has no `coef()` method.
#' @export
np_train <- function(pairs, engine = "logit", features = attr(pairs, "cmp_cols")) {
  features <- intersect(features, names(pairs))
  df <- as.data.frame(pairs)
  keep <- !is.na(df$label)
  x <- df[keep, features, drop = FALSE]
  y <- .np_as01(df$label[keep])
  if (length(unique(y)) < 2) {
    stop("Training needs both matched and non-matched labelled pairs.", call. = FALSE)
  }

  if (identical(engine, "logit")) {
    # glm's fit-time warnings stay suppressed: "fitted probabilities
    # numerically 0 or 1" is expected on well-separated label sets and says
    # nothing actionable. But that suppression also hid the rank-deficiency
    # report, and the fit is the one place that knows which coefficients were
    # dropped -- so the fit is inspected below and reported by name instead.
    fit <- suppressWarnings(
      stats::glm(y ~ ., data = cbind(y = y, x), family = stats::binomial())
    )
    eng <- "logit"
  } else if (is.function(engine)) {
    fit <- engine(x, y)
    eng <- "custom"
  } else {
    stop("engine must be 'logit' or a function(x, y).", call. = FALSE)
  }

  co <- tryCatch(stats::coef(fit), error = function(e) NULL)
  named <- length(co) && !is.null(names(co))
  aliased <- if (named) setdiff(names(co)[is.na(unname(co))], "(Intercept)") else character()
  model <- structure(
    list(fit = fit, features = features, engine = eng, n = sum(keep),
         rank = if (is.null(fit$rank)) NA_integer_ else as.integer(fit$rank),
         n_terms = if (named) length(co) else NA_integer_,
         aliased = aliased),
    class = "np_model")

  # A dropped similarity column is the quiet failure this package stops on
  # elsewhere, and it is a realistic input: a field empty on one side of the
  # join, or two columns saying the same thing. Raised with its own condition
  # class so a caller who expects it -- np_benchmark() cross-validating a small
  # set -- can muffle precisely this and nothing else.
  if (length(aliased))
    warning(structure(
      class = c("np_rank_deficient", "warning", "condition"),
      list(call = NULL, message = paste0(
        length(aliased), " feature(s) could not be estimated and were dropped ",
        "as collinear: ", paste(aliased, collapse = ", "),
        ". Scores from this model ignore them, and predictions for rows that ",
        "depend on them are not identified. Look for constant or duplicated ",
        "similarity columns in the labelled set."))))

  model
}

#' @export
predict.np_model <- function(object, newdata, type = "response", ...) {
  x <- as.data.frame(newdata)[, object$features, drop = FALSE]
  # np_train() already reported rank deficiency once, by name, when the model
  # was fitted. predict.lm() repeats it on every prediction call with no names
  # in it, so muffle that one message -- matched on its text, since it is
  # stats' own warning and carries no class to match on. Everything else
  # predict() emits (newdata level mismatches, NA coercions) still gets through.
  quiet <- function(expr) withCallingHandlers(expr, warning = function(w) {
    if (grepl("rank-deficient fit", conditionMessage(w), fixed = TRUE))
      invokeRestart("muffleWarning")
  })
  p <- tryCatch(
    quiet(as.numeric(stats::predict(object$fit, x, type = "response"))),
    error = function(e) quiet(as.numeric(stats::predict(object$fit, x)))
  )
  p
}

#' @export
print.np_model <- function(x, ...) {
  cat("<np_model>", x$engine, "on", length(x$features), "features:",
      paste(x$features, collapse = ", "), "\n")
  cat("  trained on", x$n, "labelled pairs\n")
  if (!is.na(x$rank) && !is.na(x$n_terms))
    cat("  rank", x$rank, "of", x$n_terms, "terms\n")
  if (length(x$aliased))
    cat("  dropped as collinear:", paste(x$aliased, collapse = ", "), "\n")
  invisible(x)
}

# Deterministic k-fold assignment over row indices (no RNG dependence on the
# global seed unless `seed` is given).
.np_folds <- function(n, k, seed = 1L) {
  idx <- seq_len(n)
  if (!is.null(seed)) { set.seed(seed); idx <- sample(idx) }
  fold <- integer(n)
  fold[idx] <- ((seq_len(n) - 1L) %% k) + 1L
  fold
}

#' Benchmark scoring methods by cross-validation
#'
#' Compares the candidate scorers on a labelled set so the "best" combiner can be
#' chosen empirically. The unsupervised methods (`weighted`, `em`) are scored on
#' the full candidate set; `model` uses out-of-fold predictions to avoid optimism.
#' Each method is then evaluated at thresholds tuned on the same labels, so the
#' comparison reflects how the tiering would actually behave.
#'
#' On a small labelled set a fold can hold fewer usable rows than the model
#' has features, leaving that fold's fit rank-deficient and its out-of-fold
#' predictions unidentified. That is an expected consequence of splitting a
#' small set, so [np_train()]'s per-model warning is muffled here and the
#' count is reported in the `rank_deficient_folds` column instead, with the
#' per-fold detail on the `rank_deficient` attribute. A non-zero count means
#' the `model` row should be read as provisional.
#'
#' @param pairs A labelled `np_pairs` frame.
#' @param methods Which scorers to compare.
#' @param k Number of CV folds for the supervised `model` method.
#' @param config An [np_config()] (supplies weights for `weighted`).
#' @param engine Training engine for `model` (see [np_train()]).
#' @param target_precision,min_recall Passed to [np_tune_thresholds()].
#' @param seed Fold-assignment seed.
#' @return A data frame, one row per method, with AUC and tuned-threshold
#'   precision/recall/coverage, plus `rank_deficient_folds`: the number of
#'   `model` folds whose fit dropped a term (`NA` for the unsupervised rows).
#'   Out-of-fold scores are attached as attribute `scores`, and
#'   `rank_deficient` holds one entry per affected fold, named by fold number
#'   and listing the terms it dropped.
#' @export
np_benchmark <- function(pairs, methods = c("weighted", "em", "model"),
                         k = 5, config = np_config(), engine = "logit",
                         target_precision = 0.98, min_recall = 0.95, seed = 1L) {
  df <- as.data.frame(pairs)
  lab_idx <- which(!is.na(df$label))
  if (length(lab_idx) < 4) stop("Need more labelled pairs to benchmark.", call. = FALSE)
  y <- .np_as01(df$label[lab_idx])

  method_scores <- list()
  # fold number (as character) -> terms that fold's fit dropped as collinear
  rank_deficient <- list()

  if ("weighted" %in% methods) {
    s <- np_score(pairs, config, method = "weighted")$score
    method_scores[["weighted"]] <- s[lab_idx]
  }
  if ("em" %in% methods) {
    s <- tryCatch(np_score(pairs, config, method = "em")$score,
                  error = function(e) rep(NA_real_, nrow(df)))
    method_scores[["em"]] <- s[lab_idx]
  }
  if ("model" %in% methods) {
    fold <- .np_folds(length(lab_idx), min(k, sum(y == 1), sum(y == 0)), seed)
    oof <- rep(NA_real_, length(lab_idx))
    for (f in sort(unique(fold))) {
      tr <- lab_idx[fold != f]; te <- lab_idx[fold == f]
      p_tr <- pairs[tr, , drop = FALSE]; attr(p_tr, "cmp_cols") <- attr(pairs, "cmp_cols")
      p_tr$label <- df$label[tr]
      # A fold thin enough to degenerate is an expected outcome of
      # cross-validating a small labelled set, so np_train()'s per-model
      # warning is muffled by its condition class -- precisely that, nothing
      # else -- and the count is reported in the result instead, as the
      # rank_deficient_folds column, with the per-fold detail on the
      # rank_deficient attribute.
      m <- withCallingHandlers(
        tryCatch(np_train(p_tr, engine = engine), error = function(e) NULL),
        np_rank_deficient = function(w) invokeRestart("muffleWarning")
      )
      if (!is.null(m)) {
        if (length(m$aliased)) rank_deficient[[as.character(f)]] <- m$aliased
        oof[fold == f] <- predict(m, df[te, , drop = FALSE])
      }
    }
    method_scores[["model"]] <- oof
  }

  rows <- lapply(names(method_scores), function(nm) {
    s <- method_scores[[nm]]
    th <- np_tune_thresholds(s, y, target_precision, min_recall)
    ev <- np_evaluate(s, y, threshold = th[["yes"]])
    data.frame(method = nm, n = ev$n, n_pos = ev$n_pos, auc = ev$auc,
               yes = th[["yes"]], maybe = th[["maybe"]],
               yes_precision = ev$precision, yes_recall = ev$recall,
               yes_coverage = mean(s >= th[["yes"]], na.rm = TRUE),
               rank_deficient_folds = if (identical(nm, "model"))
                 length(rank_deficient) else NA_integer_)
  })
  out <- do.call(rbind, rows)
  out <- out[order(-out$auc), , drop = FALSE]
  rownames(out) <- NULL
  attr(out, "scores") <- method_scores
  attr(out, "rank_deficient") <- rank_deficient
  out
}
