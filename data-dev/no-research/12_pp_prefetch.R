#!/usr/bin/env Rscript
# Tier-2 prefetch: resolve every queued org name against the ProPublica Nonprofit
# Explorer JSON API from ONE rate-limited, resumable process, and cache the answers
# so research agents never touch the network for Tier 2.
#
#   Rscript 12_pp_prefetch.R <queue.csv> [rate_per_sec]
#
# <queue.csv> needs columns: uei, sam_name.  Output: PP-CACHE.tsv (append-only).
suppressPackageStartupMessages({library(data.table); library(curl); library(jsonlite)})

args  <- commandArgs(trailingOnly = TRUE)
qfile <- if (length(args) >= 1) args[1] else "data-dev/no-research/FINDINGS-SEED.csv"
rate  <- if (length(args) >= 2) as.numeric(args[2]) else 2.5   # req/sec; 3/s measured clean
out   <- "data-dev/no-research"
cache <- file.path(out, "PP-CACHE.tsv")

STOP <- c("INC","INCORPORATED","CORP","CORPORATION","CO","COMPANY","LLC","LTD","THE","OF",
          "AND","FOR","A","AN","FOUNDATION","TRUST","FUND","ASSOCIATION","ASSOC","SOCIETY",
          "CENTER","CENTRE","INSTITUTE","COUNCIL","ORGANIZATION","ORG","GROUP","SERVICES",
          "SERVICE","PROJECT","PROGRAM","NONPROFIT","NON","PROFIT","USA","US","AMERICA",
          "AMERICAN","NATIONAL","INTERNATIONAL","COMMUNITY")

# ProPublica returns 0 for long multi-word queries: keep the distinctive head of the name.
distinctive <- function(nm) {
  x <- toupper(gsub("[^A-Za-z0-9 ]", " ", nm))
  w <- setdiff(strsplit(trimws(gsub(" +", " ", x)), " ")[[1]], STOP)
  if (!length(w)) w <- strsplit(trimws(gsub(" +", " ", x)), " ")[[1]]
  paste(head(w, 4), collapse = " ")
}

q <- fread(qfile, colClasses = "character")
stopifnot(all(c("uei", "sam_name") %in% names(q)))
q[, query := vapply(sam_name, distinctive, "")]
q <- unique(q[query != ""], by = "query")            # one network call per distinct query

done <- character(0)
if (file.exists(cache)) {
  done <- unique(fread(cache, sep = "\t", colClasses = "character", quote = "")$query)
  cat("cache already holds", length(done), "queries\n")
} else {
  writeLines(paste(c("query","http","total_results","results"), collapse = "\t"), cache)
}
todo <- q[!query %chin% done]
cat("queries to fetch:", nrow(todo), "at", rate, "req/s ->",
    sprintf("%.1f min\n", nrow(todo) / rate / 60))

esc <- function(s) URLencode(s, reserved = TRUE)
gap <- 1 / rate
con <- file(cache, open = "at", encoding = "UTF-8")
on.exit(close(con))

for (i in seq_len(nrow(todo))) {
  qq <- todo$query[i]
  url <- paste0("https://projects.propublica.org/nonprofits/api/v2/search.json?q=", esc(qq))
  t0 <- Sys.time()
  code <- NA_integer_; body <- ""
  for (attempt in 1:4) {
    r <- tryCatch(curl_fetch_memory(url, handle = new_handle(timeout = 25)),
                  error = function(e) NULL)
    if (is.null(r)) { Sys.sleep(2 * attempt); next }
    code <- r$status_code
    # the API answers 404 for a genuine zero-result query, and the body still
    # carries total_results:0 -- that is evidence, not a failure.
    if (code %in% c(200L, 404L)) { body <- rawToChar(r$content); break }
    if (code == 429) { Sys.sleep(5 * attempt); next }   # back off and retry
    break
  }
  tot <- ""; flat <- ""
  if (code %in% c(200L, 404L) && nzchar(body)) {
    j <- tryCatch(fromJSON(body, simplifyDataFrame = TRUE), error = function(e) NULL)
    if (!is.null(j)) {
      tot <- as.character(j$total_results)
      o <- j$organizations
      if (is.data.frame(o) && nrow(o)) {
        o <- head(o, 15)
        flat <- paste(sprintf("%s|%s|%s, %s|ntee=%s|sub=%s",
                              o$strein, o$name, o$city, o$state,
                              ifelse(is.null(o$ntee_code), "", o$ntee_code),
                              ifelse(is.null(o$subseccd), "", o$subseccd)),
                      collapse = " ;; ")
      }
    }
  }
  clean <- function(s) gsub("[\t\r\n]", " ", ifelse(is.na(s), "", s))
  writeLines(paste(c(clean(qq), clean(code), clean(tot), clean(flat)), collapse = "\t"), con)
  if (i %% 50 == 0) { flush(con); cat("  ", i, "/", nrow(todo), "\n") }
  el <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  if (el < gap) Sys.sleep(gap - el)
}
flush(con)
cat("done. cache rows:", length(readLines(cache)) - 1, "\n")
