# ---------------------------------------------------------------------------
# Source fetching, SAM nonprofit filtering, and incremental (diff) matching.
# ---------------------------------------------------------------------------

.np_s3_base <- "https://nccsdata.s3.dualstack.us-east-1.amazonaws.com/crosswalks/npmatch"

#' Known npmatch data sources
#'
#' The pinned **archive** snapshots (the exact vintages used to build the
#' shipped crosswalk, hosted on the NCCS S3 bucket) plus the **source** landing
#' pages for pulling fresh files. Archive files let documentation reproduce
#' outputs exactly; source pages let you check for newer data.
#'
#' @return A data frame with columns `key`, `kind` (`"archive"`/`"source"`),
#'   `url`, and `note`.
#' @export
np_source_urls <- function() {
  s3 <- function(f) file.path(.np_s3_base, f)
  data.frame(
    key  = c("bmf_processed", "bmf_unified", "bmf_dictionary", "sam_extract",
             "training_pairs", "bmf_fresh", "sam_fresh"),
    kind = c("archive", "archive", "archive", "archive", "archive", "source", "source"),
    url  = c(s3("bmf_2026_01_processed.csv"), s3("bmf_unified_geocoded.csv"),
             s3("bmf_2026_01_data_dictionary.csv"), s3("SAM_PUBLIC_MONTHLY_V2_20251102.dat"),
             s3("TRAINING-PAIRS-1502.csv"),
             "https://nccs.urban.org/nccs/catalogs/catalog-bmf.html",
             "https://sam.gov/data-services/Entity%20Registration/Public%20-%20Historical?privacy=Public"),
    note = c("active BMF (2026-01), pinned", "unified active+inactive BMF, pinned",
             "BMF field dictionary", "SAM monthly public extract (2025-11), pinned; needs np_prepare_sam()",
             "model-training projection: 304k scored pairs, features + label",
             "NCCS BMF catalog - pick a vintage, then np_fetch()",
             "SAM historical - download, then np_prepare_sam()"),
    stringsAsFactors = FALSE)
}

#' Download a data file
#'
#' Thin wrapper over [utils::download.file()] with sensible defaults for large
#' files (binary mode, long timeout, resumable skip). Records the download in
#' the data [np_manifest()] when `manifest = TRUE`.
#'
#' @param url File URL.
#' @param dest Destination path. Default: `raw/<basename>` under the data root.
#' @param overwrite Re-download if the destination already exists. Default `FALSE`.
#' @param manifest Record the download in the manifest. Default `TRUE`.
#' @param timeout Download timeout in seconds. Default 3600.
#' @param method Download method passed to [utils::download.file()]. Default
#'   `"auto"` (R picks a working transport); override with `"libcurl"`,
#'   `"curl"`, or `"wininet"` if needed.
#' @param quiet Suppress progress. Default `FALSE`.
#' @return The destination path, invisibly.
#' @export
np_fetch <- function(url, dest = NULL, overwrite = FALSE, manifest = TRUE,
                     timeout = 3600, method = "auto", quiet = FALSE) {
  if (is.null(dest)) dest <- np_data_path("raw", basename(url), create = TRUE)
  if (file.exists(dest) && !overwrite) {
    if (!quiet) message("exists, skipping (overwrite = TRUE to force): ", dest)
    return(invisible(dest))
  }
  dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
  old <- options(timeout = max(timeout, getOption("timeout", 60))); on.exit(options(old))
  if (!quiet) message("downloading ", url, "\n       -> ", dest)
  utils::download.file(url, dest, mode = "wb", quiet = quiet, method = method)
  if (manifest)
    tryCatch(np_manifest_add(basename(dest), "raw", source = "fetch", url = url,
                             path = dest),
             error = function(e) warning("manifest not updated: ", conditionMessage(e)))
  invisible(dest)
}

#' Fetch the reference BMF (pinned archive)
#'
#' @param which Which BMF file: `"unified"` (active+inactive), `"processed"`
#'   (active only), or `"dictionary"`.
#' @param dest,overwrite,quiet Passed to [np_fetch()].
#' @return The destination path, invisibly.
#' @export
np_fetch_bmf <- function(which = c("unified", "processed", "dictionary"),
                         dest = NULL, overwrite = FALSE, quiet = FALSE, ...) {
  which <- match.arg(which)
  key <- c(unified = "bmf_unified", processed = "bmf_processed",
           dictionary = "bmf_dictionary")[[which]]
  url <- np_source_urls()$url[np_source_urls()$key == key]
  np_fetch(url, dest = dest, overwrite = overwrite, quiet = quiet, ...)
}

