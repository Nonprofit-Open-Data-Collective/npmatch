# A rule tests the pair-level frame and returns TRUE where the pair violates a
# do-not-match constraint. Both-sided features are `_x` / `_y`. Rules carry a
# severity: "hard" forces NO; "soft" blocks auto-YES (caps the pair at MAYBE and
# sends it to refinement) but does not by itself reject the pair.

.np_present <- function(a) !is.na(a) & nzchar(a)
.np_both_present <- function(a, b) .np_present(a) & .np_present(b)

# VESTIGIAL -- do not wire these in, and do not cite them as examples of what
# the veto layer does. Jr vs Sr separates two *people*; nothing about it
# separates two organisations. They came over from npmatch's SAM / USASpending
# person-matching lineage on a misreading of the veto layer's purpose. The
# organisation-level equivalents are the rules that actually ship below:
# ordinal_conflict (First vs Second Presbyterian), direction_conflict (regional),
# number_conflict (chapter/local), affiliate_suffix and forprofit_form (legal
# form / affiliation). Kept only until name_gen can be dropped from the pair
# features without breaking existing labeled extracts. See ?np_default_rules.
.np_rule_generation <- function(df) {
  a <- df$name_gen_rank_x; b <- df$name_gen_rank_y
  .np_both_present(a, b) & a != b
}

# also vestigial: one side carries the marker, the other none.
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
  # municipal "City/County of X" only when it *leads* the name -- a real
  # municipality is named "City of Springfield ...", whereas "... University in
  # the City of New York" just carries the phrase, and is not government.
  grepl(paste0(
    "^(THE )?(CITY|COUNTY|TOWN|VILLAGE|TOWNSHIP|BOROUGH) OF ",
    "|HOUSING AUTHORITY|REDEVELOPMENT AUTHORITY|SCHOOL DISTRICT",
    "|BOARD OF EDUCATION|PUBLIC LIBRARY|COUNCIL OF GOVERNMENTS|JOINT POWERS",
    "|(WATER|SEWER|SEWERAGE|SANITATION|SANITARY|IRRIGATION|RECLAMATION|FIRE",
    "|UTILITY|DRAINAGE|CONSERVANCY|IMPROVEMENT|METROPOLITAN) DISTRICT"), n)
}

