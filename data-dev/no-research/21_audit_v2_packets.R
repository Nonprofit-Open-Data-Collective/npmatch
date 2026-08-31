#!/usr/bin/env Rscript
# Rebuild the 167 gate-audit packets with the two new assets baked in:
#   - cached ProPublica results (no live call, no 429s)
#   - efile 990 header hits by website domain and by name-as-filed
suppressPackageStartupMessages({library(data.table)})

out <- "data-dev/no-research"
dir.create(file.path(out, "audit2-batches"), showWarnings = FALSE)
dir.create(file.path(out, "audit2-out"),     showWarnings = FALSE)

seed <- fread(file.path(out, "FINDINGS-SEED.csv"), colClasses = "character")
ai   <- fread(file.path(out, "audit-index.csv"), colClasses = "character")
xw   <- fread(file.path(out, "EFILE-XWALK.tsv"), sep="\t", colClasses="character", quote="")
nm   <- fread(file.path(out, "EFILE-NAMES.tsv"), sep="\t", colClasses="character", quote="")
pp   <- fread(file.path(out, "PP-CACHE.tsv"), sep="\t", colClasses="character", quote="")

s <- seed[uei %chin% ai$uei]
s <- merge(s, ai[, .(uei, batch)], by = "uei")
cat("audit cases:", nrow(s), "\n")

dom <- function(u) {
  u <- tolower(trimws(u)); u <- sub("^[a-z]+://","",u); u <- sub("^www[0-9]?\\.","",u)
  u <- sub("[/?#].*$","",u); u <- sub(":.*$","",u); u <- sub("\\.+$","",u)
  u[!grepl("\\.",u) | nchar(u) < 4] <- ""; u
}
s[, sam_dom := dom(sam_url)]

fmt_x <- function(d) paste0(sprintf("%s | %s | %s, %s %s | web=%s | officer=%s | formed=%s | filed %s yrs thru %s",
    d$ein, d$name, d$city, d$state, d$zip, d$web_domain, d$officer,
    d$year_formed, d$years_filed, d$last_tax_year), collapse = " ;; ")

## efile hit by website domain
hd <- merge(s[sam_dom != "", .(uei, sam_dom)], xw[web_domain != ""],
            by.x = "sam_dom", by.y = "web_domain", allow.cartesian = TRUE)
hd <- hd[, .(efile_by_domain = fmt_x(.SD[1:min(.N,5)])), by = uei]

## efile hit by name-as-filed / dba
hn <- merge(s[q_nk_ds != "", .(uei, q_nk_ds)], nm, by.x = "q_nk_ds",
            by.y = "variant_key", allow.cartesian = TRUE)
hn <- merge(hn, xw, by = "ein", allow.cartesian = TRUE)
hn <- hn[, .(efile_by_name = fmt_x(.SD[1:min(.N,5)])), by = uei]

## cached ProPublica, keyed on the same distinctive-name query the prefetcher used
STOP <- c("INC","INCORPORATED","CORP","CORPORATION","CO","COMPANY","LLC","LTD","THE","OF",
          "AND","FOR","A","AN","FOUNDATION","TRUST","FUND","ASSOCIATION","ASSOC","SOCIETY",
          "CENTER","CENTRE","INSTITUTE","COUNCIL","ORGANIZATION","ORG","GROUP","SERVICES",
          "SERVICE","PROJECT","PROGRAM","NONPROFIT","NON","PROFIT","USA","US","AMERICA",
          "AMERICAN","NATIONAL","INTERNATIONAL","COMMUNITY")
distinctive <- function(nm_) {
  x <- toupper(gsub("[^A-Za-z0-9 ]", " ", nm_))
  w <- setdiff(strsplit(trimws(gsub(" +"," ",x)), " ")[[1]], STOP)
  if (!length(w)) w <- strsplit(trimws(gsub(" +"," ",x)), " ")[[1]]
  paste(head(w, 4), collapse = " ")
}
s[, pp_query := vapply(sam_name, distinctive, "")]
s <- merge(s, pp[, .(query, pp_http = http, pp_n = total_results, pp_results = results)],
           by.x = "pp_query", by.y = "query", all.x = TRUE)

s <- merge(s, hd, by = "uei", all.x = TRUE)
s <- merge(s, hn, by = "uei", all.x = TRUE)
cat("with an efile domain hit:", sum(!is.na(s$efile_by_domain)),
    " | efile name hit:", sum(!is.na(s$efile_by_name)),
    " | cached ProPublica:", sum(!is.na(s$pp_http)), "\n")

blk <- function(l, x) if (length(x) && !is.na(x) && nzchar(x)) sprintf("- %s: %s\n", l, x) else ""
for (b in sort(unique(s$batch))) {
  d <- s[batch == b]
  txt <- sprintf("# Gate audit (rev 2) batch %s  (%d cases)\n\n", b, nrow(d))
  for (i in seq_len(nrow(d))) {
    x <- d[i]
    ppline <- if (is.na(x$pp_http)) "" else
      sprintf("%s results (HTTP %s)%s", x$pp_n, x$pp_http,
              if (nzchar(x$pp_results)) paste0(" :: ", x$pp_results) else "")
    txt <- paste0(txt, sprintf("\n## CASE %d of %d\n", i, nrow(d)),
      blk("uei", x$uei), blk("run", x$run), blk("no_stage", x$stage),
      blk("SAM legal name", x$sam_name), blk("SAM dba", x$sam_dba),
      blk("SAM address", paste(na.omit(c(x$sam_street1, x$sam_street2)), collapse=" ")),
      blk("SAM city/state/zip", paste(x$sam_city, x$sam_state, x$sam_zip)),
      blk("SAM mailing", paste(na.omit(c(x$sam_mail_street, x$sam_mail_city,
                                         x$sam_mail_state, x$sam_mail_zip)), collapse=" ")),
      blk("SAM url", x$sam_url),
      blk("SAM entity structure", x$sam_entity_structure),
      blk("SAM state of incorporation", x$sam_state_incorp),
      blk("SAM business types", x$sam_bus_type),
      blk("SAM contact", paste(na.omit(c(x$sam_poc_first, x$sam_poc_last, x$sam_poc_title)), collapse=" ")),
      blk("BMF exact name-key lookup", x$bmf_lookup),
      blk("EFILE 990 filers sharing this website domain", x$efile_by_domain),
      blk("EFILE 990 filers matching this name-as-filed", x$efile_by_name),
      blk("ProPublica (CACHED - do not re-query)", ppline),
      blk("Stage-2: candidates the LLM saw", x$candidates),
      blk("Stage-2: LLM rejection reason", x$llm_reason))
  }
  writeLines(txt, file.path(out, "audit2-batches", sprintf("audit2-%s.md", b)))
}
cat("batches:", length(unique(s$batch)), "\n")
