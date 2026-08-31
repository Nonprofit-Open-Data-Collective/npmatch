# ---------------------------------------------------------------------------
# Query batching + a batched stage-1 driver.
#
# A large source (e.g. all SAM nonprofits) is matched in chunks so that (a) the
# reference is normalized ONCE and reused across chunks, and (b) each chunk's
# review (MAYBE) queue is a manageable, LLM-validation-sized hand-off. See
# np_cascade() for the per-chunk stage-1 chain and np_route() for the hand-off.
# ---------------------------------------------------------------------------

# Normalize raw SAM-style headers ("UNIQUE ENTITY ID") to the lower_underscore
# names np_map_sam() expects ("unique_entity_id"). Idempotent on already-lower
# names. Not applied to an np_query (whose columns are the canonical .id/name/...).
.np_norm_headers <- function(x) {
  x <- tolower(trimws(as.character(x)))
  x <- gsub("[^a-z0-9]+", "_", x)
  gsub("^_+|_+$", "", x)
}

#' Split a data frame into batches
#'
#' Partitions the rows of a data frame into evenly sized batches for chunked
#' processing (e.g. feeding a large source through [np_run_batches()] a chunk at
#' a time). Rows are shuffled first (deterministically, given `seed`) so each
#' batch is a representative slice rather than an accident of source ordering.
#'
#' Batches are made **as even as possible**: with `size`, the number of batches
#' is `ceiling(nrow / size)` and each batch holds `nrow / n_batches` rows (so a
#' batch is never larger than `size`, and there is no tiny remainder batch); with
#' `n`, the rows are split into exactly `n` near-equal batches.
#'
#' @param x A data frame.
#' @param size Target rows per batch. Ignored if `n` is supplied. Default 2500 —
#'   at the observed ~8% review rate this yields ~200 review cases per batch, one
#'   LLM-validation pass.
#' @param n Number of batches. Overrides `size` when given.
#' @param shuffle Shuffle rows before splitting. Default `TRUE`.
#' @param seed Optional RNG seed for reproducible shuffling. The global RNG state
#'   is saved and restored, so callers are unaffected.
#' @return A list of data frames (the batches), with attribute `n_batches`.
#'   An empty input returns an empty list.
#' @examples
#' b <- np_batch(mtcars, size = 10, seed = 1)
#' length(b); vapply(b, nrow, integer(1))
#' @export
np_batch <- function(x, size = 2500L, n = NULL, shuffle = TRUE, seed = NULL) {
  x <- as.data.frame(x, stringsAsFactors = FALSE)
  N <- nrow(x)
  if (N == 0L) return(structure(list(), n_batches = 0L))

  if (!is.null(seed)) {
    if (exists(".Random.seed", envir = .GlobalEnv)) {
      old_seed <- get(".Random.seed", envir = .GlobalEnv)
      on.exit(assign(".Random.seed", old_seed, envir = .GlobalEnv), add = TRUE)
    } else {
      on.exit(if (exists(".Random.seed", envir = .GlobalEnv))
        rm(".Random.seed", envir = .GlobalEnv), add = TRUE)
    }
    set.seed(seed)
  }

  ord <- if (shuffle) sample.int(N) else seq_len(N)
  nb  <- if (!is.null(n)) max(1L, as.integer(n)) else max(1L, as.integer(ceiling(N / size)))
  nb  <- min(nb, N)
  # near-equal contiguous bins over 1..N, then map through the shuffled order
  # (cut() needs >= 2 breaks; a single batch is just everything)
  bins <- if (nb <= 1L) rep(1L, N) else as.integer(cut(seq_len(N), breaks = nb, labels = FALSE))
  out <- lapply(seq_len(nb), function(b) {
    rows <- ord[bins == b]
    d <- x[rows, , drop = FALSE]
    rownames(d) <- NULL
    d
  })
  structure(out, n_batches = nb)
}

# Split a review frame into LLM-sized shards by query id (all candidate rows of a
# query stay together, ~review_size queries per shard). Returns the file paths.
.np_write_review_shards <- function(review, base, review_size, id_col = "uei") {
  if (!nrow(review) || !(id_col %in% names(review))) return(character(0))
  ids <- unique(as.character(review[[id_col]]))
  grp <- ceiling(seq_along(ids) / review_size)
  files <- character(0)
  for (g in unique(grp)) {
    sub <- review[as.character(review[[id_col]]) %in% ids[grp == g], , drop = FALSE]
    f <- sprintf("%s-part%02d.csv", base, g)
    data.table::fwrite(sub, f)
    files <- c(files, f)
  }
  files
}

