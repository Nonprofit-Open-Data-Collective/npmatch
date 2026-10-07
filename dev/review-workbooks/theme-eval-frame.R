#!/usr/bin/env Rscript
# ===========================================================================
# Theme the candidate evaluation frame for colleague review.
#
#   * columns renamed and ordered to match eval_frame_full.xlsx
#   * rows sorted so every UEI is one contiguous block
#   * alternating white / light-gray banding, flipping at each new UEI
#   * rows with is_best_candidate = 1 shaded light orange (wins over the band)
#   * frozen header + autofilter, populated data_dictionary, legend sheet
#   * one workbook per state; each UEI assigned to its modal state
#
# Usage:  Rscript theme_eval_frame.R [all|states|full|<STATE> ...]
#         Rscript theme_eval_frame.R CO        # rebuild just Colorado
# ===========================================================================

suppressMessages({ library(data.table); library(openxlsx); library(openssl) })

BASE   <- Sys.getenv("NPMATCH_RUN_DIR",
            "C:/Users/jdlec/Dropbox/00 - URBAN/00-GITHUB/npmatch/data-dev/runs/COMBINED_RESULTS")
SRC    <- file.path(BASE, "eval_frame_full.csv")
XLSX   <- file.path(BASE, "eval_frame_full.xlsx")
OUTDIR <- file.path(BASE, "review")
STDIR  <- file.path(OUTDIR, "by_state")
HERE   <- dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))
dir.create(STDIR, recursive = TRUE, showWarnings = FALSE)
source(file.path(HERE, "dictionary.R"))

ARGS <- commandArgs(TRUE); if (!length(ARGS)) ARGS <- "states"

HDR_FILL <- "#44546A"; BAND_FILL <- "#F2F2F2"; TOP_FILL <- "#FCE4D6"
WIDE <- 45L; NARROW <- 14L

msg <- function(...) { cat(sprintf(...), "\n"); flush.console() }

## ---------------------------------------------------------------- load ----
msg("reading %s", basename(SRC))
d <- fread(SRC, colClasses = "character", showProgress = FALSE, na.strings = NULL)
msg("  %d rows x %d cols", nrow(d), ncol(d))

## --------------------------------------------- rename + reorder columns ----
# The xlsx is the reviewer-facing presentation of the same data: it renames the
# stage-3 columns to llm_* and final_stage/final_reason to match_stage/
# match_reason, and front-loads the fields a reviewer actually reads.
# (Verified row-for-row against the CSV: no value conflicts.)
# is_top_candidate -> is_best_candidate is ours, not the xlsx's: "top" read as
# "the answer", which it is not once stages 2 and 3 have had their say.
RENAME <- c(final_stage = "match_stage", final_reason = "match_reason",
            is_top_candidate = "is_best_candidate")
s3 <- grep("^s3_", names(d), value = TRUE)
RENAME <- c(RENAME, setNames(sub("^s3_", "llm_", s3), s3))
setnames(d, names(RENAME), unname(RENAME))

XORDER <- readLines(file.path(HERE, "column-order.txt"))
stopifnot(setequal(XORDER, names(d)), length(XORDER) == ncol(d))
setcolorder(d, XORDER)
msg("  columns renamed (%d) and reordered to match the xlsx", length(RENAME))

## ------------------------------------------------------------- row_id ----
# A stable per-row handle so a reviewer can cite a row without pasting a whole
# line. Built from the raw CSV strings BEFORE the numeric conversion below, so
# it is reproducible from the source file and identical in the state workbook
# and the full one. uei+ein+total_score is unique across the frame; the assert
# fires rather than silently issuing a duplicate id if that ever stops holding.
rid <- substr(as.character(openssl::md5(
         paste(d$uei, d$ein, d$total_score, sep = "|"))), 1, 12)
if (anyDuplicated(rid)) stop("row_id collision: ", sum(duplicated(rid)), " duplicate hashes")
d[, row_id := paste0("RID-", rid)]
setcolorder(d, c("row_id", XORDER))
msg("  row_id added as column 1 (%d unique)", uniqueN(d$row_id))

## --------------------------------------------------------- size marker ----
# Surfaced next to the ids so a reviewer can sort the large organizations to the
# top without scrolling out to the BMF block.
#
# ON THE NAME: this is the IRS-reported revenue of the EIN on this row, so it is
# _bmf, not _uss. The SAM public extract carries no monetary field whatsoever --
# no revenue, receipts, assets or employee count -- so there is no source-side
# size marker available to import. Calling BMF money `size_uss` would break the
# convention that the _uss / _bmf suffix states which side a value came from.
d[, size_bmf := bmf_revenue_amount]
setcolorder(d, "size_bmf", after = "ein")
msg("  size_bmf added after ein (%d rows with revenue > 0)",
    sum(suppressWarnings(as.numeric(d$size_bmf)) > 0, na.rm = TRUE))

