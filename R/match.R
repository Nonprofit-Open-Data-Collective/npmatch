#' Run the full linkage pipeline
#'
#' Convenience wrapper chaining normalize -> compare -> score -> veto -> select
#' -> tier. Intermediate objects are attached as attributes for inspection.
#'
#' @param query A raw query data frame, or an `np_query` from [np_query()].
#' @param reference A raw reference data frame, or an `np_reference`.
#' @param config An [np_config()].
#' @param method Scoring method for [np_score()].
#' @param model A fitted [np_train()] model, required when `method = "model"`.
#' @param block,profile,candidates Passed to [np_compare()]; supply
#'   `candidates` from [np_block()] for the scalable name-token blocking path.
#' @param query_map,reference_map Schema maps used only if `query`/`reference`
#'   are raw data frames.
#' @return An `np_tiered` result. The scored candidate pairs are attached as
#'   `attr(result, "pairs")`.
#' @export
np_match <- function(query, reference, config = np_config(),
                     method = "weighted", model = NULL,
                     block = "state", profile = NULL, candidates = NULL,
                     query_map = np_map_sam(), reference_map = np_map_bmf()) {
  if (!inherits(query, "np_query"))         query <- np_query(query, query_map)
  if (!inherits(reference, "np_reference")) reference <- np_reference(reference, reference_map)

  query     <- np_normalize(query)
  reference <- np_normalize(reference)

  pairs <- np_compare(query, reference, config, block = block, profile = profile,
                      candidates = candidates,
                      name_freq = np_name_freq(reference$name_key))
  pairs <- np_score(pairs, config, method = method, model = model)
  pairs <- np_veto(pairs, config)

  sel <- np_select(pairs, config)
  res <- np_tier(sel, config)
  attr(res, "pairs") <- pairs
  res
}

#' Preview the field-by-field comparison for one candidate pair
#'
#' Reconstructs, for a single query/reference pair, the values compared on each
#' field and their similarity — the view a human reviewer needs. Adapted from the
#' prototype `preview_pair()`.
#'
#' @param pairs An `np_pairs` frame.
#' @param id A query `.id`.
#' @param ein A reference `.ein`. Defaults to that query's top-scoring pair.
#' @return A small data frame: one row per compared field.
#' @export
np_preview_pair <- function(pairs, id, ein = NULL) {
  df <- as.data.frame(pairs)
  sub <- df[df$.id == id, , drop = FALSE]
  if (nrow(sub) == 0) stop("No pairs for .id = ", id, call. = FALSE)
  if (is.null(ein)) ein <- sub$.ein[which.max(sub$score)]
  row <- sub[sub$.ein == ein, , drop = FALSE][1, ]
  cmp_cols <- attr(pairs, "cmp_cols")
  data.frame(
    field = cmp_cols,
    similarity = round(as.numeric(row[cmp_cols]), 3),
    row.names = NULL
  )
}
