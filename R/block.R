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

# Tokenize a frame's `token_col` into (row, token) pairs, applying the stopword /
# min-length filter, and (optionally) the adjacent-token concatenation. Returns
# base tokens and concat bigrams separately so a caller can use either. Shared by
# np_block()'s per-side indexing and by np_ref_index() so the two never drift.
.np_tokenize <- function(frame, token_col, stopwords, min_token_len, concat_adjacent) {
  v <- as.character(frame[[token_col]]); v[is.na(v)] <- ""
  toks <- strsplit(v, "\\s+")
  n <- nrow(frame)
  row_all <- rep(seq_len(n), lengths(toks))
  tok_all <- unlist(toks, use.names = FALSE)
  keep <- nchar(tok_all) >= min_token_len & !(tok_all %in% stopwords)
  base <- list(row = row_all[keep], token = tok_all[keep])
  concat <- list(row = integer(0), token = character(0))
  if (isTRUE(concat_adjacent)) {
    filt <- lapply(toks, function(t) t[nchar(t) >= min_token_len & !(t %in% stopwords)])
    bg <- lapply(filt, function(t)
      if (length(t) < 2L) character(0) else paste0(t[-length(t)], t[-1]))
    nb <- lengths(bg)
    concat <- list(row = rep(seq_len(n), nb), token = unlist(bg, use.names = FALSE))
  }
  list(base = base, concat = concat)
}

# Distinct-record document frequency per token. Same values as
# tapply(row, token, function(v) length(unique(v))) but far faster at scale:
# dedup (row, token) via unique.data.table (function dispatch, no `[` DSL), then a
# single table() gives distinct rows per token.
.np_doc_freq <- function(row, token) {
  if (!length(token)) return(stats::setNames(numeric(0), character(0)))
  d <- data.frame(row = row, token = token, stringsAsFactors = FALSE)
  data.table::setDT(d)
  d <- unique(d)
  tb <- table(d$token)
  stats::setNames(as.numeric(tb), names(tb))
}

# Is a precomputed np_ref_index compatible with these blocking parameters?
.np_ref_index_ok <- function(ref_index, token_col, stopwords, min_token_len) {
  inherits(ref_index, "np_ref_index") &&
    identical(ref_index$token_col, token_col) &&
    identical(ref_index$stopwords, stopwords) &&
    isTRUE(ref_index$min_token_len == min_token_len)
}

#' Precompute the reference-side token index for blocking
#'
#' Tokenizes the reference `token_col` (default `name_key`) once — the inverted
#' index plus per-token document frequency that [np_block()] otherwise rebuilds on
#' every token pass. Pass the result to [np_block()] / [np_cascade()] /
#' [np_run_batches()] via `ref_index =` to skip re-tokenizing a large reference on
#' every pass and every batch. The blocking results are identical either way.
#'
#' Both base tokens and adjacent-token concatenations (the `concat_adjacent`
#' bigrams) are indexed, so one index serves passes with or without
#' `concat_adjacent`.
#'
#' @param reference A normalized `np_reference` (from [np_normalize()]).
#' @param token_col Column to tokenize. Default `"name_key"`.
#' @param stopwords Tokens to drop (see [np_stopwords()]).
#' @param min_token_len Minimum token length to index. Default 2.
#' @return An `np_ref_index` object. It is only reused by [np_block()] when
#'   `token_col`, `stopwords`, and `min_token_len` match the block call.
#' @export
np_ref_index <- function(reference, token_col = "name_key",
                         stopwords = np_stopwords(), min_token_len = 2L) {
  stopifnot(is.data.frame(reference))
  tk <- .np_tokenize(reference, token_col, stopwords, min_token_len,
                     concat_adjacent = TRUE)
  concat_all <- list(row = c(tk$base$row, tk$concat$row),
                     token = c(tk$base$token, tk$concat$token))
  df_base   <- .np_doc_freq(tk$base$row, tk$base$token)
  df_concat <- .np_doc_freq(concat_all$row, concat_all$token)
  structure(list(token_col = token_col, stopwords = stopwords,
                 min_token_len = min_token_len, n_reference = nrow(reference),
                 base = tk$base, concat_all = concat_all,
                 df_base = df_base, df_concat = df_concat),
            class = "np_ref_index")
}

