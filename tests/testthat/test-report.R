test_that("np_run_report renders sections from a cascade result", {
  res <- np_cascade(np_test_query(), np_test_reference(),
                    query_map = np_test_map_q, reference_map = np_test_map_r,
                    verbose = FALSE)
  rep <- np_run_report(res, reference = "test reference",
                       timings = c(cascade = 30), outputs = "results/x.csv")
  expect_type(rep, "character")
  expect_length(rep, 1L)
  # key sections present
  for (h in c("# npmatch run report", "## Matching process", "## Outcome",
              "## Next stage", "| Tier | Count | Share |"))
    expect_true(grepl(h, rep, fixed = TRUE), info = h)
  # tier counts in the report match the result
  tt <- table(factor(as.character(as.data.frame(res)$tier), c("YES","MAYBE","NO")))
  expect_true(grepl(sprintf("| YES | %s |", format(tt[["YES"]], big.mark=",")), rep, fixed = TRUE))
  # computed parts attached
  expect_true(all(c("tiers", "stages") %in% names(attr(rep, "parts"))))
})

test_that("np_run_report works without optional args and writes to file", {
  res <- np_cascade(np_test_query(), np_test_reference(),
                    query_map = np_test_map_q, reference_map = np_test_map_r,
                    verbose = FALSE)
  f <- tempfile(fileext = ".md"); on.exit(unlink(f))
  out <- np_run_report(res, file = f)
  expect_true(file.exists(f))
  expect_gt(length(readLines(f)), 10L)
})
