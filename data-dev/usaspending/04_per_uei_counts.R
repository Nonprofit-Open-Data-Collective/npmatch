# Per-UEI award counts for the top-1000 sample.
# Throttled: USAspending rate-limits sustained single-recipient calls.
suppressMessages({library(httr2); library(data.table)})
OUT <- "C:/Users/jdlec/Dropbox/00 - URBAN/00-GITHUB/npmatch/data-dev/usaspending"
u   <- readLines(file.path(OUT, "TOP1000-UEIS.txt"))
NM  <- c("contracts","grants","idvs","direct_payments","loans","other")

one <- function(uei) {
  body <- list(filters=list(recipient_search_text=I(uei),
               time_period=list(list(start_date="2007-10-01", end_date="2025-09-30"))),
               subawards=FALSE)
  r <- try(request("https://api.usaspending.gov/api/v2/search/spending_by_award_count/") |>
    req_body_json(body) |>
    req_throttle(rate = 2) |>                          # httr2 1.1.0 signature: 2 req/s
    req_retry(max_tries=6, backoff=~ 3 * 2^.x) |>
    req_timeout(120) |> req_perform() |> resp_body_json(), silent=TRUE)
  if (inherits(r, "try-error"))
    return(data.table(uei=uei, err=TRUE, msg=conditionMessage(attr(r, "condition"))))
  data.table(uei=uei, err=FALSE, msg=NA_character_, as.data.table(r$results))
}

t0 <- Sys.time(); res <- vector("list", length(u))
for (i in seq_along(u)) {
  res[[i]] <- one(u[i])
  if (i == 1 && res[[1]]$err) stop("first request failed: ", res[[1]]$msg)   # fail fast
  if (i %% 200 == 0) cat(i, "/", length(u), round(difftime(Sys.time(), t0, units="mins"),1), "min\n")
}
out <- rbindlist(res, fill=TRUE)

bad <- out[err == TRUE]$uei
if (length(bad)) {
  cat("retrying", length(bad), "failures\n")
  fix <- rbindlist(lapply(bad, function(x) { Sys.sleep(1); one(x) }), fill=TRUE)
  out <- rbind(out[err == FALSE], fix, fill=TRUE)
}

for (k in NM) if (!k %in% names(out)) out[, (k) := NA_integer_]
out[, n_awards := rowSums(.SD, na.rm=TRUE), .SDcols=NM]
out[err == TRUE, n_awards := NA_real_]          # never let a failure read as a zero
fwrite(out, file.path(OUT, "UEI-AWARD-COUNTS.csv"))

pl  <- fread(file.path(OUT, "TOP1000-UEI-PULLLIST-2025NOV.csv"), colClasses=list(character="ein"))
pl  <- merge(pl, out[, c("uei","err","n_awards",NM), with=FALSE], by="uei", all.x=TRUE)
org <- pl[, .(n_uei=.N, n_uei_err=sum(err), n_awards=sum(n_awards, na.rm=TRUE),
              grants=sum(grants, na.rm=TRUE), contracts=sum(contracts, na.rm=TRUE),
              rank=rank[1], revenue_amount=revenue_amount[1],
              org=org_name_display[1], source=source[1]), by=ein]
fwrite(org[order(rank)], file.path(OUT, "ORG-AWARD-COUNTS.csv"))

cat("\n=== coverage ===\n")
cat("UEI request failures :", sum(out$err), "/", nrow(out), "\n")
cat("UEIs with >0 awards  :", sum(out$n_awards > 0, na.rm=TRUE), "of", sum(!out$err), "resolved\n")
cat("ORGS with >0 awards  :", sum(org$n_awards > 0), "/", nrow(org), "\n")
cat("total awards         :", sum(out$n_awards, na.rm=TRUE), "\n")
cat("\nhit rate by match source:\n")
print(org[, .(orgs=.N, with_awards=sum(n_awards > 0),
              pct=round(100*mean(n_awards > 0),1)), by=source])
cat("\nawards per org:\n"); print(quantile(org$n_awards, c(0,.25,.5,.75,.9,.99,1)))
cat("wall:", round(difftime(Sys.time(), t0, units="mins"),1), "min\n")
