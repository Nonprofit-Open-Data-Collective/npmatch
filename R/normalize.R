# Internal dictionaries -------------------------------------------------------

# Legal / organizational suffixes. Detected, recorded, and stripped from the
# match key (they inflate similarity between unrelated orgs).
.np_legal_suffixes <- c(
  "INCORPORATED", "INC", "CORPORATION", "CORP", "COMPANY", "CO",
  "LIMITED", "LTD", "LLC", "LLP", "LP", "PC", "PLLC",
  "ASSOCIATION", "ASSN", "ASSOC", "FOUNDATION", "FDN", "FUND",
  "TRUST", "SOCIETY", "INSTITUTE", "ORGANIZATION", "ORG"
)

# Conservative token expansions to a common form (applied whole-word).
.np_abbrev <- c(
  "ASSOC" = "ASSOCIATION", "ASSN" = "ASSOCIATION", "ASSN'" = "ASSOCIATION",
  "NATL" = "NATIONAL", "NAT" = "NATIONAL", "INTL" = "INTERNATIONAL",
  "INTERNATL" = "INTERNATIONAL", "DEPT" = "DEPARTMENT", "DEPT'" = "DEPARTMENT",
  "UNIV" = "UNIVERSITY", "COMM" = "COMMUNITY", "CTR" = "CENTER",
  "CTR'" = "CENTER", "SVCS" = "SERVICES", "SVC" = "SERVICE",
  "AMER" = "AMERICAN", "MT" = "MOUNT", "ST" = "SAINT",
  # Added from networked990's resolver (990 Schedule R / O names), each checked
  # against its contexts in the unified BMF. PHYS was left out on purpose: in
  # the BMF it is mostly PHYS EDUCATION (physical), not PHYSICIANS.
  "FDN" = "FOUNDATION", "FND" = "FOUNDATION", "FNDTN" = "FOUNDATION",
  "FDTN" = "FOUNDATION", "HOSP" = "HOSPITAL", "MED" = "MEDICAL",
  "HLTH" = "HEALTH", "HLTHCARE" = "HEALTHCARE", "MGMT" = "MANAGEMENT",
  "REG" = "REGIONAL", "RGNL" = "REGIONAL", "CNTR" = "CENTER",
  "SYS" = "SYSTEM", "SYST" = "SYSTEM", "SRVCS" = "SERVICES", "SRVS" = "SERVICES"
)

# Tokens dropped anywhere in `name_core`: connector words and legal forms.
# Descriptive organisation words (FOUNDATION, TRUST, ASSOCIATION, FUND, SOCIETY)
# are kept, unlike the trailing-suffix strip that builds `name_key`, because
# "X" and "X FOUNDATION" are usually two different EINs (a charity and its
# fundraising foundation). Taken from networked990's exact-name resolver.
.np_core_stop <- c(
  "THE", "INC", "INCORPORATED", "CORP", "CORPORATION", "CO", "LLC", "LTD",
  "OF", "AND", "A", "AN", "FOR", "LP", "PC", "DBA"
)

# Placeholder text written where a name should be ("SEE SCHEDULE O", "SEE
# ATTACHED", "VARIOUS"), matched on the raw upper-cased name. From 990 filings,
# where preparers write these in name fields.
.np_placeholder_re <- paste0(
  "^\\s*(SEE|REFER TO|PER|AS PER|LISTED ON|LISTED IN)\\s+(THE\\s+)?",
  "(SCHEDULE|SCHED|SCH|ATTACHED|ATTACHMENT|STATEMENT|STMT|PART|LINE|BELOW|",
  "ABOVE|LIST|ADDENDUM|EXHIBIT|SUPPLEMENTAL|FORM)\\b|",
  "^\\s*(VARIOUS|MULTIPLE|SEE ATTACHED|ATTACHED)\\s*$"
)

# A cleaned name made only of these tokens is a placeholder ("N/A", "NONE",
# "SAME AS ABOVE", "NOT APPLICABLE", "UNKNOWN").
.np_placeholder_tok <- c(
  "NA", "N", "A", "NONE", "NO", "X", "SAME", "UNKNOWN", "NOT", "APPLICABLE",
  "SEE", "ABOVE", "AS", "BELOW", "INAPPLICABLE", "NULL"
)

# USPS street-type standardization (long -> short) for address keys.
.np_street_types <- c(
  "STREET" = "ST", "AVENUE" = "AVE", "BOULEVARD" = "BLVD", "ROAD" = "RD",
  "DRIVE" = "DR", "LANE" = "LN", "COURT" = "CT", "PLACE" = "PL",
  "SQUARE" = "SQ", "HIGHWAY" = "HWY", "PARKWAY" = "PKWY", "CIRCLE" = "CIR",
  "TERRACE" = "TER", "TRAIL" = "TRL", "SUITE" = "STE", "APARTMENT" = "APT",
  "BUILDING" = "BLDG", "FLOOR" = "FL", "NORTH" = "N", "SOUTH" = "S",
  "EAST" = "E", "WEST" = "W"
)

# VESTIGIAL. Generation tokens are a person-name concept (Ken Griffey vs Ken
# Griffey Jr) inherited from npmatch's SAM / USASpending person-matching
# lineage. Organisations do not have generations, no veto rule consumes
# name_gen, and it is not a useful feature here -- see ?np_default_rules. The
# extraction is retained only so existing labeled training extracts keep their
# column layout; drop it and name_gen/name_gen_rank together when those are
# regenerated.
#
# Narrowed to abbreviated JR/SR when it was still wired to a veto: spelled-out
# "JUNIOR"/"SENIOR" are ordinary org words ("Junior League", "Senior Care") and
# roman II-V are series/phase numbers ("Fund II", "Phase III"), and both made
# the rule over-fire massively (found via np_veto_audit). The genuinely useful
# organisation-level analogue is the ordinal extractor below (FIRST/SECOND).
.np_generation <- c("JR", "SR")

# Ordinal words <-> a canonical rank, so "FIRST" != "SECOND" can be vetoed.
.np_ordinals <- c(
  "FIRST" = "1", "1ST" = "1", "SECOND" = "2", "2ND" = "2",
  "THIRD" = "3", "3RD" = "3", "FOURTH" = "4", "4TH" = "4",
  "FIFTH" = "5", "5TH" = "5", "SIXTH" = "6", "6TH" = "6",
  "SEVENTH" = "7", "7TH" = "7", "EIGHTH" = "8", "8TH" = "8",
  "NINTH" = "9", "9TH" = "9", "TENTH" = "10", "10TH" = "10"
)

