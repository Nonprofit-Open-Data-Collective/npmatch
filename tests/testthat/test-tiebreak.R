# Two reference orgs both score high (>=0.95, within tie_band): NAMEHIT is the
# exact name with a weaker (ZIP5-only) address; ADDRHIT is a near-name with an
# exact (ZIP+4 + street) address, so the combined score narrowly favors ADDRHIT.
tie_frames <- function() {
  ref <- data.frame(
    ein = c("NAMEHIT", "ADDRHIT"),
    name = c("ACME REGIONAL HOUSING", "ACME REGIONAL HOUSINGS"),
    street = c("999 OAK AVE", "100 MAIN ST"),
    city = "JUNEAU", state = "AK",
    zip = c("99801", "99801-1234"), dba_name = "", stringsAsFactors = FALSE)
  qry <- data.frame(
    unique_entity_id = "q", name = "ACME REGIONAL HOUSING", dba_name = "",
    street = "100 MAIN ST", city = "JUNEAU", state = "AK", zip = "99801-1234",
    stringsAsFactors = FALSE)
  q <- np_normalize(np_query(qry, np_test_map_q))
  r <- np_normalize(np_reference(ref, np_test_map_r))
  np_veto(np_score(np_compare(q, r, block = "state"), method = "hier"))
}

test_that("near-tie candidates are flagged with n_close and tie", {
  pr <- tie_frames()
  sel <- np_select(pr, np_config())
  expect_true(sel$tie)
  expect_gte(sel$n_close, 2)
})

test_that("the high-tie tiebreak prefers the name-exact candidate", {
  pr <- tie_frames()
  by_score <- np_select(pr, np_config(tiebreak = "none"))
  by_name  <- np_select(pr, np_config(tiebreak = "name"))
  # both candidates are high-scoring; score alone favors the address match,
  # name-priority flips the overall pick to the exact-name entity
  expect_equal(by_score$overall_ein, "ADDRHIT")
  expect_equal(by_name$overall_ein,  "NAMEHIT")
})

test_that("full-name tiebreak prefers the base org over its FOUNDATION sibling", {
  # org and its foundation share an address and an identical (suffix-stripped)
  # name_key, so name_key can't distinguish them; full-name exactness can.
  ref <- data.frame(ein = c("ORG", "FDN"),
    name = c("GOW SCHOOL", "GOW SCHOOL FOUNDATION"),
    street = "2491 EMERY RD", city = "SOUTH WALES", state = "NY",
    zip = "14139", dba_name = "", stringsAsFactors = FALSE)
  qry <- data.frame(unique_entity_id = "q", name = "GOW SCHOOL", dba_name = "",
    street = "2491 EMERY RD", city = "SOUTH WALES", state = "NY", zip = "14139",
    stringsAsFactors = FALSE)
  q <- np_normalize(np_query(qry, np_test_map_q))
  r <- np_normalize(np_reference(ref, np_test_map_r))
  pr <- np_veto(np_score(np_compare(q, r, block = "state"), method = "hier"))
  sel <- np_select(pr, np_config())
  expect_true(sel$tie)
  expect_equal(sel$overall_ein, "ORG")   # "GOW SCHOOL" beats "GOW SCHOOL FOUNDATION"
})

test_that("tiebreak leaves non-tied cases unchanged", {
  # a single dominant candidate: no tie, pick is the same regardless of rule
  ref <- data.frame(ein = c("A", "B"),
    name = c("SALMON CREEK HOUSING", "COMPLETELY DIFFERENT ORG"),
    street = c("3406 GLACIER HWY", "1 NOWHERE LN"), city = c("JUNEAU", "NOME"),
    state = "AK", zip = c("99801", "99762"), dba_name = "", stringsAsFactors = FALSE)
  qry <- data.frame(unique_entity_id = "q", name = "SALMON CREEK HOUSING",
    dba_name = "", street = "3406 GLACIER HWY", city = "JUNEAU", state = "AK",
    zip = "99801", stringsAsFactors = FALSE)
  q <- np_normalize(np_query(qry, np_test_map_q))
  r <- np_normalize(np_reference(ref, np_test_map_r))
  pr <- np_veto(np_score(np_compare(q, r, block = "state"), method = "hier"))
  expect_false(np_select(pr, np_config())$tie)
  expect_equal(np_select(pr, np_config(tiebreak = "name"))$overall_ein, "A")
  expect_equal(np_select(pr, np_config(tiebreak = "none"))$overall_ein, "A")
})
