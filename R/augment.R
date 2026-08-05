# =============================================================================
# Optional geography cleaning and ZIP-based augmentation. These are separate,
# opt-in helpers -- npmatch's core pipeline does not require them.
# =============================================================================

#' Common city aliases
#'
#' Whole-name city aliases mapped to a canonical form, used by [np_clean_geo()].
#' Extend or replace with your own named character vector
#' (`"VARIANT" = "CANONICAL"`, uppercase).
#'
#' @return A named character vector.
#' @export
np_city_aliases <- function() {
  c("NYC" = "NEW YORK CITY", "NY CITY" = "NEW YORK CITY", "NEW YORK" = "NEW YORK CITY",
    "LA" = "LOS ANGELES", "L A" = "LOS ANGELES",
    "SF" = "SAN FRANCISCO", "PHILLY" = "PHILADELPHIA",
    "ST LOUIS" = "SAINT LOUIS", "ST PAUL" = "SAINT PAUL",
    "FT WORTH" = "FORT WORTH", "FT LAUDERDALE" = "FORT LAUDERDALE",
    "MT PLEASANT" = "MOUNT PLEASANT")
}

# Reference-based city correction/fill via ZIP: fill a missing city from the
# ZIP's canonical city, and swap a city that is a near-miss (edit distance
# <= max_dist) of the ZIP's canonical city. Leaves genuinely different (far)
# city names alone (a ZIP can have several acceptable place names).
.np_refine_city <- function(city, zip5, zip_ref, max_dist = 2) {
  zr <- zip_ref; names(zr) <- tolower(names(zr))
  citycol <- intersect(c("city", "major_city", "primary_city", "po_name"), names(zr))[1]
  if (is.na(citycol) || !"zip5" %in% names(zr)) return(city)
  refcity <- toupper(as.character(zr[[citycol]]))[
    match(as.character(zip5), .np_pad5(zr$zip5))]
  cur <- toupper(as.character(city))
  miss <- (is.na(cur) | !nzchar(cur)) & !is.na(refcity) & nzchar(refcity)
  cur[miss] <- refcity[miss]
  cand <- !is.na(cur) & nzchar(cur) & !is.na(refcity) & nzchar(refcity) & cur != refcity
  if (any(cand)) {
    d <- mapply(function(a, b) as.integer(utils::adist(a, b)), cur[cand], refcity[cand])
    swap <- logical(length(cur)); swap[cand] <- d <= max_dist
    cur[swap] <- refcity[swap]
  }
  cur
}

#' Clean and standardize city and state fields
#'
#' Normalizes `city` and `state` in place. Two engines:
#'
#' * `"rules"` (default, no dependency) — upper-case and squish, expand the
#'   common abbreviated prefixes (`ST`->`SAINT`, `FT`->`FORT`, `MT`->`MOUNT`),
#'   apply whole-name city aliases (`NYC`->`NEW YORK CITY`), and coerce `state`
#'   to a two-letter code.
#' * `"campfin"` — delegate city/state normalization to the `campfin` package
#'   (`normal_city()` / `normal_state()`), which validate against USPS and
#'   Census place lists (expanding abbreviations, stripping trailing state
#'   tokens, and nulling known-invalid entries). The alias map is still applied
#'   on top.
#'
#' Correcting arbitrary *misspellings* (e.g. "PHOENex" -> "PHOENIX") needs a
#' reference of valid place names. Supply `zip_ref` (a `zip5`-keyed crosswalk
#' with a city column, e.g. from [np_load_zipcode_db()]): a missing city is
#' filled from its ZIP, and a near-miss (edit distance <= `max_dist`) is snapped
#' to the ZIP's canonical city.
#'
#' @param data A data frame with `city` / `state` (and `zip5` for `zip_ref`).
#' @param engine `"rules"` or `"campfin"`.
#' @param aliases Whole-name city alias map (see [np_city_aliases()]).
#' @param zip_ref Optional `zip5`-keyed crosswalk for misspelling correction.
#' @param max_dist Max edit distance to treat a city as a correctable near-miss.
#' @return `data` with `city` / `state` cleaned in place.
#' @export
np_clean_geo <- function(data, engine = c("rules", "campfin"),
                         aliases = np_city_aliases(), zip_ref = NULL,
                         max_dist = 2) {
  engine <- match.arg(engine)

  if (engine == "campfin") {
    if (!requireNamespace("campfin", quietly = TRUE))
      stop("engine = 'campfin' needs the campfin package.", call. = FALSE)
    if (!is.null(data$city))
      data$city <- campfin::normal_city(as.character(data$city),
                     abbs = campfin::usps_city, states = campfin::valid_state,
                     na = campfin::invalid_city, na_rep = TRUE)
    if (!is.null(data$state))
      data$state <- campfin::normal_state(as.character(data$state),
                     abbreviate = TRUE, valid = campfin::valid_state)
  } else if (!is.null(data$state)) {
    data$state <- .np_to_state_abb(data$state)
  }

  if (!is.null(data$city)) {
    city <- toupper(stringr::str_squish(as.character(data$city)))
    city <- sub("^ST ",  "SAINT ",  city)
    city <- sub("^STE ", "SAINTE ", city)
    city <- sub("^FT ",  "FORT ",   city)
    city <- sub("^MT ",  "MOUNT ",  city)
    hit <- city %in% names(aliases)
    city[hit] <- aliases[city[hit]]
    data$city <- city
  }

  if (!is.null(zip_ref) && !is.null(data$zip5))
    data$city <- .np_refine_city(data$city, data$zip5, zip_ref, max_dist)

  data
}

