#!/usr/bin/env Rscript
# Phase 3 packets for the full run. Same enrichment as 05_make_batches.R but off
# FULL-SEED.csv. Optional arg: "stage1" / "stage2" to build one stage only, so
# agents can start on stage 2 while stage-1 prefetch is still going.
#
#   Rscript 29_full_packets.R [stage1|stage2]
suppressPackageStartupMessages({library(data.table)})
args <- commandArgs(trailingOnly = TRUE)
WANT <- if (length(args)) args[1] else NA_character_
out  <- "data-dev/no-research"
dir.create(file.path(out, "run-batches"), showWarnings = FALSE)
dir.create(file.path(out, "run-out"),     showWarnings = FALSE)

a <- fread(file.path(out, "FULL-SEED.csv"), colClasses = "character")
w <- a[web == "TRUE"]
if (!is.na(WANT)) w <- w[stage == WANT]
cat("cases to packet:", format(nrow(w), big.mark = ","),
    if (!is.na(WANT)) paste0(" (", WANT, " only)") else "", "\n")

fmt_x <- function(d) paste0(sprintf(
  "%s | %s | %s, %s %s | web=%s | officer=%s | formed=%s | filed %s yrs thru %s",
  d$ein, d$name, d$city, d$state, d$zip, d$web_domain, d$officer,
  d$year_formed, d$years_filed, d$last_tax_year), collapse = " ;; ")

xw <- fread(file.path(out,"EFILE-XWALK.tsv"), sep="\t", colClasses="character",
            quote="", showProgress=FALSE)
nm <- fread(file.path(out,"EFILE-NAMES.tsv"), sep="\t", colClasses="character",
            quote="", showProgress=FALSE)

hd <- merge(w[sam_domain != "", .(uei, sam_domain)], xw[web_domain != ""],
            by.x="sam_domain", by.y="web_domain", allow.cartesian=TRUE)
hd[, web_domain := sam_domain]                       # join consumed it; fmt_x needs it
hd <- hd[, .(efile_by_domain = fmt_x(.SD[1:min(.N,5)])), by = uei]
w <- merge(w, hd, by="uei", all.x=TRUE, sort=FALSE)

hn <- merge(w[q_nk_ds != "", .(uei, q_nk_ds)], nm, by.x="q_nk_ds",
            by.y="variant_key", allow.cartesian=TRUE)
hn <- merge(hn, xw, by="ein", allow.cartesian=TRUE)
hn <- hn[, .(efile_by_name = fmt_x(.SD[1:min(.N,5)])), by = uei]
w <- merge(w, hn, by="uei", all.x=TRUE, sort=FALSE)

STOP <- c("INC","INCORPORATED","CORP","CORPORATION","CO","COMPANY","LLC","LTD","THE","OF",
          "AND","FOR","A","AN","FOUNDATION","TRUST","FUND","ASSOCIATION","ASSOC","SOCIETY",
          "CENTER","CENTRE","INSTITUTE","COUNCIL","ORGANIZATION","ORG","GROUP","SERVICES",
          "SERVICE","PROJECT","PROGRAM","NONPROFIT","NON","PROFIT","USA","US","AMERICA",
          "AMERICAN","NATIONAL","INTERNATIONAL","COMMUNITY")
distinctive <- function(s){x<-toupper(gsub("[^A-Za-z0-9 ]"," ",s))
  v<-setdiff(strsplit(trimws(gsub(" +"," ",x))," ")[[1]],STOP)
  if(!length(v)) v<-strsplit(trimws(gsub(" +"," ",x))," ")[[1]]
  paste(head(v,4),collapse=" ")}
w[, pp_query := vapply(sam_name, distinctive, "")]
pp <- fread(file.path(out,"PP-CACHE.tsv"), sep="\t", colClasses="character",
            quote="", showProgress=FALSE)
w <- merge(w, pp[, .(query, pp_http=http, pp_n=total_results, pp_results=results)],
           by.x="pp_query", by.y="query", all.x=TRUE, sort=FALSE)

nz <- function(v) sum(!is.na(v) & nzchar(v))
cat("efile domain evidence:", nz(w$efile_by_domain),
    " | name evidence:", nz(w$efile_by_name),
    " | cached ProPublica:", sum(!is.na(w$pp_http)), "of", nrow(w), "\n")
miss <- sum(is.na(w$pp_http))
if (miss) cat("!! ", miss, " cases have NO Tier-2 cache entry. Finish 12_pp_prefetch.R\n",
              "   over this queue before fanning out, or those agents lose Tier 2.\n", sep="")

setorder(w, stage, web_reason, uei)
w[, batch := sprintf("%04d", (seq_len(.N) - 1L) %/% 8L + 1L)]
if (!is.na(WANT) && WANT == "stage1") w[, batch := sprintf("1%s", batch)]  # keep ids distinct

blk <- function(l,x) if (length(x) && !is.na(x) && nzchar(x)) sprintf("- %s: %s\n", l, x) else ""
for (b in unique(w$batch)) {
  d <- w[batch == b]
  txt <- sprintf("# Research batch %s  (%d organizations)\n\n", b, nrow(d))
  for (i in seq_len(nrow(d))) {
    x <- d[i]
    txt <- paste0(txt, sprintf("\n## CASE %d of %d\n", i, nrow(d)),
      blk("uei", x$uei), blk("run", x$run), blk("no_stage", x$stage),
      blk("why_this_needs_web", x$web_reason),
      blk("SAM legal name", x$sam_name), blk("SAM dba", x$sam_dba),
      blk("SAM address", paste(na.omit(c(x$sam_street1,x$sam_street2)), collapse=" ")),
      blk("SAM city/state/zip", paste(x$sam_city, x$sam_state, x$sam_zip)),
      blk("SAM mailing", paste(na.omit(c(x$sam_mail_street,x$sam_mail_city,
                                         x$sam_mail_state,x$sam_mail_zip)), collapse=" ")),
      blk("SAM url", x$sam_url),
      blk("SAM entity structure", x$sam_entity_structure),
      blk("SAM state of incorporation", x$sam_state_incorp),
      blk("SAM business types", x$sam_bus_type),
      blk("SAM contact", paste(na.omit(c(x$sam_poc_first,x$sam_poc_last,
                                         x$sam_poc_title)), collapse=" ")),
      blk("Tier-1 entity gate", x$entity_gate),
      blk("Tier-1 full-BMF name lookup", x$bmf_lookup),
      blk("EFILE 990 filers sharing this website domain", x$efile_by_domain),
      blk("EFILE 990 filers matching this name-as-filed", x$efile_by_name),
      blk("ProPublica (CACHED - do not re-query)",
          if (is.na(x$pp_http)) "" else sprintf("%s results (HTTP %s)%s", x$pp_n, x$pp_http,
            if (!is.na(x$pp_results) && nzchar(x$pp_results))
              paste0(" :: ", x$pp_results) else "")),
      blk("Stage-2: candidates the adjudicator saw", x$candidates),
      blk("Stage-2: rejection reason", x$llm_reason))
  }
  writeLines(txt, file.path(out, "run-batches", sprintf("run-%s.md", b)))
}
cat("batches written:", length(unique(w$batch)), "\n")
fwrite(w[, .(uei, batch, stage, web_reason)],
       file.path(out, sprintf("run-batch-index%s.csv",
                              if (is.na(WANT)) "" else paste0("-", WANT))))