.np_gen_rank <- c(JR = "2", SR = "1")

# Directional words in a name, canonicalized. Word forms only (single letters
# N/S/E/W are usually initials or street directionals, not org descriptors).
# "Southwest X" vs "Southeast X" are different organisations.
.np_directions <- c(
  NORTH = "N", SOUTH = "S", EAST = "E", WEST = "W",
  NORTHEAST = "NE", NORTHWEST = "NW", SOUTHEAST = "SE", SOUTHWEST = "SW"
)

# Recognised trailing street-type tokens (USPS short forms, post-standardization)
# used to split the street name from its type.
.np_street_type_set <- c(
  "ST","AVE","BLVD","RD","DR","LN","CT","PL","SQ","HWY","PKWY","CIR","TER",
  "TRL","WAY","PLZ","LOOP","PATH","PIKE","RUN","ROW","XING","EXPY","FWY",
  "TPKE","ALY","BND","BR","BRG","CYN","CV","CRK","EST","GDNS","GLN","GRN",
  "HTS","HL","HOLW","JCT","KNL","LK","MNR","MDWS","PT","RDG","SPG","SPGS",
  "TRCE","VLY","VW","VIS","WALK","CTR","XRD","PASS","CRES","GTWY","LNDG",
  "MALL","PARK","CMN","CMNS","BLF","CIR"
)

# Full US state / territory name (uppercase) -> USPS two-letter abbreviation.
.np_state_abbr <- c(
  stats::setNames(datasets::state.abb, toupper(datasets::state.name)),
  "DISTRICT OF COLUMBIA" = "DC", "PUERTO RICO" = "PR", "GUAM" = "GU",
  "VIRGIN ISLANDS" = "VI", "U S VIRGIN ISLANDS" = "VI",
  "AMERICAN SAMOA" = "AS", "NORTHERN MARIANA ISLANDS" = "MP"
)
.np_state_codes <- c(datasets::state.abb, "DC", "PR", "GU", "VI", "AS", "MP")

# Latin letters that are not an accented form of some other letter, and the
# ASCII strings they stand for. De-accenting cannot reach them: there is no mark
# to drop, so an unmapped letter survives to the `[^A-Z0-9 ]` rule in
# .np_basic_clean() and is replaced by a SPACE, which splits the word it sits
# in -- "Strasse Fund" came back as "STRA E FUND", "Oresund" as "RESUND".
#
# ICU's Latin-ASCII covers all of these today, so the table is belt and braces
# against an older ICU (eszett is a comparatively recent addition to that
# transform) and, more to the point, it is the list matchdb's `md_light_key()`
# ports into SQL. The two keys must agree character for character or a cached
# reference key and a run-time query key stop meeting, so the mapping is pinned
# here and exposed through np_name_rules() rather than left to the transform.
#
# Written with \u escapes, not literal glyphs, so this file stays pure ASCII.
.np_special_letters <- c(
  "\u00df" = "SS", "\u1e9e" = "SS",    # eszett, capital eszett
  "\u00d8" = "O",  "\u00f8" = "O",     # O with stroke
  "\u0141" = "L",  "\u0142" = "L",     # L with stroke
  "\u0110" = "D",  "\u0111" = "D",     # D with stroke
  "\u00c6" = "AE", "\u00e6" = "AE",    # ash
  "\u0152" = "OE", "\u0153" = "OE",    # ethel
  "\u00de" = "TH", "\u00fe" = "TH"     # thorn
)

# Helpers ---------------------------------------------------------------------

.np_tokens <- function(x) strsplit(x, "\\s+")

.np_replace_tokens <- function(x, dict) {
  toks <- .np_tokens(x)
  vapply(toks, function(tk) {
    hit <- tk %in% names(dict)
    tk[hit] <- dict[tk[hit]]
    paste(tk, collapse = " ")
  }, character(1))
}

# Intra-word punctuation that must be DELETED rather than turned into a space.
#
# The IRS BMF contains no apostrophes or periods at all -- they are stripped
# upstream, and stripped by deletion: "St. Luke's Hospital" is held as
# "ST LUKES HOSPITAL", not "ST LUKE S HOSPITAL". Source datasets keep them
# (3.5% of 990-PF grantee names carry an apostrophe). Turning them into a space
# therefore splits the possessive on the query side only, and no possessive name
# can ever clear an exact-name pass:
#
#   query "BO'S PLACE" -> "BO S PLACE"   vs   BMF "BOS PLACE"   -> no match
#
# Apostrophes are deleted unconditionally. Periods are deleted only between two
# alphanumerics ("F.I.N.D." -> "FIND"), so a period that already separates words
# ("ST. LUKES") still falls through to the space rule below and keeps its break.
#
# The quote class is written with \u escapes rather than literal glyphs so this
# file stays pure ASCII. De-accenting runs before this in .np_basic_clean() and
# already folds the curly forms to a plain apostrophe; the rest are belt and
# braces for any caller that cleans a string directly.
.np_strip_joiners <- function(x) {
  x <- gsub("['\u2018\u2019\u02BC\u00B4`]", "", x, perl = TRUE)
  gsub("(?<=[A-Za-z0-9])\\.(?=[A-Za-z0-9])", "", x, perl = TRUE)
}

# Fold the letters .np_special_letters names to their ASCII spellings.
.np_map_special <- function(x) {
  stringi::stri_replace_all_fixed(x, names(.np_special_letters),
                                  .np_special_letters, vectorize_all = FALSE)
}

# Upper-casing runs AFTER the two folding steps, not before. R's toupper() is
# per-character, so it leaves a letter whose upper case is two letters alone:
# toupper("Strasse") kept the eszett, Latin-ASCII then produced a LOWERCASE
# "ss", and the final [^A-Z0-9 ] rule blanked it -- "STRA E". Folding first and
# upper-casing the result keeps SS / AE / OE / TH (and ligatures such as "fi"),
# and costs nothing otherwise.
.np_basic_clean <- function(x) {
  x <- .np_map_special(as.character(x))
  x <- stringi::stri_trans_general(x, "Latin-ASCII") # de-accent
  x <- toupper(x)
  x <- gsub("&", " AND ", x, fixed = TRUE)
  x <- .np_strip_joiners(x)          # delete, do not space -- see above
  x <- gsub("[[:punct:]]", " ", x)   # every other mark separates tokens
  x <- gsub("[^A-Z0-9 ]", " ", x)
  stringr::str_squish(x)
}

