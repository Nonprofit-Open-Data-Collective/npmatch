#' Summarise a cascade run as a report
#'
#' Assembles a human-readable report from an [np_cascade()] result: provenance
#' (version, config, inputs), the matching process (per-pass cascade table, how
#' many candidates were generated, how matches were formed), the outcome
#' (YES / MAYBE / NO with margins and vetoes), operations (timings, files
#' written), and a pointer to the review hand-off for the MAYBE queue.
#'
#' Most of the content is read straight off the result object —
#' `attr(res, "stages")` (the per-pass summary) and `attr(res, "pairs")` (the
#' scored candidate union) — so it works on any cascade result without a
#' labelled truth set. Supply `inputs`, `timings`, and `outputs` to record
#' provenance and operational context that the result object cannot know.
#'
#' @param res An `np_tiered` result from [np_cascade()] (carrying its `stages`,
#'   `pairs`, and `config` attributes).
#' @param inputs Optional data frame or named list describing the source files
#'   used (e.g. columns `file`, `vintage`, `rows`, `md5`). Rendered verbatim.
#' @param timings Optional named numeric vector of stage durations in seconds
#'   (e.g. `c(normalize = 610, cascade = 2900)`).
#' @param outputs Optional character vector of output file paths written.
#' @param reference Label for the reference used, e.g. `"unified (active+inactive)"`.
#' @param file Optional path to write the Markdown report to.
#' @param title Report title.
#' @return The Markdown report as a length-one character string (invisibly if
#'   `file` is given). A structured list of the computed pieces is attached as
#'   `attr(., "parts")`.
#' @export
np_run_report <- function(res, inputs = NULL, timings = NULL, outputs = NULL,
                          reference = NULL, file = NULL,
                          title = "npmatch run report") {
  cfg    <- attr(res, "config"); if (is.null(cfg)) cfg <- np_config()
  stages <- attr(res, "stages")
  pairs  <- attr(res, "pairs")
  R      <- as.data.frame(res)
  nq     <- nrow(R)
  tier   <- factor(as.character(R$tier), c("YES", "MAYBE", "NO"))
  tt     <- table(tier)

  fmt_int <- function(x) formatC(x, format = "d", big.mark = ",")
  pct     <- function(a, b) if (b > 0) sprintf("%.1f%%", 100 * a / b) else "n/a"
  L       <- character(0)
  add     <- function(...) L <<- c(L, sprintf(...))
  addv    <- function(v) L <<- c(L, v)          # append pre-built lines (e.g. tables)
  parts   <- list()

  ## ---- header / provenance ----
  add("# %s", title)
  add("")
  add("- **npmatch version:** %s", tryCatch(as.character(utils::packageVersion("npmatch")),
                                            error = function(e) "dev"))
  add("- **generated:** %s", as.character(Sys.time()))
  if (!is.null(reference)) add("- **reference:** %s", reference)
  add("- **source orgs considered:** %s", fmt_int(nq))
  th <- cfg$thresholds
  add("- **config:** method scoring; thresholds YES >= %.2f, MAYBE >= %.2f, min margin %.2f",
      th[["yes"]], th[["maybe"]], cfg$min_margin)
  if (!is.null(inputs)) {
    add(""); add("### Input files")
    add(""); addv(.np_md_table(as.data.frame(inputs)))
  }

  ## ---- matching process ----
  add(""); add("## Matching process")
  if (!is.null(stages)) {
    st <- as.data.frame(stages)
    parts$stages <- st
    add(""); add("Cascade passes (tight to loose):"); add("")
    addv(.np_md_table(st))
    add(""); add("- **total candidates generated:** %s (sum over passes)",
                 fmt_int(sum(st$candidates)))
  }
  if (!is.null(pairs)) {
    P <- as.data.frame(pairs)
    up   <- !duplicated(paste(P$.id, P$.ein))
    ncand <- sum(up)
    nqc  <- length(unique(P$.id))
    per  <- as.integer(table(P$.id[up]))
    parts$candidates <- list(unique_pairs = ncand, queries_with_candidates = nqc,
                             avg_per_query = ncand / max(nqc, 1), max_per_query = max(per))
    add("- **unique candidate pairs (deduped union):** %s", fmt_int(ncand))
    add("- **avg candidates per source org:** %.1f (max %s); %d of %d orgs got >=1 candidate",
        ncand / max(nqc, 1), fmt_int(max(per)), nqc, nq)

    ## how matches were formed: name variant + match type of each query's chosen pick
    mi <- match(paste(R$.id, R$overall_ein), paste(P$.id, P$.ein))
    yes_maybe <- tier %in% c("YES", "MAYBE")
    mt  <- P$name_match_type[mi][yes_maybe]
    vx  <- P$name_ver_x[mi][yes_maybe]; vy <- P$name_ver_y[mi][yes_maybe]
    if (any(!is.na(mt))) {
      parts$match_type <- table(match_type = mt, useNA = "no")
      add(""); add("How surfaced matches were formed (match type of the chosen pick):"); add("")
      addv(.np_md_table(as.data.frame(parts$match_type)))
    }
    if (any(!is.na(vx))) {
      cv <- table(source_name = vx, reference_name = vy)
      parts$name_version <- cv
      add(""); add("Name version used, source x reference (of the chosen pick):"); add("")
      addv(.np_md_table(cbind(source_name = rownames(cv), as.data.frame.matrix(cv))))
    }
    if (!is.null(P$veto)) {
      hard <- sum(P$veto[mi] %in% TRUE & yes_maybe, na.rm = TRUE)
      soft <- sum(P$veto_soft[mi] %in% TRUE & yes_maybe, na.rm = TRUE)
      add(""); add("- **vetoes on chosen picks:** %d hard, %d soft (soft caps at MAYBE)", hard, soft)
    }
  }

  ## ---- outcome ----
  add(""); add("## Outcome")
  add("")
  add("| Tier | Count | Share |")
  add("|---|---:|---:|")
  for (k in c("YES", "MAYBE", "NO"))
    add("| %s | %s | %s |", k, fmt_int(tt[[k]]), pct(tt[[k]], nq))
  add("| **Total** | **%s** | |", fmt_int(nq))
  parts$tiers <- tt
  if (!is.null(R$overall_margin)) {
    ym <- R$overall_margin[tier == "YES"]
    add(""); add("- **YES margin (runner-up gap):** median %.2f, min %.2f",
                 stats::median(ym, na.rm = TRUE), suppressWarnings(min(ym, na.rm = TRUE)))
  }
  add("- Treating YES as an accepted link: %s auto-accepted, %s routed to review, %s withheld.",
      fmt_int(tt[["YES"]]), fmt_int(tt[["MAYBE"]]), fmt_int(tt[["NO"]]))

  ## ---- operations ----
  if (!is.null(timings) || !is.null(outputs)) {
    add(""); add("## Operations")
    if (!is.null(timings)) {
      add("")
      for (nm in names(timings))
        add("- **%s:** %.1f min", nm, timings[[nm]] / 60)
      add("- **total:** %.1f min", sum(timings) / 60)
    }
    if (!is.null(outputs)) {
      add(""); add("Files written:")
      for (f in outputs) add("- `%s`", f)
    }
  }

  ## ---- next stage ----
  add(""); add("## Next stage — review hand-off")
  add("")
  add("The %s MAYBE cases are the review queue. Generate per-case LLM adjudication",
      fmt_int(tt[["MAYBE"]]))
  add("prompts with `np_as_prompts(np_route(res))`, or inspect one with")
  add("`np_as_prompt(routing, id)`. YES rows are auto-accepted; NO rows are withheld.")

  out <- paste(L, collapse = "\n")
  out <- structure(out, parts = parts)
  if (!is.null(file)) {
    writeLines(out, file)
    message("wrote run report: ", file)
    return(invisible(out))
  }
  out
}

## minimal Markdown table from a data frame (no external deps)
.np_md_table <- function(df) {
  df <- as.data.frame(df)
  if (!nrow(df)) return(character(0))
  cn <- names(df)
  body <- apply(df, 1, function(r) paste0("| ", paste(format(r, trim = TRUE), collapse = " | "), " |"))
  c(paste0("| ", paste(cn, collapse = " | "), " |"),
    paste0("|", paste(rep("---", length(cn)), collapse = "|"), "|"),
    body)
}
