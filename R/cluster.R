#' Match one level up: roll candidates up to their family
#'
#' Some queries cannot be settled to one EIN but can be to a family: a chapter
#' of a federation, a hospital system, a school and its PTO. Often the
#' evidence is split - the name matches one member and the address another -
#' so no single candidate scores as a match, while the family plainly does.
#' `np_cluster_rollup()` finds those cases among queries that did not reach
#' `YES`, from the candidates the cascade already scored.
#'
#' @section How a cluster qualifies:
#' For each query and each cluster holding at least one of its candidates, take
#' the best name similarity and the best address similarity over the cluster's
#' candidate members. The cluster qualifies when both clear `min_name` and
#' `min_addr`, and it passes a size guard: a cluster of thousands has, by
#' chance alone, some member near the query's name and some other member near
#' its address. So one of these must hold:
#' \enumerate{
#'   \item the same member is best on both name and address (then the EIN-level
#'     result was close, and the family confirms it);
#'   \item the cluster has at most `max_size` members;
#'   \item the cluster's leading brand token - the first word of four or more
#'     letters in matchdb's `cluster.brand_tokens`, which lists the words most
#'     members share, most shared first: `ROTARY`, not `CLUB` - appears in the
#'     query's name.
#' }
#' Of several qualifying clusters the one with the highest combined score wins,
#' smaller clusters first on ties: the narrowest family that explains the
#' evidence.
#'
#' The result annotates; it does not change the EIN-level `tier`. Whether a
#' `CLUSTER` match counts as a resolution is the analysis's choice.
#'
#' @param tiered The result of [np_cascade()], carrying `attr(, "pairs")`.
#' @param clusters Cluster membership: a data frame with `cluster_id`,
#'   `cluster_type`, `.ein` (or `ein`), and optionally `size` and
#'   `brand_tokens` - matchdb's `cluster_member` joined to `cluster`.
#' @param pairs The scored candidate pairs. Defaults to `attr(tiered, "pairs")`.
#' @param query Optional query frame with `.id` and `name_key`, for the brand
#'   test. Without it, condition 3 is not used.
#' @param min_name,min_addr Similarity each side must reach within the cluster.
#' @param max_size Largest cluster accepted without the brand test.
#' @param types Cluster types to use; `NULL` for all.
#' @return A data frame, one row per query that rolls up: `.id`, `cluster_id`,
#'   `cluster_type`, `cluster_size`, `cluster_name_sim`, `cluster_addr_sim`,
#'   `cluster_score`, `name_ein`, `addr_ein`, `n_members`, `basis` (which
#'   condition admitted it).
#' @export
np_cluster_rollup <- function(tiered, clusters, pairs = attr(tiered, "pairs"),
                              query = NULL, min_name = 0.90, min_addr = 0.80,
                              max_size = 25L, types = NULL) {
  if (is.null(pairs)) stop("no scored pairs: pass `pairs`, or a result that carries them",
                           call. = FALSE)
  cl <- .np_cluster_frame(clusters, types)
  tiered <- as.data.frame(tiered)
  open_ids <- tiered$.id[as.character(tiered$tier) != "YES"]
  p <- .np_pair_sims(pairs)
  p <- p[p$.id %in% open_ids, c(".id", ".ein", "name_sim", "addr_sim", "score")]
  if (!nrow(p) || !nrow(cl)) return(.np_empty_rollup())

  m <- merge(p, cl, by = ".ein")
  if (!nrow(m)) return(.np_empty_rollup())
  key <- paste(m$.id, m$cluster_id, sep = "\r")
  best <- function(v, w) {   # value and EIN of the max per (query, cluster)
    o <- order(key, -v, m$.ein); k <- key[o]; first <- !duplicated(k)
    data.frame(k = k[first], v = v[o][first], ein = m$.ein[o][first], stringsAsFactors = FALSE)
  }
  bn <- best(m$name_sim); ba <- best(m$addr_sim)
  g <- unique(m[, c(".id", "cluster_id", "cluster_type", "size", "brand_tokens")])
  g$k <- paste(g$.id, g$cluster_id, sep = "\r")
  g$cluster_name_sim <- bn$v[match(g$k, bn$k)]; g$name_ein <- bn$ein[match(g$k, bn$k)]
  g$cluster_addr_sim <- ba$v[match(g$k, ba$k)]; g$addr_ein <- ba$ein[match(g$k, ba$k)]
  g$n_members <- as.integer(table(key)[g$k])
  g <- g[!is.na(g$cluster_name_sim) & !is.na(g$cluster_addr_sim) &
         g$cluster_name_sim >= min_name & g$cluster_addr_sim >= min_addr, , drop = FALSE]
  if (!nrow(g)) return(.np_empty_rollup())

  brand_ok <- rep(FALSE, nrow(g))
  if (!is.null(query) && !all(is.na(g$brand_tokens))) {
    qk <- stats::setNames(toupper(as.character(query$name_key)), as.character(query$.id))
    qt <- strsplit(qk[as.character(g$.id)], "\\s+")
    bt <- strsplit(toupper(ifelse(is.na(g$brand_tokens), "", g$brand_tokens)), "\\s+")
    brand_ok <- mapply(function(q, b) {
      # the most-shared long token is the distinctive one (ROTARY, not CLUB)
      b <- b[nchar(b) >= 4][1]
      !is.na(b) && b %in% q
    }, qt, bt)
  }
  g$basis <- ifelse(g$name_ein == g$addr_ein, "same_member",
             ifelse(!is.na(g$size) & g$size <= max_size, "small_cluster",
             ifelse(brand_ok, "brand", NA_character_)))
  g <- g[!is.na(g$basis), , drop = FALSE]
  if (!nrow(g)) return(.np_empty_rollup())
  g$cluster_score <- (g$cluster_name_sim + g$cluster_addr_sim) / 2
  g <- g[order(g$.id, -g$cluster_score, g$size, g$cluster_id), , drop = FALSE]
  g <- g[!duplicated(g$.id), , drop = FALSE]
  out <- data.frame(.id = g$.id, cluster_id = g$cluster_id, cluster_type = g$cluster_type,
                    cluster_size = g$size, cluster_name_sim = g$cluster_name_sim,
                    cluster_addr_sim = g$cluster_addr_sim, cluster_score = g$cluster_score,
                    name_ein = g$name_ein, addr_ein = g$addr_ein, n_members = g$n_members,
                    basis = g$basis, stringsAsFactors = FALSE)
  rownames(out) <- NULL
  out
}