#' Normalize a query or reference frame
#'
#' Brings entity names and addresses onto a common, matchable form (parity with
#' the BMF `org_name_join` field) and extracts the token-level features the veto
#' layer needs. Adds columns alongside the canonical ones:
#'
#' * `name_key`     cleaned, abbreviation-standardized, legal-suffix-stripped
#' * `dba_key`      the DBA name under the same normalization (for cross-matching)
#' * `name_full`    cleaned name *with* suffix retained
#' * `name_core`    exact-lookup key: `name_full` without connector words and
#'   legal forms anywhere (THE, OF, AND, INC, LLC ...), keeping FOUNDATION,
#'   TRUST, FUND (see [np_name_core()])
#' * `name_placeholder` `TRUE` for names that are not names ("SEE SCHEDULE O",
#'   "N/A", no letters); [np_block()] gives such query rows no candidates
#' * `name_form`    detected legal form (INC / LLC / CORP / ...), or `NA`
#' * `name_gen`, `name_gen_rank` **vestigial** — a person-name generation marker
#'   (`JR` / `SR`, ranked `SR` = 1, `JR` = 2) inherited from npmatch's
#'   person-matching lineage. Organisations do not have generations; nothing in
#'   the package consumes these and they are not useful features. Retained only
#'   for column compatibility with existing labeled extracts. See
#'   [np_default_rules()].
#' * `name_nums`    space-joined embedded digit tokens (chapter/local numbers)
#' * `name_ord`     canonical ordinal rank(s) found in the name
#' * `street_key`   USPS-standardized street with unit stripped
#' * `street_num`   leading house / box number
#' * `street_name`  street body with the number, type, and unit removed
#' * `street_type`  trailing street type (ST / AVE / BLVD / WAY / ...), or `NA`
#' * `street_unit`  the suite / floor / unit as written, normalized to
#'   "<designator> <id>" ("STE 300", "FL 2", "# 12"). Read from the street line,
#'   or from the `unit` column when the street line names none
#' * `street_unit_id` the identifier alone, separators dropped ("STE D-2" ->
#'   "D2"). Two records are compared on this, so a BMF "STE 300" and a source
#'   "# 300" are recognised as one office
#' * `is_po_box`    `TRUE` if the street is a PO box (any variant), else `FALSE`
#' * `zip5`         five-digit ZIP, leading zeros restored (nested prefix)
#' * `zip3`         three-digit ZIP prefix / SCF region (nested prefix)
#' * `zip9`         full `xxxxx-xxxx` ZIP when the +4 is known, else `NA`
#'
#' The ZIP match hierarchy is the nested prefix family `zip3` \eqn{\subset}
#' `zip5` \eqn{\subset} `zip9`. The +4 add-on (`zip_plus4`) is an input only,
#' consumed to build `zip9`; it is not a standalone level.
#' * `state_abb`    two-letter state code (mapped from a full state name if given)
#'
#' @param data An `np_query` or `np_reference` frame from [np_query()] /
#'   [np_reference()].
#' @return The same frame with the normalization columns added.
#' @export
np_normalize <- function(data) {
  nm  <- .np_basic_clean(data$name)
  nm  <- .np_replace_tokens(nm, .np_abbrev)

  data$name_gen      <- .np_extract_generation(nm)
  data$name_gen_rank <- unname(.np_gen_rank[data$name_gen])
  data$name_nums     <- .np_extract_numbers(nm)
  data$name_ord      <- .np_extract_ordinals(nm)
  data$name_dir      <- .np_extract_direction(nm)
  data$name_form     <- .np_extract_form(nm)
  data$name_full     <- nm
  # strip a leading "THE" from the match key: it shifts the string and sinks the
  # Jaro-Winkler score (no prefix boost) so "THE X FOUNDATION" would otherwise
  # fail to match "X FOUNDATION" -- a real false negative found in labelling.
  data$name_key      <- .np_strip_lead_the(.np_strip_suffix(nm))
  data$name_core     <- .np_name_core(nm)
  data$name_core[is.na(data$name)] <- ""
  data$name_placeholder <- .np_is_placeholder(data$name, nm)

  # DBA key: same normalization as the name, for exact DBA cross-matching.
  dv <- data$dba; dv[is.na(dv)] <- ""
  data$dba_key <- .np_strip_lead_the(
    .np_strip_suffix(.np_replace_tokens(.np_basic_clean(dv), .np_abbrev)))

  # Division key: a second alternate-name field (SAM's entity_division_name),
  # normalized like the DBA so it can be cross-matched independently.
  dv2 <- if (!is.null(data$division)) as.character(data$division) else
    rep(NA_character_, nrow(data))
  dv2[is.na(dv2)] <- ""
  data$division_key <- .np_strip_lead_the(
    .np_strip_suffix(.np_replace_tokens(.np_basic_clean(dv2), .np_abbrev)))

  data$street_unit <- .np_extract_unit(data$street, data$unit)
  data$street_unit_id <- .np_unit_id(data$street_unit)
  sk  <- .np_street_key(data$street)
  pob <- .np_is_pobox(sk)
  box <- stringr::str_extract(sk, "[0-9]+")               # PO boxes carry one number
  sk[pob] <- ifelse(!is.na(box[pob]), paste("PO BOX", box[pob]), "PO BOX")
  data$street_key <- sk
  data$is_po_box  <- pob
  sp <- .np_parse_street(sk)
  data$street_num  <- sp$street_num
  data$street_name <- sp$street_name
  data$street_type <- sp$street_type

  zp <- .np_parse_zip(data$zip5, data$zip_plus4)
  data$zip5 <- zp$zip5
  data$zip3 <- zp$zip3
  data$zip9 <- zp$zip9

  data$state_abb <- .np_to_state_abb(data$state)

  data
}

# Exact-lookup key: the cleaned name without connector words and legal forms
# (see .np_core_stop). Blank when nothing is left.
.np_name_core <- function(nm) {
  out <- vapply(.np_tokens(nm), function(tk)
    paste(tk[nzchar(tk) & !tk %in% .np_core_stop], collapse = " "), character(1))
  out[is.na(nm)] <- ""
  out
}

# TRUE when a name is not usable as a name: blank, placeholder text ("SEE
# SCHEDULE O"), only placeholder tokens ("N/A", "SAME AS ABOVE"), or no letters
# ("100", a misread share). `raw` is the name as written, `nm` the cleaned one.
.np_is_placeholder <- function(raw, nm) {
  raw <- toupper(as.character(raw)); raw[is.na(raw)] <- ""
  nm <- as.character(nm); nm[is.na(nm)] <- ""
  tok <- paste0("(", paste(.np_placeholder_tok, collapse = "|"), ")")
  !grepl("[A-Z]", nm) |
    grepl(.np_placeholder_re, raw, perl = TRUE) |
    grepl(paste0("^", tok, "( ", tok, ")*$"), nm)
}

