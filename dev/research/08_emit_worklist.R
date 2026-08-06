suppressMessages(library(data.table))
base <- "C:/Users/jdlec/Dropbox/00 - URBAN/00-GITHUB/npmatch"
tr  <- fread(file=file.path(base,"data-dev/TRAINING-RESEARCH.csv"))
web <- fread(file=file.path(base,"data-dev/WEB-FINAL.csv"), colClasses="character")
p <- tr[tr$determination=="pending_web", ]
w <- merge(p[, .(uei, set, algo_tier, name, state, cand_hint=notes)],
           web[, .(uei, city)], by="uei", all.x=TRUE)
# order: NO & ZERO_CAND first (FN value), then MAYBE
w[, ord := fifelse(algo_tier %in% c("NO","ZERO_CAND"),0L,1L)]
setorder(w, ord, set)
w[, ord := NULL]
fwrite(w, file=file.path(base,"data-dev/VERIFY-WORKLIST.csv"))
# init results file if absent
rf <- file.path(base,"data-dev/VERIFY-RESULTS.csv")
if(!file.exists(rf)) fwrite(data.table(uei=character(),name=character(),ein_found=character(),
   determination=character(),confidence=character(),source=character(),notes=character()), file=rf)
cat(sprintf("worklist: %d cases (NO/ZERO first)\n", nrow(w)))
print(table(w$algo_tier))
cat("\n--- batch 1 (first 12) ---\n")
print(data.frame(n=1:12, name=substr(w$name[1:12],1,40), city=w$city[1:12], st=w$state[1:12]), row.names=FALSE)