#' Fetch a SAM extract (pinned archive or a URL you supply)
#'
#' Downloads the raw pipe-delimited SAM `.dat`. It still needs filtering to
#' nonprofits and column naming before matching — see [np_prepare_sam()].
#'
#' @param url SAM extract URL. Defaults to the pinned archive extract.
#' @param dest,overwrite,quiet Passed to [np_fetch()].
#' @return The destination path, invisibly.
#' @export
np_fetch_sam <- function(url = NULL, dest = NULL, overwrite = FALSE, quiet = FALSE, ...) {
  if (is.null(url)) url <- np_source_urls()$url[np_source_urls()$key == "sam_extract"]
  np_fetch(url, dest = dest, overwrite = overwrite, quiet = quiet, ...)
}

#' SAM public extract column layout
#'
#' The 142 field names of the SAM Master Extract (Public File V2), in order, so
#' the headerless pipe-delimited `.dat` can be named.
#' @return A character vector of length 142.
#' @export
np_sam_layout <- function() {
  c("UNIQUE ENTITY ID","BLANK (DEPRECATED)","ENTITY EFT INDICATOR","CAGE CODE","DODAAC",
    "SAM EXTRACT CODE","PURPOSE OF REGISTRATION","INITIAL REGISTRATION DATE",
    "REGISTRATION EXPIRATION DATE","LAST UPDATE DATE","ACTIVATION DATE","LEGAL BUSINESS NAME",
    "DBA NAME","ENTITY DIVISION NAME","ENTITY DIVISION NUMBER","PHYSICAL ADDRESS LINE 1",
    "PHYSICAL ADDRESS LINE 2","PHYSICAL ADDRESS CITY","PHYSICAL ADDRESS PROVINCE OR STATE",
    "PHYSICAL ADDRESS ZIP/POSTAL CODE","PHYSICAL ADDRESS ZIP CODE +4","PHYSICAL ADDRESS COUNTRY CODE",
    "PHYSICAL ADDRESS CONGRESSIONAL DISTRICT","D&B OPEN DATA FLAG","ENTITY START DATE",
    "FISCAL YEAR END CLOSE DATE","ENTITY URL","ENTITY STRUCTURE","STATE OF INCORPORATION",
    "COUNTRY OF INCORPORATION","BUSINESS TYPE COUNTER","BUS TYPE STRING","PRIMARY NAICS",
    "NAICS CODE COUNTER","NAICS CODE STRING","PSC CODE COUNTER","PSC CODE STRING","CREDIT CARD USAGE",
    "CORRESPONDENCE FLAG","MAILING ADDRESS LINE 1","MAILING ADDRESS LINE 2","MAILING ADDRESS CITY",
    "MAILING ADDRESS ZIP/POSTAL CODE","MAILING ADDRESS ZIP CODE +4","MAILING ADDRESS COUNTRY",
    "MAILING ADDRESS STATE OR PROVINCE","GOVT BUS POC FIRST NAME","GOVT BUS POC MIDDLE INITIAL",
    "GOVT BUS POC LAST NAME","GOVT BUS POC TITLE","GOVT BUS POC ST ADD 1","GOVT BUS POC ST ADD 2",
    "GOVT BUS POC CITY","GOVT BUS POC ZIP/POSTAL CODE","GOVT BUS POC ZIP CODE +4",
    "GOVT BUS POC COUNTRY CODE","GOVT BUS POC STATE OR PROVINCE","ALT GOVT BUS POC FIRST NAME",
    "ALT GOVT BUS POC MIDDLE INITIAL","ALT GOVT BUS POC LAST NAME","ALT GOVT BUS POC TITLE",
    "ALT GOVT BUS POC ST ADD 1","ALT GOVT BUS POC ST ADD 2","ALT GOVT BUS POC CITY",
    "ALT GOVT BUS POC ZIP/POSTAL CODE","ALT GOVT BUS POC ZIP CODE +4","ALT GOVT BUS POC COUNTRY CODE",
    "ALT GOVT BUS POC STATE OR PROVINCE","PAST PERF POC POC  FIRST NAME","PAST PERF POC POC  MIDDLE INITIAL",
    "PAST PERF POC POC  LAST NAME","PAST PERF POC POC  TITLE","PAST PERF POC ST ADD 1",
    "PAST PERF POC ST ADD 2","PAST PERF POC CITY","PAST PERF POC ZIP/POSTAL CODE",
    "PAST PERF POC ZIP CODE +4","PAST PERF POC COUNTRY CODE","PAST PERF POC STATE OR PROVINCE",
    "ALT PAST PERF POC FIRST NAME","ALT PAST PERF POC MIDDLE INITIAL","ALT PAST PERF POC LAST NAME",
    "ALT PAST PERF POC TITLE","ALT PAST PERF POC ST ADD 1","ALT PAST PERF POC ST ADD 2",
    "ALT PAST PERF POC CITY","ALT PAST PERF POC ZIP/POSTAL CODE","ALT PAST PERF POC ZIP CODE +4",
    "ALT PAST PERF POC COUNTRY CODE","ALT PAST PERF POC STATE OR PROVINCE","ELEC BUS POC FIRST NAME",
    "ELEC BUS POC MIDDLE INITIAL","ELEC BUS POC LAST NAME","ELEC BUS POC TITLE","ELEC BUS POC ST ADD 1",
    "ELEC BUS POC ST ADD 2","ELEC BUS POC CITY","ELEC BUS POC ZIP/POSTAL CODE","ELEC BUS POC ZIP CODE +4",
    "ELEC BUS POC COUNTRY CODE","ELEC BUS POC STATE OR PROVINCE","ALT ELEC POC BUS POC FIRST NAME",
    "ALT ELEC POC BUS POC MIDDLE INITIAL","ALT ELEC POC BUS POC LAST NAME","ALT ELEC POC BUS POC TITLE",
    "ALT ELEC POC BUS ST ADD 1","ALT ELEC POC BUS ST ADD 2","ALT ELEC POC BUS CITY",
    "ALT ELEC POC BUS ZIP/POSTAL CODE","ALT ELEC POC BUS ZIP CODE +4","ALT ELEC POC BUS COUNTRY CODE",
    "ALT ELEC POC BUS STATE OR PROVINCE","NAICS EXCEPTION COUNTER","NAICS EXCEPTION STRING",
    "DEBT SUBJECT TO OFFSET FLAG","EXCLUSION STATUS FLAG","SBA BUSINESS TYPES COUNTER",
    "SBA BUSINESS TYPES STRING","NO PUBLIC DISPLAY FLAG","DISASTER RESPONSE COUNTER",
    "DISASTER RESPONSE STRING","ENTITY EVS SOURCE",paste("FLEX FIELD", 1:19),"END OF RECORD INDICATOR")
}

