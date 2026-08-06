# Compact fixtures drawn from the reclin2 prototype (AK subset).

np_test_reference <- function() {
  data.frame(
    ein = c("05","10","11","14","09","08"),
    name = c("SALMON CREEK HOUSING INC", "ANCHORAGE SYMPHONY ORCHESTRA",
             "ALASKA INJURY PREVENTION CENTER", "NOME COMMUNITY CENTER INC",
             "FAIRBANKS CONCERT ASSOCIATION", "ANCHORAGE CONCERT FOUNDATION"),
    street = c("3406 GLACIER HWY", "430 W 7TH AVE STE 202", "4241 B ST STE 100",
               "104 DIVISION ST", "PO BOX 80547", "430 W 7TH AVE STE 200"),
    city = c("JUNEAU","ANCHORAGE","ANCHORAGE","NOME","FAIRBANKS","ANCHORAGE"),
    state = "AK",
    zip = c("99801-9501","99501-3550","99503-5920","99762-0000","99708-0547","99501-3550"),
    dba_name = "",
    stringsAsFactors = FALSE
  )
}

np_test_query <- function() {
  data.frame(
    unique_entity_id = c("q1","q2","q3","q4"),
    name = c("SALMON CREEK HOUSING", "ANCHORAGE SYMPHONY ORCHESTRA",
             "THE ALASKA INJURY PREVENTION CENTER", "NOME COMMUNITY CENTER INC."),
    dba_name = "",
    street = c("3406 GLACIER HWY STE A", "430 W 7TH AVE STE 202",
               "4241 B ST STE 100", "104 DIVISION RD"),
    city = c("JUNEAU","ANCHORAGE","ANCHORAGE","NOME"),
    state = "AK",
    zip = c("99801","99501","99503","99762"),
    stringsAsFactors = FALSE
  )
}

np_test_map_q <- c(.id = "unique_entity_id", name = "name", dba = "dba_name",
                   street = "street", city = "city", state = "state", zip5 = "zip")
np_test_map_r <- c(.ein = "ein", name = "name", dba = "dba_name",
                   street = "street", city = "city", state = "state", zip5 = "zip")