#' Exact-lookup name key and placeholder check for raw name strings
#'
#' `np_name_core()` cleans a name the way [np_normalize()] does (special
#' letters folded to ASCII, de-accented, upper-cased, `&` to AND, possessives
#' joined, abbreviations expanded), then
#' drops connector words and legal forms anywhere in the name (THE, OF, AND,
#' INC, CORP, LLC ...). Unlike `name_key` it keeps FOUNDATION, TRUST,
#' ASSOCIATION and FUND, so a charity and its foundation get different keys.
#' Use it for exact lookups where a key must point to one organisation.
#'
#' `np_name_placeholder()` is `TRUE` for names that are not names: blank,
#' "SEE SCHEDULE O", "N/A", "SAME AS ABOVE", or no letters at all.
#'
#' @param x Character vector of names as written.
#' @return `np_name_core()`: character vector of keys ("" when nothing is
#'   left). `np_name_placeholder()`: logical vector.
#' @examples
#' np_name_core(c("The Pueblo Zoological Society", "Pueblo Zoological Society Foundation"))
#' np_name_placeholder(c("SEE SCHEDULE O", "N/A", "Acme Fdn"))
#' @export
np_name_core <- function(x) {
  out <- .np_name_core(.np_clean_name(x))
  out[is.na(x)] <- ""      # the cleaner turns NA into the token "NA"
  out
}

#' @rdname np_name_core
#' @export
np_name_placeholder <- function(x) .np_is_placeholder(x, .np_clean_name(x))

# The shared first stage of every name key: clean, then expand abbreviations.
.np_clean_name <- function(x) .np_replace_tokens(.np_basic_clean(x), .np_abbrev)

#' Name-normalization rule tables
#'
#' The tables [np_normalize()] uses, for packages that need the same rules in
#' another engine (for example a DuckDB SQL macro). A port should be checked
#' against [np_name_core()] on test strings; the tables are covered by
#' [np_normalize_signature()].
#'
#' @return A list: `abbrev` (named character, token to expansion),
#'   `core_stop` (tokens dropped from `name_core`), `legal_suffixes`
#'   (trailing tokens stripped from `name_key`), `special_letters` (named
#'   character, a non-decomposable Latin letter to its ASCII spelling, folded
#'   before de-accenting), `placeholder_re` (a Perl regex on the raw
#'   upper-cased name) and `placeholder_tok`.
#' @export
np_name_rules <- function() {
  list(abbrev = .np_abbrev, core_stop = .np_core_stop,
       legal_suffixes = .np_legal_suffixes,
       special_letters = .np_special_letters,
       placeholder_re = .np_placeholder_re, placeholder_tok = .np_placeholder_tok)
}

.np_extract_generation <- function(x) {
  toks <- .np_tokens(x)
  vapply(toks, function(tk) {
    hit <- tk[tk %in% .np_generation]
    if (length(hit)) hit[[1]] else NA_character_
  }, character(1))
}

.np_extract_numbers <- function(x) {
  m <- regmatches(x, gregexpr("[0-9]+", x))
  vapply(m, function(v) if (length(v)) paste(sort(v), collapse = " ") else NA_character_,
         character(1))
}

.np_extract_ordinals <- function(x) {
  toks <- .np_tokens(x)
  vapply(toks, function(tk) {
    hit <- tk[tk %in% names(.np_ordinals)]
    if (length(hit)) paste(sort(unique(.np_ordinals[hit])), collapse = " ")
    else NA_character_
  }, character(1))
}

.np_extract_direction <- function(x) {
  toks <- .np_tokens(x)
  vapply(toks, function(tk) {
    hit <- tk[tk %in% names(.np_directions)]
    if (length(hit)) paste(sort(unique(.np_directions[hit])), collapse = " ")
    else NA_character_
  }, character(1))
}

.np_extract_form <- function(x) {
  toks <- .np_tokens(x)
  vapply(toks, function(tk) {
    hit <- tk[tk %in% .np_legal_suffixes]
    if (length(hit)) .np_canon_form(hit[[length(hit)]]) else NA_character_
  }, character(1))
}

# Collapse synonymous legal forms so INC == INCORPORATED, etc.
.np_canon_form <- function(f) {
  map <- c(INCORPORATED = "INC", CORPORATION = "CORP", COMPANY = "CO",
           LIMITED = "LTD", ASSOCIATION = "ASSN", ASSOC = "ASSN",
           FDN = "FOUNDATION", ORGANIZATION = "ORG")
  ifelse(f %in% names(map), map[f], f)
}

# Drop a single leading "THE " (keeps names like "THEATER" intact).
.np_strip_lead_the <- function(x) {
  out <- sub("^THE ", "", x)
  ifelse(nzchar(out), out, x)          # never blank the whole name
}

.np_strip_suffix <- function(x) {
  toks <- .np_tokens(x)
  out <- vapply(toks, function(tk) {
    keep <- !(tk %in% .np_legal_suffixes)
    # only strip trailing suffixes, keep interior words like "FUND" in a name
    n <- length(tk)
    while (n >= 1 && tk[n] %in% .np_legal_suffixes) n <- n - 1
    paste(tk[seq_len(max(n, 0))], collapse = " ")
  }, character(1))
  out <- stringr::str_squish(out)
  ifelse(out == "", stringr::str_squish(vapply(toks, paste, character(1),
                                               collapse = " ")), out)
}

# Secondary-unit designators and the canonical short form each normalizes to.
# Keys are the spellings that appear in address text, values the USPS
# Publication 28 Appendix C2 abbreviation. The pattern below is built in
# decreasing key length so SUITE wins over STE.
#
# The list is the C2 set filtered against the 1.9M-row unified BMF rather than
# adopted wholesale (dev/scan-unit-designators.R). C2's FRNT, REAR, LOWR, UPPR,
# OFC, PH, PIER, KEY, SIDE and SLIP are left out: in this corpus what they match
# is street names -- PIERCE ST, KEYSER AVE, SIDEHILL RD, N FRNT ST -- not units.
# NO is left out for a sharper reason: it is North far more often than Number
# ("123 NO 5TH ST"), so unlike the others it would delete a real street token.
.np_unit_designators <- c(
  SUITE = "STE",   STE  = "STE",   APARTMENT = "APT", APT = "APT",
  UNIT  = "UNIT",  ROOM = "RM",    RM  = "RM",        BLDG = "BLDG",
  FLOOR = "FL",    FL   = "FL",    PMB = "PMB",
  SPACE = "SPC",   SPC  = "SPC",   LOT = "LOT",       TRLR = "TRLR",
  DEPT  = "DEPT",  STOP = "STOP",  BSMT = "BSMT",     LBBY = "LBBY",
  HNGR  = "HNGR",  NUMBER = "#",   NUM = "#"
)

