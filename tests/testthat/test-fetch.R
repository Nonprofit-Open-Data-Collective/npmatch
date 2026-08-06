test_that("np_sam_layout has the 142 fields and key columns", {
  L <- np_sam_layout()
  expect_length(L, 142L)
  expect_true(all(c("UNIQUE ENTITY ID", "LEGAL BUSINESS NAME", "BUS TYPE STRING",
                    "PHYSICAL ADDRESS PROVINCE OR STATE") %in% L))
})

test_that("np_source_urls lists archive + source entries", {
  u <- np_source_urls()
  expect_true(all(c("bmf_unified", "sam_extract", "bmf_fresh", "sam_fresh") %in% u$key))
  expect_true(all(grepl("^https?://", u$url)))
})

test_that("np_flag_nonprofits keeps only nonprofit business-type codes", {
  sam <- data.frame(
    `UNIQUE ENTITY ID` = c("u1", "u2", "u3", "u4", "u5"),
    `BUS TYPE STRING`  = c("2X~LJ", "23~A8~H2", "BZ", "27~XS", "2U~A2"),
    check.names = FALSE, stringsAsFactors = FALSE)
  kept <- np_flag_nonprofits(sam)
  expect_equal(sort(kept[["UNIQUE ENTITY ID"]]), c("u2", "u3", "u5"))   # A8, BZ, 2U
  flagged <- np_flag_nonprofits(sam, keep = FALSE)
  expect_equal(flagged$is_nonprofit, c(FALSE, TRUE, TRUE, FALSE, TRUE))
})

test_that("np_diff_unmatched retains only records not already matched", {
  fresh <- data.frame(uei = c("a", "b", "c", "d"), name = letters[1:4],
                      stringsAsFactors = FALSE)
  xwalk <- data.frame(uei = c("a", "b", "c"), ein = c("1", "2", NA),
                      tier = c("YES", "MAYBE", "NO"), stringsAsFactors = FALSE)

  # default: only YES counts as matched -> retain b (MAYBE), c (NO), d (new)
  r1 <- np_diff_unmatched(fresh, xwalk, quiet = TRUE)
  expect_equal(sort(r1$uei), c("b", "c", "d"))
  expect_equal(attr(r1, "diff")[["already_matched"]], 1L)
  expect_equal(attr(r1, "diff")[["new_ids"]], 1L)          # only d is brand new

  # include MAYBE as matched -> retain c, d
  r2 <- np_diff_unmatched(fresh, xwalk, matched_values = c("YES", "MAYBE"), quiet = TRUE)
  expect_equal(sort(r2$uei), c("c", "d"))

  # no status column -> any appearance counts as matched -> retain only d
  r3 <- np_diff_unmatched(fresh, xwalk[, c("uei", "ein")], quiet = TRUE)
  expect_equal(r3$uei, "d")
})

test_that("np_diff_unmatched auto-detects differing key column names", {
  fresh <- data.frame(`UNIQUE ENTITY ID` = c("a", "b"), check.names = FALSE)
  xwalk <- data.frame(uei = "a", tier = "YES", stringsAsFactors = FALSE)
  r <- np_diff_unmatched(fresh, xwalk, quiet = TRUE)
  expect_equal(r[["UNIQUE ENTITY ID"]], "b")
})
