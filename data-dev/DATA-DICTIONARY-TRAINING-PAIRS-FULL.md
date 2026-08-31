# TRAINING-PAIRS-FULL data dictionary

`TRAINING-PAIRS-FULL-1502.csv` / `.rds` -- one row per scored (source org x BMF candidate) pair; 304274 rows x 126 columns.
Group by `uei` for a source org's candidate set. **`match_yn`** is the target (1 = this EIN is the correct match).
Fields are marked **DERIVED** (with the formula + input fields) or direct imports. Similarities use reclin2 Jaro-Winkler (Winkler prefix p=0.1) floored at `jw_threshold` = 0.85.

| column | group | type | derived | inputs | derivation / formula |
|---|---|---|:--:|---|---|
| `match_yn` | target | 0/1 | yes | ein, gt_ein (ground-truth master) | DERIVED. 1 if digits(ein)==digits(gt_ein[uei]), else 0. The label: is this BMF EIN the ground-truth correct match for the source org. |
| `uei` | key | chr | no | - | Source (SAM/USASpending) Unique Entity ID (the query key). |
| `ein` | key | chr | no | - | Candidate BMF Employer Identification Number (one row per source org x candidate). |
| `sample_type` | key | chr | no | - | Stratum: 'random' (1,000 representative) or 'hard' (502 oversampled difficult cases). |
| `name_raw_x` | name-raw | chr | no | - | Raw source (SAM) legal name, as mapped from the input. |
| `name_raw_y` | name-raw | chr | no | - | Raw BMF legal name (BMF org_name_join). |
| `dba_x` | name-raw | chr | no | - | Raw source DBA name. |
| `dba_y` | name-raw | chr | no | - | Raw BMF DBA / sort name. |
| `division_x` | name-raw | chr | no | - | Raw source division name (SAM entity_division_name). |
| `division_y` | name-raw | chr | no | - | Raw BMF division name (usually empty). |
| `name_x` | name-norm | chr | yes | name_raw_x | DERIVED (name_full). str_squish(replace_tokens(basic_clean(name_raw), abbrev)) -- cleaned + abbreviation-standardized, legal suffix RETAINED. basic_clean = uppercase -> de-accent -> '&'->'AND' -> punctuation/non-alnum -> space -> squish. |
| `name_y` | name-norm | chr | yes | name_raw_y | DERIVED (name_full) of the BMF name; see name_x. |
| `name_key_x` | name-norm | chr | yes | name_raw_x | DERIVED. strip_lead_the(strip_suffix(name_x)) -- the match key: name_full with a trailing legal suffix (INC/CORP/LLC/ASSOCIATION/FOUNDATION/TRUST/...) and a leading 'THE' removed. |
| `name_key_y` | name-norm | chr | yes | name_raw_y | DERIVED. BMF match key; see name_key_x. |
| `street_norm_x` | addr-norm | chr | yes | street_x | DERIVED (street_key). USPS-standardized street with the unit/suite stripped (STREET->ST, AVENUE->AVE, SUITE removed, ...). |
| `street_norm_y` | addr-norm | chr | yes | street_y | DERIVED (street_key). BMF standardized street; see street_norm_x. |
| `name_ver_x` | name-norm | chr | yes | name/dba/division cross-products | DERIVED. Which source name version produced the best match: MAIN / DBA / DIVISION / TOKEN_OVERLAP. |
| `name_ver_y` | name-norm | chr | yes | name/dba cross-products | DERIVED. Which BMF name version matched: MAIN / DBA / TOKEN_OVERLAP. |
| `geo_zip9` | geo-flag | 0/1 | yes | zip9_x, zip9_y | DERIVED. 1 if zip9_x==zip9_y and both present, else 0. zip9 = zip5 + '-' + zip_plus4 (only when the +4 is known). |
| `geo_zip5` | geo-flag | 0/1 | yes | zip5_x, zip5_y | DERIVED. 1 if zip5_x==zip5_y and both present, else 0. |
| `geo_zip3` | geo-flag | 0/1 | yes | zip3_x, zip3_y | DERIVED. 1 if zip3_x==zip3_y, else 0. zip3 = first 3 digits of zip5 (SCF region). |
| `geo_state` | geo-flag | 0/1 | yes | state_x, state_y | DERIVED. 1 if state_x==state_y, else 0 (2-letter code). |
| `geo_stnum` | geo-flag | 0/1 | yes | street_num_x, street_num_y | DERIVED. 1 if street_num_x==street_num_y and both present, else 0. street_num = leading house/box number parsed from the street. |
| `geo_pobox` | geo-flag | 0/1 | yes | is_po_box_x, is_po_box_y | DERIVED. 1 if BOTH sides are PO boxes (is_po_box parsed from the street), else 0. |
| `name_match_type` | name-cmp | chr | yes | the winning cross-product | DERIVED. How the best name match was formed: exact (identical name_key) / dba (via a DBA/division variant) / name (fuzzy Jaro-Winkler) / token_overlap (containment/token recovery). |
| `name_freq` | name-cmp | int | yes | reference name_key frequency table | DERIVED (normalized_match_count). Count of BMF reference records sharing this candidate's name_key -- name distinctiveness; 1 = unique. |
| `name_gen_x` | name-feat | chr | yes | name_raw_x | DERIVED. Generation marker in the name (JR or SR), else NA. **VESTIGIAL -- do not model on this.** Person-name generational suffix, an artifact of npmatch's SAM/USASpending person-matching lineage. Organisations do not have generations; no veto rule consumes it and it carries no signal. Present for column compatibility only. |
| `name_gen_y` | name-feat | chr | yes | name_raw_y | DERIVED. BMF generation marker; see name_gen_x. VESTIGIAL. |
| `name_gen_rank_x` | name-feat | chr | yes | name_gen_x | DERIVED. Numeric rank of the generation marker: JR=2, SR=1. VESTIGIAL; see name_gen_x. |
| `name_gen_rank_y` | name-feat | chr | yes | name_gen_y | DERIVED. BMF generation rank; see name_gen_rank_x. VESTIGIAL. |
| `name_nums_x` | name-feat | chr | yes | name_raw_x | DERIVED. Space-joined embedded digit tokens in the name (chapter/local numbers). |
| `name_nums_y` | name-feat | chr | yes | name_raw_y | DERIVED. BMF embedded numbers; see name_nums_x. |
| `name_ord_x` | name-feat | chr | yes | name_raw_x | DERIVED. Canonical ordinal rank(s) found in the name (FIRST/1ST->1, SECOND/2ND->2, ... TENTH/10TH->10). |
| `name_ord_y` | name-feat | chr | yes | name_raw_y | DERIVED. BMF ordinals; see name_ord_x. |
| `name_dir_x` | name-feat | chr | yes | name_raw_x | DERIVED. Canonicalized direction word(s) in the name (NORTH->N, SOUTHWEST->SW, ...); single letters excluded. |
| `name_dir_y` | name-feat | chr | yes | name_raw_y | DERIVED. BMF directions; see name_dir_x. |
| `name_form_x` | name-feat | chr | yes | name_raw_x | DERIVED. Legal-form token detected/stripped from the name (INC, LLC, CORP, ASSOCIATION, FOUNDATION, ...), else NA. |
| `name_form_y` | name-feat | chr | yes | name_raw_y | DERIVED. BMF legal form; see name_form_x. |
| `street_x` | addr-raw | chr | no | - | Raw source street address (SAM physical_address_line_1). |
| `street_y` | addr-raw | chr | no | - | Raw BMF street address (org_addr_street). |
| `city_x` | addr-raw | chr | no | - | Raw source city. |
| `city_y` | addr-raw | chr | no | - | Raw BMF city. |
| `state_x` | addr-raw | chr | no | - | Source state (2-letter). |
| `state_y` | addr-raw | chr | no | - | BMF state (2-letter). |
| `zip5_x` | addr-raw | chr | no | - | Source 5-digit ZIP (leading zeros restored). |
| `zip5_y` | addr-raw | chr | no | - | BMF 5-digit ZIP (leading zeros restored). |
| `bmf_active` | scoring | lgl | yes | BMF active-file membership | DERIVED. TRUE if the candidate BMF org is in the ACTIVE BMF file; FALSE if inactive (present only in the unified active+inactive reference). |
| `score` | scoring | num | yes | name_sim, geo flags, city_sim, street_sim, name_freq, name_match_type | DERIVED (hier scorer). score = 0.60*name_sim + 0.40*geo, where geo = max(1.00*geo_zip9, 0.95*street_hit, 0.90*geo_zip5, 0.90*pobox_hit, 0.55*geo_zip3, 0.50*city_sim, 0.20*geo_state); street_hit = (geo_stnum==1 & street_sim>=0.9 & geo_pobox==0); pobox_hit = (geo_pobox==1 & geo_stnum==1). Distinctive-exact-name matches (name_sim>=0.95 & name_freq<=distinct_name_maxfreq) are floored up; token_overlap-only matches are capped below the YES threshold. |
| `veto` | scoring | lgl | yes | name_nums/ord/dir/form, legal form, BMF/SAM metadata | DERIVED. TRUE if a HARD do-not-match rule fired (number/ordinal/direction/legal-form conflict, for-profit legal form, ...) -> forces NO. |
| `veto_soft` | scoring | lgl | yes | affiliate suffix, government-entity pattern | DERIVED. TRUE if a SOFT rule fired (affiliate suffix e.g. '... FOUNDATION' the query lacks; government entity) -> caps the pair at MAYBE (review). |
| `pass` | scoring | chr | yes | blocking cascade | DERIVED. The cascade blocking pass that generated this candidate (exact-name, exact-name-dba, exact-dba-name, exact-dba-dba, token-state, token-concat, token-crossstate). |
| `name_sim` | name-cmp | num (0-1) | yes | name_key_x/y, dba_key, division_key, token IDF, geo_state | DERIVED. Effective name similarity = max(s_name, s_dba, s_overlap). s_name = Jaro-Winkler(name_key_x, name_key_y) with Winkler prefix p=0.1, floored to 0 below jw_threshold (0.85). s_dba = max Jaro-Winkler over the name x DBA, DBA x name, DBA x DBA, division x name, division x DBA cross-products (floored). s_overlap = containment-aware IDF-weighted token overlap for same-state below-threshold pairs (floored at 0.6). |
| `street_sim` | addr-cmp | num (0-1) | yes | street_norm_x/y | DERIVED. Jaro-Winkler(street_norm_x, street_norm_y), Winkler p=0.1, floored to 0 below jw_threshold (0.85). |
| `city_sim` | addr-cmp | num (0-1) | yes | city_x/y | DERIVED. Jaro-Winkler(city_x, city_y), floored to 0 below jw_threshold (0.85). |
| `zip_sim` | addr-cmp | 0/1 | yes | zip5_x/y | DERIVED. Exact-match indicator: 1 if zip5_x==zip5_y, else 0. |
| `BMF_ntee_clean` | bmf | chr | no | ntee_code_clean | Direct import: cleaned NTEE code. |
| `BMF_nteev2` | bmf | chr | no | nteev2 | Direct import: NTEEv2 classification. |
| `BMF_subsection` | bmf | chr | no | subsection_code | Direct import: 501(c) subsection code (3 = 501(c)(3)). |
| `BMF_is_foundation` | bmf | lgl | yes | foundation_code_definition | DERIVED. grepl('private (non-)?operating foundation', tolower(foundation_code_definition)) -- TRUE for private (operating/non-operating) foundations. |
| `BMF_rule_year` | bmf | int | yes | ruling_date | DERIVED. as.integer(substr(ruling_date, 1, 4)) -- year of the IRS exemption ruling. |
| `BMF_ruling_ym` | bmf | chr | no | ruling_date_ym_str | Direct import: IRS ruling year-month. |
| `BMF_accounting_period` | bmf | chr | no | accounting_period | Direct import: accounting-period month. |
| `BMF_assets` | bmf | num | no | asset_amount | Direct import (as.numeric): reported assets. |
| `BMF_revenue` | bmf | num | no | revenue_amount | Direct import (as.numeric): reported revenue. |
| `BMF_form_990` | bmf | chr | yes | pf_filing_requirement_code, filing_requirement_code_definition | DERIVED. ifelse(pf_filing_requirement_code=='1','990PF', map(filing_requirement_code_definition): '990-N'->990N, '990 (all other) or 990EZ'->990/990EZ, 'Group return'->990-group, 'Not required'->none). |
| `BMF_filing_requirement` | bmf | chr | no | filing_requirement_code_definition | Direct import: filing-requirement definition. |
| `BMF_pf_filing_requirement` | bmf | chr | no | pf_filing_requirement_code_definition | Direct import: private-foundation filing-requirement definition. |
| `BMF_affiliation_code` | bmf | chr | no | affiliation_code | Direct import: affiliation code (central/subordinate). |
| `BMF_affiliation` | bmf | chr | no | affiliation_code_definition | Direct import: affiliation-code definition. |
| `BMF_group_exemption_number` | bmf | chr | no | group_exemption_number | Direct import: group-exemption number. |
| `BMF_group_exemption_is_member` | bmf | lgl | no | group_exemption_is_member | Direct import: TRUE if a group-ruling member. |
| `BMF_in_care_of` | bmf | chr | no | in_care_of_name_clean | Direct import: cleaned in-care-of / director name. |
| `SAM_entity_start_date` | sam | chr | no | entity_start_date | Direct import: SAM entity start date. |
| `SAM_fiscal_year_end` | sam | chr | no | fiscal_year_end_close_date | Direct import: SAM fiscal year-end. |
| `SAM_entity_url` | sam | chr | no | entity_url | Direct import: SAM entity URL. |
| `SAM_entity_structure` | sam | chr | no | entity_structure | Direct import: SAM entity-structure code (e.g. 8H, 2L). |
| `SAM_entity_structure_label` | sam | chr | yes | entity_structure | DERIVED. Human label mapped from the entity-structure code (8H -> 'Corporate Entity (Tax Exempt)', 2L -> 'Corporate Entity (Not Tax Exempt)', ...). |
| `SAM_primary_naics` | sam | chr | no | primary_naics | Direct import: SAM primary NAICS code. |
| `SAM_poc_first_name` | sam | chr | no | govt_bus_poc_first_name | Direct import: SAM point-of-contact first name. |
| `SAM_poc_middle_initial` | sam | chr | no | govt_bus_poc_middle_initial | Direct import: SAM POC middle initial. |
| `SAM_poc_last_name` | sam | chr | no | govt_bus_poc_last_name | Direct import: SAM POC last name. |
| `SAM_poc_title` | sam | chr | no | govt_bus_poc_title | Direct import: SAM POC title. |
| `SAM_bus_type_minority_owned` | sam-bustype | lgl | yes | BUS TYPE STRING | DERIVED. TRUE if the SAM business-type code for 'minority owned' appears in the '~'-delimited BUS TYPE STRING. |
| `SAM_bus_type_nonprofit` | sam-bustype | lgl | yes | BUS TYPE STRING | DERIVED. TRUE if the SAM business-type code for 'nonprofit' appears in the '~'-delimited BUS TYPE STRING. |
| `SAM_bus_type_community_development_corp` | sam-bustype | lgl | yes | BUS TYPE STRING | DERIVED. TRUE if the SAM business-type code for 'community development corp' appears in the '~'-delimited BUS TYPE STRING. |
| `SAM_bus_type_hispanic_american_owned` | sam-bustype | lgl | yes | BUS TYPE STRING | DERIVED. TRUE if the SAM business-type code for 'hispanic american owned' appears in the '~'-delimited BUS TYPE STRING. |
| `SAM_bus_type_foundation` | sam-bustype | lgl | yes | BUS TYPE STRING | DERIVED. TRUE if the SAM business-type code for 'foundation' appears in the '~'-delimited BUS TYPE STRING. |
| `SAM_bus_type_educational_institution` | sam-bustype | lgl | yes | BUS TYPE STRING | DERIVED. TRUE if the SAM business-type code for 'educational institution' appears in the '~'-delimited BUS TYPE STRING. |
| `SAM_bus_type_state_controlled_higher_ed` | sam-bustype | lgl | yes | BUS TYPE STRING | DERIVED. TRUE if the SAM business-type code for 'state controlled higher ed' appears in the '~'-delimited BUS TYPE STRING. |
| `SAM_bus_type_black_american_owned` | sam-bustype | lgl | yes | BUS TYPE STRING | DERIVED. TRUE if the SAM business-type code for 'black american owned' appears in the '~'-delimited BUS TYPE STRING. |
| `SAM_bus_type_other_not_for_profit` | sam-bustype | lgl | yes | BUS TYPE STRING | DERIVED. TRUE if the SAM business-type code for 'other not for profit' appears in the '~'-delimited BUS TYPE STRING. |
| `SAM_bus_type_woman_owned` | sam-bustype | lgl | yes | BUS TYPE STRING | DERIVED. TRUE if the SAM business-type code for 'woman owned' appears in the '~'-delimited BUS TYPE STRING. |
| `SAM_bus_type_hospital` | sam-bustype | lgl | yes | BUS TYPE STRING | DERIVED. TRUE if the SAM business-type code for 'hospital' appears in the '~'-delimited BUS TYPE STRING. |
| `SAM_bus_type_domestic_shelter` | sam-bustype | lgl | yes | BUS TYPE STRING | DERIVED. TRUE if the SAM business-type code for 'domestic shelter' appears in the '~'-delimited BUS TYPE STRING. |
| `SAM_bus_type_llc` | sam-bustype | lgl | yes | BUS TYPE STRING | DERIVED. TRUE if the SAM business-type code for 'llc' appears in the '~'-delimited BUS TYPE STRING. |
| `SAM_bus_type_native_american_owned` | sam-bustype | lgl | yes | BUS TYPE STRING | DERIVED. TRUE if the SAM business-type code for 'native american owned' appears in the '~'-delimited BUS TYPE STRING. |
| `SAM_bus_type_american_indian_owned` | sam-bustype | lgl | yes | BUS TYPE STRING | DERIVED. TRUE if the SAM business-type code for 'american indian owned' appears in the '~'-delimited BUS TYPE STRING. |
| `SAM_bus_type_veteran_owned` | sam-bustype | lgl | yes | BUS TYPE STRING | DERIVED. TRUE if the SAM business-type code for 'veteran owned' appears in the '~'-delimited BUS TYPE STRING. |
| `SAM_bus_type_other` | sam-bustype | lgl | yes | BUS TYPE STRING | DERIVED. TRUE if the SAM business-type code for 'other' appears in the '~'-delimited BUS TYPE STRING. |
| `SAM_bus_type_abilityone_nonprofit` | sam-bustype | lgl | yes | BUS TYPE STRING | DERIVED. TRUE if the SAM business-type code for 'abilityone nonprofit' appears in the '~'-delimited BUS TYPE STRING. |
| `SAM_bus_type_sba_hubzone_joint_venture` | sam-bustype | lgl | yes | BUS TYPE STRING | DERIVED. TRUE if the SAM business-type code for 'sba hubzone joint venture' appears in the '~'-delimited BUS TYPE STRING. |
| `SAM_bus_type_private_university_or_college` | sam-bustype | lgl | yes | BUS TYPE STRING | DERIVED. TRUE if the SAM business-type code for 'private university or college' appears in the '~'-delimited BUS TYPE STRING. |
| `SAM_bus_type_dot_certified_dbe` | sam-bustype | lgl | yes | BUS TYPE STRING | DERIVED. TRUE if the SAM business-type code for 'dot certified dbe' appears in the '~'-delimited BUS TYPE STRING. |
| `SAM_bus_type_us_local_government` | sam-bustype | lgl | yes | BUS TYPE STRING | DERIVED. TRUE if the SAM business-type code for 'us local government' appears in the '~'-delimited BUS TYPE STRING. |
| `SAM_bus_type_city` | sam-bustype | lgl | yes | BUS TYPE STRING | DERIVED. TRUE if the SAM business-type code for 'city' appears in the '~'-delimited BUS TYPE STRING. |
| `SAM_bus_type_service_disabled_veteran_owned` | sam-bustype | lgl | yes | BUS TYPE STRING | DERIVED. TRUE if the SAM business-type code for 'service disabled veteran owned' appears in the '~'-delimited BUS TYPE STRING. |
| `SAM_bus_type_manufacturer` | sam-bustype | lgl | yes | BUS TYPE STRING | DERIVED. TRUE if the SAM business-type code for 'manufacturer' appears in the '~'-delimited BUS TYPE STRING. |
| `SAM_bus_type_subchapter_s_corp` | sam-bustype | lgl | yes | BUS TYPE STRING | DERIVED. TRUE if the SAM business-type code for 'subchapter s corp' appears in the '~'-delimited BUS TYPE STRING. |
| `SAM_bus_type_foreign_owned` | sam-bustype | lgl | yes | BUS TYPE STRING | DERIVED. TRUE if the SAM business-type code for 'foreign owned' appears in the '~'-delimited BUS TYPE STRING. |
| `SAM_bus_type_cdc_owned_firm` | sam-bustype | lgl | yes | BUS TYPE STRING | DERIVED. TRUE if the SAM business-type code for 'cdc owned firm' appears in the '~'-delimited BUS TYPE STRING. |
| `SAM_bus_type_joint_venture` | sam-bustype | lgl | yes | BUS TYPE STRING | DERIVED. TRUE if the SAM business-type code for 'joint venture' appears in the '~'-delimited BUS TYPE STRING. |
| `SAM_bus_type_asian_pacific_american_owned` | sam-bustype | lgl | yes | BUS TYPE STRING | DERIVED. TRUE if the SAM business-type code for 'asian pacific american owned' appears in the '~'-delimited BUS TYPE STRING. |
| `SAM_bus_type_minority_institution` | sam-bustype | lgl | yes | BUS TYPE STRING | DERIVED. TRUE if the SAM business-type code for 'minority institution' appears in the '~'-delimited BUS TYPE STRING. |
| `SAM_bus_type_native_hawaiian_org_owned` | sam-bustype | lgl | yes | BUS TYPE STRING | DERIVED. TRUE if the SAM business-type code for 'native hawaiian org owned' appears in the '~'-delimited BUS TYPE STRING. |
| `SAM_bus_type_hispanic_serving_institution` | sam-bustype | lgl | yes | BUS TYPE STRING | DERIVED. TRUE if the SAM business-type code for 'hispanic serving institution' appears in the '~'-delimited BUS TYPE STRING. |
| `SAM_bus_type_subcontinent_asian_american_owned` | sam-bustype | lgl | yes | BUS TYPE STRING | DERIVED. TRUE if the SAM business-type code for 'subcontinent asian american owned' appears in the '~'-delimited BUS TYPE STRING. |
| `SAM_bus_type_alaskan_native_corp_owned` | sam-bustype | lgl | yes | BUS TYPE STRING | DERIVED. TRUE if the SAM business-type code for 'alaskan native corp owned' appears in the '~'-delimited BUS TYPE STRING. |
| `SAM_bus_type_indian_tribe_federally_recognized` | sam-bustype | lgl | yes | BUS TYPE STRING | DERIVED. TRUE if the SAM business-type code for 'indian tribe federally recognized' appears in the '~'-delimited BUS TYPE STRING. |
| `SAM_bus_type_us_state_government` | sam-bustype | lgl | yes | BUS TYPE STRING | DERIVED. TRUE if the SAM business-type code for 'us state government' appears in the '~'-delimited BUS TYPE STRING. |
| `SAM_bus_type_small_agricultural_cooperative` | sam-bustype | lgl | yes | BUS TYPE STRING | DERIVED. TRUE if the SAM business-type code for 'small agricultural cooperative' appears in the '~'-delimited BUS TYPE STRING. |
| `SAM_bus_type_hbcu` | sam-bustype | lgl | yes | BUS TYPE STRING | DERIVED. TRUE if the SAM business-type code for 'hbcu' appears in the '~'-delimited BUS TYPE STRING. |
| `SAM_bus_type_municipality` | sam-bustype | lgl | yes | BUS TYPE STRING | DERIVED. TRUE if the SAM business-type code for 'municipality' appears in the '~'-delimited BUS TYPE STRING. |
| `SAM_bus_type_self_certified_hubzone_jv` | sam-bustype | lgl | yes | BUS TYPE STRING | DERIVED. TRUE if the SAM business-type code for 'self certified hubzone jv' appears in the '~'-delimited BUS TYPE STRING. |
| `SAM_bus_type_self_certified_small_disadvantaged` | sam-bustype | lgl | yes | BUS TYPE STRING | DERIVED. TRUE if the SAM business-type code for 'self certified small disadvantaged' appears in the '~'-delimited BUS TYPE STRING. |
| `SAM_bus_type_for_profit` | sam-bustype | lgl | yes | BUS TYPE STRING | DERIVED. TRUE if the SAM business-type code for 'for profit' appears in the '~'-delimited BUS TYPE STRING. |
| `SAM_bus_type_land_grant_1862` | sam-bustype | lgl | yes | BUS TYPE STRING | DERIVED. TRUE if the SAM business-type code for 'land grant 1862' appears in the '~'-delimited BUS TYPE STRING. |
