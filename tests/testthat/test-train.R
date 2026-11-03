# Build a labelled candidate set from the fixtures using ground truth.
np_test_labeled_pairs <- function() {
  q <- np_normalize(np_query(np_test_query(), np_test_map_q))
  r <- np_normalize(np_reference(np_test_reference(), np_test_map_r))
  p <- np_veto(np_score(np_compare(q, r, block = "state")))
  truth <- c(q1 = "05", q2 = "10", q3 = "11", q4 = "14")
  p$label <- p$.ein == truth[p$.id]
  p
}

test_that("np_label joins labels back by (.id, .ein)", {
  q <- np_normalize(np_query(np_test_query(), np_test_map_q))
  r <- np_normalize(np_reference(np_test_reference(), np_test_map_r))
  p <- np_score(np_compare(q, r, block = "state"))
  labels <- data.frame(.id = "q1", .ein = "05", label = TRUE, stringsAsFactors = FALSE)
  p <- np_label(p, labels)
  expect_true("label" %in% names(p))
  expect_true(isTRUE(p$label[p$.id == "q1" & p$.ein == "05"]))
  expect_true(all(is.na(p$label[p$.id == "q1" & p$.ein != "05"])))
})

test_that("np_train returns a usable model that plugs into np_score", {
  p <- np_test_labeled_pairs()
  m <- np_train(p, engine = "logit")
  expect_s3_class(m, "np_model")
  scored <- np_score(p, method = "model", model = m)
  expect_true(all(scored$score >= 0 & scored$score <= 1))
  # true matches should score above the mean
  expect_gt(mean(scored$score[p$label]), mean(scored$score[!p$label]))
})

test_that("np_train errors without both classes present", {
  p <- np_test_labeled_pairs()
  p$label <- FALSE
  expect_error(np_train(p), "both matched and non-matched")
})

test_that("np_evaluate and np_auc report sane metrics on separable data", {
  score <- c(0.9, 0.8, 0.85, 0.2, 0.1, 0.3)
  label <- c(TRUE, TRUE, TRUE, FALSE, FALSE, FALSE)
  expect_equal(np_auc(score, label), 1)
  ev <- np_evaluate(score, label, threshold = 0.5)
  expect_equal(ev$precision, 1)
  expect_equal(ev$recall, 1)
})

test_that("np_tune_thresholds keeps yes >= maybe and hits target precision", {
  score <- c(0.95, 0.92, 0.9, 0.6, 0.55, 0.2, 0.1)
  label <- c(TRUE, TRUE, TRUE, FALSE, TRUE, FALSE, FALSE)
  th <- np_tune_thresholds(score, label, target_precision = 1, min_recall = 0.75)
  expect_true(th[["yes"]] >= th[["maybe"]])
  m <- attr(th, "metrics")
  expect_gte(m$yes_precision, 1 - 1e-9)
})

test_that("np_benchmark compares methods and separates matches", {
  p <- np_test_labeled_pairs()
  # Fold 2 of this 24-row fixture is rank-deficient (see
  # dev/BENCHMARK-RANK-DEFICIENCY.md), but np_benchmark() now accounts for that
  # in its result rather than on the console, so the call is simply silent.
  expect_silent(bench <- np_benchmark(p, methods = c("weighted", "em", "model"), k = 3))
  expect_true(all(c("method", "auc", "yes", "yes_precision") %in% names(bench)))
  expect_setequal(bench$method, c("weighted", "em", "model"))
  # every method should order true matches above non-matches here
  expect_true(all(bench$auc >= 0.75, na.rm = TRUE))
})

test_that("np_train reports and records terms it had to drop", {
  p <- np_test_labeled_pairs()
  # An exact duplicate column cannot be estimated alongside its original, so
  # glm aliases it. That is the realistic case the warning exists for: a
  # similarity column that is constant, or says the same thing as another.
  p$zip5_copy <- p$zip5
  attr(p, "cmp_cols") <- c(attr(p, "cmp_cols"), "zip5_copy")

  expect_warning(m <- np_train(p), class = "np_rank_deficient")
  expect_warning(np_train(p), "zip5_copy")
  expect_identical(m$aliased, "zip5_copy")
  expect_identical(m$rank, 5L)
  expect_identical(m$n_terms, 6L)
  expect_output(print(m), "dropped as collinear: zip5_copy", fixed = TRUE)

  # predict() must not repeat it: np_train() already said it by name.
  expect_silent(s <- predict(m, as.data.frame(p)))
  expect_true(all(is.finite(s)))
})

test_that("np_train is quiet and records full rank when every term is estimable", {
  p <- np_test_labeled_pairs()
  expect_silent(m <- np_train(p))
  expect_identical(m$aliased, character())
  expect_identical(m$rank, m$n_terms)
  expect_output(print(m), "rank 5 of 5 terms", fixed = TRUE)
})

test_that("np_benchmark counts rank-deficient folds in its result", {
  p <- np_test_labeled_pairs()
  bench <- np_benchmark(p, methods = c("weighted", "em", "model"), k = 3)

  # One of the three folds degenerates; the unsupervised rows have no folds.
  expect_identical(bench$rank_deficient_folds[bench$method == "model"], 1L)
  expect_true(all(is.na(bench$rank_deficient_folds[bench$method != "model"])))

  rd <- attr(bench, "rank_deficient")
  expect_named(rd, "2")
  expect_setequal(rd[["2"]], c("street_key", "zip5"))
})

test_that("np_benchmark reports no deficient folds when every fold is full rank", {
  # The shared fixture degenerates at every k worth trying, so a
  # well-conditioned frame is built here: 40 rows, 20 positive, two continuous
  # features. Guards against the count being reported unconditionally.
  set.seed(42)
  n <- 40
  d <- data.frame(
    .id  = sprintf("q%02d", seq_len(n)),
    .ein = sprintf("%02d", seq_len(n)),
    f1   = round(stats::runif(n), 3),
    f2   = round(stats::runif(n), 3)
  )
  d$label <- c(rep(TRUE, n / 2), rep(FALSE, n / 2))
  d$f1 <- round(ifelse(d$label, d$f1 * 0.4 + 0.6, d$f1 * 0.4), 3)
  attr(d, "cmp_cols") <- c("f1", "f2")

  expect_silent(bench <- np_benchmark(d, methods = "model", k = 3))
  expect_identical(bench$rank_deficient_folds, 0L)
  expect_identical(attr(bench, "rank_deficient"), list())
})
