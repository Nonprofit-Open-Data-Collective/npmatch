#' npmatch data asset directories
#'
#' npmatch keeps data outside the package (the reference files are large and
#' versioned separately). These helpers resolve and create a consistent on-disk
#' layout with three tiers:
#'
#' * `raw/` — immutable source downloads (BMF, SAM extracts), one per vintage.
#' * `normalized/` — reusable derived assets built once per source vintage
#'   (the normalized reference, the token-IDF table, the name-frequency table).
#' * `results/` — per-run outputs (crosswalks, evaluation frames, run reports).
#'
#' The root is resolved in order from `getOption("npmatch.data")`, the
#' `NPMATCH_DATA` environment variable, then a default of `~/npmatch-data`.
#'
#' @param subdir One of `"raw"`, `"normalized"`, `"results"`, or `""` (the root).
#' @param file Optional file name to append to the resolved directory.
#' @param create Create the directory if it does not exist. Default `FALSE`.
#' @param root Data root directory. Defaults to [np_data_root()].
#' @param quiet Suppress the informational message. Default `FALSE`.
#' @return `np_data_root()` and `np_data_path()` return a path string;
#'   `np_data_init()` returns the root invisibly.
#' @name np_data
#' @examples
#' \dontrun{
#' options(npmatch.data = tempfile("npdata"))
#' np_data_init()
#' np_data_path("normalized", "reference-2026-01.rds")
#' }
#' @export
np_data_root <- function() {
  r <- getOption("npmatch.data")
  if (is.null(r) || !nzchar(r)) r <- Sys.getenv("NPMATCH_DATA", "")
  if (!nzchar(r)) r <- file.path(path.expand("~"), "npmatch-data")
  r
}

#' @rdname np_data
#' @export
np_data_path <- function(subdir = "", file = NULL, create = FALSE) {
  subdir <- as.character(subdir)[1]
  if (!subdir %in% c("", "raw", "normalized", "results"))
    stop("`subdir` must be one of '', 'raw', 'normalized', 'results'.", call. = FALSE)
  p <- if (nzchar(subdir)) file.path(np_data_root(), subdir) else np_data_root()
  if (create && !dir.exists(p)) dir.create(p, recursive = TRUE, showWarnings = FALSE)
  if (!is.null(file)) p <- file.path(p, file)
  p
}

#' @rdname np_data
#' @export
np_data_init <- function(root = np_data_root(), quiet = FALSE) {
  for (s in c("raw", "normalized", "results")) {
    d <- file.path(root, s)
    if (!dir.exists(d)) dir.create(d, recursive = TRUE, showWarnings = FALSE)
  }
  man <- file.path(root, "MANIFEST.csv")
  if (!file.exists(man))
    utils::write.csv(
      data.frame(asset = character(), tier = character(), source = character(),
                 url = character(), download_date = character(), md5 = character(),
                 row_count = integer(), note = character(), stringsAsFactors = FALSE),
      man, row.names = FALSE)
  if (!quiet)
    message("npmatch data root: ", root,
            "\n  raw/  normalized/  results/   + MANIFEST.csv")
  invisible(root)
}

#' Record and read the data-asset manifest
#'
#' The manifest is a small CSV under the data root that records the provenance
#' of every source and derived asset — what it is, where it came from, when it
#' was fetched, its checksum and row count. It is what makes a run reproducible:
#' documentation can point at exact vintages, and a colleague can verify they
#' hold the same bytes.
#'
#' `np_manifest_add()` appends (or replaces, by `asset` name) one row; the `md5`
#' is computed with [tools::md5sum()] when `path` is given and `md5` is not.
#'
#' @param asset Short asset name (also the file's basename), e.g. `"bmf-2026-01"`.
#' @param tier One of `"raw"`, `"normalized"`, `"results"`.
#' @param source Human label of the origin (e.g. `"NCCS BMF catalog"`).
#' @param url Download / origin URL.
#' @param path Optional path to the file, used to auto-fill `md5` and `row_count`.
#' @param md5,row_count Optional explicit checksum / row count (override `path`).
#' @param note Free-text note.
#' @param root Data root. Defaults to [np_data_root()].
#' @return `np_manifest()` returns the manifest data frame; `np_manifest_add()`
#'   returns it invisibly after writing.
#' @name np_manifest
#' @export
np_manifest <- function(root = np_data_root()) {
  man <- file.path(root, "MANIFEST.csv")
  if (!file.exists(man)) np_data_init(root, quiet = TRUE)
  utils::read.csv(man, stringsAsFactors = FALSE)
}

#' @rdname np_manifest
#' @export
np_manifest_add <- function(asset, tier = c("raw", "normalized", "results"),
                            source = NA, url = NA, path = NULL, md5 = NA,
                            row_count = NA, note = NA, root = np_data_root()) {
  tier <- match.arg(tier)
  if (!dir.exists(root)) np_data_init(root, quiet = TRUE)
  if (!is.null(path) && file.exists(path)) {
    if (is.na(md5)) md5 <- unname(tools::md5sum(path))
    if (is.na(row_count))
      row_count <- tryCatch(length(count.fields(path, sep = ",")) - 1L,
                            error = function(e) NA_integer_)
  }
  man  <- file.path(root, "MANIFEST.csv")
  cur  <- np_manifest(root)
  cur  <- cur[cur$asset != asset, , drop = FALSE]           # replace by name
  row  <- data.frame(asset = asset, tier = tier, source = source, url = url,
                     download_date = as.character(Sys.Date()), md5 = md5,
                     row_count = row_count, note = note, stringsAsFactors = FALSE)
  out <- rbind(cur, row)
  utils::write.csv(out, man, row.names = FALSE)
  invisible(out)
}
