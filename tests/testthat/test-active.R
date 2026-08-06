# Active-vs-unified BMF option: an `active` flag on the reference is carried
# through to the match result so it can be filtered (current 990s vs identity).

test_that("np_map_bmf(active_col=) maps and np_reference coerces to logical", {
  r <- data.frame(ein = c("1", "2", "3"),
    org_name_join = c("ALPHA FUND", "BETA TRUST", "GAMMA CLUB"),
    dba_name = "", org_addr_street = "", org_addr_city = "",
    org_addr_state = "AK", org_addr_zip5 = "", org_addr_zip4 = "",
    act = c("1", "0", "TRUE"), stringsAsFactors = FALSE)
  ref <- np_reference(r, np_map_bmf(active_col = "act"))
  expect_type(ref$active, "logical")
  expect_equal(ref$active, c(TRUE, FALSE, TRUE))
})

test_that("np_flag_active flags by EIN membership", {
  r <- np_reference(data.frame(ein = c("1", "2"),
    org_name_join = c("A", "B"), dba_name = "", org_addr_street = "",
    org_addr_city = "", org_addr_state = "AK", org_addr_zip5 = "",
    org_addr_zip4 = "", stringsAsFactors = FALSE))
  ref <- np_flag_active(r, active_eins = "1")
  expect_equal(ref$active, c(TRUE, FALSE))
})

test_that("the active flag reaches the cascade result", {
  q <- data.frame(unique_entity_id = c("a", "b"),
    name = c("ALPHA FUND", "BETA TRUST"), state = "AK", stringsAsFactors = FALSE)
  r <- data.frame(ein = c("1", "2"),
    org_name_join = c("ALPHA FUND", "BETA TRUST"), dba_name = "",
    org_addr_street = "", org_addr_city = "", org_addr_state = "AK",
    org_addr_zip5 = "", org_addr_zip4 = "", act = c("1", "0"),
    stringsAsFactors = FALSE)
  ref <- np_reference(r, np_map_bmf(active_col = "act"))
  res <- np_cascade(q, ref, verbose = FALSE,
    query_map = c(.id = "unique_entity_id", name = "name", state = "state"))
  expect_true("bmf_active" %in% names(res))
  expect_equal(res$bmf_active[res$.id == "a"], TRUE)
  expect_equal(res$bmf_active[res$.id == "b"], FALSE)
})
