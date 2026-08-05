#' Blocking stopwords
#'
#' Non-discriminating legal/filler tokens dropped from name-token blocking so
#' blocks stay small and precise. Deliberately conservative (legal forms and
#' function words only) — rely on `max_ref_freq` in [np_block()] to prune the
#' remaining corpus-common words data-drivenly rather than hard-coding them.
#'
#' @return A character vector of uppercase stopwords.
#' @export
np_stopwords <- function() {
  c("INC", "INCORPORATED", "CORP", "CORPORATION", "CO", "COMPANY",
    "LLC", "LTD", "LP", "LLP", "PC", "PLLC", "LIMITED",
    "THE", "AND", "OF", "FOR", "A", "AN", "IN", "TO", "AT",
    "FOUNDATION", "FUND", "TRUST", "ASSOCIATION", "ASSN",
    "ORGANIZATION", "ORG")
}

# Composite exact-block key per record (paste of the `by` columns), or "" when
# no `by` is given. A key with ANY missing/empty component is returned as ""
# (invalid) so it is dropped from the join -- e.g. records without a DBA do not
# all collapse onto a shared "state + empty" key.
.np_bykey <- function(frame, by) {
  if (is.null(by) || !length(by)) return(rep("", nrow(frame)))
  cols <- lapply(by, function(b) as.character(frame[[b]]))
  valid <- Reduce(`&`, lapply(cols, function(v) !is.na(v) & nzchar(v)))
  key <- do.call(paste, c(cols, sep = "\r"))
  key[!valid] <- ""
  key
}

