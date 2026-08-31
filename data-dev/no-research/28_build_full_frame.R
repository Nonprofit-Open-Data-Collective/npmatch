#!/usr/bin/env Rscript
# Phase 0-1 at full scale: build the seed frame for ALL 40,860 NO cases.
# Same logic as 02/03/04 (which operate on the 1,000-case sample), generalised.
# Output: FULL-SEED.csv -- one row per pool case, gated or queued for research.
suppressPackageStartupMessages({library(data.table); library(npmatch)})

D <- "data-dev"; out <- file.path(D, "no-research")
B <- "\\b"
p1 <- fread(file.path(out, "POOL-STAGE1-NO.csv"), colClasses = "character")
p2 <- fread(file.path(out, "POOL-STAGE2-NO.csv"), colClasses = "character")
pool <- rbindlist(list(p1, p2))
cat("pool:", format(nrow(pool), big.mark = ","), "\n")

## ---- SAM attributes ------------------------------------------------------
samcols <- c("UNIQUE ENTITY ID","LEGAL BUSINESS NAME","DBA NAME","ENTITY DIVISION NAME",
             "PHYSICAL ADDRESS LINE 1","PHYSICAL ADDRESS LINE 2","PHYSICAL ADDRESS CITY",
             "PHYSICAL ADDRESS PROVINCE OR STATE","PHYSICAL ADDRESS ZIP/POSTAL CODE",
             "ENTITY URL","ENTITY STRUCTURE","STATE OF INCORPORATION","BUS TYPE STRING",
             "PRIMARY NAICS","INITIAL REGISTRATION DATE","ENTITY START DATE","CAGE CODE",
             "GOVT BUS POC FIRST NAME","GOVT BUS POC LAST NAME","GOVT BUS POC TITLE",
             "MAILING ADDRESS LINE 1","MAILING ADDRESS CITY",
             "MAILING ADDRESS STATE OR PROVINCE","MAILING ADDRESS ZIP/POSTAL CODE")
newnm <- c("uei","sam_name","sam_dba","sam_division","sam_street1","sam_street2","sam_city",
           "sam_state","sam_zip","sam_url","sam_entity_structure","sam_state_incorp",
           "sam_bus_type","sam_naics","sam_reg_date","sam_start_date","sam_cage",
           "sam_poc_first","sam_poc_last","sam_poc_title",
           "sam_mail_street","sam_mail_city","sam_mail_state","sam_mail_zip")
read_sam <- function(f) {
  x <- fread(f, select = samcols, colClasses = "character", showProgress = FALSE)
  setnames(x, samcols, newnm); unique(x, by = "uei")
}
sam <- unique(rbindlist(list(
  read_sam(file.path(D, "run-2025NOV", "ALL-NONPROFITS.CSV")),
  read_sam(file.path(D, "FRESH-NEW-2026MAY.CSV")))), by = "uei")
a <- merge(pool, sam, by = "uei", all.x = TRUE, sort = FALSE)
cat("missing SAM name:", sum(is.na(a$sam_name) | a$sam_name == ""), "\n")

## ---- stage-2: the candidate slate the adjudicator saw --------------------
dec <- rbindlist(list(
  fread(file.path(D,"run-2025NOV","llm-review","DECISIONS-ALL.csv"), colClasses="character"),
  fread(file.path(D,"run-2026MAY","llm-review","DECISIONS-ALL.csv"), colClasses="character")),
  fill = TRUE)
a <- merge(a, unique(dec[llm_decision == "NO",
           .(uei, rejected_ein = best_ein, llm_confidence, llm_reason)], by = "uei"),
           by = "uei", all.x = TRUE, sort = FALSE)

revcols <- c("uei","ein","name_similarity","addr_similarity","total_score","match_type",
             "decision_reason","name_bmf_raw_main","city_bmf","state_bmf","zip5_bmf","bmf_active")
revf <- c(list.files(file.path(D,"run-2025NOV"), "^review-[0-9]+[.]csv$", full.names=TRUE),
          file.path(D,"run-2026MAY","batch1-new","review-01.csv"),
          list.files(file.path(D,"run-2026MAY","rest"), "^review-[0-9]+[.]csv$", full.names=TRUE))
s2u <- a[stage == "stage2"]$uei
rev <- rbindlist(lapply(revf, function(f) {
  x <- fread(f, select = revcols, colClasses = "character", showProgress = FALSE)
  x[uei %chin% s2u]
}), fill = TRUE)
setorder(rev, uei, -total_score)
cand <- rev[, .(n_candidates = .N,
  candidates = paste0(sprintf("%s | %s | %s, %s %s | score=%s name=%s addr=%s type=%s active=%s",
      ein, name_bmf_raw_main, city_bmf, state_bmf, zip5_bmf, total_score,
      name_similarity, addr_similarity, match_type, bmf_active), collapse = " ;; ")), by = uei]
