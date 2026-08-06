suppressMessages(library(data.table))
base <- "C:/Users/jdlec/Dropbox/00 - URBAN/00-GITHUB/npmatch"
G   <- fread(file=file.path(base,"data-dev/GATE-IDF.csv"))
web <- fread(file=file.path(base,"data-dev/WEB-FINAL.csv"), colClasses="character")
# reload the firm structural/church/individual/fuzzy set (48) from TRIAGE + classify outputs is gone; rebuild from scratch seed:
seed <- fread(file=file.path(base,"data-dev/TRAINING-RESEARCH.csv"))            # current file has tr+matchA+prov(200); take only firm non-pending non-provisional
firm <- seed[!determination %in% c("pending_web") & source!="containment+address", ]   # structural/church/individual/fuzzy + propublica
firm <- firm[!duplicated(uei)]

# provisional: ALL web cases not firm -> record best local candidate (from GATE) if any, else no-candidate
gcand <- G[!duplicated(uei), .(uei, cand_ein, cand_name, contain, addr, active, accept)]
prov <- web[!uei %in% firm$uei, .(uei, set, algo_tier, name, state)]
prov <- merge(prov, gcand, by="uei", all.x=TRUE)
prov[, `:=`(ein_found="", determination="pending_web", confidence="low", resolving_tier="pending",
   source=fifelse(is.na(cand_ein),"no local candidate","best local candidate (unverified)"),
   notes=fifelse(is.na(cand_ein),"", sprintf("cand=%s ein=%s idfaccept=%s contain=%s addr=%s",
        substr(cand_name,1,26), cand_ein, accept, contain, addr)))]
prov <- prov[, .(uei,set,algo_tier,name,state,ein_found,determination,confidence,resolving_tier,source,notes)]
final <- rbindlist(list(firm, prov), use.names=TRUE, fill=TRUE)[!duplicated(uei)]
fwrite(final, file=file.path(base,"data-dev/TRAINING-RESEARCH.csv"))

## fold firm labels into ground-truth files, recompute FP/FN (pending excluded from denominators)
foldin <- function(gt, detcol, eincol){
  m <- final[determination!="pending_web", .(uei, d=determination, e=ein_found)]
  gt <- merge(gt, m, by.x=names(gt)[1], by.y="uei", all.x=TRUE)
  hit <- !is.na(gt$d)
  gt[[detcol]][hit] <- sub(":.*","",gt$d[hit])
  gt[[eincol]][hit & gt$d=="match"] <- gt$e[hit & gt$d=="match"]
  gt$d <- NULL; gt$e <- NULL; gt
}
rg <- fread(file=file.path(base,"data-dev/RANDOM-GROUNDTRUTH.csv"), colClasses="character")
hg <- fread(file=file.path(base,"data-dev/HARD-GROUNDTRUTH.csv"), colClasses="character")
rg <- foldin(rg, "gt_det", "gt_ein")
hg[, gt_det2 := gt_det]; hg <- foldin(hg, "gt_det2", "gt_ein")
fwrite(rg, file=file.path(base,"data-dev/RANDOM-GROUNDTRUTH.csv"))
fwrite(hg, file=file.path(base,"data-dev/HARD-GROUNDTRUTH.csv"))

cat("=== 260 unresolved -> medium-effort automated resolution ===\n")
cat(sprintf("FIRM labels (structural/church/individual/fuzzy+addr/ProPublica): %d\n", nrow(firm)))
print(sort(table(sub(":.*","",firm$determination)), decreasing=TRUE))
cat(sprintf("\nPROVISIONAL (need web verify): %d  [with local candidate: %d | no candidate: %d]\n",
    nrow(prov), sum(prov$source=="best local candidate (unverified)"), sum(prov$source=="no local candidate")))
np <- prov[grepl("candidate", source) & grepl("idfaccept=TRUE", notes)]
cat(sprintf("  of provisional, %d have an IDF-accepted candidate (best web-verify targets, mostly NO/ZERO tier)\n", nrow(np)))
print(table(prov$algo_tier))
cat(sprintf("\nFIRMLY LABELED share of 260: %d (%.0f%%) | pending: %d\n", nrow(firm), 100*nrow(firm)/260, nrow(prov)))
