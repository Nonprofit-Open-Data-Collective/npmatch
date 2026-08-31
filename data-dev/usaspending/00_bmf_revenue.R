suppressMessages({library(DBI); library(duckdb)})
bmf <- "C:/Users/jdlec/Dropbox/00 - URBAN/00-GITHUB/npmatch/data-raw/bmf_unified_geocoded_2026-08-20.csv"
con <- dbConnect(duckdb::duckdb())
dbExecute(con, "SET memory_limit='12GB'")
dbExecute(con, "SET preserve_insertion_order=false")
q <- sprintf("SELECT ein, org_name_display, org_addr_state, nteev2, status_code,
                     TRY_CAST(revenue_amount AS BIGINT) AS revenue_amount,
                     TRY_CAST(asset_amount AS BIGINT)   AS asset_amount,
                     bmf_vintage_ym, last_year_in_bmf, bmf_vintages_observed
              FROM read_csv('%s', header=true, all_varchar=true)", bmf)
dbExecute(con, paste0("CREATE TABLE bmf AS ", q))
print(dbGetQuery(con, "SELECT count(*) AS n_rows, count(DISTINCT ein) AS n_ein FROM bmf"))
print(dbGetQuery(con, "SELECT bmf_vintage_ym, count(*) n FROM bmf GROUP BY 1 ORDER BY 1 DESC LIMIT 15"))
print(dbGetQuery(con, "SELECT count(*) n FROM bmf WHERE revenue_amount IS NULL"))
dbExecute(con, "COPY (SELECT * FROM bmf) TO 'C:/Users/jdlec/AppData/Local/Temp/claude/C--Users-jdlec-Dropbox-00---URBAN-00-GITHUB-npmatch/bbab77f1-2aa8-4172-aa8c-d9628a0c35cf/scratchpad/bmf_rev.parquet' (FORMAT PARQUET)")
cat("DONE\n")
