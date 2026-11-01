# npnormalize 0.1.4's `street_has_box` is deliberately NOT consumed here. These
# tests are the guard on that decision: they pin the facts that make the column
# redundant for npmatch, so that if npnormalize's parse ever regresses, this
# suite fails instead of npmatch silently scoring a box number as a house
# number. See dev/STREET-HAS-BOX.md for the measurement behind each one.

box_pair <- function(qstreet, rstreet, name = "ACME FOUNDATION",
                     zip = "99801", city = "JUNEAU", config = np_config()) {
  mq <- c(.id = "unique_entity_id", name = "name", street = "street",
          city = "city", state = "state", zip5 = "zip")
  mr <- c(.ein = "ein", name = "name", street = "street",
          city = "city", state = "state", zip5 = "zip")
  q <- np_normalize(np_query(data.frame(unique_entity_id = "1", name = name,
        street = qstreet, city = city, state = "AK", zip = zip,
        stringsAsFactors = FALSE), mq))
  r <- np_normalize(np_reference(data.frame(ein = "1", name = name,
        street = rstreet, city = city, state = "AK", zip = zip,
        stringsAsFactors = FALSE), mr))
  np_compare(q, r, config = config, block = "state")
}

# The premise of the whole decision: once npnormalize 0.1.4 anchored the parse
# gate, a street that merely CARRIES a box keeps its own house number. So
# `street_num` holds a box number only where `is_po_box` is TRUE -- which
# npmatch already reads, as `geo_pobox`.
test_that("a street that carries a box keeps its house number, not the box number", {
  skip_if_not_installed("npnormalize")
  s <- c("211 EMMET ST S PO BOX", "520 N MAIN ST BOX 30", "280 SALEM ST BOX B",
         "6606 W BROAD ST PO BOX 26234")
  expect_true(all(npnormalize::np_has_box(s)))
  expect_false(any(npnormalize::np_is_po_box(s)))
  r <- np_normalize(np_reference(data.frame(ein = as.character(seq_along(s)),
        name = "ACME", street = s, city = "JUNEAU", state = "AK",
        zip = "99801", stringsAsFactors = FALSE),
        c(.ein = "ein", name = "name", street = "street", city = "city",
          state = "state", zip5 = "zip")))
  expect_equal(r$street_num, c("211", "520", "280", "6606"))
  expect_false(any(r$is_po_box))
  # a box number never reaches the unit identifier either, so `geo_unit` cannot
  # read one as a door number
  expect_true(all(is.na(r$street_unit_id)))
})

# Direction 1: the query is a box, the reference a door. The numbers DO agree --
# `geo_stnum` is 1, the collision the column was offered to guard -- but the
# street bodies cannot clear `.np_hier_score()`'s 0.9 floor, so `street_hit`
# never fires and the pair is never credited with a shared building.
test_that("a box number agreeing with a house number earns no street credit", {
  p <- box_pair("PO BOX 211", "211 EMMET ST S")
  expect_equal(p$geo_stnum, 1L)        # the numbers agree
  expect_equal(p$geo_pobox, 0L)        # but only one side is a box
  expect_lt(p$street_key, 0.9)         # and the street bodies do not agree
  # so the pair scores exactly as it would with no street evidence at all
  expect_equal(np_score(p, method = "hier")$score,
               np_score(box_pair(NA, NA), method = "hier")$score,
               tolerance = 1e-9)
})

# Direction 2: the reverse. Same conclusion, so there is no asymmetry to exploit.
test_that("the reverse direction -- door against box -- is also uncredited", {
  p <- box_pair("211 EMMET ST S", "PO BOX 211")
  expect_equal(p$geo_stnum, 1L)
  expect_equal(p$geo_pobox, 0L)
  expect_lt(p$street_key, 0.9)
  expect_equal(np_score(p, method = "hier")$score,
               np_score(box_pair(NA, NA), method = "hier")$score,
               tolerance = 1e-9)
})

# The pair a `street_has_box` veto would have broken. "211 EMMET ST S PO BOX"
# carries a box and "211 EMMET ST S" does not, so the column DISAGREES across
# the pair -- yet 211 is a genuine house number on both sides and this is one
# building. A veto on a disagreeing flag would refuse it outright.
test_that("a street carrying a box still matches the same street without one", {
  skip_if_not_installed("npnormalize")
  expect_true(npnormalize::np_has_box("211 EMMET ST S PO BOX"))
  expect_false(npnormalize::np_has_box("211 EMMET ST S"))
  # under Jaro-Winkler the trailing box word leaves the street body above the
  # 0.9 floor, so the shared building IS credited and the pair scores above one
  # with no street evidence -- exactly what a flag-disagreement veto would have
  # taken away
  jw <- np_config(jw_p = 0.1)
  p <- box_pair("211 EMMET ST S PO BOX", "211 EMMET ST S", config = jw)
  expect_equal(p$geo_stnum, 1L)                   # the same house number
  expect_equal(p$geo_pobox, 0L)                   # neither side is a box
  expect_gte(p$street_key, 0.9)                   # and the same street body
  expect_gt(np_score(p, method = "hier", config = jw)$score,
            np_score(box_pair(NA, NA, config = jw), method = "hier",
                     config = jw)$score)
})

# What the trailing box word DOES cost, so it is on the record. Under the
# default comparator (`jw_p = NULL` is plain Jaro with no prefix boost -- see
# [np_config()]) the box word drags the street body to 0.889, below the 0.9
# floor, so the building is not credited and the pair falls back to its ZIP.
# That is a property of the box word sitting in `street_key`, which
# `street_has_box` does not change: the flag says the tail is there, it does not
# remove it. The shape occurs 0 times in the 304,274-pair labeled benchmark.
test_that("under plain Jaro the box word costs the pair its street credit", {
  p <- box_pair("211 EMMET ST S PO BOX", "211 EMMET ST S")
  expect_equal(p$geo_stnum, 1L)
  expect_lt(p$street_key, 0.9)
  # not refused, and not scored down past its ZIP: it lands exactly where a
  # ZIP5-only pair lands
  expect_equal(np_score(p, method = "hier")$score,
               np_score(box_pair(NA, NA), method = "hier")$score,
               tolerance = 1e-9)
})
