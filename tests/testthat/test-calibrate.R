test_that("np_calibration_frame samples across tiers and is label-ready", {
  res <- np_match(np_test_query(), np_test_reference(),
                  query_map = np_test_map_q, reference_map = np_test_map_r)
  cf <- np_calibration_frame(res, per_tier = c(YES = 5, MAYBE = 5, NO = 5), k = 2)

  expect_s3_class(cf, "np_calibration")
  need <- c(".id", ".ein", "name_x", "name_y", "name_sim", "addr_sim", "score",
            "candidate_type", "query_tier", "is_overall", "label")
  expect_true(all(need %in% names(cf)))
  expect_true(all(is.na(cf$label)))                 # empty, ready to fill
  # every sampled query keeps its chosen overall candidate
  expect_true(all(tapply(cf$is_overall, cf$.id, any)))
})

test_that("per_tier caps the number of sampled queries", {
  res <- np_match(np_test_query(), np_test_reference(),
                  query_map = np_test_map_q, reference_map = np_test_map_r)
  cf <- np_calibration_frame(res, per_tier = c(YES = 1, MAYBE = 1, NO = 1))
  expect_lte(length(unique(cf$.id)), 3)
})

test_that("a labelled calibration frame flows back into the training loop", {
  res <- np_match(np_test_query(), np_test_reference(),
                  query_map = np_test_map_q, reference_map = np_test_map_r)
  cf <- np_calibration_frame(res, per_tier = c(YES = 9, MAYBE = 9, NO = 9), k = 3)
  # simulate labelling by ground truth
  truth <- c(q1 = "05", q2 = "10", q3 = "11", q4 = "14")
  cf$label <- cf$.ein == truth[cf$.id]

  labels <- cf[, c(".id", ".ein", "label")]
  pairs <- np_label(attr(res, "pairs"), labels)
  th <- np_tune_thresholds(pairs$score[!is.na(pairs$label)],
                           pairs$label[!is.na(pairs$label)],
                           target_precision = 0.9, min_recall = 0.5)
  expect_true(th[["yes"]] >= th[["maybe"]])
})