# ONE pattern for both extracting the unit and removing it from the street key,
# because two patterns drifted: the extractor allowed "#" and the key strip did
# not, so "123 MAIN ST # 300" recorded unit "# 300" and still keyed as
# "123 MAIN ST 300".
#
# Three guards the old pattern lacked, each measured on the unified BMF:
#
# * A word boundary before the designator. Without it the match ran inside
#   ordinary words -- "SHERMAN WAY" gave RM = "AN WAY", "INDIGO BROOM LOOP" gave
#   RM = "OOM LOOP" and keyed as "10317 INDIGO B". 27,954 rows (11.3% of all
#   extractions) were false this way.
# * A separator before an ALPHABETIC id, which stops a designator that merely
#   starts a word: STERLING, STEWART, WESTERN, VERMONT, BARNSTEAD, UNITY,
#   FLAGLER. In 3,636 rows the false match also MASKED the real unit --
#   "259 N RADNOR CHESTER RD STE 150" extracted "STER", from inside CHESTER.
# * An alphabetic id is a SINGLE letter plus optional digits (STE C, APT D-2,
#   SPC F20, RM C281) and must end on a word boundary. A multi-letter id is
#   almost always the next word of a street name, so "LOCKHART TRLR CT RD" no
#   longer loses "TRLR CT" and "LBBY UNIT" is not a unit called UNIT.
#
# A numeric id may follow with no separator at all ("ROOM216", "STE#12"), which
# is why the alternation splits on whether the id starts with a digit.
.np_unit_pat <- local({
  d  <- names(.np_unit_designators)
  d  <- paste(d[order(-nchar(d))], collapse = "|")
  nm <- "[0-9][0-9A-Z-]*"              # numeric id: 300, 12-B, 216
  al <- "(?:[A-Z][0-9-]*|[A-Z]{2}[0-9][0-9A-Z-]*)"  # C, D-2, F20, C281, NO274
  # Floors are the one designator usually written AFTER the number ("2ND FLOOR",
  # "- 2ND FL"), so they get their own branch, capped at three digits so a
  # stray ZIP at the end of a street line ("... FL 33101") cannot read as a floor.
  paste0("(?:#[ .,]*(?:", nm, "|", al, ")",
         "|\\b[0-9]{1,3}(?:ST|ND|RD|TH)?[ .,-]*(?:FLOOR|FL)",
         "|\\b(?:", d, ")(?:[ .,]*#?[ .,]*", nm, "|[ .,]+#?[ .,]*", al, "))\\b")
})

# PO-box variants on an already-cleaned street key: "PO BOX 12", "P O BOX 12",
# "POBOX 12", "POB 12", "PO B 12", "PO 12", "P O 12", "BOX 12". Ordered so the
# longest prefix wins; each must be followed by the box number.
.np_pobox_pat <- "^(P ?O ?BOX|P ?O ?B|BOX|P ?O) ?#? ?[0-9]+"

.np_is_pobox <- function(street_key) {
  s <- toupper(as.character(street_key)); s[is.na(s)] <- ""
  grepl(.np_pobox_pat, s)
}

# The unit as written, normalized to "<canonical designator> <id>" ("STE 300",
# "FL 2", "# 12"), or NA when the address names none.
#
# `unit` is the canonical second address line and is consulted only when the
# street line itself carries no unit. Ignoring it was a quiet penalty, not just
# a gap: SAM keeps the suite there (physical_address_line_2) and
# np_detect_geo() selects the street_unit_full profile on that column's
# coverage, so the profile fired *because* the data was present while the
# compared column was NA on every query row -- a unit similarity of 0 on every
# pair. A bare value is accepted from that field ("300", "D-2"), since a
# dedicated unit column needs no designator to say what it is.
.np_extract_unit <- function(street, unit = NULL) {
  s <- toupper(as.character(street)); s[is.na(s)] <- ""
  out <- .np_norm_unit(stringr::str_extract(s, .np_unit_pat))
  if (!is.null(unit)) {
    u <- toupper(stringr::str_squish(as.character(unit))); u[is.na(u)] <- ""
    alt <- .np_norm_unit(stringr::str_extract(u, .np_unit_pat))
    bare <- is.na(alt) & grepl("^[0-9A-Z][0-9A-Z-]*$", u)
    alt[bare] <- .np_norm_unit(paste("#", u[bare]))
    out <- ifelse(is.na(out), alt, out)
  }
  out
}

# "Suite 300" / "STE. 300" / "#300" / "ROOM216" -> "STE 300" / "# 300" / "RM 216";
# the postfix floor form "2ND FLOOR" -> "FL 2".
.np_norm_unit <- function(m) {
  post <- grepl("(FLOOR|FL)$", m)
  d  <- stringr::str_extract(m, "^(#|[A-Z]+)")
  id <- .np_unit_id(m)
  id[post] <- stringr::str_extract(m[post], "^[0-9]+")
  # "FL 11TH", "11TH FL" and "FL 11" are one floor
  id <- sub("^([0-9]+)(ST|ND|RD|TH)$", "\\1", id)
  canon <- ifelse(post, "FL",
            ifelse(is.na(d) | d == "#", "#", unname(.np_unit_designators[d])))
  ifelse(is.na(m) | is.na(id) | !nzchar(id), NA_character_, paste(canon, id))
}

# The identifier alone, separators dropped: "STE D-2" -> "D2", "# 300" -> "300".
# This is what two records are compared on, because the designator is spelling
# rather than information: "STE 300", "Suite 300" and "# 300" are one office,
# and a BMF record that writes STE against a SAM record that writes # should not
# read as a conflict.
.np_unit_id <- function(x) {
  v  <- toupper(as.character(x))
  id <- sub("^(#|[A-Z]+)[ .,]*#?[ .,]*", "", v)
  id <- gsub("[^A-Z0-9]", "", id)
  ifelse(is.na(v) | !nzchar(id), NA_character_, id)
}

