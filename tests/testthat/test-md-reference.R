# Precomputed address counts (addr_freq) and matchdb references.

md_fixture <- function() {
  r <- np_normalize(np_reference(np_test_reference(), np_test_map_r))
  # the same reference twelve times over: every address 12x as crowded, so a
  # pair's addr_shared shows which table a run used
  af_big <- np_addr_freq(rep(r$street_key, 12), rep(r$zip5, 12),
                         rep(r$street_unit_id, 12), rep(r$name_key, 12))
  list(r = r, af = np_addr_freq(r$street_key, r$zip5, r$street_unit_id, r$name_key),
       af_big = af_big)
}

# A stand-in for what matchdb returns: md_compile() gives class "md_reference",
# md_reference() a plain list of the same shape.
md_ref <- function(r, ..., signature = npnormalize::np_normalize_signature(),
                   classed = TRUE) {
  x <- c(list(reference = r, stamp = list(normalize_signature = signature)), list(...))
  if (classed) class(x) <- "md_reference"
  x
}

shared_at <- function(res, ein) {
  p <- attr(res, "pairs")
  unique(p$addr_shared[p$.ein == ein])
}

test_that("np_cascade uses a supplied addr_freq instead of counting", {
  f <- md_fixture()
  base <- np_cascade(np_test_query(), f$r, query_map = np_test_map_q, verbose = FALSE)
  same <- np_cascade(np_test_query(), f$r, query_map = np_test_map_q, verbose = FALSE,
                     addr_freq = f$af)
  expect_identical(attr(base, "pairs")$addr_shared, attr(same, "pairs")$addr_shared)
  expect_equal(shared_at(base, "10"), 2L)

  big <- np_cascade(np_test_query(), f$r, query_map = np_test_map_q, verbose = FALSE,
                    addr_freq = f$af_big)
  expect_equal(shared_at(big, "10"), 24L)
})

test_that("np_cascade refuses an addr_freq that np_addr_freq() did not make", {
  f <- md_fixture()
  expect_error(np_cascade(np_test_query(), f$r, query_map = np_test_map_q,
                          verbose = FALSE, addr_freq = list(addr = 1)),
               "np_addr_freq")
})

test_that("np_cascade takes a matchdb reference, classed or plain", {
  f <- md_fixture()
  base <- np_cascade(np_test_query(), f$r, query_map = np_test_map_q, verbose = FALSE)
  for (classed in c(TRUE, FALSE)) {
    x <- md_ref(f$r, name_freq = np_name_freq(f$r$name_key),
                token_idf = np_token_idf(f$r$name_key), classed = classed)
    res <- np_cascade(np_test_query(), x, query_map = np_test_map_q, verbose = FALSE)
    m <- match(base$.id, res$.id)
    expect_equal(res$overall_ein[m], base$overall_ein)
    expect_equal(as.character(res$tier)[m], as.character(base$tier))
  }
})

test_that("a matchdb reference's addr_freq is used, and an explicit one wins", {
  f <- md_fixture()
  x <- md_ref(f$r, addr_freq = f$af_big)
  res <- np_cascade(np_test_query(), x, query_map = np_test_map_q, verbose = FALSE)
  expect_equal(shared_at(res, "10"), 24L)

  res2 <- np_cascade(np_test_query(), x, query_map = np_test_map_q, verbose = FALSE,
                     addr_freq = f$af)
  expect_equal(shared_at(res2, "10"), 2L)
})

test_that("a matchdb reference from another normalizer is refused", {
  f <- md_fixture()
  x <- md_ref(f$r, signature = "v1-0000000000000000")
  expect_error(np_cascade(np_test_query(), x, query_map = np_test_map_q, verbose = FALSE),
               "v1-0000000000000000")
})

test_that("np_run_batches passes addr_freq through and caches it", {
  f <- md_fixture()
  out <- tempfile("npbatch-af-")
  on.exit(unlink(out, recursive = TRUE), add = TRUE)
  cache <- file.path(out, "ref.rds")

  np_run_batches(np_test_query(), md_ref(f$r, addr_freq = f$af_big), out_dir = out,
                 query_map = np_test_map_q, cache = cache, verbose = FALSE)
  cc <- readRDS(cache)
  expect_s3_class(cc$addr_freq, "np_addr_freq")
  expect_equal(unname(max(cc$addr_freq$addr)), 24L)   # the matchdb table, not a recount
  expect_false(is.null(cc$ref_index))
})

test_that("np_run_batches adds addr_freq to a cache written before it existed", {
  f <- md_fixture()
  out <- tempfile("npbatch-old-")
  dir.create(out)
  on.exit(unlink(out, recursive = TRUE), add = TRUE)
  cache <- file.path(out, "ref.rds")
  saveRDS(list(reference = f$r, name_freq = np_name_freq(f$r$name_key),
               token_idf = np_token_idf(f$r$name_key),
               ref_index = np_ref_index(f$r)), cache)

  np_run_batches(np_test_query(), np_test_reference(), out_dir = out,
                 query_map = np_test_map_q, cache = cache, verbose = FALSE)
  cc <- readRDS(cache)
  expect_s3_class(cc$addr_freq, "np_addr_freq")
  expect_equal(unname(max(cc$addr_freq$addr)), 2L)    # counted from the cached frame
})
