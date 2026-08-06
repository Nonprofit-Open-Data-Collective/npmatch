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
  need <- c("uei", "ein", "match_name_uss", "match_name_bmf", "street_bmf",
            "name_similarity", "addr_similarity", "total_score", "candidate_type",
            "match_decision", "match_layer", "decision_reason", "notes")
  expect_true(all(need %in% names(rt$review)))
  # match_decision is the algorithmic tier, not blank
  if (nrow(rt$review))
    expect_true(all(rt$review$match_decision %in% c("YES", "MAYBE", "NO")))
  if (nrow(rt$review)) expect_true(all(nzchar(rt$review$decision_reason)))
  # (1) match strength + outcome leads the columns
  expect_equal(names(rt$review)[1:7],
               c("uei", "ein", "name_similarity", "addr_similarity",
                 "candidate_type", "total_score", "is_top_candidate"))
})

test_that("is_top_candidate flags one pick per YES/MAYBE group, none for NO", {
  res <- route_fixture()
  rt <- np_route(res)
  skip_if(nrow(rt$review) == 0)
  expect_true(all(rt$review$is_top_candidate %in% c(0L, 1L)))
  by_q <- split(rt$review, rt$review$uei)
  for (g in by_q) {
    tier <- unique(g$match_decision)
    expect_lte(sum(g$is_top_candidate), 1)               # at most one top per group
    if (all(tier == "NO")) expect_equal(sum(g$is_top_candidate), 0)
  }
})

test_that("name match summary + cleaning progression are present and labelled", {
  res <- route_fixture()
  rt <- np_route(res)
  skip_if(nrow(rt$review) == 0)
  expect_true(all(c("match_version_uss", "match_version_bmf", "match_type",
                    "name_uss_raw_main", "name_uss_raw_dba", "name_uss_normalized",
                    "name_uss_org_type", "name_uss_tokenized") %in% names(rt$review)))
  vers <- na.omit(c(rt$review$match_version_uss, rt$review$match_version_bmf))
  if (length(vers))
    expect_true(all(vers %in% c("MAIN", "DBA", "DIVISION", "TOKEN_OVERLAP", "none")))
})

test_that("review column suffixes follow the source/reference arguments", {
  res <- route_fixture()
  rt <- np_route(res, source = "sam", reference = "irs", id_label = "duns")
  expect_true(all(c("duns", "match_name_sam", "match_name_irs",
                    "name_sam_normalized", "street_irs") %in% names(rt$review)))
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
