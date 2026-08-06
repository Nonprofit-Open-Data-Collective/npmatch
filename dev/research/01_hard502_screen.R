suppressMessages(library(data.table))
base <- "C:/Users/jdlec/Dropbox/00 - URBAN/00-GITHUB/npmatch"
idx <- readRDS(file.path(base,"data-dev/BMF-NAME-INDEX.rds")); setDT(idx)
lab <- fread(file.path(base,"data-dev/CALIBRATION-LABELED-502.csv"), colClasses=list(character=c(".id",".ein")))
sam <- fread(file.path(base,"data-dev/SAMPLE-2K-NONPROFITS.CSV"), colClasses="character")
setnames(sam, names(sam), gsub("^_|_$","",tolower(gsub("[^A-Za-z0-9]+","_",names(sam)))))

clean <- function(x){ x<-toupper(as.character(x)); x[is.na(x)]<-""
  x<-gsub("&"," AND ",x,fixed=TRUE); x<-gsub("[^A-Z0-9 ]"," ",x); trimws(gsub("\\s+"," ",x)) }
suf <- "( INC| INCORPORATED| CORP| CORPORATION| CO| COMPANY| LLC| LTD| LP| LLP| PC| PLLC| FOUNDATION| FDN| FUND| TRUST| SOCIETY| INSTITUTE| ASSOCIATION| ASSN| ASSOC| ORGANIZATION| ORG| NFP)$"
strip <- function(x){ x<-sub("^THE ","",x); for(i in 1:3){ y<-trimws(sub(suf,"",x)); if(all(y==x,na.rm=TRUE)) break; x<-y }; x }
ds <- function(x) gsub(" ","",x)

## per-query algo facts from the labeled candidate rows
ov <- lab[is_overall==TRUE, .(uei=.id, algo_tier=query_tier, algo_pick_ein=.ein, pick_correct=label)]
hg <- lab[label==TRUE, .(human_gt_ein=.ein[1]), by=.(uei=.id)]      # correct candidate if labeled
q  <- merge(ov, hg, by="uei", all.x=TRUE)
q[, human_says_match := !is.na(human_gt_ein)]
# join SAM context
sc <- sam[, .(uei=unique_entity_id, sam_name=legal_business_name, dba=dba_name,
              divn=entity_division_name, st=physical_address_province_or_state, estruct=entity_structure)]
q <- merge(q, sc, by="uei", all.x=TRUE)

NAME <- clean(q$sam_name)
q[, qnk := strip(NAME)][, qnk_ds := ds(qnk)][, qfc := sub("^THE ","",NAME)]
q[, qdk := strip(clean(dba))][, qvk := strip(clean(divn))]
idx[, bfc := sub("^THE ","",clean(name))]

## (1) legal-form / entity gate
gov  <- grepl("(^| )(CITY|COUNTY|TOWN|VILLAGE|TOWNSHIP) OF ", NAME) |
        grepl("HOUSING AUTHORITY|SCHOOL DISTRICT|PUBLIC LIBRARY|BOARD OF EDUCATION|BOARD OF COUNTY", NAME)
forp <- q$estruct=="2L" | grepl(" (LLC|L L C|LP|L P|LLP|PLLC|LLLP)$", NAME) | grepl("(^| )(LLC|LP)$", NAME)
q[, gate := fifelse(gov,"not_a_nonprofit:government", fifelse(forp,"not_a_nonprofit:for_profit", NA_character_))]

## (2) BMF name-index lookup
qk <- rbindlist(list(
  q[nzchar(qnk), .(uei, key=qnk, st, via="name")],
  q[nzchar(qdk), .(uei, key=qdk, st, via="dba")],
  q[nzchar(qvk), .(uei, key=qvk, st, via="division")]))
hits <- merge(qk, idx[, .(nk, ein, bstate=state, active, care_of, bfc)], by.x="key", by.y="nk", allow.cartesian=TRUE)
hits[, same_state := !is.na(st) & st==bstate]
dsx <- merge(q[nzchar(qnk_ds), .(uei, key=qnk_ds, st)],
             idx[, .(nk_ds, ein, bstate=state, active, care_of, bfc)], by.x="key", by.y="nk_ds", allow.cartesian=TRUE)
