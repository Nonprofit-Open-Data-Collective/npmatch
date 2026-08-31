# ---------------------------------------------------------------------------
# Stage runners.
#
# One np_stageN_run() per stage of a project created by np_project_init(). Each
# reads its inputs from the previous stage's standard outputs, writes its own,
# and leaves a report next to them.
#
# Stages 2 and 3 have an LLM in the middle, so their runners are RESUMABLE
# rather than split into two functions: the first call writes the agent inputs
# and stops at the hand-off; a second call, after the agent has written its
# outputs, collects them. Same idiom as np_run_batches()'s chunk resume.
# ---------------------------------------------------------------------------

.np_empty_outcomes <- function() {
  d <- as.data.frame(matrix(character(0), nrow = 0,
                            ncol = length(np_stage_schema())),
                     stringsAsFactors = FALSE)
  names(d) <- np_stage_schema()
  d
}

# Project a tiered cascade result onto the shared outcome schema. One row per
# query. Reference-side fields are blank on NO: nothing was selected, and the
# near miss belongs in stage1_k_candidates, not here.
.np_outcome_frame <- function(tiered, stage, run_id, decided_by, config = NULL) {
  d <- as.data.frame(tiered, stringsAsFactors = FALSE)
  if (!nrow(d)) return(.np_empty_outcomes())
  if (is.null(config)) config <- attr(tiered, "config")
  if (is.null(config)) config <- np_config()
  tier <- as.character(d$tier)
  no   <- tier == "NO"
  reason <- tryCatch(
    .np_route_reason(d, config$thresholds[["yes"]], config$thresholds[["maybe"]],
                     config$min_margin),
    error = function(e) rep(NA_character_, nrow(d)))
  blank <- function(x) { x <- as.character(x); x[is.na(x)] <- ""; x }
  out <- data.frame(
    uei            = blank(d$.id),
    run_id         = run_id,
    stage          = as.character(stage),
    outcome        = tier,
    ein            = ifelse(no, "", blank(d$overall_ein)),
    name_source    = blank(d$name_x),
    name_reference = ifelse(no, "", blank(d$overall_name_y)),
    score          = blank(round(as.numeric(d$overall_score), 3)),
    decided_by     = decided_by,
    confidence     = "",
    reason         = blank(reason),
    stringsAsFactors = FALSE)
  out[, np_stage_schema(), drop = FALSE]
}

# Queries that reached the cascade but produced no candidate at all. They are a
# different failure from "candidates existed and scored low", and keeping them
# distinct is what makes blocking recall measurable.
.np_zero_candidate_rows <- function(ids, stage, run_id, names = NULL) {
  if (!length(ids)) return(.np_empty_outcomes())
  d <- .np_empty_outcomes()[rep(NA_integer_, length(ids)), , drop = FALSE]
  d[] <- ""
  d$uei <- as.character(ids)
  d$run_id <- run_id; d$stage <- as.character(stage)
  d$outcome <- "NO"; d$decided_by <- "algorithm"
  d$name_source <- if (is.null(names)) "" else as.character(names)
  d$reason <- "no_candidates"
  rownames(d) <- NULL
  d
}

.np_write_outcomes <- function(frame, stage_dir, prefix, project) {
  paths <- character(0)
  for (o in c("YES", "MAYBE", "NO")) {
    sub <- frame[frame$outcome == o, , drop = FALSE]
    if (o == "MAYBE" && !grepl("stage1", prefix)) next     # only stage 1 has MAYBE
    f <- np_project_path(stage_dir, sprintf("%s_%s.csv", prefix, tolower(o)),
                         project = project)
    data.table::fwrite(sub, f)
    paths[o] <- f
  }
  paths
}

