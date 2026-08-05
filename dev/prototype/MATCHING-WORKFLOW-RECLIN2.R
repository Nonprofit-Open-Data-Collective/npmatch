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
df_source <- data.frame(
  legal_business_name                  = c("Acme Corp", "Widget LLC", "Globex Inc"),
  physical_address_line_1              = c("123 Main St", "456 Oak Ave", "789 Pine Rd"),
  physical_address_city                = c("Phoenix", "Tucson", "Scottsdale"),
  physical_address_province_or_state   = c("AZ", "AZ", "AZ"),
  physical_address_zip_postal_code     = c("85001", "85701", "85251"),
  check.names = FALSE,
  stringsAsFactors = FALSE
)

df_db <- data.frame(
  org_name_display = c("Acme Corporation", "Widgets LLC", "Globex Incorporated"),
  org_addr_street  = c("123 Main Street", "456 Oak Avenue", "789 Pine Road"),
  org_addr_city    = c("Phoenix", "Tucson", "Scottsdale"),
  org_addr_state   = c("AZ", "AZ", "AZ"),
  org_addr_zip     = c("85001", "85701", "85251"),
  stringsAsFactors = FALSE
)

# --- Load your datasets here ---
df_source <- fread("SAMPLE-1K-NONPROFITS.CSV")
df_db     <- fread("bmf_2026_01_processed.csv")


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
  "physical_address_country_code" )
  
source_clean <- df_source[keep1] %>%
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
  "org_name_raw",
  "org_addr_street",
  "org_addr_city",
  "org_addr_state",
  "org_addr_zip" )

db_clean <- df_db[keep2] %>%
  rename(
    name   = org_name_raw,
    street = org_addr_street,
    city   = org_addr_city,
    state  = org_addr_state,
    zip    = org_addr_zip
  ) %>%
  mutate(across(where(is.character), str_squish),
         across(where(is.character), str_to_upper))

# =============================================================================
# 3. CREATE PAIR TABLE  (blocking on state)
# =============================================================================

# drop cases outside the US
unique_states <- unique( db_clean$state )
source_clean <- filter( source_clean, state %in% unique_states )

# pair_blocking() only compares records that share the same blocking key,
# dramatically reducing the number of candidate pairs.
pairs <- pair_blocking(source_clean, db_clean, on = "state")

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

# as.data.frame(pairs)
# .x .y      name    street      city       zip
# 1  1  1 0.8541667 0.9111111 1.0000000 1.0000000
# 2  1  2 0.4680135 0.4664502 0.5396825 0.8666667
# 3  1  3 0.6052632 0.5571096 0.4142857 0.7333333
# 4  2  1 0.4250000 0.5434343 0.5396825 0.8666667
# 5  2  2 0.9696970 0.9285714 1.0000000 1.0000000
# 6  2  3 0.5552632 0.4321096 0.5638889 0.7333333
# 7  3  1 0.4916667 0.5651515 0.4142857 0.7333333
# 8  3  2 0.5878788 0.4664502 0.5638889 0.7333333
# 9  3  3 0.8421053 0.9487179 1.0000000 1.0000000


# Optionally add an exact-match column for zip (high precision signal)
pairs <- compare_pairs(
  pairs,
  on      = "zip",
  default_comparator = cmp_identical(),
  suffix  = "_exact",
  overwrite = FALSE
)

# as.data.frame(pairs)
# .x .y      name    street      city   zip
# 1  1  1 0.8541667 0.9111111 1.0000000  TRUE
# 2  1  2 0.4680135 0.4664502 0.5396825 FALSE
# 3  1  3 0.6052632 0.5571096 0.4142857 FALSE
# 4  2  1 0.4250000 0.5434343 0.5396825 FALSE
# 5  2  2 0.9696970 0.9285714 1.0000000  TRUE
# 6  2  3 0.5552632 0.4321096 0.5638889 FALSE
# 7  3  1 0.4916667 0.5651515 0.4142857 FALSE
# 8  3  2 0.5878788 0.4664502 0.5638889 FALSE
# 9  3  3 0.8421053 0.9487179 1.0000000  TRUE


# =============================================================================
# 5. SCORE & SELECT MATCHES
# =============================================================================

# Simple weighted linear score.  Weights reflect field reliability:
#   name   – most discriminating
#   street – high value but noisy
#   city   – moderate (partly captured by blocking)
#   zip    – binary exact match bonus