#' Read a raw SAM public extract
#'
#' The extract is headerless, pipe-delimited, and unquoted; this reads it and
#' applies [np_sam_layout()] names.
#'
#' @param path Path to the `.dat` file.
#' @param layout Column names. Default [np_sam_layout()].
#' @return A `data.table`.
#' @export
np_read_sam <- function(path, layout = np_sam_layout()) {
  d <- data.table::fread(path, sep = "|", header = FALSE, fill = TRUE, quote = "",
                         na.strings = c("", "NA"), showProgress = FALSE)
  data.table::setnames(d, layout[seq_len(ncol(d))])
  d
}

#' Filter a SAM extract to nonprofits
#'
#' Keeps SAM registrations whose business-type string carries a nonprofit code
#' (`A8` Non-Profit, `BZ` Foundation, `2U` Other Not-For-Profit, `A7`
#' AbilityOne) — the definition used to build the worked example (see
#' `dev/prototype/IDENTIFY-NONPROFITS.R`).
#'
#' @param sam A SAM data frame (with a business-type-string column), or a path
#'   to a raw `.dat` (read via [np_read_sam()]).
#' @param codes Nonprofit business-type codes to keep.
#' @param bus_type_col Business-type-string column. Auto-detected from
#'   `"BUS TYPE STRING"` / `"bus_type_string"` if `NULL`.
#' @param keep If `TRUE` (default) return only nonprofit rows; if `FALSE` return
#'   all rows with an added logical `is_nonprofit` column.
#' @return The filtered (or flagged) data frame.
#' @export
np_flag_nonprofits <- function(sam, codes = c("A8", "BZ", "2U", "A7"),
                               bus_type_col = NULL, keep = TRUE) {
  if (is.character(sam) && length(sam) == 1 && file.exists(sam)) sam <- np_read_sam(sam)
  if (is.null(bus_type_col))
    bus_type_col <- intersect(c("BUS TYPE STRING", "bus_type_string", "BUS_TYPE_STRING"),
                              names(sam))[1]
  if (is.na(bus_type_col) || is.null(bus_type_col))
    stop("could not find the business-type-string column; set bus_type_col=", call. = FALSE)
  x <- as.character(sam[[bus_type_col]])
  is_np <- grepl(paste(codes, collapse = "|"), x)
  is_np[is.na(is_np)] <- FALSE
  if (keep) sam[is_np, , drop = FALSE]
  else { sam$is_nonprofit <- is_np; sam }
}

