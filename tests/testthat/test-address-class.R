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

freq_of <- function(df, ...) {
  r <- np_normalize(np_reference(df, np_test_map_r))
  np_addr_freq(r$street_key, r$zip5, r$street_unit_id, r$name_key, ...)
}

test_that("a federated address is told apart from a sponsor address", {
  # 12 chapters filing from one national office under one name: the address
  # matches every chapter equally, and so would a suite. The real
  # discriminator is the chapter number, which np_veto() already uses.
  fed <- freq_of(at_one_address(rep("PEO SISTERHOOD INTERNATIONAL CHAPTER", 12)))
  k <- "127 FILMORE LN 78701"
  expect_equal(fed$class[[k]], "federated")
  expect_equal(fed$n_names[[k]], 1L)
  expect_equal(fed$top_name_share[[k]], 1)

  # 12 unrelated foundations at a fiscal sponsor: the NAME separates them, so
  # the address is true but uninformative
  spo <- freq_of(at_one_address(paste(LETTERS[1:12], "FAMILY FOUNDATION")))
  expect_equal(spo$class[[k]], "shared")
  expect_equal(spo$n_names[[k]], 12L)
  expect_lt(spo$top_name_share[[k]], 0.5)
})

test_that("a multi-tenant building is recognised, and thin suite data is not", {
  k <- "127 FILMORE LN 78701"
  # every tenant records a distinct suite: the suite is the discriminator
  bld <- freq_of(at_one_address(paste(LETTERS[1:12], "ARTS COLLECTIVE"),
                                units = paste("STE", 100 + seq_len(12))))
  expect_equal(bld$class[[k]], "building")
  expect_equal(bld$units[[k]], 12L)
  expect_equal(bld$unit_coverage[[k]], 1)

  # the same building, but the reference recorded a suite for only 2 of 12.
  # "two distinct suites here" then describes the data, not the building: at
  # the BMF addresses holding 10+ records the share naming a suite averages
  # 0.52, and 1,601 of them name none at all.
  thin <- freq_of(at_one_address(paste(LETTERS[1:12], "ARTS COLLECTIVE"),
                                 units = c("STE 101", "STE 102", rep(NA, 10))))
  expect_equal(thin$units[[k]], 2L)
  expect_lt(thin$unit_coverage[[k]], 0.5)
  expect_equal(thin$class[[k]], "shared")      # not "building"
})

test_that("a handful of co-located records is a family cluster, not a crowd", {
  fam <- freq_of(at_one_address(c("PUEBLO ZOOLOGICAL SOCIETY",
                                  "PUEBLO ZOOLOGICAL SOCIETY FOUNDATION",
                                  "PUEBLO ZOOLOGICAL AUXILIARY")))
  expect_equal(fam$class[["127 FILMORE LN 78701"]], "cluster")
})

test_that("without names an address cannot be classified, and nothing breaks", {
  r <- np_normalize(np_reference(
    at_one_address(rep("PEO SISTERHOOD INTERNATIONAL CHAPTER", 12)),
    np_test_map_r))
  af <- np_addr_freq(r$street_key, r$zip5, r$street_unit_id)   # no name_keys
  k <- "127 FILMORE LN 78701"
  expect_true(is.na(af$top_name_share[[k]]))
  expect_equal(af$class[[k]], "shared")        # crowded, but which kind is unknown
})

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
