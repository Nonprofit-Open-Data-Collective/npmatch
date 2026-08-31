tmp_project <- function() file.path(tempdir(), paste0("npp-", as.integer(Sys.time()),
                                                     "-", sample.int(1e6, 1)))

test_that("np_project_init creates every stage folder and its subdirectories", {
  p <- tmp_project(); on.exit(unlink(p, recursive = TRUE))
  old <- options(npmatch.project = NULL); on.exit(options(old), add = TRUE)
  np_project_init(p, run_id = "unit", quiet = TRUE, use = FALSE)

  stages <- c("00_bmf", "00_sams", "01_stage1", "02_stage2", "03_stage3", "04_final")
  expect_true(all(dir.exists(file.path(p, stages))))
  # every stage has logs/; the working stages have batches/ and interim/
  expect_true(all(dir.exists(file.path(p, stages, "logs"))))
  expect_true(all(dir.exists(file.path(p, c("01_stage1", "02_stage2", "03_stage3"),
                                       "batches"))))
  expect_true(all(dir.exists(file.path(p, c("00_sams", "01_stage1", "02_stage2",
                                            "03_stage3", "04_final"), "interim"))))
  # stage-specific batch subdirectories
  expect_true(dir.exists(file.path(p, "01_stage1", "batches", "shards")))
  expect_true(dir.exists(file.path(p, "02_stage2", "batches", "decisions")))
  expect_true(dir.exists(file.path(p, "03_stage3", "batches", "packets")))
  expect_true(dir.exists(file.path(p, "03_stage3", "interim", "cache")))
})

test_that("np_project_init writes config, manifest, status and the documents", {
  p <- tmp_project(); on.exit(unlink(p, recursive = TRUE))
  old <- options(npmatch.project = NULL); on.exit(options(old), add = TRUE)
  np_project_init(p, run_id = "unit", quiet = TRUE, use = FALSE)

  expect_true(file.exists(file.path(p, "config.yml")))
  expect_true(file.exists(file.path(p, "manifest.csv")))
  expect_true(file.exists(file.path(p, "RUN-STATUS.md")))
  expect_true(file.exists(file.path(p, "README.md")))
  expect_true(file.exists(file.path(p, "AGENTS.md")))
  # a README in every stage folder
  expect_true(all(file.exists(file.path(p, names(npmatch:::.np_layout), "README.md"))))
  # prompts only in the two LLM stages
  expect_true(file.exists(file.path(p, "02_stage2", "PROMPT.md")))
  expect_true(file.exists(file.path(p, "03_stage3", "PROMPT.md")))
  expect_false(file.exists(file.path(p, "01_stage1", "PROMPT.md")))

  cfg <- readLines(file.path(p, "config.yml"))
  expect_true(any(grepl("^run_id: unit$", cfg)))
  expect_equal(nrow(utils::read.csv(file.path(p, "manifest.csv"))), 0L)
  # the run_id placeholder is substituted, not left in the template
  expect_false(any(grepl("{{run_id}}", readLines(file.path(p, "README.md")), fixed = TRUE)))
})

test_that("np_project_init is non-destructive on re-run", {
  p <- tmp_project(); on.exit(unlink(p, recursive = TRUE))
  old <- options(npmatch.project = NULL); on.exit(options(old), add = TRUE)
  np_project_init(p, run_id = "unit", quiet = TRUE, use = FALSE)

  keep <- file.path(p, "01_stage1", "stage1_yes.csv")
  utils::write.csv(data.frame(uei = "X"), keep, row.names = FALSE)
  writeLines("edited by hand", file.path(p, "README.md"))

  np_project_init(p, run_id = "unit", quiet = TRUE, use = FALSE)   # overwrite = FALSE
  expect_true(file.exists(keep))
  expect_equal(readLines(file.path(p, "README.md"))[1], "edited by hand")

  np_project_init(p, run_id = "unit", quiet = TRUE, use = FALSE, overwrite = TRUE)
  expect_true(file.exists(keep))                                   # data still untouched
  expect_false(readLines(file.path(p, "README.md"))[1] == "edited by hand")
})

test_that("template values survive backslashes (Windows paths)", {
  p <- tmp_project(); on.exit(unlink(p, recursive = TRUE))
  old <- options(npmatch.project = NULL); on.exit(options(old), add = TRUE)
  bs  <- rawToChar(as.raw(92))
  win <- paste0("C:", bs, "data", bs, "bmf.csv")
  np_project_init(p, run_id = "unit", bmf = win, quiet = TRUE, use = FALSE)

  # a regex replacement would eat the backslashes and yield "C:databmf.csv"
  expect_true(any(grepl(win, readLines(file.path(p, "00_bmf", "SOURCE.md")), fixed = TRUE)))
  expect_true(any(grepl(win, readLines(file.path(p, "config.yml")), fixed = TRUE)))
  expect_true(any(grepl(win, readLines(file.path(p, "00_bmf", "README.md")), fixed = TRUE)))
})

