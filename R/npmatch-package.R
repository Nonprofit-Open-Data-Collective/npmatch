#' npmatch: a tiered workflow for organization record linkage
#'
#' npmatch manages the steps of matching organization records to a reference
#' database when no shared identifier exists. The steps are generic; the
#' nonprofit case the package ships wired for — federal registrants (SAM) to
#' the IRS Business Master File — is one deployment of the framework, not a
#' requirement of it.
#'
#' Six tiers, each a separable concern:
#'
#' \enumerate{
#'   \item \strong{Alias enumeration} — every name and address an entity is
#'     known by. Supplied by \pkg{matchdb}: pass the object its
#'     \code{md_compile()} or \code{md_reference()} returns straight to
#'     [np_cascade()] as \code{reference}.
#'   \item \strong{Input standardization} — [np_query()] / [np_reference()] map
#'     any dataset onto the canonical fields, then [np_normalize()] (from
#'     \pkg{npnormalize}, re-exported here) builds the name and address keys.
#'   \item \strong{Data pre-prep} — the corpus statistics that make a token or
#'     an address informative: [np_ref_index()], [np_token_idf()],
#'     [np_name_freq()], [np_addr_freq()]. Computed once over the whole
#'     reference, or taken precomputed from a matchdb reference.
#'   \item \strong{Candidate generation} — [np_block()] / [np_block_union()]
#'     keep the pair set tractable; [np_compare()] scores each field, over
#'     \pkg{reclin2}.
#'   \item \strong{Tiered adjudication} — [np_score()] combines the fields,
#'     [np_veto()] applies hard and soft do-not-match rules, [np_select()]
#'     picks the best candidate per query, [np_tier()] sorts into
#'     YES / MAYBE / NO.
#'   \item \strong{Packaging for review} — [np_route()] emits the accepted
#'     crosswalk, the candidate-level review queue and the unmatched set;
#'     [np_label_frame()] emits training data and [np_as_prompt()] LLM prompts.
#' }
#'
#' [np_cascade()] runs tiers 2–5 as progressive blocking passes (the scalable
#' path) and [np_match()] in a single pass; [np_route()] then does tier 6 on the
#' result. [np_run_batches()] chunks a large source over [np_cascade()] and
#' routes each chunk, and the stage drivers ([np_stage1_run()] and its siblings)
#' wrap the whole thing in an on-disk run project.
#'
#' @keywords internal
"_PACKAGE"
