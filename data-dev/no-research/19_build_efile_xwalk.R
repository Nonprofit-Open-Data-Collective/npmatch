#!/usr/bin/env Rscript
# Build a slim, grep-able crosswalk from the NCCS efile 990 header tables.
# Two outputs:
#   EFILE-XWALK.tsv   one row per EIN, most recent filing, with join keys
#   EFILE-NAMES.tsv   every distinct (ein, name-as-filed) pair across years
#                     -- this is the rebrand / name-variant index
suppressPackageStartupMessages({library(data.table)})

SCR  <- "C:/Users/jdlec/AppData/Local/Temp/claude/C--Users-jdlec-Dropbox-00---URBAN-00-GITHUB-npmatch/8d457f05-c251-4620-a087-8660f4eedfde/scratchpad"
out  <- "data-dev/no-research"
YRS  <- 2019:2024

cols <- c("ORG_EIN","ORG_NAME_L1","ORG_NAME_L2","F9_00_ORG_NAME_DBA_L1","F9_00_ORG_NAME_DBA_L2",
          "F9_00_ORG_ADDR_L1","F9_00_ORG_ADDR_CITY","F9_00_ORG_ADDR_STATE","F9_00_ORG_ADDR_ZIP",
          "F9_00_ORG_ADDR_IN_CARE_OF","F9_00_ORG_WEBSITE","F9_00_ORG_PHONE",
          "F9_00_PRIN_OFF_NAME_PERS","F9_00_YEAR_FORMATION","F9_00_LEGAL_DMCL_STATE",
          "F9_00_EXEMPT_STAT_501C3_X","F9_00_GROUP_EXEMPT_NUM","TAX_YEAR","RETURN_TYPE")

norm_ein <- function(x) {
  x <- gsub("[^0-9]", "", x)
  x <- formatC(x, width = 9, flag = "0")
  paste0(substr(x,1,2), "-", substr(x,3,9))
}
# domain only: drop scheme, www, path, port, trailing dots
dom <- function(u) {
  u <- tolower(trimws(u))
  u <- sub("^[a-z]+://", "", u)
  u <- sub("^www[0-9]?\\.", "", u)
  u <- sub("[/?#].*$", "", u)
  u <- sub(":.*$", "", u)
  u <- sub("\\.+$", "", u)
  u[!grepl("\\.", u) | nchar(u) < 4] <- ""
  u
}
squish <- function(x) gsub("[\t\r\n]", " ", trimws(gsub(" +", " ", x)))

all <- rbindlist(lapply(YRS, function(y) {
  p <- file.path(SCR, sprintf("efile-%d.csv", y))
  if (!file.exists(p)) { cat("  missing", y, "\n"); return(NULL) }
  x <- fread(p, select = cols, colClasses = "character", showProgress = FALSE)
  cat(sprintf("  %d: %s rows\n", y, format(nrow(x), big.mark = ",")))
  x
}), fill = TRUE)
cat("total filings:", format(nrow(all), big.mark = ","), "\n")

all[, ein  := norm_ein(ORG_EIN)]
all[, name := squish(paste(ORG_NAME_L1, ORG_NAME_L2))]
all[, dba  := squish(paste(F9_00_ORG_NAME_DBA_L1, F9_00_ORG_NAME_DBA_L2))]
all[, web_domain := dom(F9_00_ORG_WEBSITE)]
all[, phone := gsub("[^0-9]", "", F9_00_ORG_PHONE)]
all[, ty := suppressWarnings(as.integer(TAX_YEAR))]
all <- all[grepl("^[0-9]{2}-[0-9]{7}$", ein) & name != ""]

## ---- name / dba variant index (all years) --------------------------------
nm <- unique(rbindlist(list(
  all[name != "", .(ein, variant = toupper(name), kind = "name")],
  all[dba  != "", .(ein, variant = toupper(dba),  kind = "dba")])), by = c("ein","variant"))
nm[, variant_key := gsub("[^A-Z0-9]", "", variant)]
fwrite(nm, file.path(out, "EFILE-NAMES.tsv"), sep = "\t", quote = FALSE)
cat("name/dba variants:", format(nrow(nm), big.mark = ","),
    " over", format(uniqueN(nm$ein), big.mark = ","), "EINs\n")

## ---- one row per EIN, most recent filing ---------------------------------
setorder(all, ein, -ty)
x <- all[, .SD[1], by = ein, .SDcols = c("name","dba","web_domain","phone",
        "F9_00_ORG_ADDR_L1","F9_00_ORG_ADDR_CITY","F9_00_ORG_ADDR_STATE","F9_00_ORG_ADDR_ZIP",
        "F9_00_ORG_ADDR_IN_CARE_OF","F9_00_PRIN_OFF_NAME_PERS","F9_00_YEAR_FORMATION",
        "F9_00_LEGAL_DMCL_STATE","F9_00_EXEMPT_STAT_501C3_X","F9_00_GROUP_EXEMPT_NUM","ty")]
setnames(x, c("F9_00_ORG_ADDR_L1","F9_00_ORG_ADDR_CITY","F9_00_ORG_ADDR_STATE","F9_00_ORG_ADDR_ZIP",
              "F9_00_ORG_ADDR_IN_CARE_OF","F9_00_PRIN_OFF_NAME_PERS","F9_00_YEAR_FORMATION",
              "F9_00_LEGAL_DMCL_STATE","F9_00_EXEMPT_STAT_501C3_X","F9_00_GROUP_EXEMPT_NUM","ty"),
         c("street","city","state","zip","care_of","officer","year_formed",
           "domicile_state","is_501c3","group_exempt","last_tax_year"))
for (c_ in names(x)) if (is.character(x[[c_]])) set(x, j = c_, value = squish(x[[c_]]))
# how many distinct years each EIN filed, and how many distinct names it used
x <- merge(x, all[, .(years_filed = uniqueN(ty)), by = ein], by = "ein")
x <- merge(x, nm[kind == "name", .(n_name_variants = .N), by = ein], by = "ein", all.x = TRUE)

fwrite(x, file.path(out, "EFILE-XWALK.tsv"), sep = "\t", quote = FALSE)
cat("\nEFILE-XWALK.tsv:", format(nrow(x), big.mark = ","), "EINs\n")
cat(sprintf("  with a website domain : %5.1f%%\n", 100*mean(x$web_domain != "")))
cat(sprintf("  with a phone          : %5.1f%%\n", 100*mean(x$phone != "")))
cat(sprintf("  with an officer name  : %5.1f%%\n", 100*mean(x$officer != "")))
cat(sprintf("  with >1 name variant  : %5.1f%%\n", 100*mean(x$n_name_variants > 1, na.rm = TRUE)))
cat("distinct website domains:", format(uniqueN(x[web_domain != ""]$web_domain), big.mark = ","), "\n")

idx <- as.data.table(readRDS("data-dev/BMF-NAME-INDEX.rds"))
cat("EINs absent from the unified BMF:",
    format(sum(!x$ein %chin% idx$ein), big.mark = ","),
    sprintf("(%.1f%%)\n", 100*mean(!x$ein %chin% idx$ein)))