#' Run stage 1 - the probabilistic cascade
#'
#' Matches the prepared source against the reference and writes the four stage-1
#' outputs: `stage1_yes`, `stage1_maybe`, `stage1_no` (all in the shared
#' [np_stage_schema()], one row per source id) and `stage1_k_candidates` (one row
#' per surfaced candidate, joined to any of them by `uei`).
#'
#' Work is delegated to [np_run_batches()], which normalizes the reference once
#' and chunks the query. Unlike a bare `np_run_batches()` call this runner keeps
#' everything: the review frame spans **all three tiers**, the NO tier is written
#' rather than dropped, and each chunk's cascade result and scored pairs are
#' persisted to `interim/`. Those pairs are the only record of what blocking
#' surfaced; without them a later evaluation frame cannot be built except by
#' re-running the match against a possibly-changed candidate set.
#'
#' @param query The prepared source frame, or a path to one. Defaults to
#'   `00_sams/sam_query.csv` in the project.
#' @param reference The reference BMF: raw data frame, [np_reference()], or
#'   pre-normalized reference. May be `NULL` when `cache` holds a built bundle.
#' @param project Project root. Defaults to [np_project_root()].
#' @param cache Optional `.rds` bundle of the normalized reference, passed to
#'   [np_run_batches()].
#' @param compute_size,review_size,seed,method,config Passed to [np_run_batches()].
#' @param query_map,reference_map Schema maps for the source and reference,
#'   passed to [np_run_batches()]. Default to [np_map_sam()] / [np_map_bmf()].
#' @param k Candidates surfaced per query in `stage1_k_candidates`. Default 3.
#' @param bmf_context,sam_context Optional raw frames whose `BMF_` / `SAM_`
#'   context columns are joined onto the candidate frame.
#' @param only Optional chunk numbers, for a partial or resumed run.
#' @param verbose Print progress. Default `TRUE`.
#' @return The consolidated outcome frame, invisibly.
#' @seealso [np_project_init()], [np_stage2_run()], [np_run_batches()].
#' @export
np_stage1_run <- function(query = NULL, reference = NULL,
                          project = np_project_root(), cache = NULL,
                          compute_size = 2500L, review_size = 250L,
                          k = 3, seed = 1L, method = "hier",
                          query_map = np_map_sam(), reference_map = np_map_bmf(),
                          config = np_config(), bmf_context = NULL,
                          sam_context = NULL, only = NULL, verbose = TRUE) {
  say <- function(...) if (verbose) message(sprintf(...))
  if (is.na(project))
    stop("no active npmatch project; call np_project_init() or np_project_use().",
         call. = FALSE)
  run_id <- attr(np_project_status(project, write = FALSE, quiet = TRUE), "run_id")

  if (is.null(query)) query <- np_project_path("00_sams", "sam_query.csv",
                                               project = project)
  if (is.character(query)) {
    if (!file.exists(query))
      stop("source query not found: ", query,
           "\n  put a prepared SAM extract at 00_sams/sam_query.csv, or pass query=.",
           call. = FALSE)
    query <- as.data.frame(data.table::fread(query, colClasses = "character",
                                             showProgress = FALSE))
  }

  batches <- np_project_path("01_stage1", "batches", create = TRUE, project = project)
  interim <- np_project_path("01_stage1", "interim", create = TRUE, project = project)
  logs    <- np_project_path("01_stage1", "logs",    create = TRUE, project = project)

  say("stage 1: %s query rows", format(nrow(query), big.mark = ","))
  t0 <- Sys.time()
  summ <- np_run_batches(
    query = query, reference = reference, compute_size = compute_size,
    review_size = review_size, out_dir = batches, only = only, config = config,
    method = method, seed = seed, cache = cache,
    query_map = query_map, reference_map = reference_map,
    sam_context = sam_context, bmf_context = bmf_context,
    review_tiers = c("YES", "MAYBE", "NO"),      # candidate frame spans every tier
    save_interim = interim, verbose = verbose)
  mins <- as.numeric(difftime(Sys.time(), t0, units = "mins"))

  # --- consolidate the per-chunk cascade results into the shared schema -------
  res_files <- sort(list.files(interim, "^res-[0-9]+[.]rds$", full.names = TRUE))
  if (!length(res_files))
    stop("no cascade results in ", interim, "; stage 1 did not complete.", call. = FALSE)
  frame <- do.call(rbind, lapply(res_files, function(f)
    .np_outcome_frame(readRDS(f), stage = 1L, run_id = run_id,
                      decided_by = "algorithm", config = config)))

  # queries the cascade returned no row for surfaced no candidate at all
  id_col <- intersect(c("uei", "unique_entity_id", ".id"), names(query))[1]
  if (!is.na(id_col)) {
    missing_ids <- setdiff(as.character(query[[id_col]]), frame$uei)
    if (length(missing_ids)) {
      nm_col <- intersect(c("legal_business_name", "name", "sam_name"), names(query))[1]
      nm <- if (!is.na(nm_col))
        as.character(query[[nm_col]])[match(missing_ids, as.character(query[[id_col]]))]
      else NULL
      frame <- rbind(frame, .np_zero_candidate_rows(missing_ids, 1L, run_id, nm))
      say("  %s quer%s with no candidate at all -> NO / no_candidates",
          format(length(missing_ids), big.mark = ","),
          if (length(missing_ids) == 1L) "y" else "ies")
    }
  }
  frame <- frame[!duplicated(frame$uei), , drop = FALSE]
  rownames(frame) <- NULL

  .np_write_outcomes(frame, "01_stage1", "stage1", project)

  # --- candidate-level frame -------------------------------------------------
  rev_files <- sort(list.files(batches, "^review-[0-9]+[.]csv$", full.names = TRUE))
  kc <- if (length(rev_files))
    data.table::rbindlist(lapply(rev_files, data.table::fread,
                                 colClasses = "character", showProgress = FALSE),
                          use.names = TRUE, fill = TRUE)
  else data.table::data.table()
  data.table::fwrite(kc, np_project_path("01_stage1", "stage1_k_candidates.csv",
                                         project = project))

  # --- reports ---------------------------------------------------------------
  tt <- table(factor(frame$outcome, c("YES", "MAYBE", "NO")))
  data.table::fwrite(summ, np_project_path("01_stage1", "STAGE1-STATS.csv",
                                           project = project))
  pct <- function(a) if (nrow(frame)) sprintf("%.1f%%", 100 * a / nrow(frame)) else "n/a"
  writeLines(c(
    sprintf("# Stage 1 - %s", run_id), "",
    sprintf("_generated %s_", format(Sys.time(), "%Y-%m-%d %H:%M:%S")), "",
    sprintf("- queries: %s", format(nrow(frame), big.mark = ",")),
    sprintf("- chunks: %d (size ~%s)", nrow(summ), format(compute_size, big.mark = ",")),
    sprintf("- runtime: %.1f min", mins), "",
    "| outcome | n | share | goes to |", "|---|---|---|---|",
    sprintf("| YES | %s | %s | 04_final |", format(tt[["YES"]], big.mark = ","), pct(tt[["YES"]])),
    sprintf("| MAYBE | %s | %s | 02_stage2 |", format(tt[["MAYBE"]], big.mark = ","), pct(tt[["MAYBE"]])),
    sprintf("| NO | %s | %s | 03_stage3 |", format(tt[["NO"]], big.mark = ","), pct(tt[["NO"]])),
    "",
    sprintf("- candidate rows surfaced: %s (%.2f per query)",
            format(nrow(kc), big.mark = ","),
            if (nrow(frame)) nrow(kc) / nrow(frame) else 0),
    sprintf("- zero-candidate queries: %s",
            format(sum(frame$reason == "no_candidates"), big.mark = ",")), "",
    "Scored pairs and cascade results are in `interim/`. They are the only",
    "record of what blocking surfaced - do not delete them until 04_final is",
    "complete."
  ), np_project_path("01_stage1", "STAGE1-REPORT.md", project = project))

  say("stage 1 done in %.1f min: YES %s | MAYBE %s | NO %s", mins,
      format(tt[["YES"]], big.mark = ","), format(tt[["MAYBE"]], big.mark = ","),
      format(tt[["NO"]], big.mark = ","))
  np_project_status(project, write = TRUE, quiet = TRUE)
  invisible(frame)
}

