# Reproduce the rank-deficient fit behind np_benchmark()'s test warning.
# The record for dev/BENCHMARK-RANK-DEFICIENCY.md: prints the per-fold table in
# section 1. Re-run it after any change to the compared-field set, since adding
# a similarity column changes which folds degenerate.
#
#   Rscript dev/probe-rank-deficiency.R        # from the package root

pkg <- normalizePath(".", mustWork = TRUE)
suppressMessages(library(npmatch))
sys.source(file.path(pkg, "tests", "testthat", "helper-fixtures.R"), envir = globalenv())

# The same labelled set tests/testthat/test-train.R builds.
q <- np_normalize(np_query(np_test_query(), np_test_map_q))
r <- np_normalize(np_reference(np_test_reference(), np_test_map_r))
pairs <- np_veto(np_score(np_compare(q, r, block = "state")))
truth <- c(q1 = "05", q2 = "10", q3 = "11", q4 = "14")
pairs$label <- pairs$.ein == truth[pairs$.id]

features <- intersect(attr(pairs, "cmp_cols"), names(pairs))
labelled <- as.data.frame(pairs)[!is.na(pairs$label), , drop = FALSE]

cat("labelled pairs:", nrow(labelled),
    " positives:", sum(labelled$label),
    " features:", length(features), "\n")
cat("features:", paste(features, collapse = ", "), "\n\n")

report <- function(label, train, test) {
  const <- vapply(train[, features, drop = FALSE],
                  function(z) length(unique(z[!is.na(z)])) < 2, TRUE)
  m <- np_train(train)
  co <- stats::coef(m$fit)
  cat(sprintf("%-10s train %2d rows, %d positives | rank %d of %d | aliased: %s\n",
              label, nrow(train), sum(train$label), m$fit$rank, length(co),
              if (any(is.na(co))) paste(names(co)[is.na(co)], collapse = ", ") else "none"))
  if (any(const))
    cat("           constant in train:", paste(names(const)[const], collapse = ", "), "\n")
  withCallingHandlers(
    invisible(stats::predict(m, test)),
    warning = function(cond) {
      cat("           PREDICT WARNING:", conditionMessage(cond), "\n")
      invokeRestart("muffleWarning")
    })
  invisible(NULL)
}

# The full fit is full rank and predicts cleanly; only a fold degenerates.
report("full", labelled, labelled)

fold <- npmatch:::.np_folds(nrow(labelled), 3L, seed = 1L)
for (k in sort(unique(fold)))
  report(paste("fold", k), labelled[fold != k, , drop = FALSE],
         labelled[fold == k, , drop = FALSE])

cat("\nnp_benchmark(k = 3), warnings captured:\n")
withCallingHandlers(
  invisible(np_benchmark(pairs, methods = c("weighted", "em", "model"), k = 3)),
  warning = function(cond) {
    cat("  WARN:", conditionMessage(cond), "\n")
    invokeRestart("muffleWarning")
  })
