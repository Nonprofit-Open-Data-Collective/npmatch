# The suite number: parsed out of the address, compared as an identifier, and
# credited only where it actually distinguishes one tenant from another.
# The suite parser and np_addr_freq() tests moved to npnormalize with the
# normalizer; these test how npmatch scores and reports the suite.

test_that("an exact suite match lifts a candidate in a multi-tenant building", {
  # The fixtures put two organisations at 430 W 7TH AVE, in STE 202 and STE 200.
  # An exact-address match surfaces both, so the suite is the only thing between
  # them, which is the case this credit exists for.
  q <- np_normalize(np_query(np_test_query(), np_test_map_q))
  r <- np_normalize(np_reference(np_test_reference(), np_test_map_r))
  p <- np_compare(q, r, block = "state")
  row <- function(df, ein) df[df$.id == "q2" & df$.ein == ein, ]
  expect_equal(row(p, "10")$geo_unit, 1L)
  expect_equal(row(p, "08")$geo_unit, 0L)
  expect_true(is.na(row(p, "05")$geo_unit))
  expect_equal(row(p, "10")$addr_units, 2L)

  s <- np_score(p, method = "hier")
  blind <- p; blind$geo_unit <- NA_integer_
  s0 <- np_score(blind, method = "hier")
  expect_gt(row(s, "10")$score, row(s0, "10")$score)
  # nothing else moves: a differing suite and an absent suite both cost 0,
  # because the geo terms combine with max()
  for (e in c("05", "08", "11", "14", "09"))
    expect_equal(row(s, e)$score, row(s0, e)$score)
})

test_that("a suite shared by a crowd is reported, not credited", {
  # 12 nonprofits in one suite is a fiscal sponsor or a registered agent, and
  # sharing it says nothing about being the same organisation.
  ref <- data.frame(
    ein = sprintf("%02d", 1:12), name = paste("SPONSORED PROJECT", 1:12),
    street = "127 FILMORE LN STE 320", city = "AUSTIN", state = "TX",
    zip = "78701", dba_name = "", stringsAsFactors = FALSE)
  qry <- data.frame(unique_entity_id = "q1", name = "SPONSORED PROJECT 1",
                    dba_name = "", street = "127 FILMORE LN STE 320",
                    city = "AUSTIN", state = "TX", zip = "78701",
                    stringsAsFactors = FALSE)
  p <- np_compare(np_normalize(np_query(qry, np_test_map_q)),
                  np_normalize(np_reference(ref, np_test_map_r)), block = "state")
  expect_true(all(p$geo_unit == 1L))
  expect_equal(unique(p$addr_unit_shared), 12L)
  expect_equal(unique(p$addr_note), "12 records share this address and suite")

  s <- np_score(p, method = "hier")
  blind <- p; blind$geo_unit <- NA_integer_
  expect_equal(s$score, np_score(blind, method = "hier")$score)
})

test_that("the adjudication prompt states the suite and a shared address", {
  ref <- data.frame(
    ein = sprintf("%02d", 1:12), name = paste("SPONSORED PROJECT", 1:12),
    street = "127 FILMORE LN STE 320", city = "AUSTIN", state = "TX",
    zip = "78701", dba_name = "", stringsAsFactors = FALSE)
  qry <- data.frame(unique_entity_id = "q1", name = "SPONSORED PROJECTS",
                    dba_name = "", street = "127 FILMORE LN STE 320",
                    city = "AUSTIN", state = "TX", zip = "78701",
                    stringsAsFactors = FALSE)
  res <- np_match(np_query(qry, np_test_map_q), np_reference(ref, np_test_map_r),
                  method = "hier")
  rt  <- np_route(res)
  skip_if(nrow(rt$review) == 0, "nothing routed to review in this fixture")
  txt <- np_as_prompt(rt, "q1")
  expect_match(txt, "same suite", fixed = TRUE)
  expect_match(txt, "Note: 12 records share this address and suite", fixed = TRUE)
})
