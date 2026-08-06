test_that("name_key uppercases, de-punctuates, and strips trailing legal suffixes", {
  d <- np_query(data.frame(unique_entity_id = c("1","2","3"),
                           name = c("Widget, LLC", "Acme Corp.", "Globex Inc"),
                           state = "AZ", stringsAsFactors = FALSE),
                c(.id = "unique_entity_id", name = "name", state = "state"))
  d <- np_normalize(d)
  expect_equal(d$name_key, c("WIDGET", "ACME", "GLOBEX"))
  expect_equal(d$name_form, c("LLC", "CORP", "INC"))
})

test_that("a leading THE is stripped from the match key but kept in name_full", {
  d <- np_query(data.frame(unique_entity_id = c("1", "2"),
                           name = c("THE SAN DIEGO EDUCATION FOUNDATION", "THEATER GUILD"),
                           state = "CA", stringsAsFactors = FALSE),
                c(.id = "unique_entity_id", name = "name", state = "state"))
  d <- np_normalize(d)
  expect_equal(d$name_key, c("SAN DIEGO EDUCATION", "THEATER GUILD"))  # THE stripped, THEATER intact
  expect_match(d$name_full[1], "^THE ")
})

test_that("generation, number, and ordinal features are extracted", {
  d <- np_reference(data.frame(ein = c("1","2","3","4"),
        name = c("KEN GRIFFEY JR", "IBEW LOCAL 32", "FIRST BAPTIST CHURCH",
                 "KEN GRIFFEY SR"),
        state = "AK", stringsAsFactors = FALSE),
        c(.ein = "ein", name = "name", state = "state"))
  d <- np_normalize(d)
  expect_equal(d$name_gen, c("JR", NA, NA, "SR"))       # JR/SR only; roman is not generational
  expect_equal(d$name_gen_rank, c("2", NA, NA, "1"))
  expect_equal(d$name_nums, c(NA, "32", NA, NA))
  expect_equal(d$name_ord, c(NA, NA, "1", NA))
})

test_that("ordinal words are not treated as generation markers", {
  d <- np_reference(data.frame(ein = "1", name = "SECOND BAPTIST CHURCH",
                               state = "AK", stringsAsFactors = FALSE),
                    c(.ein = "ein", name = "name", state = "state"))
  d <- np_normalize(d)
  expect_true(is.na(d$name_gen))
  expect_equal(d$name_ord, "2")
})

test_that("address normalization splits zip5 and strips the unit from the key", {
  d <- np_query(data.frame(unique_entity_id = "1", name = "X",
                           street = "3406 GLACIER HWY STE A", zip = "99801-9501",
                           state = "AK", stringsAsFactors = FALSE),
                c(.id = "unique_entity_id", name = "name", street = "street",
                  zip5 = "zip", state = "state"))
  d <- np_normalize(d)
  expect_equal(d$zip5, "99801")
  expect_equal(d$street_key, "3406 GLACIER HWY")
  expect_equal(d$street_unit, "STE A")
})
