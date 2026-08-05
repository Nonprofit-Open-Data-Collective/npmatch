# Cross-state exact-name matches: a rare/distinctive name should be trusted
# without address; a common name should not.
idf_score <- function(qname, rname, name_freq) {
  mq <- c(.id = "unique_entity_id", name = "name", street = "street",
          city = "city", state = "state", zip5 = "zip")
  mr <- c(.ein = "ein", name = "name", street = "street",
          city = "city", state = "state", zip5 = "zip")
  # same state (so a pair is formed) but otherwise unrelated address -> geo is
  # weak, exactly the cross-state firm-vs-establishment situation.
  q <- np_normalize(np_query(data.frame(unique_entity_id = "q", name = qname,
        street = "1 A ST", city = "AUSTIN", state = "TX", zip = "78701",
        stringsAsFactors = FALSE), mq))
  r <- np_normalize(np_reference(data.frame(ein = "R", name = rname,
        street = "9 B AVE", city = "DALLAS", state = "TX", zip = "75201",
        stringsAsFactors = FALSE), mr))
  np_score(np_compare(q, r, block = "state", name_freq = name_freq), method = "hier")$score
}

test_that("a distinctive exact name is promoted across states; a common one is not", {
  # freq table: XIA GIBBS SOCIETY is rare (1), FOURTH BAPTIST CHURCH is common (40)
  nf <- c("XIA GIBBS SOCIETY" = 1L, "FOURTH BAPTIST CHURCH" = 40L)
  expect_gte(idf_score("XIA GIBBS SOCIETY", "XIA GIBBS SOCIETY", nf), 0.85)
  expect_lt(idf_score("FOURTH BAPTIST CHURCH", "FOURTH BAPTIST CHURCH", nf), 0.75)
})

test_that("np_name_freq counts shared name_keys", {
  nf <- np_name_freq(c("ALPHA", "ALPHA", "BETA GAMMA"))
  expect_equal(nf[["ALPHA"]], 2L)
  expect_equal(nf[["BETA GAMMA"]], 1L)
})

test_that("name_match_type flags how the name matched", {
  q <- np_normalize(np_query(data.frame(unique_entity_id = c("1", "2"),
        name = c("SALMON CREEK HOUSING", "NOME COMMUNITY CENTER"),
        dba_name = c("", ""), state = "AK", stringsAsFactors = FALSE),
        c(.id = "unique_entity_id", name = "name", dba = "dba_name", state = "state")))
  r <- np_normalize(np_reference(data.frame(ein = c("A", "B"),
        name = c("SALMON CREEK HOUSING", "HELPING HANDS"),
        dba_name = c("", "NOME COMMUNITY CENTER"), state = "AK",
        stringsAsFactors = FALSE),
        c(.ein = "ein", name = "name", dba = "dba_name", state = "state")))
  pr <- np_compare(q, r, block = "state")
  expect_true("name_match_type" %in% names(pr))
  # exact name-name match flagged "exact"; query-name==reference-dba flagged "dba"
  expect_equal(pr$name_match_type[pr$.id == "1" & pr$.ein == "A"], "exact")
  expect_equal(pr$name_match_type[pr$.id == "2" & pr$.ein == "B"], "dba")
})
