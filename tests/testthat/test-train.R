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
  bench <- np_benchmark(p, methods = c("weighted", "em", "model"), k = 3)
  expect_true(all(c("method", "auc", "yes", "yes_precision") %in% names(bench)))
  expect_setequal(bench$method, c("weighted", "em", "model"))
  # every method should order true matches above non-matches here
  expect_true(all(bench$auc >= 0.75, na.rm = TRUE))
})