.np_street_key <- function(street) {
  # The unit comes out BEFORE cleaning, with the pattern that extracts it: "#"
  # only exists at this point (.np_basic_clean() turns it into a space), which
  # is why the old post-cleaning strip left "123 MAIN ST # 300" keyed as
  # "123 MAIN ST 300".
  s <- toupper(as.character(street))
  s <- gsub(.np_unit_pat, " ", s, perl = TRUE)
  s <- .np_basic_clean(s)
  s <- .np_replace_tokens(s, .np_street_types)
  stringr::str_squish(s)
}

# Collapse consecutive single-letter tokens into one ("F O R" -> "FOR").
.np_collapse_initials <- function(toks) {
  if (!length(toks)) return(toks)
  out <- character(0); buf <- ""
  for (t in toks) {
    if (nchar(t) == 1) buf <- paste0(buf, t)
    else { if (nzchar(buf)) { out <- c(out, buf); buf <- "" }; out <- c(out, t) }
  }
  if (nzchar(buf)) out <- c(out, buf)
  out
}

.np_is_acronymish <- function(t) grepl("^[A-Z]{2,6}$", t)

#' Name-key frequency table for a reference corpus
#'
#' Counts how many reference records share each exact `name_key`. A name that
#' occurs once or twice is distinctive (an exact match to it is trustworthy even
#' without address corroboration); a name shared by many records (e.g.
#' "FIRST BAPTIST CHURCH") is not. Used by the distinctive-exact-name promotion
#' in `np_score(method = "hier")`. This is more robust than summed token IDF,
#' which conflates distinctiveness with name length.
#'
#' @param name_keys Character vector of normalized names (reference `name_key`).
#' @return A named integer vector mapping `name_key` -> record count.
#' @export
np_name_freq <- function(name_keys) {
  tab <- table(toupper(as.character(name_keys)))
  stats::setNames(as.integer(tab), names(tab))
}

#' Address-sharing statistics for a reference corpus
#'
#' Counts how many reference records sit at each exact address, at each address
#' + suite, and how many distinct suites each address carries. This is what
#' makes a suite match *interpretable* rather than merely true:
#'
#' * **One address, many distinct suites** — an office building let to many
#'   nonprofits, common in cities and often a foundation's building rented out
#'   to centralize back-office services. Here the suite is the differentiator,
#'   precisely because an exact-address match surfaces every tenant as a
#'   candidate.
#' * **One address + suite shared by many records** — a fiscal sponsor, a
#'   registered agent, or an accountant's mail drop. The suite is then evidence
#'   of nothing, and the address is worth flagging to a reviewer instead.
#'
#' Feed the result to [np_compare()] (`addr_freq =`), which annotates each pair
#' with `addr_shared`, `addr_units`, `addr_unit_shared` and a reviewer-facing
#' `addr_note`, and gates the suite credit in `np_score(method = "hier")`.
#'
#' @param street_keys Normalized street (reference `street_key`).
#' @param zip5 Five-digit ZIP, so one street name in two towns is two addresses.
#' @param unit_ids Normalized unit identifiers (reference `street_unit_id`),
#'   `NA` where a record names no unit.
#' @param name_keys Normalized names (reference `name_key`). Optional, but
#'   without them an address cannot be classified: the share of records
#'   carrying the most common name is what separates a federated parent from a
#'   fiscal sponsor, and counts alone cannot.
#' @param share_min Count above which an address, or an address + suite, counts
#'   as *shared*. Default 10: below that, repeats are usually variants of one
#'   organisation — an org, its foundation, its auxiliary — rather than a
#'   multi-tenant building or a sponsor's mail drop.
#' @param unit_coverage_min Share of the records at an address that must name a
#'   suite before "several distinct suites here" is read as a fact about the
#'   building rather than about the data. Default 0.5.
#' @return An `np_addr_freq` list: `addr` (records per address), `addr_unit`
#'   (records per address + suite), `units` (distinct suites per address),
#'   `unit_coverage`, `n_names`, `top_name_share`, `class` (one of
#'   `"federated"`, `"shared"`, `"building"`, `"cluster"`), `share_min` and
#'   `unit_coverage_min`.
#' @seealso [np_name_freq()], [np_compare()]
#' @export
np_addr_freq <- function(street_keys, zip5 = NULL, unit_ids = NULL,
                         name_keys = NULL, share_min = 10L,
                         unit_coverage_min = 0.5) {
  a <- .np_addr_key(street_keys, zip5)
  u <- if (is.null(unit_ids)) rep(NA_character_, length(a)) else as.character(unit_ids)
  ok    <- nzchar(a)
  has_u <- ok & !is.na(u) & nzchar(u)
  addr  <- table(a[ok])
  aunit <- table(paste(a[has_u], u[has_u], sep = "|"))
  units <- tapply(u[has_u], a[has_u], function(v) length(unique(v)))
  n_addr <- stats::setNames(as.integer(addr), names(addr))
  n_unit <- stats::setNames(as.integer(units), names(units))

  # Share of the records at an address that name a suite at all. Without it,
  # "two or more distinct suites here" describes the DATA as easily as the
  # building: at the 4,417 BMF addresses holding 10+ records the share naming a
  # suite has median 0.73 and mean 0.52, and at 1,601 of them not one record
  # names a suite. A suite match is only informative where the reference
  # actually records suites at that address.
  wu  <- stats::setNames(as.integer(table(a[has_u])), names(table(a[has_u])))
  cov <- stats::setNames(rep(0, length(n_addr)), names(n_addr))
  cov[names(wu)] <- wu / n_addr[names(wu)]

  # Distinct names at the address, and the share of records carrying the single
  # most common one. This is what separates the two crowded-address archetypes,
  # which counts alone cannot: a federated parent (3700 GRAND AVE: 5,965
  # records, 45 distinct name_keys, 0.98) against a fiscal sponsor (501
  # SILVERSIDE RD: 1,933 records, 1,931 names, 0.00).
  nk <- if (is.null(name_keys)) NULL else as.character(name_keys)
  if (!is.null(nk)) {
    n_names <- vapply(split(nk[ok], a[ok]), function(v) length(unique(v)), integer(1))
    top_shr <- vapply(split(nk[ok], a[ok]), function(v) max(table(v)) / length(v),
                      numeric(1))
  } else {
    n_names <- stats::setNames(rep(NA_integer_, length(n_addr)), names(n_addr))
    top_shr <- stats::setNames(rep(NA_real_, length(n_addr)), names(n_addr))
  }

  structure(list(
    addr      = n_addr,
    addr_unit = stats::setNames(as.integer(aunit), names(aunit)),
    units     = n_unit,
    unit_coverage  = cov,
    n_names        = n_names[names(n_addr)],
    top_name_share = top_shr[names(n_addr)],
    class     = .np_addr_class(n_addr, n_unit, cov, top_shr[names(n_addr)],
                               share_min, unit_coverage_min),
    share_min = as.integer(share_min),
    unit_coverage_min = as.numeric(unit_coverage_min)), class = "np_addr_freq")
}

