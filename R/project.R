# ---------------------------------------------------------------------------
# Per-run project scaffolding.
#
# np_data_* (R/assets.R) manages the SHARED asset store: reference vintages and
# the expensive derived tables, built once and reused by every run. This file
# manages the PER-RUN project: one directory per matching run, holding that
# run's inputs, stage outputs, reports and logs.
#
# The two are joined by pointers, not copies. A run records which BMF vintage it
# used (00_bmf/SOURCE.md) rather than duplicating 3.5 GB of it.
# ---------------------------------------------------------------------------

# Canonical stage layout. `outputs` are the query-level / rollup deliverables a
# stage is expected to produce; np_project_status() scans for exactly these to
# decide whether a stage has run.
.np_layout <- list(
  `00_bmf` = list(
    subdirs = "logs",
    outputs = c("SOURCE.md", "SIGNATURE.txt"),
    title   = "Reference (BMF) pointer",
    prompt  = FALSE),
  `00_sams` = list(
    subdirs = c("raw", "interim", "logs"),
    outputs = "sam_query.csv",
    title   = "Source (SAM) extract + nonprofit filter",
    prompt  = FALSE),
  `01_stage1` = list(
    subdirs = c("batches", "batches/shards", "interim", "logs"),
    outputs = c("stage1_yes.csv", "stage1_maybe.csv", "stage1_no.csv",
                "stage1_k_candidates.csv"),
    title   = "Stage 1 - probabilistic cascade",
    prompt  = FALSE),
  `02_stage2` = list(
    subdirs = c("batches", "batches/slim", "batches/decisions", "interim", "logs"),
    outputs = c("stage2_yes.csv", "stage2_no.csv"),
    title   = "Stage 2 - LLM adjudication of MAYBE",
    prompt  = TRUE),
  `03_stage3` = list(
    subdirs = c("batches", "batches/packets", "batches/out",
                "interim", "interim/cache", "logs"),
    outputs = c("stage3_yes.csv", "stage3_no.csv", "stage3_research_findings.csv"),
    title   = "Stage 3 - LLM research of NO",
    prompt  = TRUE),
  `04_final` = list(
    subdirs = c("interim", "logs"),
    outputs = c("crosswalk.csv", "eval_frame.csv"),
    title   = "Final rollup",
    prompt  = FALSE)
)

# Short aliases so np_project_path("stage1") works as well as "01_stage1".
.np_stage_alias <- c(
  bmf = "00_bmf", sams = "00_sams", sam = "00_sams",
  stage1 = "01_stage1", stage2 = "02_stage2", stage3 = "03_stage3",
  final = "04_final",
  `1` = "01_stage1", `2` = "02_stage2", `3` = "03_stage3")

.np_stage_dir <- function(stage) {
  s <- as.character(stage)[1]
  if (s %in% names(.np_layout)) return(s)
  i <- match(s, names(.np_stage_alias))          # [[ ]] errors on an absent name
  if (!is.na(i)) return(unname(.np_stage_alias[i]))
  stop("unknown stage '", s, "'. Use one of: ",
       paste(names(.np_layout), collapse = ", "), call. = FALSE)
}

#' The shared outcome schema
#'
#' Every `stage*_yes` / `stage*_maybe` / `stage*_no` file carries these columns,
#' in this order, with exactly one row per source id. Identical columns across
#' every stage is what makes the rollup a plain `rbind()`.
#'
#' Candidate-level and stage-specific detail lives in side tables joined by
#' `uei` — `stage1_k_candidates.csv` (one row per surfaced candidate) and
#' `stage3_research_findings.csv` (the full research record).
#'
#' @return A character vector of column names.
#' @seealso [np_project_init()] for the directory layout these files live in.
#' @examples
#' np_stage_schema()
#' @export
np_stage_schema <- function() {
  c("uei", "run_id", "stage", "outcome", "ein", "name_source", "name_reference",
    "score", "decided_by", "confidence", "reason")
}

