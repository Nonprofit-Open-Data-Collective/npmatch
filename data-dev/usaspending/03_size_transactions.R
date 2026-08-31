suppressMessages({library(httr2); library(data.table)})
u <- readLines("C:/Users/jdlec/Dropbox/00 - URBAN/00-GITHUB/npmatch/data-dev/usaspending/TOP1000-UEIS.txt")
B <- split(u, ceiling(seq_along(u)/20))
res <- vector("list", length(B)); t0 <- Sys.time()
for (i in seq_along(B)) {
  body <- list(filters=list(recipient_search_text=I(B[[i]]),
               time_period=list(list(start_date="2007-10-01", end_date="2025-09-30"))))
  r <- try(request("https://api.usaspending.gov/api/v2/search/spending_by_transaction_count/") |>
    req_body_json(body) |> req_retry(max_tries=4, backoff=~2) |> req_timeout(120) |>
    req_perform() |> resp_body_json(), silent=TRUE)
  if (inherits(r,"try-error")) { if (i==1) cat(as.character(r), "\n"); res[[i]] <- data.table(batch=i, err=TRUE); next }
  res[[i]] <- data.table(batch=i, err=FALSE, as.data.table(r$results))
}
out <- rbindlist(res, fill=TRUE)
fwrite(out, "TX-COUNTS-BY-BATCH.csv")
cat("failed:", sum(out$err), "\n")
nm <- setdiff(names(out), c("batch","err"))
print(out[err==FALSE, lapply(.SD, sum), .SDcols=nm])
cat("total transactions:", sum(unlist(out[err==FALSE, ..nm])), "\n")
cat("wall:", round(difftime(Sys.time(), t0, units="mins"),1), "min\n")
