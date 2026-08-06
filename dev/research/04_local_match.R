suppressMessages({library(data.table); library(stringdist)})
base <- "C:/Users/jdlec/Dropbox/00 - URBAN/00-GITHUB/npmatch"
web <- fread(file.path(base,"data-dev/WEB-FINAL.csv"), colClasses="character")
idx <- readRDS(file.path(base,"data-dev/BMF-NAME-INDEX.rds")); setDT(idx)
clean <- function(x){ x<-toupper(as.character(x)); x[is.na(x)]<-""; trimws(gsub("\\s+"," ",gsub("[^A-Z0-9 ]"," ",gsub("&"," AND ",x,fixed=TRUE)))) }
stop <- c("THE","OF","AND","FOR","INC","INCORPORATED","A","AN","IN","TO","CO","COMPANY","CORP","CORPORATION","LLC","LTD","LP")
dtok <- function(s){ t<-setdiff(strsplit(s," ",fixed=TRUE)[[1]], c("",stop)); t[nchar(t)>=3] }
idx[, bnk := clean(name)][, padnk := paste0(" ",bnk," ")][, bcity := clean(city)]
setkey(idx, state)
# zip is not in WEB-FINAL; join it from the SAM sources
sam <- fread(file=file.path(base,"data-dev/SAMPLE-2K-NONPROFITS.CSV"), colClasses="character")
rnd <- fread(file=file.path(base,"data-dev/RANDOM-1K.csv"), colClasses="character")
for(d in list(sam,rnd)) setnames(d, names(d), gsub("^_|_$","",tolower(gsub("[^A-Za-z0-9]+","_",names(d)))))
zp <- unique(rbindlist(list(sam[,.(uei=unique_entity_id, zip=physical_address_zip_postal_code)],
                            rnd[,.(uei=unique_entity_id, zip=physical_address_zip_postal_code)])), by="uei")
web <- merge(web, zp, by="uei", all.x=TRUE)
web[, qn := clean(name)][, qcity := clean(city)][, qz := substr(zip,1,5)]

res <- vector("list", nrow(web))
tokcache <- new.env()
for(i in seq_len(nrow(web))){
  st <- web$state[i]; qt <- dtok(web$qn[i])
  if(is.na(st) || !nzchar(st) || length(qt)<1){ next }
  sub <- idx[.(st), nomatch=0L, .(ein,name,bnk,padnk,bcity,zip5,active)]
  if(!nrow(sub)) next
  shared <- Reduce(`+`, lapply(qt, function(t) grepl(paste0(" ",t," "), sub$padnk, fixed=TRUE)+0L))
  cov <- shared/length(qt)
  # candidate distinctive token count (for submatch detection)
  key <- st; ct <- tokcache[[key]]
  if(is.null(ct)){ ct <- vapply(sub$bnk, function(s) length(dtok(s)), integer(1)); tokcache[[key]] <- ct }
  full_submatch <- shared>=2 & shared==ct                 # all BMF distinctive tokens present in query
  addr <- (nzchar(web$qz[i]) & web$qz[i]==sub$zip5) | (nzchar(web$qcity[i]) & web$qcity[i]==sub$bcity)
  scorev <- cov + 0.25*addr + 0.15*full_submatch
  o <- which.max(scorev)
  res[[i]] <- data.table(uei=web$uei[i], set=web$set[i], algo_tier=web$algo_tier[i],
     name=web$name[i], state=st, cand_ein=sub$ein[o], cand_name=sub$name[o],
     shared=shared[o], nqt=length(qt), cov=round(cov[o],2), addr=addr[o],
     submatch=full_submatch[o], active=sub$active[o])
}
R <- rbindlist(res)
R[, klass := fifelse(shared>=2 & (cov>=0.6|submatch) & addr, "high",
             fifelse(shared>=2 & (cov>=0.75|submatch), "med", "none"))]
fwrite(R, file.path(base,"data-dev/LOCAL-MATCH2.csv"))
cat("=== token-coverage local match (same-state, submatch-aware) ===\n")
print(table(R$klass))
cat(sprintf("\nresolved high: %d | med: %d | none: %d (of %d web cases)\n",
    sum(R$klass=="high"), sum(R$klass=="med"), sum(R$klass=="none"), nrow(web)))
cat("\n--- HIGH (auto-accept) ---\n")
print(R[klass=="high", .(name=substr(name,1,30), cand=substr(cand_name,1,30), st=state, cov, sub=submatch, act=active)], row.names=FALSE)
cat("\n--- MED sample (verify) ---\n")
print(head(R[klass=="med", .(name=substr(name,1,30), cand=substr(cand_name,1,30), st=state, cov, sub=submatch, act=active)],25), row.names=FALSE)