# size_uss: lifetime federal award obligations per UEI, summed from the
# USASpending annual archives by build-size-uss.R. This IS a source-side measure
# -- it describes the registrant, not the candidate EIN -- so it is constant
# across a UEI's block and _uss is the right suffix.
#
# Absence means two different things, and conflating them would be wrong. The
# archive was filtered to the matched crosswalk, so its universe is exactly the
# MATCHED UEIs: a matched UEI missing from it genuinely drew no federal awards
# ($0), while an unmatched UEI was never in scope at all (unknown, left blank).
SIZE_USS <- file.path(BASE, "size_uss.rds")
if (file.exists(SIZE_USS)) {
  su <- as.data.table(readRDS(SIZE_USS))[, .(uei, .su = size_uss)]
  d[su, on = "uei", size_uss := i..su]
  n_join <- sum(!is.na(d$size_uss))
  d[is.na(size_uss) & final_outcome == "MATCH", size_uss := 0]
  msg("  size_uss joined for %d rows; %d matched rows set to $0; %d unmatched left blank",
      n_join, sum(d$size_uss == 0, na.rm = TRUE), sum(is.na(d$size_uss)))
} else {
  d[, size_uss := NA_real_]
  msg("  ! %s not found -- size_uss left empty (run build-size-uss.R)", basename(SIZE_USS))
}
setcolorder(d, "size_uss", after = "ein")   # ein, size_uss, size_bmf

## ------------------------------------------------------- types + hygiene ----
KEEP_TEXT <- intersect(c("zip5_uss", "zip5_bmf"), names(d))   # leading zeros
num_ok <- function(x) {
  v <- x[!is.na(x) & x != ""]
  length(v) > 0 && all(grepl("^[+-]?(\\d+\\.?\\d*|\\.\\d+)([eE][+-]?\\d+)?$", v))
}
num_cols <- setdiff(names(d)[vapply(d, num_ok, logical(1))], KEEP_TEXT)
d[, (num_cols) := lapply(.SD, as.numeric), .SDcols = num_cols]
msg("  numeric columns: %d", length(num_cols))

for (cl in names(d)[vapply(d, is.character, logical(1))]) {   # Excel hygiene
  v <- d[[cl]]
  v <- gsub("[\x01-\x08\x0B\x0C\x0E-\x1F]", "", v, useBytes = TRUE)
  long <- !is.na(v) & nchar(v) > 32000
  if (any(long)) v[long] <- paste0(substr(v[long], 1, 32000), " ...[truncated]")
  set(d, j = cl, value = v)
}

## ---------------------------------------------------------------- sort ----
# Stable sort on uei: each group keeps its original candidate ordering.
d[, .srcrow := .I]; setorder(d, uei, .srcrow); d[, .srcrow := NULL]
msg("sorted; %d UEI groups, all contiguous: %s", uniqueN(d$uei),
    sum(d$uei != shift(d$uei, fill = "\u0001")) == uniqueN(d$uei))

## --------------------------------------------- state: one per UEI, modal ----
US <- c(state.abb, "DC", "PR", "VI", "GU", "AS", "MP", "UM", "FM", "MH", "PW")
modal <- function(v) {
  v <- v[!is.na(v) & v != ""]
  if (!length(v)) return(NA_character_)
  tb <- table(v)
  names(tb)[order(-as.integer(tb), names(tb))][1]   # ties -> alphabetical
}
# Each UEI goes to exactly one file: the modal state_uss across its rows,
# falling back to the modal state_bmf of its candidates when the source record
# carries no state at all.
ustate <- d[, .(st  = modal(state_uss),
                bst = modal(state_bmf),
                nst = uniqueN(state_uss[state_uss != ""])), by = uei]
msg("modal state: %d UEIs carried >1 distinct state_uss (modal broke the tie)",
    sum(ustate$nst > 1))
n_miss <- sum(is.na(ustate$st))
ustate[is.na(st), st := bst]
msg("state_uss missing for %d UEIs; state_bmf recovered %d, %d remain unknown",
    n_miss, n_miss - sum(is.na(ustate$st)), sum(is.na(ustate$st)))
