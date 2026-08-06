# A rule tests the pair-level frame and returns TRUE where the pair violates a
# do-not-match constraint. Both-sided features are `_x` / `_y`. Rules carry a
# severity: "hard" forces NO; "soft" blocks auto-YES (caps the pair at MAYBE and
# sends it to refinement) but does not by itself reject the pair.

.np_present <- function(a) !is.na(a) & nzchar(a)
.np_both_present <- function(a, b) .np_present(a) & .np_present(b)

# generation markers disagree AND both are present: JR vs SR, II vs III -> hard.
.np_rule_generation <- function(df) {
  a <- df$name_gen_rank_x; b <- df$name_gen_rank_y
  .np_both_present(a, b) & a != b
}

# one side carries a generation marker, the other none -> soft (e.g. "... JR
# Center" vs "... Center" may or may not be the same org).
.np_rule_generation_asym <- function(df) {
  a <- df$name_gen_rank_x; b <- df$name_gen_rank_y
  xor(.np_present(a), .np_present(b))
}

.np_rule_number <- function(df) {
  a <- strsplit(ifelse(is.na(df$name_nums_x), "", df$name_nums_x), " ")
  b <- strsplit(ifelse(is.na(df$name_nums_y), "", df$name_nums_y), " ")
  mapply(function(x, y) {
    x <- x[nzchar(x)]; y <- y[nzchar(y)]
    length(x) > 0 && length(y) > 0 && length(intersect(x, y)) == 0
  }, a, b)
}

.np_rule_ordinal <- function(df) {
  a <- df$name_ord_x; b <- df$name_ord_y
  .np_both_present(a, b) & a != b
}

# directional markers disagree AND both present: SOUTHWEST vs SOUTHEAST -> hard.
.np_rule_direction <- function(df) {
  a <- df$name_dir_x; b <- df$name_dir_y
  .np_both_present(a, b) & a != b
}

.np_rule_legal_form <- function(df) {
  a <- df$name_form_x; b <- df$name_form_y
  .np_both_present(a, b) & a != b
}

# Candidate name ends in a subordinate-affiliate token (FOUNDATION, ENDOWMENT,
# AUXILIARY, BOOSTERS) that the query name does not carry, on an otherwise strong
# name match -> soft. When only the affiliate arm is in the reference (its parent
# org absent) it gets matched to a query that named the parent; route to review
# instead of auto-accepting. If the query itself carries the token, no conflict.
.np_affiliate_tokens <- c("FOUNDATION", "ENDOWMENT", "AUXILIARY", "BOOSTERS", "BOOSTER")

.np_rule_affiliate_suffix <- function(df) {
  n <- nrow(df)
  nx <- df$name_x; ny <- df$name_y; nk <- df$name_key
  if (is.null(nx) || is.null(ny) || is.null(nk)) return(logical(n))
  norm <- function(x) trimws(gsub("\\s+", " ",
            gsub("[^A-Z0-9 ]", " ", toupper(ifelse(is.na(x), "", x)))))
  cy <- norm(ny)
  lastok <- sub("^.* ", "", cy)                       # last token of candidate
  cand <- which(lastok %in% .np_affiliate_tokens & grepl(" ", cy) &
                !is.na(nk) & nk >= 0.95)              # >=2 tokens, strong name match
  out <- logical(n)
  if (!length(cand)) return(out)
  qx <- norm(nx[cand]); lo <- lastok[cand]
  # query does NOT already contain that affiliate token as a whole word
  qhas <- mapply(function(l, x) grepl(paste0("(^| )", l, "( |$)"), x), lo, qx)
  out[cand] <- !qhas
  out
}

# Query-side legal-form / entity gate, folding the Tier-1 screen into the cascade.
# Operates on the RAW query name (name_raw_x) because normalization strips the
# legal suffix from name_key. A SAM registrant that is a for-profit or a unit of
# government should not resolve to a BMF nonprofit.
.np_gate_clean <- function(x)
  trimws(gsub("\\s+", " ", gsub("[^A-Z0-9 ]", " ", toupper(ifelse(is.na(x), "", x)))))

# For-profit legal form as the name ending (LLC / LP / LLP / PLLC / limited
# partnership) -> hard: these forms are not used by exempt organizations.
.np_rule_forprofit <- function(df) {
  x <- if (!is.null(df$name_raw_x)) df$name_raw_x else df$name_x
  if (is.null(x)) return(logical(nrow(df)))
  n <- .np_gate_clean(x)
  grepl(" (LLC|L L C|LP|L P|LLP|PLLC|LLLP)$| LIMITED PARTNERSHIP$", n)
}

# Unit of government (municipal corporation, special district, school district,
# housing/redevelopment authority, ...) -> soft: almost never a 501(c), but a few
# "... authority" entities operate as exempt (e.g. a hospital authority), so route
# to review rather than hard-rejecting.
.np_rule_government <- function(df) {
  x <- if (!is.null(df$name_raw_x)) df$name_raw_x else df$name_x
  if (is.null(x)) return(logical(nrow(df)))
  n <- .np_gate_clean(x)
  grepl(paste0(
    "(^| )(CITY|COUNTY|TOWN|VILLAGE|TOWNSHIP|BOROUGH) OF ",
    "|HOUSING AUTHORITY|REDEVELOPMENT AUTHORITY|SCHOOL DISTRICT",
    "|BOARD OF EDUCATION|PUBLIC LIBRARY|COUNCIL OF GOVERNMENTS|JOINT POWERS",
    "|(WATER|SEWER|SEWERAGE|SANITATION|SANITARY|IRRIGATION|RECLAMATION|FIRE",
    "|UTILITY|DRAINAGE|CONSERVANCY|IMPROVEMENT|METROPOLITAN) DISTRICT"), n)
}

