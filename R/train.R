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
#' @param pairs A labelled `np_pairs` frame (see [np_label()]); rows with `NA`
#'   label are ignored.
#' @param engine `"logit"` (default) or a function `(x, y)` returning a fitted
#'   model, where `x` is the similarity data frame and `y` is 0/1.
#' @param features Similarity columns to use. Defaults to the compared fields.
#' @return An `np_model` object usable as `np_score(..., model = )`.
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
  structure(list(fit = fit, features = features, engine = eng, n = sum(keep)),
            class = "np_model")
}

#' @export
predict.np_model <- function(object, newdata, type = "response", ...) {
  x <- as.data.frame(newdata)[, object$features, drop = FALSE]
  p <- tryCatch(
    as.numeric(stats::predict(object$fit, x, type = "response")),
    error = function(e) as.numeric(stats::predict(object$fit, x))
  )
  p
}

#' @export
print.np_model <- function(x, ...) {
  cat("<np_model>", x$engine, "on", length(x$features), "features:",
      paste(x$features, collapse = ", "), "\n")
  cat("  trained on", x$n, "labelled pairs\n")
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
#' @param pairs A labelled `np_pairs` frame.
#' @param methods Which scorers to compare.
#' @param k Number of CV folds for the supervised `model` method.
#' @param config An [np_config()] (supplies weights for `weighted`).
#' @param engine Training engine for `model` (see [np_train()]).
#' @param target_precision,min_recall Passed to [np_tune_thresholds()].
#' @param seed Fold-assignment seed.
#' @return A data frame, one row per method, with AUC and tuned-threshold
#'   precision/recall/coverage. Out-of-fold scores are attached as
#'   attribute `scores`.
#' @export
np_benchmark <- function(pairs, methods = c("weighted", "em", "model"),
                         k = 5, config = np_config(), engine = "logit",
                         target_precision = 0.98, min_recall = 0.95, seed = 1L) {
  df <- as.data.frame(pairs)
  lab_idx <- which(!is.na(df$label))
  if (length(lab_idx) < 4) stop("Need more labelled pairs to benchmark.", call. = FALSE)
  y <- .np_as01(df$label[lab_idx])

  method_scores <- list()

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
      m <- tryCatch(np_train(p_tr, engine = engine), error = function(e) NULL)
      if (!is.null(m)) oof[fold == f] <- predict(m, df[te, , drop = FALSE])
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
               yes_coverage = mean(s >= th[["yes"]], na.rm = TRUE))
  })
  out <- do.call(rbind, rows)
  out <- out[order(-out$auc), , drop = FALSE]
  rownames(out) <- NULL
  attr(out, "scores") <- method_scores
  out
}
