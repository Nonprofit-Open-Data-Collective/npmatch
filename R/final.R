# ---------------------------------------------------------------------------
# Final rollup. Binds the per-stage outcome files into the two deliverables and
# reports the end-to-end funnel. Generated, never authored: everything here is
# rebuilt from the stage outputs.
# ---------------------------------------------------------------------------

# EINs are written with or without a dash depending on source; compare on digits.
.np_ein_digits <- function(x) {
  d <- gsub("[^0-9]", "", as.character(x))
  d[is.na(d)] <- ""
  d
}

# Read a stage outcome file, or an empty frame in the shared schema when absent.
.np_read_outcomes <- function(stage_dir, file, project) {
  f <- np_project_path(stage_dir, file, project = project)
  if (!file.exists(f)) return(.np_empty_outcomes())
  d <- as.data.frame(data.table::fread(f, colClasses = "character",
                                       showProgress = FALSE))
  if (!nrow(d)) return(.np_empty_outcomes())
  for (cl in setdiff(np_stage_schema(), names(d))) d[[cl]] <- ""
  d[, np_stage_schema(), drop = FALSE]
}

#' Roll the stages up into the final deliverables
#'
#' Binds the per-stage outcome files into the two artifacts the run exists to
#' produce, and reports the end-to-end funnel.
#'
#' * **`crosswalk.csv`** — every matched source id, one row each, carrying
#'   `decided_by` so a consumer can tell an auto-accepted stage-1 match from one
#'   an adjudicator or a web search produced. This is the only place the word
#'   "crosswalk" is used; elsewhere the linked pairs are `matches`.
#' * **`eval_frame.csv`** — the candidate-level frame: every candidate stage 1
#'   surfaced, annotated with the final answer for its source id. Every source
#'   id has at least one row; one with no candidates gets a single row with
#'   `candidate_source = "none"`.
#'
#' `final_outcome` is `"MATCH"` exactly for the ids in the crosswalk. An
#' unmatched id takes `final_stage`, `final_basis`, `final_confidence` and
#' `final_reason` from the last stage that decided it and has no `final_ein`: a
#' MAYBE candidate rejected downstream is not an answer.
#'
#' @section Answers found outside the candidate set:
#' Stage 3 recovers matches the matcher never surfaced, so the final EIN for a
#' source id is often absent from `stage1_k_candidates`. Those are **not**
#' dropped: a synthetic row is emitted carrying the final EIN with its
#' similarity columns empty and `candidate_source = "stage3_research"`, and
#' `final_ein_in_candset` records which case each row is.
#'
#' That flag splits recall loss in two. A match whose EIN was never in the
#' candidate set is a **blocking** failure — no threshold change recovers it. One
#' that was surfaced but scored below the floor is a **scoring** failure, and is
#' recoverable by recalibration. Collapsing them would hide the only number that
#' says which of the two to work on.
#'
#' @param project Project root. Defaults to [np_project_root()].
#' @param precedence Order in which stages win when one source id is matched by
#'   more than one (a duplicate registration can be matched in two stages).
#'   Default `c("1", "2", "3")` — the earliest, most automatic match wins.
#' @param verbose Print progress. Default `TRUE`.
#' @return The crosswalk, invisibly.
#' @seealso [np_stage1_run()], [np_stage2_run()], [np_stage3_run()].
#' @export
np_final_run <- function(project = np_project_root(),
                         precedence = c("1", "2", "3"), verbose = TRUE) {
  say <- function(...) if (verbose) message(sprintf(...))
  if (is.na(project))
    stop("no active npmatch project; call np_project_init() or np_project_use().",
         call. = FALSE)
  run_id <- attr(np_project_status(project, write = FALSE, quiet = TRUE), "run_id")

  src <- list(c("01_stage1", "stage1_yes.csv"),   c("01_stage1", "stage1_maybe.csv"),
              c("01_stage1", "stage1_no.csv"),    c("02_stage2", "stage2_yes.csv"),
              c("02_stage2", "stage2_no.csv"),    c("03_stage3", "stage3_yes.csv"),
              c("03_stage3", "stage3_no.csv"))
  all_out <- do.call(rbind, lapply(src, function(s)
    .np_read_outcomes(s[1], s[2], project)))
  if (!nrow(all_out))
    stop("no stage outputs found; run np_stage1_run() first.", call. = FALSE)

  # --- crosswalk: every matched id, earliest stage wins -----------------------
  yes <- all_out[all_out$outcome == "YES" & nzchar(all_out$ein), , drop = FALSE]
  ord <- match(yes$stage, precedence); ord[is.na(ord)] <- length(precedence) + 1L
  yes <- yes[order(ord), , drop = FALSE]
  n_dup <- sum(duplicated(yes$uei))
  xw <- yes[!duplicated(yes$uei), , drop = FALSE]
  rownames(xw) <- NULL
  data.table::fwrite(xw, np_project_path("04_final", "crosswalk.csv", project = project))

  # --- one row per source id: the final answer, matched or not ---------------
  # Matched is crosswalk membership, nothing else: a stage-1 MAYBE carries its
  # candidate EIN, so a non-empty `ein` does not mean the id was matched. An
  # unmatched id takes its final fields from the last stage that decided it
  # (stage 3 when it ran), and has no final EIN.
  rest <- all_out[!(all_out$uei %in% xw$uei), , drop = FALSE]
  st   <- suppressWarnings(as.integer(rest$stage)); st[is.na(st)] <- 0L
  rest <- rest[order(-st, -seq_len(nrow(rest))), , drop = FALSE]
  rest <- rest[!duplicated(rest$uei), , drop = FALSE]
  rest$ein <- rep("", nrow(rest))
  final   <- rbind(xw, rest)
  matched <- final$uei %in% xw$uei
  fin <- data.frame(
    uei              = final$uei,
    final_ein        = final$ein,
    final_outcome    = ifelse(matched, "MATCH", "NO_MATCH"),
    final_basis      = final$decided_by,
    final_stage      = final$stage,
    final_confidence = final$confidence,
    final_reason     = final$reason,
    stringsAsFactors = FALSE)

  # --- evaluation frame: candidates annotated with the final answer -----------
  cand_f <- np_project_path("01_stage1", "stage1_k_candidates.csv", project = project)
  cand <- if (file.exists(cand_f))
    as.data.frame(data.table::fread(cand_f, colClasses = "character",
                                    showProgress = FALSE))
  else data.frame()

  if (nrow(cand) && "uei" %in% names(cand)) {
    ev <- merge(cand, fin, by = "uei", all.x = TRUE, sort = FALSE)
    for (cl in names(fin)[-1]) ev[[cl]][is.na(ev[[cl]])] <- ""
    ev$candidate_source <- "cascade"
    ev$is_final_ein <- as.integer(
      nzchar(ev$final_ein) &
        .np_ein_digits(ev[[if ("ein" %in% names(ev)) "ein" else "uei"]]) ==
        .np_ein_digits(ev$final_ein))
    ev$final_ein_in_candset <- stats::ave(ev$is_final_ein, ev$uei,
                                          FUN = function(v) as.integer(any(v == 1L)))
  } else {
    ev <- cbind(data.frame(uei = character(), ein = character(),
                           stringsAsFactors = FALSE),
                fin[0, -1, drop = FALSE],
                data.frame(candidate_source = character(), is_final_ein = integer(),
                           final_ein_in_candset = integer(), stringsAsFactors = FALSE))
  }

  # A row for a source id the candidate file cannot show: similarity columns
  # empty, the final answer filled in.
  synth <- function(ids, source, ein) {
    syn <- fin[match(ids, fin$uei), , drop = FALSE]
    add <- ev[rep(NA_integer_, length(ids)), , drop = FALSE]
    add[] <- lapply(add, function(x) rep(NA, length(ids)))
    add$uei <- syn$uei
    if ("ein" %in% names(add)) add$ein <- ein
    for (cl in names(fin)[-1]) add[[cl]] <- syn[[cl]]
    add$candidate_source     <- source
    add$is_final_ein         <- as.integer(nzchar(ein))
    add$final_ein_in_candset <- 0L
    add
  }

  # matched ids whose answer the cascade never surfaced get a synthetic row --
  # dropping them would hide exactly the cases the frame exists to measure
  surfaced <- if (nrow(ev)) unique(ev$uei[ev$final_ein_in_candset == 1L]) else character(0)
  missed   <- setdiff(fin$uei[nzchar(fin$final_ein)], surfaced)
  if (length(missed))
    ev <- rbind(ev, synth(missed, "stage3_research",
                          fin$final_ein[match(missed, fin$uei)]))
  # ids with no candidates at all still get a row, so the frame covers every id
  none <- setdiff(fin$uei, ev$uei)
  if (length(none))
    ev <- rbind(ev, synth(none, "none", rep("", length(none))))
  rownames(ev) <- NULL
  data.table::fwrite(ev, np_project_path("04_final", "eval_frame.csv", project = project))

  # --- funnel ----------------------------------------------------------------
  by_stage <- table(factor(xw$stage, precedence))
  n_all    <- length(unique(all_out$uei))
  data.table::fwrite(
    data.frame(metric = c("source_ids", "matched", "unmatched",
                          paste0("matched_stage_", precedence),
                          "candidate_rows", "answers_outside_candidate_set",
                          "source_ids_without_candidates"),
               value = c(n_all, nrow(xw), n_all - nrow(xw), as.integer(by_stage),
                         nrow(ev), length(missed), length(none)),
               stringsAsFactors = FALSE),
    np_project_path("04_final", "FINAL-STATS.csv", project = project))

  pc <- function(a) if (n_all) sprintf("%.1f%%", 100 * a / n_all) else "n/a"
  writeLines(c(
    sprintf("# Final rollup - %s", run_id), "",
    sprintf("_generated %s_", format(Sys.time(), "%Y-%m-%d %H:%M:%S")), "",
    "## Funnel", "",
    sprintf("- source ids: %s", format(n_all, big.mark = ",")),
    sprintf("- matched: %s (%s)", format(nrow(xw), big.mark = ","), pc(nrow(xw))),
    sprintf("- unmatched: %s (%s)", format(n_all - nrow(xw), big.mark = ","),
            pc(n_all - nrow(xw))), "",
    "| matched by | n | share of source |", "|---|---|---|",
    sprintf("| stage %s | %s | %s |", precedence,
            format(as.integer(by_stage), big.mark = ","), pc(as.integer(by_stage))),
    "", "## Candidate coverage", "",
    sprintf("- candidate rows: %s", format(nrow(ev), big.mark = ",")),
    sprintf("- source ids with no candidates: %s", format(length(none), big.mark = ",")),
    sprintf("- answers the cascade never surfaced: %s%s",
            format(length(missed), big.mark = ","),
            if (nrow(xw)) sprintf(" (%.1f%% of matches)",
                                  100 * length(missed) / nrow(xw)) else ""),
    "",
    "A match whose EIN was never in the candidate set is a **blocking** failure -",
    "no threshold change recovers it. One that was surfaced but scored below the",
    "floor is a **scoring** failure, recoverable by recalibration.",
    "`final_ein_in_candset` separates them.",
    if (n_dup)
      c("", sprintf("_%d source id(s) matched in more than one stage; the earliest won._",
                    n_dup))
    else NULL
  ), np_project_path("04_final", "FINAL-REPORT.md", project = project))

  say("final: %s matched of %s (%s) | %s answer(s) outside the candidate set",
      format(nrow(xw), big.mark = ","), format(n_all, big.mark = ","),
      pc(nrow(xw)), format(length(missed), big.mark = ","))
  np_project_status(project, write = TRUE, quiet = TRUE)
  invisible(xw)
}
