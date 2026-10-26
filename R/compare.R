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
  unit   = "street_unit_id",
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
#' @param name_freq,token_idf Optional pre-computed reference tables from
#'   [np_name_freq()] / [np_token_idf()].
#' @param addr_freq Optional [np_addr_freq()] table for the reference. Used to
#'   read a suite match in context: `addr_shared`, `addr_units`,
#'   `addr_unit_shared` and `addr_note` are added to the result, and
#'   `np_score(method = "hier")` credits a matching suite only where the
#'   address is genuinely multi-tenant. Computed from `reference` when `NULL`,
#'   which is wrong if `reference` is a slice of the real corpus — build it
#'   once from the whole reference and pass it in (as [np_cascade()] does).
#' @return A data frame of candidate pairs, one row per (query, reference) pair,
#'   with class `np_pairs`. Columns include `.x`, `.y`, `.id`, `.ein`, a
#'   similarity column per compared field, plus carried veto features.
#' @export
np_compare <- function(query, reference, config = np_config(),
                       block = "state", profile = NULL, candidates = NULL,
                       name_freq = NULL, token_idf = NULL, addr_freq = NULL) {
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
  # config$jw_p = NULL reproduces the historical behaviour exactly, which is
  # NOT Jaro-Winkler: reclin2::cmp_jarowinkler() calls stringdist(method="jw")
  # with no `p`, so p defaults to 0 and this path computes plain Jaro with no
  # prefix boost -- while the DBA cross-products further down use p = 0.1.
  # Setting jw_p applies one value to both paths, which is what makes them
  # comparable. See pfmatch dev/JARO-NOT-JAROWINKLER.md.
  jp <- config$jw_p
  cmp_name <- if (is.null(jp)) reclin2::cmp_jarowinkler(threshold = jt) else
    local({ p <- jp; function(x, y) {
      if (!missing(y)) 1 - stringdist::stringdist(x, y, method = "jw", p = p)
      else (x > jt) & !is.na(x) } })
  comparators <- stats::setNames(
    lapply(cmp_cols, function(col) {
      # a suite is an identifier, not a string: 320 and 380 are different
      # offices, and a fuzzy score between them is meaningless
      if (col %in% c("zip5", "street_unit_id")) reclin2::cmp_identical()
      else cmp_name
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
  for (col in setdiff(cmp_cols, c("zip5", "street_unit_id")))
    df[[col]][df[[col]] < jt] <- 0

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

  # Suite agreement, and what a suite is worth at THIS address.
  #
  # geo_unit is deliberately three-valued: 1 both sides name a suite and it is
  # the same office, 0 both name one and they differ, NA either side is silent.
  # Most records are silent (12% of the BMF carries a suite), and silence is not
  # a conflict -- .np_hier_score() only ever uses this to RAISE a score, so an
  # absent or a differing suite costs a pair nothing. Partial agreement is not a
  # thing: 320 against 380 is simply 0, never a fraction.
  #
  # The context columns answer "is this suite informative here", which the match
  # alone cannot:
  #   addr_units       distinct suites the reference lists at this address. >= 2
  #                    means a multi-tenant building, where an exact-address
  #                    match surfaces every tenant and the suite is the only
  #                    thing separating them.
  #   addr_unit_shared records at this address AND suite. Above share_min it is
  #                    a fiscal sponsor / registered agent / mail drop, where a
  #                    shared suite says nothing about being the same entity.
  #   addr_shared      records at this address, suite or not.
  # addr_note states either case in words for a human or LLM reviewer, which is
  # the whole value in the crowded cases: the suite cannot decide them, so the
  # reviewer should be told the address is shared rather than left to guess.
  if (is.null(addr_freq))
    addr_freq <- np_addr_freq(reference$street_key, reference$zip5,
                              reference$street_unit_id, reference$name_key)
  ux <- query$street_unit_id[ix]; uy <- reference$street_unit_id[iy]
  both <- !is.na(ux) & !is.na(uy) & nzchar(ux) & nzchar(uy)
  df$geo_unit <- ifelse(both, as.integer(ux == uy), NA_integer_)

  akey <- .np_addr_key(reference$street_key[iy], reference$zip5[iy])
  cnt <- function(tab, key) {
    v <- unname(tab[key]); v[is.na(v)] <- 0L; as.integer(v)
  }
  df$addr_shared      <- cnt(addr_freq$addr, akey)
  df$addr_units       <- cnt(addr_freq$units, akey)
  df$addr_unit_shared <- cnt(addr_freq$addr_unit, paste(akey, uy, sep = "|"))
  num <- function(tab, key, default) {
    if (is.null(tab)) return(rep(default, length(key)))
    v <- unname(tab[key]); v[is.na(v)] <- default; as.numeric(v)
  }
  df$addr_unit_coverage <- num(addr_freq$unit_coverage, akey, 0)
  df$addr_top_name_share <- num(addr_freq$top_name_share, akey, NA_real_)
  cls <- if (is.null(addr_freq$class)) rep(NA_character_, length(akey)) else
    unname(addr_freq$class[akey])
  cls[is.na(cls)] <- "single"
  df$addr_class <- cls
  sm <- addr_freq$share_min

  # What the reviewer is told, which is the whole value in the cases arithmetic
  # cannot settle. Ordered by what actually decides the case: a crowded suite
  # first (the suite is a mail drop), then a federated address (neither address
  # nor suite separates anything -- the chapter number does), then a merely
  # shared one.
  df$addr_note <- ifelse(
    df$addr_unit_shared > sm,
    sprintf("%d records share this address and suite", df$addr_unit_shared),
    ifelse(df$addr_class == "federated",
      sprintf("federated address: %d records here, %d%% of them under one name; the address does not separate them",
              df$addr_shared, round(100 * df$addr_top_name_share)),
    ifelse(df$addr_shared > sm,
      sprintf("%d records share this address under %s distinct names (sponsor or agent)",
              df$addr_shared, ifelse(is.na(df$addr_top_name_share), "several",
                                     as.character(num(addr_freq$n_names, akey, NA_real_)))),
      NA_character_)))

  # Effective name similarity = best of the name/DBA cross-products (name==name,
  # name==dba, dba==name, dba==dba), so an exact DBA match scores like a name
  # match. Reuses reclin2's name-name JW and adds the DBA terms via stringdist;
  # floored at jw_threshold like the other fuzzy fields.
  if (requireNamespace("stringdist", quietly = TRUE) &&
      !is.null(query$dba_key) && !is.null(reference$dba_key)) {
    has <- function(v) !is.na(v) & nzchar(v)
    # p follows config$jw_p when set, else the historical 0.1 on this path
    jw  <- function(a, b) { s <- stringdist::stringsim(a, b, method = "jw",
                                   p = if (is.null(jp)) 0.1 else jp)
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

    # Name-blind recovery: for pairs whose JW/DBA name score did not clear the
    # threshold but whose ADDRESS is already confirmed (same 5-digit ZIP, street
    # number, or PO box), try a containment-aware, acronym-aware token overlap
    # (word-reorder, acronyms, subset/superset names). Containment alone is
    # ambiguous -- a parent, a subsidiary, an auxiliary and a chapter all share
    # the distinctive tokens -- so np_score caps a token_overlap-only match at the
    # MAYBE (review) tier: it recovers a false negative into human/LLM review but
    # never auto-accepts. The gate is address confirmation, NOT merely same-state:
    # same-state alone fires this per-pair recovery on nearly every candidate and
    # made compare ~100x slower for a marginal (state-only, address-less) recall
    # slice. The expensive .np_contain_overlap runs only on this small subset.
    # Substring credit (config$substring_p, NULL = off, no behaviour change).
    # Measured in pfmatch dev/NAME-METRIC-EVALUATION.md: on the hard cases a
    # sliding-window partial ratio finds 17 of 21 while admitting only 6 wrong
    # names, against Jaro-Winkler's 16 and 11. It targets the dominant shape
    # here -- a filed name that is a prefix or infix of the legal name.
    #
    # It is folded into the SAME review-only path as token overlap, not into the
    # JW term, and deliberately so: "PLAYWORKS" inside "PLAYWORKS WASHINGTON DC"
    # is precisely the parent/chapter ambiguity that containment cannot resolve,
    # and "GIRLS" scores 1.0 against both "GIRLS INC OF WASHINGTON COUNTY" and an
    # org literally named "GIRLS". So it must surface for review rather than
    # auto-accept. Gated on the same address confirmation for the same cost
    # reason as the overlap path.
    sp <- config$substring_p
    s_sub <- numeric(nrow(df))
    addr_ok <- df$geo_zip5 == 1 | df$geo_stnum == 1 | df$geo_pobox == 1
    if (!is.null(sp)) {
      lo2 <- which(pmax(s_nn, s_dba) < jt & addr_ok)
      if (length(lo2)) {
        s_sub[lo2] <- .np_partial_ratio(nkx[lo2], nky[lo2])
        s_sub[s_sub < sp] <- 0
      }
    }
    s_ov <- numeric(nrow(df))
    low <- which(pmax(s_nn, s_dba) < jt & addr_ok)
    if (length(low)) {
      qt <- strsplit(nkx[low], "\\s+"); rt <- strsplit(nky[low], "\\s+")
      # np_stopwords() is a default argument of .np_contain_overlap(), so it
      # is rebuilt on every call; pass it in once.
      sw_ov <- np_stopwords()
      ov <- mapply(function(a, b) .np_contain_overlap(a, b, token_idf, sw_ov),
                   qt, rt)
      ov[ov < 0.6] <- 0
      s_ov[low] <- ov
    }
    df[["name_key"]] <- pmax(s_nn, s_dba, s_ov, s_sub)

    # provenance: which name *version* on each side produced the match, and the
    # readable string of that version. Columns of M line up with (uss, bmf)
    # versions below.
    # OVERLAP = token-set / acronym / word-reorder overlap (the s_ov recovery
    # path), NOT specifically abbreviation. "none" = no name signal cleared the
    # threshold: the pair is on the list because its address matched, not its name.
    M  <- cbind(s_nn, t_nd, t_dn, t_dd, t_vn, t_vd, s_ov, s_sub)
    wi <- max.col(M, ties.method = "first")
    uss_ver <- c("MAIN", "MAIN", "DBA", "DBA", "DIVISION", "DIVISION",
                 "TOKEN_OVERLAP", "SUBSTRING")[wi]
    bmf_ver <- c("MAIN", "DBA", "MAIN", "DBA", "MAIN", "DBA",
                 "TOKEN_OVERLAP", "SUBSTRING")[wi]
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
    typ <- c("name", "dba", "dba", "dba", "dba", "dba",
             "token_overlap", "substring")[wi]
    typ[az] <- NA_character_; typ[ex] <- "exact"
    df$name_match_type <- typ

    # name distinctiveness = how many reference records share this name_key
    # (rare -> an exact match is trustworthy without address). For the
    # distinctive-exact-name promotion in np_score(method = "hier").
    if (!is.null(name_freq)) {
      f <- name_freq[toupper(reference$name_key[iy])]; f[is.na(f)] <- 1L
      df$name_freq <- as.integer(f)
    } else df$name_freq <- NA_integer_

    # How much information the name actually carries, as the summed IDF of its
    # content tokens. `name_freq` counts how many reference records share the
    # exact string, which is LEXICAL rarity and not the same thing: "COMMUNITY
    # CHURCH" is unique in the BMF as a literal string (every other one is
    # "<Place> Community Church") yet identifies nothing, while "KOINONIA
    # ACADEMY" is equally unique and identifies precisely. Used by the
    # distinctive-name promotion in np_score(method = "hier").
    if (!is.null(token_idf)) {
      rk <- toupper(ifelse(is.na(reference$name_key[iy]), "", reference$name_key[iy]))
      mx <- suppressWarnings(max(token_idf, na.rm = TRUE))
      if (!is.finite(mx)) mx <- 0
      # Vectorised on purpose. The obvious per-pair form --
      #   vapply(strsplit(rk, " "), function(t) sum(token_idf[t]), numeric(1))
      # -- indexes a NAMED vector by character once per candidate pair, and R
      # rebuilds the name hash on every such call. token_idf carries one entry
      # per distinct reference token (259,324 on the 1.9M-row BMF), so that
      # costs ~8,100 s per million pairs against ~3 s for a single match() over
      # all tokens at once: measured at 3,234x, with identical output.
      # B1/B2 generate millions of pairs per batch, so the per-pair form made
      # the cascade roughly 30x slower than its benchmarked figure.
      tl   <- strsplit(rk, " ", fixed = TRUE)
      lens <- lengths(tl)
      flat <- unlist(tl, use.names = FALSE)
      if (!length(flat)) {
        df$name_idf <- rep(0, length(rk))
      } else {
        sw   <- np_stopwords()
        keep <- nchar(flat) >= 2L & !(flat %in% sw)
        j    <- match(flat, names(token_idf))
        w    <- ifelse(is.na(j), mx, token_idf[j])
        w[!keep] <- 0
        grp  <- rep.int(seq_along(tl), lens)
        s    <- tapply(w, factor(grp, levels = seq_along(tl)), sum)
        s    <- as.numeric(s); s[is.na(s)] <- 0
        df$name_idf <- s
      }
    } else df$name_idf <- NA_real_
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
  for (f in c("street", "city", "state", "zip5", "unit", "street_unit",
              "street_unit_id")) {
    df[[paste0(f, "_x")]] <- query[[f]][ix]
    df[[paste0(f, "_y")]] <- reference[[f]][iy]
  }
  # carry the reference active flag (unified-BMF option) so the result can be
  # filtered to current-990 matches vs identity-resolution matches downstream
  df$bmf_active <- if (!is.null(reference$active)) reference$active[iy] else NA

  attr(df, "addr_share_min") <- addr_freq$share_min
  attr(df, "addr_unit_coverage_min") <- addr_freq$unit_coverage_min
  attr(df, "profile")      <- profile
  attr(df, "cmp_fields")   <- cmp_fields
  attr(df, "cmp_cols")     <- cmp_cols
  attr(df, "reclin_pairs") <- pairs   # kept for EM (needs the reclin2 object)
  structure(df, class = c("np_pairs", "data.frame"))
}
