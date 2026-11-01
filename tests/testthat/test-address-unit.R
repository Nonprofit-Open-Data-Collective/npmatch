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

test_that(".np_unit_kind() folds the doors and keeps every other place apart", {
  # One door written eight ways. These must fold, because the identifier
  # comparison already treats them as one and it is right to.
  doors <- c("STE 320", "APT 320", "UNIT 320", "RM 320", "SPC 320",
             "TRLR 320", "LOT 320", "# 320")
  expect_equal(unique(.np_unit_kind(doors)), "DOOR")
  # Different kinds of place, each its own class.
  expect_equal(.np_unit_kind(c("FL 2", "PMB 2", "DEPT 2", "BLDG 2", "BSMT 2")),
               c("FL", "PMB", "DEPT", "BLDG", "BSMT"))
  # A designator this package has never heard of becomes its own class, which is
  # the conservative answer: it can only make the annotation more cautious, and
  # it never reaches a score. So npnormalize adding a designator cannot silently
  # fold it into the doors.
  expect_equal(.np_unit_kind("WING 4"), "WING")
  expect_true(all(is.na(.np_unit_kind(c(NA_character_, "")))))
})

test_that("the same number on different kinds of unit is not the same suite", {
  # street_unit_id drops the designator, so "FL 2" and "STE 2" share an
  # identifier -- the same drop that makes "STE 320" and "# 320" agree, which is
  # correct. A floor is not a suite; geo_unit cannot tell the two cases apart
  # and geo_unit_same_kind is what does.
  qry <- data.frame(unique_entity_id = c("q1", "q2"),
                    name = c("ALPHA TRUST", "BETA FUND"), dba_name = "",
                    street = c("1 PLAZA FL 2", "1 PLAZA STE 320"),
                    city = "AUSTIN", state = "TX", zip = "78701",
                    stringsAsFactors = FALSE)
  ref <- data.frame(ein = c("01", "02"), name = c("ALPHA TRUST", "BETA FUND"),
                    street = c("1 PLAZA STE 2", "1 PLAZA # 320"),
                    city = "AUSTIN", state = "TX", zip = "78701",
                    dba_name = "", stringsAsFactors = FALSE)
  p <- np_compare(np_normalize(np_query(qry, np_test_map_q)),
                  np_normalize(np_reference(ref, np_test_map_r)), block = "state")
  row <- function(id, ein) p[p$.id == id & p$.ein == ein, ]

  # the floor against the suite: one identifier, two kinds of place
  expect_equal(row("q1", "01")$geo_unit, 1L)
  expect_equal(row("q1", "01")$geo_unit_same_kind, 0L)
  # the suite against the bare number: one identifier, one kind of place
  expect_equal(row("q2", "02")$geo_unit, 1L)
  expect_equal(row("q2", "02")$geo_unit_same_kind, 1L)
  # silence on neither side here, but a cross pair differs on both
  expect_equal(row("q1", "02")$geo_unit, 0L)

  # The score is untouched. geo_unit is the only column np_score() reads, so
  # dropping the new one cannot move a single number.
  blind <- p; blind$geo_unit_same_kind <- NULL
  expect_identical(np_score(p, method = "hier")$score,
                   np_score(blind, method = "hier")$score)
})

test_that("the prompt says the kinds differ instead of claiming one suite", {
  # .np_prompt_suite() is the line a reviewer and the stage-2 model read. Both
  # directions matter: the fold must still agree, and the floor must not.
  say <- function(q, c, gu, gk) .np_prompt_suite(
    list(street_unit_uss = q, street_unit_bmf = c,
         geo_unit = gu, geo_unit_same_kind = gk), "uss", "bmf")

  expect_match(say("STE 320", "# 320", 1L, 1L), "same suite", fixed = TRUE)
  fl <- say("FL 2", "STE 2", 1L, 0L)
  expect_false(grepl("same suite", fl, fixed = TRUE))
  expect_match(fl, "not the same kind of unit", fixed = TRUE)
  # both values still printed, so the reviewer can see what was compared
  expect_match(fl, "FL 2", fixed = TRUE)
  expect_match(fl, "STE 2", fixed = TRUE)

  # unchanged elsewhere: a real disagreement, and silence on one side
  expect_match(say("STE 320", "STE 400", 0L, 1L), "different suites",
               fixed = TRUE)
  expect_match(say("STE 320", NA_character_, NA_integer_, NA_integer_),
               "named on one side only", fixed = TRUE)
  # A review frame saved before this column existed gets the right words too:
  # the canonical values are in the frame, so the kinds can be read off them.
  old <- .np_prompt_suite(list(street_unit_uss = "FL 2",
                               street_unit_bmf = "STE 2", geo_unit = 1L),
                          "uss", "bmf")
  expect_match(old, "not the same kind of unit", fixed = TRUE)
  expect_match(.np_prompt_suite(list(street_unit_uss = "STE 320",
                                     street_unit_bmf = "# 320", geo_unit = 1L),
                                "uss", "bmf"), "same suite", fixed = TRUE)
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
