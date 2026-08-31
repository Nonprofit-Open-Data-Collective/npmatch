tmp_p <- function() {
  p <- file.path(tempdir(), paste0("np3-", as.integer(Sys.time()), "-",
                                   sample.int(1e6, 1)))
  np_project_init(p, run_id = "t", quiet = TRUE, use = TRUE)
  p
}

# Write a stage outcome file in the shared schema.
put <- function(stage_dir, file, uei, outcome, ein = "", name = "N",
                decided_by = "algorithm", confidence = "", reason = "r",
                stage = "1") {
  n <- length(uei)
  r <- function(x) if (n) rep_len(x, n) else character(0)
  d <- data.frame(uei = as.character(uei), run_id = r("t"), stage = r(stage),
                  outcome = r(outcome), ein = r(ein), name_source = r(name),
                  name_reference = r(""), score = r(""), decided_by = r(decided_by),
                  confidence = r(confidence), reason = r(reason),
                  stringsAsFactors = FALSE)
  data.table::fwrite(d, np_project_path(stage_dir, file))
  d
}

# ---- entity gate ------------------------------------------------------------

test_that("np_entity_gate classifies by name and structure", {
  d <- data.frame(
    name = c("ACME HOLDINGS LLC", "CITY OF AUSTIN", "FIRST BAPTIST CHURCH",
             "RIVER ARTS COUNCIL", "NAVAJO NATION OF ARIZONA", "JOHN Q SMITH",
             "OAKLAND UNIFIED SCHOOL DISTRICT"),
    state = "TX", structure = c("", "", "", "", "", "2J", ""),
    stringsAsFactors = FALSE)
  g <- np_entity_gate(d, structure = "structure")$entity_gate
  expect_equal(g, c("for_profit_form", "government", "church",
                    "nonprofit_candidate", "tribal_government", "individual",
                    "government"))
})

test_that("the gate applies its categories in priority order", {
  # a foreign government unit reports as foreign: being outside the BMF's scope
  # is the more basic fact than what kind of body it is
  d <- data.frame(name = "CITY OF TORONTO", state = "ON", stringsAsFactors = FALSE)
  expect_equal(np_entity_gate(d)$entity_gate, "foreign")
  # a US-incorporated foreign registrant is flagged for research, not settled
  d2 <- data.frame(name = "GLOBAL AID SOCIETY", state = "ON", incorp = "DE",
                   stringsAsFactors = FALSE)
  g2 <- np_entity_gate(d2, state_incorp = "incorp")
  expect_equal(g2$entity_gate, "foreign")
  expect_true(g2$foreign_us_incorp)
})

test_that("a person-form name is only 'individual' with the 2J structure code", {
  d <- data.frame(name = "JOHN Q SMITH", state = "TX", structure = c("2J", "2X"),
                  stringsAsFactors = FALSE)
  expect_equal(np_entity_gate(d, structure = "structure")$entity_gate,
               c("individual", "nonprofit_candidate"))
  # an org-sounding name is never 'individual' even under 2J
  d2 <- data.frame(name = "SMITH FAMILY FOUNDATION", state = "TX", structure = "2J",
                   stringsAsFactors = FALSE)
  expect_equal(np_entity_gate(d2, structure = "structure")$entity_gate,
               "nonprofit_candidate")
})

test_that("np_gate_rules is data the caller can override", {
  r <- np_gate_rules()
  expect_type(r, "list")
  expect_true(all(c("government", "church", "tribal", "us_states") %in% names(r)))
  r$church <- "\\bZZZNOMATCH\\b"
  d <- data.frame(name = "FIRST BAPTIST CHURCH", state = "TX", stringsAsFactors = FALSE)
  expect_equal(np_entity_gate(d, rules = r)$entity_gate, "nonprofit_candidate")
})

# ---- stage 3 ----------------------------------------------------------------

