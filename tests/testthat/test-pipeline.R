test_that("geo profile is detected from populated fields", {
  q <- np_query(np_test_query(), np_test_map_q)
  expect_equal(as.character(np_detect_geo(q)), "street_full")

  q2 <- q; q2$street <- NA; q2$zip5 <- NA
  expect_equal(as.character(np_detect_geo(q2)), "city_state")
})

test_that("np_match returns a tiered result resolving obvious matches to the right EIN", {
  res <- np_match(np_test_query(), np_test_reference(),
                  query_map = np_test_map_q, reference_map = np_test_map_r)
  expect_s3_class(res, "np_tiered")
  expect_equal(nrow(res), 4)

  row1 <- res[res$.id == "q1", ]
  expect_equal(row1$overall_ein, "05")          # SALMON CREEK HOUSING
  expect_equal(as.character(row1$tier), "YES")

  row4 <- res[res$.id == "q4", ]
  expect_equal(row4$overall_ein, "14")          # NOME COMMUNITY CENTER
  expect_equal(as.character(row4$tier), "YES")
})

test_that("loosened views are populated and the agreement flag is well-formed", {
  res <- np_match(np_test_query(), np_test_reference(),
                  query_map = np_test_map_q, reference_map = np_test_map_r)
  expect_true(all(c("name_ein", "addr_ein", "views_agree") %in% names(res)))
  expect_type(res$views_agree, "logical")
  expect_false(anyNA(res$views_agree))
})

test_that("view disagreement is flagged and blocks auto-YES", {
  # name points at one EIN, address points at a different EIN
  ref <- data.frame(
    ein = c("A", "B"),
    name = c("HELPING HANDS FOUNDATION", "COMPLETELY UNRELATED SOCIETY"),
    street = c("999 FAR AWAY RD", "100 MAIN ST"),
    city = c("NOME", "JUNEAU"), state = "AK",
    zip = c("99762", "99801"), dba_name = "", stringsAsFactors = FALSE)
  qry <- data.frame(
    unique_entity_id = "z1", name = "HELPING HANDS FOUNDATION", dba_name = "",
    street = "100 MAIN ST", city = "JUNEAU", state = "AK", zip = "99801",
    stringsAsFactors = FALSE)
  res <- np_match(qry, ref, query_map = np_test_map_q, reference_map = np_test_map_r)
  expect_equal(res$name_ein, "A")   # name matches A
  expect_equal(res$addr_ein, "B")   # address matches B
  expect_false(res$views_agree)
  expect_true(as.character(res$tier) %in% c("MAYBE", "NO"))
})

test_that("EM scoring runs and yields a 0-1 score", {
  res <- np_match(np_test_query(), np_test_reference(), method = "em",
                  query_map = np_test_map_q, reference_map = np_test_map_r)
  expect_true(all(res$overall_score >= 0 & res$overall_score <= 1, na.rm = TRUE))
})

test_that("label frame emits candidates with an empty label column", {
  res <- np_match(np_test_query(), np_test_reference(),
                  query_map = np_test_map_q, reference_map = np_test_map_r)
  lf <- np_label_frame(attr(res, "pairs"), k = 2)
  expect_true(all(c(".id", ".ein", "score", "candidate_type", "label") %in% names(lf)))
  expect_true(all(is.na(lf$label)))
  expect_true(nrow(lf) >= 4)
})
