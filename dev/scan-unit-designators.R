# Which secondary-unit designators are worth parsing, measured rather than
# assumed, and how badly the old pattern misfired. Run against the normalized
# unified BMF (1.92M rows); re-run it before changing .np_unit_designators.
#
# What it showed, and what the current pattern is built on:
#
#   * 247,683 rows had a unit extracted. 27,954 of those (11.3%) were false,
#     because the old pattern had no word boundary and let the "id" be letters:
#     SHERMAN WAY -> RM "AN WAY", INDIGO BROOM LOOP -> RM "OOM LOOP", whose
#     removal left the street key as "10317 INDIGO B".
#   * In 3,636 rows the false match also MASKED the real unit, the leftmost
#     match winning: "259 N RADNOR CHESTER RD STE 150" -> "STER", inside
#     CHESTER, and the real STE 150 never seen.
#   * Designators the old pattern did not know, by volume: PMB (10.2k), FL /
#     FLOOR (10.2k, nearly all written AFTER the number -- "2ND FL"), the bare
#     number sign (1.4k), SPC, LOT, DEPT, TRLR, STOP, LBBY, HNGR, BSMT.
#   * USPS C2 designators deliberately NOT adopted: FRNT, REAR, LOWR, UPPR,
#     OFC, PH, PIER, KEY, SIDE, SLIP. In this corpus they match street names
#     (PIERCE ST, KEYSER AVE, SIDEHILL RD, N FRNT ST), not units. NO is out for
#     a sharper reason: it is North far more often than Number ("123 NO 5TH
#     ST"), so it would delete a real street token.
#   * The token before a trailing number is usually NOT a unit designator but a
#     numbered route: RD, HWY, RTE, FM, CR, US, LOOP. Those must stay.

library(npmatch)
r <- readRDS("data-dev/NORM-R.rds")      # normalized reference (BMF)
s <- toupper(as.character(r$street)); s[is.na(s)] <- ""

# --- 1. what the current pattern does ---------------------------------------
u <- npmatch:::.np_extract_unit(r$street)
k <- npmatch:::.np_street_key(r$street)
cat(sprintf("units extracted: %d (%.1f%%)\n", sum(!is.na(u)), 100 * mean(!is.na(u))))
cat(sprintf("street_key differs from the stored one: %d\n", sum(k != r$street_key, na.rm = TRUE)))

# --- 2. a candidate designator, scored before adopting it -------------------
# total matches, how many have a numeric id, and examples of the alphabetic
# ones -- which is where the false positives live.
probe <- function(d) {
  m <- stringr::str_match(s, paste0("\b", d, "[ .,]*#?[ .,]*([0-9A-Z][0-9A-Z-]*)"))
  hit <- !is.na(m[, 1]); id <- m[hit, 2]
  num <- grepl("^[0-9]", id)
  cat(sprintf("%-10s total %7d  numeric %7d  alpha %7d | %s\n", d, sum(hit),
              sum(num), sum(!num), paste(utils::head(s[hit][!num], 2), collapse = " | ")))
}
invisible(lapply(c("STE", "APT", "UNIT", "RM", "BLDG", "FL", "PMB", "SPC", "LOT",
                   "TRLR", "DEPT", "STOP", "NO", "NUM", "FRNT", "REAR", "KEY",
                   "SIDE", "PH", "PIER", "OFC", "MS", "MC"), probe))

# --- 3. the user's scan: street starts with a number and ends with one ------
# tabulates the token immediately before the trailing number, which is where an
# unparsed designator shows up -- and where numbered routes show up too.
cl   <- npmatch:::.np_basic_clean(r$street); cl[is.na(cl)] <- ""
dd   <- grepl("^[0-9].*[0-9]$", cl)
body <- sub("^[0-9]+[A-Z]?(-[0-9]+[A-Z]?)? *", "", cl[dd])
tok  <- stringr::str_match(body, "\b([A-Z][A-Z0-9]*) +#? ?[0-9][0-9A-Z]*$")[, 2]
known <- names(npmatch:::.np_unit_designators)
tt <- sort(table(tok[!is.na(tok)]), decreasing = TRUE)
print(utils::head(data.frame(token = names(tt), n = as.integer(tt),
                             parsed = names(tt) %in% known), 45))

# --- 4. how crowded addresses really are ------------------------------------
af <- np_addr_freq(r$street_key, r$zip5, r$street_unit_id)
cat(sprintf("addresses: %d | with >10 records: %d | address+suite with >10: %d\n",
            length(af$addr), sum(af$addr > 10), sum(af$addr_unit > 10)))
cat("most distinct suites at one address:\n")
print(utils::head(sort(af$units, decreasing = TRUE), 10))
