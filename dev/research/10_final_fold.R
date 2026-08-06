suppressMessages(library(data.table))
base <- "C:/Users/jdlec/Dropbox/00 - URBAN/00-GITHUB/npmatch"
v  <- fread(file=file.path(base,"data-dev/VERIFY-RESULTS.csv"), colClasses="character")
tr <- fread(file=file.path(base,"data-dev/TRAINING-RESEARCH.csv"), colClasses="character")
idx<- readRDS(file.path(base,"data-dev/BMF-NAME-INDEX.rds")); setDT(idx)
nod <- function(x) gsub("-","",x)
act_eins <- idx[active==TRUE, unique(ein)]; all_eins <- idx[, unique(ein)]

# combine firm-52 (non-pending from TRAINING-RESEARCH) + verified-208
firm <- tr[determination!="pending_web", .(uei, ein_found, determination, confidence)]
allv <- rbindlist(list(firm, v[, .(uei, ein_found, determination, confidence)]))[!duplicated(uei)]
# classify EIN presence in BMF
allv[, e := nod(ein_found)]
allv[, in_active := determination=="match" & e %in% nod(act_eins)]
allv[, in_unified := determination=="match" & e %in% nod(all_eins)]
allv[determination=="match", bmf_status := fifelse(in_active,"active",fifelse(in_unified,"inactive_only","absent"))]

cat(sprintf("=== 260 residual: final determinations ===\n"))
print(sort(table(allv$determination), decreasing=TRUE))
cat(sprintf("\nof %d recovered-EIN matches, BMF presence:\n", sum(allv$determination=="match")))
print(table(allv[determination=="match", bmf_status]))

## fold into ground-truth files
foldin <- function(gtfile, algocol){
  gt <- fread(file=file.path(base,gtfile), colClasses="character")
  ke <- names(gt)[1]
  gt <- merge(gt, allv[, .(k=uei, d=determination, e2=ein_found, bs=bmf_status)], by.x=ke, by.y="k", all.x=TRUE)
  hit <- !is.na(gt$d)
  gt$gt_det[hit] <- sub(":.*","",gt$d[hit])
  gt$gt_ein[hit & gt$d=="match"] <- gt$e2[hit & gt$d=="match"]
  # FN = algo NO/MAYBE/ZERO_CAND & a match exists in the (active) BMF that algo missed
  algo <- gt[[algocol]]
  gt[, is_fn := algo %in% c("NO","MAYBE","ZERO_CAND") & d=="match" & bs %in% c("active")]
  gt[is.na(is_fn), is_fn := FALSE]
  gt$d<-NULL; gt$e2<-NULL; gt$bs<-NULL
  fwrite(gt, file=file.path(base,gtfile))
  gt
}
rg <- foldin("data-dev/RANDOM-GROUNDTRUTH.csv","algo_tier")
hg <- foldin("data-dev/HARD-GROUNDTRUTH.csv","algo_tier")

## overall FP/FN across the whole training set
# FN from residual (newly discovered active-BMF matches algo missed)
fn_rand <- sum(rg$is_fn==TRUE); fn_hard <- sum(hg$is_fn==TRUE)
cat(sprintf("\n=== FALSE NEGATIVES (active-BMF match existed, algo said NO/MAYBE/ZERO) ===\n"))
cat(sprintf("  random set: %d  | hard set: %d\n", fn_rand, fn_hard))
cat(sprintf("  (plus inactive-only recovered matches: %d — findable only vs the unified BMF)\n",
    sum(allv[determination=="match", bmf_status]=="inactive_only")))
cat(sprintf("  (plus 'absent' recovered EINs — real orgs whose EIN is not in BMF at all: %d)\n",
    sum(allv[determination=="match", bmf_status]=="absent")))
# residual still unresolved
cat(sprintf("\nstill cant_determine (escalation queue, mostly real orgs w/ EIN not surfaced): %d\n",
    sum(allv$determination=="cant_determine")))
saveRDS(allv, file.path(base,"data-dev/RESIDUAL-260-FINAL.rds"))
cat("\nsaved RESIDUAL-260-FINAL.rds\n")
