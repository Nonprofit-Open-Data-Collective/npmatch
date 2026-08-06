# =============================================================================
# Organization Record Linkage using reclin2
# Matches on: name + address fields
# Blocking variable: state
# =============================================================================

library( reclin2 )
library( dplyr )
library( stringr )
library( data.table )

# =============================================================================
# 1. LOAD & PREPARE DATA
# =============================================================================

# For illustration, small example frames are included.
# Remove/replace these with your actual data loading above.
df <- data.frame(
  legal_business_name                  = c("Acme Corp", "Widget LLC", "Globex Inc"),
  physical_address_line_1              = c("123 Main St", "456 Oak Ave", "789 Pine Rd"),
  physical_address_city                = c("Phoenix", "Tucson", "Scottsdale"),
  physical_address_province_or_state   = c("AZ", "AZ", "AZ"),
  physical_address_zip_postal_code     = c("85001", "85701", "85251"),
  check.names = FALSE,
  stringsAsFactors = FALSE
)

bmf <- data.frame(
  org_name_display = c("Acme Corporation", "Widgets LLC", "Globex Incorporated"),
  org_addr_street  = c("123 Main Street", "456 Oak Avenue", "789 Pine Road"),
  org_addr_city    = c("Phoenix", "Tucson", "Scottsdale"),
  org_addr_state   = c("AZ", "AZ", "AZ"),
  org_addr_zip     = c("85001", "85701", "85251"),
  stringsAsFactors = FALSE
)

# --- Load your datasets here ---
df_full   <- fread( "SAMPLE-1K-NONPROFITS.CSV" )  |> as.data.frame()
bmf_full  <- fread( "bmf_2026_01_processed.csv" ) |> as.data.frame()

df_full <-
  df_full %>%
  filter( 
    physical_address_province_or_state %in% state.abb | 
    mailing_address_state_or_province %in% state.abb ) %>%
  arrange( physical_address_province_or_state )

# =============================================================================
# 2. STANDARDISE FIELD NAMES
#    Rename to simple internal names so the linkage code stays readable.
# =============================================================================

keep1 <- c(
  "unique_entity_id",
  "legal_business_name", 
  "dba_name", 
  "entity_division_name", 
  "entity_division_number", 
  "physical_address_line_1", 
  "physical_address_line_2", 
  "physical_address_city", 
  "physical_address_province_or_state", 
  "physical_address_zip_postal_code",
  "physical_address_country_code",
  "mailing_address_line_1",
  "mailing_address_line_2", 
  "mailing_address_city", 
  "mailing_address_zip_postal_code",
  "mailing_address_state_or_province", 
  "mailing_address_country" )
  
df <- df_full[keep1] %>%
  rename(
    name   = legal_business_name,
    street = physical_address_line_1,
    city   = physical_address_city,
    state  = physical_address_province_or_state,
    zip    = physical_address_zip_postal_code
  ) %>%
  mutate(across(where(is.character), str_squish),          # trim whitespace
         across(where(is.character), str_to_upper))         # normalise case

keep2 <- c(
  "ein",
  "org_name_raw",
  "org_addr_street",
  "org_addr_city",
  "org_addr_state",
  "org_addr_zip",
  "org_parent_name", 
  "org_legal_suffix", 
  "dba_name_raw", 
  "dba_name",
  "subsection_code" )

bmf <- bmf_full[keep2] %>%
  rename(
    name   = org_name_raw,
    street = org_addr_street,
    city   = org_addr_city,
    state  = org_addr_state,
    zip    = org_addr_zip
  ) %>%
  mutate(across(where(is.character), str_squish),
         across(where(is.character), str_to_upper))


 
#------------------

get_matched_names <- function( x, d=bmfs ){
  v1 <- grep( x, d[["name"]], value=TRUE )
  v2 <- grep( x, d[["dba_name"]], value=TRUE )
  return( c(v1,v2) )
}

m1 <- get_matched_names( "SALMON CREEK", bmfs )
m2 <- get_matched_names( "CONCERT" )
m3 <- get_matched_names( "SYMPHONY" )
m4 <- get_matched_names( "INJURY PREVENTION" )
m5 <- get_matched_names( "WOMENS RESOURCE" )
m6 <- get_matched_names( "COMMUNITY CENTER" ) |> head()

