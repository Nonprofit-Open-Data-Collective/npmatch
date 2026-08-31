#!/usr/bin/env Rscript
# Does the efile 990 header table give join keys the BMF doesn't?
# Test on the 213 confirmed matches: for each, is the EIN present in the 2023
# header, and would website / officer / domicile have CONFIRMED it independently?
suppressPackageStartupMessages({library(data.table)})

SCR <- "C:/Users/jdlec/AppData/Local/Temp/claude/C--Users-jdlec-Dropbox-00---URBAN-00-GITHUB-npmatch/8d457f05-c251-4620-a087-8660f4eedfde/scratchpad"
out <- "data-dev/no-research"

cols <- c("ORG_EIN","ORG_NAME_L1","ORG_NAME_L2","F9_00_ORG_NAME_DBA_L1",
          "F9_00_ORG_ADDR_CITY","F9_00_ORG_ADDR_STATE","F9_00_ORG_WEBSITE",
          "F9_00_PRIN_OFF_NAME_PERS","F9_00_YEAR_FORMATION","F9_00_LEGAL_DMCL_STATE",
          "F9_00_ORG_NAME_CHANGE_X","TAX_YEAR")
e <- fread(file.path(SCR, "efile-2023.csv"), select = cols, colClasses = "character",
           showProgress = FALSE)
cat("efile 2023 rows:", format(nrow(e), big.mark = ","), "\n")
e[, ein := sub("^([0-9]{2})([0-9]{7})$", "\\1-\\2", sprintf("%09s", ORG_EIN))]
e[, ein := gsub(" ", "0", ein)]

cat("\n=== field fill rates in the header ===\n")
for (f in c("F9_00_ORG_WEBSITE","F9_00_PRIN_OFF_NAME_PERS","F9_00_ORG_NAME_DBA_L1",
            "F9_00_YEAR_FORMATION","F9_00_LEGAL_DMCL_STATE","F9_00_ORG_NAME_CHANGE_X"))
  cat(sprintf("  %-28s %5.1f%%\n", f, 100*mean(!is.na(e[[f]]) & e[[f]] != "")))

## ---- our confirmed matches ----------------------------------------------
a <- rbindlist(list(fread(file.path(out,"FINDINGS-STAGE1-NO-500.csv"), colClasses="character"),
                    fread(file.path(out,"FINDINGS-STAGE2-NO-500.csv"), colClasses="character")))
m <- a[determination == "match" & ein_found != ""]
# sam_poc_last is not carried into the findings tables; take it from the seed
seed <- fread(file.path(out, "FINDINGS-SEED.csv"), colClasses = "character")
m <- merge(m, seed[, .(uei, sam_poc_last)], by = "uei", all.x = TRUE)
cat("\nconfirmed matches with an EIN:", nrow(m), "\n")

m <- merge(m, e[, .(ein, e_name = paste(ORG_NAME_L1, ORG_NAME_L2),
                    e_dba = F9_00_ORG_NAME_DBA_L1, e_city = F9_00_ORG_ADDR_CITY,
                    e_state = F9_00_ORG_ADDR_STATE, e_web = F9_00_ORG_WEBSITE,
                    e_off = F9_00_PRIN_OFF_NAME_PERS, e_dmcl = F9_00_LEGAL_DMCL_STATE)],
           by.x = "ein_found", by.y = "ein", all.x = TRUE)
m <- unique(m, by = "uei")
cat("of those, present in the 2023 efile header:", sum(!is.na(m$e_name)),
    sprintf("(%.1f%%)\n", 100*mean(!is.na(m$e_name))))

## ---- would the website have confirmed it independently? -----------------
dom <- function(u) {
  u <- tolower(trimws(u)); u <- sub("^https?://", "", u); u <- sub("^www[0-9]?\\.", "", u)
  u <- sub("/.*$", "", u); u <- sub(":.*$", "", u); ifelse(u == "" | is.na(u), NA, u)
}
m[, sam_dom := dom(sam_url)]
m[, e_dom   := dom(e_web)]
both <- m[!is.na(sam_dom) & !is.na(e_dom)]
cat("\n=== website join ===\n")
cat("matches where BOTH sides carry a domain:", nrow(both), "\n")
cat("  domains agree exactly:", sum(both$sam_dom == both$e_dom),
    sprintf("(%.0f%% of those testable)\n", 100*mean(both$sam_dom == both$e_dom)))
if (nrow(both)) print(head(both[sam_dom == e_dom, .(sam_name = substr(sam_name,1,34),
                                                    ein_found, sam_dom)], 8))

## ---- officer-name overlap -----------------------------------------------
m[, off_hit := vapply(seq_len(.N), function(i) {
  pl <- sam_poc_last[i]; eo <- e_off[i]
  if (is.na(pl) || pl == "" || is.na(eo) || eo == "") return(NA)
  grepl(toupper(pl), toupper(eo), fixed = TRUE)
}, logical(1))]
cat("\n=== principal-officer join ===\n")
cat("testable:", sum(!is.na(m$off_hit)), " | SAM POC surname appears in efile officer:",
    sum(m$off_hit, na.rm = TRUE), "\n")

## ---- name-as-filed vs BMF name ------------------------------------------
cat("\n=== how many efile EINs are absent from our unified BMF? ===\n")
idx <- as.data.table(readRDS("data-dev/BMF-NAME-INDEX.rds"))
cat("efile 2023 distinct EINs:", format(uniqueN(e$ein), big.mark=","),
    " | not in unified BMF:", format(sum(!unique(e$ein) %chin% idx$ein), big.mark=","),
    sprintf(" (%.1f%%)\n", 100*mean(!unique(e$ein) %chin% idx$ein)))
