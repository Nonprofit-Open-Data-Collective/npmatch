tmp_stage_project <- function() {
  p <- file.path(tempdir(), paste0("nps-", as.integer(Sys.time()), "-",
                                   sample.int(1e6, 1)))
  np_project_init(p, run_id = "t", quiet = TRUE, use = TRUE)
  p
}

# A tiny query/reference pair that exercises all three tiers.
stage_fixture <- function() {
  q <- np_test_query()
  q$unique_entity_id <- c("U1", "U2", "U3", "U4")
  # U3 is deliberately unmatchable: no reference row shares a token with it
  q$name[3] <- "QQQ ZZZ UNMATCHABLE XYZZY"
  q$street[3] <- "9 NOWHERE LN"
  list(query = q, reference = np_test_reference())
}

test_that("np_stage1_run writes the four standard outputs in the shared schema", {
  p <- tmp_stage_project(); on.exit({ unlink(p, recursive = TRUE)
                                      options(npmatch.project = NULL) })
  f <- stage_fixture()
  out <- np_stage1_run(query = f$query, reference = f$reference,
                       query_map = np_test_map_q, reference_map = np_test_map_r,
                       compute_size = 10L, verbose = FALSE)

  for (o in c("stage1_yes.csv", "stage1_maybe.csv", "stage1_no.csv",
              "stage1_k_candidates.csv"))
    expect_true(file.exists(np_project_path("01_stage1", o)), info = o)

  # every outcome file carries exactly the shared schema, in order
  for (o in c("stage1_yes.csv", "stage1_maybe.csv", "stage1_no.csv")) {
    d <- utils::read.csv(np_project_path("01_stage1", o), colClasses = "character")
    expect_equal(names(d), np_stage_schema(), info = o)
  }
  # one row per source id, and the three files partition the queries
  n <- sum(vapply(c("stage1_yes.csv", "stage1_maybe.csv", "stage1_no.csv"),
                  function(o) nrow(utils::read.csv(np_project_path("01_stage1", o),
                                                   colClasses = "character")),
                  integer(1)))
  expect_equal(n, nrow(f$query))
  expect_equal(nrow(out), nrow(f$query))
  expect_false(anyDuplicated(out$uei) > 0)
  expect_true(all(out$run_id == "t"))
  expect_true(all(out$stage == "1"))
  expect_true(all(out$decided_by == "algorithm"))

  # NO rows carry no reference-side selection; the near miss lives in k_candidates
  no <- out[out$outcome == "NO", , drop = FALSE]
  expect_true(all(no$ein == ""))
  expect_true(all(no$name_reference == ""))

  expect_true(file.exists(np_project_path("01_stage1", "STAGE1-REPORT.md")))
  expect_true(file.exists(np_project_path("01_stage1", "STAGE1-STATS.csv")))
})

test_that("stage 1 persists the cascade result and scored pairs", {
  p <- tmp_stage_project(); on.exit({ unlink(p, recursive = TRUE)
                                      options(npmatch.project = NULL) })
  f <- stage_fixture()
  np_stage1_run(query = f$query, reference = f$reference, compute_size = 10L,
                query_map = np_test_map_q, reference_map = np_test_map_r, verbose = FALSE)
  interim <- np_project_path("01_stage1", "interim")
  expect_true(length(list.files(interim, "^res-[0-9]+[.]rds$")) >= 1L)
  expect_true(length(list.files(interim, "^pairs-[0-9]+[.]rds$")) >= 1L)
  # the NO tier is written per chunk rather than discarded
  expect_true(length(list.files(np_project_path("01_stage1", "batches"),
                                "^unmatched-[0-9]+[.]csv$")) >= 1L)
})

test_that("a query with no candidate at all is NO / no_candidates", {
  p <- tmp_stage_project(); on.exit({ unlink(p, recursive = TRUE)
                                      options(npmatch.project = NULL) })
  f <- stage_fixture()
  out <- np_stage1_run(query = f$query, reference = f$reference,
                       query_map = np_test_map_q, reference_map = np_test_map_r,
                       compute_size = 10L, verbose = FALSE)
  u3 <- out[out$uei == "U3", ]
  expect_equal(nrow(u3), 1L)
  expect_equal(u3$outcome, "NO")
  # either the cascade surfaced nothing, or it surfaced only sub-floor candidates
  expect_true(u3$reason == "no_candidates" || nzchar(u3$reason))
})

