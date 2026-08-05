#' npmatch: nonprofit record linkage to the IRS BMF
#'
#' A geography-adaptive, tiered linkage pipeline built as a thin layer over
#' reclin2. The stages compose left to right:
#'
#' \enumerate{
#'   \item [np_query()] / [np_reference()] — map a dataset onto canonical fields
#'   \item [np_normalize()] — standardize names/addresses, extract veto features
#'   \item [np_compare()] — block and score candidate pairs (reclin2)
#'   \item [np_score()] — combine field similarities (weighted / EM / model)
#'   \item [np_veto()] — apply hard do-not-match rules
#'   \item [np_select()] — best entity per query, plus loosened name/addr views
#'   \item [np_tier()] — sort into YES / MAYBE / NO
#' }
#'
#' [np_match()] runs the whole chain; [np_label_frame()] emits training data.
#'
#' @keywords internal
"_PACKAGE"
