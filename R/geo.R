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
  # `unit` coverage is measured on the EXTRACTED unit where the frame has been
  # normalized, not on the raw second address line. The raw line was the wrong
  # test in both directions: a source that writes the suite inside line 1 (most
  # of them) looked unit-less, while SAM, which fills line 2, selected the
  # street_unit_full profile on a column nothing then compared.
  cov <- vapply(geo_fields, function(f) {
    v <- query[[f]]
    if (f == "unit" && !is.null(query$street_unit)) v <- query$street_unit
    if (is.null(v)) return(0)
    mean(!is.na(v) & nzchar(as.character(v)))
  }, numeric(1))
  available <- names(cov)[cov >= min_coverage]

  # A profile requiring `unit` is never auto-selected, however well covered the
  # column is. The profiles feed a WEIGHTED SUM, where a field earns its weight
  # only by matching -- so a unit term silently penalises every candidate whose
  # suite is simply unrecorded, and a BMF that omits the suite can then never
  # score as well as one that keeps it. Suite evidence belongs in the
  # hierarchical score instead, where terms combine with max() and an absent
  # suite costs nothing (see np_addr_freq() and np_default_geo_weights()).
  # street_unit_full remains available to a caller who passes `profile =`
  # explicitly, or who has learned weights for it.
  profiles <- np_geo_profiles()
  ok <- vapply(profiles, function(fl)
    all(fl %in% available) && !("unit" %in% fl), logical(1))
  chosen <- if (any(ok)) {
    # richest = most fields among those fully satisfied
    names(which.max(vapply(profiles[ok], length, integer(1))))
  } else {
    "state"
  }
  structure(chosen, coverage = cov, fields = profiles[[chosen]])
}
