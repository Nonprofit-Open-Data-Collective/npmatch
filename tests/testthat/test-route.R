route_fixture <- function() {
  # q1 clean, well-separated YES; q2 a near-tie between two near-duplicate
  # entities -> MAYBE (margin gate); q3 a far miss -> NO.
  ref <- data.frame(
    ein = c("C", "A", "B", "D"),
    name = c("SALMON CREEK HOUSING INC", "HELPING HANDS FOUNDATION",
             "HELPING HANDS FOUNDATION INC", "TOTALLY DIFFERENT ORG"),
    street = c("3406 GLACIER HWY", "100 MAIN ST", "100 MAIN ST", "5 NOWHERE LN"),
    city = c("JUNEAU", "JUNEAU", "JUNEAU", "SITKA"), state = "AK",
    zip = c("99801-9501", "99801", "99801", "99835"),
    dba_name = "", stringsAsFactors = FALSE)
  qry <- data.frame(
    unique_entity_id = c("q1", "q2", "q3"),
    name = c("SALMON CREEK HOUSING", "HELPING HANDS FOUNDATION", "Z Q Z NONEXISTENT ORG"),
    dba_name = "",
    street = c("3406 GLACIER HWY STE A", "100 MAIN ST", "77 GHOST AVE"),
    city = c("JUNEAU", "JUNEAU", "KETCHIKAN"), state = "AK",
    zip = c("99801", "99801", "99901"), stringsAsFactors = FALSE)
  np_match(qry, ref, query_map = np_test_map_q, reference_map = np_test_map_r)
}

test_that("np_route partitions into accepted / review / unmatched", {
  res <- route_fixture()
  rt <- np_route(res)
  expect_s3_class(rt, "np_routing")
  expect_true(all(c("accepted", "review", "unmatched") %in% names(rt)))
  # counts add up to the number of queries
  total <- rt$summary[["accepted"]] + rt$summary[["review"]] + rt$summary[["unmatched"]]
  expect_equal(total, nrow(res))
  expect_true("q1" %in% rt$accepted$uei)          # clean match auto-accepted
})

test_that("the review queue is self-contained and reviewer-ready", {
  res <- route_fixture()
  rt <- np_route(res)
  need <- c("uei", "ein", "name_uss", "name_bmf", "street_bmf", "name_sim", "addr_sim",
            "score", "candidate_type", "decision_layer", "decision_reason",
            "decision", "notes")
  expect_true(all(need %in% names(rt$review)))
  expect_true(all(is.na(rt$review$decision)))     # blank for the reviewer
  if (nrow(rt$review)) expect_true(all(nzchar(rt$review$decision_reason)))
  # curated block leads: keys, name-provenance cluster, then scores
  expect_equal(names(rt$review)[1:11],
               c("uei", "ein",
                 "name_uss_raw", "name_uss", "name_uss_version",
                 "name_bmf_raw", "name_bmf", "name_bmf_version",
                 "name_sim", "addr_sim", "score"))
})

test_that("name-version provenance labels which version matched", {
  res <- route_fixture()
  rt <- np_route(res)
  skip_if(nrow(rt$review) == 0)
  expect_true(all(c("name_uss_version", "name_bmf_version",
                    "name_uss_raw", "name_bmf_raw") %in% names(rt$review)))
  vers <- na.omit(c(rt$review$name_uss_version, rt$review$name_bmf_version))
  if (length(vers)) expect_true(all(vers %in% c("MAIN", "DBA", "ABBR")))
})

test_that("review column suffixes follow the source/reference arguments", {
  res <- route_fixture()
  rt <- np_route(res, source = "sam", reference = "irs", id_label = "duns")
  expect_true(all(c("duns", "name_sam", "name_irs", "street_irs") %in% names(rt$review)))
  expect_false(any(grepl("_x$|_y$|^\\.id$", names(rt$review))))
})

test_that("extra passthrough columns are joined and suffixed", {
  res <- route_fixture()
  # a source lookup keyed by uei carrying an award column
  src <- data.frame(uei = c("q1", "q2", "q3"),
                    award = c(100, 200, 300), stringsAsFactors = FALSE)
  rt <- np_route(res, source_data = src, extra_source = "award")
  skip_if(nrow(rt$review) == 0)
  expect_true("award_uss" %in% names(rt$review))
})

test_that("near-tie cases carry an explanatory decision_reason", {
  res <- route_fixture()
  rt <- np_route(res)
  q2 <- rt$review[rt$review$uei == "q2", ]
  skip_if(nrow(q2) == 0)
  expect_match(paste(unique(q2$decision_reason), collapse = " "), "near-tie|review band|differ")
})

test_that("np_as_prompt renders a self-contained LLM prompt without calls", {
  res <- route_fixture()
  rt <- np_route(res)
  ids <- unique(rt$review$.id)
  skip_if(length(ids) == 0)
  p <- np_as_prompt(rt, ids[1])
  expect_type(p, "character")
  expect_match(p, "SOURCE RECORD")
  expect_match(p, "CANDIDATE MATCHES")
  expect_match(p, "JSON")
  prompts <- np_as_prompts(rt)
  expect_named(prompts)
  expect_length(prompts, length(ids))
})