cases <- c( m1, m2, m3, m4, m5, m6 )


bmfs <- 
  bmf %>%
  filter( state %in% c("AK","WV","WY") ) %>%
  arrange( state )

fwrite( bmfs, "SAMPLE-BMF.CSV" )

bmfs2 <-
  bmfs %>%
  filter( name %in% cases | dba_name %in% cases )

# TESTING DATASET
# dput( bmfs2 )

bs <-
structure(list(ein = c("27-1710606", "92-0154977", "92-0080948", 
"23-7017298", "02-0713689", "23-7212781", "92-0165950", "92-0161542", 
"92-0094139", "92-6002867", "92-0169574", "92-0070130", "92-6002302", 
"92-0039475", "61-1601701", "20-5230890", "92-0088315", "92-0177037", 
"05-0557685", "82-5499369", "55-0584800", "45-3655643", "23-7427617", 
"55-0711071", "55-0737376", "20-5635406", "31-0897174", "55-0339426", 
"55-6000958", "46-1996321", "14-1967975", "92-2132871", "55-6019164", 
"92-0964860", "27-3017648", "55-6035296", "83-0319008", "83-0329203", 
"56-2321631", "83-6011424", "83-6006472", "83-0247309", "61-1575808", 
"83-0283663", "46-4521935", "31-1784594", "73-1668893"), name = c("GUSTAVUS COMMUNITY CENTER", 
"STERLING COMMUNITY CENTER INC", "JUNEAU SYMPHONY INC", "ANCHORAGE CONCERT CHORUS", 
"SALMON CREEK HOUSING INC", "FAIRBANKS SYMPHONY ASSOC INC", "THE ANCHORAGE SYMPHONY ORCHESTRA ENDOWMENT FOUNDATION", 
"ANCHORAGE CONCERT FOUNDATION", "FAIRBANKS CONCERT ASSOCIATION", 
"ANCHORAGE SYMPHONY ORCHESTRA", "ALASKA INJURY PREVENTION CENTER", 
"KODIAK WOMENS RESOURCE AND CRISIS CENTER", "ANCHORAGE CONCERT ASSOCIATION INC", 
"NOME COMMUNITY CENTER INC", "MAT-SU CONCERT BAND INC", "KETCHIKAN COMMUNITY CONCERT BANDINC", 
"ANCHORAGE COMMUNITY CONCERT", "THE JUNEAU SYMPHONY FOUNDATION", 
"SAMOA IN ALASKA COMMUNITY CENTER ASSEMBLY OF GOD", "TACY COMMUNITY CENTER ASSOCIATION", 
"NATIVE AMERICAN COMMUNITY CENTER INCORPORATED", "WEST VIRGINIA SYMPHONY REGIONAL OUTREACH GROUP INC", 
"HUNTINGTON SYMPHONY ORCHESTRA ASSOCIATION INC", "WEST VIRGINIA YOUTH SYMPHONY INC", 
"MID-OHIO VALLEY SYMPHONY SOCIETY INC", "WEST VIRGINIA SYMPHONY ORCHESTRA FOUNDATION INC", 
"COMPREHENSIVE WOMENS SERVICE COUNCIL INC", "WEST VIRGINIA SYMPHONY ORCHESTRA INC", 
"WHEELING SYMPHONY SOCIETY INC", "CHARLES WASHINGTON SYMPHONY ORCHESTRA CORP", 
"NEW RIVER YOUTH SYMPHONY AND CHORUS", "MONONGALIA SYMPHONY ORCHESTRA INC", 
"BECKLEY CONCERT ASSOCIATION", "SMITH FAMILY CONCERTS", "MOUNTAIN STATE TRAUMA AND INJURY PREVENTION COALITION INC", 
"WHEELING SYMPHONY FUND", "LANDER COMMUNITY CONCERT ASSOCIATION", 
"INJURY PREVENTION RESOURCES - PROMOTING A SAFER WYOMING", "WOMENS RESOURCE CENTER", 
"WYOMING SYMPHONY ORCHESTRA", "CHEYENNE SYMPHONY ORCHESTRA", 
"CHEYENNE SYMPHONY FOUNDATION", "FREMONT SYMPHONY ORCHESTRA", 
"POWDER RIVER SYMPHONY", "CHEYENNE CIVIC CONCERT BAND", "CHEYENNE YOUTH SYMPHONY", 
"SOUTHEAST WYOMING CONCERT SERIES"), street = c("PO BOX 147", 
"PO BOX 15", "522 W 10TH ST BSMT", "PO BOX 241447", "3406 GLACIER HWY", 
"PO BOX 82104", "430 W 7TH AVE STE 202", "430 W 7TH AVE STE 200", 
"PO BOX 80547", "430 W 7TH AVE STE 202", "4241 B ST STE 100", 
"PO BOX 2122", "430 W 7TH AVE STE 200", "104 DIVISION ST", "PO BOX 876685", 
"2417 TONGASS AVE STE 111197", "PO BOX 140615", "PO BOX 21236", 
"PO BOX 93464", "1102 LAUREL CRK RD", "1902 RANGE RD", "PO BOX 2292", 
"763 3RD AVE", "PO BOX 4908", "PO BOX 5511", "4700 MACCORKLE AVE SE STE 101", 
"150 CAMPBELL ST", "PO BOX 2292", "1025 MAIN ST", "PO BOX 1087", 
"PO BOX 177", "433 WESTERN AVE", "PO BOX 2083", "79 SPIVEY RD", 
"2265 MARKET ST", "1 BANK PLZ", "PO BOX 647", "303 N BROADWAY AVE", 
"706 W 8TH ST", "225 S DAVID ST", "PO BOX 851", "525 RANDALL AVE STE 200", 
"45 RUSSIAN OLIVE LN", "501 SINCLAIR ST", "46 LIONHEAD RD", "1634 CROOK AVE", 
"PO BOX 21894"), city = c("GUSTAVUS", "STERLING", "JUNEAU", "ANCHORAGE", 
"JUNEAU", "FAIRBANKS", "ANCHORAGE", "ANCHORAGE", "FAIRBANKS", 
"ANCHORAGE", "ANCHORAGE", "KODIAK", "ANCHORAGE", "NOME", "WASILLA", 
"KETCHIKAN", "ANCHORAGE", "JUNEAU", "ANCHORAGE", "MOATSVILLE", 
"WADESTOWN", "CHARLESTON", "HUNTINGTON", "CHARLESTON", "VIENNA", 
"CHARLESTON", "GLEN WHITE", "CHARLESTON", "WHEELING", "CHARLES TOWN", 
"FAYETTEVILLE", "MORGANTOWN", "BECKLEY", "ELKVIEW", "WHEELING", 
"WHEELING", "LANDER", "RIVERTON", "GILLETTE", "CASPER", "CHEYENNE", 
"CHEYENNE", "LANDER", "GILLETTE", "BUFORD", "CHEYENNE", "CHEYENNE"
), state = c("AK", "AK", "AK", "AK", "AK", "AK", "AK", "AK", 
"AK", "AK", "AK", "AK", "AK", "AK", "AK", "AK", "AK", "AK", "AK", 
"WV", "WV", "WV", "WV", "WV", "WV", "WV", "WV", "WV", "WV", "WV", 
"WV", "WV", "WV", "WV", "WV", "WV", "WY", "WY", "WY", "WY", "WY", 
"WY", "WY", "WY", "WY", "WY", "WY"), zip = c("99826-0147", "99672-0015", 
"99801-1818", "99524-1447", "99801-9501", "99708-2104", "99501-3550", 
"99501-3550", "99708-0547", "99501-3550", "99503-5920", "99615-2122", 
"99501-3550", "99762-0000", "99687-6685", "99901-5900", "99514-0615", 
"99802-1236", "99509-3464", "26405-8409", "26590-8910", "25328-2292", 
"25701-1421", "25364-4908", "26105-5511", "25304-1907", "25849-0000", 
"25328-2292", "26003-2726", "25414-7087", "25840-0177", "26505-2134", 
"25802-2083", "25071-7241", "26003-3839", "26003-3543", "82520-0647", 
"82501-3544", "82716-4109", "82601-7510", "82003-0851", "82001-2772", 
"82520-9737", "82718-6460", "82052-8704", "82001-5324", "82003-7109"
), org_parent_name = c("", "", "", "", "", "", "", "", "", "", 
"", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", 
"", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", 
"", "", "", "", ""), org_legal_suffix = c("", "INC", "INC", "", 
"INC", "INC", "", "", "", "", "", "", "INC", "INC", "INC", "INC", 
"", "", "", "", "INC", "INC", "INC", "INC", "INC", "INC", "INC", 
"INC", "INC", "CORP", "", "INC", "", "", "INC", "", "", "", "", 
"", "", "", "", "", "", "", ""), dba_name_raw = c("", "", "", 
"", "", "", "", "", "", "", "DBA THE CENTER FOR SAFE ALASKANS", 
"", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "WOMENS RESOURCE CENTER", 
"", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", 
"", "", "", ""), dba_name = c("", "", "", "", "", "", "", "", 
"", "", "DBA THE CENTER FOR SAFE ALASKANS", "", "", "", "", "", 
"", "", "", "", "", "", "", "", "", "", "WOMENS RESOURCE CENTER", 
"", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", 
"", "", "", ""), subsection_code = c(3L, 3L, 3L, 3L, 3L, 3L, 
3L, 3L, 3L, 3L, 3L, 3L, 3L, 3L, 3L, 3L, 3L, 3L, 3L, 3L, 3L, 3L, 
3L, 3L, 3L, 3L, 3L, 3L, 3L, 3L, 3L, 3L, 3L, 3L, 3L, 3L, 3L, 3L, 
3L, 3L, 3L, 3L, 3L, 3L, 3L, 3L, 3L)), row.names = c(NA, -47L), class = "data.frame")



