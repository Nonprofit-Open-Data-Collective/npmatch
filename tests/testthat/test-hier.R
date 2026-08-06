# Score a single query/reference pair with the hierarchical geo method.
hier_score <- function(qcity, qzip, rcity, rzip,
                       qstreet = NA, rstreet = NA, name = "ACME FOUNDATION") {
  mq <- c(.id = "unique_entity_id", name = "name", street = "street",
          city = "city", state = "state", zip5 = "zip")
  mr <- c(.ein = "ein", name = "name", street = "street",
          city = "city", state = "state", zip5 = "zip")
  q <- np_normalize(np_query(data.frame(unique_entity_id = "1", name = name,
        street = qstreet, city = qcity, state = "AK", zip = qzip,
        stringsAsFactors = FALSE), mq))
  r <- np_normalize(np_reference(data.frame(ein = "1", name = name,
        street = rstreet, city = rcity, state = "AK", zip = rzip,
        stringsAsFactors = FALSE), mr))
  np_score(np_compare(q, r, block = "state"), method = "hier")$score
}

test_that("a matching ZIP5 eclipses a wrong city (no double-counting, no penalty)", {
  wrong_city <- hier_score("JUNEAU", "99801", "ANCHORAGE", "99801")  # zip5 same, city differs
  right_city <- hier_score("JUNEAU", "99801", "JUNEAU",    "99801")
  expect_equal(wrong_city, right_city, tolerance = 1e-9)
})

test_that("ZIP+4 confirms location more strongly than ZIP5 alone", {
  s9 <- hier_score("JUNEAU", "99801-1234", "JUNEAU", "99801-1234")   # zip9 match
  s5 <- hier_score("JUNEAU", "99801",      "JUNEAU", "99801")        # zip5 only
  expect_gt(s9, s5)
})

test_that("geo score degrades gracefully when ZIP is missing (falls back to city)", {
  s_city  <- hier_score("JUNEAU", NA, "JUNEAU",    NA)   # only city + state
  s_none  <- hier_score("JUNEAU", NA, "ANCHORAGE", NA)   # city differs too
  expect_gt(s_city, s_none)                              # city still contributes
  expect_true(s_city > 0 && s_city < 1)
})

test_that("a matching street number + body beats ZIP5 alone", {
  s_street <- hier_score("JUNEAU", "99801", "JUNEAU", "99801",
                         qstreet = "100 MAIN ST", rstreet = "100 MAIN ST")
  s_zip    <- hier_score("JUNEAU", "99801", "JUNEAU", "99801")
  expect_gte(s_street, s_zip)          # street term (0.95) >= zip5 term (0.90)
})

test_that("hierarchical score stays within [0, 1]", {
  s <- hier_score("JUNEAU", "99801-1234", "JUNEAU", "99801-1234",
                  qstreet = "100 MAIN ST", rstreet = "100 MAIN ST")
  expect_true(s >= 0 && s <= 1)
})

test_that("np_score exposes the hier method end to end via np_match", {
  res <- np_match(np_test_query(), np_test_reference(), method = "hier",
                  query_map = np_test_map_q, reference_map = np_test_map_r)
  expect_s3_class(res, "np_tiered")
  expect_true(all(res$overall_score >= 0 & res$overall_score <= 1, na.rm = TRUE))
})
