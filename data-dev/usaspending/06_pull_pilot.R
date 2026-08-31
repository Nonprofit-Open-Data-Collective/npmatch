# Pilot pull: top-50 orgs by BMF revenue, all award families, FY2008-FY2025.
# Submits transaction-level download jobs, polls to a terminal state, fetches, unzips.
#
# Job state machine (measured): ready -> running -> finished | failed
# "ready" is a queue state; treating anything != "running" as terminal reads a
# freshly-queued job as done and throws the download away.
suppressMessages({library(httr2); library(data.table)})
OUT <- "C:/Users/jdlec/Dropbox/00 - URBAN/00-GITHUB/npmatch/data-dev/usaspending"
PIL <- file.path(OUT, "pilot"); ZIP <- file.path(PIL, "zips"); RAW <- file.path(PIL, "raw")
for (d in c(PIL, ZIP, RAW)) dir.create(d, showWarnings = FALSE, recursive = TRUE)

N_ORGS    <- 50
BATCH     <- 5      # UEIs per job; 20 fails outright and 10 stalls on the largest recipients
CONCURRENT<- 3      # jobs in flight at once
INFLIGHT  <- c("ready", "running")
TYPES <- c("02","03","04","05",                         # grants
           "A","B","C","D",                             # contracts
           "IDV_A","IDV_B","IDV_B_A","IDV_B_B","IDV_B_C","IDV_C","IDV_D","IDV_E",
           "06","10",                                   # direct payments
           "07","08",                                   # loans
           "09","11")                                   # other
TP <- list(list(start_date = "2007-10-01", end_date = "2025-09-30", date_type = "action_date"))

pull  <- fread(file.path(OUT, "TOP1000-UEI-PULLLIST-2025NOV.csv"), colClasses = list(character = "ein"))
pilot <- pull[rank <= N_ORGS]
fwrite(pilot, file.path(PIL, "PILOT-UEI-PULLLIST.csv"))
u <- unique(pilot$uei)
cat("pilot orgs:", uniqueN(pilot$ein), " ueis:", length(u), "\n")

submit <- function(ueis) {
  body <- list(filters = list(recipient_search_text = I(ueis),
                              award_type_codes = I(TYPES), time_period = TP),
               columns = I(character(0)), file_format = "csv")
  r <- try(request("https://api.usaspending.gov/api/v2/download/transactions/") |>
    req_body_json(body) |> req_retry(max_tries = 4, backoff = ~ 5 * 2^.x) |>
    req_timeout(180) |> req_perform() |> resp_body_json(), silent = TRUE)
  if (inherits(r, "try-error")) return(NA_character_)
  r$file_name
}

status <- function(fn) {
  r <- try(request("https://api.usaspending.gov/api/v2/download/status") |>
    req_url_query(file_name = fn) |> req_retry(max_tries = 4) |> req_timeout(120) |>
    req_perform() |> resp_body_json(), silent = TRUE)
  if (inherits(r, "try-error")) return(list(status = "running"))   # transient: keep waiting
  r
}

# Run a set of UEI batches to terminal state, at most CONCURRENT in flight.
run_batches <- function(B, tag) {
  jobs <- data.table(tag = tag, batch = seq_along(B), n_uei = lengths(B),
                     file_name = NA_character_, state = "queued",
                     rows = NA_integer_, url = NA_character_)
  t0 <- Sys.time()
  repeat {
    live <- jobs[state %in% INFLIGHT, .N]
    nxt  <- jobs[state == "queued", which = TRUE]
    while (live < CONCURRENT && length(nxt)) {
      i <- nxt[1]; nxt <- nxt[-1]
      fn <- submit(B[[jobs$batch[i]]])
      if (is.na(fn)) { jobs[i, state := "submit_failed"] } else {
        jobs[i, `:=`(file_name = fn, state = "ready")]; live <- live + 1
      }
      Sys.sleep(3)                                   # stagger submissions
    }
    for (i in jobs[state %in% INFLIGHT, which = TRUE]) {
      s <- status(jobs$file_name[i])
      jobs[i, state := s$status]
      if (identical(s$status, "finished")) jobs[i, `:=`(rows = s$total_rows, url = s$file_url)]
    }
    cat(format(Sys.time(), "%H:%M:%S"), tag, paste(jobs$state, collapse = " "), "\n")
    if (!nrow(jobs[state %in% c("queued", INFLIGHT)])) break
    if (difftime(Sys.time(), t0, units = "mins") > 90) { cat("timeout\n"); break }
    Sys.sleep(20)
  }
  jobs
}

B <- split(u, ceiling(seq_along(u) / BATCH))
cat("batches:", length(B), "of <=", BATCH, "UEIs\n")
jobs <- run_batches(B, "main")

# Retry failures one UEI at a time -- a single oversized recipient poisons its batch.
bad <- jobs[state != "finished"]
if (nrow(bad)) {
  singles <- unlist(B[bad$batch], use.names = FALSE)
  cat("\nretrying", length(singles), "UEIs from", nrow(bad), "failed batches, individually\n")
  jobs <- rbind(jobs, run_batches(as.list(singles), "retry"), fill = TRUE)
}
fwrite(jobs, file.path(PIL, "PILOT-JOBS.csv"))

ok <- jobs[state == "finished"]
cat("\nfinished:", nrow(ok), "jobs, rows:", sum(ok$rows, na.rm = TRUE), "\n")
if (nrow(jobs[state != "finished"])) print(jobs[state != "finished", .(tag, batch, n_uei, state)])

for (i in seq_len(nrow(ok))) {
  z <- file.path(ZIP, ok$file_name[i])
  if (!file.exists(z)) try(download.file(ok$url[i], z, mode = "wb", quiet = TRUE), silent = TRUE)
  if (file.exists(z)) try(unzip(z, exdir = RAW), silent = TRUE)
}
f <- list.files(RAW, pattern = "[.]csv$", full.names = TRUE)
cat("\nunzipped:", length(f), "csv files,", round(sum(file.size(f)) / 1e6, 1), "MB\n")
print(basename(f))
