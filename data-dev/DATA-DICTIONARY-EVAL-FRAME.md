# Evaluation dataframe — data dictionary

`EVAL-FRAME-1502-MERGED.csv` — one row per **candidate pair** (source org x BMF candidate); 2763 rows, 150 columns.
Group a source org's rows by `uei`; `is_top_candidate=1` marks the algorithm's pick, `is_gt_ein=1` marks the true match.

## identity

| column | description |
|---|---|
| `uei` | Source (SAM/USASpending) Unique Entity ID — the query key. |
| `ein` | Candidate IRS Employer Identification Number from the BMF (one row per candidate). |

## decision

| column | description |
|---|---|
| `addr_similarity` | Composite geographic-agreement score for this pair (0-1). |
| `candidate_type` | How this candidate was surfaced (e.g. best_addr+best_name+top1). |
| `total_score` | Final blended match score = 0.6*name + 0.4*geo, after vetoes. |
| `num_of_candidates` | Number of candidate rows surfaced for this source org (review group size). |
| `is_top_candidate` | 1 on the selected pick for a YES/MAYBE decision; blank otherwise. |
| `match_decision` | Algorithm tier for the source org: YES / MAYBE / NO. |
| `match_layer` | Blocking pass that produced the chosen match (exact-name, token-state, ...). |
| `decision_reason` | Why this tier/decision was reached (margin, veto, threshold). |
| `notes` | Free-text reviewer notes (blank by default). |
| `state_uss` | Source state. |
| `state_bmf` | BMF state. |
| `bmf_active` | TRUE if the matched BMF org is in the ACTIVE file; FALSE if inactive (unified reference). |
| `pass` | Cascade pass that generated this candidate pair. |

## veto

| column | description |
|---|---|
| `veto` | TRUE if a hard do-not-match rule fired (forces NO). |
| `veto_reason` | Which hard rule fired. |
| `veto_soft` | TRUE if a soft rule fired (caps the pair at MAYBE). |
| `veto_soft_reason` | Which soft rule fired. |

## name

| column | description |
|---|---|
| `name_similarity` | Jaro-Winkler similarity of the best source vs BMF name variant (0-1). |
| `match_name_uss` | The source name variant that matched (main/DBA/division). |
| `match_version_uss` | Which source name field won: MAIN / DBA / DIVISION / TOKEN_OVERLAP. |
| `match_name_bmf` | The BMF name variant that matched. |
| `match_version_bmf` | Which BMF name field won: MAIN / DBA / TOKEN_OVERLAP. |
| `match_type` | How the names matched: exact / dba / name / token_overlap. |
| `normalized_match_count` | How many BMF orgs share this normalized name (name distinctiveness; 1 = unique). |
| `name_uss_raw_main` | Raw source legal name. |
| `name_uss_raw_dba` | Raw source DBA name. |
| `name_uss_raw_division` | Raw source division name. |
| `name_uss_normalized` | Normalized source name key used for matching. |
| `name_uss_org_type` | Legal-form token extracted from the source name (INC, LLC, ...). |
| `name_uss_tokenized` | Source name tokens annotated with reference IDF (rarest first). |
| `name_bmf_raw_main` | Raw BMF legal name. |
| `name_bmf_raw_dba` | Raw BMF DBA/sort name. |
| `name_bmf_raw_division` | Raw BMF division name. |
| `name_bmf_normalized` | Normalized BMF name key. |
| `name_bmf_org_type` | Legal-form token extracted from the BMF name. |
| `name_bmf_tokenized` | BMF name tokens annotated with IDF. |
| `name_gen_uss` | Generational marker in source name (JR or SR). **VESTIGIAL** -- a person-name concept inherited from the SAM/USASpending lineage. Organisations do not have generations; no veto rule uses it. Do not model on it. |
| `name_gen_bmf` | Generational marker in BMF name. VESTIGIAL; see `name_gen_uss`. |
| `name_gen_rank_uss` | Numeric rank of source generation (SR=1, JR=2). VESTIGIAL; see `name_gen_uss`. |
| `name_gen_rank_bmf` | Numeric rank of BMF generation. VESTIGIAL; see `name_gen_uss`. |
| `name_nums_uss` | Numbers embedded in source name. |
| `name_nums_bmf` | Numbers embedded in BMF name. |
| `name_ord_uss` | Ordinals in source name (FIRST/SECOND). |
| `name_ord_bmf` | Ordinals in BMF name. |
| `name_dir_uss` | Direction words in source name (NORTH/EAST). |
| `name_dir_bmf` | Direction words in BMF name. |

## address