# Label an address by what it is, which decides what its evidence is worth.
# Deliberately four coarse labels, each one a different answer to "can this
# address, or a suite within it, separate two candidates":
#
#   federated  many records, one name dominating -- a national office its
#              chapters all file from. The address matches every chapter
#              equally, and so does the suite; the chapter number (name_nums)
#              is the only discriminator, and np_veto() already uses it.
#   shared     many records, many names -- a fiscal sponsor, a registered
#              agent, an accountant. The address is true but uninformative;
#              the NAME does the separating here, which is why damping the
#              address credit measurably does not help (dev note section 9).
#   building   many records across several recorded suites -- the suite is the
#              discriminator, and the only case the suite credit fires in.
#   cluster    a handful of records, usually an org with its foundation or
#              auxiliary. Neither address nor suite helps; the name logic does.
#
# Addresses holding one record are absent from the table entirely -- a lookup
# miss means exactly that, which is 88% of addresses.
.np_addr_class <- function(n_addr, n_unit, cov, top_share, share_min,
                           unit_coverage_min) {
  cls <- rep("cluster", length(n_addr))
  nm  <- names(n_addr)
  big <- n_addr >= share_min
  u   <- n_unit[nm]; u[is.na(u)] <- 0L
  ts  <- top_share[nm]
  cls[big] <- "shared"
  cls[big & u >= 2 & cov[nm] >= unit_coverage_min] <- "building"
  cls[big & !is.na(ts) & ts >= 0.5] <- "federated"
  cls[n_addr < 2] <- "single"
  stats::setNames(cls, nm)
}

# The address a suite is read against: street + ZIP, so "123 MAIN ST" in two
# towns is two addresses. PO boxes are excluded -- a box number IS the address,
# so counting records at one counts the box's owners, not a building's tenants.
.np_addr_key <- function(street_keys, zip5 = NULL) {
  s <- toupper(as.character(street_keys)); s[is.na(s)] <- ""
  z <- if (is.null(zip5)) rep("", length(s)) else as.character(zip5)
  z[is.na(z)] <- ""
  out <- ifelse(nzchar(s), paste(s, z), "")
  out[grepl(.np_pobox_pat, s)] <- ""
  out
}

#' @export
print.np_addr_freq <- function(x, ...) {
  cat("<np_addr_freq>\n")
  cat(sprintf("  addresses: %d | with a suite: %d | shared above: %d\n",
              length(x$addr), length(x$units), x$share_min))
  if (!is.null(x$class)) {
    tb <- table(x$class)
    cat(sprintf("  %s\n", paste(sprintf("%s %d", names(tb), tb), collapse = " | ")))
  }
  invisible(x)
}

#' Per-token inverse document frequency for a reference corpus
#'
#' Document frequency of each name token across the reference, turned into
#' `idf = log(N / df)`: rare tokens (distinctive, high IDF) are the ones the
#' name-token blocking leverages; corpus-common tokens (low IDF) are not. Feed
#' the result to [np_route()] (`token_idf =`) to annotate the tokenized name
#' fields with each token's rarity, exposing which tokens carry the match.
#'
#' @param name_keys Character vector of normalized names (reference `name_key`).
#' @param stopwords Tokens to drop (see [np_stopwords()]).
#' @param min_token_len Minimum token length to count. Default 2.
#' @return A named numeric vector mapping token -> IDF.
#' @export
np_token_idf <- function(name_keys, stopwords = np_stopwords(), min_token_len = 2L) {
  v <- as.character(name_keys); v[is.na(v)] <- ""
  toks <- strsplit(toupper(v), "\\s+")
  ut <- lapply(toks, function(t)
    unique(t[nchar(t) >= min_token_len & !(t %in% stopwords)]))
  df <- table(unlist(ut, use.names = FALSE))
  idf <- log(length(v) / as.numeric(df))
  stats::setNames(idf, names(df))
}

# Token-set + acronym-aware name overlap: matched token "units" over the longer
# name. Catches word-reorder ("Heritage Museum of Newaygo County" <-> "Newaygo
# County Museum Heritage Center"), typos, and acronym/expansion pairs ("EMS" <->
# "Emergency Medical Service", "F O R" <-> "Focus On Renewal") that Jaro-Winkler
# on the joined string scores near 0. Returns 0..1.
.np_name_overlap <- function(ta, tb) {
  ta <- .np_collapse_initials(ta); tb <- .np_collapse_initials(tb)
  if (!length(ta) || !length(tb)) return(0)
  ma <- logical(length(ta)); mb <- logical(length(tb)); collapsed <- 0L

  for (i in seq_along(ta)) {                        # exact token matches
    j <- which(!mb & tb == ta[i])
    if (length(j)) { ma[i] <- TRUE; mb[j[1]] <- TRUE }
  }
  run_match <- function(acr, toks, used) {          # run whose initials spell acr
    L <- nchar(acr); n <- length(toks)
    if (n < L) return(NULL)
    for (s in seq_len(n - L + 1)) {
      idx <- s:(s + L - 1)
      if (all(!used[idx]) &&
          paste0(substr(toks[idx], 1, 1), collapse = "") == acr) return(idx)
    }
    NULL
  }
  for (i in which(!ma & vapply(ta, .np_is_acronymish, logical(1)))) {
    idx <- run_match(ta[i], tb, mb)
    if (!is.null(idx)) { ma[i] <- TRUE; mb[idx] <- TRUE; collapsed <- collapsed + length(idx) - 1L }
  }
  for (j in which(!mb & vapply(tb, .np_is_acronymish, logical(1)))) {
    idx <- run_match(tb[j], ta, ma)
    if (!is.null(idx)) { mb[j] <- TRUE; ma[idx] <- TRUE; collapsed <- collapsed + length(idx) - 1L }
  }
  sum(ma) / max(length(ta), length(tb) - collapsed)
}

