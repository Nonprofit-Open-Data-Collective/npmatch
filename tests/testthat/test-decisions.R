test_that("np_merge_decisions joins query-level decisions onto candidate rows", {
  review <- data.frame(
    uei = c("A1", "A1", "B2", "B2", "C3"),
    ein = c("11-1111111", "22-2222222", "33-3333333", "44-4444444", "55-5555555"),
    stringsAsFactors = FALSE
  )
  dec <- data.frame(
    uei = c("A1", "B2"), best_ein = c("22-2222222", ""),
    llm_decision = c("YES", "NO"), llm_confidence = c("high", "medium"),
    llm_reason = c("same org", "no candidate"), stringsAsFactors = FALSE
  )
  m <- np_merge_decisions(review, dec, quiet = TRUE)

  expect_equal(nrow(m), 5)                      # row count and order preserved
  expect_equal(m$uei, review$uei)
  expect_equal(m$llm_decision, c("YES", "YES", "NO", "NO", NA))
  # the decision replicates across a query's candidates; only the chosen EIN is TRUE
  expect_equal(m$llm_selected, c(FALSE, TRUE, FALSE, FALSE, NA))
  expect_equal(m$llm_best_ein, c("22-2222222", "22-2222222", "", "", NA))
})

test_that("unadjudicated queries are NA, not FALSE", {
  review <- data.frame(uei = c("A1", "Z9"), ein = c("11-1111111", "99-9999999"),
                       stringsAsFactors = FALSE)
  dec <- data.frame(uei = "A1", best_ein = "11-1111111", llm_decision = "YES",
                    llm_confidence = "high", llm_reason = "r", stringsAsFactors = FALSE)
  m <- np_merge_decisions(review, dec, quiet = TRUE)
  expect_true(is.na(m$llm_selected[2]))
  expect_false(isTRUE(m$llm_selected[2]))       # NA must not read as rejected
  expect_equal(sum(m$llm_selected %in% TRUE), 1)
})

test_that("a NO decision selects nothing even when best_ein is blank", {
  review <- data.frame(uei = c("B2", "B2"), ein = c("33-3333333", ""),
                       stringsAsFactors = FALSE)
  dec <- data.frame(uei = "B2", best_ein = "", llm_decision = "NO",
                    llm_confidence = "low", llm_reason = "none", stringsAsFactors = FALSE)
  m <- np_merge_decisions(review, dec, quiet = TRUE)
  expect_equal(m$llm_selected, c(FALSE, FALSE))  # blank ein must not match blank best_ein
})

test_that("duplicate ids collapse preferring YES then confidence, and flag conflicts", {
  review <- data.frame(uei = c("D4", "D4"), ein = c("11-1111111", "22-2222222"),
                       stringsAsFactors = FALSE)
  dec <- data.frame(
    uei = c("D4", "D4", "E5", "E5"),
    best_ein = c("", "22-2222222", "77-7777777", "77-7777777"),
    llm_decision = c("NO", "YES", "YES", "YES"),
    llm_confidence = c("high", "medium", "low", "high"),
    llm_reason = c("a", "b", "c", "d"), stringsAsFactors = FALSE
  )
  m <- np_merge_decisions(review, dec, quiet = TRUE)
  expect_equal(unique(m$llm_decision), "YES")           # YES beats a high-confidence NO
  expect_equal(m$llm_selected, c(FALSE, TRUE))

  st <- attr(m, "decision_merge")
  expect_equal(st$n_decisions, 4)
  expect_equal(st$n_ids, 2)
  expect_equal(st$n_collapsed, 2)
  expect_equal(st$conflicts, "D4")                      # E5 agreed; D4 did not
  expect_equal(st$n_unmatched_ids, 1)                   # E5 is not in the frame
})