a <- merge(a, cand, by = "uei", all.x = TRUE, sort = FALSE)
cat("stage-2 rows with a candidate slate:",
    sum(a$stage == "stage2" & !is.na(a$n_candidates)), "of", sum(a$stage == "stage2"), "\n")

## ---- entity gate ---------------------------------------------------------
US <- c(state.abb,"DC","PR","VI","GU","AS","MP","FM","MH","PW")
nm <- toupper(a$sam_name)
a[, foreign := !(sam_state %in% US)]
a[, forprofit_form := grepl(paste0(B,"(LLC|L L C|LLP|LLLP|PLLC)",B), nm) |
    grepl(" LLC$| LP$| LLP$| PLLC$| PC$| INC CO$", nm)]
a[, govt_form := grepl("^(CITY OF|COUNTY OF|TOWN OF|VILLAGE OF|TOWNSHIP OF|BOROUGH OF|STATE OF|COMMONWEALTH OF)", nm) |
    grepl(paste0(B,"(SCHOOL DISTRICT|HOUSING AUTHORITY|PUBLIC LIBRARY|TRANSIT AUTHORITY|PORT AUTHORITY|AIRPORT AUTHORITY|COUNCIL OF GOVERNMENTS|SHERIFF|POLICE DEPARTMENT|FIRE DISTRICT|WATER DISTRICT|SEWER DISTRICT|UTILITY DISTRICT|CONSERVATION DISTRICT|BOARD OF EDUCATION|UNIFIED SCHOOL|COMMUNITY COLLEGE DISTRICT|PUBLIC SCHOOLS)",B), nm)]
a[, tribal := grepl(paste0(B,"(TRIBE|TRIBAL|NATION OF|BAND OF|PUEBLO OF|RANCHERIA|NATIVE VILLAGE)",B), nm)]
a[, person_like := sam_entity_structure == "2J" &
    grepl("^[A-Z]+ [A-Z] [A-Z]+$|^[A-Z]+ [A-Z]+$|^[A-Z]+ [A-Z]+ [A-Z]+$", nm) &
    !grepl(paste0(B,"(FOUNDATION|CHURCH|MINISTR|ASSOCIATION|SOCIETY|CENTER|CENTRE|INSTITUTE|COUNCIL|FUND|TRUST|ALLIANCE|NETWORK|CLUB|LEAGUE|CORPS|ACADEMY|SCHOOL|COLLEGE|HOUSE|PROJECT|GROUP|SERVICES|INC|LLC|COMPANY|FARM)",B), nm)]
a[, church_like := grepl(paste0(B,"(CHURCH|CHAPEL|PARISH|MINISTR|MISSION|SYNAGOGUE|MOSQUE|MASJID|TEMPLE|CONGREGATION|DIOCESE|CATHEDRAL|ASSEMBLY OF GOD|BAPTIST|METHODIST|LUTHERAN|PRESBYTERIAN|EPISCOPAL|PENTECOSTAL|EVANGEL)",B), nm)]
a[, entity_gate := fcase(
  foreign, "foreign", person_like, "individual", govt_form, "government",
  tribal, "tribal_government", forprofit_form, "for_profit_form",
  sam_entity_structure == "2L", "not_tax_exempt_corp", church_like, "church",
  default = "nonprofit_candidate")]
a[, foreign_us_incorp := entity_gate == "foreign" & sam_state_incorp %in% US]
cat("\nentity gate:\n"); print(table(a$entity_gate))

## ---- normalized keys + full-BMF exact lookup ----------------------------
q <- np_query(as.data.frame(a[, .(uei, name = sam_name, dba = sam_dba,
                                  street = sam_street1, city = sam_city,
                                  state = sam_state, zip5 = sam_zip)]),
              map = list(name="name", dba="dba", street="street", city="city",
                         state="state", zip5="zip5", .id="uei"))
qn <- as.data.table(np_normalize(q))
qn[, q_nk := name_key][, q_nk_ds := gsub("[^A-Z0-9]", "", name_key)]
a <- merge(a, qn[, .(uei = .id, q_nk, q_nk_ds)], by = "uei", all.x = TRUE, sort = FALSE)

idx <- as.data.table(readRDS(file.path(D, "BMF-NAME-INDEX.rds")))
fmt <- function(d) paste0(sprintf("%s|%s|%s, %s %s|active=%s",
                                  d$ein, d$name, d$city, d$state, d$zip5, d$active),
                          collapse = " ;; ")
