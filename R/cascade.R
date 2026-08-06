#' Default progressive blocking passes
#'
#' The tight-to-loose blocking cascade used by [np_cascade()]. Each pass is a
#' list with a `name`, a human-readable `desc` (the decision criterion, shown in
#' the stage report), and `args` passed to [np_block()]. Earlier passes are cheap
#' and high-precision; later passes are looser and only run on the residual
#' (queries not yet auto-accepted).
#'
#' The first tier is four **exact** passes that exploit both the legal name and
#' the DBA on each side (name==name, name==dba, dba==name, dba==dba), then
#' name-token blocking within state, then a cross-state token pass for the
#' firm-vs-establishment case.
#'
#' @return A list of pass specifications.
#' @export
np_default_passes <- function() {
  ex <- function(name, desc, x, y)
    list(name = name, desc = desc,
         args = list(by_x = c("state", x), by_y = c("state", y), token = FALSE))
  list(
    ex("exact-name",     "name == name (exact, same state)", "name_key", "name_key"),
    ex("exact-name-dba", "name == dba  (exact, same state)", "name_key", "dba_key"),
    ex("exact-dba-name", "dba == name  (exact, same state)", "dba_key",  "name_key"),
    ex("exact-dba-dba",  "dba == dba   (exact, same state)", "dba_key",  "dba_key"),
    list(name = "token-state", desc = "shared name token, same state",
         args = list(by = "state", token = TRUE, max_ref_freq = 25000,
                     min_pair_idf = 8)),
    list(name = "token-concat", desc = "shared token incl. de-spaced compound, same state",
         args = list(by = "state", token = TRUE, concat_adjacent = TRUE,
                     max_ref_freq = 25000, min_pair_idf = 8)),
    list(name = "token-crossstate", desc = "shared name token, any state",
         args = list(by = NULL, token = TRUE, max_ref_freq = 5000,
                     min_pair_idf = 8))
  )
}

# Compact description of the scoring decision criteria for the stage report.
.np_criteria <- function(config, method, profile) {
  th <- config$thresholds
  head <- sprintf("YES>=%.2f  MAYBE>=%.2f  margin>=%.2f",
                  th[["yes"]], th[["maybe"]], config$min_margin)
  if (method == "hier") {
    ng <- config$name_geo; gw <- config$geo_weights
    body <- sprintf("score = %.2f*name + %.2f*geo;  geo = max(%s)",
                    ng[["name"]], ng[["geo"]],
                    paste(sprintf("%s=%.2f", names(gw), gw), collapse = ", "))
  } else if (method == "weighted") {
    w <- config$weights[[profile]]
    body <- sprintf("weighted sum [%s]: %s",
                    profile, paste(sprintf("%s=%.2f", names(w), w), collapse = ", "))
  } else {
    body <- sprintf("method = %s", method)
  }
  c(head, body)
}