test_that("np_stage3_run screens, queues, then collects", {
  p <- tmp_p(); on.exit({ unlink(p, recursive = TRUE); options(npmatch.project = NULL) })
  put("01_stage1", "stage1_no.csv",
      uei = c("N1", "N2", "N3"), outcome = "NO",
      name = c("ACME HOLDINGS LLC", "RIVER ARTS COUNCIL", "HOPE CENTER"))
  put("02_stage2", "stage2_no.csv", uei = "N4", outcome = "NO",
      name = "COMMUNITY TRUST", decided_by = "llm_review", stage = "2")

  seed <- np_stage3_run(verbose = FALSE)
  expect_equal(nrow(seed), 4L)
  expect_true(all(c("N1", "N2", "N3", "N4") %in% seed$uei))
  # the LLC is settled for free; the rest are queued
  expect_equal(seed$determination[seed$uei == "N1"], "not_a_nonprofit")
  expect_false(seed$web[seed$uei == "N1"])
  expect_true(all(seed$web[seed$uei %in% c("N2", "N3", "N4")]))
  expect_true(length(list.files(np_project_path("03_stage3", "batches/packets"),
                                "[.]md$")) >= 1L)
  # nothing emitted until the agent returns
  expect_false(file.exists(np_project_path("03_stage3", "stage3_yes.csv")))
  expect_null(np_stage3_run(verbose = FALSE))

  writeLines(c(
    paste(c("uei","sam_name","run","stage","ein_found","determination",
            "resolving_tier","confidence","sources","judgement","notes"),
          collapse = "\t"),
    paste(c("N2","RIVER ARTS COUNCIL","t","1","44-4444444","match","tier3","high",
            "web:example.org","same org","" ), collapse = "\t"),
    paste(c("N3","HOPE CENTER","t","1","","nonprofit_not_in_bmf","tier1","medium",
            "bmf_grep: no name hit","real but unlisted",""), collapse = "\t"),
    paste(c("N4","COMMUNITY TRUST","t","2","","cant_determine","tier3","low",
            "web: nothing decisive","insufficient evidence",""), collapse = "\t")),
    np_project_path("03_stage3", "batches/out/run-0001.tsv"))

  out <- np_stage3_run(verbose = FALSE)
  expect_equal(nrow(out), 4L)
  yes <- utils::read.csv(np_project_path("03_stage3", "stage3_yes.csv"),
                         colClasses = "character")
  no  <- utils::read.csv(np_project_path("03_stage3", "stage3_no.csv"),
                         colClasses = "character")
  expect_equal(names(yes), np_stage_schema())
  expect_equal(nrow(yes), 1L)
  expect_equal(yes$uei, "N2")
  expect_equal(yes$ein, "44-4444444")
  expect_true(all(yes$decided_by == "llm_research"))
  expect_equal(nrow(no), 3L)
  # the taxonomy survives into `reason` rather than being flattened away
  expect_true(all(c("not_a_nonprofit", "nonprofit_not_in_bmf", "cant_determine")
                  %in% no$reason))
  expect_true(file.exists(np_project_path("03_stage3",
                                          "stage3_research_findings.csv")))
})

test_that("stage 3 can be constrained to stage-1 NO only", {
  p <- tmp_p(); on.exit({ unlink(p, recursive = TRUE); options(npmatch.project = NULL) })
  put("01_stage1", "stage1_no.csv", uei = c("N1", "N2"), outcome = "NO")
  put("02_stage2", "stage2_no.csv", uei = "N9", outcome = "NO", stage = "2")
  seed <- np_stage3_run(sources = "stage1_no", verbose = FALSE)
  expect_equal(sort(seed$uei), c("N1", "N2"))
  expect_false("N9" %in% seed$uei)
})