#' Locate the active npmatch project
#'
#' Resolved from `getOption("npmatch.project")`, then the `NPMATCH_PROJECT`
#' environment variable. [np_project_init()] and [np_project_use()] set the
#' option, so the fetch helpers and stage functions can default their paths into
#' the run directory without the caller repeating it.
#'
#' @return The project root path, or `NA_character_` when none is active.
#' @seealso [np_project_use()] to point the session at an existing run.
#' @examples
#' old <- options(npmatch.project = tempdir())
#' np_project_root()
#' options(old)
#' @export
np_project_root <- function() {
  r <- getOption("npmatch.project")
  if (is.null(r) || !nzchar(r)) r <- Sys.getenv("NPMATCH_PROJECT", "")
  if (!nzchar(r)) return(NA_character_)
  r
}

#' Build a path inside the active project
#'
#' @param stage Stage directory: a canonical name (`"01_stage1"`), a short alias
#'   (`"stage1"`, `"bmf"`, `"final"`), or `""` for the project root.
#' @param file Optional path below the stage directory, e.g. `"stage1_yes.csv"`
#'   or `"batches/shards"`.
#' @param create Create the directory (of `stage`, or of `file`'s parent) if it
#'   does not exist. Default `FALSE`.
#' @param project Project root. Defaults to [np_project_root()].
#' @return A path string.
#' @seealso [np_project_init()], [np_project_use()].
#' @examples
#' old <- options(npmatch.project = "P:/runs/2026MAY")
#' np_project_path("stage1", "stage1_yes.csv")
#' np_project_path("03_stage3", "batches/packets")
#' options(old)
#' @export
np_project_path <- function(stage = "", file = NULL, create = FALSE,
                            project = np_project_root()) {
  if (is.na(project))
    stop("no active npmatch project; call np_project_init() or np_project_use().",
         call. = FALSE)
  p <- if (nzchar(as.character(stage)[1])) file.path(project, .np_stage_dir(stage)) else project
  if (!is.null(file)) p <- file.path(p, file)
  if (create) {
    d <- if (is.null(file)) p else dirname(p)
    if (!dir.exists(d)) dir.create(d, recursive = TRUE, showWarnings = FALSE)
  }
  p
}

#' Point the session at an existing project
#'
#' @param path An existing project root created by [np_project_init()].
#' @param quiet Suppress the confirmation message. Default `FALSE`.
#' @return The path, invisibly.
#' @seealso [np_project_init()], [np_project_status()].
#' @examples
#' \dontrun{
#' np_project_use("runs/2026MAY")
#' }
#' @export
np_project_use <- function(path, quiet = FALSE) {
  if (!dir.exists(path))
    stop("project directory not found: ", path, call. = FALSE)
  missing <- names(.np_layout)[!dir.exists(file.path(path, names(.np_layout)))]
  if (length(missing))
    warning("not a complete npmatch project; missing: ",
            paste(missing, collapse = ", "), call. = FALSE)
  options(npmatch.project = path)
  if (!quiet) message("npmatch project: ", path)
  invisible(path)
}

# Fill {{placeholders}} in a template string. fixed = TRUE is required, not a
# style choice: values are often Windows paths, and a regex replacement treats
# their backslashes as escapes -- "C:\Users\x" silently becomes "C:sersx".
.np_fill <- function(txt, vals) {
  for (k in names(vals))
    txt <- gsub(paste0("{{", k, "}}"), vals[[k]], txt, fixed = TRUE)
  txt
}

# Read a template from inst/templates/, or return NULL when absent (so the
# package still scaffolds if a template file is missing).
.np_template <- function(name) {
  f <- system.file("templates", name, package = "npmatch")
  if (!nzchar(f) || !file.exists(f)) return(NULL)
  paste(readLines(f, warn = FALSE), collapse = "\n")
}

.np_write_template <- function(name, dest, vals, overwrite = FALSE) {
  if (file.exists(dest) && !overwrite) return(FALSE)
  txt <- .np_template(name)
  if (is.null(txt)) return(FALSE)
  writeLines(.np_fill(txt, vals), dest)
  TRUE
}

