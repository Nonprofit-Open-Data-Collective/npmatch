suppressMessages(library(data.table))
base <- "C:/Users/jdlec/Dropbox/00 - URBAN/00-GITHUB/npmatch"
rg <- fread(file.path(base,"data-dev/RANDOM-GROUNDTRUTH.csv"), colClasses="character")
hg <- fread(file.path(base,"data-dev/HARD-GROUNDTRUTH.csv"), colClasses="character")
sam <- fread(file.path(base,"data-dev/SAMPLE-2K-NONPROFITS.CSV"), colClasses="character")
setnames(sam, names(sam), gsub("^_|_$","",tolower(gsub("[^A-Za-z0-9]+","_",names(sam)))))
rnd <- fread(file.path(base,"data-dev/RANDOM-1K.csv"), colClasses="character")
setnames(rnd, names(rnd), gsub("^_|_$","",tolower(gsub("[^A-Za-z0-9]+","_",names(rnd)))))
done <- unique(fread(file.path(base,"data-dev/RESEARCH-SAMPLE-FINDINGS.csv"), fill=TRUE, colClasses="character")$uei)

unresolved <- function(d) d=="" | d=="pending" | grepl("cross_state|unverified|cant_determine", d)
cat("=== RANDOM gt_det ===\n"); print(sort(table(rg$gt_det), decreasing=TRUE))
cat("\n=== HARD gt_det ===\n"); print(sort(table(hg$gt_det), decreasing=TRUE))

info <- unique(rbindlist(list(
  sam[, .(uei=unique_entity_id, name=legal_business_name, dba=dba_name, divn=entity_division_name,
          city=physical_address_city, state=physical_address_province_or_state)],
  rnd[, .(uei=unique_entity_id, name=legal_business_name, dba=dba_name, divn=entity_division_name,
          city=physical_address_city, state=physical_address_province_or_state)]), use.names=TRUE), by="uei")

pend <- rbindlist(list(
  rg[unresolved(gt_det), .(uei, set="random", algo_tier, prior_det=gt_det)],
  hg[unresolved(gt_det), .(uei, set="hard",   algo_tier, prior_det=gt_det)]), use.names=TRUE)
pend <- pend[!uei %in% done]
pend <- merge(pend, info, by="uei", all.x=TRUE)
setorder(pend, set, algo_tier)
fwrite(pend, file.path(base,"data-dev/PENDING-RESEARCH.csv"))
cat(sprintf("\n=== UNRESOLVED needing Tier-2/3 (after removing %d already-researched) ===\n", length(done)))
cat(sprintf("TOTAL %d  | random %d | hard %d\n", nrow(pend), sum(pend$set=="random"), sum(pend$set=="hard")))
cat("\nby set x algo_tier:\n"); print(table(pend$set, pend$algo_tier))
cat("\nby prior determination state:\n"); print(table(pend$set, ifelse(pend$prior_det=="","(empty)",pend$prior_det)))
