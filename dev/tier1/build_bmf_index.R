suppressMessages(library(data.table))
t0 <- Sys.time(); say <- function(...) cat(sprintf("[%s] ",format(Sys.time(),"%H:%M:%S")),...,"\n")
base <- "C:/Users/jdlec/Dropbox/00 - URBAN/00-GITHUB/npmatch"
say("loading unified BMF (3.69M rows)")
u <- fread(file.path(base,"data-raw/bmf_unified_geocoded.csv"),
  select=c("ein","org_name_join","dba_name","org_addr_state","org_addr_city","org_addr_zip5",
           "in_care_of_name_clean","subsection_code"), colClasses=list(character="ein"))
setnames(u, c("ein","org_name_join","dba_name","org_addr_state","org_addr_city","org_addr_zip5",
              "in_care_of_name_clean","subsection_code"),
             c("ein","name","dba","state","city","zip5","care_of","subsection"))
say("normalizing names")
clean <- function(x){ x<-toupper(as.character(x)); x[is.na(x)]<-""
  x<-gsub("&"," AND ",x,fixed=TRUE); x<-gsub("[^A-Z0-9 ]"," ",x); trimws(gsub("\\s+"," ",x)) }
suf <- "( INC| INCORPORATED| CORP| CORPORATION| CO| COMPANY| LLC| LTD| LP| LLP| PC| PLLC| FOUNDATION| FDN| FUND| TRUST| SOCIETY| INSTITUTE| ASSOCIATION| ASSN| ASSOC| ORGANIZATION| ORG| NFP)$"
strip <- function(x){ x<-sub("^THE ","",x); for(i in 1:3){ y<-trimws(sub(suf,"",x)); if(all(y==x,na.rm=TRUE)) break; x<-y }; x }
u[, nk := strip(clean(name))]
u[, nk_ds := gsub(" ","",nk)]                                   # de-spaced (STEP FORWARD -> STEPFORWARD)
u[, dk := strip(clean(dba))]
act <- unique(fread(file.path(base,"data-raw/bmf_2026_01_processed.csv"), select="ein",
                    colClasses=list(character="ein"))$ein)
u[, active := ein %in% act]
say(sprintf("rows %s | active %s | inactive %s | distinct nk %s",
    format(nrow(u),big.mark=","), format(sum(u$active),big.mark=","),
    format(sum(!u$active),big.mark=","), format(uniqueN(u$nk),big.mark=",")))
setkey(u, nk)
saveRDS(u, file.path(base,"data-dev/BMF-NAME-INDEX.rds"))
say("saved BMF-NAME-INDEX.rds", round(difftime(Sys.time(),t0,units="mins"),1),"min")