#' Generate candidate pairs by blocking
#'
#' Produces the (query, reference) candidate pairs worth comparing, so
#' [np_compare()] never has to score every same-state pair. Three modes:
#'
#' * **exact** (`token = FALSE`) — pairs that match exactly on all `by` columns
#'   (a hash join). E.g. `by = "state"` or `by = c("state", "zip5")`.
#' * **token** (`token = TRUE`, default) — pairs that share the exact `by` key
#'   **and** at least one distinctive token of `token_col` (a name-token inverted
#'   index). This is what makes blocking scale: "ALASKA X" is only paired with
#'   same-state orgs that share a rare token, not all ~40k orgs in the state.
#' * **token, cross-key** (`by = NULL`, `token = TRUE`) — shared token only, no
#'   exact key. The loose recall-recovery pass (finds a same-name org in another
#'   state — the firm-vs-establishment case).
#'
#' Both frames must be normalized ([np_normalize()]). Combine passes by
#' `rbind`-ing results and de-duplicating (see [np_block_union()]).
#'
#' @param query,reference Normalized `np_query` / `np_reference` frames.
#' @param by Character vector of exact-match block columns, or `NULL`. Applied to
#'   both sides unless `by_x` / `by_y` override.
#' @param by_x,by_y Per-side block columns for cross-column matching (e.g.
#'   `by_x = c("state","name_key")`, `by_y = c("state","dba_key")` pairs a query
#'   name against a reference DBA). Default to `by`. Columns are matched
#'   position-for-position, so the two must be the same length.
#' @param token If `TRUE` (default), also require a shared `token_col` token.
#' @param token_col Column to tokenize. Default `"name_key"`.
#' @param stopwords Tokens to drop (see [np_stopwords()]).
#' @param min_token_len Minimum token length to index. Default 2.
#' @param max_ref_freq Optional: drop tokens occurring in more than this many
#'   reference records (kills corpus-common words). `NULL` = stopwords only.
#' @param min_pair_idf Optional IDF-weighted pruning. A single common token
#'   (e.g. "CALIFORNIA", "CHURCH") should not by itself justify a candidate pair,
#'   but a global `max_ref_freq` can't see that such a token is concentrated
#'   within one block (state). With `min_pair_idf` set, each shared token is
#'   weighted by its inverse document frequency `log(N_ref / df)` and a pair is
#'   kept only when the sum of its shared tokens' IDF is at least this value. One
#'   rare token, or several moderately common ones, clears the bar; a lone common
#'   token does not. `NULL` (default) disables this. Only used when `token`.
#' @return A data frame of candidate pairs with integer columns `.x` (query row)
#'   and `.y` (reference row), class `np_blocks`.
#' @export
np_block <- function(query, reference, by = "state", by_x = NULL, by_y = NULL,
                     token = TRUE, token_col = "name_key",
                     stopwords = np_stopwords(), min_token_len = 2L,
                     max_ref_freq = NULL, min_pair_idf = NULL) {
  stopifnot(is.data.frame(query), is.data.frame(reference))
  if (is.null(by_x)) by_x <- by
  if (is.null(by_y)) by_y <- by
  # Fast equi-join on a shared string key via merge.data.table (function
  # dispatch), avoiding the data.table `[` DSL (which reverts inside a package).
  # xid/yid carry the real record rows through the join.
  join_on_key <- function(xid, xkey, yid, ykey) {
    qd <- data.frame(.x = xid, k = xkey, stringsAsFactors = FALSE)
    rd <- data.frame(.y = yid, k = ykey, stringsAsFactors = FALSE)
    qd <- qd[nzchar(qd$k) & !is.na(qd$k), , drop = FALSE]
    rd <- rd[nzchar(rd$k) & !is.na(rd$k), , drop = FALSE]
    data.table::setDT(qd); data.table::setDT(rd)
    m <- merge(qd, rd, by = "k", allow.cartesian = TRUE)
    data.frame(.x = m$.x, .y = m$.y)
  }

  if (!isTRUE(token)) {
    cand <- join_on_key(seq_len(nrow(query)),     .np_bykey(query, by_x),
                        seq_len(nrow(reference)), .np_bykey(reference, by_y))
  } else {
    idx_of <- function(frame, byk) {
      v <- as.character(frame[[token_col]]); v[is.na(v)] <- ""
      toks <- strsplit(v, "\\s+")
      d <- data.frame(row = rep(seq_len(nrow(frame)), lengths(toks)),
                      token = unlist(toks, use.names = FALSE),
                      bk = rep(.np_bykey(frame, byk), lengths(toks)),
                      stringsAsFactors = FALSE)
      d[nchar(d$token) >= min_token_len & !(d$token %in% stopwords), , drop = FALSE]
    }
    qi <- idx_of(query, by_x); ri <- idx_of(reference, by_y)
    # reference document frequency per token (distinct records), before pruning
    ref_df <- tapply(ri$row, ri$token, function(v) length(unique(v)))
    if (!is.null(max_ref_freq)) {
      common <- names(ref_df)[ref_df > max_ref_freq]
      qi <- qi[!qi$token %in% common, , drop = FALSE]
      ri <- ri[!ri$token %in% common, , drop = FALSE]
    }
    if (is.null(min_pair_idf)) {
      cand <- join_on_key(qi$row, paste(qi$bk, qi$token, sep = "\r"),
                          ri$row, paste(ri$bk, ri$token, sep = "\r"))
    } else {
      # IDF-weighted: retain the shared token through the join, then keep a pair
      # only if its shared tokens' summed IDF clears min_pair_idf.
      n_ref <- nrow(reference)
      idf <- log(n_ref / pmax(as.numeric(ref_df), 1)); names(idf) <- names(ref_df)
      # A globally unique shared token (idf = log(N)) is the strongest possible
      # block signal and must always clear the bar; cap the effective threshold
      # at log(N) so the filter stays meaningful for small references too. This
      # is a no-op at BMF scale (log(~2M) ~ 14.5 > any sensible min_pair_idf).
      eff_idf <- min(min_pair_idf, log(max(n_ref, 2)))
      qd <- data.frame(.x = qi$row, k = paste(qi$bk, qi$token, sep = "\r"),
                       stringsAsFactors = FALSE)
      rd <- data.frame(.y = ri$row, k = paste(ri$bk, ri$token, sep = "\r"),
                       tok = ri$token, stringsAsFactors = FALSE)
      qd <- qd[nzchar(qd$k), , drop = FALSE]; rd <- rd[nzchar(rd$k), , drop = FALSE]
      data.table::setDT(qd); data.table::setDT(rd)
      m <- merge(qd, rd, by = "k", allow.cartesian = TRUE)
      if (!nrow(m)) {
        cand <- data.frame(.x = integer(0), .y = integer(0))
      } else {
        w <- idf[m$tok]; w[is.na(w)] <- 0
        g <- paste(m$.x, m$.y, sep = "\r")
        s <- rowsum(w, g)                       # summed shared-token IDF per pair
        keep <- rownames(s)[s[, 1] >= eff_idf]
        xy <- do.call(rbind, strsplit(keep, "\r", fixed = TRUE))
        cand <- if (length(keep))
          data.frame(.x = as.integer(xy[, 1]), .y = as.integer(xy[, 2]))
        else data.frame(.x = integer(0), .y = integer(0))
      }
    }
  }
  cand <- unique(cand)
  out <- data.frame(.x = as.integer(cand$.x), .y = as.integer(cand$.y))
  attr(out, "n_query") <- nrow(query)
  attr(out, "n_reference") <- nrow(reference)
  structure(out, class = c("np_blocks", "data.frame"))
}

#' Union candidate-pair sets from several blocking passes
#'
#' @param ... `np_blocks` objects.
#' @return A de-duplicated `np_blocks`.
#' @export
np_block_union <- function(...) {
  parts <- list(...)
  out <- unique(do.call(rbind, lapply(parts, function(p) p[, c(".x", ".y")])))
  rownames(out) <- NULL
  a <- parts[[1]]
  attr(out, "n_query") <- attr(a, "n_query")
  attr(out, "n_reference") <- attr(a, "n_reference")
  structure(out, class = c("np_blocks", "data.frame"))
}

#' @export
print.np_blocks <- function(x, ...) {
  nq <- attr(x, "n_query"); nr <- attr(x, "n_reference")
  full <- as.numeric(nq) * as.numeric(nr)
  cat("<np_blocks>", format(nrow(x), big.mark = ","), "candidate pairs\n")
  if (!is.null(nq))
    cat(sprintf("  from %s query x %s reference (%.4f%% of the full cross)\n",
                format(nq, big.mark = ","), format(nr, big.mark = ","),
                100 * nrow(x) / full))
  invisible(x)
}