#' Default veto rule set
#'
#' The do-not-match rules applied by [np_veto()]. Each is a predicate over the
#' candidate-pair frame with a `severity`:
#'
#' * **hard** forces the pair to NO regardless of similarity —
#'   `number_conflict` ("Local 32" vs "Local 45"), `ordinal_conflict`
#'   (FIRST vs SECOND), `direction_conflict` ("Southwest ..." vs "Southeast ..."),
#'   `forprofit_form` (query legal name ends in LLC/LP/LLP/PLLC — a for-profit
#'   form that no exempt org uses).
#' * **soft** blocks auto-YES (caps at MAYBE for review) but does not reject —
#'   `affiliate_suffix` (query "Rend Lake College" matched to "Rend Lake College
#'   Foundation": only the affiliate arm is in the reference, so send to review),
#'   `government_entity` (query is a municipality / special district / authority —
#'   almost never a 501(c), but a few "... authority" bodies file as exempt, so
#'   route to review). The last two fold the Tier-1 legal-form/entity screen into
#'   the cascade.
#'
#' `legal_form` (INC vs CORP vs LLC) ships **inactive**; add it with
#' `rbind(np_default_rules(), np_rule_legal_form())`.
#' A generation veto (JR vs SR) was removed: the abbreviated markers are rare and
#' the spelled-out / roman variants caused heavy false positives (see
#' [np_veto_audit()]).
#'
#' @return A data frame (class `np_rules`) with columns `id`, `description`,
#'   `severity`, and a list-column `test`.
#' @export
np_default_rules <- function() {
  rules <- rbind(
    np_rule("number_conflict",
            "Embedded numbers disjoint (chapter/local/district #)",
            .np_rule_number, severity = "hard"),
    np_rule("ordinal_conflict",
            "Ordinal markers disagree (FIRST vs SECOND ...)",
            .np_rule_ordinal, severity = "hard"),
    np_rule("direction_conflict",
            "Directional markers disagree (SOUTHWEST vs SOUTHEAST ...)",
            .np_rule_direction, severity = "hard"),
    np_rule("affiliate_suffix",
            "Candidate carries a subordinate-affiliate suffix the query lacks (FOUNDATION/ENDOWMENT/AUXILIARY/BOOSTERS)",
            .np_rule_affiliate_suffix, severity = "soft"),
    np_rule("forprofit_form",
            "Query legal name ends in a for-profit form (LLC/LP/LLP/PLLC)",
            .np_rule_forprofit, severity = "hard"),
    np_rule("government_entity",
            "Query is a unit of government (municipality / special district / authority)",
            .np_rule_government, severity = "soft")
  )
  structure(rules, class = c("np_rules", "data.frame"))
}

#' Build a veto rule
#'
#' @param id Short rule identifier (recorded in the veto reason).
#' @param description Human-readable description.
#' @param test A function of the pair-level data frame returning a logical
#'   vector, `TRUE` where the pair violates the rule.
#' @param severity `"hard"` (force NO) or `"soft"` (cap at MAYBE).
#' @return A one-row `np_rules` data frame.
#' @export
np_rule <- function(id, description, test, severity = c("hard", "soft")) {
  severity <- match.arg(severity)
  stopifnot(is.function(test))
  data.frame(id = id, description = description, severity = severity,
             test = I(list(test)), stringsAsFactors = FALSE)
}

#' The optional legal-form conflict rule
#' @rdname np_default_rules
#' @export
np_rule_legal_form <- function() {
  np_rule("legal_form_conflict",
          "Legal form disagrees (INC vs CORP vs LLC ...)",
          .np_rule_legal_form, severity = "hard")
}

#' Apply veto rules to candidate pairs
#'
#' Flags pairs that violate a do-not-match rule. Runs after scoring so it can
#' override a strong fuzzy match. Adds `veto` / `veto_reason` (hard) and
#' `veto_soft` / `veto_soft_reason` (soft).
#'
#' @param pairs An `np_pairs` frame (typically already scored).
#' @param config An [np_config()] whose `rules` are applied.
#' @return `pairs` with the four veto columns.
#' @export
np_veto <- function(pairs, config = np_config()) {
  rules <- config$rules
  if (is.null(rules$severity)) rules$severity <- "hard"
  n <- nrow(pairs)
  acc <- function(sev) {
    hitany <- logical(n); reason <- character(n)
    idx <- which(rules$severity == sev)
    for (i in idx) {
      hit <- tryCatch(as.logical(rules$test[[i]](pairs)), error = function(e) rep(FALSE, n))
      hit[is.na(hit)] <- FALSE
      hitany <- hitany | hit
      reason[hit] <- ifelse(nzchar(reason[hit]),
                            paste(reason[hit], rules$id[i], sep = ";"), rules$id[i])
    }
    list(flag = hitany, reason = ifelse(nzchar(reason), reason, NA_character_))
  }
  h <- acc("hard"); s <- acc("soft")
  pairs$veto <- h$flag;      pairs$veto_reason <- h$reason
  pairs$veto_soft <- s$flag; pairs$veto_soft_reason <- s$reason
  pairs
}
