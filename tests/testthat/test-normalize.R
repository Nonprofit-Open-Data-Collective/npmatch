# The normalizer's own tests moved to npnormalize with the normalizer. These are
# the ones that need npmatch's blocking or comparison on top of it.

test_that("placeholder query names get no candidates", {
  q <- np_normalize(np_query(data.frame(id = c("1", "2"), name = c("SEE SCHEDULE O", "ACME FDN"), state = "AZ"),
                             c(.id = "id", name = "name", state = "state")))
  r <- np_normalize(np_reference(data.frame(ein = c("9", "8"), name = c("SEE SCHEDULE O", "ACME FOUNDATION"), state = "AZ"),
                                 c(.ein = "ein", name = "name", state = "state")))
  # a state block pairs all 4 combinations; the placeholder query loses its two
  b <- np_block(q, r, by = "state", token = FALSE)
  expect_equal(as.data.frame(b)[, c(".x", ".y")], data.frame(.x = 2L, .y = 1:2))
  b <- np_block(q, r, by = c("state", "name_key"), token = FALSE)
  expect_equal(as.data.frame(b)[, c(".x", ".y")], data.frame(.x = 2L, .y = 2L))
})

test_that("two records with no street do not agree on the street", {
  qmap <- c(.id = "id", name = "nm", street = "st", city = "ci", state = "s", zip5 = "z")
  rmap <- c(.ein = "ein", name = "nm", street = "st", city = "ci", state = "s", zip5 = "z")
  q <- np_normalize(np_query(data.frame(id = c("q1", "q2", "q3"), nm = "ACME CLUB",
                                        st = c(NA, "", "1 MAIN ST"), ci = "X", s = "GA",
                                        z = "30341", stringsAsFactors = FALSE), qmap))
  r <- np_normalize(np_reference(data.frame(ein = c("EIN-10-0000001", "EIN-10-0000002"),
                                            nm = "ACME CLUB", st = c(NA, "1 MAIN ST"),
                                            ci = "X", s = "GA", z = "30341",
                                            stringsAsFactors = FALSE), rmap))
  p <- as.data.frame(np_compare(q, r, profile = "street_full"))
  expect_true("street_key" %in% names(p))
  st <- function(id, ein) p$street_key[p$.id == id & p$.ein == ein]
  # missing on both sides, or on one side: no street evidence either way
  expect_equal(st("q1", "EIN-10-0000001"), 0)
  expect_equal(st("q2", "EIN-10-0000001"), 0)
  expect_equal(st("q1", "EIN-10-0000002"), 0)
  # a real street still agrees with itself
  expect_equal(st("q3", "EIN-10-0000002"), 1)
})
