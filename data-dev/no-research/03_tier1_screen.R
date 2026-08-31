#!/usr/bin/env Rscript
# Tier 1 of dev/RESEARCH-PROTOCOL.md, run in bulk over both 500-case samples:
#   (a) legal-form / entity gate from SAM fields
#   (b) name-blind full-BMF lookup (active + inactive, 3.69M rows), no address gate
suppressPackageStartupMessages({library(data.table); library(npmatch)})

D <- "data-dev"; out <- file.path(D, "no-research")
s1 <- fread(file.path(out, "SAMPLE-STAGE1-NO-500.csv"), colClasses = "character")
s2 <- fread(file.path(out, "SAMPLE-STAGE2-NO-500.csv"), colClasses = "character")
s1[, .src := "stage1"]; s2[, .src := "stage2"]
all <- rbindlist(list(s1, s2), fill = TRUE)

B <- "\\b"   # word boundary, assembled to survive shell escaping

## ---- (a) entity gate -----------------------------------------------------
US <- c(state.abb, "DC", "PR", "VI", "GU", "AS", "MP", "FM", "MH", "PW")
nm <- toupper(all$sam_name)

all[, foreign := !(sam_state %in% US)]
all[, forprofit_form := grepl(paste0(B, "(LLC|L L C|LLP|LLLP|PLLC)", B), nm) |
      grepl(" LLC$| LP$| LLP$| PLLC$| PC$| INC CO$", nm)]
all[, govt_form := grepl("^(CITY OF|COUNTY OF|TOWN OF|VILLAGE OF|TOWNSHIP OF|BOROUGH OF|STATE OF|COMMONWEALTH OF)", nm) |
      grepl(paste0(B, "(SCHOOL DISTRICT|HOUSING AUTHORITY|PUBLIC LIBRARY|TRANSIT AUTHORITY|PORT AUTHORITY|AIRPORT AUTHORITY|COUNCIL OF GOVERNMENTS|SHERIFF|POLICE DEPARTMENT|FIRE DISTRICT|WATER DISTRICT|SEWER DISTRICT|UTILITY DISTRICT|CONSERVATION DISTRICT|BOARD OF EDUCATION|UNIFIED SCHOOL|COMMUNITY COLLEGE DISTRICT|PUBLIC SCHOOLS)", B), nm)]
all[, tribal := grepl(paste0(B, "(TRIBE|TRIBAL|NATION OF|BAND OF|PUEBLO OF|RANCHERIA|NATIVE VILLAGE)", B), nm)]
# SAM entity structure: 2J = sole proprietorship, 2K = partnership,
# 2L = corporate entity NOT tax exempt, 8H = corporate entity tax exempt
all[, person_like := sam_entity_structure == "2J" &
      grepl("^[A-Z]+ [A-Z] [A-Z]+$|^[A-Z]+ [A-Z]+$|^[A-Z]+ [A-Z]+ [A-Z]+$", nm) &
      !grepl(paste0(B, "(FOUNDATION|CHURCH|MINISTR|ASSOCIATION|SOCIETY|CENTER|CENTRE|INSTITUTE|COUNCIL|FUND|TRUST|ALLIANCE|NETWORK|CLUB|LEAGUE|CORPS|ACADEMY|SCHOOL|COLLEGE|HOUSE|PROJECT|GROUP|SERVICES|INC|LLC|COMPANY|FARM|GROUP)", B), nm)]
all[, church_like := grepl(paste0(B, "(CHURCH|CHAPEL|PARISH|MINISTR|MISSION|SYNAGOGUE|MOSQUE|MASJID|TEMPLE|CONGREGATION|DIOCESE|CATHEDRAL|ASSEMBLY OF GOD|BAPTIST|METHODIST|LUTHERAN|PRESBYTERIAN|EPISCOPAL|PENTECOSTAL|EVANGEL)", B), nm)]

all[, entity_gate := fcase(
  foreign,                        "foreign",
  person_like,                    "individual",
  govt_form,                      "government",
  tribal,                         "tribal_government",
  forprofit_form,                 "for_profit_form",
  sam_entity_structure == "2L",   "not_tax_exempt_corp",
  church_like,                    "church",
  default = "nonprofit_candidate")]

## ---- (b) name-blind full-BMF lookup -------------------------------------
idx <- readRDS(file.path(D, "BMF-NAME-INDEX.rds"))
setDT(idx)

q <- np_query(as.data.frame(all[, .(uei, name = sam_name, dba = sam_dba,
                                    street = sam_street1, city = sam_city,
                                    state = sam_state, zip5 = sam_zip)]),
              map = list(name = "name", dba = "dba", street = "street",
                         city = "city", state = "state", zip5 = "zip5", .id = "uei"))
qn <- as.data.table(np_normalize(q))
qn[, q_nk := name_key]
qn[, q_nk_ds := gsub("[^A-Z0-9]", "", name_key)]
all <- merge(all, qn[, .(uei = .id, q_nk, q_nk_ds)], by = "uei", all.x = TRUE, sort = FALSE)

fmt <- function(d) paste0(sprintf("%s|%s|%s, %s %s|active=%s",
                                  d$ein, d$name, d$city, d$state, d$zip5, d$active),
                          collapse = " ;; ")

roll <- function(keycol, qcol, label) {
  keys <- unique(all[[qcol]][!is.na(all[[qcol]]) & all[[qcol]] != ""])
  h <- idx[get(keycol) %in% keys]
  if (!nrow(h)) return(data.table(uei = character(), x = character()))
  m <- merge(all[, c("uei", "sam_state", qcol), with = FALSE], h,
             by.x = qcol, by.y = keycol, allow.cartesian = TRUE)
  m[, samestate := state == sam_state]
  setorder(m, uei, -samestate, -active)
  m[, .(x = paste0(label, ": ", fmt(.SD[1:min(.N, 6)]))), by = uei]
}
r1 <- roll("nk",    "q_nk",    "name_key")
r2 <- roll("nk_ds", "q_nk_ds", "name_key_nospace")
r3 <- roll("dk",    "q_nk_ds", "dba_key")

bmf <- rbindlist(list(r1, r2, r3))[, .(bmf_lookup = paste(unique(x), collapse = " || ")), by = uei]
all <- merge(all, bmf, by = "uei", all.x = TRUE, sort = FALSE)
all[is.na(bmf_lookup), bmf_lookup := ""]

# same-state exact-name hits are the strong Tier-1 recoveries
ss <- merge(all[, .(uei, sam_state, q_nk)], idx[nk != ""],
            by.x = "q_nk", by.y = "nk", allow.cartesian = TRUE)[state == sam_state]
all[, tier1_exact_same_state := uei %in% ss$uei]

all[, needs_web := entity_gate %in% c("nonprofit_candidate", "church", "tribal_government") &
      !tier1_exact_same_state]

fwrite(all[.src == "stage1"], file.path(out, "TIER1-STAGE1-NO-500.csv"))
fwrite(all[.src == "stage2"], file.path(out, "TIER1-STAGE2-NO-500.csv"))

cat("\n=== entity gate x sample ===\n");            print(table(all$entity_gate, all$.src))
cat("\n=== Tier-1 exact same-state BMF hit ===\n"); print(table(all$tier1_exact_same_state, all$.src))
cat("\n=== any full-BMF name lookup hit ===\n");    print(table(all$bmf_lookup != "", all$.src))
cat("\n=== needs web research ===\n");              print(table(all$needs_web, all$.src))
