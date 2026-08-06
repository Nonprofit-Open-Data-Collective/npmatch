suppressMessages(library(data.table))
base <- "C:/Users/jdlec/Dropbox/00 - URBAN/00-GITHUB/npmatch"
res <- as.data.table(readRDS(file.path(base,"data-dev/RES-1K-RANDOM.rds"))); pairs <- as.data.table(attr(res,"pairs"))
ac <- intersect(c("street_key","city","zip5"), names(pairs))
am <- as.matrix(pairs[, ..ac]); pairs$addr_sim <- rowMeans(am, na.rm=TRUE); pairs$addr_sim[is.nan(pairs$addr_sim)] <- 0
yes <- res[tier=="YES", .id]
set.seed(7); samp <- sample(yes, 60)
pk <- merge(data.table(.id=samp, ein=res$overall_ein[match(samp,res$.id)]),
            pairs, by.x=c(".id","ein"), by.y=c(".id",".ein"))
pk[, `:=`(nm=round(name_key,2), ad=round(addr_sim,2), sc=round(score,3))]
# suspect if: weak name, no state confirmation, non-MAIN version, or affiliate-suffix in pick
aff <- grepl(" FOUNDATION$| ENDOWMENT$| AUXILIARY$| BOOSTERS?$", toupper(pk$name_y)) &
       !grepl("FOUNDATION|ENDOWMENT|AUXILIARY|BOOSTER", toupper(pk$name_x))
pk[, suspect := nm < 0.95 | geo_state==0 | !(name_ver_x %in% c("MAIN")) | aff]
cat(sprintf("QC of %d auto-accepted YES:\n  clean (name>=.95, same-state, MAIN, no affiliate): %d\n  SUSPECT (need eyeball): %d\n",
    nrow(pk), sum(!pk$suspect), sum(pk$suspect)))
cat(sprintf("  name_sim quantiles: %s\n", paste(round(quantile(pk$nm,c(0,.05,.25,.5)),2),collapse=" ")))
cat("\n=== SUSPECT YES picks (potential false positives) ===\n")
print(pk[suspect==TRUE, .(name_x=substr(name_x,1,34), pick=substr(name_y,1,34),
     nm, ad, sc, ver=name_ver_x, st=geo_state)], row.names=FALSE)
