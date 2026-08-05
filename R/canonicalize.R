#' Built-in schema maps
#'
#' Named vectors mapping canonical npmatch fields (names) to source column
#' names (values) for known dataset formats. Use with the `map` argument of
#' [np_query()] / [np_reference()], or supply your own.
#'
#' `np_map_bmf()` targets the current processed IRS BMF. It matches on
#' `org_name_join` (already uppercased and de-punctuated) and keeps the raw and
#' parent names for the veto layer.
#'
#' `np_map_sam()` targets the SAM / USASpending public extract used as the
#' worked example.
#'
#' @return A named character vector: `canonical_field = source_column`.
#' @name np_maps
#' @export
np_map_bmf <- function() {
  c(
    .ein   = "ein",
    name   = "org_name_join",
    dba    = "dba_name",
    street = "org_addr_street",
    city   = "org_addr_city",
    state  = "org_addr_state",
    zip5   = "org_addr_zip5",
    zip_plus4 = "org_addr_zip4"     # +4 add-on: input only, used to build zip9
  )
}

#' Default BMF context fields for the review queue
#'
#' Builds the small set of IRS-BMF descriptive fields worth showing a human
#' reviewer next to each candidate: what kind of nonprofit it is and how big.
#' Pass the raw processed BMF and join the result onto a review frame by `ein`
#' (this is what `np_route(bmf = ...)` does automatically).
#'
#' Derived fields:
#' * `ntee` — NTEE common code (activity area)
#' * `subsection` — 501(c) subsection number (3 = 501(c)(3), ...)
#' * `is_foundation` — TRUE for private (operating or non-operating) foundations
#' * `rule_year` — year of the IRS ruling (exemption) date
#' * `assets`, `revenue` — reported asset / revenue amounts
#' * `form_990` — filing requirement: 990PF / 990N / 990-EZ/990 / none / group
#'
#' @param bmf The raw processed BMF data frame.
#' @return A data frame keyed by `ein` with the fields above.
#' @export
np_bmf_review_fields <- function(bmf) {
  bmf <- as.data.frame(bmf)
  g <- function(col) if (!is.null(bmf[[col]])) bmf[[col]] else rep(NA, nrow(bmf))
  fdef <- tolower(as.character(g("foundation_code_definition")))
  frq  <- as.character(g("filing_requirement_code_definition"))
  pf   <- as.character(g("pf_filing_requirement_code"))
  form <- ifelse(pf == "1", "990PF",
           ifelse(grepl("990-N", frq), "990N",
           ifelse(grepl("990 \\(all other\\) or 990EZ", frq), "990/990EZ",
           ifelse(grepl("Group return", frq), "990-group",
           ifelse(grepl("Not required", frq), "none", NA_character_)))))
  data.frame(
    ein           = as.character(g("ein")),
    ntee          = as.character(g("ntee_common_code")),
    subsection    = as.character(g("subsection_code")),
    is_foundation = grepl("private (non-)?operating foundation", fdef),
    rule_year     = suppressWarnings(as.integer(substr(as.character(g("ruling_date")), 1, 4))),
    assets        = suppressWarnings(as.numeric(g("asset_amount"))),
    revenue       = suppressWarnings(as.numeric(g("revenue_amount"))),
    form_990      = form,
    stringsAsFactors = FALSE
  )
}

#' @rdname np_maps
#' @export
np_map_sam <- function() {
  c(
    .id    = "unique_entity_id",
    name   = "legal_business_name",
    dba    = "dba_name",
    street = "physical_address_line_1",
    unit   = "physical_address_line_2",
    city   = "physical_address_city",
    state  = "physical_address_province_or_state",
    zip5   = "physical_address_zip_postal_code"
  )
}

# Shared canonicaliser -------------------------------------------------------

.np_canonicalize <- function(data, map, side) {
  data <- as.data.frame(data, stringsAsFactors = FALSE)
  missing <- setdiff(unname(map), names(data))
  if (length(missing)) {
    stop(sprintf("%s data is missing mapped column(s): %s",
                 side, paste(missing, collapse = ", ")), call. = FALSE)
  }
  out <- data.frame(row.names = seq_len(nrow(data)))
  for (canon in names(map)) out[[canon]] <- data[[map[[canon]]]]
  # ensure every canonical field exists (unmapped -> NA character)
  for (f in setdiff(np_fields, names(out))) out[[f]] <- NA_character_
  out <- out[, np_fields, drop = FALSE]
  # light hygiene shared by both sides
  chr <- vapply(out, is.character, logical(1))
  out[chr] <- lapply(out[chr], function(v) stringr::str_squish(as.character(v)))
  out
}

#' Construct a query frame
#'
#' Maps an arbitrary source dataset onto npmatch canonical fields. The query is
#' the "unknown" side being matched *into* the reference. A stable `.id` is
#' required; if the map does not supply one, row numbers are used.
#'
#' @param data A data frame.
#' @param map A named character vector, `canonical = source_column`
#'   (see [np_maps]). Defaults to the SAM/USASpending map.
#' @return A data frame of class `np_query` with the canonical columns.
#' @export
np_query <- function(data, map = np_map_sam()) {
  out <- .np_canonicalize(data, map, "query")
  if (all(is.na(out$.id))) out$.id <- as.character(seq_len(nrow(out)))
  out$.id <- as.character(out$.id)
  structure(out, class = c("np_query", "data.frame"))
}

#' Construct a reference frame
#'
#' Maps the BMF (or, later, the disambiguation database) onto canonical fields.
#' The entity key `.ein` is required and is what selection/tiering resolve to.
#'
#' @param data A data frame.
#' @param map A named character vector (see [np_maps]). Defaults to the BMF map.
#' @return A data frame of class `np_reference` with the canonical columns.
#' @export
np_reference <- function(data, map = np_map_bmf()) {
  out <- .np_canonicalize(data, map, "reference")
  if (all(is.na(out$.ein))) {
    stop("reference data must map an entity key to `.ein`.", call. = FALSE)
  }
  out$.ein <- as.character(out$.ein)
  structure(out, class = c("np_reference", "data.frame"))
}
