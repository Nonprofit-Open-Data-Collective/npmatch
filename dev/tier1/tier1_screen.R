suppressMessages(library(data.table))
base <- "C:/Users/jdlec/Dropbox/00 - URBAN/00-GITHUB/npmatch"
idx <- readRDS(file.path(base,"data-dev/BMF-NAME-INDEX.rds")); setDT(idx)
res <- as.data.table(readRDS(file.path(base,"data-dev/RES-1K-RANDOM.rds")))
sam <- fread(file.path(base,"data-dev/RANDOM-1K.csv"), colClasses="character")
setnames(sam, names(sam), gsub("^_|_$","",tolower(gsub("[^A-Za-z0-9]+","_",names(sam)))))

clean <- function(x){ x<-toupper(as.character(x)); x[is.na(x)]<-""
  x<-gsub("&"," AND ",x,fixed=TRUE); x<-gsub("[^A-Z0-9 ]"," ",x); trimws(gsub("\\s+"," ",x)) }
suf <- "( INC| INCORPORATED| CORP| CORPORATION| CO| COMPANY| LLC| LTD| LP| LLP| PC| PLLC| FOUNDATION| FDN| FUND| TRUST| SOCIETY| INSTITUTE| ASSOCIATION| ASSN| ASSOC| ORGANIZATION| ORG| NFP)$"
strip <- function(x){ x<-sub("^THE ","",x); for(i in 1:3){ y<-trimws(sub(suf,"",x)); if(all(y==x,na.rm=TRUE)) break; x<-y }; x }
ds <- function(x) gsub(" ","",x)

## residual = MAYBE + NO (+ zero-candidate queries not in res)
resid_ids <- res[tier %in% c("MAYBE","NO"), .id]
zero_ids  <- setdiff(sam$unique_entity_id, res$.id)          # drawn but zero candidates
q <- sam[unique_entity_id %in% c(resid_ids, zero_ids)]
q[, algo_tier := res$tier[match(unique_entity_id, res$.id)]]
q[is.na(algo_tier), algo_tier := "ZERO_CAND"]
q[, algo_pick_ein := res$overall_ein[match(unique_entity_id, res$.id)]]
NAME <- clean(q$legal_business_name)
q[, qnk := strip(NAME)]; q[, qnk_ds := ds(qnk)]
q[, qfc := sub("^THE ","",NAME)]                          # full clean (suffix retained) for variant tiebreak
q[, qdk := strip(clean(dba_name))]; q[, qvk := strip(clean(entity_division_name))]
idx[, bfc := sub("^THE ","",clean(name))]

## (1) legal-form / entity gate
gov <- grepl("(^| )(CITY|COUNTY|TOWN|VILLAGE|TOWNSHIP) OF ", NAME) |
       grepl("HOUSING AUTHORITY|SCHOOL DISTRICT|PUBLIC LIBRARY|BOARD OF EDUCATION|BOARD OF COUNTY", NAME)
forp <- q$entity_structure=="2L" | grepl(" (LLC|L L C|LP|L P|LLP|PLLC|LLLP)$", NAME) |
        grepl("(^| )(LLC|LP)$", NAME)
q[, gate := fifelse(gov,"not_a_nonprofit:government",
              fifelse(forp,"not_a_nonprofit:for_profit", NA_character_))]

## (2) BMF name lookup (index keyed on nk). helper: best hit for a set of keys
lookup <- function(keys, state, kind){
  h <- idx[.(keys), nomatch=0L, on="nk"][nchar(nk)>=3]
  if(!nrow(h)) return(data.table())
  h[, `:=`(uei_state=state[match(nk, keys)], via=kind)]
  h
}
# build a long table of (uei -> query keys) then join
qk <- rbindlist(list(
  q[nzchar(qnk),    .(uei=unique_entity_id, key=qnk,    st=physical_address_province_or_state, via="name")],
  q[nzchar(qdk),    .(uei=unique_entity_id, key=qdk,    st=physical_address_province_or_state, via="dba")],
  q[nzchar(qvk),    .(uei=unique_entity_id, key=qvk,    st=physical_address_province_or_state, via="division")]
))
hits <- merge(qk, idx[, .(nk, ein, bstate=state, active, care_of, bfc)], by.x="key", by.y="nk", allow.cartesian=TRUE)
hits[, same_state := !is.na(st) & st==bstate]
# de-spaced pass (STEP FORWARD -> STEPFORWARD): match query despaced to index nk_ds
dsx <- merge(q[nzchar(qnk_ds), .(uei=unique_entity_id, key=qnk_ds, st=physical_address_province_or_state)],
             idx[, .(nk_ds, ein, bstate=state, active, care_of, bfc)], by.x="key", by.y="nk_ds", allow.cartesian=TRUE)
dsx[, `:=`(via="despace", same_state = !is.na(st) & st==bstate)]
allh <- rbindlist(list(hits, dsx), use.names=TRUE, fill=TRUE)
# variant tiebreak: does the BMF full name equal the query full name (suffix-inclusive)?
allh[, exact_full := bfc == q$qfc[match(uei, q$unique_entity_id)]]
# rank: exact-full+same-state+active best; then exact-full active; then same-state active; ...
allh[, rank := fifelse(exact_full & same_state & active,1L,
                fifelse(exact_full & active,2L,
                fifelse(same_state & active,3L, fifelse(same_state & !active,4L,
                fifelse(active,5L,6L)))))]
setorder(allh, uei, rank)
best <- allh[, .SD[1], by=uei]

out <- q[, .(uei=unique_entity_id, sam_name=legal_business_name, algo_tier, algo_pick_ein, gate)]
out <- merge(out, best[, .(uei, screen_ein=ein, screen_via=via, screen_active=active,
                           screen_same_state=same_state, screen_care_of=care_of)], by="uei", all.x=TRUE)
out[, determination_t1 := fifelse(!is.na(gate), gate,
   fifelse(!is.na(screen_ein) & screen_same_state & screen_active, "match",
   fifelse(!is.na(screen_ein) & screen_same_state & !screen_active, "nonprofit_not_in_bmf:inactive",
   fifelse(!is.na(screen_ein) & screen_active, "match:cross_state?", NA_character_))))]
out[, needs_escalation := is.na(determination_t1)]
fwrite(out, file.path(base,"data-dev/TIER1-DETERMINATIONS.csv"))
cat(sprintf("Tier-1 screen over %d residual queries (%d MAYBE, %d NO, %d zero-cand)\n",
    nrow(out), sum(out$algo_tier=="MAYBE"), sum(out$algo_tier=="NO"), sum(out$algo_tier=="ZERO_CAND")))
cat("\ndetermination_t1 breakdown:\n"); print(table(sub(":.*","",out$determination_t1), useNA="always"))
cat("\nfull labels:\n"); print(sort(table(out$determination_t1), decreasing=TRUE))
cat(sprintf("\nresolved by Tier 1: %d (%.0f%%) | escalate: %d\n",
    sum(!out$needs_escalation), 100*mean(!out$needs_escalation), sum(out$needs_escalation)))
cat("\nsample matches found (blocking-misses the algo tiered as MAYBE/NO):\n")
print(head(out[determination_t1 %in% c("match","match:cross_state?") & algo_tier!="YES",
    .(sam_name, algo_tier, screen_ein, screen_via, screen_active)], 15))
cat("\ninactive-only matches (would need unified BMF):\n")
print(head(out[grepl("inactive",determination_t1), .(sam_name, screen_ein, screen_via)], 10))
