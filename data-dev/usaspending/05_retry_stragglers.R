suppressMessages({library(httr2); library(data.table)})
OUT <- "C:/Users/jdlec/Dropbox/00 - URBAN/00-GITHUB/npmatch/data-dev/usaspending"
NM  <- c("contracts","grants","idvs","direct_payments","loans","other")
out <- fread(file.path(OUT, "UEI-AWARD-COUNTS.csv"))
bad <- out[err == TRUE]$uei
cat("stragglers:", length(bad), "\n")
print(table(substr(out[err==TRUE]$msg, 1, 60)))

one <- function(uei) {
  body <- list(filters=list(recipient_search_text=I(uei),
               time_period=list(list(start_date="2007-10-01", end_date="2025-09-30"))), subawards=FALSE)
  r <- try(request("https://api.usaspending.gov/api/v2/search/spending_by_award_count/") |>
    req_body_json(body) |> req_throttle(rate=1) |>
    req_retry(max_tries=8, backoff=~ 5 * 2^.x) |> req_timeout(180) |>
    req_perform() |> resp_body_json(), silent=TRUE)
  if (inherits(r,"try-error")) return(data.table(uei=uei, err=TRUE, msg=conditionMessage(attr(r,"condition"))))
  data.table(uei=uei, err=FALSE, msg=NA_character_, as.data.table(r$results))
}
if (length(bad)) {
  fix <- rbindlist(lapply(bad, one), fill=TRUE)
  for (k in NM) if (!k %in% names(fix)) fix[, (k) := NA_integer_]
  fix[, n_awards := rowSums(.SD, na.rm=TRUE), .SDcols=NM]
  fix[err == TRUE, n_awards := NA_real_]
  out <- rbind(out[err == FALSE], fix, fill=TRUE)
  fwrite(out, file.path(OUT, "UEI-AWARD-COUNTS.csv"))
}

pl  <- fread(file.path(OUT,"TOP1000-UEI-PULLLIST-2025NOV.csv"), colClasses=list(character="ein"))
pl  <- merge(pl, out[, c("uei","err","n_awards",NM), with=FALSE], by="uei", all.x=TRUE)
org <- pl[, .(n_uei=.N, n_uei_err=sum(err), n_awards=sum(n_awards, na.rm=TRUE),
              grants=sum(grants,na.rm=TRUE), contracts=sum(contracts,na.rm=TRUE),
              rank=rank[1], revenue_amount=revenue_amount[1],
              org=org_name_display[1], source=source[1]), by=ein]
fwrite(org[order(rank)], file.path(OUT,"ORG-AWARD-COUNTS.csv"))

cat("\n=== final coverage ===\n")
cat("unresolved UEIs      :", sum(out$err), "/", nrow(out), "\n")
cat("ORGS with >0 awards  :", sum(org$n_awards > 0), "/", nrow(org), "\n")
cat("ORGS at 0 awards     :", sum(org$n_awards == 0), "\n")
cat("  of which fully resolved (clean zeros):", org[n_awards == 0 & n_uei_err == 0, .N], "\n")
cat("  of which have an unresolved UEI      :", org[n_awards == 0 & n_uei_err > 0, .N], "\n")
cat("total awards         :", sum(out$n_awards, na.rm=TRUE), "\n")
cat("\nhit rate by match source (clean orgs only):\n")
print(org[n_uei_err == 0, .(orgs=.N, with_awards=sum(n_awards>0), pct=round(100*mean(n_awards>0),1)), by=source])
cat("\nzero-award orgs, top 15 by revenue:\n")
print(org[n_awards == 0 & n_uei_err == 0][order(rank)][1:15, .(rank, ein, org, revenue_amount, source)])
