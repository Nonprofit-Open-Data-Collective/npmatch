suppressMessages({library(data.table); library(DBI); library(duckdb)})
setwd("C:/Users/jdlec/Dropbox/00 - URBAN/00-GITHUB/npmatch")
SCR <- "C:/Users/jdlec/AppData/Local/Temp/claude/C--Users-jdlec-Dropbox-00---URBAN-00-GITHUB-npmatch/bbab77f1-2aa8-4172-aa8c-d9628a0c35cf/scratchpad"
OUT <- "data-dev/usaspending"
dir.create(OUT, showWarnings=FALSE, recursive=TRUE)

cw <- fread("data-dev/run-2025NOV/CROSSWALK-AUGMENTED-2025NOV.csv",
            colClasses="character", na.strings=c("","NA"))

con <- dbConnect(duckdb::duckdb())
bmf <- as.data.table(dbGetQuery(con, sprintf(
  "SELECT ein, org_name_display, org_addr_state, nteev2, status_code,
          revenue_amount, asset_amount, bmf_vintage_ym, last_year_in_bmf
   FROM read_parquet('%s/bmf_rev.parquet')", SCR)))
dbDisconnect(con, shutdown=TRUE)

setkey(bmf, ein)
cw <- merge(cw, bmf, by="ein", all.x=TRUE, sort=FALSE)
cat("crosswalk rows with BMF hit:", sum(!is.na(cw$org_name_display)), "/", nrow(cw), "\n")
cat("rows with non-missing revenue:", sum(!is.na(cw$revenue_amount)), "\n")
cat("rows with revenue > 0      :", sum(cw$revenue_amount > 0, na.rm=TRUE), "\n")

# ---- org level (EIN) -------------------------------------------------------
cw[, score := as.numeric(score)]
setorder(cw, ein, -score, uei)
org <- cw[, .(
  n_uei      = .N,
  uei        = uei[1],                       # primary = best-scoring UEI
  uei_all    = paste(sort(uei), collapse="|"),
  name_uss   = name_uss[1],
  name_bmf   = name_bmf[1],
  score      = score[1],
  source     = source[1],
  revenue_amount = revenue_amount[1],
  asset_amount   = asset_amount[1],
  org_name_display = org_name_display[1],
  state      = org_addr_state[1],
  nteev2     = nteev2[1],
  status_code= status_code[1],
  bmf_vintage_ym = bmf_vintage_ym[1]
), by=ein]

cat("distinct orgs (EIN):", nrow(org), "\n")

setorder(org, -revenue_amount, ein)
top <- head(org[!is.na(revenue_amount) & revenue_amount > 0], 1000)
top[, rank := .I]
setcolorder(top, c("rank","ein","uei","n_uei","revenue_amount","asset_amount",
                   "org_name_display","name_uss","name_bmf","state","nteev2",
                   "status_code","score","source","bmf_vintage_ym","uei_all"))

fwrite(top, file.path(OUT, "TOP1000-REVENUE-2025NOV.csv"))

# UEI-level pull list (includes secondary UEIs of the same org)
uei_list <- cw[ein %in% top$ein, .(ein, uei, name_uss, name_bmf, score, source)]
uei_list <- merge(uei_list, top[, .(ein, rank, revenue_amount, org_name_display)], by="ein")
setorder(uei_list, rank, -score)
fwrite(uei_list, file.path(OUT, "TOP1000-UEI-PULLLIST-2025NOV.csv"))
writeLines(unique(uei_list$uei), file.path(OUT, "TOP1000-UEIS.txt"))

cat("\n--- top 1000 summary ---\n")
cat("orgs:", nrow(top), " ueis:", uniqueN(uei_list$uei), "\n")
cat("revenue range: ", format(min(top$revenue_amount), big.mark=","), " to ",
    format(max(top$revenue_amount), big.mark=","), "\n", sep="")
cat("total revenue: $", format(sum(as.numeric(top$revenue_amount)), big.mark=","), "\n", sep="")
print(top[, .N, by=source])
print(head(top[, .(rank, ein, uei, revenue_amount, org_name_display, state, nteev2, score)], 25))
print(top[, .N, by=substr(nteev2,1,3)][order(-N)][1:12])
cat("\nwrote:", file.path(OUT,"TOP1000-REVENUE-2025NOV.csv"), "\n")