# ds <- rbinf( head(df), tail(df) )  # 3 states for blocking
# dput( ds )
# ds <- head( df )  # only alaska
# dput( ds )



ds <- 
structure(list(unique_entity_id = c("ECRJMKLBPTD1", "G3UHEMDQY9L5", 
"J2ZKT3QWEVQ2", "JJG4DKAT2FF3", "D3QJUWJUZAN8", "MHBUPJGHEDH3"
), name = c("SALMON CREEK HOUSING", "FAIRBANKS CONCERT ASSOCIATION, INC.", 
"ANCHORAGE SYMPHONY ORCHESTRA", "THE ALASKA INJURY PREVENTION CENTER", 
"ALASKA NATIVE WOMEN'S RESOURCE CENTER", "NOME COMMUNITY CENTER INC."
), dba_name = c("", "FAIRBANKS CONCERT ASSOCIATION", "", "CENTER FOR SAFE ALASKANS", 
"", ""), entity_division_name = c("", "", "", "", "", ""), entity_division_number = c("", 
"", "", "", "", ""), street = c("3406 GLACIER HWY STE A", "1755 WESTWOOD WAY STE 6", 
"430 W 7TH AVE STE 202", "4241 B ST STE 100", "912 BARNETTE ST", 
"104 DIVISION RD"), physical_address_line_2 = c("", "", "", "", 
"", ""), city = c("JUNEAU", "FAIRBANKS", "ANCHORAGE", "ANCHORAGE", 
"FAIRBANKS", "NOME"), state = c("AK", "AK", "AK", "AK", "AK", 
"AK"), zip = c("99801", "99709", "99501", "99503", "99701", "99762"
), physical_address_country_code = c("USA", "USA", "USA", "USA", 
"USA", "USA"), mailing_address_line_1 = c("3406 GLACIER HWY.", 
"P.O. BOX 80547", "430 W 7TH AVE STE 202", "4241 B ST STE 100", 
"P.O. BOX 80382", "PO BOX 98"), mailing_address_line_2 = c("", 
"", "", "", "", ""), mailing_address_city = c("JUNEAU", "FAIRBANKS", 
"ANCHORAGE", "ANCHORAGE", "FAIRBANKS", "NOME"), mailing_address_zip_postal_code = c("99801", 
"99708", "99501", "99503", "99708", "99762"), mailing_address_state_or_province = c("AK", 
"AK", "AK", "AK", "AK", "AK"), mailing_address_country = c("USA", 
"USA", "USA", "USA", "USA", "USA")), row.names = c(NA, 6L), class = "data.frame")