#' Default veto rule set
#'
#' The do-not-match rules applied by [np_veto()]. A rule is a predicate over the
#' candidate-pair frame — both-sided features are suffixed `_x` (query) and `_y`
#' (reference) — plus a `severity` that decides what a hit costs the pair.
#'
#' The layer exists because fuzzy string similarity is at its worst exactly
#' where organization names differ by one short, decisive token. "First
#' Presbyterian Church" and "Second Presbyterian Church" are ~95% similar as
#' strings and are two different congregations; so are "Southwest Community
#' Center" and "Southeast Community Center", "UAW Local 32" and "UAW Local 45",
#' and an organization versus its fundraising foundation. No amount of scorer
#' tuning separates those — the one differing token is drowned out by the
#' agreeing ones. The rules below encode the token as a constraint on identity
#' instead, and are applied *after* scoring so they can override a strong match.
#'
#' @section Severities:
#' * **hard** — the pair is impossible, whatever the similarity. [np_veto()]
#'   sets `veto` / `veto_reason`, and [np_select()] drops the pair before
#'   choosing a best candidate, so that reference record is out of contention
#'   for the query. (Pass `include_vetoed = TRUE` to keep it and inspect why.)
#' * **soft** — the pair is plausible but wants a human. [np_veto()] sets
#'   `veto_soft` / `veto_soft_reason`, the pair stays eligible, and if it *is*
#'   the selected match [np_tier()] caps it at MAYBE instead of auto-accepting.
#'   A soft veto never turns a MAYBE into a NO, and one on a pair that was not
#'   selected has no effect.
#'
#' Both flags are accumulated independently and `;`-separated when several rules
#' of the same severity fire, so `veto_reason` is the full list of hard hits,
#' not just the first.
#'
#' @section The shipped rules:
#' \describe{
#'   \item{`number_conflict` (hard)}{Both names carry embedded digit tokens and
#'     the two sets are disjoint — "Local 32" vs "Local 45", VFW Post 1234 vs
#'     Post 5678. Chapter/local/post/district numbers are identifiers, so a
#'     disjoint pair is a different unit of the same parent, not a typo.}
#'   \item{`ordinal_conflict` (hard)}{Ordinal markers present on both sides and
#'     disagreeing — "First Baptist" vs "Second Baptist". Matched on canonical
#'     rank, so FIRST and 1ST are the same marker.}
#'   \item{`direction_conflict` (hard)}{Directional markers present on both
#'     sides and disagreeing — "Southwest Community Center" vs "Southeast
#'     Community Center". Word forms only; bare N/S/E/W are usually initials or
#'     street directionals and are not extracted.}
#'   \item{`forprofit_form` (hard)}{The **query's raw** legal name ends in a
#'     for-profit form — LLC, LP, LLP, PLLC, LLLP, "limited partnership". These
#'     forms are not used by exempt organizations, so the query is not the BMF
#'     record it resembles. Reads `name_raw_x` because normalization strips the
#'     legal suffix out of `name_key`.}
#'   \item{`affiliate_suffix` (soft)}{The candidate's last token is a
#'     subordinate-affiliate word — FOUNDATION, ENDOWMENT, AUXILIARY, BOOSTERS,
#'     BOOSTER — that the query name does not carry, on an otherwise strong name
#'     match (`name_key >= 0.95`). Query "Rend Lake College" matched to "Rend
#'     Lake College Foundation": the parent is absent from the reference and its
#'     fundraising arm absorbed the match. Often the right EIN in practice, so
#'     it is routed to review rather than rejected. If the query itself carries
#'     the token there is no conflict and the rule does not fire.}
#'   \item{`government_entity` (soft)}{The query's raw name matches a unit-of-
#'     government pattern: a leading "City/County/Town/Village/Township/Borough
#'     of ...", or a housing/redevelopment authority, school district, board of
#'     education, public library, council of governments, joint powers agency,
#'     or a water/sewer/fire/utility/conservancy-type special district. Almost
#'     never a 501(c) — but a few authorities (hospital authorities in
#'     particular) do file as exempt, so this is soft. The leading-anchor on the
#'     municipal pattern matters: "Columbia University in the City of New York"
#'     carries the phrase without being a municipality.}
#' }
#'
#' `forprofit_form` and `government_entity` fold what was a separate Tier-1
#' legal-form / entity screen into the cascade, so the decision is recorded on
#' the pair with a reason instead of silently removing the query up front.
#'
#' @section The optional rule:
#' `legal_form_conflict` (INC vs CORP vs LLC) is exported as
#' [np_rule_legal_form()] and ships **inactive** — the same organization is
#' routinely written both ways across sources, so enabling it costs recall.
#' Add it with `rbind(np_default_rules(), np_rule_legal_form())`.
#'
#' @section The generation predicates are vestigial:
#' `.np_rule_generation()` and `.np_rule_generation_asym()` are internal, unwired,
#' and **not useful for this package**. They test person-name generational
#' suffixes — Jr vs Sr — which distinguish two *people*, not two organizations.
#' They are an artifact of npmatch's SAM / USASpending person-matching lineage,
#' carried over on a misreading of what the veto layer is for, and they are the
#' wrong thing to reach for when explaining it.
#'
#' The organization-level equivalents are the rules that actually ship:
#' `ordinal_conflict` is the real "First Presbyterian vs Second Presbyterian"
#' case, `direction_conflict` the regional one, `number_conflict` the
#' chapter/local one, and `affiliate_suffix` / `forprofit_form` the
#' legal-form-and-affiliation one. Cite those.
#'
#' `np_normalize()` still emits `name_gen` / `name_gen_rank` (JR/SR only) and
#' [np_compare()] still carries them through as pair features, so they appear in
#' the training frames and data dictionaries. Nothing consumes them, and they are
#' retained only so existing labeled extracts keep their column layout.
#'
#'
#' @return A data frame (class `np_rules`) with columns `id`, `description`,
#'   `severity`, and a list-column `test`.
#' @seealso [np_veto()] to apply a rule set, [np_rule()] to write one,
#'   [np_veto_audit()] to check a rule's hits against labels, and [np_tier()]
#'   for how severity translates into a tier.
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
#' Flags pairs that violate a do-not-match rule. Runs *after* scoring, so a rule
#' can override a strong fuzzy match: the rules encode facts about identity that
#' string similarity cannot see (a chapter number, a for-profit legal form),
#' rather than adjusting the score. Every rule in `config$rules` is evaluated on
#' every pair — there is no short-circuit — and the hits are accumulated by
#' severity into four new columns:
#'
#' * `veto` (logical) / `veto_reason` (character) — any **hard** rule fired.
#' * `veto_soft` / `veto_soft_reason` — any **soft** rule fired.
#'
#' The two are independent: a pair can carry both. When several rules of the
#' same severity fire, their ids are joined with `;` in the reason column;
#' `NA` means no rule of that severity fired. A rule that errors is caught and
#' treated as no-hit for every row, so a malformed custom rule degrades rather
#' than aborting the run. Rules with a missing `severity` are treated as hard.
#'
#' What each severity costs the pair happens downstream, not here — [np_select()]
#' drops hard-vetoed pairs from candidate selection, and [np_tier()] caps a
#' soft-vetoed selected pair at MAYBE. See [np_default_rules()] for the shipped
#' rules and the reasoning behind each.
#'
#' @param pairs An `np_pairs` frame (typically already scored).
#' @param config An [np_config()] whose `rules` are applied. Defaults to
#'   [np_default_rules()]; supply your own with
#'   `np_config(rules = rbind(np_default_rules(), np_rule(...)))`.
#' @return `pairs` with the four veto columns.
#' @seealso [np_default_rules()], [np_rule()], [np_veto_audit()].
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
