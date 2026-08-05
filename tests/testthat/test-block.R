blk_pairs <- function(blk, q, r) {
  data.frame(id = q$.id[blk$.x], ein = r$.ein[blk$.y], stringsAsFactors = FALSE)
}
truth <- c(q1 = "05", q2 = "10", q3 = "11", q4 = "14")

setup_frames <- function() {
  q <- np_normalize(np_query(np_test_query(), np_test_map_q))
  r <- np_normalize(np_reference(np_test_reference(), np_test_map_r))
  list(q = q, r = r)
}

test_that("exact blocking on state pairs every same-state record", {
  f <- setup_frames()
  blk <- np_block(f$q, f$r, by = "state", token = FALSE)
  expect_equal(nrow(blk), nrow(f$q) * nrow(f$r))   # all AK x AK
})

test_that("name-token blocking keeps the true matches but far fewer pairs", {
  f <- setup_frames()
  blk <- np_block(f$q, f$r, by = "state", token = TRUE)
  expect_lt(nrow(blk), nrow(f$q) * nrow(f$r))       # a reduction vs the full cross
  got <- blk_pairs(blk, f$q, f$r)
  for (id in names(truth)) {
    expect_true(any(got$id == id & got$ein == truth[[id]]),
                info = paste("missing true pair for", id))
  }
})

test_that("records sharing only a stopword are not blocked together", {
  q <- np_normalize(np_query(data.frame(unique_entity_id = "a",
        name = "THE FOUNDATION", state = "AK", stringsAsFactors = FALSE),
        c(.id = "unique_entity_id", name = "name", state = "state")))
  r <- np_normalize(np_reference(data.frame(ein = c("1", "2"),
        name = c("THE FOUNDATION", "RIVERKEEPER FOUNDATION"),
        state = "AK", stringsAsFactors = FALSE),
        c(.ein = "ein", name = "name", state = "state")))
  blk <- np_block(q, r, by = "state", token = TRUE)
  # "THE"/"FOUNDATION" are stopwords; only ein 1 shares the real token
  expect_true(all(r$.ein[blk$.y] == "1"))
})

test_that("max_ref_freq drops corpus-common tokens", {
  f <- setup_frames()
  # 'CENTER' appears in several reference names; capping frequency removes it
  wide <- np_block(f$q, f$r, by = "state", token = TRUE)
  capped <- np_block(f$q, f$r, by = "state", token = TRUE, max_ref_freq = 1)
  expect_lte(nrow(capped), nrow(wide))
})

test_that("min_pair_idf keeps a distinctive match but drops common-token-only pairs", {
  # one distinctive org + many sharing a single common token ("CALIFORNIA")
  q <- np_normalize(np_query(data.frame(unique_entity_id = "a",
        name = "EARTH TEAM CALIFORNIA", state = "CA", stringsAsFactors = FALSE),
        c(.id = "unique_entity_id", name = "name", state = "state")))
  r <- np_normalize(np_reference(data.frame(
        ein = as.character(seq_len(21)),
        name = c("EARTH TEAM", paste("CALIFORNIA GROUP", 1:20)),
        state = "CA", stringsAsFactors = FALSE),
        c(.ein = "ein", name = "name", state = "state")))
  off <- np_block(q, r, by = "state", token = TRUE, stopwords = character(0))
  on  <- np_block(q, r, by = "state", token = TRUE, stopwords = character(0),
                  min_pair_idf = 3)
  expect_equal(nrow(off), 21)                 # EARTH TEAM + all CALIFORNIA*
  expect_equal(nrow(on), 1)                   # only the distinctive one survives
  expect_equal(r$.ein[on$.y], "1")            # EARTH TEAM
})

test_that("cross-key token blocking (by = NULL) crosses states", {
  q <- np_normalize(np_query(data.frame(unique_entity_id = "a",
        name = "RASMUSON FOUNDATION", state = "AK", stringsAsFactors = FALSE),
        c(.id = "unique_entity_id", name = "name", state = "state")))
  r <- np_normalize(np_reference(data.frame(ein = "1",
        name = "RASMUSON FOUNDATION", state = "WA", stringsAsFactors = FALSE),
        c(.ein = "ein", name = "name", state = "state")))
  expect_equal(nrow(np_block(q, r, by = "state", token = TRUE)), 0)   # different states
  expect_equal(nrow(np_block(q, r, by = NULL,   token = TRUE)), 1)    # token match crosses
})

test_that("np_compare accepts np_block candidates and scores them", {
  f <- setup_frames()
  blk <- np_block(f$q, f$r, by = "state", token = TRUE)
  pr  <- np_score(np_compare(f$q, f$r, candidates = blk), method = "hier")
  expect_s3_class(pr, "np_pairs")
  expect_equal(nrow(pr), nrow(blk))
  expect_true(all(pr$score >= 0 & pr$score <= 1))
})

test_that("np_match resolves the right EIN via token-blocked candidates", {
  f <- setup_frames()
  blk <- np_block(f$q, f$r, by = "state", token = TRUE)
  res <- np_match(f$q, f$r, method = "hier", candidates = blk)
  expect_equal(res$overall_ein[res$.id == "q1"], "05")
  expect_equal(res$overall_ein[res$.id == "q4"], "14")
})