# =============================================================================
# 3. CREATE PAIR TABLE  (blocking on state)
# =============================================================================
 
# pair_blocking() only compares records that share the same blocking key,
# dramatically reducing the number of candidate pairs.
pairs <- 
  pair_blocking(
    ds, bs, 
    on = "state") |>
  add_from_x( "unique_entity_id", new_variable = "id_x" ) |>
  add_from_y( "ein", new_variable = "id_y" )
 
# Save references now — dplyr verbs will strip x/y attributes from pairs
x_data <- ds
y_data <- bs
 
cat("Candidate pairs after blocking:", nrow(pairs), "\n")
 
# =============================================================================
# 4. COMPARE FIELDS
# =============================================================================
 
# compare_pairs() adds a similarity score column for each field.
# jaro_winkler is well-suited for names; lcs (longest common subsequence)
# works well for street addresses.  Adjust methods to taste.
 
pairs <- compare_pairs(
  pairs,
  on = c("name", "street", "city", "zip"),
  default_comparator = cmp_jarowinkler(threshold = 0.85),  # soft match
  overwrite = TRUE
)

preview_match <- function(v = "name", pairs = pairs) {
  
  x <- attr(pairs, "x")
  y <- attr(pairs, "y")
  
  # Identify ID columns from comparator attributes
  id_x <- attr(pairs[["id_x"]], "on_x")
  id_y <- attr(pairs[["id_y"]], "on_y")
  
  # Get the field names on each side from the comparator attributes
  col_x <- attr(pairs[[v]], "on_x")
  col_y <- attr(pairs[[v]], "on_y")
  
  data.frame(
    .x        = pairs[[".x"]],
    .y        = pairs[[".y"]],
    id_x      = pairs[["id_x"]],
    id_y      = pairs[["id_y"]],
    score     = pairs[[v]],
    val_x     = x[[col_x]][ pairs[[".x"]] ],
    val_y     = y[[col_y]][ pairs[[".y"]] ]
  ) |>
    setNames(c( paste0(v, "_score"),
                paste0(v, "_1"), 
                paste0(v, "_2"),
                ".x",".y","id_x", "id_y" )) |>
    (\(df) df[order(-df[[paste0(v, "_score")]]), ])()
}