# Containment-aware name overlap for the review-tier recovery path. Unlike
# .np_name_overlap (max denominator, so a fully-contained short name is penalised
# by the longer name's extra words), this scores coverage of the *smaller*
# informative token set -- "BAPTIST BIBLE COLLEGE" fully inside "BAPTIST BIBLE
# COLLEGE AND GRADUATE SCHOOL" -> ~1.0, not 0.5. Requires >= 2 shared informative
# tokens AND, when a token-IDF map is supplied, at least one *distinctive* shared
# token (idf >= idf_min), so generic shared words ("COMMUNITY HOUSING") don't
# trigger it. Falls back to the acronym-aware .np_name_overlap so YWCA-style
# matches still register. The result feeds a MAYBE-capped recovery in np_score:
# containment alone is ambiguous (parent vs subsidiary vs chapter share tokens),
# so it surfaces for review, never auto-accepts.
# Sliding-window partial ratio: the best normalised Levenshtein similarity of
# the shorter string against any equal-length window of the longer one -- the
# fuzzywuzzy partial_ratio, and the canonical substring matcher. Unlike
# Jaro-Winkler it credits an INFIX, not only a shared prefix.
#
# Measured in pfmatch dev/NAME-METRIC-EVALUATION.md: on the hard cases it finds
# 17 of 21 while admitting only 6 wrong names, against Jaro-Winkler's 16 and 11.
# Like containment it cannot separate a parent from a chapter ("GIRLS" scores 1.0
# against both "GIRLS INC OF WASHINGTON COUNTY" and an org named "GIRLS"), so
# np_compare() routes it into the MAYBE-capped recovery rather than the JW term.
#
# Cost is O(|long| - |short|) distance calls per pair, so callers must restrict
# it to a small subset rather than running it over every candidate.
.np_partial_ratio <- function(a, b) {
  a <- ifelse(is.na(a), "", a); b <- ifelse(is.na(b), "", b)
  vapply(seq_along(a), function(i) {
    x <- a[i]; y <- b[i]
    if (nchar(x) > nchar(y)) { t <- x; x <- y; y <- t }
    lx <- nchar(x); ly <- nchar(y)
    if (!lx || !ly) return(0)
    if (lx == ly) return(1 - stringdist::stringdist(x, y, method = "lv") / lx)
    st <- seq_len(ly - lx + 1L)
    w  <- substring(y, st, st + lx - 1L)
    max(1 - stringdist::stringdist(x, w, method = "lv") / lx)
  }, numeric(1))
}

.np_contain_overlap <- function(ta, tb, idf = NULL, stopwords = np_stopwords(),
                                idf_min = 9, min_len = 2L) {
  acr <- .np_name_overlap(ta, tb)
  qa <- ta[nchar(ta) >= min_len & !(ta %in% stopwords)]
  qb <- tb[nchar(tb) >= min_len & !(tb %in% stopwords)]
  con <- 0
  if (length(qa) && length(qb)) {
    sh <- intersect(qa, qb)
    if (length(sh) >= 2L) {
      distinct <- is.null(idf) || {
        w <- idf[sh]; w <- w[!is.na(w)]; length(w) && max(w) >= idf_min
      }
      if (isTRUE(distinct)) {
        cov <- length(sh) / min(length(qa), length(qb))   # coverage of smaller set
        con <- 0.55 + 0.40 * cov                          # full containment -> ~0.95
      }
    }
  }
  max(acr, con)
}

# Parse a ZIP field into the nested prefix family zip5 / zip3 / zip9, restoring
# dropped leading zeros. Handles 5-digit, 9-digit (with or without a dash), and
# short (leading-zero-dropped) inputs. The +4 add-on is used internally to build
# zip9 (falling back to a separately mapped `zip_plus4` column) but is not
# returned as a standalone level.
.np_parse_zip <- function(zip_raw, zip_plus4_raw = NULL) {
  d <- gsub("[^0-9]", "", as.character(zip_raw))
  n <- nchar(d)
  base <- ifelse(n > 5, substr(d, 1, n - 4), d)          # 5-digit portion
  p4d  <- ifelse(n > 5, substr(d, n - 3, n), NA_character_)
  z5   <- ifelse(n > 0, stringr::str_pad(substr(base, 1, 5), 5, "left", "0"),
                 NA_character_)

  p4m <- if (is.null(zip_plus4_raw)) rep(NA_character_, length(d))
         else gsub("[^0-9]", "", as.character(zip_plus4_raw))
  p4m <- ifelse(!is.na(p4m) & nzchar(p4m),
                stringr::str_pad(substr(p4m, 1, 4), 4, "left", "0"), NA_character_)
  p4 <- ifelse(!is.na(p4d), p4d, p4m)                    # +4 add-on (internal)

  z3 <- ifelse(!is.na(z5), substr(z5, 1, 3), NA_character_)
  z9 <- ifelse(!is.na(z5) & !is.na(p4), paste0(z5, "-", p4), NA_character_)
  data.frame(zip5 = z5, zip3 = z3, zip9 = z9, stringsAsFactors = FALSE)
}

# Split a cleaned street key into number / name / type. PO boxes are recognised:
# the box number becomes street_num and street_name is "PO BOX".
.np_parse_street <- function(street_key) {
  sk <- toupper(as.character(street_key)); sk[is.na(sk)] <- ""
  is_po <- grepl("\\bBOX\\b", sk)
  lead <- stringr::str_extract(sk, "^[0-9]+[A-Z]?(-[0-9]+[A-Z]?)?")
  rest <- stringr::str_squish(sub("^[0-9]+[A-Z]?(-[0-9]+[A-Z]?)?", "", sk))
  box  <- stringr::str_match(sk, "BOX\\s*#?\\s*([0-9]+)")[, 2]

  nm_ty <- t(vapply(rest, function(r) {
    if (!nzchar(r)) return(c(NA_character_, NA_character_))
    tk <- strsplit(r, " ")[[1]]; L <- length(tk)
    if (L >= 2 && tk[L] %in% .np_street_type_set)
      c(paste(tk[-L], collapse = " "), tk[L])
    else if (L == 1 && tk %in% .np_street_type_set)
      c(NA_character_, tk)
    else c(r, NA_character_)
  }, character(2)))

  street_num  <- lead
  street_name <- nm_ty[, 1]
  street_type <- nm_ty[, 2]
  street_num[is_po]  <- box[is_po]
  street_name[is_po] <- "PO BOX"
  street_type[is_po] <- NA_character_
  data.frame(street_num = unname(street_num), street_name = unname(street_name),
             street_type = unname(street_type), stringsAsFactors = FALSE)
}

# Map a state value to its two-letter code: pass through valid codes, translate
# full names, otherwise NA.
.np_to_state_abb <- function(state) {
  s <- toupper(stringr::str_squish(as.character(state)))
  out <- ifelse(s %in% .np_state_codes, s, unname(.np_state_abbr[s]))
  out[!nzchar(s)] <- NA_character_
  out
}
