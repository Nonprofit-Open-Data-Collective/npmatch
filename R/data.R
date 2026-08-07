#' npmatch evaluation frame (1,502-org benchmark)
#'
#' The candidate-level evaluation frame for the hand-labeled 1,502-organization
#' benchmark: one row per (source organization x BMF candidate), joined with the
#' ground-truth labels. Group rows by `uei` to see a source org's competing
#' candidates; `is_top_candidate == 1` marks the algorithm's chosen pick and
#' `is_gt_ein == 1` marks the row whose EIN is the ground-truth correct match.
#'
#' Alongside similarity features it carries the full review evidence: normalized
#' name variants, IDF-annotated tokens, geographic-agreement flags, the veto
#' trail, imported BMF context (`BMF_*`) and SAM context (`SAM_*`), and the
#' ground-truth columns (`gt_*`). Every column is described in
#' `vignette("training-dataset", package = "npmatch")` and the field-level
#' `vignette("candidate-evaluation-frame", package = "npmatch")`.
#'
#' @format A data frame with 2,763 rows and 150 columns.
#' @source SAM / USASpending nonprofit registrations matched to the IRS Business
#'   Master File (unified active + inactive, 2026-01 vintage). See
#'   `vignette("training-dataset", package = "npmatch")`.
#' @seealso [npmatch_groundtruth]
"npmatch_eval"

#' npmatch ground-truth master (1,502-org benchmark)
#'
#' Query-level ground-truth labels for the benchmark: one row per source
#' organization. This is the archival label key — the training/validation target
#' that the evaluation frame joins onto.
#'
#' @format A data frame with 1,502 rows and 17 columns, including:
#' \describe{
#'   \item{uei}{Source (SAM) Unique Entity ID.}
#'   \item{sample_type}{`"random"` (1,000 representative) or `"hard"` (502 oversampled).}
#'   \item{sam_name}{Source organization legal name.}
#'   \item{gt_is_match}{`TRUE` if a correct BMF EIN exists.}
#'   \item{gt_outcome_class}{`in_bmf_match` / `nonprofit_not_in_bmf` /
#'     `not_a_nonprofit` / `no_match_or_na` / `cant_determine`.}
#'   \item{gt_ein}{The correct EIN (may be an inactive-BMF or externally-collected EIN).}
#'   \item{gt_ein_in_bmf, gt_ein_bmf_active}{Whether `gt_ein` is in the BMF, and active.}
#'   \item{gt_method, gt_confidence, gt_notes}{How the label was determined, confidence, and notes.}
#' }
#' @source See `vignette("training-dataset", package = "npmatch")`.
#' @seealso [npmatch_eval]
"npmatch_groundtruth"