dsx[, `:=`(via="despace", same_state = !is.na(st) & st==bstate)]
allh <- rbindlist(list(hits, dsx), use.names=TRUE, fill=TRUE)
allh[, exact_full := bfc == q$qfc[match(uei, q$uei)]]
allh[, rank := fifelse(exact_full & same_state & active,1L, fifelse(exact_full & active,2L,
                fifelse(same_state & active,3L, fifelse(same_state & !active,4L, fifelse(active,5L,6L)))))]
setorder(allh, uei, rank)
best <- allh[, .SD[1], by=uei]

out <- merge(q, best[, .(uei, screen_ein=ein, screen_via=via, screen_active=active, screen_same_state=same_state)],
             by="uei", all.x=TRUE)
out[, det_t1 := fifelse(!is.na(gate), gate,
   fifelse(!is.na(screen_ein) & screen_same_state & screen_active, "match",
   fifelse(!is.na(screen_ein) & screen_same_state & !screen_active, "nonprofit_not_in_bmf:inactive",
   fifelse(!is.na(screen_ein) & screen_active, "match:cross_state?", NA_character_))))]
out[, needs_escalation := is.na(det_t1)]

## ground-truth determination: human label is authoritative; Tier-1 fills blocking-miss discoveries
out[, gt_ein := fifelse(human_says_match, human_gt_ein, "")]
out[, gt_det := fifelse(human_says_match, "match", "")]
# where human found NO candidate match but Tier-1 finds an active same-state EIN -> discovered FN
disc <- !out$human_says_match & out$det_t1=="match" & !is.na(out$det_t1)
out[disc, `:=`(gt_ein=screen_ein, gt_det="match", gt_src2="tier1_discovered")]
# fill remaining unresolved from gate / inactive
out[gt_det=="" & !is.na(gate), gt_det := sub(":.*","",gate)]
out[gt_det=="" & grepl("inactive",det_t1), gt_det := "nonprofit_not_in_bmf"]
out[gt_det=="", gt_det := "pending"]

## FP / FN  (algo labels preserved: algo_tier, algo_pick_ein)
out[, is_fp := algo_tier=="YES" & pick_correct==FALSE]
out[, is_fn := algo_tier %in% c("NO","MAYBE") & gt_det=="match" &
              (is.na(algo_pick_ein) | gt_ein!=algo_pick_ein | pick_correct==FALSE)]
fwrite(out[, .(uei, sam_name, algo_tier, algo_pick_ein, pick_correct, human_says_match,
   human_gt_ein, det_t1, screen_ein, screen_via, screen_active, screen_same_state,
   gt_ein, gt_det, is_fp, is_fn, needs_escalation)], file.path(base,"data-dev/HARD-GROUNDTRUTH.csv"))

cat(sprintf("=== HARD-502 Tier-1 screen ===\nqueries: %d  (algo YES %d / MAYBE %d / NO %d)\n",
    nrow(out), sum(out$algo_tier=="YES"), sum(out$algo_tier=="MAYBE"), sum(out$algo_tier=="NO")))
cat("\ngt_det:\n"); print(sort(table(out$gt_det), decreasing=TRUE))
cat(sprintf("\nFALSE POSITIVES (algo YES but pick wrong): %d  (of %d YES = %.1f%%)\n",
    sum(out$is_fp), sum(out$algo_tier=="YES"), 100*sum(out$is_fp)/sum(out$algo_tier=="YES")))
cat(sprintf("FALSE NEGATIVES (match exists, algo said NO/MAYBE): %d\n", sum(out$is_fn)))
cat(sprintf("  of which MAYBE: %d | NO: %d\n", sum(out$is_fn & out$algo_tier=="MAYBE"), sum(out$is_fn & out$algo_tier=="NO")))
cat(sprintf("  Tier-1 DISCOVERED (true EIN was never a candidate - blocking miss): %d\n", sum(disc)))
cat(sprintf("\nresolved by human labels + Tier-1: %d (%.0f%%) | still pending Tier2/3: %d\n",
    sum(out$gt_det!="pending"), 100*mean(out$gt_det!="pending"), sum(out$gt_det=="pending")))
cat("\n--- Tier-1 blocking-miss discoveries (algo missed, index found active same-state EIN) ---\n")
print(head(out[disc==TRUE, .(sam_name=substr(sam_name,1,40), algo_tier, screen_ein, screen_via)], 20))
