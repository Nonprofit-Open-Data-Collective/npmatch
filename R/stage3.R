# ---------------------------------------------------------------------------
# Stage 3: research the NO cases.
#
# Most NO cases are not near-misses -- they are entities that could never have
# matched: foreign registrants, for-profit legal forms, government units, sole
# proprietors. Classifying those deterministically before any lookup is what
# makes the stage affordable; only what survives the screen is researched.
#
# The rules are exported (np_gate_rules) rather than buried here, because they
# encode judgement about what counts as a government unit or a church, and that
# judgement should be inspectable and overridable rather than implicit.
# ---------------------------------------------------------------------------

#' Entity-gate rules
#'
#' The patterns [np_entity_gate()] uses to classify a source record from its
#' legal name and SAM structure code, before any lookup. Returned as data so
#' they can be inspected, edited and passed back in.
#'
#' Each element is a case-insensitive regular expression matched against the
#' upper-cased legal name, except `us_states` (the set treated as domestic) and
#' `structure_*` (exact SAM entity-structure codes).
#'
#' @return A named list of patterns.
#' @seealso [np_entity_gate()], [np_stage3_run()].
#' @examples
#' names(np_gate_rules())
#' np_gate_rules()$tribal
#' @export
np_gate_rules <- function() {
  B <- "\\b"
  list(
    us_states = c(datasets::state.abb, "DC", "PR", "VI", "GU", "AS", "MP",
                  "FM", "MH", "PW"),
    structure_individual   = "2J",     # sole proprietorship
    structure_not_exempt   = "2L",     # corporate entity, not tax exempt
    for_profit_form = paste0(B, "(LLC|L L C|LLP|LLLP|PLLC)", B,
                             "| LLC$| LP$| LLP$| PLLC$| PC$| INC CO$"),
    government = paste0(
      "^(CITY OF|COUNTY OF|TOWN OF|VILLAGE OF|TOWNSHIP OF|BOROUGH OF|STATE OF|",
      "COMMONWEALTH OF)|", B,
      "(SCHOOL DISTRICT|HOUSING AUTHORITY|PUBLIC LIBRARY|TRANSIT AUTHORITY|",
      "PORT AUTHORITY|AIRPORT AUTHORITY|COUNCIL OF GOVERNMENTS|SHERIFF|",
      "POLICE DEPARTMENT|FIRE DISTRICT|WATER DISTRICT|SEWER DISTRICT|",
      "UTILITY DISTRICT|CONSERVATION DISTRICT|BOARD OF EDUCATION|",
      "UNIFIED SCHOOL|COMMUNITY COLLEGE DISTRICT|PUBLIC SCHOOLS)", B),
    tribal = paste0(B, "(TRIBE|TRIBAL|NATION OF|BAND OF|PUEBLO OF|RANCHERIA|",
                    "NATIVE VILLAGE)", B),
    church = paste0(B, "(CHURCH|CHAPEL|PARISH|MINISTR|MISSION|SYNAGOGUE|MOSQUE|",
                    "MASJID|TEMPLE|CONGREGATION|DIOCESE|CATHEDRAL|ASSEMBLY OF GOD|",
                    "BAPTIST|METHODIST|LUTHERAN|PRESBYTERIAN|EPISCOPAL|",
                    "PENTECOSTAL|EVANGEL)", B),
    person_name = "^[A-Z]+ [A-Z] [A-Z]+$|^[A-Z]+ [A-Z]+$|^[A-Z]+ [A-Z]+ [A-Z]+$",
    person_not  = paste0(B, "(FOUNDATION|CHURCH|MINISTR|ASSOCIATION|SOCIETY|CENTER|",
                         "CENTRE|INSTITUTE|COUNCIL|FUND|TRUST|ALLIANCE|NETWORK|CLUB|",
                         "LEAGUE|CORPS|ACADEMY|SCHOOL|COLLEGE|HOUSE|PROJECT|GROUP|",
                         "SERVICES|INC|LLC|COMPANY|FARM)", B)
  )
}