preview_match("name",   pairs) |> head(10) 
preview_match("street", pairs) |> head(10) 
preview_match("city",   pairs) |> head(10) 
 



preview_pair <- function(.x = 1, .y = 5, pairs = pairs) {
  
  x <- attr(pairs, "x")
  y <- attr(pairs, "y")
  
  score_cols <- setdiff(names(pairs), c(".x", ".y", "id_x", "id_y", "score"))
  col_meta <- lapply(score_cols, function(v) {
    list(
      on_x = attr(pairs[[v]], "on_x"),
      on_y = attr(pairs[[v]], "on_y")
    )
  })
  names(col_meta) <- score_cols
  
  df_pairs <- as.data.frame(pairs)
  pair_row <- df_pairs[df_pairs[[".x"]] == .x & df_pairs[[".y"]] == .y, ]
  
  if (nrow(pair_row) == 0) {
    stop("No pair found for .x = ", .x, " and .y = ", .y)
  }
  
  ix <- pair_row[[".x"]]
  iy <- pair_row[[".y"]]
  
  rows <- lapply(score_cols, function(v) {
    col_x <- col_meta[[v]]$on_x
    col_y <- col_meta[[v]]$on_y
    score_val <- pair_row[[v]]
    data.frame(
      field = v,
      val_x = as.character(x[[col_x]][[ix]]),
      val_y = as.character(y[[col_y]][[iy]]),
      score = ifelse(is.numeric(score_val),
                     as.character(round(score_val, 2)),
                     as.character(score_val))
    )
  })
  
  result <- do.call(rbind, rows)
  rownames(result) <- NULL
  result
}