ustate[, grp := fifelse(is.na(st), "unknown", fifelse(st %in% US, st, "foreign"))]
d[ustate, on = "uei", .grp := i.grp]
msg("state groups: %d", uniqueN(d$.grp))

## ------------------------------------------------------- data dictionary ----
# Sections are declared as positions in XORDER, but row_id and size_bmf are ours
# and sit outside it, so resolve section by field NAME -- otherwise every column
# after an inserted one picks up its neighbour's section.
sect_of <- setNames(rep(NA_character_, length(XORDER)), XORDER)
for (s in names(NP_SECTIONS)) sect_of[NP_SECTIONS[[s]]] <- s
sect_of[c("row_id", "size_uss", "size_bmf")] <- "1. Review header"

FIELDS <- setdiff(names(d), ".grp")          # the order actually written
missing_def <- setdiff(FIELDS, names(NP_DICT))
if (length(missing_def)) msg("  ! no definition for: %s", paste(missing_def, collapse = ", "))
dict <- data.frame(
  `#`        = seq_along(FIELDS),
  Section    = unname(sect_of[FIELDS]),
  Field      = FIELDS,
  Definition = unname(NP_DICT[FIELDS]),
  check.names = FALSE, stringsAsFactors = FALSE)
msg("data dictionary: %d fields, %d defined", nrow(dict), sum(!is.na(dict$Definition)))

## -------------------------------------------------------------- styles ----
hdr_style <- createStyle(fgFill = HDR_FILL, fontColour = "#FFFFFF", textDecoration = "bold",
                         halign = "left", valign = "center", border = "TopBottomLeftRight",
                         borderColour = "#2F3B4F")
band_dxf  <- createStyle(bgFill = BAND_FILL)
top_dxf   <- createStyle(bgFill = TOP_FILL)
wrap_top  <- createStyle(wrapText = TRUE, valign = "top")
sect_style<- createStyle(textDecoration = "bold", valign = "top")

WIDE_PAT <- paste0("name_|street|reason|notes|judgement|sources|web_|path|",
                   "definition|tokenized|status_basis")