#' Classify source records before research
#'
#' Applies [np_gate_rules()] to decide what kind of entity each source record
#' is, from its legal name and SAM structure code alone. This is the screen that
#' settles most NO cases without any lookup.
#'
#' Categories are assigned in priority order: `foreign`, `individual`,
#' `government`, `tribal_government`, `for_profit_form`, `not_tax_exempt_corp`,
#' `church`, then `nonprofit_candidate` for anything left. The order matters —
#' a foreign government unit is reported as foreign, because being outside the
#' BMF's scope is the more basic fact about it.
#'
#' @param data A data frame of source records.
#' @param name,state Columns holding the legal name and the physical-address
#'   state. `name` is required.
#' @param structure,state_incorp Optional columns holding the SAM entity
#'   structure code and the state of incorporation. Without `structure`, the
#'   `individual` and `not_tax_exempt_corp` categories cannot fire.
#' @param rules Rule set. Defaults to [np_gate_rules()].
#' @return `data` with `entity_gate` and `foreign_us_incorp` appended.
#' @seealso [np_gate_rules()], [np_stage3_run()].
#' @examples
#' d <- data.frame(name = c("ACME HOLDINGS LLC", "CITY OF AUSTIN",
#'                          "FIRST BAPTIST CHURCH", "RIVER ARTS COUNCIL"),
#'                 state = "TX")
#' np_entity_gate(d)$entity_gate
#' @export
np_entity_gate <- function(data, name = "name", state = "state",
                           structure = NULL, state_incorp = NULL,
                           rules = np_gate_rules()) {
  data <- as.data.frame(data, stringsAsFactors = FALSE)
  if (!name %in% names(data))
    stop("`data` has no column '", name, "'.", call. = FALSE)
  n  <- nrow(data)
  nm <- toupper(trimws(as.character(data[[name]])))
  nm[is.na(nm)] <- ""
  get <- function(col) if (!is.null(col) && col %in% names(data))
    as.character(data[[col]]) else rep(NA_character_, n)
  st  <- get(state); str <- get(structure); inc <- get(state_incorp)
  hit <- function(p) grepl(p, nm, perl = TRUE)

  foreign     <- !is.na(st) & !(st %in% rules$us_states)
  person_like <- !is.na(str) & str == rules$structure_individual &
    hit(rules$person_name) & !hit(rules$person_not)
  not_exempt  <- !is.na(str) & str == rules$structure_not_exempt

  gate <- rep("nonprofit_candidate", n)
  # last assignment wins, so apply in reverse priority order
  gate[hit(rules$church)]          <- "church"
  gate[not_exempt]                 <- "not_tax_exempt_corp"
  gate[hit(rules$for_profit_form)] <- "for_profit_form"
  gate[hit(rules$tribal)]          <- "tribal_government"
  gate[hit(rules$government)]      <- "government"
  gate[person_like]                <- "individual"
  gate[foreign]                    <- "foreign"

  data$entity_gate <- gate
  data$foreign_us_incorp <- gate == "foreign" & !is.na(inc) & inc %in% rules$us_states
  data
}

# Deterministic determinations the gate can settle without a lookup, and the
# justification recorded for each. medium confidence on 2L because SAM's own
# flag is unreliable -- which is also why it always escapes to research.
.np_gate_seed <- list(
  individual = list("not_a_nonprofit", "high",
    "SAM entity structure 2J (sole proprietorship) + person-form legal name",
    "Registrant is an individual/sole proprietor, not an organization."),
  for_profit_form = list("not_a_nonprofit", "high",
    "SAM legal business name carries a for-profit legal form (LLC/LP/PLLC)",
    "For-profit legal form; not an IRS-recognized exempt organization."),
  government = list("not_a_nonprofit", "high",
    "SAM legal business name is a government unit",
    "Government unit, not a 501(c) filer."),
  not_tax_exempt_corp = list("not_a_nonprofit", "medium",
    "SAM entity structure 2L = corporate entity, NOT tax exempt",
    "SAM reports the registrant as a non-tax-exempt corporation."),
  foreign = list("nonprofit_not_in_bmf", "high",
    "SAM physical address outside the US; no US state of incorporation",
    "Foreign entity, outside the scope of the IRS BMF."))

.np_stage3_taxonomy <- c("match", "not_a_nonprofit", "nonprofit_not_in_bmf",
                         "cant_determine")

