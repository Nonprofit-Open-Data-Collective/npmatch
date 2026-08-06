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
#' Derived / imported fields:
#' * `ntee_clean`, `nteev2` — cleaned NTEE code and NTEEv2 classification
#' * `subsection` — 501(c) subsection number (3 = 501(c)(3), ...)
#' * `is_foundation` — TRUE for private (operating or non-operating) foundations
#' * `rule_year` — year of the IRS ruling (exemption) date
#' * `assets`, `revenue` — reported asset / revenue amounts
#' * `form_990` — filing requirement: 990PF / 990N / 990-EZ/990 / none / group
#' * `affiliation_code`, `affiliation_code_definition` — central/subordinate status
#' * `group_exemption_number`, `group_exemption_is_member` — group-ruling membership
#'
#' Imported columns are prefixed `BMF_` (capitalized source prefix) so they read
#' as distinct from the pipeline's derived `_bmf` matching fields.
#'
#' @param bmf The raw processed BMF data frame.
#' @return A data frame keyed by `ein` with `BMF_`-prefixed context fields.
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
    ein                       = as.character(g("ein")),
    BMF_ntee_clean            = as.character(g("ntee_code_clean")),
    BMF_nteev2                = as.character(g("nteev2")),
    BMF_subsection            = as.character(g("subsection_code")),
    BMF_is_foundation         = grepl("private (non-)?operating foundation", fdef),
    BMF_rule_year             = suppressWarnings(as.integer(substr(as.character(g("ruling_date")), 1, 4))),
    BMF_ruling_ym             = as.character(g("ruling_date_ym_str")),
    BMF_accounting_period     = as.character(g("accounting_period")),
    BMF_assets                = suppressWarnings(as.numeric(g("asset_amount"))),
    BMF_revenue               = suppressWarnings(as.numeric(g("revenue_amount"))),
    BMF_form_990              = form,
    BMF_filing_requirement    = as.character(g("filing_requirement_code_definition")),
    BMF_pf_filing_requirement = as.character(g("pf_filing_requirement_code_definition")),
    BMF_affiliation_code      = as.character(g("affiliation_code")),
    BMF_affiliation           = as.character(g("affiliation_code_definition")),
    BMF_group_exemption_number    = as.character(g("group_exemption_number")),
    BMF_group_exemption_is_member = g("group_exemption_is_member"),
    BMF_in_care_of            = as.character(g("in_care_of_name_clean")),  # director/care-of (future match field)
    stringsAsFactors = FALSE
  )
}

#' SAM context fields for the review queue
#'
#' Builds descriptive fields imported from the SAM / USASpending source record,
#' `SAM_`-prefixed so they read as distinct from the derived `_uss` fields.
#' Handles either the uppercase-spaced or lowercase-underscore SAM column
#' conventions. The business-type string is tidied into one boolean per observed
#' type (`SAM_bus_type_<label>`), and `entity_structure` gains a decoded label.
#'
#' Note: SAM's org-size metrics (the "SAM Numerics" employee/receipt codes) are
#' not present in the V2 public monthly extract, so no size field is derived
#' here; use the BMF `BMF_assets` / `BMF_revenue` as the size proxy.
#'
#' @param sam The raw SAM data frame.
#' @return A data frame keyed by `uei` with `SAM_`-prefixed context fields.
#' @export
np_sam_review_fields <- function(sam) {
  sam <- as.data.frame(sam)
  names(sam) <- gsub("^_|_$", "", tolower(gsub("[^A-Za-z0-9]+", "_", names(sam))))
  g <- function(col) if (!is.null(sam[[col]])) as.character(sam[[col]]) else rep(NA_character_, nrow(sam))
  es_map <- c("2J"="Sole Proprietorship", "2K"="Partnership or LLP",
              "2L"="Corporate Entity (Not Tax Exempt)", "8H"="Corporate Entity (Tax Exempt)",
              "2A"="U.S. Government Entity", "CY"="Foreign Government",
              "X6"="International Organization", "ZZ"="Other")
  es <- g("entity_structure")
  out <- data.frame(
    uei                     = g("unique_entity_id"),
    SAM_entity_start_date   = g("entity_start_date"),
    SAM_fiscal_year_end     = g("fiscal_year_end_close_date"),
    SAM_entity_url          = g("entity_url"),
    SAM_entity_structure    = es,
    SAM_entity_structure_label = unname(ifelse(es %in% names(es_map), es_map[es], es)),
    SAM_primary_naics       = g("primary_naics"),
    SAM_poc_first_name      = g("govt_bus_poc_first_name"),
    SAM_poc_middle_initial  = g("govt_bus_poc_middle_initial"),
    SAM_poc_last_name       = g("govt_bus_poc_last_name"),
    SAM_poc_title           = g("govt_bus_poc_title"),
    stringsAsFactors = FALSE
  )
  # tidy the tilde-delimited business-type string into one boolean per type
  bt_map <- .np_sam_bus_types()
  bts <- g("bus_type_string"); bts[is.na(bts)] <- ""
  codes <- unique(unlist(strsplit(bts, "~"))); codes <- codes[nzchar(codes)]
  for (cd in codes) {
    lab <- if (cd %in% names(bt_map)) bt_map[[cd]] else tolower(cd)
    out[[paste0("SAM_bus_type_", lab)]] <- grepl(paste0("(^|~)", cd, "($|~)"), bts)
  }
  out
}

