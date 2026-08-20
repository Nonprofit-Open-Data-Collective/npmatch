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

test_that("a shared city name across different states earns no location credit", {
  # Patterson LA vs Patterson NC are different places. Ungated this scored
  # 0.6*name + 0.4*city = 0.80 and auto-accepted.
  cfg <- np_config()
  same <- data.frame(name_key = 1, city = 1, state_x = "LA", state_y = "LA",
                     geo_state = 1, stringsAsFactors = FALSE)
  diff <- data.frame(name_key = 1, city = 1, state_x = "LA", state_y = "NC",
                     geo_state = 0, stringsAsFactors = FALSE)
  s_same <- npmatch:::.np_hier_score(same, cfg)
  s_diff <- npmatch:::.np_hier_score(diff, cfg)
  expect_gt(s_same, s_diff)
  expect_lt(s_diff, cfg$thresholds[["yes"]])   # must not auto-accept
})

test_that("a missing state still earns city credit", {
  cfg <- np_config()
  miss <- data.frame(name_key = 1, city = 1, state_x = NA_character_,
                     state_y = "NC", geo_state = 0, stringsAsFactors = FALSE)
  none <- data.frame(name_key = 1, city = 0, state_x = NA_character_,
                     state_y = "NC", geo_state = 0, stringsAsFactors = FALSE)
  expect_gt(npmatch:::.np_hier_score(miss, cfg), npmatch:::.np_hier_score(none, cfg))
})

test_that("the distinctive-name promotion requires an informative name, not just a rare one", {
  # name_freq measures lexical rarity. "COMMUNITY CHURCH" is unique in the BMF as
  # a literal string yet identifies nothing; a low name_idf must block promotion.
  cfg <- np_config(distinct_name_min_idf = 10)
  base <- data.frame(name_key = 1, name_freq = 1, geo_state = 1,
                     state_x = "CA", state_y = "CA", stringsAsFactors = FALSE)
  informative <- transform(base, name_idf = 20)
  generic     <- transform(base, name_idf = 6)
  expect_gte(npmatch:::.np_hier_score(informative, cfg), cfg$distinct_name_floor)
  expect_lt(npmatch:::.np_hier_score(generic, cfg), cfg$distinct_name_floor)
})

test_that("callers that supply no token_idf keep the previous promotion behaviour", {
  cfg <- np_config(distinct_name_min_idf = 10)
  no_idf <- data.frame(name_key = 1, name_freq = 1, geo_state = 1,
                       state_x = "CA", state_y = "CA", name_idf = NA_real_,
                       stringsAsFactors = FALSE)
  expect_gte(npmatch:::.np_hier_score(no_idf, cfg), cfg$distinct_name_floor)
})

test_that("setting distinct_name_min_idf to 0 disables the gate", {
  cfg <- np_config(distinct_name_min_idf = 0)
  generic <- data.frame(name_key = 1, name_freq = 1, geo_state = 1,
                        state_x = "CA", state_y = "CA", name_idf = 0,
                        stringsAsFactors = FALSE)
  expect_gte(npmatch:::.np_hier_score(generic, cfg), cfg$distinct_name_floor)
})

test_that("the distinctive-name promotion only fires on a primary-name match", {
  # name_freq / name_idf describe the reference's PRIMARY name. If the match was
  # made on a short generic DBA, those statistics justify a different string:
  # "COMMUNITY CHURCH" matched the DBA of FORT JONES COMMUNITY CHURCH and was
  # auto-accepted to a congregation 700 miles from the grant.
  cfg <- np_config(distinct_name_main_only = TRUE)
  base <- data.frame(name_key = 1, name_freq = 1, geo_state = 1,
                     state_x = "CA", state_y = "CA", name_ver_x = "MAIN",
                     stringsAsFactors = FALSE)
  on_main <- transform(base, name_ver_y = "MAIN")
  on_dba  <- transform(base, name_ver_y = "DBA")
  expect_gte(npmatch:::.np_hier_score(on_main, cfg), cfg$distinct_name_floor)
  expect_lt(npmatch:::.np_hier_score(on_dba, cfg), cfg$distinct_name_floor)
})

test_that("distinct_name_main_only = FALSE restores the old behaviour", {
  cfg <- np_config(distinct_name_main_only = FALSE)
  on_dba <- data.frame(name_key = 1, name_freq = 1, geo_state = 1,
                       state_x = "CA", state_y = "CA", name_ver_x = "MAIN",
                       name_ver_y = "DBA", stringsAsFactors = FALSE)
  expect_gte(npmatch:::.np_hier_score(on_dba, cfg), cfg$distinct_name_floor)
})

test_that("pairs without a name_ver column are not gated", {
  cfg <- np_config(distinct_name_main_only = TRUE)
  no_ver <- data.frame(name_key = 1, name_freq = 1, geo_state = 1,
                       state_x = "CA", state_y = "CA", stringsAsFactors = FALSE)
  expect_gte(npmatch:::.np_hier_score(no_ver, cfg), cfg$distinct_name_floor)
})