| column | description |
|---|---|
| `street_similarity` | Street-level agreement (0-1). |
| `city_similarity` | City agreement (0-1). |
| `zip_similarity` | ZIP agreement (0-1). |
| `street_uss` | Source street address. |
| `street_bmf` | BMF street address. |
| `city_uss` | Source city. |
| `city_bmf` | BMF city. |
| `zip5_uss` | Source 5-digit ZIP. |
| `zip5_bmf` | BMF 5-digit ZIP. |
| `street_uss_normalized` | Normalized source street key. |
| `street_bmf_normalized` | Normalized BMF street key. |
| `geo_stnum` | 1 if street number + name agree (tightest geo). |
| `geo_zip9` | 1 if ZIP+4 agrees. |
| `geo_zip5` | 1 if 5-digit ZIP agrees. |
| `geo_zip3` | 1 if 3-digit ZIP prefix agrees. |
| `geo_state` | 1 if state agrees. |
| `geo_pobox` | 1 if PO boxes agree. |

## bmf_context

| column | description |
|---|---|
| `BMF_ntee_clean` | Cleaned NTEE code. |
| `BMF_nteev2` | NTEEv2 classification. |
| `BMF_subsection` | 501(c) subsection (3 = 501(c)(3)). |
| `BMF_is_foundation` | TRUE for private foundations. |
| `BMF_rule_year` | Year of IRS exemption ruling. |
| `BMF_ruling_ym` | Ruling year-month. |
| `BMF_accounting_period` | Accounting period (month). |
| `BMF_assets` | Reported assets. |
| `BMF_revenue` | Reported revenue. |
| `BMF_form_990` | Filing requirement (990/990EZ/990N/990PF/none/group). |
| `BMF_filing_requirement` | Filing requirement definition. |
| `BMF_pf_filing_requirement` | Private-foundation filing requirement. |
| `BMF_affiliation_code` | Affiliation code (central/subordinate). |
| `BMF_affiliation` | Affiliation definition. |
| `BMF_group_exemption_number` | Group exemption number. |
| `BMF_group_exemption_is_member` | TRUE if a group-ruling member. |
| `BMF_in_care_of` | BMF in-care-of name. |

## sam_context

| column | description |
|---|---|
| `SAM_entity_start_date` | SAM entity start date. |
| `SAM_fiscal_year_end` | SAM fiscal year end. |
| `SAM_entity_url` | SAM entity URL. |
| `SAM_entity_structure` | SAM entity structure code. |
| `SAM_entity_structure_label` | SAM entity structure label (e.g. Corporate Entity (Tax Exempt)). |
| `SAM_primary_naics` | SAM primary NAICS code. |
| `SAM_poc_first_name` | SAM point-of-contact first name. |
| `SAM_poc_middle_initial` | SAM POC middle initial. |
| `SAM_poc_last_name` | SAM POC last name. |
| `SAM_poc_title` | SAM POC title. |

## sam_business_type

