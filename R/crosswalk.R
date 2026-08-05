# =============================================================================
# Loaders that turn a downloaded ZIP crosswalk (or the zipcodeR database) into
# the {zip5, ...} shape np_augment_geo() expects. They handle the column-name
# guessing and the dominant-record collapse so callers don't have to. npmatch
# still ships no data -- these read what you point them at.
# =============================================================================

.np_pad5 <- function(x) stringr::str_pad(gsub("[^0-9]", "", as.character(x)), 5, "left", "0")

# Accept an already-loaded data frame, a .csv path (data.table), or an .xlsx
# path (readxl, if installed).
.np_read_any <- function(x, sheet = 1) {
  if (is.data.frame(x)) return(as.data.frame(x, stringsAsFactors = FALSE))
  if (!is.character(x) || length(x) != 1) stop("Provide a data frame or a file path.", call. = FALSE)
  if (grepl("\\.xlsx?$", x, ignore.case = TRUE)) {
    if (!requireNamespace("readxl", quietly = TRUE))
      stop("Reading '", x, "' needs the readxl package (or pass a data frame / .csv).",
           call. = FALSE)
    return(as.data.frame(readxl::read_excel(x, sheet = sheet), stringsAsFactors = FALSE))
  }
  as.data.frame(data.table::fread(x), stringsAsFactors = FALSE)
}

#' Load a HUD USPS ZIP crosswalk file
#'
#' Reshapes a downloaded HUD ZIP crosswalk (ZIP->CBSA, ZIP->county, ...) into a
#' `zip5`-keyed lookup for [np_augment_geo()]. A ZIP can map to several target
#' geographies; the dominant one (highest address ratio) is kept.
#'
#' Download from <https://www.huduser.gov/portal/datasets/usps_crosswalk.html>
#' (login required). The geography column (`cbsa`, `county`, ...) is detected
#' automatically as the non-ZIP, non-ratio column.
#'
#' @param x A HUD crosswalk: a data frame, `.csv`, or `.xlsx` path.
#' @param ratio Which HUD ratio to rank dominance by: `"tot"`, `"res"`, `"bus"`,
#'   or `"oth"`. Default `"tot"`.
#' @return A data frame with `zip5` and the detected geography column.
#' @export
np_load_hud <- function(x, ratio = c("tot", "res", "bus", "oth")) {
  ratio <- match.arg(ratio)
  d <- .np_read_any(x); names(d) <- tolower(names(d))
  zipcol <- intersect(c("zip", "zip_code", "zipcode"), names(d))[1]
  if (is.na(zipcol)) stop("No ZIP column found in the HUD file.", call. = FALSE)
  ratio_cols <- grep("_ratio$", names(d), value = TRUE)
  geocol <- setdiff(names(d), c(zipcol, ratio_cols))[1]
  if (is.na(geocol)) stop("No geography column found in the HUD file.", call. = FALSE)

  d$zip5 <- .np_pad5(d[[zipcol]])
  ratecol <- paste0(ratio, "_ratio")
  rate <- if (ratecol %in% names(d)) suppressWarnings(as.numeric(d[[ratecol]])) else 1
  d <- d[order(d$zip5, -rate), , drop = FALSE]
  d <- d[!duplicated(d$zip5), , drop = FALSE]

  out <- data.frame(zip5 = d$zip5, stringsAsFactors = FALSE)
  out[[geocol]] <- d[[geocol]]
  out
}

#' Load a USDA ERS ZIP-code RUCA file
#'
#' Reshapes the USDA Economic Research Service ZIP-code Rural-Urban Commuting
#' Area file into a `zip5`-keyed lookup with a numeric `ruca` (primary RUCA).
#' Pair with [np_ruca_urban()] for an urban/rural flag.
#'
#' Download from <https://www.ers.usda.gov/data-products/rural-urban-commuting-area-codes>.
#'
#' @param x A RUCA file: a data frame, `.csv`, or `.xlsx` path.
#' @param sheet Worksheet for `.xlsx` input. Default 1.
#' @return A data frame with `zip5` and `ruca`.
#' @export
np_load_ruca <- function(x, sheet = 1) {
  d <- .np_read_any(x, sheet = sheet); names(d) <- tolower(names(d))
  zipcol  <- intersect(c("zip_code", "zipa", "zip", "zipcode"), names(d))[1]
  rucacol <- intersect(c("ruca1", "ruca", "primary_ruca"), names(d))[1]
  if (is.na(zipcol) || is.na(rucacol))
    stop("Could not find ZIP and RUCA columns in the file.", call. = FALSE)
  out <- data.frame(zip5 = .np_pad5(d[[zipcol]]),
                    ruca = suppressWarnings(as.numeric(d[[rucacol]])),
                    stringsAsFactors = FALSE)
  out[!duplicated(out$zip5), , drop = FALSE]
}

#' Build a ZIP crosswalk from the zipcodeR package
#'
#' Convenience wrapper around `zipcodeR::zip_code_db` (no download needed) that
#' returns a `zip5`-keyed lookup for [np_augment_geo()].
#'
#' @param cols Columns to carry from `zip_code_db`. Default county / state /
#'   primary city.
#' @return A data frame with `zip5` and the requested columns.
#' @export
np_load_zipcode_db <- function(cols = c("county", "state", "major_city")) {
  if (!requireNamespace("zipcodeR", quietly = TRUE))
    stop("np_load_zipcode_db() needs the zipcodeR package.", call. = FALSE)
  db <- zipcodeR::zip_code_db
  out <- data.frame(zip5 = .np_pad5(db$zipcode), stringsAsFactors = FALSE)
  for (cc in intersect(cols, names(db))) out[[cc]] <- db[[cc]]
  out
}
