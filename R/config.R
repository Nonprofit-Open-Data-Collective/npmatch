#' npmatch canonical fields
#'
#' The internal, dataset-agnostic column names every npmatch stage works with.
#' Query and reference frames are mapped onto these by [np_query()] /
#' [np_reference()]. Not every field will be populated for every dataset; the
#' geography-adaptive machinery keys off which of the geo fields are present.
#'
#' @format A character vector of canonical field names.
#' @export
np_fields <- c(
  ".id", ".ein",
  "name", "dba", "division",
  "street", "unit", "city", "county", "state", "zip5", "zip_plus4"
)

#' Geographic profiles
#'
#' npmatch adapts blocking, comparison, and weighting to the geographic detail
#' available in the *query* dataset. A profile is an ordered set of geo fields;
#' `np_geo_profiles()` lists the ones npmatch recognises, weakest to strongest.
#' State is the minimum (and the default blocking key); richer profiles add
#' comparison fields and shift weight away from the name.
#'
#' @return A named list; each element is the character vector of geo fields that
#'   defines that profile.
#' @export
np_geo_profiles <- function() {
  list(
    state             = c("state"),
    city_state        = c("city", "state"),
    county_state      = c("county", "state"),
    zip_city_state    = c("zip5", "city", "state"),
    street_full       = c("street", "city", "state", "zip5"),
    street_unit_full  = c("street", "unit", "city", "state", "zip5")
  )
}

#' Configuration for a linkage run
#'
#' Bundles the comparators, per-field weights, tier thresholds, and active veto
#' rule set so a run is reproducible and tunable. Weights are supplied per geo
#' profile; [np_detect_geo()] picks the profile at run time and [np_score()]
#' uses the matching weight vector. Weights need not sum to 1 — they are
#' normalised internally.
#'
#' @param weights Named list mapping geo-profile name to a named numeric vector
#'   of field weights. Fields absent from a profile are ignored.
#' @param thresholds Named numeric of length 2, `yes` and `maybe`, on the
#'   0-1 score scale. `score >= yes` -> YES; `>= maybe` -> MAYBE; else NO.
#' @param min_margin Minimum lead the best match must have over the runner-up
#'   (next-best distinct entity) to be auto-accepted. A near-tie (`margin <
#'   min_margin`) is held at MAYBE for disambiguation even above `yes`.
#' @param tie_band Score window below the top candidate within which other
#'   candidates count as "tied" (used to flag 2-3 close candidates).
#' @param tie_high When tied candidates are all at or above this score, the tie
#'   is broken by the `tiebreak` rule instead of the combined score.
#' @param tiebreak How to break a high tie: `"name"` picks the tied candidate
#'   with the highest name similarity (address is uninformative when several
#'   strong candidates exist); `"none"` keeps the combined-score pick.
#' @param distinct_name_maxfreq,distinct_name_floor Distinctive-name promotion
#'   (hier scoring): an exact name match on a name shared by at most
#'   `distinct_name_maxfreq` reference records is trusted even without address
#'   corroboration, its score floored up to `distinct_name_floor`.
#' @param distinct_name_floor_xstate Lower promotion floor applied when the
#'   distinctive-name match is *not* state-confirmed (query and candidate in
#'   different states, or no state to compare). Cross-state exact-name-only
#'   matches are far less reliable than same-state ones, so they are floored to
#'   this lower value (landing in MAYBE for review) rather than `distinct_name_floor`.
#' @param name_comparator,addr_comparator reclin2 comparator constructors used
#'   for name-like and address-like fields respectively.
#' @param jw_threshold Jaro-Winkler floor passed to the comparators; per-field
#'   similarities below this are set to 0 (reduces noise from unrelated pairs).
#' @param rules A veto rule set as returned by [np_default_rules()] (or a
#'   user-extended version).
#' @param geo_weights Named numeric of location-granularity credits used by
#'   `np_score(method = "hier")` (see [np_default_geo_weights()]).
#' @param name_geo Named numeric `c(name=, geo=)` splitting the hierarchical
#'   score between the name and the geo sub-score. Should sum to 1.
#' @return An object of class `np_config`.
#' @export
np_config <- function(weights    = np_default_weights(),
                      thresholds = c(yes = 0.78, maybe = 0.65),
                      min_margin = 0.05,
                      tie_band = 0.05, tie_high = 0.95, tiebreak = "name",
                      distinct_name_maxfreq = 3, distinct_name_floor = 0.90,
                      distinct_name_floor_xstate = 0.72,
                      name_comparator = "jaro_winkler",
                      addr_comparator = "jaro_winkler",
                      jw_threshold = 0.85,
                      rules = np_default_rules(),
                      geo_weights = np_default_geo_weights(),
                      name_geo = c(name = 0.6, geo = 0.4)) {
  stopifnot(all(c("yes", "maybe") %in% names(thresholds)))
  structure(
    list(
      weights         = weights,
      thresholds      = thresholds,
      min_margin      = min_margin,
      tie_band        = tie_band,
      tie_high        = tie_high,
      tiebreak        = tiebreak,
      distinct_name_maxfreq = distinct_name_maxfreq,
      distinct_name_floor   = distinct_name_floor,
      distinct_name_floor_xstate = distinct_name_floor_xstate,
      name_comparator = name_comparator,
      addr_comparator = addr_comparator,
      jw_threshold    = jw_threshold,
      rules           = rules,
      geo_weights     = geo_weights,
      name_geo        = name_geo
    ),
    class = "np_config"
  )
}

#' Default location-granularity credits
#'
#' The evidence weight for confirming two records share a location at each
#' granularity, used by the hierarchical geo score. The score takes the
#' \emph{maximum} applicable term ("how precisely is the location confirmed"),
#' so correlated fields are never double-counted and a redundant noisy field
#' (e.g. a wrong city when the ZIP already matches) cannot lower the score.
#'
#' Ordered strongest to weakest: full ZIP+4 (`zip9`), same street
#' (`street` = number + body), 5-digit ZIP, matching PO box, 3-digit ZIP
#' (SCF region), city, state.
#'
#' @return A named numeric vector.
#' @export
np_default_geo_weights <- function() {
  c(zip9 = 1.00, street = 0.95, zip5 = 0.90, pobox = 0.90,
    zip3 = 0.55, city = 0.50, state = 0.20)
}

#' Default per-profile field weights
#'
#' Starting weights, richest-geo profiles lean less on the name. These are
#' deliberately hand-set defaults; the intended workflow is to *replace* them
#' with weights learned from a labelled training set (see [np_score()] method
#' `"em"` and the labelling-frame helpers).
#'
#' @return A named list suitable for the `weights` argument of [np_config()].
#' @export
np_default_weights <- function() {
  list(
    state            = c(name = 1.0),
    city_state       = c(name = 0.70, city = 0.30),
    county_state     = c(name = 0.70, county = 0.30),
    zip_city_state   = c(name = 0.55, zip5 = 0.25, city = 0.20),
    street_full      = c(name = 0.45, street = 0.25, zip5 = 0.15, city = 0.15),
    street_unit_full = c(name = 0.45, street = 0.22, unit = 0.06,
                         zip5 = 0.14, city = 0.13)
  )
}

#' @export
print.np_config <- function(x, ...) {
  cat("<np_config>\n")
  cat("  tiers:  YES >=", x$thresholds["yes"],
      " MAYBE >=", x$thresholds["maybe"], "\n")
  cat("  geo profiles weighted:", paste(names(x$weights), collapse = ", "), "\n")
  cat("  veto rules:", nrow(x$rules), "active\n")
  invisible(x)
}