#' Are a query's top two candidates one family?
#'
#' For each query, the best and second-best distinct candidate EINs, and the
#' cluster types they share. When they share one, the contest is within a
#' family - a hospital and its foundation, two chapters - not between
#' strangers. A `YES` won over a linked sibling by a thin margin is the case a
#' reference without the sibling would have auto-accepted unseen (matchdb
#' `PLAN.md` section 8a); `family_contest` marks it.
#'
#' @inheritParams np_cluster_rollup
#' @param margin A winner ahead of a linked runner-up by less than this is a
#'   `family_contest`.
#' @return A data frame, one row per query with at least two candidates: `.id`,
#'   `top_ein`, `runner_up_ein`, `top_score`, `runner_up_score`, `linked`,
#'   `link_types` (`;`-separated), `family_contest`.
#' @export
np_pair_links <- function(tiered, clusters, pairs = attr(tiered, "pairs"),
                          margin = 0.05, types = NULL) {
  if (is.null(pairs)) stop("no scored pairs: pass `pairs`, or a result that carries them",
                           call. = FALSE)
  cl <- .np_cluster_frame(clusters, types)
  p <- as.data.frame(pairs)[, c(".id", ".ein", "score")]
  if (!is.null(as.data.frame(pairs)$veto)) p <- p[!as.data.frame(pairs)$veto, , drop = FALSE]
  p <- p[order(p$.id, -p$score, p$.ein), , drop = FALSE]
  p <- p[!duplicated(paste(p$.id, p$.ein)), , drop = FALSE]
  rk <- stats::ave(seq_len(nrow(p)), p$.id, FUN = seq_along)
  t1 <- p[rk == 1, ]; t2 <- p[rk == 2, ]
  out <- data.frame(.id = t2$.id, stringsAsFactors = FALSE)
  out$top_ein <- t1$.ein[match(out$.id, t1$.id)]
  out$runner_up_ein <- t2$.ein
  out$top_score <- t1$score[match(out$.id, t1$.id)]
  out$runner_up_score <- t2$score
  memb <- split(paste(cl$cluster_id, cl$cluster_type, sep = "\t"), cl$.ein)
  shared <- mapply(function(a, b) {
    s <- intersect(memb[[a]], memb[[b]])
    if (!length(s)) "" else paste(sort(unique(sub("^.*\t", "", s))), collapse = ";")
  }, out$top_ein, out$runner_up_ein, USE.NAMES = FALSE)
  out$linked <- nzchar(shared)
  out$link_types <- shared
  tier <- as.character(as.data.frame(tiered)$tier[match(out$.id, as.data.frame(tiered)$.id)])
  out$family_contest <- out$linked & tier %in% "YES" &
    (out$top_score - out$runner_up_score) < margin
  rownames(out) <- NULL
  out
}

# Cluster membership in one shape: .ein, cluster_id, cluster_type, size,
# brand_tokens. Accepts matchdb's `ein` column name.
.np_cluster_frame <- function(clusters, types) {
  cl <- as.data.frame(clusters, stringsAsFactors = FALSE)
  if (is.null(cl$.ein) && !is.null(cl$ein)) cl$.ein <- cl$ein
  miss <- setdiff(c(".ein", "cluster_id", "cluster_type"), names(cl))
  if (length(miss)) stop("clusters lacks: ", paste(miss, collapse = ", "), call. = FALSE)
  if (is.null(cl$size)) cl$size <- stats::ave(seq_len(nrow(cl)), cl$cluster_id, FUN = length)
  if (is.null(cl$brand_tokens)) cl$brand_tokens <- NA_character_
  if (!is.null(types)) cl <- cl[cl$cluster_type %in% types, , drop = FALSE]
  cl[, c(".ein", "cluster_id", "cluster_type", "size", "brand_tokens")]
}

# name and address similarity per scored pair, exactly as np_select() reads them
.np_pair_sims <- function(pairs) {
  cmp_cols <- attr(pairs, "cmp_cols")
  df <- as.data.frame(pairs)
  if (!is.null(df$veto)) df <- df[!df$veto, , drop = FALSE]
  df$name_sim <- if ("name_key" %in% names(df)) df$name_key else 0
  acols <- .np_addr_cols(cmp_cols)
  df$addr_sim <- if (length(acols)) rowMeans(df[, acols, drop = FALSE], na.rm = TRUE) else NA_real_
  df
}

.np_empty_rollup <- function() {
  data.frame(.id = character(0), cluster_id = character(0), cluster_type = character(0),
             cluster_size = integer(0), cluster_name_sim = numeric(0),
             cluster_addr_sim = numeric(0), cluster_score = numeric(0),
             name_ein = character(0), addr_ein = character(0), n_members = integer(0),
             basis = character(0), stringsAsFactors = FALSE)
}