#' Augment records with ZIP-level geography
#'
#' Left-joins a ZIP-keyed crosswalk onto `data`, adding whatever columns it
#' carries (county, CBSA/metro name, RUCA code, urban/rural flag, ...). npmatch
#' ships no crosswalk data; you supply one built from a standard source and load
#' it yourself:
#'
#' * **county / CBSA (metro):** HUD USPS ZIP Crosswalk (ZIP->CBSA, ZIP->county)
#'   or the `zipcodeR` package's `zip_code_db`.
#' * **urban / rural:** USDA ERS ZIP-code RUCA codes (then [np_ruca_urban()]).
#'
#' The crosswalk must have a `zip5` (or `by`) key column; all other columns are
#' added to `data`. Join first on the record's own `zip5` from [np_normalize()].
#'
#' @examples
#' \dontrun{
#' # from the zipcodeR package
#' xwalk <- zipcodeR::zip_code_db[, c("zipcode", "county", "state")]
#' names(xwalk)[1] <- "zip5"
#' records <- np_augment_geo(records, xwalk)
#' }
#'
#' @param data A data frame with a ZIP key column (default `zip5`).
#' @param crosswalk A data frame keyed by the same column.
#' @param by The join key column name present in both. Default `"zip5"`.
#' @param cols Columns from `crosswalk` to add; default all non-key columns.
#' @return `data` with the crosswalk columns joined on.
#' @export
np_augment_geo <- function(data, crosswalk, by = "zip5", cols = NULL) {
  if (!by %in% names(data))      stop("`data` has no column '", by, "'.", call. = FALSE)
  if (!by %in% names(crosswalk)) stop("`crosswalk` has no column '", by, "'.", call. = FALSE)
  if (is.null(cols)) cols <- setdiff(names(crosswalk), by)
  m <- match(as.character(data[[by]]),
             stringr::str_pad(as.character(crosswalk[[by]]), 5, "left", "0"))
  for (cc in cols) data[[cc]] <- crosswalk[[cc]][m]
  data
}

#' Collapse a RUCA code to an urban / rural flag
#'
#' Primary Rural-Urban Commuting Area codes 1-3 are metropolitan; 4 and above
#' are non-metropolitan. Returns `"urban"` / `"rural"` accordingly.
#'
#' @param ruca Numeric or character primary RUCA codes.
#' @param urban_max Highest RUCA still treated as urban. Default 3.
#' @return A character vector of `"urban"` / `"rural"` / `NA`.
#' @export
np_ruca_urban <- function(ruca, urban_max = 3) {
  r <- floor(suppressWarnings(as.numeric(ruca)))
  ifelse(is.na(r), NA_character_, ifelse(r <= urban_max, "urban", "rural"))
}
