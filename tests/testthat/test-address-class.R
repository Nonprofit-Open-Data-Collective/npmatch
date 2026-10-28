# What a shared address IS, which decides what its evidence is worth. Counts
# alone cannot tell a federated parent from a fiscal sponsor; the share of
# records carrying the most common name can.

# n records at one address, with the names and suites given
at_one_address <- function(names, units = NA_character_, street = "127 FILMORE LN",
                           zip = "78701") {
  n <- length(names)
  data.frame(
    ein    = sprintf("%03d", seq_len(n)),
    name   = names,
    street = ifelse(is.na(units), street, paste(street, units)),
    city   = "AUSTIN", state = "TX", zip = zip, dba_name = "",
    stringsAsFactors = FALSE)
}

# np_addr_freq()'s classification tests moved to npnormalize with the
# normalizer; these test how np_compare() and scoring use the class.

test_that("the thin-suite gate withholds the credit the suite match would earn", {
  # Two candidates differing only in suite, at an address where almost nothing
  # records a suite. The match is still reported; it is simply not scored.
  ref <- at_one_address(c(paste(LETTERS[1:2], "ARTS COLLECTIVE"),
                          paste(LETTERS[3:12], "ARTS COLLECTIVE")),
                        units = c("STE 101", "STE 102", rep(NA, 10)))
  qry <- data.frame(unique_entity_id = "q1", name = "A ARTS COLLECTIVE",
                    dba_name = "", street = "127 FILMORE LN STE 101",
                    city = "AUSTIN", state = "TX", zip = "78701",
                    stringsAsFactors = FALSE)
  p <- np_compare(np_normalize(np_query(qry, np_test_map_q)),
                  np_normalize(np_reference(ref, np_test_map_r)), block = "state")
  hit <- p[p$.ein == "001", ]
  expect_equal(hit$geo_unit, 1L)               # the suites do match
  expect_lt(hit$addr_unit_coverage, 0.5)
  blind <- p; blind$geo_unit <- NA_integer_
  expect_equal(np_score(p, method = "hier")$score,
               np_score(blind, method = "hier")$score)
})

test_that("np_compare labels the pair and says so in words for a reviewer", {
  ref <- at_one_address(rep("PEO SISTERHOOD INTERNATIONAL CHAPTER", 12))
  qry <- data.frame(unique_entity_id = "q1",
                    name = "PEO SISTERHOOD INTERNATIONAL CHAPTER",
                    dba_name = "", street = "127 FILMORE LN", city = "AUSTIN",
                    state = "TX", zip = "78701", stringsAsFactors = FALSE)
  p <- np_compare(np_normalize(np_query(qry, np_test_map_q)),
                  np_normalize(np_reference(ref, np_test_map_r)), block = "state")
  expect_equal(unique(p$addr_class), "federated")
  expect_match(unique(p$addr_note), "^federated address: 12 records here, 100%")
  expect_match(unique(p$addr_note), "does not separate them", fixed = TRUE)
})