test_that("agreeing duplicates keep the higher confidence and are not conflicts", {
  review <- data.frame(uei = "F6", ein = "88-8888888", stringsAsFactors = FALSE)
  dec <- data.frame(uei = c("F6", "F6"), best_ein = c("88-8888888", "88-8888888"),
                    llm_decision = c("YES", "YES"), llm_confidence = c("low", "high"),
                    llm_reason = c("weak", "strong"), stringsAsFactors = FALSE)
  m <- np_merge_decisions(review, dec, quiet = TRUE)
  expect_equal(m$llm_confidence, "high")
  expect_equal(attr(m, "decision_merge")$conflicts, character(0))
})

test_that("prefix lets a second pass merge alongside the first", {
  review <- data.frame(uei = "A1", ein = "11-1111111", stringsAsFactors = FALSE)
  dec <- data.frame(uei = "A1", best_ein = "11-1111111", llm_decision = "YES",
                    llm_confidence = "high", llm_reason = "r", stringsAsFactors = FALSE)
  m <- np_merge_decisions(review, dec, quiet = TRUE)
  m <- np_merge_decisions(m, dec, prefix = "human_", quiet = TRUE)
  expect_true(all(c("llm_selected", "human_selected") %in% names(m)))
  expect_true(m$human_selected)
})

test_that("np_merge_decisions reads a directory of decision shards", {
  d <- file.path(tempdir(), paste0("npdec-", as.integer(Sys.time())))
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  write.csv(data.frame(uei = "A1", best_ein = "11-1111111", llm_decision = "YES",
                       llm_confidence = "high", llm_reason = "r"),
            file.path(d, "decision-01-part01.csv"), row.names = FALSE)
  write.csv(data.frame(uei = "B2", best_ein = "", llm_decision = "NO",
                       llm_confidence = "low", llm_reason = "r"),
            file.path(d, "decision-02-part01.csv"), row.names = FALSE)

  review <- data.frame(uei = c("A1", "B2"), ein = c("11-1111111", "33-3333333"),
                       stringsAsFactors = FALSE)
  m <- np_merge_decisions(review, d, quiet = TRUE)
  expect_equal(m$llm_decision, c("YES", "NO"))
  expect_equal(m$llm_selected, c(TRUE, FALSE))
  expect_equal(attr(m, "decision_merge")$n_decisions, 2)

  empty <- file.path(d, "empty"); dir.create(empty, showWarnings = FALSE)
  expect_error(np_merge_decisions(review, empty), "no decision-.*csv")
})

test_that("np_merge_decisions validates its inputs", {
  review <- data.frame(uei = "A1", ein = "11-1111111", stringsAsFactors = FALSE)
  ok <- data.frame(uei = "A1", best_ein = "11-1111111", llm_decision = "YES",
                   llm_confidence = "high", llm_reason = "r", stringsAsFactors = FALSE)

  expect_error(np_merge_decisions(review, ok[, 1:3]), "missing column")
  expect_error(np_merge_decisions(review, ok, id = "nope"), "no column 'nope'")
  expect_error(np_merge_decisions(review, transform(ok, llm_decision = "MAYBE")),
               "must be YES or NO")
  expect_error(np_merge_decisions(review, ok, prefix = ""), "non-empty")
  expect_error(np_merge_decisions(review, "no-such-file.csv"), "file not found")
})

test_that("np_merge_decisions accepts an np_routing and a CSV path", {
  review <- data.frame(uei = "A1", ein = "11-1111111", stringsAsFactors = FALSE)
  dec <- data.frame(uei = "A1", best_ein = "11-1111111", llm_decision = "yes",
                    llm_confidence = "HIGH", llm_reason = "r", stringsAsFactors = FALSE)

  routing <- structure(list(review = review), class = "np_routing")
  m <- np_merge_decisions(routing, dec, quiet = TRUE)
  expect_true(m$llm_selected)
  expect_equal(m$llm_decision, "YES")            # case is normalized on both fields
  expect_equal(m$llm_confidence, "high")

  f <- tempfile(fileext = ".csv"); on.exit(unlink(f), add = TRUE)
  write.csv(dec, f, row.names = FALSE)
  expect_true(np_merge_decisions(review, f, quiet = TRUE)$llm_selected)
})
