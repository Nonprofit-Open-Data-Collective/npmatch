suppressMessages(library(data.table))
base <- "C:/Users/jdlec/Dropbox/00 - URBAN/00-GITHUB/npmatch"
pend <- fread(file.path(base,"data-dev/PENDING-RESEARCH.csv"), colClasses="character")
sam  <- fread(file.path(base,"data-dev/SAMPLE-2K-NONPROFITS.CSV"), colClasses="character")
rnd  <- fread(file.path(base,"data-dev/RANDOM-1K.csv"), colClasses="character")
for(d in list(sam,rnd)) setnames(d, names(d), gsub("^_|_$","",tolower(gsub("[^A-Za-z0-9]+","_",names(d)))))
est <- unique(rbindlist(list(sam[,.(uei=unique_entity_id, estruct=entity_structure, zip=physical_address_zip_postal_code)],
                             rnd[,.(uei=unique_entity_id, estruct=entity_structure, zip=physical_address_zip_postal_code)])), by="uei")
pend <- merge(pend, est, by="uei", all.x=TRUE)
clean <- function(x){ x<-toupper(as.character(x)); x[is.na(x)]<-""; trimws(gsub("\\s+"," ",gsub("[^A-Z0-9 ]"," ",gsub("&"," AND ",x,fixed=TRUE)))) }
N <- clean(pend$name)

gov <- grepl("(^| )(CITY|COUNTY|TOWN|VILLAGE|TOWNSHIP) OF ", N) |
       grepl("HOUSING AUTHORITY|SCHOOL DISTRICT|PUBLIC LIBRARY|BOARD OF EDUCATION|BOARD OF COUNTY|IRRIGATION DISTRICT|RECLAMATION DISTRICT|FIRE PROTECTION DISTRICT|COUNCIL OF GOVERNMENTS|MUNICIPAL (FACILITY|IMPROVEMENT|UTILIT)", N)
cu  <- grepl("CREDIT UNION$| CREDIT UNION ", N)
forp<- pend$estruct=="2L" | grepl(" (LLC|L L C|LP|L P|LLP|PLLC|LLLP)$", N) | grepl(" LIMITED PARTNERSHIP$", N)
pend[, triage_det := NA_character_]
pend[forp, triage_det := "not_a_nonprofit:for_profit"]
pend[cu,   triage_det := "nonprofit_not_in_bmf:credit_union"]
pend[gov,  triage_det := "not_a_nonprofit:government"]
pend[, needs_web := is.na(triage_det)]

## seed checkpoint file with structural determinations
seed <- pend[!is.na(triage_det), .(uei, set, algo_tier, name, state,
    ein_found="", determination=triage_det, confidence="high", resolving_tier="tier1",
    source="structural (name/legal-form)", notes="")]
fwrite(seed, file.path(base,"data-dev/TRAINING-RESEARCH.csv"))
## web worklist
web <- pend[needs_web==TRUE, .(uei, set, algo_tier, name, dba, divn, city, state, zip)]
setorder(web, set, -algo_tier)     # NO/ZERO first (highest FN value), then MAYBE
fwrite(web, file.path(base,"data-dev/TRIAGE-WEB.csv"))
cat(sprintf("structural auto-classified: %d\n", nrow(seed))); print(table(seed$determination))
cat(sprintf("\nneeds ProPublica web pass: %d\n", nrow(web)))
cat("by set x algo_tier:\n"); print(table(web$set, web$algo_tier))
