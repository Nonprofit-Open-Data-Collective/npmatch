suppressMessages(library(data.table))
base <- "C:/Users/jdlec/Dropbox/00 - URBAN/00-GITHUB/npmatch"
w  <- fread(file=file.path(base,"data-dev/VERIFY-WORKLIST.csv"), colClasses="character")
rf <- file.path(base,"data-dev/VERIFY-RESULTS.csv")
prev <- if(file.exists(rf)) fread(file=rf, colClasses="character") else data.table()

# batch results: worklist row index -> determination. EDIT `b` each batch.
b <- data.table(
 idx = 191:208,
 ein_found = c("","13-3593039","38-3264730","54-2052107","","","","22-2868942","","",
               "","","99-0890106","","30-0108124","","","93-1749650"),
 determination = c("cant_determine","match","match","match","cant_determine","nonprofit_not_in_bmf",
                   "cant_determine","match","cant_determine","nonprofit_not_in_bmf","nonprofit_not_in_bmf",
                   "nonprofit_not_in_bmf","match","cant_determine","match","cant_determine","cant_determine","match"),
 confidence = c("low","high","high","high","low","high","low","high","low","med","high","med","med","low","high","low","low","high"),
 notes = c("'Opportunity for All Inc' not found (Opportunity Network is a diff org)",
   "Global Network for Energy & Environment Inc EIN 13-3593039 = FALSE NEGATIVE",
   "Gardena Marine Ave Senior Housing Inc (HUD 202) EIN 38-3264730 = FALSE NEGATIVE",
   "Edward Via Virginia College of Osteopathic Medicine (VCOM-Auburn) EIN 54-2052107 = FALSE NEGATIVE",
   "Gardena South Park Senior Project = HUD senior housing nonprofit; exact EIN uncertain (sibling Gardena Sr Hsg=95-4109165) - escalate",
   "foreign (Bangalore, India)",
   "'Surgical Systems Research Group' not found; possibly for-profit/defunct",
   "TeX Users Group (TUG) educational nonprofit EIN 22-2868942 = FALSE NEGATIVE",
   "Salvation Army Morehead City corps = federated territorial EIN",
   "Holy Name of Jesus School = Catholic school (Diocese of Orlando group ruling)",
   "foreign (Abuja, Nigeria - Neem Foundation)",
   "PR church (Iglesia de Hoy, Carolina PR)",
   "Center for Economic Recovery US-registered entity EIN 99-0890106 (Ukraine-focused) = FALSE NEGATIVE",
   "Community Integrated Services = real DE 501c3 (disability employment, est 2001), likely FN; EIN not surfaced - escalate",
   "Equality Community Housing Corporation EIN 30-0108124 = FALSE NEGATIVE",
   "Berean Christian Academy = real private Christian school (40+ yrs), likely FN; EIN not surfaced - escalate",
   "Salvation Army Lakeland corps = federated territorial EIN",
   "Data Institute of Delaware Inc EIN 93-1749650 = FALSE NEGATIVE"))
b <- merge(b, w[, .(idx=.I, uei, name)], by="idx")
b[, `:=`(source="websearch", resolving_tier="tier3_web")]
out <- b[, .(uei, name, ein_found, determination, confidence, source, notes)]
res <- rbindlist(list(prev, out), use.names=TRUE, fill=TRUE)[!duplicated(uei, fromLast=TRUE)]
fwrite(res, file=rf)
cat(sprintf("appended %d; VERIFY-RESULTS now %d / 208\n", nrow(out), nrow(res)))
cat(sprintf("  false-negatives recovered this batch: %d | not_a_nonprofit: %d | not_in_bmf: %d | cant_determine: %d\n",
    sum(out$determination=="match" & b$notes %like% "FALSE NEGATIVE"),
    sum(out$determination=="not_a_nonprofit"), sum(out$determination=="nonprofit_not_in_bmf"),
    sum(out$determination=="cant_determine")))
