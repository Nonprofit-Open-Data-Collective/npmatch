#!/usr/bin/env Rscript
# Emit (a) a grep-able flat BMF for Tier-1.5 lookups and (b) per-agent work packets.
suppressPackageStartupMessages({library(data.table)})

D <- "data-dev"; out <- file.path(D, "no-research")
dir.create(file.path(out, "web-batches"), showWarnings = FALSE)
dir.create(file.path(out, "agent-out"),   showWarnings = FALSE)

## ---- (a) flat, ripgrep-able BMF (active + inactive, 3.69M rows) ----------
gp <- file.path(out, "BMF-GREP.tsv")
if (!file.exists(gp)) {
  idx <- as.data.table(readRDS(file.path(D, "BMF-NAME-INDEX.rds")))
  idx[, act := ifelse(active, "ACTIVE", "INACTIVE")]
  fwrite(idx[, .(ein, name, dba, city, state, zip5, care_of, subsection, act)],
         gp, sep = "\t", quote = FALSE)
  cat("wrote", gp, nrow(idx), "rows\n")
}

## ---- (b) work packets ----------------------------------------------------
a <- fread(file.path(out, "FINDINGS-SEED.csv"), colClasses = "character")
w <- a[web == "TRUE"]
setorder(w, .src, web_reason, uei)

## ---- evidence the brief promises the packet will carry -------------------
fmt_x <- function(d) paste0(sprintf(
  "%s | %s | %s, %s %s | web=%s | officer=%s | formed=%s | filed %s yrs thru %s",
  d$ein, d$name, d$city, d$state, d$zip, d$web_domain, d$officer,
  d$year_formed, d$years_filed, d$last_tax_year), collapse = " ;; ")

xwp <- file.path(out, "EFILE-XWALK.tsv"); nmp <- file.path(out, "EFILE-NAMES.tsv")
if (file.exists(xwp)) {
  xw <- fread(xwp, sep = "\t", colClasses = "character", quote = "", showProgress = FALSE)
  # (i) efile filers sharing this org's website domain
  hd <- merge(w[sam_domain != "", .(uei, sam_domain)], xw[web_domain != ""],
              by.x = "sam_domain", by.y = "web_domain", allow.cartesian = TRUE)
  # the join consumes web_domain into sam_domain; fmt_x needs it back, or sprintf
  # gets a NULL, returns character(0), and every row silently formats to ""
  hd[, web_domain := sam_domain]
  hd <- hd[, .(efile_by_domain = fmt_x(.SD[1:min(.N, 5)])), by = uei]
  w <- merge(w, hd, by = "uei", all.x = TRUE, sort = FALSE)
  # (ii) efile filers that filed under this name (any year) -- the rebrand index
  if (file.exists(nmp)) {
    nm <- fread(nmp, sep = "\t", colClasses = "character", quote = "", showProgress = FALSE)
    hn <- merge(w[q_nk_ds != "", .(uei, q_nk_ds)], nm,
                by.x = "q_nk_ds", by.y = "variant_key", allow.cartesian = TRUE)
    hn <- merge(hn, xw, by = "ein", allow.cartesian = TRUE)
    hn <- hn[, .(efile_by_name = fmt_x(.SD[1:min(.N, 5)])), by = uei]
    w <- merge(w, hn, by = "uei", all.x = TRUE, sort = FALSE)
  } else w[, efile_by_name := NA_character_]
  # count what will actually PRINT (non-empty), not merely what is non-NA --
  # an empty string passes !is.na and would mask a formatting failure
  nz <- function(v) sum(!is.na(v) & nzchar(v))
  cat("packets carrying efile domain evidence:", nz(w$efile_by_domain),
      " name evidence:", nz(w$efile_by_name), "\n")
} else {
  w[, efile_by_domain := NA_character_]; w[, efile_by_name := NA_character_]
  cat("!! EFILE-XWALK.tsv missing -- packets will carry no efile evidence.\n")
}

## (iii) cached ProPublica, keyed on the same distinctive-name query the
##       prefetcher used. Agents must never call ProPublica live.
ppp <- file.path(out, "PP-CACHE.tsv")
STOP <- c("INC","INCORPORATED","CORP","CORPORATION","CO","COMPANY","LLC","LTD","THE","OF",
          "AND","FOR","A","AN","FOUNDATION","TRUST","FUND","ASSOCIATION","ASSOC","SOCIETY",
          "CENTER","CENTRE","INSTITUTE","COUNCIL","ORGANIZATION","ORG","GROUP","SERVICES",
          "SERVICE","PROJECT","PROGRAM","NONPROFIT","NON","PROFIT","USA","US","AMERICA",
          "AMERICAN","NATIONAL","INTERNATIONAL","COMMUNITY")
