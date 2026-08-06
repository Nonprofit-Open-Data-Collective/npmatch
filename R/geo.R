#' Detect the geographic profile of a query frame
#'
#' Inspects which geo fields are usably populated and returns the richest
#' [np_geo_profiles()] entry all of whose fields clear `min_coverage`. This
#' drives the "optimal approach is conditional on the geography available"
#' decision: blocking key, comparison fields, and weight vector all follow from
#' the detected profile.
#'
#' @param query An `np_query` frame (normalized or not).
#' @param min_coverage Minimum non-missing fraction for a field to count as
#'   available. Default 0.5.
#' @return A length-one character naming the detected profile, with attributes
#'   `coverage` (per-field non-missing fraction) and `fields`.
#' @export
np_detect_geo <- function(query, min_coverage = 0.5) {
  geo_fields <- c("street", "unit", "city", "county", "state", "zip5")
  cov <- vapply(geo_fields, function(f) {
    v <- query[[f]]
    if (is.null(v)) return(0)
    mean(!is.na(v) & nzchar(as.character(v)))
  }, numeric(1))
  available <- names(cov)[cov >= min_coverage]

  profiles <- np_geo_profiles()
  ok <- vapply(profiles, function(fl) all(fl %in% available), logical(1))
  chosen <- if (any(ok)) {
    # richest = most fields among those fully satisfied
    names(which.max(vapply(profiles[ok], length, integer(1))))
  } else {
    "state"
  }
  structure(chosen, coverage = cov, fields = profiles[[chosen]])
}