pairs <- score_simple(
  pairs,
  var    = "score",
  on     = c("name", "street", "city", "zip"),
  w1      = c(0.45,   0.25,    0.15,   0.15)   # must sum to 1
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


# --- Threshold selection ---
# Inspect the score distribution first:
# hist(pairs$score, breaks = 50, main = "Match score distribution")

MATCH_THRESHOLD  <- 0.80   # adjust after reviewing score distribution
REVIEW_THRESHOLD <- 0.65   # scores between this and MATCH_THRESHOLD → manual review

pairs <- pairs %>%
  mutate(
    decision = case_when(
      score >= MATCH_THRESHOLD  ~ "match",
      score >= REVIEW_THRESHOLD ~ "review",
      TRUE                      ~ "no_match"
    )
  )

# as.data.frame(pairs)
# .x .y      name    street      city       zip     score decision
# 1  1  1 0.8541667 0.9111111 1.0000000 1.0000000 0.9121528    match
# 2  1  2 0.4680135 0.4664502 0.5396825 0.8666667 0.5381710 no_match
# 3  1  3 0.6052632 0.5571096 0.4142857 0.7333333 0.5837887 no_match
# 4  2  1 0.4250000 0.5434343 0.5396825 0.8666667 0.5380610 no_match
# 5  2  2 0.9696970 0.9285714 1.0000000 1.0000000 0.9685065    match
# 6  2  3 0.5552632 0.4321096 0.5638889 0.7333333 0.5524791 no_match
# 7  3  1 0.4916667 0.5651515 0.4142857 0.7333333 0.5346807 no_match
# 8  3  2 0.5878788 0.4664502 0.5638889 0.7333333 0.5757413 no_match
# 9  3  3 0.8421053 0.9487179 1.0000000 1.0000000 0.9161269    match

# =============================================================================
# 6. DEDUPLICATE  – keep best match per source record
# =============================================================================

# If a single source record matches multiple DB records, keep the top score.
best_matches <- pairs %>%
  filter(decision %in% c("match", "review")) %>%
  group_by(.x) %>%                        # .x = row index in source_clean
  slice_max(score, n = 1, with_ties = FALSE) %>%
  ungroup()


# =============================================================================
# 6. SELECT BEST MATCH PER SOURCE RECORD
#    link() requires the full pairs object with a logical 'select' column.
#    select_n_to_m() adds that column, picking the top-scoring pair for each
#    source record (n=1) and each DB record (m=1) subject to a score floor.
# =============================================================================
 
# NA similarity scores (e.g. both sides missing a field) would crash
# select_n_to_m, so replace them with 0 before scoring.
pairs$score <- replace(pairs$score, is.na(pairs$score), 0)
 
# select_n_to_m adds a logical column called 'select' to the pairs object.
# Only pairs above the threshold AND chosen as best-on-both-sides are TRUE.
# Correct argument names: variable= (not var=), threshold= (not score=).
pairs <- select_n_to_m(
  pairs,
  variable = "select",
  score  = "score",
  threshold = REVIEW_THRESHOLD,   # minimum score to be considered at all
  n         = 1,                  # max matches per source record
  m         = 1                   # max matches per DB record
)


# =============================================================================
# 7. BUILD OUTPUT TABLES
# =============================================================================
 
# link() reads x and y from attributes already stored on the pairs object.
# 'selection' is the name of the logical column added by select_n_to_m().
# Do NOT pass source_clean/db_clean as positional args — that breaks the call.
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
unmatched_out <- source_clean %>%
  slice(setdiff(seq_len(nrow(source_clean)), matched_source_rows)) %>%
  mutate(match_type = "unmatched")
 
# =============================================================================
# 8. SUMMARY
# =============================================================================
 
cat("\n--- Linkage summary ---\n")
cat("Source records      :", nrow(source_clean),  "\n")
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



















# =============================================================================
# Organization Record Linkage using reclin2
# Matches on: name + address fields
# Blocking variable: state
# =============================================================================
 
library(reclin2)
library(dplyr)
library(stringr)
 
# =============================================================================
# 1. LOAD & PREPARE DATA
# =============================================================================
 
# --- Load your datasets here ---
# df_source <- read.csv("your_source_file.csv")
# df_db     <- read.csv("your_database_file.csv")
 
# For illustration, small example frames are included.
# Remove/replace these with your actual data loading above.
df_source <- data.frame(
  `LEGAL BUSINESS NAME`                  = c("Acme Corp", "Widget LLC", "Globex Inc"),
  `PHYSICAL ADDRESS LINE 1`              = c("123 Main St", "456 Oak Ave", "789 Pine Rd"),
  `PHYSICAL ADDRESS CITY`                = c("Phoenix", "Tucson", "Scottsdale"),
  `PHYSICAL ADDRESS PROVINCE OR STATE`   = c("AZ", "AZ", "AZ"),
  `PHYSICAL ADDRESS ZIP/POSTAL CODE`     = c("85001", "85701", "85251"),
  check.names = FALSE,
  stringsAsFactors = FALSE
)
 
df_db <- data.frame(
  org_name_display = c("Acme Corporation", "Widgets LLC", "Globex Incorporated"),
  org_addr_street  = c("123 Main Street", "456 Oak Avenue", "789 Pine Road"),
  org_addr_city    = c("Phoenix", "Tucson", "Scottsdale"),
  org_addr_state   = c("AZ", "AZ", "AZ"),
  org_addr_zip     = c("85001", "85701", "85251"),
  stringsAsFactors = FALSE
)
 
# =============================================================================
# 2. STANDARDISE FIELD NAMES
#    Rename to simple internal names so the linkage code stays readable.
# =============================================================================
 
source_clean <- df_source %>%
  rename(
    name   = `LEGAL BUSINESS NAME`,
    street = `PHYSICAL ADDRESS LINE 1`,
    city   = `PHYSICAL ADDRESS CITY`,
    state  = `PHYSICAL ADDRESS PROVINCE OR STATE`,
    zip    = `PHYSICAL ADDRESS ZIP/POSTAL CODE`
  ) %>%
  mutate(across(where(is.character), str_squish),          # trim whitespace
         across(where(is.character), str_to_upper))         # normalise case
 
db_clean <- df_db %>%
  rename(
    name   = org_name_display,
    street = org_addr_street,
    city   = org_addr_city,
    state  = org_addr_state,
    zip    = org_addr_zip
  ) %>%
  mutate(across(where(is.character), str_squish),
         across(where(is.character), str_to_upper))
 
# =============================================================================
# 3. CREATE PAIR TABLE  (blocking on state)
# =============================================================================
 
# pair_blocking() only compares records that share the same blocking key,
# dramatically reducing the number of candidate pairs.
pairs <- pair_blocking(source_clean, db_clean, blocking_var = "state",
                       id_x = "unique_entity_id", id_y = "ein")
 
# Save references now — dplyr verbs will strip x/y attributes from pairs
x_data <- source_clean
y_data <- db_clean
 
cat("Candidate pairs after blocking:", nrow(pairs), "\n")
 
# =============================================================================
# 4. COMPARE FIELDS
# =============================================================================
 
# compare_pairs() adds a similarity score column for each field.
# jaro_winkler is well-suited for names; lcs (longest common subsequence)
# works well for street addresses.  Adjust methods to taste.
 
pairs <- compare_pairs(
  pairs,
  by = c("name", "street", "city", "zip"),
  default_comparator = cmp_jarowinkler(threshold = 0.85),  # soft match
  overwrite = TRUE
)
 
# Convert any NA similarities to 0 so score_simsum doesn't propagate NAs
pairs[, name   := fifelse(is.na(name),   0, name)]
pairs[, street := fifelse(is.na(street), 0, street)]
pairs[, city   := fifelse(is.na(city),   0, city)]
pairs[, zip    := fifelse(is.na(zip),    0, zip)]
 
# =============================================================================
# 5. SCORE & SELECT MATCHES
# =============================================================================
 
# Simple weighted linear score.  Weights reflect field reliability:
#   name   – most discriminating
#   street – high value but noisy
#   city   – moderate (partly captured by blocking)
#   zip    – binary exact match bonus
 
pairs <- score_simsum(
  pairs,
  var    = "score",
  by     = c("name", "street", "city", "zip"),
  w      = c(0.45,   0.25,    0.15,   0.15)   # must sum to 1
)
 
# --- Threshold selection ---
# Inspect the score distribution first:
# hist(pairs$score, breaks = 50, main = "Match score distribution")
 
MATCH_THRESHOLD  <- 0.75   # adjust after reviewing score distribution
REVIEW_THRESHOLD <- 0.55   # scores between this and MATCH_THRESHOLD → manual review
# NOTE: cmp_jarowinkler(threshold=0.85) returns 0 for any pair below 0.85
# similarity on a given field, so weighted scores will be lower than you
# might expect. Lower REVIEW_THRESHOLD or reduce the jarowinkler threshold
# if too many records are falling through as unmatched.
 
pairs <- pairs %>%
  mutate(
    decision = case_when(
      score >= MATCH_THRESHOLD  ~ "match",
      score >= REVIEW_THRESHOLD ~ "review",
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
# Do NOT pass source_clean/db_clean as positional args — that breaks the call.
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
unmatched_out <- source_clean %>%
  slice(setdiff(seq_len(nrow(source_clean)), matched_source_rows)) %>%
  mutate(match_type = "unmatched")
 
# =============================================================================
# 8. SUMMARY
# =============================================================================
 
cat("\n--- Linkage summary ---\n")
cat("Source records      :", nrow(source_clean),  "\n")
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
 