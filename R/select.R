.np_addr_cols <- function(cmp_cols) {
  intersect(cmp_cols, c("street_key", "city", "county", "zip5", "street_unit"))
}

# argmax row per group; ties broken by first. Returns integer row indices.
.np_argmax_by <- function(score, group) {
  ord <- order(group, -score, na.last = TRUE)
  keep <- !duplicated(group[ord])
  ord[keep]
}

# Full-name similarity (query full name vs candidate full name), for tie-breaking
# among candidates whose suffix-stripped name_key is identical (org vs its
# FOUNDATION/ASSOCIATION). Falls back to the name_key similarity if stringdist
# is unavailable.
.np_full_name_sim <- function(df, rows) {
  if (requireNamespace("stringdist", quietly = TRUE) &&
      !is.null(df$name_x) && !is.null(df$name_y)) {
    s <- stringdist::stringsim(df$name_x[rows], df$name_y[rows], method = "jw", p = 0.1)
    s[is.na(s)] <- 0; s
  } else df$name_sim[rows]
}

# Per-query overall pick + near-tie count. Candidates within `tie_band` of the
# top score are "close"; when there are >=2 close and all are >= `tie_high`, the
# tie is broken by full-name exactness (address is uninformative among several
# strong candidates, and full-name distinguishes an org from its
# FOUNDATION/ASSOCIATION where the stripped name_key cannot) instead of score.
.np_overall_summary <- function(df, tie_band, tie_high, tiebreak) {
  if (nrow(df) == 0)
    return(data.frame(.id = character(0), ov_row = integer(0),
                      n_close = integer(0), stringsAsFactors = FALSE))
  ord <- order(df$.id, -df$score)
  grp <- split(ord, df$.id[ord])
  rows <- lapply(names(grp), function(id) {
    ix <- grp[[id]]                       # df rows for this id, score desc
    s <- df$score[ix]; top <- s[1]
    close <- ix[s >= top - tie_band]
    ov <- if (identical(tiebreak, "name") && length(close) >= 2 && top >= tie_high)
            close[which.max(.np_full_name_sim(df, close))] else ix[1]
    data.frame(.id = id, ov_row = ov, n_close = length(close), stringsAsFactors = FALSE)
  })
  do.call(rbind, rows)
}

# Enumerate review/training candidates per query: the top-k by score plus the
# best name-only and best address-only pairs (the loosened views). Hard-vetoed
# pairs are dropped. Returns one tidy row per (.id, .ein) with display values,
# per-field similarities, and a `candidate_type` recording why it was surfaced.
# Shared by np_label_frame() and np_route().
.np_candidates <- function(pairs, k = 3, ids = NULL) {
  cmp_cols <- attr(pairs, "cmp_cols")
  df <- as.data.frame(pairs)
  if (!is.null(ids)) df <- df[df$.id %in% ids, , drop = FALSE]
  if (!is.null(df$veto)) df <- df[!df$veto, , drop = FALSE]
  if (nrow(df) == 0) return(df)

  df$name_sim <- if ("name_key" %in% names(df)) df$name_key else 0
  acols <- .np_addr_cols(cmp_cols)
  df$addr_sim <- if (length(acols)) rowMeans(df[, acols, drop = FALSE], na.rm = TRUE) else NA_real_

  ord <- order(df$.id, -df$score); d <- df[ord, , drop = FALSE]
  rk <- ave(seq_len(nrow(d)), d$.id, FUN = seq_along)
  top <- d[rk <= k, , drop = FALSE]; top$candidate_type <- paste0("top", rk[rk <= k])

  best_of <- function(col, tag) {
    idx <- .np_argmax_by(df[[col]], df$.id); b <- df[idx, , drop = FALSE]
    b$candidate_type <- tag; b
  }
  nm <- best_of("name_sim", "best_name")
  ad <- if (length(acols)) best_of("addr_sim", "best_addr") else df[0, , drop = FALSE]

  # Keep every generated feature/stat (drop only the internal row indices) so the
  # review layer can surface a curated block up front and append the rest.
  keep <- c(setdiff(names(df), c(".x", ".y")), "candidate_type")
  all <- rbind(top[keep], nm[keep], if (nrow(ad)) ad[keep] else NULL)

  key <- paste(all$.id, all$.ein, sep = "\r")
  agg <- tapply(all$candidate_type, key, function(v) paste(sort(unique(v)), collapse = "+"))
  all <- all[!duplicated(key), , drop = FALSE]
  all$candidate_type <- agg[paste(all$.id, all$.ein, sep = "\r")]
  all <- all[order(all$.id, -all$score), , drop = FALSE]
  rownames(all) <- NULL
  all
}

