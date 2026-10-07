# Field definitions for the candidate evaluation frame, keyed by the reviewer
# facing column names used in eval_frame_full.xlsx.
#
# Sourced from npmatch's own documentation rather than invented:
#   vignettes/candidate-evaluation-frame.qmd  - sections 1-4 (scores, names, geo)
#   R/final.R                                 - the final_* rollup fields
#   R/stage3.R + dev/RESEARCH-PROTOCOL.md     - the llm_* research fields
# Value domains were read off the data itself.

NP_DICT <- c(

## --- 1. Review header: what this row is and which group it belongs to -------
row_id =
  "Stable identifier for this row, as RID- plus a 12-character hash of uei, ein and total_score. Unique across the whole frame and identical in the per-state workbook and the full one, so you can cite a specific row - in a note, an email or a bug report - without pasting the line. It is derived from the data, not a sequence number: re-running the build regenerates the same id, but a row whose score changes gets a new one.",
num_of_candidates =
  "Number of candidate EINs surfaced for this UEI - i.e. the size of this review group, and the number of rows sharing this uei.",
final_outcome =
  "Whether the pipeline settled on an EIN for this UEI: MATCH or NO_MATCH. Constant across every row of the group.",
is_best_candidate =
  "1 on the candidate the STAGE-1 cascade selected, 0 on the alternatives, blank where the cascade surfaced nothing. NOT the shading key: it is 0 on the 9,072 answers stages 2 and 3 produced, and 1 on 7,918 stage-1 picks those stages later overrode. Compare against is_final_ein to find exactly those disagreements.",
uei =
  "SAM.gov Unique Entity Identifier - the source organization being matched. This is the grouping key: one UEI = one shaded band.",
ein =
  "IRS Employer Identification Number of the reference (BMF) organization proposed on this row.",
size_uss =
  "Size marker for the REGISTRANT: total federal award obligations received by this UEI, summed across contracts and assistance over FY2008-2026 from the USASpending annual archives. Constant across every row of a UEI's block, because it describes the source organization rather than the candidate. Note this is a LIFETIME total over 19 years, so it is not comparable in magnitude to size_bmf, which is a single year. Blank means unknown, NOT zero: the archive was filtered to the matched crosswalk, so unmatched registrants were never in scope. A matched registrant showing 0 genuinely drew no federal awards in the period.",
size_bmf =
  "Size marker for prioritising review: the IRS-reported annual revenue of THIS ROW's EIN, copied from bmf_revenue_amount and surfaced here so large organizations can be sorted to the top without scrolling. It is _bmf, not _uss, because it describes the IRS record - the SAM registration carries no revenue, receipts, assets or employee count, so no source-side size measure exists to use instead. Blank or 0 where the BMF reports no revenue (about a quarter of matched rows). On a candidate row that is NOT the match, it is that candidate's revenue, not the registrant's - so sort on the orange rows to rank matched organizations by size.",

## --- 2. The strings that were actually compared -----------------------------
match_name_uss =
  "The source-side name string that actually produced this match (may be the main name, a DBA, or a division name).",
match_name_bmf =
  "The BMF-side name string that actually produced this match.",
street_uss_normalized =
  "Source street address after standardization (the form used for comparison).",
street_bmf_normalized =
  "BMF street address after standardization (the form used for comparison).",
city_uss  = "City as supplied by the source (SAM.gov) record.",
city_bmf  = "City as recorded in the IRS BMF for this candidate.",
state_uss = "State as supplied by the source record. This field drives the per-state file split.",
state_bmf = "State as recorded in the IRS BMF for this candidate.",
zip5_uss  = "5-digit ZIP from the source record. Kept as text so leading zeros survive.",
zip5_bmf  = "5-digit ZIP from the BMF record. Kept as text so leading zeros survive.",

## --- 3. Match strength ------------------------------------------------------
candidate_type =
  "Which selection rule(s) surfaced this candidate, joined by '+': top1/top2/top3 = rank by total_score; best_name = highest name similarity; best_addr = highest address similarity. A candidate can satisfy several at once.",
final_basis =
  "What decided the final answer for this UEI: algorithm (auto-accepted by score), llm_review (stage 2 adjudication), llm_research (stage 3 web research), entity_screen (settled by the entity gate without a lookup).",
final_confidence =
  "Confidence attached to the final answer: high / medium / low.",
name_similarity =
  "Name agreement, 0-1. Jaro-Winkler similarity (prefix factor p = 0.1); values below the 0.85 threshold are floored to 0 so unrelated strings contribute nothing.",
addr_similarity =
  "Address agreement, 0-1, at the best available granularity.",
total_score =
  "Combined match score, 0-1: 0.6 * name_similarity + 0.4 * geographic agreement.",

## --- 4. Outcome of the automated decision -----------------------------------
match_stage =
  "Which pipeline stage produced the final answer: 1 = automated cascade, 2 = LLM adjudication, 3 = LLM web research. (Stored as final_stage in the CSV.)",
match_reason =
  "Short reason recorded with the final answer. (Stored as final_reason in the CSV.)",

## --- 5. Stage-3 LLM research (llm_* = s3_* in the CSV) ----------------------
llm_determination =
  "Stage-3 research verdict: match (a specific EIN is the same org); nonprofit_not_in_bmf (real nonprofit legitimately absent from the active BMF - church, foreign, state-only, or inactive); not_a_nonprofit (for-profit, individual, or government unit); cant_determine (insufficient evidence after all tiers).",
llm_judgement =
  "The researcher's reasoning for that determination.",
llm_confidence =
  "Confidence in the stage-3 determination: high / medium / low.",
llm_sources_consulted =
  "How many sources were consulted before deciding.",
llm_sources =
  "Which sources produced the determination (local BMF, 990 e-file index, ProPublica, web).",
llm_notes =
  "Free-text research notes - usually the single most useful field when auditing a stage-3 call.",
llm_ein_found =
  "The EIN stage-3 research turned up, when it found one. May be an EIN the matcher never surfaced.",
llm_resolving_tier =
  "Which research tier settled it: tier1 (local BMF / 990 e-file index, ~free), tier2 (cached ProPublica), tier3 (general web search).",
llm_web_urls    = "URLs consulted during tier-3 web research.",
llm_web_domains = "Domains of those URLs, for provenance at a glance.",

## --- 6. IRS BMF context for the candidate EIN (carried verbatim) ------------
bmf_subsection_code =
  "IRS subsection code - 3 = 501(c)(3), 4 = 501(c)(4), 6 = 501(c)(6), and so on.",
bmf_exempt_org_type             = "Plain-language exempt organization type for that subsection.",
bmf_foundation_code             = "IRS foundation classification code.",
bmf_foundation_definition       = "Plain-language reading of the foundation code.",
bmf_ntee_code                   = "NTEE code (activity classification) as recorded in the BMF.",
bmf_ntee_definition             = "Plain-language reading of the NTEE code.",
bmf_ntee_major_group            = "NTEE major group (the single-letter tier, A-Z).",
bmf_nteev2                      = "NTEE v2 code (the revised NCCS classification).",
bmf_nteev2_subsector            = "NTEE v2 subsector.",
bmf_nteev2_subsector_definition = "Plain-language reading of the NTEE v2 subsector.",
bmf_nteev2_org_type             = "Organization type under NTEE v2.",
bmf_revenue_amount              = "Revenue reported in the BMF financial extract.",
bmf_income_amount               = "Income reported in the BMF financial extract.",
bmf_asset_amount                = "Assets reported in the BMF financial extract.",
bmf_financials_tax_period       = "Tax period those financial figures describe.",
bmf_ruling_date                 = "IRS ruling date (YYYYMM) granting exempt status.",
bmf_last_year_in_bmf            = "Last year this EIN appears in the BMF - the inactivity marker.",
bmf_ruling_year                 = "Year component of the ruling date.",

## --- 7. How the case was routed into stage 3 --------------------------------
llm_federated_parent =
  "TRUE when the EIN found is a shared federated/parent EIN (8 or more source orgs resolved to it) - e.g. a Salvation Army territorial EIN. Treat a TRUE here with care: the local chapter may not file separately.",
llm_path =
  "Route the case took through stage 3.",
llm_entity_gate =
  "Entity screen applied before any lookup: nonprofit_candidate, foreign, church, government, individual, for_profit_form, not_tax_exempt_corp, tribal_government. The gate settles some cases deterministically.",
llm_queue_reason =
  "Why the case was queued for research despite the gate - e.g. sam_2L_flag_unreliable, church_may_or_may_not_be_in_bmf, bmf_name_hit_contradicts_screen, efile_990_filer_shares_this_website.",

## --- 8. Run provenance ------------------------------------------------------
run_id =
  "Which matching run produced this row (2025NOV or 2026MAY). The two runs share no UEIs.",

## --- 9. Name-match detail ---------------------------------------------------
match_version_uss =
  "Which source name version matched: MAIN, DBA, DIVISION, TOKEN_OVERLAP, or none.",
match_version_bmf =
  "Which BMF name version matched: MAIN, DBA, DIVISION, TOKEN_OVERLAP, or none.",
match_type =
  "How the names were matched: exact, name (fuzzy), dba, or token_overlap.",
match_decision =
  "Tier assigned by the cascade: YES (auto-accept), MAYBE (send to review), NO (reject).",
match_layer =
  "Which cascade pass surfaced this candidate: exact-name, exact-name-dba, exact-dba-name, exact-dba-dba, token-state, token-crossstate, token-concat.",
decision_reason =
  "Human-readable justification for the tier, including the score and the threshold it was compared against.",
veto =
  "TRUE when a hard do-not-match rule fired, forcing NO (e.g. a for-profit legal form).",
veto_reason      = "Which hard rule fired.",
veto_soft =
  "TRUE when a soft rule fired, capping the candidate at MAYBE (e.g. an affiliate suffix or a government entity).",
veto_soft_reason = "Which soft rule fired.",
notes            = "Free-text annotations carried through the pipeline.",
normalized_match_count =
  "How many reference records share this exact normalized name - a distinctiveness measure. A high count means the name alone cannot identify the organization.",

## --- 10. Name cleaning progression, raw -> normalized -> tokenized ----------
name_uss_raw_main     = "Source: original legal name as supplied.",
name_uss_raw_dba      = "Source: original DBA / alternate name, if any.",
name_uss_raw_division = "Source: original division / second alternate name, if any.",
name_uss_normalized   = "Source: cleaned match key - suffixes, 'The' and punctuation removed, abbreviations standardized.",
name_uss_org_type     = "Source: the organization-type words that were stripped (Foundation, Inc, Association ...).",
name_uss_tokenized    = "Source: informative tokens with IDF weights, rarest first, as TOKEN(idf). Shows which words carry the match.",
name_bmf_raw_main     = "BMF: original legal name as recorded.",
name_bmf_raw_dba      = "BMF: original DBA / alternate name, if any.",
name_bmf_raw_division = "BMF: original division / second alternate name, if any.",
name_bmf_normalized   = "BMF: cleaned match key, same normalization as the source side.",
name_bmf_org_type     = "BMF: the organization-type words that were stripped.",
name_bmf_tokenized    = "BMF: informative tokens with IDF weights, rarest first, as TOKEN(idf).",

## --- 11. Address & geography detail -----------------------------------------
street_similarity = "Field-level street agreement, 0-1.",
city_similarity   = "Field-level city agreement, 0-1.",
zip_similarity    = "Field-level ZIP agreement, 0-1.",
street_uss        = "Raw source street address, before normalization.",
street_bmf        = "Raw BMF street address, before normalization.",
geo_stnum = "1/0 flag: the street numbers agree exactly.",
geo_zip9  = "1/0 flag: the 9-digit ZIPs agree exactly.",
geo_zip5  = "1/0 flag: the 5-digit ZIPs agree exactly.",
geo_zip3  = "1/0 flag: the 3-digit ZIP prefixes agree (same rough area).",
geo_state = "1/0 flag: the states agree.",
geo_pobox = "1/0 flag: the address is a PO box, where street comparison means little.",

## --- 12. Name-distinctiveness features (model inputs) ----------------------
name_idf          = "Summed IDF weight of the matching tokens - how much rare-word evidence supports this match.",
name_gen_uss      = "Generic (high-frequency) tokens in the source name.",
name_gen_bmf      = "Generic (high-frequency) tokens in the BMF name.",
name_gen_rank_uss = "Rank of the source name's most generic token.",
name_gen_rank_bmf = "Rank of the BMF name's most generic token.",
name_nums_uss     = "Numbers appearing in the source name (chapter or post numbers separate otherwise identical orgs).",
name_nums_bmf     = "Numbers appearing in the BMF name.",
name_ord_uss      = "Ordinals in the source name (First, Second ...).",
name_ord_bmf      = "Ordinals in the BMF name.",
name_dir_uss      = "Directionals in the source name (North, Southeast ...).",
name_dir_bmf      = "Directionals in the BMF name.",

## --- 13. Reference record flags ---------------------------------------------
bmf_active =
  "TRUE when this EIN is in the ACTIVE BMF; FALSE when it is known only from the inactive/historical file.",
pass =
  "The blocking pass that generated this candidate pair (same vocabulary as match_layer).",

## --- 14. The final answer for this UEI --------------------------------------
final_ein =
  "The EIN the pipeline settled on for this UEI, whatever stage produced it. Constant across the group.",
candidate_source =
  "Where this row came from: cascade (the matcher surfaced it) or stage3_research (a synthetic row carrying an EIN the matcher never surfaced - similarity columns are empty by design).",
is_final_ein =
  "1 when this row carries THE MATCH for the UEI, whichever stage produced it. This is the orange shading key: exactly one such row per matched UEI, none for an unmatched one. Compare against is_best_candidate to spot where stage 2 or 3 overrode the matcher.",
final_ein_in_candset =
  "1 when the final EIN was somewhere in the candidate set, 0 when it was not. This splits recall loss: 0 is a BLOCKING failure (no threshold change recovers it), 1 with a low score is a SCORING failure (recoverable by recalibration).",
final_ein_bmf_status     = "BMF status of the final EIN: ACTIVE or INACTIVE.",
final_ein_bmf_subsection = "501(c) subsection of the final EIN.",
final_ein_efile_501c3    = "X when the final EIN appears as a 501(c)(3) in the 990 e-file index.",
final_ein_efile_last_tax_year = "Most recent tax year the final EIN e-filed a 990/990-EZ.",
llm_ein_bmf_status       = "BMF status of the EIN stage-3 research found.",
llm_ein_bmf_subsection   = "501(c) subsection of the EIN stage-3 research found.",
final_ein_status_basis =
  "One-line plain-language summary of the evidence behind the final EIN - e.g. 'IRS BMF ACTIVE, 501(c)(3); 990 filer through 2023'."
)

# Section labels, assigned by position in the reviewer-facing column order.
NP_SECTIONS <- list(
  "1. Review header"              = 1:5,
  "2. Compared strings"           = 6:15,
  "3. Match strength"             = 16:21,
  "4. Automated decision"         = 22:23,
  "5. Stage-3 LLM research"       = 24:33,
  "6. IRS BMF context"            = 34:51,
  "7. Stage-3 routing"            = 52:55,
  "8. Run provenance"             = 56,
  "9. Name-match detail"          = 57:68,
  "10. Name cleaning"             = 69:80,
  "11. Address & geography"       = 81:91,
  "12. Name distinctiveness"      = 92:102,
  "13. Reference flags"           = 103:104,
  "14. The final answer"          = 105:115
)