| column | description |
|---|---|
| `SAM_bus_type_minority_owned` | SAM self-reported business-type flag: minority owned (TRUE/FALSE). |
| `SAM_bus_type_nonprofit` | SAM self-reported business-type flag: nonprofit (TRUE/FALSE). |
| `SAM_bus_type_community_development_corp` | SAM self-reported business-type flag: community development corp (TRUE/FALSE). |
| `SAM_bus_type_hispanic_american_owned` | SAM self-reported business-type flag: hispanic american owned (TRUE/FALSE). |
| `SAM_bus_type_foundation` | SAM self-reported business-type flag: foundation (TRUE/FALSE). |
| `SAM_bus_type_educational_institution` | SAM self-reported business-type flag: educational institution (TRUE/FALSE). |
| `SAM_bus_type_state_controlled_higher_ed` | SAM self-reported business-type flag: state controlled higher ed (TRUE/FALSE). |
| `SAM_bus_type_black_american_owned` | SAM self-reported business-type flag: black american owned (TRUE/FALSE). |
| `SAM_bus_type_other_not_for_profit` | SAM self-reported business-type flag: other not for profit (TRUE/FALSE). |
| `SAM_bus_type_woman_owned` | SAM self-reported business-type flag: woman owned (TRUE/FALSE). |
| `SAM_bus_type_hospital` | SAM self-reported business-type flag: hospital (TRUE/FALSE). |
| `SAM_bus_type_domestic_shelter` | SAM self-reported business-type flag: domestic shelter (TRUE/FALSE). |
| `SAM_bus_type_llc` | SAM self-reported business-type flag: llc (TRUE/FALSE). |
| `SAM_bus_type_native_american_owned` | SAM self-reported business-type flag: native american owned (TRUE/FALSE). |
| `SAM_bus_type_american_indian_owned` | SAM self-reported business-type flag: american indian owned (TRUE/FALSE). |
| `SAM_bus_type_veteran_owned` | SAM self-reported business-type flag: veteran owned (TRUE/FALSE). |
| `SAM_bus_type_other` | SAM self-reported business-type flag: other (TRUE/FALSE). |
| `SAM_bus_type_abilityone_nonprofit` | SAM self-reported business-type flag: abilityone nonprofit (TRUE/FALSE). |
| `SAM_bus_type_sba_hubzone_joint_venture` | SAM self-reported business-type flag: sba hubzone joint venture (TRUE/FALSE). |
| `SAM_bus_type_private_university_or_college` | SAM self-reported business-type flag: private university or college (TRUE/FALSE). |
| `SAM_bus_type_dot_certified_dbe` | SAM self-reported business-type flag: dot certified dbe (TRUE/FALSE). |
| `SAM_bus_type_us_local_government` | SAM self-reported business-type flag: us local government (TRUE/FALSE). |
| `SAM_bus_type_city` | SAM self-reported business-type flag: city (TRUE/FALSE). |
| `SAM_bus_type_service_disabled_veteran_owned` | SAM self-reported business-type flag: service disabled veteran owned (TRUE/FALSE). |
| `SAM_bus_type_manufacturer` | SAM self-reported business-type flag: manufacturer (TRUE/FALSE). |
| `SAM_bus_type_subchapter_s_corp` | SAM self-reported business-type flag: subchapter s corp (TRUE/FALSE). |
| `SAM_bus_type_foreign_owned` | SAM self-reported business-type flag: foreign owned (TRUE/FALSE). |
| `SAM_bus_type_cdc_owned_firm` | SAM self-reported business-type flag: cdc owned firm (TRUE/FALSE). |
| `SAM_bus_type_joint_venture` | SAM self-reported business-type flag: joint venture (TRUE/FALSE). |
| `SAM_bus_type_asian_pacific_american_owned` | SAM self-reported business-type flag: asian pacific american owned (TRUE/FALSE). |
| `SAM_bus_type_minority_institution` | SAM self-reported business-type flag: minority institution (TRUE/FALSE). |
| `SAM_bus_type_native_hawaiian_org_owned` | SAM self-reported business-type flag: native hawaiian org owned (TRUE/FALSE). |
| `SAM_bus_type_hispanic_serving_institution` | SAM self-reported business-type flag: hispanic serving institution (TRUE/FALSE). |
| `SAM_bus_type_subcontinent_asian_american_owned` | SAM self-reported business-type flag: subcontinent asian american owned (TRUE/FALSE). |
| `SAM_bus_type_alaskan_native_corp_owned` | SAM self-reported business-type flag: alaskan native corp owned (TRUE/FALSE). |
| `SAM_bus_type_indian_tribe_federally_recognized` | SAM self-reported business-type flag: indian tribe federally recognized (TRUE/FALSE). |
| `SAM_bus_type_us_state_government` | SAM self-reported business-type flag: us state government (TRUE/FALSE). |
| `SAM_bus_type_small_agricultural_cooperative` | SAM self-reported business-type flag: small agricultural cooperative (TRUE/FALSE). |
| `SAM_bus_type_hbcu` | SAM self-reported business-type flag: hbcu (TRUE/FALSE). |
| `SAM_bus_type_municipality` | SAM self-reported business-type flag: municipality (TRUE/FALSE). |
| `SAM_bus_type_self_certified_hubzone_jv` | SAM self-reported business-type flag: self certified hubzone jv (TRUE/FALSE). |
| `SAM_bus_type_self_certified_small_disadvantaged` | SAM self-reported business-type flag: self certified small disadvantaged (TRUE/FALSE). |
| `SAM_bus_type_for_profit` | SAM self-reported business-type flag: for profit (TRUE/FALSE). |
| `SAM_bus_type_land_grant_1862` | SAM self-reported business-type flag: land grant 1862 (TRUE/FALSE). |

## ground_truth

| column | description |
|---|---|
| `sample_type` | Stratum: 'random' (1,000 representative) or 'hard' (502 oversampled difficult cases). |
| `sam_name` | Source organization legal name (readability). |
| `gt_is_match` | Ground truth: TRUE if a correct BMF EIN exists for this org. |
| `gt_outcome_class` | Ground-truth class: in_bmf_match / nonprofit_not_in_bmf / not_a_nonprofit / cant_determine / no_match_or_na. |
| `gt_ein` | Ground-truth correct EIN (may be an inactive-BMF or externally-collected EIN; blank if none). |
| `gt_ein_in_bmf` | TRUE if gt_ein appears in the unified BMF name index. |
| `gt_ein_bmf_active` | TRUE/FALSE if gt_ein is active/inactive in the BMF; NA if not in BMF. |
| `gt_method` | How truth was determined: algo_auto / tier1_screen / human_review / matched_inactive_bmf. |
| `gt_method_detail` | Finer determination detail / sub-tag. |
| `gt_confidence` | Labeler confidence: high / medium / low. |
| `gt_notes` | Ground-truth notes, incl. relabeling and held-for-review annotations. |
| `labeled_by` | Provenance of the label. |
| `label_date` | Date the label was assigned. |
| `is_gt_ein` | 1 if THIS candidate row's ein equals the ground-truth gt_ein (the correct pick within the group). |