preview_pair(.x = 1, .y = 5, pairs = pairs) |> knitr::kable()

# |field  |val_x                  |val_y                    |score |
# |:------|:----------------------|:------------------------|:-----|
# |name   |SALMON CREEK HOUSING   |SALMON CREEK HOUSING INC |0.94  |
# |street |3406 GLACIER HWY STE A |3406 GLACIER HWY         |0.91  |
# |city   |JUNEAU                 |JUNEAU                   |1     |
# |zip    |99801                  |99801-9501               |0.83  |


 
# =============================================================================
# 5. SCORE & SELECT MATCHES
# =============================================================================

# EM ALGORITHM
# ADD WEIGHTS COLUMN:
#  serves as alternative to score

m <- problink_em( ~ name + street + city + zip, data = pairs )
pairs <- predict( m, pairs = pairs, add = TRUE )



# Simple weighted linear score.  Weights reflect field reliability:
#   name   – most discriminating
#   street – high value but noisy
#   city   – moderate (partly captured by blocking)
#   zip    – binary exact match bonus

# score sums to max 10 here: 

pairs <- score_simple(
  pairs,
  var    = "score",
  on     = c("name", "street", "city", "zip"),
  w1      = c(5,2,2,1)   
)

# as.data.frame(pairs)
# .x .y      name    street      city       zip     score
# 1  1  1 0.8541667 0.9111111 1.0000000 1.0000000 0.9121528
# 2  1  2 0.4680135 0.4664502 0.5396825 0.8666667 0.5381710
# 3  1  3 0.6052632 0.5571096 0.4142857 0.7333333 0.5837887
# 4  2  1 0.4250000 0.5434343 0.5396825 0.8666667 0.5380610
# 5  2  2 0.9696970 0.9285714 1.0000000 1.0000000 0.9685065
# 6  2  3 0.5552632 0.4321096 0.5638889 0.7333333 0.5524791
# 7  3  1 0.4916667 0.5651515 0.4142857 0.7333333 0.5346807
# 8  3  2 0.5878788 0.4664502 0.5638889 0.7333333 0.5757413
# 9  3  3 0.8421053 0.9487179 1.0000000 1.0000000 0.9161269

# ALTERNATIVE WAYS TO SELECT PAIRS 
#
#   you can use "weights" instead of "score" for any of these:

pairs2 <- 
  pairs %>%
  select_threshold( "threshold", score = "score", threshold = 6 )

pairs2
head( pairs2 )

pairs3 <- 
  pairs %>%
  select_greedy( "score", variable = "greedy", threshold = 0 )

pairs4 <- 
  pairs %>% select_n_to_m( "score", variable = "ntom", threshold = 0)

 


df_linked <- link( pairs4, selection = "ntom")





#############
############# TEST WITH FULL SAMPLE
#############

pairs <- 
  pair_blocking(
    df, bmf, 
    on = "state") |>
  add_from_x( "unique_entity_id", new_variable = "id_x" ) |>
  add_from_y( "ein", new_variable = "id_y" )

pairs <- compare_pairs(
  pairs,
  on = c("name", "street", "city", "zip"),
  default_comparator = cmp_jarowinkler(threshold = 0.85),  # soft match
  overwrite = TRUE
)

pairs <- score_simple(
  pairs,
  var    = "score",
  on     = c("name", "street", "city", "zip"),
  w1      = c(5,2,2,1)   
)

pairs3 <- 
  pairs %>%
  select_greedy( "score", variable = "greedy", threshold = 0 )

KEEP <- c("score","name", "street", "city", "zip")

df_linked <- 
  pairs3 %>% 
  link( selection = "greedy", keep_from_pairs=KEEP )

fwrite( df_linked, "TEST_1K_GREEDY.CSV" )



m <- problink_em( ~ name + street + city + zip, data = pairs )
pairs <- predict( m, pairs = pairs, add = TRUE )