# Columns an adjudicator reasons over. Everything else in the candidate frame is
# noise at the point of judgement.
.np_slim_cols <- c(
  "uei", "ein", "is_top_candidate", "num_of_candidates", "total_score",
  "name_similarity", "addr_similarity", "candidate_type", "match_layer", "pass",
  "match_decision", "decision_reason", "veto", "veto_reason", "veto_soft",
  "veto_soft_reason",
  "name_uss_raw_main", "name_uss_raw_dba", "name_uss_raw_division",
  "name_bmf_raw_main", "name_bmf_raw_dba", "name_bmf_raw_division",
  "street_similarity", "city_similarity", "zip_similarity",
  "street_uss", "street_bmf", "city_uss", "city_bmf",
  "state_uss", "state_bmf", "zip5_uss", "zip5_bmf", "bmf_active")

#' Run stage 2 - LLM adjudication of the MAYBE queue
#'
#' Resumable, because an adjudicator sits in the middle:
#'
#' * **First call** — reads `stage1_maybe` and `stage1_k_candidates`, writes
#'   shard files to `02_stage2/batches/slim/`, and stops. Point an agent at
#'   `02_stage2/PROMPT.md`; it writes one `decision-<shard>.csv` per shard to
#'   `02_stage2/batches/decisions/`.
#' * **Second call** — collects those decisions, collapses duplicate source
#'   registrations, and writes `stage2_yes` / `stage2_no`.
#'
#' Re-running after only some shards are adjudicated collects what is there and
#' reports which shards are still outstanding. An unreturned shard is a hole in
#' the results, not a set of NOs, so it is never silently treated as one.
#'
#' @param project Project root. Defaults to [np_project_root()].
#' @param shard_size Source ids per adjudication shard. Default 250.
#' @param columns Columns carried into the shard files. Defaults to the
#'   adjudication set; pass more to give the agent extra context.
#' @param verbose Print progress. Default `TRUE`.
#' @return Invisibly: the outcome frame once decisions exist, otherwise the
#'   manifest of shards written.
#' @seealso [np_stage1_run()], [np_merge_decisions()], [np_stage_schema()].
#' @export
np_stage2_run <- function(project = np_project_root(), shard_size = 250L,
                          columns = .np_slim_cols, verbose = TRUE) {
  say <- function(...) if (verbose) message(sprintf(...))
  if (is.na(project))
    stop("no active npmatch project; call np_project_init() or np_project_use().",
         call. = FALSE)
  run_id <- attr(np_project_status(project, write = FALSE, quiet = TRUE), "run_id")

  maybe_f <- np_project_path("01_stage1", "stage1_maybe.csv", project = project)
  cand_f  <- np_project_path("01_stage1", "stage1_k_candidates.csv", project = project)
  if (!file.exists(maybe_f))
    stop("stage 1 has not produced stage1_maybe.csv; run np_stage1_run() first.",
         call. = FALSE)
  maybe <- data.table::fread(maybe_f, colClasses = "character", showProgress = FALSE)
  slim_dir <- np_project_path("02_stage2", "batches/slim", create = TRUE, project = project)
  dec_dir  <- np_project_path("02_stage2", "batches/decisions", create = TRUE, project = project)

  # An empty MAYBE queue is a legitimate outcome -- stage 1 resolved everything --
  # not a failure. Write the empty outputs so the stage reads as complete and the
  # rollup has something to bind, rather than stopping the run.
  if (!nrow(maybe)) {
    .np_write_outcomes(.np_empty_outcomes(), "02_stage2", "stage2", project)
    writeLines(c(
      sprintf("# Stage 2 - %s", run_id), "",
      sprintf("_generated %s_", format(Sys.time(), "%Y-%m-%d %H:%M:%S")), "",
      "Stage 1 produced no MAYBE cases, so there was nothing to adjudicate.",
      "`stage2_yes.csv` and `stage2_no.csv` are written empty, with the standard",
      "schema, so the rollup can bind them unchanged."
    ), np_project_path("02_stage2", "STAGE2-REPORT.md", project = project))
    say("stage 2: no MAYBE cases; wrote empty outputs")
    np_project_status(project, write = TRUE, quiet = TRUE)
    return(invisible(.np_empty_outcomes()))
  }

  # --- prepare: write shards if none exist -----------------------------------
  shards <- sort(list.files(slim_dir, "^slim-.*[.]csv$", full.names = TRUE))
  if (!length(shards)) {
    if (!file.exists(cand_f))
      stop("stage1_k_candidates.csv not found; stage 2 needs the candidate frame.",
           call. = FALSE)
    cand <- data.table::fread(cand_f, colClasses = "character", showProgress = FALSE)
    cand <- cand[cand$uei %in% maybe$uei, , drop = FALSE]
    keep <- intersect(columns, names(cand))
    ids  <- unique(as.character(cand$uei))
    if (!length(ids))
      stop("no candidate rows for the MAYBE queue; nothing to adjudicate.", call. = FALSE)
    grp  <- ceiling(seq_along(ids) / shard_size)
    man  <- list()
    for (g in unique(grp)) {
      sub <- cand[as.character(cand$uei) %in% ids[grp == g], keep, with = FALSE]
      f   <- file.path(slim_dir, sprintf("slim-%02d.csv", g))
      data.table::fwrite(sub, f)
      man[[length(man) + 1L]] <- data.frame(
        shard = basename(f), n_uei = length(unique(sub$uei)), n_rows = nrow(sub),
        stringsAsFactors = FALSE)
    }
    man <- do.call(rbind, man)
    data.table::fwrite(man, np_project_path("02_stage2", "STAGE2-STATS.csv",
                                            project = project))
    say(paste0("stage 2 prepared: %d shard(s), %s source ids -> %s\n",
               "  next: point an agent at 02_stage2/PROMPT.md, then re-run np_stage2_run()"),
        nrow(man), format(length(ids), big.mark = ","), slim_dir)
    np_project_status(project, write = TRUE, quiet = TRUE)
    return(invisible(man))
  }

  # --- collect: fold decisions back ------------------------------------------
  dec_files <- sort(list.files(dec_dir, "^decision-.*[.]csv$", full.names = TRUE))
  if (!length(dec_files)) {
    say(paste0("stage 2: %d shard(s) awaiting adjudication in %s\n",
               "  follow 02_stage2/PROMPT.md, write decision-<shard>.csv to %s"),
        length(shards), slim_dir, dec_dir)
    return(invisible(NULL))
  }

  dec <- .np_as_decisions_df(dec_dir)
  co  <- .np_collapse_decisions(dec)
  d   <- co$dec

  # name lookup so the outcome rows carry both sides, as every other stage does
  cand <- data.table::fread(cand_f, colClasses = "character", showProgress = FALSE)
  lu   <- unique(cand[, c("uei", "ein", "name_uss_raw_main", "name_bmf_raw_main"),
                      with = FALSE])
  i_src <- match(d$uei, lu$uei)
  i_ref <- match(paste(d$uei, d$best_ein), paste(lu$uei, lu$ein))
  yes   <- d$llm_decision == "YES" & nzchar(d$best_ein)

  frame <- data.frame(
    uei            = d$uei,
    run_id         = run_id,
    stage          = "2",
    outcome        = ifelse(yes, "YES", "NO"),
    ein            = ifelse(yes, d$best_ein, ""),
    name_source    = ifelse(is.na(i_src), "", lu$name_uss_raw_main[i_src]),
    name_reference = ifelse(yes & !is.na(i_ref), lu$name_bmf_raw_main[i_ref], ""),
    score          = "",
    decided_by     = "llm_review",
    confidence     = d$llm_confidence,
    reason         = d$llm_reason,
    stringsAsFactors = FALSE)
  frame[is.na(frame)] <- ""
  .np_write_outcomes(frame, "02_stage2", "stage2", project)

  # --- reconciliation: an unreturned shard is a hole, not a set of NOs --------
  pending <- setdiff(as.character(maybe$uei), frame$uei)
  extra   <- setdiff(frame$uei, as.character(maybe$uei))
  tt <- table(factor(frame$outcome, c("YES", "NO")))
  cf <- table(factor(frame$confidence[frame$outcome == "YES"],
                     c("high", "medium", "low")))

  writeLines(c(
    sprintf("# Stage 2 - %s", run_id), "",
    sprintf("_generated %s_", format(Sys.time(), "%Y-%m-%d %H:%M:%S")), "",
    sprintf("- shards adjudicated: %d of %d", length(dec_files), length(shards)),
    sprintf("- decision rows: %s -> %s unique ids (%s duplicate registrations collapsed)",
            format(nrow(dec), big.mark = ","), format(nrow(d), big.mark = ","),
            format(nrow(dec) - nrow(d), big.mark = ",")),
    sprintf("- conflicting duplicates (kept best): %d", length(co$conflict)), "",
    "| outcome | n |", "|---|---|",
    sprintf("| YES | %s |", format(tt[["YES"]], big.mark = ",")),
    sprintf("| NO | %s |", format(tt[["NO"]], big.mark = ",")), "",
    sprintf("YES confidence: high %s, medium %s, low %s",
            cf[["high"]], cf[["medium"]], cf[["low"]]), "",
    "## Reconciliation", "",
    sprintf("- stage1_maybe ids: %s", format(nrow(maybe), big.mark = ",")),
    sprintf("- adjudicated: %s", format(nrow(frame), big.mark = ",")),
    if (length(pending))
      sprintf("- **%s id(s) NOT returned** - a hole in the results, not a NO. Re-run the missing shard(s).",
              format(length(pending), big.mark = ","))
    else "- all MAYBE ids accounted for",
    if (length(extra))
      sprintf("- %s adjudicated id(s) are not in stage1_maybe (check for shard drift)",
              format(length(extra), big.mark = ","))
    else NULL
  ), np_project_path("02_stage2", "STAGE2-REPORT.md", project = project))

  if (length(pending))
    warning(length(pending), " MAYBE id(s) were never adjudicated; they are ",
            "absent from stage2_yes/stage2_no rather than counted as NO. ",
            "See STAGE2-REPORT.md.", call. = FALSE)

  say("stage 2 done: YES %s | NO %s%s",
      format(tt[["YES"]], big.mark = ","), format(tt[["NO"]], big.mark = ","),
      if (length(pending)) sprintf(" | %d pending", length(pending)) else "")
  np_project_status(project, write = TRUE, quiet = TRUE)
  invisible(frame)
}
