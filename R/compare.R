# Build a reclin2 pairs object from np_block() candidate indices, so the
# name-token / progressive-blocking path reuses compare_pairs (and EM).
.np_pairs_from_candidates <- function(query, reference, candidates) {
  pm <- data.table::data.table(.x = as.integer(candidates$.x),
                               .y = as.integer(candidates$.y))
  data.table::setattr(pm, "x", data.table::as.data.table(query))
  data.table::setattr(pm, "y", data.table::as.data.table(reference))
  data.table::setattr(pm, "blocking_on", character(0))
  data.table::setattr(pm, "class", c("pairs", "data.table", "data.frame"))
  pm
}

# Map canonical geo fields to the normalized column actually compared.
.np_compare_col <- c(
  name   = "name_key",
  street = "street_key",
  unit   = "street_unit",
  city   = "city",
  county = "county",
  zip5   = "zip5"
)

#' Generate and compare candidate pairs
#'
#' Blocks the query against the reference, then scores each candidate pair on
#' the fields implied by the detected (or supplied) geographic profile. reclin2
#' does the blocked pairing and per-field string comparison; the result is
#' returned as a plain data frame so every downstream npmatch stage works on
#' ordinary columns.
#'
#' The name is always compared (on `name_key`). Geographic comparison fields are
#' taken from the profile. Name-feature columns needed by [np_veto()] are carried
#' through for both sides with `_x` / `_y` suffixes.
#'
#' @param query,reference Normalized `np_query` / `np_reference` frames.
#' @param config An [np_config()].
#' @param block Character vector of canonical fields to block on when
#'   `candidates` is not supplied. Defaults to `"state"`.
#' @param profile Optional profile name to force; otherwise [np_detect_geo()].
#' @param candidates Optional `np_blocks` from [np_block()]. When given, these
#'   candidate pairs are compared instead of blocking on `block` — the scalable
#'   path (name-token / progressive blocking).
#' @return A data frame of candidate pairs, one row per (query, reference) pair,
#'   with class `np_pairs`. Columns include `.x`, `.y`, `.id`, `.ein`, a
#'   similarity column per compared field, plus carried veto features.
#' @export
np_compare <- function(query, reference, config = np_config(),
                       block = "state", profile = NULL, candidates = NULL,
                       name_freq = NULL) {
  if (!requireNamespace("reclin2", quietly = TRUE)) {
    stop("np_compare() requires the reclin2 package.", call. = FALSE)
  }
  if (is.null(query$name_key) || is.null(reference$name_key)) {
    stop("Call np_normalize() on both frames before np_compare().", call. = FALSE)
  }

  if (is.null(profile)) profile <- np_detect_geo(query)
  geo_fields <- np_geo_profiles()[[profile]]
  # fields we will actually compare = name + geo fields present on both sides
  cmp_fields <- c("name", setdiff(geo_fields, c("state")))  # state is the block
  cmp_fields <- Filter(function(f) {
    col <- .np_compare_col[[f]]
    !is.null(query[[col]]) && !is.null(reference[[col]]) &&
      any(!is.na(query[[col]])) && any(!is.na(reference[[col]]))
  }, cmp_fields)
  cmp_cols <- unname(.np_compare_col[cmp_fields])

  # Candidate pairs: either supplied by np_block() or blocked on the raw key(s).
  if (!is.null(candidates)) {
    pairs <- .np_pairs_from_candidates(query, reference, candidates)
  } else {
    pairs <- reclin2::pair_blocking(query, reference, on = block)
  }

  jt <- config$jw_threshold
  comparators <- stats::setNames(
    lapply(cmp_cols, function(col) {
      if (col == "zip5") reclin2::cmp_identical()
      else reclin2::cmp_jarowinkler(threshold = jt)
    }), cmp_cols)

  pairs <- reclin2::compare_pairs(
    pairs, on = cmp_cols, comparators = comparators, overwrite = TRUE
  )

  df <- as.data.frame(pairs)
  # similarities: NA -> 0 (missing on a side is not evidence of a match)
  for (col in cmp_cols) df[[col]][is.na(df[[col]])] <- 0
  # Floor fuzzy (Jaro-Winkler) similarities below jw_threshold to 0. reclin2's
  # cmp_jarowinkler(threshold=) is the Winkler prefix BOOST, not a cutoff, so
  # unrelated strings otherwise leak ~0.5 into every score. zip5 is exact (0/1)
  # and is left as-is.
  for (col in setdiff(cmp_cols, "zip5")) df[[col]][df[[col]] < jt] <- 0

  ix <- df$.x; iy <- df$.y
  df$.id  <- query$.id[ix]
  df$.ein <- reference$.ein[iy]

  # Name display defaults: raw = the mapped input name, name_x/name_y = the
  # *version that produced the match* (main / DBA), overridden in the provenance
  # block below; name_ver_* labels which version. Set here so the columns exist
  # even when the DBA/overlap block is skipped.
  df$name_raw_x <- query$name[ix];      df$name_raw_y <- reference$name[iy]
  df$dba_x      <- query$dba[ix];       df$dba_y      <- reference$dba[iy]
  df$division_x <- query$division[ix];  df$division_y <- reference$division[iy]
  df$name_x     <- query$name_full[ix]; df$name_y     <- reference$name_full[iy]
  df$name_key_x <- query$name_key[ix];  df$name_key_y <- reference$name_key[iy]
  df$street_norm_x <- query$street_key[ix]; df$street_norm_y <- reference$street_key[iy]
  df$name_ver_x <- NA_character_;       df$name_ver_y <- NA_character_

  # location-granularity signals for the hierarchical geo score (cheap exact
  # comparisons; the fuzzy city/street terms are reused from the JW columns in
  # np_score). Computed before the name step so name-blind recovery can gate on
  # address. Independent of the geo profile so the geo score always degrades
  # gracefully to whatever granularity is present.
  exact <- function(col) {
    a <- as.character(query[[col]][ix]); b <- as.character(reference[[col]][iy])
    as.integer(!is.na(a) & !is.na(b) & nzchar(a) & a == b)
  }
  df$geo_zip9  <- exact("zip9")
  df$geo_zip5  <- exact("zip5")
  df$geo_zip3  <- exact("zip3")
  df$geo_state <- exact("state")
  df$geo_stnum <- exact("street_num")
  df$geo_pobox <- as.integer(query$is_po_box[ix] %in% TRUE &
                             reference$is_po_box[iy] %in% TRUE)

  # Effective name similarity = best of the name/DBA cross-products (name==name,
  # name==dba, dba==name, dba==dba), so an exact DBA match scores like a name
  # match. Reuses reclin2's name-name JW and adds the DBA terms via stringdist;
  # floored at jw_threshold like the other fuzzy fields.
  if (requireNamespace("stringdist", quietly = TRUE) &&
      !is.null(query$dba_key) && !is.null(reference$dba_key)) {
    has <- function(v) !is.na(v) & nzchar(v)
    jw  <- function(a, b) { s <- stringdist::stringsim(a, b, method = "jw", p = 0.1)
                            s[is.na(s)] <- 0; s }
    nkx <- query$name_key[ix]; nky <- reference$name_key[iy]
    dkx <- query$dba_key[ix];  dky <- reference$dba_key[iy]
    vkx <- if (!is.null(query$division_key)) query$division_key[ix] else rep("", nrow(df))
    s_nn <- df[["name_key"]]                              # name==name (floored)
    t_nd <- ifelse(has(dky),            jw(nkx, dky), 0)   # uss name     == bmf dba
    t_dn <- ifelse(has(dkx),            jw(dkx, nky), 0)   # uss dba      == bmf name
    t_dd <- ifelse(has(dkx) & has(dky), jw(dkx, dky), 0)   # uss dba      == bmf dba
    t_vn <- ifelse(has(vkx),            jw(vkx, nky), 0)   # uss division == bmf name
    t_vd <- ifelse(has(vkx) & has(dky), jw(vkx, dky), 0)   # uss division == bmf dba
    for (nm2 in c("t_nd", "t_dn", "t_dd", "t_vn", "t_vd"))
      assign(nm2, { z <- get(nm2); z[z < jt] <- 0; z })
    s_dba <- pmax(t_nd, t_dn, t_dd, t_vn, t_vd)

    # Name-blind recovery: for pairs the JW scored to 0 *but* whose address is
    # confirmed, try the token-set + acronym overlap (word-reorder, acronyms,
    # typos). Gated on address to keep it cheap and avoid false positives.
    s_ov <- numeric(nrow(df))
    low <- which(pmax(s_nn, s_dba) == 0 &
                 (df$geo_zip5 == 1 | df$geo_zip9 == 1 | df$geo_stnum == 1))
    if (length(low)) {
      qt <- strsplit(nkx[low], "\\s+"); rt <- strsplit(nky[low], "\\s+")
      ov <- mapply(.np_name_overlap, qt, rt); ov[ov < 0.6] <- 0
      s_ov[low] <- ov
    }
    df[["name_key"]] <- pmax(s_nn, s_dba, s_ov)

    # provenance: which name *version* on each side produced the match, and the
    # readable string of that version. Columns of M line up with (uss, bmf)
    # versions below.
    # OVERLAP = token-set / acronym / word-reorder overlap (the s_ov recovery
    # path), NOT specifically abbreviation. "none" = no name signal cleared the
    # threshold: the pair is on the list because its address matched, not its name.
    M  <- cbind(s_nn, t_nd, t_dn, t_dd, t_vn, t_vd, s_ov)
    wi <- max.col(M, ties.method = "first")
    uss_ver <- c("MAIN", "MAIN", "DBA", "DBA", "DIVISION", "DIVISION", "TOKEN_OVERLAP")[wi]
    bmf_ver <- c("MAIN", "DBA", "MAIN", "DBA", "MAIN", "DBA", "TOKEN_OVERLAP")[wi]
    az <- rowSums(M) == 0                                  # no name signal
    uss_ver[az] <- "none"; bmf_ver[az] <- "none"
    ex <- s_nn >= 0.999                                    # exact main match
    uss_ver[ex] <- "MAIN"; bmf_ver[ex] <- "MAIN"
    df$name_ver_x <- uss_ver; df$name_ver_y <- bmf_ver

    # show the matched version's string in the display name (the DBA or division
    # when that side matched on it, else the cleaned main name set above)
    q_dba <- query$dba[ix]; r_dba <- reference$dba[iy]; q_div <- query$division[ix]
    use_qd <- !is.na(uss_ver) & uss_ver == "DBA" & !is.na(q_dba) & nzchar(q_dba)
    use_qv <- !is.na(uss_ver) & uss_ver == "DIVISION" & !is.na(q_div) & nzchar(q_div)
    use_rd <- !is.na(bmf_ver) & bmf_ver == "DBA" & !is.na(r_dba) & nzchar(r_dba)
    df$name_x[use_qd] <- q_dba[use_qd]
    df$name_x[use_qv] <- q_div[use_qv]
    df$name_y[use_rd] <- r_dba[use_rd]

    # name_match_type retained (exact / name / dba / token_overlap); the division
    # cross-products fall under "dba" (match_version distinguishes them).
    typ <- c("name", "dba", "dba", "dba", "dba", "dba", "token_overlap")[wi]
    typ[az] <- NA_character_; typ[ex] <- "exact"
    df$name_match_type <- typ

    # name distinctiveness = how many reference records share this name_key
    # (rare -> an exact match is trustworthy without address). For the
    # distinctive-exact-name promotion in np_score(method = "hier").
    if (!is.null(name_freq)) {
      f <- name_freq[toupper(reference$name_key[iy])]; f[is.na(f)] <- 1L
      df$name_freq <- as.integer(f)
    } else df$name_freq <- NA_integer_
  }

  # carry veto features for both sides
  feats <- c("name_gen", "name_gen_rank", "name_nums", "name_ord", "name_dir",
             "name_form")
  for (f in feats) {
    df[[paste0(f, "_x")]] <- query[[f]][ix]
    df[[paste0(f, "_y")]] <- reference[[f]][iy]
  }
  # keep human-readable geo values for review output (self-contained packets);
  # name_x / name_y / name_raw_* / name_ver_* were set above with match provenance
  for (f in c("street", "city", "state", "zip5")) {
    df[[paste0(f, "_x")]] <- query[[f]][ix]
    df[[paste0(f, "_y")]] <- reference[[f]][iy]
  }

  attr(df, "profile")      <- profile
  attr(df, "cmp_fields")   <- cmp_fields
  attr(df, "cmp_cols")     <- cmp_cols
  attr(df, "reclin_pairs") <- pairs   # kept for EM (needs the reclin2 object)
  structure(df, class = c("np_pairs", "data.frame"))
}