#' @export
print.np_ref_index <- function(x, ...) {
  cat("<np_ref_index>", format(x$n_reference, big.mark = ","), "reference records\n")
  cat(sprintf("  token_col = %s | %s base tokens (%s distinct)\n",
              x$token_col, format(length(x$base$row), big.mark = ","),
              format(length(x$df_base), big.mark = ",")))
  invisible(x)
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
#' @param concat_adjacent If `TRUE`, also index the concatenation of each adjacent
#'   pair of (post-stopword) tokens as an extra token. This recovers de-spacing
#'   differences symmetrically: "STEP FORWARD" emits the compound "STEPFORWARD"
#'   which matches a reference already spelled "STEPFORWARD", and vice versa. The
#'   compounds are rare (high IDF), so with `min_pair_idf` set they only justify a
#'   pair when genuinely shared. Default `FALSE`. Only used when `token`.
#' @param min_pair_idf Optional IDF-weighted pruning. A single common token
#'   (e.g. "CALIFORNIA", "CHURCH") should not by itself justify a candidate pair,
#'   but a global `max_ref_freq` can't see that such a token is concentrated
#'   within one block (state). With `min_pair_idf` set, each shared token is
#'   weighted by its inverse document frequency `log(N_ref / df)` and a pair is
#'   kept only when the sum of its shared tokens' IDF is at least this value. One
#'   rare token, or several moderately common ones, clears the bar; a lone common
#'   token does not. `NULL` (default) disables this. Only used when `token`.
#' @param ref_index Optional precomputed [np_ref_index()] for the reference's
#'   token index + document frequency. When supplied (and compatible with
#'   `token_col` / `stopwords` / `min_token_len`), the reference is not
#'   re-tokenized — the same candidate pairs are produced far faster on repeated
#'   calls (across passes and batches). Only used when `token`.
#' @return A data frame of candidate pairs with integer columns `.x` (query row)
#'   and `.y` (reference row), class `np_blocks`.
#' @export
np_block <- function(query, reference, by = "state", by_x = NULL, by_y = NULL,
                     token = TRUE, token_col = "name_key",
                     stopwords = np_stopwords(), min_token_len = 2L,
                     max_ref_freq = NULL, min_pair_idf = NULL,
                     concat_adjacent = FALSE, ref_index = NULL) {
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
      tk <- .np_tokenize(frame, token_col, stopwords, min_token_len, concat_adjacent)
      row <- c(tk$base$row, tk$concat$row)
      bk_all <- .np_bykey(frame, byk)
      data.frame(row = row, token = c(tk$base$token, tk$concat$token),
                 bk = bk_all[row], stringsAsFactors = FALSE)
    }
    qi <- idx_of(query, by_x)
    # Reference-side token index + document frequency. Reuse a precomputed
    # np_ref_index() when supplied (skips re-tokenizing the whole reference on
    # every pass / batch); otherwise build it inline. Results are identical.
    if (!is.null(ref_index) && .np_ref_index_ok(ref_index, token_col, stopwords, min_token_len)) {
      part   <- if (isTRUE(concat_adjacent)) ref_index$concat_all else ref_index$base
      ref_df <- if (isTRUE(concat_adjacent)) ref_index$df_concat else ref_index$df_base
      bk_all <- .np_bykey(reference, by_y)
      ri <- data.frame(row = part$row, token = part$token,
                       bk = bk_all[part$row], stringsAsFactors = FALSE)
    } else {
      ri <- idx_of(reference, by_y)
      ref_df <- tapply(ri$row, ri$token, function(v) length(unique(v)))
    }
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
      # Corpus size for IDF comes from the INDEX when one is supplied, not from
      # the frame. For every ordinary caller these are the same number, because
      # the index was built from this very reference -- so this is a no-op.
      #
      # It differs only when the reference has been deliberately partitioned and
      # the index carries whole-corpus statistics: blocking a CA slice should
      # gate tokens by how common they are NATIONALLY, not by how common they
      # are within California. Without this, idf = log(n_ref / ref_df) shifts by
      # log(N_full / N_slice) for every token -- 2.25 on a 10.6% slice -- and
      # min_pair_idf then prunes a different candidate set, so a partitioned run
      # cannot reproduce an unpartitioned one.
      # See pfmatch/dev/STATE-PARTITION-FINDINGS.md.
      n_ref <- if (!is.null(ref_index) &&
                   .np_ref_index_ok(ref_index, token_col, stopwords, min_token_len) &&
                   !is.null(ref_index$n_reference)) ref_index$n_reference
               else nrow(reference)
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
