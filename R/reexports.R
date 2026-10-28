# The normalizer lives in npnormalize (from npmatch 0.2.0). These functions are
# re-exported unchanged, so npmatch::np_normalize() and every script, package
# and stored artifact that relied on them keep working. The signature they
# report is the one npmatch reported before the move.

#' @importFrom npnormalize np_normalize
#' @export
npnormalize::np_normalize

#' @importFrom npnormalize np_normalize_signature
#' @export
npnormalize::np_normalize_signature

#' @importFrom npnormalize np_name_core
#' @export
npnormalize::np_name_core

#' @importFrom npnormalize np_name_placeholder
#' @export
npnormalize::np_name_placeholder

#' @importFrom npnormalize np_name_rules
#' @export
npnormalize::np_name_rules

#' @importFrom npnormalize np_stopwords
#' @export
npnormalize::np_stopwords

#' @importFrom npnormalize np_name_freq
#' @export
npnormalize::np_name_freq

#' @importFrom npnormalize np_token_idf
#' @export
npnormalize::np_token_idf

#' @importFrom npnormalize np_addr_freq
#' @export
npnormalize::np_addr_freq
