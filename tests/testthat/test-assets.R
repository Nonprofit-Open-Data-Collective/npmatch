test_that("data root resolves from option, env, then default", {
  old <- options(npmatch.data = NULL); on.exit(options(old))
  Sys.unsetenv("NPMATCH_DATA")
  expect_match(np_data_root(), "npmatch-data$")
  Sys.setenv(NPMATCH_DATA = "X:/np"); expect_equal(np_data_root(), "X:/np")
  Sys.unsetenv("NPMATCH_DATA")
  options(npmatch.data = "Y:/np"); expect_equal(np_data_root(), "Y:/np")
})

test_that("np_data_init creates the tier layout + manifest, and manifest_add records", {
  root <- file.path(tempdir(), paste0("npd-", as.integer(Sys.time())))
  on.exit(unlink(root, recursive = TRUE))
  np_data_init(root, quiet = TRUE)
  expect_true(all(dir.exists(file.path(root, c("raw", "normalized", "results")))))
  expect_true(file.exists(file.path(root, "MANIFEST.csv")))

  f <- file.path(root, "raw", "toy.csv")
  utils::write.csv(data.frame(a = 1:3, b = 4:6), f, row.names = FALSE)
  np_manifest_add("toy", "raw", source = "unit-test", path = f, root = root)
  m <- np_manifest(root)
  expect_equal(nrow(m), 1L)
  expect_equal(m$asset, "toy")
  expect_equal(m$row_count, 3L)          # auto-filled from the file
  expect_false(is.na(m$md5))

  # replace-by-name (no duplicate rows)
  np_manifest_add("toy", "raw", source = "v2", root = root)
  expect_equal(nrow(np_manifest(root)), 1L)
  expect_equal(np_manifest(root)$source, "v2")
})

test_that("np_data_path builds subdir paths", {
  options(npmatch.data = "Z:/np")
  expect_equal(np_data_path("normalized", "ref.rds"), "Z:/np/normalized/ref.rds")
  expect_equal(np_data_path(""), "Z:/np")
})
