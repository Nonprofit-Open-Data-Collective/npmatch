nrm <- function(street = NA, zip = NA, zip_plus4 = NA, state = "AK") {
  d <- np_query(data.frame(unique_entity_id = "1", name = "X",
                           street = street, zip = zip, zip_plus4 = zip_plus4,
                           state = state, stringsAsFactors = FALSE),
                c(.id = "unique_entity_id", name = "name", street = "street",
                  zip5 = "zip", zip_plus4 = "zip_plus4", state = "state"))
  np_normalize(d)
}

test_that("street parses into number / name / type with unit removed", {
  d <- nrm(street = "3406 GLACIER HWY STE A")
  expect_equal(d$street_num, "3406")
  expect_equal(d$street_name, "GLACIER")
  expect_equal(d$street_type, "HWY")
  expect_equal(d$street_unit, "STE A")
})

test_that("street type is separated for multi-word names and directionals", {
  d <- nrm(street = "430 WEST 7TH AVENUE")
  expect_equal(d$street_num, "430")
  expect_equal(d$street_type, "AVE")            # AVENUE -> AVE
  expect_equal(d$street_name, "W 7TH")          # WEST -> W, retained in name
})

test_that("PO boxes route the box number to street_num", {
  d <- nrm(street = "PO BOX 147")
  expect_equal(d$street_num, "147")
  expect_equal(d$street_name, "PO BOX")
  expect_true(is.na(d$street_type))
})

test_that("dropped leading zeros are restored and ZIP is split", {
  d <- nrm(zip = "2139")                        # MA ZIP with a lost leading zero
  expect_equal(d$zip5, "02139")
  expect_equal(d$zip3, "021")
  expect_true(is.na(d$zip9))                    # no +4 -> no zip9
  expect_null(d$zip4)                           # zip4 is not a field anymore
})

test_that("zip9 input yields the nested zip5/zip3/zip9 family", {
  d <- nrm(zip = "99801-9501")
  expect_equal(d$zip5, "99801")
  expect_equal(d$zip3, "998")
  expect_equal(d$zip9, "99801-9501")
})

test_that("a nine-digit ZIP with a dropped leading zero parses correctly", {
  d <- nrm(zip = "21391234")                    # 02139-1234
  expect_equal(d$zip5, "02139")
  expect_equal(d$zip3, "021")
  expect_equal(d$zip9, "02139-1234")
})

test_that("a separately mapped +4 add-on is used when the ZIP lacks it", {
  d <- nrm(zip = "99801", zip_plus4 = "9501")
  expect_equal(d$zip5, "99801")
  expect_equal(d$zip9, "99801-9501")
})

test_that("full state names get a two-letter abbreviation", {
  expect_equal(nrm(state = "Alaska")$state_abb, "AK")
  expect_equal(nrm(state = "new york")$state_abb, "NY")
  expect_equal(nrm(state = "AK")$state_abb, "AK")
  expect_true(is.na(nrm(state = "")$state_abb))
})

test_that("np_clean_geo standardizes city prefixes, aliases, and state", {
  d <- data.frame(city = c("ST LOUIS", "nyc", "ft worth"),
                  state = c("Missouri", "New York", "Texas"),
                  stringsAsFactors = FALSE)
  out <- np_clean_geo(d)
  expect_equal(out$city, c("SAINT LOUIS", "NEW YORK CITY", "FORT WORTH"))
  expect_equal(out$state, c("MO", "NY", "TX"))
})

test_that("PO box variants are flagged and standardized", {
  streets <- c("P O BOX 284", "PO BOX 1111", "POB 486", "PO B 123",
               "PO 970", "P O 4911", "BOX 158")
  for (s in streets) {
    d <- nrm(street = s)
    expect_true(d$is_po_box, info = s)
    expect_equal(d$street_name, "PO BOX", info = s)
    expect_equal(d$street_key, paste("PO BOX", sub("\\D+", "", s)), info = s)
  }
})

test_that("ordinary streets are not misflagged as PO boxes", {
  for (s in c("3406 GLACIER HWY", "100 BOXER ST", "500 PORTLAND AVE", "1 POLK ST")) {
    expect_false(nrm(street = s)$is_po_box, info = s)
  }
})

test_that("np_clean_geo campfin engine normalizes city and state", {
  skip_if_not_installed("campfin")
  d <- data.frame(city = c("St. Louis", "nyc", "Stowe"),
                  state = c("Missouri", "New York", "Vermont"),
                  stringsAsFactors = FALSE)
  out <- np_clean_geo(d, engine = "campfin")
  expect_equal(out$state, c("MO", "NY", "VT"))
  expect_equal(out$city[1], "SAINT LOUIS")     # ST. -> SAINT via campfin/alias
  expect_equal(out$city[2], "NEW YORK CITY")   # alias applied on top
})

test_that("zip_ref corrects a misspelled city and fills a missing one", {
  ref <- data.frame(zip5 = c("85001", "63101"),
                    major_city = c("PHOENIX", "SAINT LOUIS"), stringsAsFactors = FALSE)
  d <- data.frame(city = c("PHOENex", ""), state = c("AZ", "MO"),
                  zip5 = c("85001", "63101"), stringsAsFactors = FALSE)
  out <- np_clean_geo(d, zip_ref = ref)
  expect_equal(out$city[1], "PHOENIX")         # near-miss snapped
  expect_equal(out$city[2], "SAINT LOUIS")     # missing filled from ZIP
})

test_that("zip_ref leaves a genuinely different acceptable city name alone", {
  ref <- data.frame(zip5 = "11201", major_city = "BROOKLYN", stringsAsFactors = FALSE)
  d <- data.frame(city = "NEW YORK CITY", state = "NY", zip5 = "11201",
                  stringsAsFactors = FALSE)
  out <- np_clean_geo(d, zip_ref = ref, max_dist = 2)
  expect_equal(out$city, "NEW YORK CITY")      # far from BROOKLYN -> not swapped
})

test_that("np_load_hud keeps the dominant CBSA per ZIP", {
  hud <- data.frame(
    ZIP = c("02139", "02139", "99762"),
    CBSA = c("14460", "99999", "27940"),
    RES_RATIO = c(0.9, 0.1, 1), BUS_RATIO = c(0.8, 0.2, 1),
    OTH_RATIO = c(0.8, 0.2, 1), TOT_RATIO = c(0.9, 0.1, 1),
    stringsAsFactors = FALSE)
  cw <- np_load_hud(hud)
  expect_equal(names(cw), c("zip5", "cbsa"))
  expect_equal(cw$cbsa[cw$zip5 == "02139"], "14460")
  expect_equal(nrow(cw), 2)
})

test_that("np_load_ruca normalizes to zip5 + numeric ruca", {
  ruca <- data.frame(ZIP_CODE = c("2139", "99762"), RUCA1 = c("1", "10"),
                     stringsAsFactors = FALSE)
  cw <- np_load_ruca(ruca)
  expect_equal(cw$zip5, c("02139", "99762"))
  expect_equal(cw$ruca, c(1, 10))
})

test_that("np_augment_geo joins crosswalk attributes and RUCA collapses", {
  data <- data.frame(zip5 = c("02139", "99762"), stringsAsFactors = FALSE)
  xwalk <- data.frame(zip5 = c("02139", "99762"),
                      cbsa_name = c("Boston MA", "Nome AK"),
                      ruca = c(1, 10), stringsAsFactors = FALSE)
  aug <- np_augment_geo(data, xwalk)
  expect_equal(aug$cbsa_name, c("Boston MA", "Nome AK"))
  expect_equal(np_ruca_urban(aug$ruca), c("urban", "rural"))
})