write_themed <- function(dt, path, label) {
  dt <- copy(dt)
  # Parity is computed HERE, on the rows actually written, so consecutive
  # groups alternate within each file. Computing it once on the full frame and
  # then slicing by state breaks the alternation.
  dt[, `_band` := as.integer(cumsum(uei != shift(uei, fill = "\u0001")) %% 2L == 0L)]
  n <- nrow(dt); nc <- ncol(dt)
  band_ref <- paste0("$", int2col(which(names(dt) == "_band")))
  # Orange marks THE MATCH, not the cascade's pick. is_best_candidate is stage 1
  # only, so it misses every answer stage 2/3 produced and still flags stage-1
  # picks those stages later overrode. is_final_ein is the stage-agnostic
  # answer: exactly one row per matched UEI, zero per unmatched.
  top_ref  <- paste0("$", int2col(which(names(dt) == "is_final_ein")))

  wb <- createWorkbook()
  addWorksheet(wb, "eval_frame", gridLines = TRUE)
  writeData(wb, "eval_frame", dt, headerStyle = hdr_style, withFilter = TRUE)
  freezePane(wb, "eval_frame", firstActiveRow = 2, firstActiveCol = 6)  # keep ids visible
  setColWidths(wb, "eval_frame", cols = 1:nc, widths = NARROW)
  setColWidths(wb, "eval_frame", cols = grep(WIDE_PAT, names(dt)), widths = WIDE)
  setColWidths(wb, "eval_frame", cols = 1, widths = 18)   # row_id
  sz <- which(names(dt) %in% c("size_uss", "size_bmf"))
  setColWidths(wb, "eval_frame", cols = sz, widths = 16)
  if (n > 0) addStyle(wb, "eval_frame", createStyle(numFmt = "#,##0"),
                      rows = 2:(n + 1), cols = sz, gridExpand = TRUE)
  setColWidths(wb, "eval_frame", cols = nc, widths = 8, hidden = TRUE)

  if (n > 0) {
    # Mutually exclusive, so Excel's rule priority never enters into it.
    conditionalFormatting(wb, "eval_frame", cols = 1:nc, rows = 2:(n + 1), type = "expression",
                          rule = sprintf("%s2=1", top_ref), style = top_dxf)
    conditionalFormatting(wb, "eval_frame", cols = 1:nc, rows = 2:(n + 1), type = "expression",
                          rule = sprintf("AND(%s2=1,%s2<>1)", band_ref, top_ref), style = band_dxf)
  }

  addWorksheet(wb, "data_dictionary")
  writeData(wb, "data_dictionary", dict, headerStyle = hdr_style)
  setColWidths(wb, "data_dictionary", cols = 1:4, widths = c(5, 26, 32, 110))
  addStyle(wb, "data_dictionary", wrap_top, rows = 2:(nrow(dict) + 1), cols = 4, gridExpand = TRUE)
  addStyle(wb, "data_dictionary", sect_style, rows = 2:(nrow(dict) + 1), cols = 2, gridExpand = TRUE)
  freezePane(wb, "data_dictionary", firstActiveRow = 2)

  addWorksheet(wb, "legend")
  writeData(wb, "legend", data.frame(
    Shading = c("Light orange", "Gray / white alternating", "Hidden column `_band`"),
    Meaning = c(paste("is_final_ein = 1 - the row carrying THE MATCH for this UEI, whichever stage produced it",
                      "(1 = cascade, 2 = LLM review, 3 = LLM research). Exactly one orange row per matched UEI;",
                      "a UEI with no orange row was not matched. Note this is NOT is_best_candidate, which only",
                      "records the stage-1 pick and is 0 on answers stages 2 and 3 found."),
                "one band per UEI; the shade flips at each new UEI so groups are easy to separate",
                "0/1 helper that drives the banding. Ignore it; re-sorting the sheet on anything other than uei will scramble the alternation.")),
    headerStyle = hdr_style)
  setColWidths(wb, "legend", cols = 1:2, widths = c(28, 100))
  addStyle(wb, "legend", wrap_top, rows = 2:4, cols = 2, gridExpand = TRUE)
  setRowHeights(wb, "legend", rows = 2, heights = 60)
  writeData(wb, "legend", c(
    label,
    sprintf("%s rows, %s UEI groups, %s top candidates",
            format(n, big.mark = ","), format(uniqueN(dt$uei), big.mark = ","),
            format(sum(dt$is_best_candidate == 1, na.rm = TRUE), big.mark = ",")),
    "Each UEI is assigned to a single state, chosen as the modal state_uss within the group.",
    "Column names and order follow eval_frame_full.xlsx; see the data_dictionary tab."),
    startRow = 7, colNames = FALSE)

  # A workbook open in Excel is locked, and openxlsx only warns -- which would
  # leave a stale file behind looking like a successful build. Verify the write
  # actually landed, and divert to a sibling path rather than lose the build.
  before <- if (file.exists(path)) file.mtime(path) else NA
  ok <- tryCatch({ suppressWarnings(saveWorkbook(wb, path, overwrite = TRUE))
                   file.exists(path) && (is.na(before) || file.mtime(path) > before) },
                 error = function(e) FALSE)
  if (!ok) {
    alt <- sub("\\.xlsx$", "-NEW.xlsx", path)
    msg("  ! %s is locked (open in Excel) - writing %s instead", basename(path), basename(alt))
    saveWorkbook(wb, alt, overwrite = TRUE)
    path <- alt
  }
  invisible(setNames(file.size(path), path))
}

## --------------------------------------------------------------- build ----
grp <- d$.grp; d[, .grp := NULL]

build_states <- function(which_g) {
  tot <- 0
  for (g in which_g) {
    sub <- d[grp == g]
    if (!nrow(sub)) { msg("  %-8s  no rows - skipped", g); next }
    p <- file.path(STDIR, sprintf("eval_frame_%s.xlsx", g))
    sz <- write_themed(sub, p, sprintf("Candidate evaluation frame - %s", g)); tot <- tot + sz
    msg("  %-8s %6d rows  %6.1f MB", g, nrow(sub), sz / 1e6)
  }
  tot
}

if (identical(ARGS, "states") || "all" %in% ARGS) {
  gs <- names(sort(table(grp), decreasing = TRUE))
  msg("writing %d state workbooks -> %s", length(gs), STDIR)
  msg("state workbooks total: %.1f MB", build_states(gs) / 1e6)
} else if (!"full" %in% ARGS) {
  msg("rebuilding: %s", paste(ARGS, collapse = ", "))
  invisible(build_states(ARGS))
}

if ("full" %in% ARGS || "all" %in% ARGS) {
  p <- file.path(OUTDIR, "eval_frame_full_themed.xlsx")
  msg("writing full workbook -> %s (several minutes)", p)
  msg("full workbook: %d rows, %.1f MB", nrow(d), write_themed(d, p, "Candidate evaluation frame - all states") / 1e6)
}

msg("done.")
