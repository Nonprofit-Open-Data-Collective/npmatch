cascade_fixture <- function() {
  # A: exact-name same-state match; B: spelling/word variant same state;
  # C: same name, DIFFERENT state (firm-vs-establishment).
  ref <- data.frame(
    ein = c("A", "B", "C"),
    name = c("SALMON CREEK HOUSING", "ANCHORAGE SYMPHONY ORCHESTRA", "RASMUSON FOUNDATION"),
    street = c("3406 GLACIER HWY", "430 W 7TH AVE", "301 W NORTHERN LIGHTS BLVD"),
    city = c("JUNEAU", "ANCHORAGE", "SEATTLE"), state = c("AK", "AK", "WA"),
    zip = c("99801", "99501", "98101"), dba_name = "", stringsAsFactors = FALSE)
  qry <- data.frame(
    unique_entity_id = c("q1", "q2", "q3"),
    name = c("SALMON CREEK HOUSING", "ANCHORAGE SYMPHONY", "RASMUSON FOUNDATION"),
    dba_name = "",
    street = c("3406 GLACIER HWY", "430 W 7TH AVE", "301 W NORTHERN LIGHTS BLVD"),
    city = c("JUNEAU", "ANCHORAGE", "ANCHORAGE"), state = c("AK", "AK", "AK"),
    zip = c("99801", "99501", "99503"), stringsAsFactors = FALSE)
  list(qry = qry, ref = ref)
}

test_that("np_cascade resolves each query and records its pass", {
  f <- cascade_fixture()
  res <- np_cascade(f$qry, f$ref, query_map = np_test_map_q,
                    reference_map = np_test_map_r, verbose = FALSE)
  expect_s3_class(res, "np_tiered")
  expect_true("pass" %in% names(res))
  expect_equal(nrow(res), 3)

  r1 <- res[res$.id == "q1", ]
  expect_equal(r1$overall_ein, "A")
  expect_equal(r1$pass, "exact-name")        # exact name + state

  r2 <- res[res$.id == "q2", ]
  expect_equal(r2$overall_ein, "B")
  expect_equal(r2$pass, "token-state")       # variant needs token blocking

  r3 <- res[res$.id == "q3", ]
  expect_equal(r3$overall_ein, "C")
  expect_equal(r3$pass, "token-crossstate")  # match is in another state
})

test_that("the first tier matches a query name against a BMF DBA", {
  ref <- data.frame(ein = "D", name = "HELPING HANDS INC",
                    dba_name = "SALMON CREEK HOUSING", street = "3406 GLACIER HWY",
                    city = "JUNEAU", state = "AK", zip = "99801", stringsAsFactors = FALSE)
  qry <- data.frame(unique_entity_id = "q", name = "SALMON CREEK HOUSING", dba_name = "",
                    street = "3406 GLACIER HWY", city = "JUNEAU", state = "AK",
                    zip = "99801", stringsAsFactors = FALSE)
  res <- np_cascade(qry, ref, query_map = np_test_map_q,
                    reference_map = np_test_map_r, verbose = FALSE)
  expect_equal(res$overall_ein, "D")
  expect_equal(res$pass, "exact-name-dba")   # matched query name to reference DBA
})

test_that("blank DBAs do not create spurious candidates", {
  # two AK orgs, neither with a DBA -> the dba==dba pass must find nothing
  q <- np_normalize(np_query(np_test_query(), np_test_map_q))
  r <- np_normalize(np_reference(np_test_reference(), np_test_map_r))
  blk <- np_block(q, r, by_x = c("state", "dba_key"), by_y = c("state", "dba_key"),
                  token = FALSE)
  expect_equal(nrow(blk), 0)
})

test_that("a per-stage report is attached", {
  f <- cascade_fixture()
  res <- np_cascade(f$qry, f$ref, query_map = np_test_map_q,
                    reference_map = np_test_map_r, verbose = FALSE)
  st <- attr(res, "stages")
  expect_true(is.data.frame(st))
  expect_true(all(c("pass", "criteria", "candidates", "yes", "maybe", "no",
                    "resolved", "pending", "median_yes_margin") %in% names(st)))
})

test_that("the cascade output routes like any tiered result", {
  f <- cascade_fixture()
  res <- np_cascade(f$qry, f$ref, query_map = np_test_map_q,
                    reference_map = np_test_map_r, verbose = FALSE)
  rt <- np_route(res)
  expect_s3_class(rt, "np_routing")
  expect_equal(sum(rt$summary), nrow(res))   # every query lands in exactly one bucket
})

test_that("a looser pass only runs on the unresolved residual", {
  # q1 resolves at exact-name; the token passes should not re-list it.
  f <- cascade_fixture()
  res <- np_cascade(f$qry, f$ref, query_map = np_test_map_q,
                    reference_map = np_test_map_r, verbose = FALSE)
  expect_false(res$pass[res$.id == "q1"] %in% c("token-state", "token-crossstate"))
})
