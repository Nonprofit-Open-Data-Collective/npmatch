# Hierarchical geo score: name similarity + a location sub-score that takes the
# strongest confirmed granularity via max(). Exact granularity signals come from
# np_compare (geo_*); the fuzzy city / street terms reuse the JW columns.
.np_hier_score <- function(pairs, config) {
  n <- nrow(pairs)
  z <- function(v) { v <- as.numeric(v); v[is.na(v)] <- 0; v }
  g0 <- function(nm) if (!is.null(pairs[[nm]])) z(pairs[[nm]]) else rep(0, n)

  gw <- config$geo_weights
  # NB: reclin2's cmp_jarowinkler(threshold=) is the Winkler prefix boost, NOT a
  # floor -- unrelated strings still return ~0.5. Floor the fuzzy geo terms here
  # so a non-matching city/street contributes nothing to the location evidence.
  thr <- config$jw_threshold
  floor_sim <- function(v) ifelse(v >= thr, v, 0)
  name_score  <- g0("name_key")                      # name JW similarity
  city_sim    <- floor_sim(g0("city"))               # JW, floored at jw_threshold
  street_sim  <- floor_sim(g0("street_key"))         # JW over the street body

  geo_zip9  <- g0("geo_zip9");  geo_zip5 <- g0("geo_zip5")
  geo_zip3  <- g0("geo_zip3");  geo_state <- g0("geo_state")
  geo_stnum <- g0("geo_stnum"); geo_pobox <- g0("geo_pobox")

  # same physical building: matching street number AND a close street body,
  # for non-PO-box addresses
  street_hit <- as.numeric(geo_stnum == 1 & street_sim >= 0.9 & geo_pobox == 0)
  pobox_hit  <- as.numeric(geo_pobox == 1 & geo_stnum == 1)

  terms <- cbind(
    gw[["zip9"]]  * geo_zip9,
    gw[["street"]] * street_hit,
    gw[["zip5"]]  * geo_zip5,
    gw[["pobox"]] * pobox_hit,
    gw[["zip3"]]  * geo_zip3,
    gw[["city"]]  * city_sim,
    gw[["state"]] * geo_state
  )
  geo_score <- do.call(pmax, c(as.data.frame(terms), na.rm = TRUE))

  ng <- config$name_geo
  score <- as.numeric(ng[["name"]] * name_score + ng[["geo"]] * geo_score)

  # Distinctive-exact-name promotion: an exact match on a name that is rare in
  # the reference (few records share it) is trustworthy even without address
  # corroboration. Common names shared by many records (First Baptist Church,
  # Community Center) are NOT promoted. State-confirmed promotions are reliable
  # (~97% on the training set); cross-state exact-name-only matches are near a
  # coin flip (~40%), so they get a lower floor that lands in MAYBE for review
  # rather than being auto-accepted. A missing xstate floor keeps prior behaviour.
  nf <- if (!is.null(pairs$name_freq)) as.numeric(pairs$name_freq) else rep(NA, n)
  promote <- !is.na(nf) & name_score >= 0.95 & nf <= config$distinct_name_maxfreq
  fx <- config$distinct_name_floor_xstate
  if (is.null(fx)) fx <- config$distinct_name_floor
  floor_val <- ifelse(geo_state == 1, config$distinct_name_floor, fx)
  score[promote] <- pmax(score[promote], floor_val[promote])
  score
}

.np_rescale01 <- function(x) {
  r <- range(x, na.rm = TRUE)
  if (!is.finite(r[1]) || diff(r) == 0) return(rep(0.5, length(x)))
  (x - r[1]) / diff(r)
}

#' Score candidate pairs
#'
#' Collapses the per-field similarities of an [np_compare()] result into a single
#' `score` in \[0, 1\]. Three methods are provided so the "best" combiner can be
#' chosen empirically against a labelled training set:
#'
#' * `"weighted"` — normalized weighted sum using the profile weights in
#'   `config`. Transparent, no training required. The default.
#' * `"hier"` — name similarity plus a *hierarchical* geo sub-score that takes
#'   the strongest confirmed location granularity (ZIP+4 > street > ZIP5 > PO box
#'   > ZIP3 > city > state) via a `max`, not a sum. Correlated address fields are
#'   not double-counted, and a wrong city cannot pull down a ZIP-confirmed match.
#'   Degrades gracefully as geo fields go missing. See [np_default_geo_weights()].
#' * `"em"` — unsupervised Fellegi-Sunter weights via [reclin2::problink_em()];
#'   `score` is the match posterior. Learns weights from the data.
#' * `"model"` — apply a fitted classifier (`glm`, `ranger`, `xgboost`, ...)
#'   supplied in `model` to the per-field similarity columns; `score` is its
#'   predicted match probability. This is the hook for supervised optimization.
#'
#' The chosen method's raw output is retained (`weight_em`, `p_model`) so methods
#' can be compared side by side before one is adopted.
#'
#' @param pairs An `np_pairs` frame from [np_compare()].
#' @param config An [np_config()].
#' @param method One of `"weighted"`, `"em"`, `"model"`.
#' @param model A fitted model with a `predict()` method, required for
#'   `method = "model"`. Must accept a data frame of the similarity columns.
#' @return `pairs` with a numeric `score` column added (and method raw output).
#' @export
np_score <- function(pairs, config = np_config(),
                     method = c("weighted", "hier", "em", "model"), model = NULL) {
  method   <- match.arg(method)
  cmp_cols <- attr(pairs, "cmp_cols")
  profile  <- attr(pairs, "profile")

  if (method == "hier") {
    pairs$score <- .np_hier_score(pairs, config)
    pairs$score[is.na(pairs$score)] <- 0
    return(pairs)

  } else if (method == "weighted") {
    w_named <- config$weights[[profile]]
    if (is.null(w_named)) w_named <- stats::setNames(rep(1, length(cmp_cols)), cmp_cols)
    # translate profile field weights (name, city, ...) to compare columns
    fld_for_col <- names(.np_compare_col)[match(cmp_cols, .np_compare_col)]
    w <- w_named[fld_for_col]
    w[is.na(w)] <- 0
    if (sum(w) == 0) w[] <- 1
    w <- w / sum(w)
    M <- as.matrix(pairs[, cmp_cols, drop = FALSE])
    pairs$score <- as.numeric(M %*% w)

  } else if (method == "em") {
    if (!requireNamespace("reclin2", quietly = TRUE)) {
      stop("method = 'em' requires reclin2.", call. = FALSE)
    }
    rp <- attr(pairs, "reclin_pairs")
    if (is.null(rp)) stop("EM needs the reclin2 pairs object from np_compare().", call. = FALSE)
    form <- stats::as.formula(paste("~", paste(cmp_cols, collapse = " + ")))
    m <- reclin2::problink_em(form, data = rp)
    pred <- as.data.frame(predict(m, pairs = rp, type = "all", add = FALSE))
    # rows of pred align with rp, which aligns with pairs (same construction order)
    pairs$weight_em <- pred$weights
    post <- if ("mpost" %in% names(pred)) pred$mpost else NULL
    pairs$score <- if (!is.null(post)) post else .np_rescale01(pred$weights)

  } else { # model
    if (is.null(model)) stop("method = 'model' needs a fitted `model`.", call. = FALSE)
    newd <- as.data.frame(pairs)[, cmp_cols, drop = FALSE]
    p <- tryCatch(
      as.numeric(predict(model, newd, type = "response")),
      error = function(e) as.numeric(predict(model, newd))
    )
    pairs$p_model <- p
    pairs$score   <- p
  }

  pairs$score[is.na(pairs$score)] <- 0
  pairs
}
