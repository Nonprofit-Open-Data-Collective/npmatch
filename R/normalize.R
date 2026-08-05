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
  "AMER" = "AMERICAN", "MT" = "MOUNT", "ST" = "SAINT"
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

# Generation tokens (Ken Griffey vs Ken Griffey Jr): the abbreviated JR/SR only.
# Spelled-out "JUNIOR"/"SENIOR" are demographic/org words ("Junior League",
# "Senior Care"); roman II-V are usually series/phase numbers ("Fund II",
# "Phase III") not generations -- both caused the veto to over-fire massively
# (found via np_veto_audit). Ordinals (FIRST/SECOND) have their own extractor.
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

.np_basic_clean <- function(x) {
  x <- toupper(as.character(x))
  x <- stringi::stri_trans_general(x, "Latin-ASCII") # de-accent
  x <- gsub("&", " AND ", x, fixed = TRUE)
  x <- gsub("[[:punct:]]", " ", x)
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
#' * `name_form`    detected legal form (INC / LLC / CORP / ...), or `NA`
#' * `name_gen`     generation marker (JR/SR/II/III/...), or `NA`
#' * `name_gen_rank` numeric rank of the generation marker, for conflict tests
#' * `name_nums`    space-joined embedded digit tokens (chapter/local numbers)
#' * `name_ord`     canonical ordinal rank(s) found in the name
#' * `street_key`   USPS-standardized street with unit stripped
#' * `street_num`   leading house / box number
#' * `street_name`  street body with the number, type, and unit removed
#' * `street_type`  trailing street type (ST / AVE / BLVD / WAY / ...), or `NA`
#' * `street_unit`  extracted suite/unit/apt number, if any
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

  # DBA key: same normalization as the name, for exact DBA cross-matching.
  dv <- data$dba; dv[is.na(dv)] <- ""
  data$dba_key <- .np_strip_lead_the(
    .np_strip_suffix(.np_replace_tokens(.np_basic_clean(dv), .np_abbrev)))

  data$street_unit <- .np_extract_unit(data$street)
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

.np_unit_pat <- "(STE|SUITE|APT|APARTMENT|UNIT|#|BLDG|RM|ROOM)\\s*#?\\s*[0-9A-Z]+"

# PO-box variants on an already-cleaned street key: "PO BOX 12", "P O BOX 12",
# "POBOX 12", "POB 12", "PO B 12", "PO 12", "P O 12", "BOX 12". Ordered so the
# longest prefix wins; each must be followed by the box number.
.np_pobox_pat <- "^(P ?O ?BOX|P ?O ?B|BOX|P ?O) ?#? ?[0-9]+"

.np_is_pobox <- function(street_key) {
  s <- toupper(as.character(street_key)); s[is.na(s)] <- ""
  grepl(.np_pobox_pat, s)
}

.np_extract_unit <- function(street) {
  s <- toupper(as.character(street))
  stringr::str_squish(stringr::str_extract(s, .np_unit_pat))
}

.np_street_key <- function(street) {
  s <- .np_basic_clean(street)
  # drop unit portion from the matchable street key
  s <- gsub("(STE|SUITE|APT|APARTMENT|UNIT|BLDG|RM|ROOM)\\s+[0-9A-Z]+", " ", s)
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