#' Download-and-prepare a SAM extract for matching
#'
#' Reads a raw SAM `.dat`, filters to nonprofits, and (optionally) writes the
#' result. The output is ready to pass to [np_cascade()] / [np_match()] with
#' [np_map_sam()] (after the usual header lower-casing).
#'
#' @param path Path to the raw `.dat` (or use [np_fetch_sam()] first).
#' @param out Optional output CSV path. If given, the nonprofit subset is written.
#' @param codes Nonprofit codes (see [np_flag_nonprofits()]).
#' @return The nonprofit subset (invisibly if `out` is written).
#' @export
np_prepare_sam <- function(path, out = NULL, codes = c("A8", "BZ", "2U", "A7")) {
  d  <- np_read_sam(path)
  np <- np_flag_nonprofits(d, codes = codes, keep = TRUE)
  message(sprintf("SAM: %s records -> %s nonprofits (%.1f%%)",
                  format(nrow(d), big.mark = ","), format(nrow(np), big.mark = ","),
                  100 * nrow(np) / max(nrow(d), 1)))
  if (!is.null(out)) { data.table::fwrite(np, out); return(invisible(np)) }
  np
}

#' Retain only source records not already matched (incremental matching)
#'
#' Compares a fresh source table against an existing crosswalk and returns the
#' subset of fresh records that have **not** already been resolved — so a
#' re-run only spends compute on new or previously-unmatched organisations.
#'
#' A record counts as "already matched" if its key appears in the crosswalk
#' with a status in `matched_values` (when a status/tier column is present or
#' named via `status_col`); if no status column is found, any appearance in the
#' crosswalk counts as matched. Set `matched_values = c("YES","MAYBE")` to also
#' retain (re-run) review-pending cases against a refreshed reference.
#'
#' @param fresh Fresh source records (data frame) with an id key.
#' @param crosswalk Existing crosswalk (data frame) with an id key and, ideally,
#'   a tier/status column.
#' @param key_fresh,key_cross Key column names. Auto-detected from
#'   `uei` / `UNIQUE ENTITY ID` / `unique_entity_id` / `.id` if `NULL`.
#' @param status_col Status/tier column in `crosswalk`. Auto-detected from
#'   `tier` / `match_decision` / `status` if `NULL`.
#' @param matched_values Status values that count as already matched.
#' @param quiet Suppress the summary message.
#' @return The retained subset of `fresh`, with an integer `"diff"` attribute
#'   (`fresh`, `already_matched`, `retained`, `new_ids`).
#' @export
np_diff_unmatched <- function(fresh, crosswalk, key_fresh = NULL, key_cross = NULL,
                              status_col = NULL, matched_values = c("YES", "MATCH", "match"),
                              quiet = FALSE) {
  fresh <- as.data.frame(fresh); crosswalk <- as.data.frame(crosswalk)
  find_key <- function(df) {
    cand <- c("uei", "UNIQUE ENTITY ID", "unique_entity_id", ".id", "id")
    hit <- intersect(cand, names(df)); if (length(hit)) hit[1] else names(df)[1]
  }
  kf <- if (is.null(key_fresh)) find_key(fresh) else key_fresh
  kc <- if (is.null(key_cross)) find_key(crosswalk) else key_cross
  fk <- as.character(fresh[[kf]])
  ck <- as.character(crosswalk[[kc]])
  if (is.null(status_col))
    status_col <- intersect(c("tier", "match_decision", "status"), names(crosswalk))[1]
  matched_keys <- if (!is.null(status_col) && !is.na(status_col) && status_col %in% names(crosswalk))
    unique(ck[as.character(crosswalk[[status_col]]) %in% matched_values]) else unique(ck)
  keep <- !(fk %in% matched_keys)
  out  <- fresh[keep, , drop = FALSE]
  summ <- c(fresh = length(fk), already_matched = sum(!keep),
            retained = sum(keep), new_ids = sum(!fk %in% ck))
  attr(out, "diff") <- summ
  if (!quiet)
    message(sprintf(paste0("np_diff_unmatched: %s fresh | %s already matched | ",
                           "%s retained to run (%s brand-new ids)"),
                    format(summ[["fresh"]], big.mark = ","),
                    format(summ[["already_matched"]], big.mark = ","),
                    format(summ[["retained"]], big.mark = ","),
                    format(summ[["new_ids"]], big.mark = ",")))
  out
}