test_that("a match whose EIN is absent from the reference is reclassified", {
  p <- tmp_p(); on.exit({ unlink(p, recursive = TRUE); options(npmatch.project = NULL) })
  put("01_stage1", "stage1_no.csv", uei = "N1", outcome = "NO", name = "HOPE CENTER")
  idx <- data.frame(ein = c("11-1111111", "22-2222222"), stringsAsFactors = FALSE)
  np_stage3_run(bmf_index = idx, verbose = FALSE)
  writeLines(c(
    paste(c("uei","sam_name","run","stage","ein_found","determination",
            "resolving_tier","confidence","sources","judgement","notes"),
          collapse = "\t"),
    paste(c("N1","HOPE CENTER","t","1","99-9999999","match","tier3","high",
            "web:x","found it",""), collapse = "\t")),
    np_project_path("03_stage3", "batches/out/run-0001.tsv"))

  out <- np_stage3_run(bmf_index = idx, verbose = FALSE)
  # a match the crosswalk cannot join is not a match; the EIN is kept
  expect_equal(out$determination, "nonprofit_not_in_bmf")
  expect_equal(out$ein_found, "99-9999999")
  expect_true(grepl("RECLASSIFIED", out$notes))
  expect_equal(nrow(utils::read.csv(np_project_path("03_stage3", "stage3_yes.csv"),
                                    colClasses = "character")), 0L)
})

test_that("a queued case that returns nothing is a hole, not a NO", {
  p <- tmp_p(); on.exit({ unlink(p, recursive = TRUE); options(npmatch.project = NULL) })
  put("01_stage1", "stage1_no.csv", uei = c("N1", "N2"), outcome = "NO",
      name = c("HOPE CENTER", "RIVER ARTS COUNCIL"))
  np_stage3_run(verbose = FALSE)
  writeLines(c(
    paste(c("uei","sam_name","run","stage","ein_found","determination",
            "resolving_tier","confidence","sources","judgement","notes"),
          collapse = "\t"),
    paste(c("N1","HOPE CENTER","t","1","","not_a_nonprofit","tier1","high",
            "s","j",""), collapse = "\t")),
    np_project_path("03_stage3", "batches/out/run-0001.tsv"))

  expect_warning(out <- np_stage3_run(verbose = FALSE), "returned no agent row")
  expect_equal(out$determination[out$uei == "N2"], "")
  no <- utils::read.csv(np_project_path("03_stage3", "stage3_no.csv"),
                        colClasses = "character")
  expect_equal(no$reason[no$uei == "N2"], "unresolved")
  rep <- readLines(np_project_path("03_stage3", "STAGE3-REPORT.md"))
  expect_true(any(grepl("returned nothing", rep, fixed = TRUE)))
})

# ---- final rollup -----------------------------------------------------------