pairs4 <- 
  pairs %>%
  select_greedy( "weights", variable = "em_greedy", threshold = 0 )

KEEP <- c("score","weights","name", "street", "city", "zip")

df_linked2 <- 
  pairs4 %>% 
  link( selection = "em_greedy", keep_from_pairs=KEEP )

fwrite( df_linked2, "TEST_1K_EM.CSV" )


#############
#############
#############


# --- Filter by Threshold selection ---
# Inspect the score distribution first:
# hist(pairs$score, breaks = 50, main = "Match score distribution")
 
# NOTE: cmp_jarowinkler(threshold=0.85) returns 0 for any pair below 0.85
# similarity on a given field, so weighted scores will be lower than you
# might expect. Lower REVIEW_THRESHOLD or reduce the jarowinkler threshold
# if too many records are falling through as unmatched.
 

MATCH_THRESHOLD  <- 8   # adjust after reviewing score distribution
REVIEW_THRESHOLD <- 6   # scores between this and MATCH_THRESHOLD → manual review

pairs <- pairs %>%
  mutate(
    decision = case_when(
      score >= MATCH_THRESHOLD  ~ "MATCH",
      score >= REVIEW_THRESHOLD ~ "REVIEW",
      TRUE                      ~ "no_match"
    )
  )
 
# =============================================================================
# 6. SELECT BEST MATCH PER SOURCE RECORD
#    link() requires the full pairs object with a logical 'select' column.
#    select_n_to_m() adds that column, picking the top-scoring pair for each
#    source record (n=1) and each DB record (m=1) subject to a score floor.
# =============================================================================
 
# select_n_to_m signature: (pairs, variable, score, threshold, n, m)
#   variable  = name of the output logical column to create in pairs
#   score     = name of the numeric score column to optimise
#   threshold = minimum score a pair must have to be considered
pairs <- select_n_to_m(
  pairs,
  variable  = "select",
  score     = "score",
  threshold = REVIEW_THRESHOLD,
  n         = 1,                  # max matches per source record
  m         = 1                   # max matches per DB record
)
 
# =============================================================================
# 7. BUILD OUTPUT TABLES
# =============================================================================
 
# Restore x/y attributes stripped by dplyr — link() requires them.
setattr(pairs, "x", x_data)
setattr(pairs, "y", y_data)
 
# link() reads x and y from attributes already stored on the pairs object.
# 'selection' is the name of the logical column added by select_n_to_m().
# Do NOT pass df/bmf as positional args — that breaks the call.
all_linked <- link(
  pairs,
  selection = "select",          # logical column marking chosen pairs
  suffixes  = c("_source", "_db"),
  keep_from_pairs = c(".x", ".y", "score", "decision")  # carry through our cols
)
 
# Split into auto-matches and review cases
matches_out <- all_linked %>%
  filter(decision == "match") %>%
  mutate(match_type = "auto")
 
review_out <- all_linked %>%
  filter(decision == "review") %>%
  mutate(match_type = "review")
 
# Source records with no selected pair at all
matched_source_rows <- unique(as.integer(all_linked$.x))
unmatched_out <- df %>%
  slice(setdiff(seq_len(nrow(df)), matched_source_rows)) %>%
  mutate(match_type = "unmatched")
 
# =============================================================================
# 8. SUMMARY
# =============================================================================
 
cat("\n--- Linkage summary ---\n")
cat("Source records      :", nrow(df),  "\n")
cat("Auto-matched        :", nrow(matches_out),   "\n")
cat("Needs manual review :", nrow(review_out),    "\n")
cat("Unmatched           :", nrow(unmatched_out), "\n")
 
# =============================================================================
# 9. EXPORT
# =============================================================================
 
write.csv(matches_out,  "matches_auto.csv",      row.names = FALSE)
write.csv(review_out,   "matches_for_review.csv", row.names = FALSE)
write.csv(unmatched_out,"unmatched.csv",          row.names = FALSE)
 
cat("\nFiles written: matches_auto.csv, matches_for_review.csv, unmatched.csv\n")
 