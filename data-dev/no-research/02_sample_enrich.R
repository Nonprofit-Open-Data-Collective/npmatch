#!/usr/bin/env Rscript
# Draw 500 stage-1 NO + 500 stage-2 NO and attach the evidence a researcher needs.
suppressPackageStartupMessages({library(data.table)})
set.seed(20260826)

D <- "data-dev"; out <- file.path(D,"no-research")
p1 <- fread(file.path(out,"POOL-STAGE1-NO.csv"), colClasses="character")
p2 <- fread(file.path(out,"POOL-STAGE2-NO.csv"), colClasses="character")

# stage-1: stratify by run so 2026MAY is represented in proportion to its pool
n1 <- 500
take <- function(dt, k) dt[sample(.N, min(k,.N))]
s1 <- rbindlist(lapply(split(p1, p1$run), function(g)
  take(g, round(n1 * nrow(g)/nrow(p1)))))
if (nrow(s1) < n1) s1 <- rbind(s1, take(p1[!uei %in% s1$uei], n1-nrow(s1)))
s1 <- s1[sample(.N)]
s2 <- take(p2, 500)

## ---- SAM attributes ------------------------------------------------------
samcols <- c("UNIQUE ENTITY ID","LEGAL BUSINESS NAME","DBA NAME","ENTITY DIVISION NAME",
             "PHYSICAL ADDRESS LINE 1","PHYSICAL ADDRESS LINE 2","PHYSICAL ADDRESS CITY",
             "PHYSICAL ADDRESS PROVINCE OR STATE","PHYSICAL ADDRESS ZIP/POSTAL CODE",
             "ENTITY URL","ENTITY STRUCTURE","STATE OF INCORPORATION","BUS TYPE STRING",
             "PRIMARY NAICS","INITIAL REGISTRATION DATE","ENTITY START DATE","CAGE CODE",
             "GOVT BUS POC FIRST NAME","GOVT BUS POC LAST NAME","GOVT BUS POC TITLE",
             "MAILING ADDRESS LINE 1","MAILING ADDRESS CITY","MAILING ADDRESS STATE OR PROVINCE",
             "MAILING ADDRESS ZIP/POSTAL CODE")
newnm <- c("uei","sam_name","sam_dba","sam_division","sam_street1","sam_street2","sam_city",
           "sam_state","sam_zip","sam_url","sam_entity_structure","sam_state_incorp",
           "sam_bus_type","sam_naics","sam_reg_date","sam_start_date","sam_cage",
           "sam_poc_first","sam_poc_last","sam_poc_title",
           "sam_mail_street","sam_mail_city","sam_mail_state","sam_mail_zip")

read_sam <- function(f) {
  x <- fread(f, select=samcols, colClasses="character", showProgress=FALSE)
  setnames(x, samcols, newnm); unique(x, by="uei")
}
sam <- unique(rbindlist(list(
  read_sam(file.path(D,"run-2025NOV","ALL-NONPROFITS.CSV")),
  read_sam(file.path(D,"FRESH-NEW-2026MAY.CSV")))), by="uei")

s1 <- merge(s1, sam, by="uei", all.x=TRUE, sort=FALSE)
s2 <- merge(s2, sam, by="uei", all.x=TRUE, sort=FALSE)

## ---- stage-2: the candidate the LLM rejected -----------------------------
dec <- fread(file.path(D,"run-2025NOV","llm-review","DECISIONS-ALL.csv"), colClasses="character")
s2 <- merge(s2, unique(dec[llm_decision=="NO", .(uei, rejected_ein=best_ein,
            llm_confidence, llm_reason)], by="uei"), by="uei", all.x=TRUE, sort=FALSE)

revcols <- c("uei","ein","name_similarity","addr_similarity","total_score","match_type",
             "is_top_candidate","decision_reason","veto","veto_reason",
             "name_bmf_raw_main","street_bmf","city_bmf","state_bmf","zip5_bmf","bmf_active")
revf <- list.files(file.path(D,"run-2025NOV"), "^review-[0-9]+[.]csv$", full.names=TRUE)
rev <- rbindlist(lapply(revf, function(f) {
  x <- fread(f, select=revcols, colClasses="character", showProgress=FALSE)
  x[uei %in% s2$uei]
}))
# collapse the candidate slate the LLM saw into one readable field per uei
setorder(rev, uei, -total_score)
cand <- rev[, .(n_candidates = .N,
                candidates = paste0(sprintf("%s | %s | %s, %s %s | score=%s name=%s addr=%s type=%s active=%s",
                                    ein, name_bmf_raw_main, city_bmf, state_bmf, zip5_bmf,
                                    total_score, name_similarity, addr_similarity, match_type, bmf_active),
                                    collapse=" ;; "),
                top_reason = decision_reason[1]), by=uei]
s2 <- merge(s2, cand, by="uei", all.x=TRUE, sort=FALSE)

## ---- blank research columns ---------------------------------------------
blank <- c("ein_found","determination","resolving_tier","confidence","sources","judgement","notes")
for (b in blank) { s1[[b]] <- ""; s2[[b]] <- "" }

fwrite(s1, file.path(out,"SAMPLE-STAGE1-NO-500.csv"))
fwrite(s2, file.path(out,"SAMPLE-STAGE2-NO-500.csv"))
cat("stage1 sample:", nrow(s1), " by run:\n"); print(table(s1$run))
cat("stage2 sample:", nrow(s2), "\n")
cat("stage1 missing SAM name:", sum(is.na(s1$sam_name)|s1$sam_name==""), "\n")
cat("stage2 missing SAM name:", sum(is.na(s2$sam_name)|s2$sam_name==""), "\n")
cat("stage2 with candidate slate:", sum(!is.na(s2$n_candidates)), "\n")