test_that("np_project_path resolves canonical names, aliases and the root", {
  old <- options(npmatch.project = "P:/runs/x"); on.exit(options(old))
  expect_equal(np_project_path("01_stage1", "stage1_yes.csv"),
               "P:/runs/x/01_stage1/stage1_yes.csv")
  expect_equal(np_project_path("stage1"), "P:/runs/x/01_stage1")
  expect_equal(np_project_path("3"), "P:/runs/x/03_stage3")
  expect_equal(np_project_path("bmf"), "P:/runs/x/00_bmf")
  expect_equal(np_project_path("final"), "P:/runs/x/04_final")
  expect_equal(np_project_path(""), "P:/runs/x")
  expect_equal(np_project_path("03_stage3", "batches/packets"),
               "P:/runs/x/03_stage3/batches/packets")
  expect_error(np_project_path("stage9"), "unknown stage")
})

test_that("project path and status error without an active project", {
  old <- options(npmatch.project = NULL); on.exit(options(old))
  Sys.unsetenv("NPMATCH_PROJECT")
  expect_true(is.na(np_project_root()))
  expect_error(np_project_path("stage1"), "no active npmatch project")
  expect_error(np_project_status(), "no active npmatch project")
})

test_that("np_project_use sets the option and warns on an incomplete project", {
  p <- tmp_project(); on.exit(unlink(p, recursive = TRUE))
  old <- options(npmatch.project = NULL); on.exit(options(old), add = TRUE)
  np_project_init(p, run_id = "unit", quiet = TRUE, use = FALSE)
  expect_true(is.na(np_project_root()))
  np_project_use(p, quiet = TRUE)
  expect_equal(np_project_root(), p)

  bare <- tmp_project(); dir.create(bare); on.exit(unlink(bare, recursive = TRUE), add = TRUE)
  expect_warning(np_project_use(bare, quiet = TRUE), "missing")
  expect_error(np_project_use(file.path(bare, "nope")), "not found")
})

test_that("np_project_status scans disk and tracks stages filling in", {
  p <- tmp_project(); on.exit(unlink(p, recursive = TRUE))
  old <- options(npmatch.project = NULL); on.exit(options(old), add = TRUE)
  np_project_init(p, run_id = "unit", quiet = TRUE, use = TRUE)

  s  <- np_project_status(write = FALSE, quiet = TRUE)
  st <- attr(s, "stages")
  expect_equal(attr(s, "run_id"), "unit")
  expect_true(all(st$status == "not run"))
  expect_equal(nrow(s), sum(st$expected))

  # one of four stage-1 outputs -> partial
  d <- data.frame(matrix(ncol = length(np_stage_schema()), nrow = 2))
  names(d) <- np_stage_schema()
  utils::write.csv(d, file.path(p, "01_stage1", "stage1_yes.csv"), row.names = FALSE)
  st <- attr(np_project_status(write = FALSE, quiet = TRUE), "stages")
  expect_equal(st$status[st$stage == "01_stage1"], "partial")
  expect_equal(st$present[st$stage == "01_stage1"], 1L)

  # all four -> complete, with row counts read off disk
  for (f in c("stage1_maybe.csv", "stage1_no.csv", "stage1_k_candidates.csv"))
    utils::write.csv(d, file.path(p, "01_stage1", f), row.names = FALSE)
  s  <- np_project_status(write = TRUE, quiet = TRUE)
  st <- attr(s, "stages")
  expect_equal(st$status[st$stage == "01_stage1"], "complete")
  expect_equal(unique(s$rows[s$stage == "01_stage1"]), 2L)
  expect_equal(st$status[st$stage == "02_stage2"], "not run")

  # removing an output makes the stage incomplete again -- a scan, not a ledger
  unlink(file.path(p, "01_stage1", "stage1_no.csv"))
  st <- attr(np_project_status(write = FALSE, quiet = TRUE), "stages")
  expect_equal(st$status[st$stage == "01_stage1"], "partial")

  status_md <- readLines(file.path(p, "RUN-STATUS.md"))
  expect_true(any(grepl("Run unit - status", status_md, fixed = TRUE)))
  expect_true(any(grepl("01_stage1", status_md, fixed = TRUE)))
})

test_that("the shared outcome schema is stable and leads with the join keys", {
  s <- np_stage_schema()
  expect_type(s, "character")
  expect_equal(s[1:4], c("uei", "run_id", "stage", "outcome"))
  expect_true(all(c("ein", "decided_by", "confidence", "reason") %in% s))
  expect_false(anyDuplicated(s) > 0)
})