# SAM business-type code -> snake_case label (from the extract STRING Clarification tab).
.np_sam_bus_types <- function() c(
  "2R"="us_federal_government", "2F"="us_state_government", "12"="us_local_government",
  "3I"="tribal_government", "CY"="foreign_government", "A7"="abilityone_nonprofit",
  "20"="foreign_owned", "1D"="small_agricultural_cooperative", "LJ"="llc",
  "XS"="subchapter_s_corp", "MF"="manufacturer", "2X"="for_profit", "A8"="nonprofit",
  "2U"="other_not_for_profit", "HK"="cdc_owned_firm", "A3"="labor_surplus_area",
  "A5"="veteran_owned", "QF"="service_disabled_veteran_owned", "A2"="woman_owned",
  "23"="minority_owned", "FR"="asian_pacific_american_owned", "QZ"="subcontinent_asian_american_owned",
  "OY"="black_american_owned", "PI"="hispanic_american_owned", "NB"="native_american_owned",
  "8W"="woman_owned_small_business", "27"="self_certified_small_disadvantaged",
  "8E"="edwosb", "8C"="jv_wosb", "8D"="jv_edwosb", "NG"="federal_agency", "QW"="ffrdc",
  "C8"="city", "C7"="county", "ZR"="inter_municipal", "MG"="local_government_owned",
  "C6"="municipality", "H6"="school_district", "TW"="transit_authority", "UD"="council_of_governments",
  "8B"="housing_authority", "86"="interstate_entity", "KM"="planning_commission", "T4"="port_authority",
  "H2"="community_development_corp", "6D"="domestic_shelter", "M8"="educational_institution",
  "G6"="land_grant_1862", "G7"="land_grant_1890", "G8"="land_grant_1994",
  "HB"="hbcu", "1A"="minority_institution", "1R"="private_university_or_college",
  "ZW"="school_of_forestry", "GW"="hispanic_serving_institution",
  "OH"="state_controlled_higher_ed", "HS"="tribal_college", "QU"="veterinary_college",
  "G3"="alaskan_native_serving_institution", "G5"="native_hawaiian_serving_institution",
  "BZ"="foundation", "80"="hospital", "FY"="veterinary_hospital", "HQ"="dot_certified_dbe",
  "05"="alaskan_native_corp_owned", "OW"="american_indian_owned",
  "XY"="indian_tribe_federally_recognized", "8U"="native_hawaiian_org_owned",
  "1B"="tribally_owned_firm", "FO"="township", "TR"="airport_authority",
  "G9"="other", "JX"="self_certified_hubzone_jv", "1E"="indian_economic_enterprise",
  "1S"="indian_small_business_economic_enterprise", "A6"="sba_8a_participant",
  "JT"="sba_8a_joint_venture", "XX"="sba_hubzone_firm", "A9"="sba_wosb",
  "A0"="sba_edwosb", "JV"="joint_venture", "JS"="sba_hubzone_joint_venture"
)

#' @rdname np_maps
#' @export
np_map_sam <- function() {
  c(
    .id      = "unique_entity_id",
    name     = "legal_business_name",
    dba      = "dba_name",
    division = "entity_division_name",   # SAM's second alternate-name field
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
