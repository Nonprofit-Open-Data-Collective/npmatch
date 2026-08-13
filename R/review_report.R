#' Render a review frame as a static HTML report
#'
#' Turns the `review` queue from [np_route()] into a self-contained HTML report
#' for human review: one section per source entity (UEI), each candidate laid out
#' as a side-by-side "matching form" (id, name, nonprofit type, age, size,
#' affiliate, address, point of contact, and the match-score block). Candidates
#' are ordered with the pipeline's selected pick first, then by descending
#' `total_score`.
#'
#' The report is read-only. If the frame also carries evaluation columns
#' (`is_gt_ein`, `gt_confidence`, `gt_outcome_class`, `labeled_by`) — as produced
#' by the benchmarking harness — the ground-truth candidate is highlighted and
#' floated to the top of its section, and UEIs whose true EIN is missing from the
#' candidate set are flagged. On an ordinary [np_route()] frame those columns are
#' simply absent and the report renders without them.
#'
#' Rendering requires the \pkg{quarto} package and a Quarto CLI installation (the
#' same dependency the vignettes use). The bundled template lives at
#' `system.file("report", "match-review-report.qmd", package = "npmatch")`.
#'
#' @param x One of: an `np_routing` object from [np_route()] (its `review`
#'   element is used); an `np_review` frame or plain data frame in the review
#'   schema; or a path to a CSV of one.
#' @param output Path for the HTML file to write. Default
#'   `"match-review-report.html"` in the working directory. A `.html` extension
#'   is added if missing.
#' @param decision Which `match_decision` tiers to include: `"ALL"`, `"YES"`,
#'   `"NO"`, or `"MAYBE"` (comma-separate to combine, e.g. `"MAYBE,NO"`).
#'   Default `"MAYBE"` — the human-review hand-off queue.
#' @param max_ueis Cap on the number of UEI sections rendered; `0` or `NA` means
#'   no cap. When the pool is larger than `max_ueis`, a deterministic random
#'   sample (see `seed`) is drawn. Default `0`.
#' @param only_missing_gt Logical; when the frame carries ground-truth columns,
#'   restrict to UEIs whose ground-truth EIN is not among the candidates
#'   (recall misses). Ignored on frames without ground truth. Default `FALSE`.
#' @param seed Sampling seed used when `max_ueis` truncates the pool. Default 42.
#' @param quiet Suppress Quarto's rendering progress output. Default `TRUE`.
#' @return The path to the written HTML file, invisibly.
#' @seealso [np_route()] for producing the review frame; [np_run_report()] for a
#'   Markdown run summary.
#' @examples
#' \dontrun{
#' res     <- np_cascade(query, reference)
#' routing <- np_route(res, bmf = bmf_raw, sam = sam_raw)
#' np_review_report(routing, output = "review.html")
#'
#' # just the recall misses on a labelled evaluation frame
#' np_review_report("EVAL-FRAME-MERGED.csv", decision = "ALL",
#'                  only_missing_gt = TRUE, output = "misses.html")
#' }
#' @export
np_review_report <- function(x, output = "match-review-report.html",
                             decision = "MAYBE", max_ueis = 0,
                             only_missing_gt = FALSE, seed = 42, quiet = TRUE) {
  if (!requireNamespace("quarto", quietly = TRUE))
    stop("np_review_report() needs the 'quarto' package and a Quarto CLI ",
         "installation. Install with install.packages('quarto') and see ",
         "https://quarto.org.", call. = FALSE)

  review <- .np_as_review_df(x)
  if (!nrow(review))
    stop("the review frame has no rows to report.", call. = FALSE)
  if (!"uei" %in% names(review))
    stop("the review frame is missing the 'uei' key column; is this an ",
         "np_route() review frame?", call. = FALSE)

  template <- system.file("report", "match-review-report.qmd", package = "npmatch")
  if (!nzchar(template))
    stop("could not find the report template in the installed package ",
         "(inst/report/match-review-report.qmd).", call. = FALSE)

  # normalize the output path
  output <- path.expand(output)
  if (!grepl("\\.html?$", output, ignore.case = TRUE)) output <- paste0(output, ".html")
  out_dir <- dirname(output)
  if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

  # render in an isolated temp dir (Quarto writes output beside its input)
  work <- tempfile("npreview_")
  dir.create(work)
  on.exit(unlink(work, recursive = TRUE), add = TRUE)
  qmd <- file.path(work, "match-review-report.qmd")
  if (!file.copy(template, qmd, overwrite = TRUE))
    stop("failed to stage the report template into a temp directory.", call. = FALSE)
  data.table::fwrite(review, file.path(work, "review.csv"))

  quarto::quarto_render(
    input = qmd,
    execute_params = list(
      data_path       = "review.csv",
      decision_filter = as.character(decision),
      max_ueis        = as.integer(max_ueis %||% 0L),
      only_missing_gt = isTRUE(only_missing_gt),
      seed            = as.integer(seed)
    ),
    quiet = quiet
  )

  rendered <- file.path(work, "match-review-report.html")
  if (!file.exists(rendered))
    stop("Quarto did not produce the expected HTML output.", call. = FALSE)
  if (!file.copy(rendered, output, overwrite = TRUE))
    stop("failed to copy the rendered report to: ", output, call. = FALSE)

  message("wrote match review report: ", output)
  invisible(output)
}

# Coerce the various accepted inputs to a plain review data frame.
.np_as_review_df <- function(x) {
  if (is.character(x) && length(x) == 1L) {
    if (!file.exists(x)) stop("file not found: ", x, call. = FALSE)
    return(utils::read.csv(x, stringsAsFactors = FALSE, check.names = FALSE))
  }
  if (inherits(x, "np_routing")) {
    if (is.null(x$review))
      stop("this np_routing has no $review frame.", call. = FALSE)
    return(as.data.frame(x$review))
  }
  if (is.data.frame(x)) return(as.data.frame(x))
  stop("x must be an np_routing, an np_review / data.frame, or a path to a CSV.",
       call. = FALSE)
}

# local NULL-coalescing helper (avoid depending on load order of other files)
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0L) b else a
