# ---------------------------------------------------------------------------
# Normalizer signature: a fingerprint of everything a caller may precompute.
#
# Downstream packages (matchdb) cache derived columns -- name_key, street_key,
# zip9 -- and corpus statistics built from them. The *query* side is normalized
# at run time by whatever npmatch is installed. If the normalizer changes after
# an artifact is built, the two sides are normalized differently and recall
# degrades silently: no error, no warning, and a symptom that looks like a data
# problem rather than a version problem.
#
# That is not hypothetical. `.np_strip_joiners()` was rewritten to delete
# apostrophes rather than space them, because the IRS holds "BO'S PLACE" as
# "BOS PLACE" while the old rule produced "BO S PLACE" on the query side. Any
# cached name_key built before that change and read after it is wrong.
#
# The signature exists so a cache can refuse to be used against a normalizer it
# was not built with.
# ---------------------------------------------------------------------------

# What the signature covers. Order within the registry does not matter (the
# per-component hashes are sorted by name before combining), but membership very
# much does -- see .np_signature_exempt below for the counterpart list.
.np_signature_registry <- function() {
  list(
    # --- rule tables consulted by np_normalize() -----------------------------
    tables = c(
      ".np_legal_suffixes", ".np_abbrev", ".np_street_types",
      ".np_generation", ".np_ordinals", ".np_gen_rank", ".np_directions",
      ".np_street_type_set", ".np_state_abbr", ".np_state_codes",
      ".np_unit_pat", ".np_pobox_pat"
    ),
    # --- functions producing the per-row derived columns --------------------
    normalize = c(
      "np_normalize",
      ".np_tokens", ".np_replace_tokens", ".np_strip_joiners", ".np_basic_clean",
      ".np_extract_generation", ".np_extract_numbers", ".np_extract_ordinals",
      ".np_extract_direction", ".np_extract_form", ".np_canon_form",
      ".np_strip_lead_the", ".np_strip_suffix",
      ".np_is_pobox", ".np_extract_unit", ".np_street_key",
      ".np_parse_street", ".np_parse_zip", ".np_to_state_abb"
    ),
    # --- corpus statistics shipped alongside a compiled reference -----------
    corpus = c("np_stopwords", "np_name_freq", "np_token_idf"),
    # --- the blocking index a caller may also cache -------------------------
    index = c(".np_tokenize", ".np_doc_freq")
  )
}

# Deliberately NOT covered: comparison, scoring, veto, selection, tiering. None
# of it is precomputed, so a change there cannot invalidate a cached artifact,
# and folding it in would fire the check on edits that do not matter -- which is
# how a staleness check gets ignored. Listed explicitly (rather than left
# implicit) so `test-signature.R` can assert the two sets partition the
# normalize-path internals, and a newly added rule table fails the test until
# someone classifies it.
.np_signature_exempt <- function() {
  c(".np_collapse_initials", ".np_is_acronymish", ".np_name_overlap",
    ".np_contain_overlap")
}

.np_sig_md5 <- function(x) {
  s <- enc2utf8(paste(x, collapse = "\n"))
  f <- tempfile("npsig")
  on.exit(unlink(f), add = TRUE)
  writeBin(charToRaw(s), f)
  unname(tools::md5sum(f))
}

# Canonical text for one registered object.
#
# Functions are deparsed after utils::removeSource(), which strips srcref and
# with it every comment. That is the point: reformatting or re-commenting must
# not invalidate a cache, while a change to the logic must. `control` is pinned
# rather than left to the default so deparse output does not drift between R
# versions.
.np_sig_text <- function(name, envir = asNamespace("npmatch")) {
  obj <- get(name, envir = envir)
  if (is.function(obj)) {
    paste(deparse(utils::removeSource(obj),
                  width.cutoff = 500L,
                  control = c("keepInteger", "keepNA")),
          collapse = "\n")
  } else {
    nm <- names(obj)
    if (is.null(nm)) nm <- rep("", length(obj))
    paste(nm, as.character(obj), sep = "\t", collapse = "\n")
  }
}

#' Fingerprint the normalizer
#'
#' A hash over everything a caller may legitimately **precompute and cache**: the
#' rule tables and functions behind [np_normalize()], the corpus statistics
#' ([np_name_freq()], [np_token_idf()], [np_stopwords()]), and the tokenizer
#' behind [np_ref_index()].
#'
#' # Why
#'
#' A cached reference stores derived columns — `name_key`, `street_key`, `zip9`
#' — while the query side is normalized at run time by whatever npmatch is
#' installed. Change the normalizer between those two moments and the sides are
#' normalized differently: matches quietly stop being found, with no error and a
#' symptom that reads as a data problem. Stamp this value into an artifact when
#' you build it, compare on load, and **error** on mismatch.
#'
#' # What is covered
#'
#' Only what is precomputable. Comparison, scoring, vetoes, selection and
#' tiering are excluded by design — none of them is cached, so a change there
#' must not invalidate an artifact. A signature that fires on unrelated edits is
#' one people learn to ignore.
#'
#' Function bodies are compared after [utils::removeSource()], so **comments and
#' reformatting leave the signature unchanged while logic changes move it**.
#'
#' # Stability
#'
#' The returned string carries a `v1-` format prefix. If a later npmatch changes
#' *what* is hashed, the prefix changes too, so that is distinguishable from a
#' change to the normalizer itself.
#'
#' @param detail If `TRUE`, also return the per-component hashes, so a mismatch
#'   can be localized to the rule table or function that moved. Default `FALSE`.
#' @return A signature string such as `"v1-a1b2c3d4e5f60718"`. With
#'   `detail = TRUE`, an `np_signature` object carrying that string, the
#'   per-component hashes, and the npmatch version.
#' @seealso [np_normalize()]
#' @examples
#' sig <- np_normalize_signature()
#' sig
#'
#' # which components make it up
#' names(np_normalize_signature(detail = TRUE)$components)
#' @export
np_normalize_signature <- function(detail = FALSE) {
  out <- .np_signature_from(asNamespace("npmatch"))
  if (!detail) return(out$signature)
  structure(c(out,
              list(npmatch_version = as.character(utils::packageVersion("npmatch")))),
            class = "np_signature")
}

# The computation, against an arbitrary environment. Split out so a historical
# check can source an older R/normalize.R into a bare environment and get a
# comparable value -- see dev/probe-signature-history.R, which is what actually
# demonstrates the "moves on logic, not on comments" property against real
# commits rather than synthetic edits.
.np_signature_from <- function(envir) {
  names_all <- sort(unique(unlist(.np_signature_registry(), use.names = FALSE)))
  present <- vapply(names_all, exists, logical(1), envir = envir, inherits = FALSE)
  comp <- vapply(names_all[present],
                 function(n) .np_sig_md5(.np_sig_text(n, envir)), character(1))
  # combine the per-component hashes, not the raw text: a component's hash is
  # then independently reportable and the overall value is order-stable.
  overall <- .np_sig_md5(paste(names(comp), comp, sep = "=", collapse = "\n"))
  list(signature = paste0("v1-", substr(overall, 1L, 16L)),
       components = comp,
       missing = names_all[!present])
}

#' @export
print.np_signature <- function(x, ...) {
  cat("<np_signature>", x$signature, "\n")
  cat("  npmatch", x$npmatch_version, "|", length(x$components), "components\n")
  invisible(x)
}