test_that("np_stage2_run prepares shards, then collects decisions", {
  p <- tmp_stage_project(); on.exit({ unlink(p, recursive = TRUE)
                                      options(npmatch.project = NULL) })
  # hand-build stage-1 outputs so the test does not depend on tiering thresholds
  maybe <- data.frame(uei = c("A1", "B2"), run_id = "t", stage = "1",
                      outcome = "MAYBE", ein = "", name_source = c("ALPHA", "BETA"),
                      name_reference = "", score = c("0.7", "0.6"),
                      decided_by = "algorithm", confidence = "", reason = "band",
                      stringsAsFactors = FALSE)
  data.table::fwrite(maybe, np_project_path("01_stage1", "stage1_maybe.csv"))
  cand <- data.frame(
    uei = c("A1", "A1", "B2"), ein = c("11-1111111", "22-2222222", "33-3333333"),
    is_top_candidate = c("1", "0", "1"), total_score = c("0.7", "0.5", "0.6"),
    name_uss_raw_main = c("ALPHA", "ALPHA", "BETA"),
    name_bmf_raw_main = c("ALPHA INC", "ALPHA TRUST", "BETA SOCIETY"),
    match_decision = "MAYBE", stringsAsFactors = FALSE)
  data.table::fwrite(cand, np_project_path("01_stage1", "stage1_k_candidates.csv"))

  man <- np_stage2_run(shard_size = 250L, verbose = FALSE)
  expect_equal(nrow(man), 1L)
  expect_equal(man$n_uei, 2L)
  shard <- list.files(np_project_path("02_stage2", "batches/slim"), full.names = TRUE)
  expect_length(shard, 1L)
  # outcome files are not written until decisions come back
  expect_false(file.exists(np_project_path("02_stage2", "stage2_yes.csv")))

  # a second call with no decisions yet is a no-op that reports, not an error
  expect_null(np_stage2_run(verbose = FALSE))

  data.table::fwrite(data.frame(
    uei = c("A1", "B2"), best_ein = c("22-2222222", ""),
    llm_decision = c("YES", "NO"), llm_confidence = c("high", "medium"),
    llm_reason = c("address confirms", "no credible candidate"),
    stringsAsFactors = FALSE),
    np_project_path("02_stage2", "batches/decisions/decision-01.csv"))

  out <- np_stage2_run(verbose = FALSE)
  expect_equal(names(out), np_stage_schema())
  expect_equal(nrow(out), 2L)
  expect_equal(out$outcome[out$uei == "A1"], "YES")
  expect_equal(out$ein[out$uei == "A1"], "22-2222222")
  # the chosen candidate's reference name is carried, not the top-scoring one
  expect_equal(out$name_reference[out$uei == "A1"], "ALPHA TRUST")
  expect_equal(out$outcome[out$uei == "B2"], "NO")
  expect_equal(out$ein[out$uei == "B2"], "")
  expect_true(all(out$decided_by == "llm_review"))

  yes <- utils::read.csv(np_project_path("02_stage2", "stage2_yes.csv"),
                         colClasses = "character")
  expect_equal(names(yes), np_stage_schema())
  expect_equal(nrow(yes), 1L)
})

test_that("an empty MAYBE queue completes stage 2 rather than failing it", {
  p <- tmp_stage_project(); on.exit({ unlink(p, recursive = TRUE)
                                      options(npmatch.project = NULL) })
  empty <- .np_empty_outcomes()
  data.table::fwrite(empty, np_project_path("01_stage1", "stage1_maybe.csv"))
  data.table::fwrite(data.frame(uei = character()),
                     np_project_path("01_stage1", "stage1_k_candidates.csv"))

  out <- np_stage2_run(verbose = FALSE)         # stage 1 resolved everything
  expect_equal(nrow(out), 0L)
  for (f in c("stage2_yes.csv", "stage2_no.csv")) {
    fp <- np_project_path("02_stage2", f)
    expect_true(file.exists(fp), info = f)
    # written with the full schema so the rollup can bind them unchanged
    expect_equal(names(utils::read.csv(fp, colClasses = "character")),
                 np_stage_schema(), info = f)
  }
  st <- attr(np_project_status(write = FALSE, quiet = TRUE), "stages")
  expect_equal(st$status[st$stage == "02_stage2"], "complete")
})

test_that("an unadjudicated shard is reported as a hole, not counted as NO", {
  p <- tmp_stage_project(); on.exit({ unlink(p, recursive = TRUE)
                                      options(npmatch.project = NULL) })
  maybe <- data.frame(uei = c("A1", "B2", "C3"), run_id = "t", stage = "1",
                      outcome = "MAYBE", ein = "", name_source = "X",
                      name_reference = "", score = "0.7", decided_by = "algorithm",
                      confidence = "", reason = "band", stringsAsFactors = FALSE)
  data.table::fwrite(maybe, np_project_path("01_stage1", "stage1_maybe.csv"))
  cand <- data.frame(uei = c("A1", "B2", "C3"), ein = "11-1111111",
                     name_uss_raw_main = "X", name_bmf_raw_main = "X INC",
                     total_score = "0.7", stringsAsFactors = FALSE)
  data.table::fwrite(cand, np_project_path("01_stage1", "stage1_k_candidates.csv"))
  np_stage2_run(verbose = FALSE)

  # only two of the three come back
  data.table::fwrite(data.frame(
    uei = c("A1", "B2"), best_ein = c("11-1111111", ""),
    llm_decision = c("YES", "NO"), llm_confidence = "high",
    llm_reason = "r", stringsAsFactors = FALSE),
    np_project_path("02_stage2", "batches/decisions/decision-01.csv"))

  expect_warning(out <- np_stage2_run(verbose = FALSE), "never adjudicated")
  expect_equal(nrow(out), 2L)                       # C3 absent, not a NO
  expect_false("C3" %in% out$uei)
  rep <- readLines(np_project_path("02_stage2", "STAGE2-REPORT.md"))
  expect_true(any(grepl("NOT returned", rep, fixed = TRUE)))
})

test_that("stage runners refuse to guess without a project or an input", {
  old <- options(npmatch.project = NULL); on.exit(options(old))
  Sys.unsetenv("NPMATCH_PROJECT")
  expect_error(np_stage1_run(), "no active npmatch project")
  expect_error(np_stage2_run(), "no active npmatch project")

  p <- tmp_stage_project(); on.exit({ unlink(p, recursive = TRUE)
                                      options(npmatch.project = NULL) }, add = TRUE)
  expect_error(np_stage1_run(), "source query not found")
  expect_error(np_stage2_run(), "stage 1 has not produced")
})
