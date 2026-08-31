# Assemble the org x fiscal-year panel from downloaded prime transactions.
# Grain: EIN x action_date_fiscal_year. UEIs roll up to EIN via the pull list.
suppressMessages({library(DBI); library(duckdb); library(data.table)})
OUT <- "C:/Users/jdlec/Dropbox/00 - URBAN/00-GITHUB/npmatch/data-dev/usaspending"
PIL <- file.path(OUT, "pilot"); RAW <- file.path(PIL, "raw")

tx <- list.files(RAW, pattern="PrimeTransactions.*[.]csv$", full.names=TRUE)
sb <- list.files(RAW, pattern="Subawards.*[.]csv$",        full.names=TRUE)
stopifnot(length(tx) > 0)
cat("prime transaction files:", length(tx), " subaward files:", length(sb), "\n")

con <- dbConnect(duckdb::duckdb()); dbExecute(con, "SET memory_limit='12GB'")
gl  <- function(v) paste0("['", paste(gsub("\\\\","/",v), collapse="','"), "']")

dbExecute(con, sprintf("CREATE VIEW tx_raw AS SELECT * FROM read_csv(%s,
  header=true, all_varchar=true, union_by_name=true, filename=true)", gl(tx)))

cat("\ncolumns present across transaction files:\n")
have <- dbGetQuery(con, "SELECT column_name FROM (DESCRIBE tx_raw)")$column_name
print(intersect(c("recipient_uei","action_date","action_date_fiscal_year",
                  "federal_action_obligation","awarding_agency_name",
                  "assistance_type_code","award_type_code","cfda_number"), have))

dbExecute(con, "CREATE TABLE tx AS
  SELECT upper(trim(recipient_uei))                       AS uei,
         TRY_CAST(action_date_fiscal_year AS INTEGER)     AS fy,
         TRY_CAST(federal_action_obligation AS DOUBLE)    AS oblig,
         awarding_agency_name                             AS agency,
         CASE WHEN filename ILIKE '%Contracts%'  THEN 'contract'
              WHEN filename ILIKE '%Assistance%' THEN 'assistance'
              ELSE 'other' END                            AS family
  FROM tx_raw
  WHERE recipient_uei IS NOT NULL")

cat("\ntransactions loaded:", dbGetQuery(con,"SELECT count(*) n FROM tx")$n, "\n")
print(dbGetQuery(con, "SELECT family, count(*) n, round(sum(oblig)/1e9,2) AS oblig_bn FROM tx GROUP BY 1 ORDER BY 2 DESC"))
print(dbGetQuery(con, "SELECT count(*) AS negative_transactions FROM tx WHERE oblig < 0"))

# ---- roll UEI -> EIN ----
pull <- fread(file.path(PIL,"PILOT-UEI-PULLLIST.csv"), colClasses=list(character="ein"))
dbWriteTable(con, "xw", pull[, .(uei=toupper(trimws(uei)), ein, rank, revenue_amount,
                                 org=org_name_display, source)])

# recipient_search_text is an ANALYSED TEXT match, not an exact UEI lookup: the
# server returns neighbouring recipients too. Everything downstream must filter
# on an exact UEI join, and any count taken straight from the API (award_count,
# transaction_count) is inflated by the same strays.
stray <- as.data.table(dbGetQuery(con, "
  SELECT uei, count(*) AS n, sum(oblig) AS oblig
  FROM tx WHERE uei NOT IN (SELECT uei FROM xw) GROUP BY 1 ORDER BY 2 DESC"))
kept  <- dbGetQuery(con, "SELECT count(*) n FROM tx WHERE uei IN (SELECT uei FROM xw)")$n
cat("\n--- stray-recipient contamination ---\n")
cat("stray UEIs :", nrow(stray), " transactions:", sum(stray$n),
    sprintf(" (%.1f%% of downloaded rows)\n", 100*sum(stray$n)/(sum(stray$n)+kept)))
cat("on-list    : ", kept, " transactions\n", sep="")
fwrite(stray, file.path(PIL, "STRAY-UEIS.csv"))
print(head(stray, 10))

# ---- panel: every org x every FY, zeros filled ----
dbExecute(con, "CREATE TABLE panel AS
WITH agg AS (
  SELECT x.ein, t.fy,
         sum(CASE WHEN t.family='assistance' THEN t.oblig ELSE 0 END) AS oblig_assistance,
         sum(CASE WHEN t.family='contract'   THEN t.oblig ELSE 0 END) AS oblig_contract,
         sum(t.oblig)                                                 AS oblig_total,
         count(*)                                                     AS n_transactions,
         count(DISTINCT t.agency)                                     AS n_agencies
  FROM tx t JOIN xw x USING (uei)
  WHERE t.fy BETWEEN 2008 AND 2025
  GROUP BY 1,2),
grid AS (SELECT DISTINCT x.ein, f.fy FROM xw x
         CROSS JOIN (SELECT unnest(generate_series(2008,2025)) AS fy) f)
SELECT g.ein, g.fy,
       coalesce(a.oblig_assistance,0) AS oblig_assistance,
       coalesce(a.oblig_contract,0)   AS oblig_contract,
       coalesce(a.oblig_total,0)      AS oblig_total,
       coalesce(a.n_transactions,0)   AS n_transactions,
       coalesce(a.n_agencies,0)       AS n_agencies
FROM grid g LEFT JOIN agg a ON a.ein=g.ein AND a.fy=g.fy")

# One row per EIN. An org's UEIs can carry different `source` values, so take the
# org's best-scoring row rather than unique()-ing across columns that disagree.
setorder(pull, ein, -score)
org <- pull[, .(rank=rank[1], revenue_amount=revenue_amount[1],
                org=org_name_display[1], source=source[1]), by=ein]
stopifnot(!anyDuplicated(org$ein))
panel <- as.data.table(dbGetQuery(con, "SELECT * FROM panel"))
panel <- merge(panel, org, by="ein")
setorder(panel, rank, fy)
setcolorder(panel, c("rank","ein","org","fy","oblig_total","oblig_assistance",
                     "oblig_contract","n_transactions","n_agencies",
                     "revenue_amount","source"))
fwrite(panel, file.path(PIL,"PANEL-PILOT.csv"))

cat("\n=== panel ===\n")
cat("rows:", nrow(panel), " orgs:", uniqueN(panel$ein), " years:", uniqueN(panel$fy), "\n")
cat("org-years with any obligation:", panel[n_transactions > 0, .N], "\n")
cat("orgs with zero across all years:", panel[, .(z=sum(n_transactions)), by=ein][z==0, .N], "\n")
print(panel[, .(oblig_bn=round(sum(oblig_total)/1e9,2), tx=sum(n_transactions)), by=fy][order(fy)])
cat("\ntop 10 org-years:\n")
print(head(panel[order(-oblig_total), .(rank, org, fy, oblig_total, n_transactions)], 10))
dbDisconnect(con, shutdown=TRUE)
cat("\nwrote:", file.path(PIL,"PANEL-PILOT.csv"), "\n")
