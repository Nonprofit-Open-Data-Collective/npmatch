# Query batching + the batched stage-1 driver.

test_that("np_batch splits into ~size batches covering every row", {
  b <- np_batch(mtcars, size = 10, seed = 1)
  expect_equal(attr(b, "n_batches"), 4L)          # ceiling(32 / 10)
  expect_equal(length(b), 4L)
  expect_true(all(vapply(b, nrow, integer(1)) <= 10L))
  # union of batches == the input rows (as a set of car names)
  got <- sort(unlist(lapply(b, rownames)))
  # rownames are reset, so compare on a stable key instead
  got_mpg <- sort(unlist(lapply(b, function(d) d$mpg)))
  expect_equal(got_mpg, sort(mtcars$mpg))
  expect_equal(sum(vapply(b, nrow, integer(1))), nrow(mtcars))
})

test_that("np_batch honours n and makes near-equal batches", {
  b <- np_batch(mtcars, n = 3, seed = 1)
  expect_equal(length(b), 3L)
  sizes <- vapply(b, nrow, integer(1))
  expect_equal(sum(sizes), nrow(mtcars))
  expect_lte(max(sizes) - min(sizes), 1L)         # near-equal
})

test_that("np_batch is deterministic given a seed and restores RNG state", {
  set.seed(99); before <- runif(1)
  set.seed(99)
  b1 <- np_batch(mtcars, size = 10, seed = 1)
  after <- runif(1)                                # global RNG untouched by np_batch
  b2 <- np_batch(mtcars, size = 10, seed = 1)
  expect_identical(b1, b2)
  expect_equal(before, after)
})

test_that("np_batch handles an empty input", {
  b <- np_batch(mtcars[0, ], size = 10)
  expect_length(b, 0L)
  expect_equal(attr(b, "n_batches"), 0L)
})

test_that("np_cascade reuses a pre-normalized reference + cached tables identically", {
  q <- np_test_query(); rraw <- np_test_reference()

  res1 <- np_cascade(q, rraw, query_map = np_test_map_q,
                     reference_map = np_test_map_r, verbose = FALSE)

  # pre-normalize once and pass cached tables (the batched-driver path)
  rnorm <- np_normalize(np_reference(rraw, np_test_map_r))
  expect_false(is.null(rnorm$name_key))
  nf <- np_name_freq(rnorm$name_key)
  ti <- np_token_idf(rnorm$name_key)
  res2 <- np_cascade(q, rnorm, query_map = np_test_map_q, verbose = FALSE,
                     name_freq = nf, token_idf = ti)

  # same picks and tiers per query
  m <- match(res1$.id, res2$.id)
  expect_equal(res1$overall_ein, res2$overall_ein[m])
  expect_equal(as.character(res1$tier), as.character(res2$tier)[m])
})

test_that("np_run_batches writes per-batch outputs and a run summary", {
  out <- file.path(tempdir(), paste0("npbatch-", as.integer(Sys.time())))
  on.exit(unlink(out, recursive = TRUE), add = TRUE)

  summ <- np_run_batches(
    np_test_query(), np_test_reference(),
    size = 2L, out_dir = out, seed = 1,
    query_map = np_test_map_q, reference_map = np_test_map_r,
    verbose = FALSE)

  expect_s3_class(summ, "data.frame")
  expect_gt(nrow(summ), 0L)
  expect_true(all(c("batch", "yes", "maybe", "no", "coverage", "review_files") %in% names(summ)))
  expect_true(file.exists(file.path(out, "run-summary.csv")))
  expect_true(file.exists(file.path(out, "batch-index.csv")))
  # every reported chunk produced a crosswalk + canonical review file
  expect_true(all(file.exists(summ$crosswalk)))
  expect_true(all(file.exists(summ$review)))
  # coverage never exceeds the chunk size
  expect_true(all(summ$coverage <= summ$rows))
})

test_that("np_run_batches defaults to match-big (one compute chunk)", {
  out <- file.path(tempdir(), paste0("npbig-", as.integer(Sys.time())))
  on.exit(unlink(out, recursive = TRUE), add = TRUE)
  summ <- np_run_batches(
    np_test_query(), np_test_reference(), out_dir = out, seed = 1,
    query_map = np_test_map_q, reference_map = np_test_map_r, verbose = FALSE)
  expect_equal(nrow(summ), 1L)                    # no compute_size/size -> single chunk
  expect_equal(summ$rows, nrow(np_test_query()))
})

test_that(".np_write_review_shards splits by query id into review_size groups", {
  out <- file.path(tempdir(), paste0("npshard-", as.integer(Sys.time())))
  dir.create(out, showWarnings = FALSE)
  on.exit(unlink(out, recursive = TRUE), add = TRUE)
  review <- data.frame(uei = rep(paste0("u", 1:5), each = 2),
                       ein = rep(letters[1:5], each = 2), stringsAsFactors = FALSE)
  files <- .np_write_review_shards(review, file.path(out, "review-01"), review_size = 2L)
  expect_length(files, 3L)                        # ceil(5 / 2) shards
  expect_true(all(file.exists(files)))
  back <- do.call(rbind, lapply(files, function(f) data.table::fread(f)))
  expect_equal(nrow(back), nrow(review))          # every row preserved
  # each shard holds whole queries (no uei split across files)
  per <- lapply(files, function(f) unique(data.table::fread(f)$uei))
  expect_equal(length(unlist(per)), length(unique(unlist(per))))
  # empty review -> no shards
  expect_length(.np_write_review_shards(review[0, ], file.path(out, "review-02"), 2L), 0L)
})

test_that("np_run_batches can run a single batch via `only`", {
  out <- file.path(tempdir(), paste0("npbatch1-", as.integer(Sys.time())))
  on.exit(unlink(out, recursive = TRUE), add = TRUE)

  summ <- np_run_batches(
    np_test_query(), np_test_reference(),
    size = 2L, out_dir = out, only = 1L, seed = 1,
    query_map = np_test_map_q, reference_map = np_test_map_r,
    verbose = FALSE)

  expect_equal(nrow(summ), 1L)
  expect_equal(summ$batch, 1L)
})
