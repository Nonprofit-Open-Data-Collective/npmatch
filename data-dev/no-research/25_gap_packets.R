#!/usr/bin/env Rscript
# Packets for the 43 cases the new escape hatch un-gated that have no answer yet.
# Same enrichment as 05_make_batches.R (efile by domain + by name, cached ProPublica).
# Agents write straight into agent-out/ as batch-90N.tsv so 06_merge_findings.R
# picks them up with no special-casing.
suppressPackageStartupMessages({library(data.table)})

out <- "data-dev/no-research"
dir.create(file.path(out, "gap-batches"), showWarnings = FALSE)

gapq <- fread(file.path(out, "QUEUE-GAP.csv"), colClasses = "character")
seed <- fread(file.path(out, "FINDINGS-SEED.csv"), colClasses = "character")
w <- seed[uei %chin% gapq$uei]
cat("gap cases:", nrow(w), "\n")

fmt_x <- function(d) paste0(sprintf(
  "%s | %s | %s, %s %s | web=%s | officer=%s | formed=%s | filed %s yrs thru %s",
  d$ein, d$name, d$city, d$state, d$zip, d$web_domain, d$officer,
  d$year_formed, d$years_filed, d$last_tax_year), collapse = " ;; ")

xw <- fread(file.path(out,"EFILE-XWALK.tsv"), sep="\t", colClasses="character", quote="")
nm <- fread(file.path(out,"EFILE-NAMES.tsv"), sep="\t", colClasses="character", quote="")
pp <- fread(file.path(out,"PP-CACHE.tsv"),   sep="\t", colClasses="character", quote="")

hd <- merge(w[sam_domain != "", .(uei, sam_domain)], xw[web_domain != ""],
            by.x="sam_domain", by.y="web_domain", allow.cartesian=TRUE)
hd[, web_domain := sam_domain]
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
w <- merge(w, pp[, .(query, pp_http=http, pp_n=total_results, pp_results=results)],
           by.x="pp_query", by.y="query", all.x=TRUE, sort=FALSE)
nz <- function(v) sum(!is.na(v) & nzchar(v))
cat("efile domain evidence:", nz(w$efile_by_domain),
    " name evidence:", nz(w$efile_by_name),
    " cached ProPublica:", sum(!is.na(w$pp_http)), "\n")

setorder(w, web_reason, uei)
w[, batch := sprintf("%02d", (seq_len(.N) - 1L) %/% 8L + 1L)]

blk <- function(l,x) if (length(x) && !is.na(x) && nzchar(x)) sprintf("- %s: %s\n", l, x) else ""
for (b in unique(w$batch)) {
  d <- w[batch == b]
  txt <- sprintf("# Gap batch %s  (%d organizations)\n\n", b, nrow(d))
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
      blk("Stage-2: candidates the LLM saw", x$candidates),
      blk("Stage-2: LLM rejection reason", x$llm_reason))
  }
  writeLines(txt, file.path(out, "gap-batches", sprintf("gap-%s.md", b)))
}
cat("batches:", length(unique(w$batch)), "\n")

## ---- fold the 25 gap cases the blind gate audit already answered ---------
vv <- fread(file.path(out, "AUDIT-V1-VS-V2.csv"), colClasses = "character")
seedq <- seed[web == "TRUE"]
done <- vv[uei %chin% seedq$uei & !is.na(v2_det) & v2_det != ""]
done <- merge(done[, .(uei, ein_found = v2_ein, determination = v2_det,
                       resolving_tier = v2_tier, confidence = v2_conf,
                       sources = v2_sources)],
              seed[, .(uei, sam_name, run, stage)], by = "uei")
done[, judgement := "Resolved in the blind Tier-1 gate audit (rev 2, cached Tier 2 + efile index)."]
done[, notes := "carried over from AUDIT-V1-VS-V2; not re-researched"]
setcolorder(done, c("uei","sam_name","run","stage","ein_found","determination",
                    "resolving_tier","confidence","sources","judgement","notes"))
fwrite(done, file.path(out, "agent-out", "batch-900.tsv"), sep = "\t", quote = FALSE)
cat("carried over from the gate audit -> agent-out/batch-900.tsv:", nrow(done), "rows\n")