roll <- function(keycol, qcol, label) {
  keys <- unique(a[[qcol]][!is.na(a[[qcol]]) & a[[qcol]] != ""])
  h <- idx[get(keycol) %chin% keys]
  if (!nrow(h)) return(data.table(uei = character(), x = character()))
  m <- merge(a[, c("uei","sam_state",qcol), with = FALSE], h,
             by.x = qcol, by.y = keycol, allow.cartesian = TRUE)
  m[, samestate := state == sam_state]
  setorder(m, uei, -samestate, -active)
  m[, .(x = paste0(label, ": ", fmt(.SD[1:min(.N,6)]))), by = uei]
}
bmf <- rbindlist(list(roll("nk","q_nk","name_key"),
                      roll("nk_ds","q_nk_ds","name_key_nospace"),
                      roll("dk","q_nk_ds","dba_key")))[
       , .(bmf_lookup = paste(unique(x), collapse = " || ")), by = uei]
a <- merge(a, bmf, by = "uei", all.x = TRUE, sort = FALSE)
a[is.na(bmf_lookup), bmf_lookup := ""]
ss <- merge(a[, .(uei, sam_state, q_nk)], idx[nk != ""],
            by.x = "q_nk", by.y = "nk", allow.cartesian = TRUE)[state == sam_state]
a[, tier1_exact_same_state := uei %chin% ss$uei]
cat("with any BMF name hit:", sum(a$bmf_lookup != ""),
    " | exact same-state:", sum(a$tier1_exact_same_state), "\n")

## ---- efile domain ---------------------------------------------------------
dom <- function(u){u<-tolower(trimws(u));u<-sub("^[a-z]+://","",u);u<-sub("^www[0-9]?\\.","",u)
  u<-sub("[/?#].*$","",u);u<-sub(":.*$","",u);u<-sub("\\.+$","",u)
  u[is.na(u)|!grepl("\\.",u)|nchar(u)<4]<-"";u}
a[, sam_domain := dom(sam_url)]
ex <- fread(file.path(out,"EFILE-XWALK.tsv"), sep="\t", select=c("ein","web_domain"),
            colClasses="character", quote="", showProgress=FALSE)
ed <- ex[web_domain != ""]
a[, efile_domain_hit := sam_domain != "" & sam_domain %chin% ed$web_domain]
cat("efile domain hits:", sum(a$efile_domain_hit), "\n")

## ---- seeded determinations + escape hatch -------------------------------
for (b in c("ein_found","determination","resolving_tier","confidence","sources","judgement","notes"))
  a[[b]] <- ""
sr <- function(i, det, conf, src, judg)
  a[i, `:=`(determination = det, resolving_tier = "tier1", confidence = conf,
            sources = src, judgement = judg)]
sr(a$entity_gate == "individual", "not_a_nonprofit", "high",
   "SAM entity structure 2J (sole proprietorship) + person-form legal name",
   "Registrant is an individual/sole proprietor, not an organization.")
sr(a$entity_gate == "for_profit_form", "not_a_nonprofit", "high",
   "SAM legal business name carries a for-profit legal form (LLC/LP/PLLC)",
   "For-profit legal form; not an IRS-recognized exempt organization.")
sr(a$entity_gate == "government", "not_a_nonprofit", "high",
   "SAM legal business name is a government unit",
   "Government unit, not a 501(c) filer.")
sr(a$entity_gate == "not_tax_exempt_corp", "not_a_nonprofit", "medium",
   "SAM entity structure 2L = corporate entity, NOT tax exempt",
   "SAM reports the registrant as a non-tax-exempt corporation.")
sr(a$entity_gate == "foreign" & !a$foreign_us_incorp, "nonprofit_not_in_bmf", "high",
   "SAM physical address outside the US; no US state of incorporation",
   "Foreign entity, outside the scope of the IRS BMF.")

a[, escape := bmf_lookup != "" | entity_gate == "not_tax_exempt_corp" | efile_domain_hit]
a[escape == TRUE, `:=`(determination="", resolving_tier="", confidence="",
                       sources="", judgement="")]
a[, web := determination == "" | tier1_exact_same_state | foreign_us_incorp]
a[, web_reason := fcase(
  tier1_exact_same_state, "confirm_tier1_exact_name_hit",
  foreign_us_incorp,      "foreign_address_but_us_incorporated",
  efile_domain_hit,       "efile_990_filer_shares_this_website",
  entity_gate == "not_tax_exempt_corp", "sam_2L_flag_unreliable",
  entity_gate == "church", "church_may_or_may_not_be_in_bmf",
  entity_gate == "tribal_government", "tribal_entity",
  default = "open_nonprofit_candidate")]

fwrite(a, file.path(out, "FULL-SEED.csv"))
cat("\n=== FULL SEED ===\n")
cat("total:", format(nrow(a), big.mark=","),
    " settled free:", format(sum(!a$web), big.mark=","),
    " to research:", format(sum(a$web), big.mark=","), "\n")
print(a[web == TRUE, .N, by = .(stage, web_reason)][order(stage, -N)])
fwrite(a[web == TRUE, .(uei, sam_name)], file.path(out, "QUEUE-FULL.csv"))
cat("\nwrote FULL-SEED.csv and QUEUE-FULL.csv\n")