distinctive <- function(s) {
  x <- toupper(gsub("[^A-Za-z0-9 ]", " ", s))
  v <- setdiff(strsplit(trimws(gsub(" +", " ", x)), " ")[[1]], STOP)
  if (!length(v)) v <- strsplit(trimws(gsub(" +", " ", x)), " ")[[1]]
  paste(head(v, 4), collapse = " ")
}
w[, pp_query := vapply(sam_name, distinctive, "")]
if (file.exists(ppp)) {
  pp <- fread(ppp, sep = "\t", colClasses = "character", quote = "", showProgress = FALSE)
  w <- merge(w, pp[, .(query, pp_http = http, pp_n = total_results, pp_results = results)],
             by.x = "pp_query", by.y = "query", all.x = TRUE, sort = FALSE)
  miss <- sum(is.na(w$pp_http))
  cat("packets with cached ProPublica:", nrow(w) - miss, "of", nrow(w), "\n")
  if (miss) cat("!! ", miss, " cases have no cache entry. Run 12_pp_prefetch.R over this\n",
                "   queue BEFORE fanning out, or those agents lose Tier 2 entirely.\n", sep = "")
} else {
  w[, `:=`(pp_http = NA_character_, pp_n = NA_character_, pp_results = NA_character_)]
  cat("!! PP-CACHE.tsv missing -- run 12_pp_prefetch.R first; Tier 2 will be unavailable.\n")
}
setorder(w, .src, web_reason, uei)
N <- 8L
w[, batch := sprintf("%03d", (seq_len(.N) - 1L) %/% N + 1L)]
fwrite(w[, .(uei, batch, .src, web_reason)], file.path(out, "web-batch-index.csv"))

blk <- function(lbl, v) if (!is.na(v) && nzchar(v)) sprintf("- %s: %s\n", lbl, v) else ""

for (b in unique(w$batch)) {
  d <- w[batch == b]
  txt <- sprintf("# Web-research batch %s  (%d organizations)\n\n", b, nrow(d))
  for (i in seq_len(nrow(d))) {
    x <- d[i]
    txt <- paste0(txt, sprintf("\n## CASE %d of %d\n", i, nrow(d)),
      blk("uei", x$uei),
      blk("run", x$run), blk("no_stage", x$stage), blk("no_origin", x$no_origin),
      blk("why_this_needs_web", x$web_reason),
      blk("SAM legal name", x$sam_name),
      blk("SAM dba", x$sam_dba), blk("SAM division", x$sam_division),
      blk("SAM address", paste(na.omit(c(x$sam_street1, x$sam_street2)), collapse = " ")),
      blk("SAM city/state/zip", paste(x$sam_city, x$sam_state, x$sam_zip)),
      blk("SAM mailing", paste(na.omit(c(x$sam_mail_street, x$sam_mail_city,
                                         x$sam_mail_state, x$sam_mail_zip)), collapse = " ")),
      blk("SAM url", x$sam_url),
      blk("SAM entity structure", x$sam_entity_structure),
      blk("SAM state of incorporation", x$sam_state_incorp),
      blk("SAM business types", x$sam_bus_type),
      blk("SAM primary NAICS", x$sam_naics),
      blk("SAM contact", paste(na.omit(c(x$sam_poc_first, x$sam_poc_last,
                                         x$sam_poc_title)), collapse = " ")),
      blk("SAM registered / entity start", paste(x$sam_reg_date, "/", x$sam_start_date)),
      blk("Tier-1 entity gate", x$entity_gate),
      blk("Tier-1 full-BMF name lookup", x$bmf_lookup),
      blk("EFILE 990 filers sharing this website domain", x$efile_by_domain),
      blk("EFILE 990 filers matching this name-as-filed", x$efile_by_name),
      blk("ProPublica (CACHED - do not re-query)",
          if (is.na(x$pp_http)) "" else sprintf("%s results (HTTP %s)%s",
            x$pp_n, x$pp_http,
            if (!is.na(x$pp_results) && nzchar(x$pp_results))
              paste0(" :: ", x$pp_results) else "")),
      blk("Stage-2: candidates the LLM saw", x$candidates),
      blk("Stage-2: LLM rejection reason", x$llm_reason))
  }
  writeLines(txt, file.path(out, "web-batches", sprintf("batch-%s.md", b)))
}
cat("batches:", length(unique(w$batch)), " cases:", nrow(w), "\n")