#' Select best matches per query record
#'
#' Reduces scored, vetoed candidate pairs to the best reference entity per query
#' record, and — because the useful MAYBE/NO review set is wider than a single
#' best guess — also surfaces the best match under two *loosened* views:
#'
#' * `overall` best by combined `score` (the primary decision),
#' * `name`    best by name similarity alone (address ignored beyond blocking),
#' * `addr`    best by address similarity alone (name ignored).
#'
#' When the three views disagree, that disagreement is itself signal for review.
#' Vetoed pairs are excluded from every "best" pick by default.
#'
#' @param pairs Scored + vetoed `np_pairs` (see [np_score()], [np_veto()]).
#' @param include_vetoed If `TRUE`, vetoed pairs remain eligible (recorded, not
#'   dropped). Default `FALSE`.
#' @return A one-row-per-query data frame of class `np_selection` with the chosen
#'   `overall_*` match and the alternative `name_*` / `addr_*` matches.
#' @export
np_select <- function(pairs, config = np_config(), include_vetoed = FALSE) {
  cmp_cols <- attr(pairs, "cmp_cols")
  df <- as.data.frame(pairs)
  if (is.null(df$veto_soft)) df$veto_soft <- FALSE
  if (is.null(df$veto_soft_reason)) df$veto_soft_reason <- NA_character_
  if (!include_vetoed && !is.null(df$veto)) df <- df[!df$veto, , drop = FALSE]

  df$name_sim <- if ("name_key" %in% names(df)) df$name_key else 0
  acols <- .np_addr_cols(cmp_cols)
  df$addr_sim <- if (length(acols)) rowMeans(df[, acols, drop = FALSE], na.rm = TRUE) else NA_real_

  ids <- unique(as.data.frame(pairs)$.id)
  pick <- function(score_col) {
    if (nrow(df) == 0) return(df[0, , drop = FALSE])
    idx <- .np_argmax_by(df[[score_col]], df$.id)
    df[idx, , drop = FALSE]
  }
  # overall pick, with near-tie flagging and the high-tie tiebreak rule
  osum <- .np_overall_summary(df, config$tie_band, config$tie_high, config$tiebreak)
  ov <- if (nrow(df)) df[osum$ov_row, , drop = FALSE] else df[0, , drop = FALSE]
  nm <- pick("name_sim"); ad <- pick("addr_sim")

  g <- function(sub, col, id) sub[[col]][match(id, sub$.id)]
  out <- data.frame(.id = ids, stringsAsFactors = FALSE)
  out$name_x            <- g(ov, "name_x", ids)
  out$n_close           <- osum$n_close[match(ids, osum$.id)]
  out$tie               <- !is.na(out$n_close) & out$n_close >= 2

  out$overall_ein       <- g(ov, ".ein", ids)
  out$overall_name_y    <- g(ov, "name_y", ids)
  out$overall_score     <- g(ov, "score", ids)
  out$overall_name_sim  <- g(ov, "name_sim", ids)
  out$overall_addr_sim  <- g(ov, "addr_sim", ids)
  out$overall_veto_soft <- g(ov, "veto_soft", ids)
  out$overall_veto_reason <- g(ov, "veto_soft_reason", ids)

  # runner-up margin: how far the best pick leads the next-best distinct entity.
  # A large margin = one clear winner; a small margin = genuine ambiguity.
  ord2 <- order(df$.id, -df$score)
  d2 <- df[ord2, , drop = FALSE]
  rk <- stats::ave(seq_len(nrow(d2)), d2$.id, FUN = seq_along)
  s1 <- d2$score[rk == 1]; names(s1) <- d2$.id[rk == 1]
  s2 <- d2$score[rk == 2]; names(s2) <- d2$.id[rk == 2]
  runner <- unname(s2[ids]); runner[is.na(runner)] <- 0
  out$runner_up_score <- runner
  out$overall_margin  <- out$overall_score - runner

  out$name_ein          <- g(nm, ".ein", ids)
  out$name_name_y       <- g(nm, "name_y", ids)
  out$name_score        <- g(nm, "name_sim", ids)

  out$addr_ein          <- g(ad, ".ein", ids)
  out$addr_name_y       <- g(ad, "name_y", ids)
  out$addr_score        <- g(ad, "addr_sim", ids)

  # do the loosened views agree with the overall pick?
  out$views_agree <- (is.na(out$name_ein) | out$name_ein == out$overall_ein) &
                     (is.na(out$addr_ein) | out$addr_ein == out$overall_ein)

  attr(out, "profile") <- attr(pairs, "profile")
  structure(out, class = c("np_selection", "data.frame"))
}