#' Run stage-1 matching in batches against a shared reference
#'
#' Drives the full stage-1 cascade ([np_cascade()]) over a large source in
#' [np_batch()] chunks, normalizing the reference **once** and reusing it (plus
#' the `name_freq` / `token_idf` tables) for every chunk — turning the ~one-time
#' reference normalization into exactly that. For each batch it writes an accepted
#' crosswalk (YES picks), a review queue (the MAYBE hand-off for LLM/human
#' validation, from [np_route()]), and a short per-batch report; it accumulates a
#' run summary across batches.
#'
#' The reference is normalized once via [np_reference()] + [np_normalize()] (or
#' reused if already normalized). When `cache` is a path, the normalized
#' reference and its `name_freq`/`token_idf` tables are saved there and reloaded
#' on the next run, so a resumed or re-run job skips normalization entirely.
#'
#' @param query Raw source data frame (e.g. a SAM nonprofit subset). Raw
#'   uppercase SAM headers are normalized to the names [np_map_sam()] expects; an
#'   `np_query` is used as-is.
#' @param reference The reference BMF: a raw data frame, an [np_reference()], or a
#'   pre-normalized reference (the latter two skip the corresponding step).
#' @param compute_size Queries per **compute chunk** — one [np_cascade()] call.
#'   This is the memory-bound knob (candidate pairs scale with chunk size); make
#'   it as large as memory allows to amortize the per-chunk pass machinery.
#'   `NULL` (default) runs the whole query in a single chunk ("match big").
#' @param review_size **Review-file** size: the number of MAYBE queries written per
#'   review shard (`review-NN-partKK.csv`), sized to one LLM-validation job.
#'   Default 250. Decouples the LLM hand-off size from the compute chunk size.
#' @param size Deprecated alias for `compute_size` (back-compat). Ignored if
#'   `compute_size` is given.
#' @param seed Passed to [np_batch()] to shuffle before chunking.
#' @param out_dir Directory for the per-chunk outputs and the run summary. Created
#'   if needed.
#' @param only Optional integer vector of compute-chunk numbers to run (e.g. `1`
#'   to run just the first chunk as a demo). Default: all chunks.
#' @param config,method Passed to [np_cascade()].
#' @param query_map,reference_map Schema maps for raw inputs.
#' @param cache Optional `.rds` path to cache/reuse the normalized reference and
#'   its `name_freq`/`token_idf` tables and blocking `ref_index`.
#' @param sam_context Optional raw SAM frame passed to [np_route()] (`sam =`) to
#'   add `SAM_`-prefixed context columns to the review queue.
#' @param bmf_context Optional raw processed BMF passed to [np_route()]
#'   (`bmf =`) to add `BMF_`-prefixed context columns (NTEE, subsection, ruling
#'   year, assets, revenue) to the review queue.
#' @param review_tiers Tiers to include in the per-chunk review frame, passed to
#'   [np_route()]. Default `"MAYBE"` — the human/LLM hand-off only. Pass
#'   `c("YES","MAYBE","NO")` for a candidate-level frame spanning every outcome,
#'   which is what an evaluation frame needs.
#' @param save_interim Optional directory in which to persist, per chunk, the
#'   cascade result (`res-NN.rds`) and its scored candidate pairs
#'   (`pairs-NN.rds`). Without this they are discarded when the chunk ends, and
#'   the candidate sets cannot be rebuilt except by re-running the match.
#' @param threads data.table thread count for the blocking joins / reads. Default
#'   `NULL` uses all detected cores for the run and restores the prior setting on
#'   exit; pass an integer to pin it, or `0` to leave the global setting untouched.
#' @param verbose Print progress. Default `TRUE`.
#' @return A data frame summarising each compute chunk (rows, YES/MAYBE/NO,
#'   coverage, seconds, output paths, review-shard count), invisibly. Written to
#'   `out_dir/run-summary.csv`.
#' @export
np_run_batches <- function(query, reference,
                           compute_size = NULL, review_size = 250L,
                           size = NULL, out_dir = ".", only = NULL,
                           config = np_config(), method = "hier",
                           query_map = np_map_sam(), reference_map = np_map_bmf(),
                           seed = 1L, cache = NULL, sam_context = NULL,
                           bmf_context = NULL, review_tiers = "MAYBE",
                           save_interim = NULL, threads = NULL, verbose = TRUE) {
  say <- function(...) if (verbose) message(sprintf(...))
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

  # --- data.table threads: use all cores for the join-heavy blocking, restore after ---
  if (is.null(threads))
    threads <- tryCatch(max(1L, parallel::detectCores()), error = function(e) 0L)
  if (!is.na(threads) && threads > 0L) {
    old_dt <- data.table::getDTthreads()
    data.table::setDTthreads(threads)
    on.exit(data.table::setDTthreads(old_dt), add = TRUE)
    say("data.table threads: %d", threads)
  }

  # --- reference: normalize + index once (or reuse cache / an already-normalized ref) ---
  ref_index <- NULL
  if (!is.null(cache) && file.exists(cache)) {
    say("reusing cached normalized reference: %s", cache)
    cc <- readRDS(cache)
    ref_norm <- cc$reference; name_freq <- cc$name_freq; token_idf <- cc$token_idf
    ref_index <- cc$ref_index                       # may be absent in an older cache
  } else {
    t_ref <- Sys.time()
    if (!inherits(reference, "np_reference"))
      reference <- np_reference(reference, reference_map)
    ref_norm <- if (is.null(reference$name_key)) np_normalize(reference) else reference
    say("normalizing reference (%s rows) ...", format(nrow(ref_norm), big.mark = ","))
    name_freq <- np_name_freq(ref_norm$name_key)
    token_idf <- np_token_idf(ref_norm$name_key)
    ref_index <- np_ref_index(ref_norm)
    say("reference ready in %.1f min", as.numeric(difftime(Sys.time(), t_ref, units = "mins")))
    if (!is.null(cache)) {
      saveRDS(list(reference = ref_norm, name_freq = name_freq,
                   token_idf = token_idf, ref_index = ref_index), cache)
      say("cached normalized reference -> %s", cache)
    }
  }
  if (is.null(ref_index)) {                          # older cache without an index
    say("building blocking index (one-time) ...")
    ref_index <- np_ref_index(ref_norm)
    if (!is.null(cache) && file.exists(cache)) {     # upgrade the cache in place
      saveRDS(list(reference = ref_norm, name_freq = name_freq,
                   token_idf = token_idf, ref_index = ref_index), cache)
      say("upgraded cache with blocking index -> %s", cache)
    }
  }

  # --- query: normalize headers (raw source only), then split into compute chunks ---
  if (!inherits(query, "np_query")) {
    query <- as.data.frame(query, stringsAsFactors = FALSE)
    names(query) <- .np_norm_headers(names(query))
  }
  if (is.null(compute_size)) compute_size <- size          # `size` = back-compat alias
  chunks <- if (is.null(compute_size))
    np_batch(query, n = 1L, seed = seed, shuffle = TRUE)    # "match big": one chunk
  else
    np_batch(query, size = compute_size, seed = seed, shuffle = TRUE)
  nb <- attr(chunks, "n_batches")
  say("split %s query rows into %d compute chunk(s)%s; review shards of ~%d queries",
      format(nrow(query), big.mark = ","), nb,
      if (is.null(compute_size)) " (match-big)" else sprintf(" of ~%d", compute_size),
      review_size)

  # chunk manifest (uei -> chunk) so a partial run is reproducible / resumable
  id_col <- intersect(unname(query_map[".id"]), names(query))
  if (length(id_col)) {
    man <- do.call(rbind, lapply(seq_len(nb), function(b)
      data.frame(uei = as.character(chunks[[b]][[id_col]]), batch = b,
                 stringsAsFactors = FALSE)))
    data.table::fwrite(man, file.path(out_dir, "batch-index.csv"))
  }

  idx <- if (is.null(only)) seq_len(nb) else intersect(as.integer(only), seq_len(nb))
  summ <- list()
  for (b in idx) {
    t0 <- Sys.time()
    say("=== compute chunk %d/%d (%d rows) ===", b, nb, nrow(chunks[[b]]))
    res <- np_cascade(chunks[[b]], ref_norm, config = config, method = method,
                      query_map = query_map, name_freq = name_freq,
                      token_idf = token_idf, ref_index = ref_index, verbose = verbose)
    routing <- np_route(res, review_tiers = review_tiers, token_idf = token_idf,
                        sam = sam_context, bmf = bmf_context)
    secs <- as.numeric(difftime(Sys.time(), t0, units = "secs"))

    tt <- table(factor(as.character(res$tier), c("YES", "MAYBE", "NO")))
    xwalk_path  <- file.path(out_dir, sprintf("crosswalk-%02d.csv", b))
    review_path <- file.path(out_dir, sprintf("review-%02d.csv", b))
    unmat_path  <- file.path(out_dir, sprintf("unmatched-%02d.csv", b))
    report_path <- file.path(out_dir, sprintf("report-%02d.md", b))
    data.table::fwrite(routing$accepted,  xwalk_path)
    data.table::fwrite(routing$review,    review_path)         # canonical (whole chunk)
    data.table::fwrite(routing$unmatched, unmat_path)          # the NO tier + near-miss

    # The scored pairs are the only record of what blocking actually surfaced.
    # Discarding them means a later evaluation frame cannot be built without a
    # full re-match -- under changed code, against a different candidate set.
    if (!is.null(save_interim)) {
      dir.create(save_interim, recursive = TRUE, showWarnings = FALSE)
      saveRDS(res, file.path(save_interim, sprintf("res-%02d.rds", b)))
      saveRDS(attr(res, "pairs"), file.path(save_interim, sprintf("pairs-%02d.rds", b)))
    }
    # LLM-sized review shards (match big, review small)
    shard_files <- .np_write_review_shards(
      routing$review, file.path(out_dir, sprintf("review-%02d", b)), review_size)

    stages <- attr(res, "stages")
    writeLines(c(
      sprintf("# Compute chunk %d stage-1 report", b),
      "",
      sprintf("- rows: %d", nrow(chunks[[b]])),
      sprintf("- YES (accepted): %d", tt[["YES"]]),
      sprintf("- MAYBE (review -> LLM): %d  in %d shard(s) of ~%d queries",
              tt[["MAYBE"]], length(shard_files), review_size),
      sprintf("- NO: %d", tt[["NO"]]),
      sprintf("- coverage: %d/%d queries with a candidate", nrow(res), nrow(chunks[[b]])),
      sprintf("- runtime: %.1f min", secs / 60),
      "",
      "## Per-pass cascade",
      if (!is.null(stages))
        c(paste(c("pass", "candidates", "yes", "maybe", "no"), collapse = " | "),
          apply(stages[, c("pass", "candidates", "yes", "maybe", "no")], 1,
                paste, collapse = " | "))
      else "(no stage table)",
      "",
      sprintf("Crosswalk: %s", basename(xwalk_path)),
      sprintf("Review shards: %s",
              if (length(shard_files)) paste(basename(shard_files), collapse = ", ") else "(none)")
    ), report_path)

    summ[[length(summ) + 1L]] <- data.frame(
      batch = b, rows = nrow(chunks[[b]]),
      yes = tt[["YES"]], maybe = tt[["MAYBE"]], no = tt[["NO"]],
      coverage = nrow(res), secs = round(secs, 1),
      crosswalk = xwalk_path, review = review_path, unmatched = unmat_path,
      review_files = length(shard_files),
      stringsAsFactors = FALSE)
    say("chunk %d: %d YES | %d MAYBE (%d shard) | %d NO in %.1f min -> %s",
        b, tt[["YES"]], tt[["MAYBE"]], length(shard_files), tt[["NO"]],
        secs / 60, basename(xwalk_path))
  }

  summary_df <- if (length(summ)) do.call(rbind, summ) else
    data.frame(batch = integer(), rows = integer(), yes = integer(),
               maybe = integer(), no = integer(), coverage = integer(),
               secs = numeric(), crosswalk = character(), review = character(),
               unmatched = character(), review_files = integer(),
               stringsAsFactors = FALSE)
  data.table::fwrite(summary_df, file.path(out_dir, "run-summary.csv"))
  invisible(summary_df)
}