test_that("np_final_run binds the stages and splits blocking from scoring loss", {
  p <- tmp_p(); on.exit({ unlink(p, recursive = TRUE); options(npmatch.project = NULL) })
  put("01_stage1", "stage1_yes.csv", uei = "A", outcome = "YES", ein = "11-1111111")
  put("01_stage1", "stage1_maybe.csv", uei = character(0), outcome = character(0))
  put("01_stage1", "stage1_no.csv", uei = c("C", "D"), outcome = "NO")
  put("02_stage2", "stage2_yes.csv", uei = "B", outcome = "YES", ein = "22-2222222",
      decided_by = "llm_review", stage = "2")
  put("02_stage2", "stage2_no.csv", uei = character(0), outcome = character(0), stage = "2")
  put("03_stage3", "stage3_yes.csv", uei = "C", outcome = "YES", ein = "33-3333333",
      decided_by = "llm_research", stage = "3")
  put("03_stage3", "stage3_no.csv", uei = "D", outcome = "NO",
      decided_by = "llm_research", stage = "3", reason = "not_a_nonprofit")

  # A and B were surfaced by blocking; C's answer never was
  data.table::fwrite(data.frame(
    uei = c("A", "B", "B", "C"),
    ein = c("11-1111111", "22-2222222", "99-9999999", "77-7777777"),
    total_score = c("0.9", "0.7", "0.6", "0.3"), stringsAsFactors = FALSE),
    np_project_path("01_stage1", "stage1_k_candidates.csv"))

  xw <- np_final_run(verbose = FALSE)
  expect_equal(sort(xw$uei), c("A", "B", "C"))
  expect_equal(names(xw), np_stage_schema())
  expect_equal(xw$decided_by[xw$uei == "C"], "llm_research")

  ev <- utils::read.csv(np_project_path("04_final", "eval_frame.csv"),
                        colClasses = "character")
  expect_true(all(c("final_ein", "final_basis", "is_final_ein",
                    "final_ein_in_candset", "candidate_source") %in% names(ev)))
  # A and B: the answer was in the candidate set -> a scoring question
  expect_equal(unique(ev$final_ein_in_candset[ev$uei %in% c("A", "B")]), "1")
  # C: the answer was never surfaced -> a blocking miss, kept as a synthetic row
  cr <- ev[ev$uei == "C", ]
  expect_true("stage3_research" %in% cr$candidate_source)
  syn <- cr[cr$candidate_source == "stage3_research", ]
  expect_equal(nrow(syn), 1L)
  expect_equal(syn$ein, "33-3333333")
  expect_equal(syn$final_ein_in_candset, "0")
  # the sub-threshold cascade candidate for C is still there alongside it
  expect_true("77-7777777" %in% cr$ein)

  st <- utils::read.csv(np_project_path("04_final", "FINAL-STATS.csv"),
                        colClasses = "character")
  expect_equal(st$value[st$metric == "matched"], "3")
  expect_equal(st$value[st$metric == "answers_outside_candidate_set"], "1")
})

test_that("the earliest stage wins when one id is matched twice", {
  p <- tmp_p(); on.exit({ unlink(p, recursive = TRUE); options(npmatch.project = NULL) })
  put("01_stage1", "stage1_yes.csv", uei = "A", outcome = "YES", ein = "11-1111111")
  put("03_stage3", "stage3_yes.csv", uei = "A", outcome = "YES", ein = "99-9999999",
      decided_by = "llm_research", stage = "3")
  xw <- np_final_run(verbose = FALSE)
  expect_equal(nrow(xw), 1L)
  expect_equal(xw$ein, "11-1111111")
  expect_equal(xw$decided_by, "algorithm")
  expect_true(any(grepl("more than one stage",
                        readLines(np_project_path("04_final", "FINAL-REPORT.md")))))
})

test_that("the runners refuse to guess", {
  old <- options(npmatch.project = NULL); on.exit(options(old))
  Sys.unsetenv("NPMATCH_PROJECT")
  expect_error(np_stage3_run(), "no active npmatch project")
  expect_error(np_final_run(), "no active npmatch project")
  p <- tmp_p(); on.exit({ unlink(p, recursive = TRUE)
                          options(npmatch.project = NULL) }, add = TRUE)
  expect_error(np_stage3_run(), "no NO cases found")
  expect_error(np_stage3_run(sources = "stage9_no"), "unknown source")
  expect_error(np_final_run(), "no stage outputs found")
})

test_that("web_reason is recorded only for cases actually queued", {
  p <- tmp_p(); on.exit({ unlink(p, recursive = TRUE); options(npmatch.project = NULL) })
  put("01_stage1", "stage1_no.csv", uei = c("N1", "N2"), outcome = "NO",
      name = c("ACME HOLDINGS LLC", "RIVER ARTS COUNCIL"))
  seed <- np_stage3_run(verbose = FALSE)
  expect_false(seed$web[seed$sam_name == "ACME HOLDINGS LLC"])
  expect_equal(seed$web_reason[seed$sam_name == "ACME HOLDINGS LLC"], "")
  expect_true(nzchar(seed$web_reason[seed$sam_name == "RIVER ARTS COUNCIL"]))
})