# Count fields by TABS, not by strsplit(): strsplit drops trailing empty strings,
# so a legitimate row ending in an empty `notes` field reads one field short and
# is falsely reported ragged.
.np_tsv_fields <- function(path, expect) {
  ln <- readLines(path, warn = FALSE)
  if (length(ln) < 2L) return(0L)
  ln <- ln[-1]; ln <- ln[nzchar(ln)]
  nf <- vapply(gregexpr("\t", ln, fixed = TRUE),
               function(m) if (m[1] == -1L) 1L else length(m) + 1L, 0L)
  sum(nf != expect)
}

.np_stage3_fields <- c("uei", "sam_name", "run", "stage", "ein_found",
                       "determination", "resolving_tier", "confidence",
                       "sources", "judgement", "notes")

#' Run stage 3 - LLM research of the NO cases
#'
#' Resumable, like [np_stage2_run()], because a research agent sits in the
#' middle:
#'
#' * **First call** — pools the NO cases from the stages named in `sources`,
#'   applies the [np_entity_gate()] screen, settles what it can deterministically,
#'   and writes research packets to `03_stage3/batches/packets/`. Point an agent
#'   at `03_stage3/PROMPT.md`; it writes one `run-<NNNN>.tsv` per packet to
#'   `03_stage3/batches/out/`.
#' * **Second call** — folds those results onto the seed and writes
#'   `stage3_yes`, `stage3_no` and `stage3_research_findings`.
#'
#' @section What the screen settles for free:
#' Foreign registrants, for-profit legal forms, government units and sole
#' proprietors get a determination and high confidence without any lookup. An
#' escape hatch overrides the screen where there is contrary evidence — a hit in
#' `bmf_index`, an unreliable SAM 2L flag, or a 990 filer sharing the registrant
#' website (`efile_domains`) — so a seeded case with a reason to doubt it is
#' still researched.
#'
#' @section The `match` constraint:
#' A `match` must resolve to an EIN the reference actually contains. An EIN that
#' is real but absent from this reference vintage is reclassified to
#' `nonprofit_not_in_bmf` with the EIN retained, because a match the crosswalk
#' cannot join is not a match.
#'
#' @param project Project root. Defaults to [np_project_root()].
#' @param sources Which stages' NO files to research. Default both; pass
#'   `"stage1_no"` to research only what the matcher rejected outright.
#' @param source_data Optional frame of source attributes (the prepared SAM
#'   query) keyed by `uei`, to enrich the packets beyond name alone.
#' @param bmf_index Optional data frame with an `ein` column (and optionally
#'   `name`) used both for the escape hatch and to enforce the `match`
#'   constraint on collection.
#' @param efile_domains Optional character vector of web domains known to belong
#'   to 990 filers, for the escape hatch.
#' @param packet_size Cases per research packet. Default 8.
#' @param rules Entity-gate rules. Defaults to [np_gate_rules()].
#' @param verbose Print progress. Default `TRUE`.
#' @return Invisibly: the findings once results exist, otherwise the seed frame.
#' @seealso [np_entity_gate()], [np_stage2_run()], [np_final_run()].
#' @export
np_stage3_run <- function(project = np_project_root(),
                          sources = c("stage1_no", "stage2_no"),
                          source_data = NULL, bmf_index = NULL,
                          efile_domains = NULL, packet_size = 8L,
                          rules = np_gate_rules(), verbose = TRUE) {
  say <- function(...) if (verbose) message(sprintf(...))
  if (is.na(project))
    stop("no active npmatch project; call np_project_init() or np_project_use().",
         call. = FALSE)
  run_id <- attr(np_project_status(project, write = FALSE, quiet = TRUE), "run_id")

  pk_dir  <- np_project_path("03_stage3", "batches/packets", create = TRUE, project = project)
  out_dir <- np_project_path("03_stage3", "batches/out",     create = TRUE, project = project)
  seed_f  <- np_project_path("03_stage3", "interim/stage3_seed.csv", create = TRUE,
                             project = project)

  # ---- prepare --------------------------------------------------------------
  if (!file.exists(seed_f)) {
    where <- c(stage1_no = "01_stage1", stage2_no = "02_stage2")
    pool <- do.call(rbind, lapply(sources, function(s) {
      if (!s %in% names(where))
        stop("unknown source '", s, "'; use stage1_no and/or stage2_no.", call. = FALSE)
      d <- .np_read_outcomes(where[[s]], paste0(s, ".csv"), project)
      if (nrow(d)) d$no_origin <- if (s == "stage1_no") "algorithm" else "llm_maybe_to_no"
      d
    }))
    if (is.null(pool) || !nrow(pool))
      stop("no NO cases found in: ", paste(sources, collapse = ", "),
           "\n  run np_stage1_run() (and np_stage2_run()) first.", call. = FALSE)
    pool <- pool[!duplicated(pool$uei), , drop = FALSE]

    a <- data.frame(uei = pool$uei, run = run_id, stage = pool$stage,
                    no_origin = pool$no_origin, sam_name = pool$name_source,
                    rejected_reason = pool$reason, confidence_in = pool$confidence,
                    stringsAsFactors = FALSE)
    if (!is.null(source_data)) {
      sd <- as.data.frame(source_data, stringsAsFactors = FALSE)
      idc <- intersect(c("uei", "unique_entity_id", ".id"), names(sd))[1]
      if (!is.na(idc)) {
        i <- match(a$uei, as.character(sd[[idc]]))
        for (cl in setdiff(names(sd), idc))
          a[[paste0("sam_", sub("^sam_", "", cl))]] <- as.character(sd[[cl]])[i]
      }
    }
    nmcol <- if (all(!nzchar(a$sam_name)) && "sam_name" %in% names(a)) "sam_name" else "sam_name"
    a <- np_entity_gate(a, name = nmcol,
                        state = if ("sam_state" %in% names(a)) "sam_state" else NULL,
                        structure = if ("sam_entity_structure" %in% names(a))
                          "sam_entity_structure" else NULL,
                        state_incorp = if ("sam_state_incorp" %in% names(a))
                          "sam_state_incorp" else NULL,
                        rules = rules)

    for (f in c("ein_found", "determination", "resolving_tier", "confidence",
                "sources", "judgement", "notes")) a[[f]] <- ""
    for (g in names(.np_gate_seed)) {
      s <- .np_gate_seed[[g]]
      i <- a$entity_gate == g
      if (g == "foreign") i <- i & !a$foreign_us_incorp
      a$determination[i] <- s[[1]]; a$confidence[i] <- s[[2]]
      a$sources[i] <- s[[3]];       a$judgement[i] <- s[[4]]
      a$resolving_tier[i] <- "tier1"
    }

    # escape hatch: contrary evidence overrides a seeded determination
    bmf_hit <- rep(FALSE, nrow(a))
    if (!is.null(bmf_index) && "name" %in% names(bmf_index))
      bmf_hit <- toupper(trimws(a$sam_name)) %in%
        toupper(trimws(as.character(bmf_index$name)))
    dom_hit <- rep(FALSE, nrow(a))
    if (!is.null(efile_domains) && "sam_url" %in% names(a)) {
      dm <- tolower(sub("^www[0-9]?\\.", "", sub("^[a-z]+://", "",
                                                 trimws(as.character(a$sam_url)))))
      dm <- sub("[/?#:].*$", "", dm); dm[is.na(dm)] <- ""
      dom_hit <- nzchar(dm) & dm %in% tolower(efile_domains)
    }
    a$bmf_name_hit <- bmf_hit
    a$efile_domain_hit <- dom_hit
    escape <- bmf_hit | dom_hit | a$entity_gate == "not_tax_exempt_corp"
    a$determination[escape] <- ""; a$confidence[escape] <- ""
    a$sources[escape] <- "";       a$judgement[escape] <- ""
    a$resolving_tier[escape] <- ""

    a$web <- !nzchar(a$determination) | a$foreign_us_incorp
    a$web_reason <- ifelse(
      a$foreign_us_incorp, "foreign_address_but_us_incorporated",
      ifelse(dom_hit, "efile_990_filer_shares_this_website",
      ifelse(bmf_hit, "bmf_name_hit_contradicts_screen",
      ifelse(a$entity_gate == "not_tax_exempt_corp", "sam_2L_flag_unreliable",
      ifelse(a$entity_gate == "church", "church_may_or_may_not_be_in_bmf",
      ifelse(a$entity_gate == "tribal_government", "tribal_entity",
             "open_nonprofit_candidate"))))))
    a$web_reason[!a$web] <- ""        # a settled case was never queued for the web
    data.table::fwrite(a, seed_f)

    q <- a[a$web, , drop = FALSE]
    if (nrow(q)) {
      q <- q[order(q$web_reason, q$uei), , drop = FALSE]
      q$packet <- ceiling(seq_len(nrow(q)) / packet_size)
      blk <- function(lab, v) if (length(v) && !is.na(v) && nzchar(v))
        sprintf("- %s: %s", lab, v) else NULL
      for (b in unique(q$packet)) {
        sub <- q[q$packet == b, , drop = FALSE]
        lines <- c(sprintf("# Research packet %04d - run %s", b, run_id), "",
                   sprintf("%d case(s). Follow `03_stage3/PROMPT.md`.", nrow(sub)),
                   sprintf("Write results to `batches/out/run-%04d.tsv`.", b), "")
        for (i in seq_len(nrow(sub))) {
          r <- sub[i, ]
          lines <- c(lines, sprintf("## %d. %s", i, r$sam_name), "",
            blk("uei", r$uei), blk("no_stage", r$stage),
            blk("why_this_needs_web", r$web_reason),
            blk("entity_gate", r$entity_gate),
            blk("rejected_because", r$rejected_reason),
            unlist(lapply(grep("^sam_", names(r), value = TRUE), function(cl)
              if (cl != "sam_name") blk(cl, r[[cl]]) else NULL)), "")
        }
        writeLines(lines, file.path(pk_dir, sprintf("run-%04d.md", b)))
      }
      data.table::fwrite(q[, c("uei", "packet", "stage", "web_reason")],
                         np_project_path("03_stage3", "interim/queue.csv",
                                         project = project))
    }
    say(paste0("stage 3 prepared: %s case(s) pooled, %s settled by the screen, ",
               "%s queued in %d packet(s)\n",
               "  next: point an agent at 03_stage3/PROMPT.md, then re-run np_stage3_run()"),
        format(nrow(a), big.mark = ","),
        format(sum(!a$web), big.mark = ","), format(sum(a$web), big.mark = ","),
        length(unique(q$packet)))
    np_project_status(project, write = TRUE, quiet = TRUE)
    return(invisible(a))
  }

  # ---- collect --------------------------------------------------------------
  a <- as.data.frame(data.table::fread(seed_f, colClasses = "character",
                                       showProgress = FALSE))
  a$web <- a$web %in% c("TRUE", "true", TRUE)
  tsv <- sort(list.files(out_dir, "^run-[0-9]+[.]tsv$", full.names = TRUE))
  if (!length(tsv)) {
    say(paste0("stage 3: %d packet(s) awaiting research in %s\n",
               "  follow 03_stage3/PROMPT.md, write run-<NNNN>.tsv to %s"),
        length(list.files(pk_dir, "[.]md$")), pk_dir, out_dir)
    return(invisible(NULL))
  }

  ragged <- vapply(tsv, .np_tsv_fields, 0L, expect = length(.np_stage3_fields))
  res <- data.table::rbindlist(lapply(tsv, function(f) {
    x <- tryCatch(data.table::fread(f, sep = "\t", colClasses = "character",
                                    quote = "", fill = TRUE, showProgress = FALSE),
                  error = function(e) NULL)
    if (is.null(x) || !nrow(x)) return(NULL)
    for (cl in setdiff(.np_stage3_fields, names(x))) x[[cl]] <- ""
    x <- x[, .np_stage3_fields, with = FALSE]
    x$batch_file <- basename(f)
    x
  }), fill = TRUE)
  res <- as.data.frame(res, stringsAsFactors = FALSE)
  res <- res[!duplicated(res$uei), , drop = FALSE]

  i <- match(a$uei, res$uei)
  a$researched <- !is.na(i)
  for (f in c("ein_found", "determination", "resolving_tier", "confidence",
              "sources", "judgement", "notes")) {
    v <- res[[f]][i]
    a[[f]][!is.na(i) & !is.na(v) & nzchar(v)] <- v[!is.na(i) & !is.na(v) & nzchar(v)]
  }

  # a match must resolve to an EIN the reference contains
  reclass <- 0L
  if (!is.null(bmf_index) && "ein" %in% names(bmf_index)) {
    have <- .np_ein_digits(bmf_index$ein)
    bad <- a$determination == "match" & nzchar(a$ein_found) &
      !(.np_ein_digits(a$ein_found) %in% have)
    reclass <- sum(bad)
    if (reclass) {
      a$determination[bad] <- "nonprofit_not_in_bmf"
      a$notes[bad] <- paste0(a$notes[bad],
        " ;; RECLASSIFIED: agent called this a match but the EIN is not in this ",
        "reference vintage, so the crosswalk cannot join it. EIN retained.")
    }
  }
  # many source ids legitimately resolve to one parent EIN (federated networks);
  # flag rather than hide, since a many-to-one behaves differently downstream
  m <- a$determination == "match" & nzchar(a$ein_found)
  cnt <- table(a$ein_found[m])
  a$federated_parent <- m & a$ein_found %in% names(cnt)[cnt >= 8L]

  data.table::fwrite(a, np_project_path("03_stage3", "stage3_research_findings.csv",
                                        project = project))

  ok  <- a$determination == "match" & nzchar(a$ein_found)
  frame <- data.frame(
    uei = a$uei, run_id = run_id, stage = "3",
    outcome = ifelse(ok, "YES", "NO"),
    ein = ifelse(ok, a$ein_found, ""),
    name_source = a$sam_name, name_reference = "", score = "",
    decided_by = "llm_research", confidence = a$confidence,
    reason = ifelse(nzchar(a$determination), a$determination, "unresolved"),
    stringsAsFactors = FALSE)
  .np_write_outcomes(frame, "03_stage3", "stage3", project)

  det <- table(factor(a$determination, c(.np_stage3_taxonomy, "")))
  pend <- sum(a$web & !a$researched)
  offtax <- sum(a$researched & !(a$determination %in% .np_stage3_taxonomy))
  data.table::fwrite(
    data.frame(determination = names(det), n = as.integer(det),
               stringsAsFactors = FALSE),
    np_project_path("03_stage3", "STAGE3-STATS.csv", project = project))
  writeLines(c(
    sprintf("# Stage 3 - %s", run_id), "",
    sprintf("_generated %s_", format(Sys.time(), "%Y-%m-%d %H:%M:%S")), "",
    sprintf("- pooled from: %s", paste(sources, collapse = ", ")),
    sprintf("- cases: %s | settled by the screen: %s | researched: %s",
            format(nrow(a), big.mark = ","), format(sum(!a$web), big.mark = ","),
            format(sum(a$researched), big.mark = ",")), "",
    "| determination | n |", "|---|---|",
    sprintf("| %s | %s |", .np_stage3_taxonomy,
            format(as.integer(det[.np_stage3_taxonomy]), big.mark = ",")),
    "", "## Data quality", "",
    sprintf("- packets read: %d (ragged rows recovered: %d)", length(tsv), sum(ragged)),
    sprintf("- off-taxonomy determinations: %d", offtax),
    sprintf("- matches reclassified (EIN absent from the reference): %d", reclass),
    sprintf("- federated parent rows (one EIN claimed by >=8 ids): %d",
            sum(a$federated_parent)),
    if (pend)
      sprintf("- **%s queued case(s) returned nothing** - a hole, not a NO. Re-run those packets.",
              format(pend, big.mark = ","))
    else "- every queued case returned a result"
  ), np_project_path("03_stage3", "STAGE3-REPORT.md", project = project))

  if (pend)
    warning(pend, " queued stage-3 case(s) returned no agent row; they carry ",
            "determination \"\" and outcome NO with reason \"unresolved\". ",
            "See STAGE3-REPORT.md.", call. = FALSE)
  if (sum(ragged))
    warning(sum(ragged), " ragged row(s) recovered with fill; if the missing ",
            "field was not `notes`, those rows are column-shifted.", call. = FALSE)

  say("stage 3 done: match %s | not_a_nonprofit %s | not_in_bmf %s | cant_determine %s%s",
      format(det[["match"]], big.mark = ","),
      format(det[["not_a_nonprofit"]], big.mark = ","),
      format(det[["nonprofit_not_in_bmf"]], big.mark = ","),
      format(det[["cant_determine"]], big.mark = ","),
      if (pend) sprintf(" | %d pending", pend) else "")
  np_project_status(project, write = TRUE, quiet = TRUE)
  invisible(a)
}
