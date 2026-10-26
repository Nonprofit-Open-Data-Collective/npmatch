# The suite number: parsed out of the address, compared as an identifier, and
# credited only where it actually distinguishes one tenant from another.

test_that("unit designators are parsed, and ordinary words are not mistaken for them", {
  x <- c("123 Main St Ste 300", "123 Main St Suite. 300", "123 Main St # 300",
         "500 BROADWAY ROOM216", "123 Main St 2nd Floor", "1180 NORTHERN BLVD - 2ND FL",
         "30802 COAST HWY SPC F20", "3575 ARDEN WAY PMB 306", "2800 ADMIRAL ST TRLR 14",
         "10317 INDIGO BROOM LOOP", "22148 SHERMAN WAY", "1963 STERLING ST",
         "1617 W FLAGLER ST", "2815 E COMMUNITY DR", "8997 LOCKHART TRLR CT RD",
         "123 NO 5TH ST", "PO BOX 1558", "123 Main St")
  expect_equal(npmatch:::.np_extract_unit(x),
    c("STE 300", "STE 300", "# 300", "RM 216", "FL 2", "FL 2", "SPC F20",
      "PMB 306", "TRLR 14", rep(NA_character_, 9)))
  # the key loses the unit, the number-sign form included: the old strip ran
  # after cleaning, by which time the sign was a space, and left "300" behind
  expect_equal(npmatch:::.np_street_key(x[1:9]),
    c("123 MAIN ST", "123 MAIN ST", "123 MAIN ST", "500 BROADWAY", "123 MAIN ST",
      "1180 NORTHERN BLVD", "30802 COAST HWY", "3575 ARDEN WAY", "2800 ADMIRAL ST"))
  # a street whose name merely contains a designator keeps every token: the old
  # pattern read "BROOM LOOP" as room "OOM LOOP" and keyed this "10317 INDIGO B"
  expect_equal(npmatch:::.np_street_key("10317 INDIGO BROOM LOOP"),
               "10317 INDIGO BROOM LOOP")
  # a designator inside a word must not MASK the real unit either
  expect_equal(npmatch:::.np_extract_unit("259 N RADNOR CHESTER RD STE 150"),
               "STE 150")
})

test_that("the compared identifier ignores how the designator was spelled", {
  # "STE 300", "Suite 300" and "# 300" are one office; 320 and 380 are not the
  # same office to any degree, which is why this is an id and not a string score
  ids <- npmatch:::.np_unit_id(npmatch:::.np_extract_unit(
    c("1 A St Ste 300", "1 A St Suite 300", "1 A St #300", "1 A St Ste D-2",
      "1 A St FL 11TH", "1 A St 11th Floor")))
  expect_equal(ids, c("300", "300", "300", "D2", "11", "11"))
})

test_that("a unit in the second address line is read, not ignored", {
  # SAM keeps the suite in physical_address_line_2. Ignoring that column was a
  # penalty, not a gap: np_detect_geo() weighed the column while nothing
  # compared it, so the unit term scored 0 on every pair.
  d <- data.frame(id = as.character(1:3), nm = "ACME FUND", st = "123 Main St",
                  un = c("STE 300", "300", ""), state = "TX",
                  stringsAsFactors = FALSE)
  m <- c(.id = "id", name = "nm", street = "st", unit = "un", state = "state")
  q <- np_normalize(np_query(d, m))
  expect_equal(q$street_unit, c("STE 300", "# 300", NA))
  expect_equal(q$street_unit_id, c("300", "300", NA))
  # the street line wins when both name a unit
  q2 <- np_normalize(np_query(transform(d, st = "123 Main St Ste 410"), m))
  expect_equal(q2$street_unit_id, rep("410", 3))
})

test_that("np_addr_freq counts tenants per address and per suite, PO boxes aside", {
  af <- np_addr_freq(
    street_keys = c("430 W 7TH AVE", "430 W 7TH AVE", "430 W 7TH AVE",
                    "104 DIVISION ST", "PO BOX 80547"),
    zip5 = c("99501", "99501", "99501", "99762", "99708"),
    unit_ids = c("200", "202", "202", NA, NA))
  expect_s3_class(af, "np_addr_freq")
  expect_equal(af$addr[["430 W 7TH AVE 99501"]], 3L)
  expect_equal(af$units[["430 W 7TH AVE 99501"]], 2L)
  expect_equal(af$addr_unit[["430 W 7TH AVE 99501|202"]], 2L)
  expect_false("PO BOX 80547 99708" %in% names(af$addr))
  expect_equal(af$share_min, 10L)
})

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