#' Match with a progressive blocking cascade
#'
#' Runs [np_block()] -> [np_compare()] -> [np_score()] -> [np_veto()] pass by
#' pass, tight to loose. After each pass, queries that reached the YES tier are
#' removed from the pending set, so each successive (more expensive) pass only
#' processes the harder residual. Candidate pairs are scored once; the final
#' [np_select()] / [np_tier()] run over the de-duplicated union, so a match found
#' by a looser pass still competes on equal footing (and the runner-up margin is
#' computed across all of a query's candidates).
#'
#' With `verbose = TRUE` it reports the scoring method and decision criteria
#' once, then per stage: candidates generated, YES / MAYBE / NO found, how many
#' were resolved, how many remain pending, and the median YES margin.
#'
#' @param query,reference Raw data frames or `np_query`/`np_reference`.
#' @param config An [np_config()].
#' @param method Scoring method for [np_score()] (default `"hier"`).
#' @param passes A list of pass specs (see [np_default_passes()]).
#' @param verbose Print the per-stage report. Default `TRUE`.
#' @param query_map,reference_map Schema maps for raw inputs.
#' @return An `np_tiered` result with a `pass` column recording which pass
#'   produced each query's chosen match. A per-stage summary is attached as
#'   `attr(result, "stages")`; the scored candidate union as `attr(result, "pairs")`.
#' @export
np_cascade <- function(query, reference, config = np_config(), method = "hier",
                       passes = np_default_passes(), verbose = TRUE,
                       query_map = np_map_sam(), reference_map = np_map_bmf()) {
  if (!inherits(query, "np_query"))         query <- np_query(query, query_map)
  if (!inherits(reference, "np_reference")) reference <- np_reference(reference, reference_map)
  q <- np_normalize(query); r <- np_normalize(reference)
  q$.id <- as.character(q$.id)
  name_freq <- np_name_freq(r$name_key)          # distinctiveness reference

  pending <- unique(q$.id)
  acc <- list(); stages <- list(); cmp_cols <- NULL; profile <- NULL
  say <- function(...) if (verbose) message(sprintf(...))

  crit <- .np_criteria(config, method, np_detect_geo(q))
  say("np_cascade: method = %s | %s", method, crit[[1]])
  say("  %s", crit[[2]])

  for (p in passes) {
    if (!length(pending)) break
    q_sub <- q[q$.id %in% pending, , drop = FALSE]
    if (!nrow(q_sub)) break

    blk <- do.call(np_block, c(list(q_sub, r), p$args))
    if (!nrow(blk)) {
      say("  [%-16s] %-32s     0 candidates", p$name, p$desc); next
    }
    blk$.x <- match(q_sub$.id[blk$.x], q$.id)          # remap to full-query rows

    pr <- np_veto(np_score(np_compare(q, r, config, candidates = blk,
                                      name_freq = name_freq),
                           config, method = method))
    if (is.null(cmp_cols)) { cmp_cols <- attr(pr, "cmp_cols"); profile <- attr(pr, "profile") }
    df <- as.data.frame(pr); df$pass <- p$name
    acc[[p$name]] <- df

    sel <- np_tier(np_select(pr, config), config)
    t <- table(factor(as.character(sel$tier), c("YES", "MAYBE", "NO")))
    yes_ids <- as.character(sel$.id[as.character(sel$tier) == "YES"])
    med_margin <- stats::median(sel$overall_margin[as.character(sel$tier) == "YES"], na.rm = TRUE)
    pending <- setdiff(pending, yes_ids)

    say("  [%-16s] %-32s %5s cand -> %4d YES  %4d MAYBE  %4d NO | resolved %d, pending %d, med YES margin %.2f",
        p$name, p$desc, format(nrow(blk), big.mark = ","),
        t[["YES"]], t[["MAYBE"]], t[["NO"]], length(yes_ids), length(pending),
        ifelse(is.nan(med_margin), NA_real_, med_margin))
    stages[[p$name]] <- data.frame(
      pass = p$name, criteria = p$desc, candidates = nrow(blk),
      yes = t[["YES"]], maybe = t[["MAYBE"]], no = t[["NO"]],
      resolved = length(yes_ids), pending = length(pending),
      median_yes_margin = ifelse(is.nan(med_margin), NA_real_, med_margin),
      stringsAsFactors = FALSE)
  }
  if (!length(acc)) stop("No candidate pairs were generated by any pass.", call. = FALSE)

  union <- as.data.frame(data.table::rbindlist(acc, fill = TRUE))
  union <- union[!duplicated(paste(union$.id, union$.ein)), , drop = FALSE]  # keep tightest pass
  attr(union, "cmp_cols") <- cmp_cols
  attr(union, "profile")  <- profile
  class(union) <- c("np_pairs", "data.frame")

  res <- np_tier(np_select(union, config), config)
  res$pass <- union$pass[match(paste(res$.id, res$overall_ein),
                               paste(union$.id, union$.ein))]
  ft <- table(factor(as.character(res$tier), c("YES", "MAYBE", "NO")))
  say("  final: %d YES | %d MAYBE | %d NO over %d/%d queries",
      ft[["YES"]], ft[["MAYBE"]], ft[["NO"]], nrow(res), nrow(q))

  attr(res, "stages") <- do.call(rbind, stages)
  attr(res, "pairs")  <- union
  attr(res, "config") <- config
  res
}
