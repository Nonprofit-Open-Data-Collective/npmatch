suppressMessages(library(data.table))
base <- "C:/Users/jdlec/Dropbox/00 - URBAN/00-GITHUB/npmatch"
allv <- readRDS(file.path(base,"data-dev/RESIDUAL-260-FINAL.rds")); setDT(allv)
rg <- fread(file=file.path(base,"data-dev/RANDOM-GROUNDTRUTH.csv"), colClasses="character")
hg <- fread(file=file.path(base,"data-dev/HARD-GROUNDTRUTH.csv"), colClasses="character")
nod <- function(x) gsub("[^0-9]","",x)
# candidate pairs from both runs
rr <- as.data.table(readRDS(file.path(base,"data-dev/RES-1K-RANDOM.rds")))
pr <- as.data.table(attr(rr,"pairs"))
r2 <- as.data.table(readRDS(file.path(base,"data-dev/RES-2K.rds")))
p2 <- as.data.table(attr(r2,"pairs"))
cand <- rbind(pr[, .(uei=.id, ein=nod(.ein))], p2[, .(uei=.id, ein=nod(.ein))])
setkey(cand, uei, ein)

# tier per uei
tier <- rbind(rg[, .(uei, tier=algo_tier)], hg[, .(uei, tier=algo_tier)])[!duplicated(uei)]
m <- allv[determination=="match" & bmf_status=="active", .(uei, e=nod(ein_found))]
m <- merge(m, tier, by="uei", all.x=TRUE)
m[, surfaced := mapply(function(u,x) nrow(cand[.(u,x), nomatch=0L])>0, uei, e)]

cat("=== 41 active-BMF matches the algo failed to auto-accept ===\n")
cat("by algo tier x whether the true EIN was among the surfaced candidates:\n")
print(table(tier=m$tier, surfaced=ifelse(m$surfaced,"candidate","blocking_miss")))
cat(sprintf("\nBLOCKING MISSES (true EIN never a candidate - hard coverage failure): %d\n", sum(!m$surfaced)))
cat(sprintf("SURFACED as candidate but mis-tiered NO / not-auto-accepted:        %d\n", sum(m$surfaced)))
cat("\n-- interpretation --\n")
cat("MAYBE-tier + surfaced  = working as intended (sent to human/LLM review)\n")
cat("NO-tier or blocking    = genuine coverage failures the matcher must fix\n")
