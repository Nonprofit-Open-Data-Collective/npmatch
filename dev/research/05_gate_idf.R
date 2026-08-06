suppressMessages(library(data.table))
base <- "C:/Users/jdlec/Dropbox/00 - URBAN/00-GITHUB/npmatch"
R  <- fread(file=file.path(base,"data-dev/LOCAL-MATCH2.csv"))
ti <- readRDS(file.path(base,"data-dev/TOKEN-IDF.rds"))
clean <- function(x){ x<-toupper(as.character(x)); x[is.na(x)]<-""; trimws(gsub("\\s+"," ",gsub("[^A-Z0-9 ]"," ",gsub("&"," AND ",x,fixed=TRUE)))) }
info <- function(s){ t<-strsplit(clean(s)," ",fixed=TRUE)[[1]]; t<-t[t!=""]; t[!is.na(ti[t])] }  # tokens present in IDF map
idf <- function(t) { v<-ti[t]; v[is.na(v)]<-0; as.numeric(v) }

dec <- lapply(seq_len(nrow(R)), function(i){
  qt <- unique(info(R$name[i])); ct <- unique(info(R$cand_name[i]))
  sh <- intersect(qt, ct)
  qtop <- if(length(qt)) qt[which.max(idf(qt))] else NA_character_
  contain <- length(ct)>0 && all(ct %in% qt)            # BMF name's informative tokens all inside query
  data.table(sh_idf=round(sum(idf(sh)),1), cand_idf=round(sum(idf(ct)),1),
     qtop=qtop, qtop_sh=qtop %in% sh, contain=contain, nsh=length(sh))
})
R <- cbind(R, rbindlist(dec))
# acceptance: containment of a distinctive BMF name, OR query signature-token shared with strong shared IDF
R[, accept := (contain & cand_idf>=8) | (qtop_sh & sh_idf>=9)]
fwrite(R, file=file.path(base,"data-dev/GATE-IDF.csv"))
cat(sprintf("ACCEPT (idf-gated match): %d  | reject: %d  (of %d local candidates)\n",
    sum(R$accept), sum(!R$accept), nrow(R)))
a <- R[R$accept==TRUE, ]
cat("\n=== ACCEPTED (distinctive-token matches) ===\n")
print(data.frame(nm=substr(a$name,1,30), cand=substr(a$cand_name,1,30), sh_idf=a$sh_idf,
   contain=a$contain, act=a$active), row.names=FALSE)
r <- R[R$accept==FALSE & R$klass %in% c("high","med"), ]
cat(sprintf("\n=== REJECTED but had high/med token-cov (should be FPs) [%d] ===\n", nrow(r)))
print(data.frame(nm=substr(r$name,1,30), cand=substr(r$cand_name,1,30), sh_idf=r$sh_idf,
   qtop=r$qtop, qtop_sh=r$qtop_sh), row.names=FALSE)