#' Create a run project directory
#'
#' Scaffolds one directory per matching run: numbered stage folders, each with
#' `batches/`, `interim/` and `logs/` subdirectories, a `README.md` explaining
#' what the stage does, and (for the LLM stages) a `PROMPT.md` holding the agent
#' instructions. Writes a `config.yml`, an empty `manifest.csv`, an `AGENTS.md`
#' describing how to orchestrate the whole run, and a first `RUN-STATUS.md`.
#'
#' All six stage folders are created unconditionally. Deploying a stage is
#' optional — one that never runs simply leaves its outputs absent, which
#' [np_project_status()] reports as *not run* rather than as an error.
#'
#' @section Reference data is pointed at, not copied:
#' The BMF is ~3.5 GB raw plus a ~470 MB normalized bundle, and is reused across
#' runs. `00_bmf/` therefore holds only `SOURCE.md` (vintage, resolved path in
#' the shared store, checksum, row count) and `SIGNATURE.txt` (the
#' [np_normalize_signature()] hash of the cached artifact, so drift is
#' detectable). The bytes stay in the [np_data_path()] store. SAM is genuinely
#' per-run, so `00_sams/raw/` holds the real extract — paste one in, or let
#' [np_fetch_sam()] download into it.
#'
#' @param path Directory to create for this run.
#' @param run_id Short run label recorded in reports and in the `run_id` column
#'   of every stage output. Defaults to `basename(path)`.
#' @param bmf Optional path to (or vintage tag of) the reference used by this
#'   run, recorded in `00_bmf/SOURCE.md`. `NULL` leaves a placeholder.
#' @param sam Optional path to a SAM extract to record in `00_sams/README.md`.
#'   The file is not copied.
#' @param config An [np_config()] whose thresholds and weights are serialized to
#'   `config.yml`.
#' @param templates Write the README / PROMPT / AGENTS documents. Default `TRUE`.
#' @param use Set this project as the session default. Default `TRUE`.
#' @param overwrite Overwrite existing template documents. Directories and data
#'   files are never removed. Default `FALSE`.
#' @param quiet Suppress the summary message. Default `FALSE`.
#' @return The project root, invisibly.
#' @seealso [np_project_status()] for the run status report, [np_project_path()]
#'   for addressing files inside it, [np_data_init()] for the shared asset store.
#' @examples
#' p <- file.path(tempdir(), "run-demo")
#' np_project_init(p, run_id = "demo", quiet = TRUE, use = FALSE)
#' list.files(p)
#' unlink(p, recursive = TRUE)
#' @export
np_project_init <- function(path, run_id = NULL, bmf = NULL, sam = NULL,
                            config = np_config(), templates = TRUE,
                            use = TRUE, overwrite = FALSE, quiet = FALSE) {
  if (missing(path) || !is.character(path) || length(path) != 1L || !nzchar(path))
    stop("`path` must be a single non-empty directory path.", call. = FALSE)
  if (is.null(run_id)) run_id <- basename(normalizePath(path, mustWork = FALSE))
  run_id <- as.character(run_id)[1]

  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  for (st in names(.np_layout)) {
    dir.create(file.path(path, st), recursive = TRUE, showWarnings = FALSE)
    for (sd in .np_layout[[st]]$subdirs)
      dir.create(file.path(path, st, sd), recursive = TRUE, showWarnings = FALSE)
  }

  vals <- list(run_id = run_id,
               date = format(Sys.Date()),
               bmf = if (is.null(bmf)) "(not yet recorded)" else as.character(bmf)[1],
               sam = if (is.null(sam)) "(not yet recorded)" else as.character(sam)[1],
               schema = paste(np_stage_schema(), collapse = ", "))

  if (isTRUE(templates)) {
    .np_write_template("README-project.md", file.path(path, "README.md"), vals, overwrite)
    .np_write_template("AGENTS.md",         file.path(path, "AGENTS.md"),  vals, overwrite)
    for (st in names(.np_layout)) {
      .np_write_template(sprintf("README-%s.md", st),
                         file.path(path, st, "README.md"), vals, overwrite)
      if (isTRUE(.np_layout[[st]]$prompt))
        .np_write_template(sprintf("PROMPT-%s.md", st),
                           file.path(path, st, "PROMPT.md"), vals, overwrite)
    }
  }

  # config.yml -- flat key: value, readable without a YAML dependency.
  cfg_file <- file.path(path, "config.yml")
  if (!file.exists(cfg_file) || overwrite) {
    th <- config$thresholds
    writeLines(c(
      sprintf("run_id: %s", run_id),
      sprintf("created: %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
      sprintf("npmatch_version: %s",
              tryCatch(as.character(utils::packageVersion("npmatch")),
                       error = function(e) "unknown")),
      "",
      "# stage 1 tiering",
      sprintf("threshold_yes: %s",   if (is.null(th)) "" else th[["yes"]]),
      sprintf("threshold_maybe: %s", if (is.null(th)) "" else th[["maybe"]]),
      sprintf("min_margin: %s",      if (is.null(config$min_margin)) "" else config$min_margin),
      "",
      "# batching",
      "compute_size: 2500",
      "review_size: 250",
      "k_candidates: 3",
      "seed: 1",
      "",
      "# inputs (paths recorded, not copied)",
      sprintf("bmf: %s", vals$bmf),
      sprintf("sam: %s", vals$sam)
    ), cfg_file)
  }

  man <- file.path(path, "manifest.csv")
  if (!file.exists(man) || overwrite)
    utils::write.csv(
      data.frame(asset = character(), stage = character(), kind = character(),
                 path = character(), created = character(), md5 = character(),
                 row_count = integer(), note = character(),
                 stringsAsFactors = FALSE),
      man, row.names = FALSE)

  if (!is.null(bmf)) {
    src <- file.path(path, "00_bmf", "SOURCE.md")
    if (!file.exists(src) || overwrite)
      writeLines(c(
        sprintf("# Reference source - run %s", run_id),
        "",
        sprintf("- path: `%s`", vals$bmf),
        sprintf("- recorded: %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
        "- md5: (run np_manifest_add() to fill)",
        "- row_count: (run np_manifest_add() to fill)",
        "",
        "The bytes live in the shared asset store; this run points at them.",
        "See SIGNATURE.txt for the np_normalize_signature() hash of the cached",
        "normalized bundle -- if it stops matching, the cache has drifted from",
        "the current normalization code and must be rebuilt."
      ), src)
  }

  if (isTRUE(use)) options(npmatch.project = path)
  np_project_status(path, write = TRUE, quiet = TRUE)

  if (!quiet)
    message(sprintf("npmatch project '%s' at %s\n  %s\n  next: add a SAM extract to 00_sams/raw/",
                    run_id, path, paste(names(.np_layout), collapse = "  ")))
  invisible(path)
}

# Cheap row count: read a single column with fread when available, else count
# lines. NA on failure rather than an error -- status must never break a run.
.np_rows <- function(f) {
  if (!file.exists(f)) return(NA_integer_)
  if (grepl("[.]csv$|[.]tsv$", f, ignore.case = TRUE)) {
    n <- tryCatch(nrow(data.table::fread(f, select = 1L, showProgress = FALSE)),
                  error = function(e) NA_integer_)
    return(as.integer(n))
  }
  NA_integer_
}

.np_fmt <- function(x) {
  out <- rep("-", length(x))
  ok <- !is.na(x)
  out[ok] <- formatC(as.integer(x[ok]), format = "d", big.mark = ",")
  out
}

#' Report the status of a run project
#'
#' Scans the project directory and reports, per stage, whether it has run and
#' what it produced. This is a **scanner, not a ledger**: it reads what is on
#' disk every time, so it cannot drift out of sync with reality the way a stored
#' state file would. Deleting an output makes the stage report as incomplete on
#' the next call.
#'
#' A stage is `complete` when every expected output in the layout is present,
#' `partial` when some are, and `not run` when none are.
#'
#' @param project Project root. Defaults to [np_project_root()].
#' @param write Write `RUN-STATUS.md` at the project root. Default `TRUE`.
#' @param quiet Suppress the printed summary. Default `FALSE`.
#' @return A data frame with one row per expected output (`stage`, `file`,
#'   `exists`, `rows`, `modified`), invisibly. The per-stage roll-up is carried
#'   in the `stages` attribute.
#' @seealso [np_project_init()].
#' @examples
#' p <- file.path(tempdir(), "run-status-demo")
#' np_project_init(p, run_id = "demo", quiet = TRUE, use = FALSE)
#' s <- np_project_status(p, write = FALSE, quiet = TRUE)
#' attr(s, "stages")[, c("stage", "status")]
#' unlink(p, recursive = TRUE)
#' @export
np_project_status <- function(project = np_project_root(), write = TRUE,
                              quiet = FALSE) {
  if (is.na(project))
    stop("no active npmatch project; call np_project_init() or np_project_use().",
         call. = FALSE)
  if (!dir.exists(project))
    stop("project directory not found: ", project, call. = FALSE)

  rows <- do.call(rbind, lapply(names(.np_layout), function(st) {
    outs <- .np_layout[[st]]$outputs
    do.call(rbind, lapply(outs, function(o) {
      f <- file.path(project, st, o)
      ok <- file.exists(f)
      data.frame(stage = st, file = o, exists = ok,
                 rows = if (ok) .np_rows(f) else NA_integer_,
                 modified = if (ok)
                   format(file.info(f)$mtime, "%Y-%m-%d %H:%M") else NA_character_,
                 stringsAsFactors = FALSE)
    }))
  }))

  stages <- do.call(rbind, lapply(names(.np_layout), function(st) {
    r <- rows[rows$stage == st, , drop = FALSE]
    n <- sum(r$exists); tot <- nrow(r)
    data.frame(
      stage = st, title = .np_layout[[st]]$title,
      status = if (n == 0L) "not run" else if (n < tot) "partial" else "complete",
      present = n, expected = tot,
      last_write = if (n) max(r$modified, na.rm = TRUE) else NA_character_,
      stringsAsFactors = FALSE)
  }))

  # batch / log counts give a sense of work in flight even before outputs land
  counts <- vapply(names(.np_layout), function(st) {
    b <- file.path(project, st, "batches")
    l <- file.path(project, st, "logs")
    sprintf("%d batch file(s), %d log file(s)",
            if (dir.exists(b)) length(list.files(b, recursive = TRUE)) else 0L,
            if (dir.exists(l)) length(list.files(l, recursive = TRUE)) else 0L)
  }, character(1))
  stages$activity <- unname(counts)

  cfg <- file.path(project, "config.yml")
  run_id <- if (file.exists(cfg)) {
    ln <- grep("^run_id:", readLines(cfg, warn = FALSE), value = TRUE)
    if (length(ln)) trimws(sub("^run_id:", "", ln[1])) else basename(project)
  } else basename(project)

  if (isTRUE(write)) {
    mark <- c(`not run` = "[ ]", partial = "[~]", complete = "[x]")
    tbl <- c(
      "| stage | what | status | outputs | last write | activity |",
      "|---|---|---|---|---|---|",
      sprintf("| %s | %s | %s %s | %d/%d | %s | %s |",
              stages$stage, stages$title, mark[stages$status], stages$status,
              stages$present, stages$expected,
              ifelse(is.na(stages$last_write), "-", stages$last_write),
              stages$activity))
    det <- c(
      "| stage | file | rows | modified |",
      "|---|---|---|---|",
      sprintf("| %s | `%s` | %s | %s |", rows$stage, rows$file,
              ifelse(rows$exists, .np_fmt(rows$rows), "missing"),
              ifelse(is.na(rows$modified), "-", rows$modified)))
    writeLines(c(
      sprintf("# Run %s - status", run_id), "",
      sprintf("_generated %s_", format(Sys.time(), "%Y-%m-%d %H:%M:%S")), "",
      "## Stages", "", tbl, "",
      "## Outputs", "", det, "",
      "## Notes", "",
      "- Regenerate with `np_project_status()`. This report is a scan of the",
      "  directory, not a stored record: it always reflects what is on disk.",
      sprintf("- Shared outcome schema: `%s`", paste(np_stage_schema(), collapse = ", "))
    ), file.path(project, "RUN-STATUS.md"))
  }

  if (!quiet) {
    message(sprintf("npmatch run '%s' - %s", run_id, project))
    for (i in seq_len(nrow(stages)))
      message(sprintf("  %-11s %-9s %d/%d outputs", stages$stage[i],
                      stages$status[i], stages$present[i], stages$expected[i]))
  }
  attr(rows, "stages") <- stages
  attr(rows, "run_id") <- run_id
  invisible(rows)
}
