# ---------------------------------------------------------------------------
# Normalizer provenance.
#
# np_normalize_signature() (npnormalize's, re-exported in R/reexports.R) is a
# fingerprint of the normalization rules: it moves when a rule moves, and keys
# computed under one value are only comparable to keys computed under the same
# one. The fingerprint is opaque by design, which is what makes it a good
# fingerprint and a poor label -- a bare hash in a provenance file records the
# value and loses the release. npnormalize 0.1.9's np_signature_history() dates
# a signature, so npmatch names the release instead of leaving a reader to look
# it up in NEWS.md (or, worse, writing it in by hand).
# ---------------------------------------------------------------------------

# Format a signature with the release that introduced it:
# "v1-5e901add4a04a5d6 (npnormalize 0.1.8)". This lands in error messages and
# in provenance files, so it must never itself fail; three cases survive:
#   * a signature npnormalize knows     -> package and version named
#   * a known value with no version     -> package named, version withheld
#     (a pre-split npmatch signature that was never written down)
#   * a value npnormalize does not know -> the hash alone, marked unrecognized,
#     which is a different answer from a recognized undated one
.np_sig_label <- function(sig) {
  sig <- as.character(sig)
  if (length(sig) != 1L || is.na(sig) || !nzchar(sig)) return("(none recorded)")
  h <- tryCatch(npnormalize::np_signature_history(sig), error = function(e) NULL)
  if (is.null(h) || !is.data.frame(h) || !nrow(h))
    return(sprintf("%s (unrecognized)", sig))
  pkg <- as.character(h$package[1])
  ver <- as.character(h$version[1])
  if (is.na(ver) || !nzchar(ver))
    return(sprintf("%s (%s, version not recorded)", sig, pkg))
  sprintf("%s (%s %s)", sig, pkg, ver)
}

#' Stamp a run's normalizer provenance
#'
#' Writes `00_bmf/SIGNATURE.txt`: the [np_normalize_signature()] fingerprint of
#' the normalizer that built the cached normalized bundle a run points at,
#' together with the npnormalize release that introduced that fingerprint.
#'
#' The normalized reference, the token-IDF table and the blocking index are
#' built once per reference vintage and reused by every run. If the
#' normalization rules move after the cache was built, the cache is stale and a
#' run over it is not reproducible against current code. The stamp makes that
#' detectable rather than silent.
#'
#' The first line is the bare signature, so a reader that compares
#' `readLines(f)[1]` to [np_normalize_signature()] keeps working — including
#' against the hand-written single-line files this function replaces. The
#' commented lines below it carry the release, the installed npnormalize
#' version and the time of the stamp.
#'
#' Pass `signature` explicitly when stamping a bundle that was *not* built by
#' the installed normalizer — recording an older bundle's real provenance
#' rather than overwriting it with the current value.
#'
#' @param project Project directory. Defaults to the active project
#'   ([np_project_root()]).
#' @param signature The signature to record. Defaults to the installed
#'   normalizer's, which is the right value when the cache was just built.
#' @param overwrite Overwrite an existing `SIGNATURE.txt`? Defaults to `TRUE`:
#'   a stamp records the cache as it now is, so refusing to update it would
#'   leave a stale claim in place.
#'
#' @return The path written, invisibly.
#'
#' @seealso [np_project_init()] creates the folder the stamp lives in;
#'   [np_project_status()] reports whether it is present.
#'
#' @examples
#' p <- file.path(tempdir(), "npp-stamp")
#' np_project_init(p, run_id = "demo", quiet = TRUE, use = FALSE)
#' np_signature_stamp(p)
#' cat(readLines(file.path(p, "00_bmf", "SIGNATURE.txt")), sep = "\n")
#' unlink(p, recursive = TRUE)
#'
#' @export
np_signature_stamp <- function(project = np_project_root(),
                               signature = np_normalize_signature(),
                               overwrite = TRUE) {
  if (length(project) != 1L || is.na(project) || !nzchar(project))
    stop(paste0("no project given and no active one; pass `project` or set it ",
                "with np_project_init(use = TRUE)."), call. = FALSE)
  dir <- file.path(project, "00_bmf")
  if (!dir.exists(dir))
    stop(sprintf("'%s' has no 00_bmf/ folder; run np_project_init() first.",
                 project), call. = FALSE)

  sig <- as.character(signature)
  if (length(sig) != 1L || is.na(sig) || !nzchar(sig))
    stop("`signature` must be a single non-empty string.", call. = FALSE)

  f <- file.path(dir, "SIGNATURE.txt")
  if (file.exists(f) && !overwrite) return(invisible(f))

  installed <- tryCatch(as.character(utils::packageVersion("npnormalize")),
                        error = function(e) NA_character_)
  writeLines(c(
    sig,
    sprintf("# normalizer: %s", .np_sig_label(sig)),
    sprintf("# installed:  npnormalize %s", installed),
    sprintf("# stamped:    %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
    "#",
    "# The first line is the np_normalize_signature() fingerprint of the",
    "# normalizer that built the cached normalized bundle this run points at.",
    "# If np_normalize_signature() stops reporting it, the cache has drifted",
    "# from the current normalization rules and must be rebuilt."
  ), f)
  invisible(f)
}
