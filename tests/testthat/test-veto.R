make_pair <- function(name_x, name_y) {
  q <- np_normalize(np_query(data.frame(unique_entity_id = "1", name = name_x,
       state = "AK", stringsAsFactors = FALSE),
       c(.id = "unique_entity_id", name = "name", state = "state")))
  r <- np_normalize(np_reference(data.frame(ein = "1", name = name_y,
       state = "AK", stringsAsFactors = FALSE),
       c(.ein = "ein", name = "name", state = "state")))
  np_veto(np_score(np_compare(q, r, block = "state")))
}

test_that("generation is NOT vetoed by default (rule removed)", {
  expect_false(make_pair("KEN GRIFFEY JR", "KEN GRIFFEY SR")$veto)
  p <- make_pair("KEN GRIFFEY", "KEN GRIFFEY JR")
  expect_false(p$veto)
  expect_false(p$veto_soft)
})

test_that("disjoint embedded numbers are a hard veto", {
  p <- make_pair("IBEW LOCAL 32", "IBEW LOCAL 45")
  expect_true(p$veto)
  expect_match(p$veto_reason, "number_conflict")
})

test_that("matching embedded numbers do not veto", {
  p <- make_pair("IBEW LOCAL 45", "IBEW LOCAL 45")
  expect_false(p$veto)
})

test_that("differing ordinals are a hard veto", {
  p <- make_pair("FIRST BAPTIST CHURCH", "SECOND BAPTIST CHURCH")
  expect_true(p$veto)
  expect_match(p$veto_reason, "ordinal_conflict")
})

test_that("differing directionals are a hard veto", {
  p <- make_pair("SOUTHWEST MISSOURI COUNCIL OF GOVERNMENTS",
                 "SOUTHEAST MISSOURI COUNCIL OF GOVERNMENTS")
  expect_true(p$veto)
  expect_match(p$veto_reason, "direction_conflict")
})

test_that("a directional on one side only does not veto", {
  p <- make_pair("NORTHWEST HEALTH SERVICES", "NORTHWEST HEALTH SERVICES")
  expect_false(p$veto)   # same directional -> fine
  p2 <- make_pair("HEALTH SERVICES", "NORTHWEST HEALTH SERVICES")
  expect_false(p2$veto)  # asymmetric -> not a conflict
})

test_that("np_veto_audit collects vetoed pairs and auto-labels hard ones FALSE", {
  q <- np_normalize(np_query(data.frame(unique_entity_id = c("1", "2"),
        name = c("SOUTHWEST MISSOURI COUNCIL", "KEN GRIFFEY"),
        state = "AK", stringsAsFactors = FALSE),
        c(.id = "unique_entity_id", name = "name", state = "state")))
  r <- np_normalize(np_reference(data.frame(ein = c("A", "B"),
        name = c("SOUTHEAST MISSOURI COUNCIL", "KEN GRIFFEY JR"),
        state = "AK", stringsAsFactors = FALSE),
        c(.ein = "ein", name = "name", state = "state")))
  p <- np_veto(np_score(np_compare(q, r, block = "state")))
  aud <- np_veto_audit(p)
  expect_s3_class(aud, "np_veto_audit")
  expect_true(all(c(".id", ".ein", "veto_rule", "severity", "label") %in% names(aud)))
  hard <- aud[aud$severity == "hard", ]
  expect_true(all(hard$label == FALSE))            # hard veto -> non-match
  expect_true(any(grepl("direction_conflict", aud$veto_rule)))
})

test_that("legal-form rule is off by default but can be enabled", {
  cfg <- np_config(rules = rbind(np_default_rules(), np_rule_legal_form()))
  q <- np_normalize(np_query(data.frame(unique_entity_id = "1", name = "ACME INC",
       state = "AK", stringsAsFactors = FALSE),
       c(.id = "unique_entity_id", name = "name", state = "state")))
  r <- np_normalize(np_reference(data.frame(ein = "1", name = "ACME LLC",
       state = "AK", stringsAsFactors = FALSE),
       c(.ein = "ein", name = "name", state = "state")))
  p_off <- np_veto(np_score(np_compare(q, r, block = "state")))
  p_on  <- np_veto(np_score(np_compare(q, r, block = "state")), cfg)
  expect_false(p_off$veto)
  expect_true(p_on$veto)
})
