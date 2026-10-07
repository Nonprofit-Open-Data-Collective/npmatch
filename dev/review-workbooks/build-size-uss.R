# Total federal award obligations per UEI, from the USASpending annual archives.
# Written to size_uss.rds for theme-eval-frame.R to join on.
suppressMessages({ library(duckdb); library(data.table) })

P   <- "C:/Users/jdlec/Documents/USASPEND/NONPROFIT/raw_parquet"
OUT <- Sys.getenv("SIZE_USS_OUT",
        "C:/Users/jdlec/Dropbox/00 - URBAN/00-GITHUB/npmatch/data-dev/runs/COMBINED_RESULTS/size_uss.rds")
msg <- function(...) { cat(sprintf(...), "\n"); flush.console() }

con <- dbConnect(duckdb::duckdb())
on.exit(dbDisconnect(con, shutdown = TRUE))
dbExecute(con, "PRAGMA memory_limit='24GB'")
dbExecute(con, sprintf("PRAGMA temp_directory='%s'", tempdir()))

# Assistance and contracts have different schemas, so aggregate each separately
# on just the two columns we need, then combine.
agg_one <- function(pattern) {
  fs <- list.files(P, pattern = pattern, full.names = TRUE)
  msg("  %s: %d files", pattern, length(fs))
  glob <- paste0(sprintf("'%s'", gsub("\\\\", "/", fs)), collapse = ", ")
  # The archives drift: federal_action_obligation is DOUBLE in some years and
  # VARCHAR in others, so cast explicitly rather than letting COALESCE bind.
  q <- sprintf("SELECT CAST(recipient_uei AS VARCHAR) AS uei,
                       SUM(COALESCE(TRY_CAST(federal_action_obligation AS DOUBLE), 0)) AS oblig,
                       COUNT(*) AS n_txn,
                       MAX(TRY_CAST(action_date_fiscal_year AS INTEGER)) AS last_fy
                FROM read_parquet([%s], union_by_name=true)
                WHERE recipient_uei IS NOT NULL AND CAST(recipient_uei AS VARCHAR) <> ''
                GROUP BY 1", glob)
  as.data.table(dbGetQuery(con, q))
}

t0 <- Sys.time()
a <- agg_one("Assistance")
msg("  assistance: %d UEIs", nrow(a))
k <- agg_one("Contracts")
msg("  contracts : %d UEIs", nrow(k))

both <- rbind(a, k)[, .(size_uss = sum(oblig), n_txn = sum(n_txn),
                        last_fy = max(last_fy)), by = uei]
msg("combined: %d UEIs in %.1f min", nrow(both), as.numeric(difftime(Sys.time(), t0, units = "mins")))

msg("\ntotal obligations: $%s", format(round(sum(both$size_uss)), big.mark = ","))
msg("UEIs with positive total: %d | zero: %d | negative: %d",
    sum(both$size_uss > 0), sum(both$size_uss == 0), sum(both$size_uss < 0))
print(round(quantile(both$size_uss[both$size_uss > 0], c(.1,.25,.5,.75,.9,.99))))

# Coverage against the eval frame
ev <- fread("C:/Users/jdlec/Dropbox/00 - URBAN/00-GITHUB/npmatch/data-dev/runs/COMBINED_RESULTS/eval_frame_full.csv",
            select = c("uei", "final_outcome"), colClasses = "character", showProgress = FALSE)
u <- unique(ev, by = "uei")
msg("\neval frame UEIs: %d", nrow(u))
msg("  covered by USASpending: %d (%.1f%%)", sum(u$uei %in% both$uei),
    100 * sum(u$uei %in% both$uei) / nrow(u))
u[, has := uei %in% both$uei]
print(u[, .N, by = .(final_outcome, has)][order(final_outcome, has)])

saveRDS(both, OUT)
msg("\nwrote %s (%.1f MB)", OUT, file.size(OUT) / 1e6)
print(head(both[order(-size_uss)], 8))
