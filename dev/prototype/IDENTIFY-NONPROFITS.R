# https://sam.gov/data-services/Entity%20Registration/Public%20-%20Historical?privacy=Public

# from: SAM Master Extract Mapping v6.1 Public File V2 Layout.xlsx
x <- 
c("UNIQUE ENTITY ID", "BLANK (DEPRECATED)", "ENTITY EFT INDICATOR", 
"CAGE CODE", "DODAAC", "SAM EXTRACT CODE", "PURPOSE OF REGISTRATION", 
"INITIAL REGISTRATION DATE", "REGISTRATION EXPIRATION DATE", 
"LAST UPDATE DATE", "ACTIVATION DATE", "LEGAL BUSINESS NAME", 
"DBA NAME", "ENTITY DIVISION NAME", "ENTITY DIVISION NUMBER", 
"PHYSICAL ADDRESS LINE 1", "PHYSICAL ADDRESS LINE 2", "PHYSICAL ADDRESS CITY", 
"PHYSICAL ADDRESS PROVINCE OR STATE", "PHYSICAL ADDRESS ZIP/POSTAL CODE", 
"PHYSICAL ADDRESS ZIP CODE +4", "PHYSICAL ADDRESS COUNTRY CODE", 
"PHYSICAL ADDRESS CONGRESSIONAL DISTRICT", "D&B OPEN DATA FLAG", 
"ENTITY START DATE", "FISCAL YEAR END CLOSE DATE", "ENTITY URL", 
"ENTITY STRUCTURE", "STATE OF INCORPORATION", "COUNTRY OF INCORPORATION", 
"BUSINESS TYPE COUNTER", "BUS TYPE STRING", "PRIMARY NAICS", 
"NAICS CODE COUNTER", "NAICS CODE STRING", "PSC CODE COUNTER", 
"PSC CODE STRING", "CREDIT CARD USAGE", "CORRESPONDENCE FLAG", 
"MAILING ADDRESS LINE 1", "MAILING ADDRESS LINE 2", "MAILING ADDRESS CITY", 
"MAILING ADDRESS ZIP/POSTAL CODE", "MAILING ADDRESS ZIP CODE +4", 
"MAILING ADDRESS COUNTRY", "MAILING ADDRESS STATE OR PROVINCE", 
"GOVT BUS POC FIRST NAME", "GOVT BUS POC MIDDLE INITIAL", "GOVT BUS POC LAST NAME", 
"GOVT BUS POC TITLE", "GOVT BUS POC ST ADD 1", "GOVT BUS POC ST ADD 2", 
"GOVT BUS POC CITY ", "GOVT BUS POC ZIP/POSTAL CODE", "GOVT BUS POC ZIP CODE +4", 
"GOVT BUS POC COUNTRY CODE", "GOVT BUS POC STATE OR PROVINCE", 
"ALT GOVT BUS POC FIRST NAME", "ALT GOVT BUS POC MIDDLE INITIAL", 
"ALT GOVT BUS POC LAST NAME", "ALT GOVT BUS POC TITLE", "ALT GOVT BUS POC ST ADD 1", 
"ALT GOVT BUS POC ST ADD 2", "ALT GOVT BUS POC CITY ", "ALT GOVT BUS POC ZIP/POSTAL CODE", 
"ALT GOVT BUS POC ZIP CODE +4", "ALT GOVT BUS POC COUNTRY CODE", 
"ALT GOVT BUS POC STATE OR PROVINCE", "PAST PERF POC POC  FIRST NAME", 
"PAST PERF POC POC  MIDDLE INITIAL", "PAST PERF POC POC  LAST NAME", 
"PAST PERF POC POC  TITLE", "PAST PERF POC ST ADD 1", "PAST PERF POC ST ADD 2", 
"PAST PERF POC CITY ", "PAST PERF POC ZIP/POSTAL CODE", "PAST PERF POC ZIP CODE +4", 
"PAST PERF POC COUNTRY CODE", "PAST PERF POC STATE OR PROVINCE", 
"ALT PAST PERF POC FIRST NAME", "ALT PAST PERF POC MIDDLE INITIAL", 
"ALT PAST PERF POC LAST NAME", "ALT PAST PERF POC TITLE", "ALT PAST PERF POC ST ADD 1", 
"ALT PAST PERF POC ST ADD 2", "ALT PAST PERF POC CITY ", "ALT PAST PERF POC ZIP/POSTAL CODE", 
"ALT PAST PERF POC ZIP CODE +4", "ALT PAST PERF POC COUNTRY CODE", 
"ALT PAST PERF POC STATE OR PROVINCE", "ELEC BUS POC FIRST NAME", 
"ELEC BUS POC MIDDLE INITIAL", "ELEC BUS POC LAST NAME", "ELEC BUS POC TITLE", 
"ELEC BUS POC ST ADD 1", "ELEC BUS POC ST ADD 2", "ELEC BUS POC CITY ", 
"ELEC BUS POC ZIP/POSTAL CODE", "ELEC BUS POC ZIP CODE +4", "ELEC BUS POC COUNTRY CODE", 
"ELEC BUS POC STATE OR PROVINCE", "ALT ELEC POC BUS POC FIRST NAME", 
"ALT ELEC POC BUS POC MIDDLE INITIAL", "ALT ELEC POC BUS POC LAST NAME", 
"ALT ELEC POC BUS POC TITLE", "ALT ELEC POC BUS ST ADD 1", "ALT ELEC POC BUS ST ADD 2", 
"ALT ELEC POC BUS CITY ", "ALT ELEC POC BUS ZIP/POSTAL CODE", 
"ALT ELEC POC BUS ZIP CODE +4", "ALT ELEC POC BUS COUNTRY CODE", 
"ALT ELEC POC BUS STATE OR PROVINCE", "NAICS EXCEPTION COUNTER", 
"NAICS EXCEPTION STRING", "DEBT SUBJECT TO OFFSET FLAG", "EXCLUSION STATUS FLAG", 
"SBA BUSINESS TYPES COUNTER", "SBA BUSINESS TYPES STRING", "NO PUBLIC DISPLAY FLAG", 
"DISASTER RESPONSE COUNTER", "DISASTER RESPONSE STRING", "ENTITY EVS SOURCE", 
"FLEX FIELD 1", "FLEX FIELD 2", "FLEX FIELD 3", "FLEX FIELD 4", 
"FLEX FIELD 5", "FLEX FIELD 6", "FLEX FIELD 7", "FLEX FIELD 8", 
"FLEX FIELD 9", "FLEX FIELD 10", "FLEX FIELD 11", "FLEX FIELD 12", 
"FLEX FIELD 13", "FLEX FIELD 14", "FLEX FIELD 15", "FLEX FIELD 16", 
"FLEX FIELD 17", "FLEX FIELD 18", "FLEX FIELD 19", "END OF RECORD INDICATOR"
)

library(data.table)

df <- fread(
  "SAM_PUBLIC_MONTHLY_V2_20251102.dat",
  sep = "|",
  header = FALSE,
  fill = TRUE,
  quote = "",
  na.strings = c("", "NA"),
  showProgress = TRUE
)

names(df) <- x


###########
###########
###########

table( df$`ENTITY STRUCTURE` ) |> knitr::kable()

|Var1 |   Freq|
|:----|------:|
|2A   |  72449|
|2J   | 107980|
|2K   | 120475|
|2L   | 373474|
|8H   | 139747|
|CY   |   1329|
|X6   |   7683|
|ZZ   |  55393|


2J  - Sole Proprietorship 
2K  - Partnership or Limited Liability Partnership
2L  - Corporate Entity (Not Tax Exempt) 
8H  - Corporate Entity (Tax Exempt) 
2A  - U.S. Government Entity 
CY  - Country - Foreign Government 
X6  - International Organization 
ZZ  - Other


###########
###########
###########


x <- df[["BUS TYPE STRING"]]
x |> strsplit("~") |> unlist() |> table() |> knitr::kable()


g <- grep( "A8|BZ|2U|A7", x, value=T )
g |> strsplit("~") |> unlist() |> table() |> knitr::kable()

t <- g |> strsplit("~") |> unlist() |> table()


tab <- t
codes <- names(tab)
labels <- business_type_lookup[codes]
# fallback for missing labels
# labels <- labels[is.na(names(labels))]
factor_codes <- factor(codes, levels = codes, labels = labels)
tt <- data.frame(
  code = codes,
  label = factor_codes,
  n = as.integer(tab) )

tt <- arrange( tt, -n )
tt


keep <- grepl( "A8|BZ|2U|A7", x )
d2 <- df[ keep , ]
dim( d2 )

fwrite( d2, "ALL-NONPROFITS.CSV" )

table( d2$`ENTITY STRUCTURE` ) |> knitr::kable()


|Var1 |   Freq|
|:----|------:|
|05   |   2158|
|12   |  63594|
|1A   |   2688|
|1B   |   2145|
|1D   |   1426|
|1E   |   2506|
|1R   |   4696|
|1S   |   2329|
|20   |  11406|
|23   | 167269|
|27   | 235702|
|2F   |   8618|
|2R   |   1468|
|2U   |  10461|
|2X   | 637769|
|3I   |   1278|
|6D   |   3565|
|80   |   5748|
|86   |    391|
|8B   |   4319|
|8C   |   6724|
|8D   |   6022|
|8E   |  14269|
|8U   |   1161|
|8W   | 126896|
|A2   | 161487|
|A5   |  77597|
|A7   |    425|
|A8   | 155736|
|BZ   |  10720|
|C6   |  17796|
|C7   |  13155|
|C8   |  16177|
|FO   |   6005|
|FR   |  18727|
|FY   |    335|
|G3   |     48|
|G5   |     75|
|G6   |    306|
|G7   |     96|
|G8   |     74|
|G9   |   8893|
|GW   |   1356|
|H2   |  15537|
|H6   |  14024|
|HB   |    180|
|HK   |   6782|
|HQ   |  27720|
|HS   |     77|
|JS   |  20460|
|JV   |   2416|
|JX   |   2991|
|KM   |   2869|
|LJ   | 244891|
|M8   |  11559|
|MF   |  58167|
|MG   |   7575|
|NB   |   9915|
|NG   |    845|
|OH   |   3970|
|OW   |   7318|
|OY   | 104942|
|PI   |  40519|
|QF   |  49469|
|QU   |     74|
|QW   |     56|
|QZ   |  13139|
|T4   |    542|
|TR   |   1497|
|TW   |   1204|
|UD   |   7680|
|XS   |  95396|
|XY   |   1941|
|ZR   |   1800|
|ZW   |    235|



Business Type Code	Business Type Name
2R	U.S Federal Government
2F	U.S. State Government
12	U.S. Local Government
3I	Tribal Government
CY	Foreign Government
A7	AbilityOne Non Profit Agency
20	Foreign Owned
1D	Small Agricultural Cooperative
LJ	Limited Liability Company
XS	Subchapter S Corporation
MF	Manufacturer of Goods
2X	For Profit Organization
A8	Non-Profit Organization
2U	Other Not For Profit Organization
HK	Community Development Corporation Owned Firm
A3	Labor Surplus Area Firm
A5	Veteran Owned Business
QF	Service Disabled Veteran Owned Business
A2	Woman Owned Business
23	Minority Owned Business
FR	Asian-Pacific American Owned
QZ	Subcontinent Asian (Asian-Indian) American Owned
OY	Black American Owned
PI	Hispanic American Owned
NB	Native American Owned
8W	Woman Owned Small Business
27	Self Certified Small Disadvantaged Business
8E	Economically Disadvantaged Women Small Owned Business
8C	Joint Venture Women Owned Small Business
8D	Joint Venture Economically Disadvantaged Women Small Owned Business
NG	Federal Agency
QW	Federally Funded Research and Development Center
C8	City
C7	County
ZR	Inter-municipal
MG	Local Government Owned
C6	Municipality
H6	School District
TW	Transit Authority
UD	Council of Governments
8B	Housing Authorities Public/Tribal
86	Interstate Entity
KM	Planning Commission
T4	Port Authority
H2	Community Development Corporation 
6D	Domestic Shelter
M8	Educational Institution
G6	1862 Land Grant College
G7	1890 Land Grant College
G8	1994 Land Grant College
HB	Historically Black College or University
1A	Minority Institution
1R	Private University or College
ZW	School of Forestry
GW	Hispanic Servicing Institution
OH	State Controlled Institution of Higher Learning
HS	Tribal College
QU	Veterinary College
G3	Alaskan Native Servicing Institution
G5	Native Hawaiian Servicing Institution
BZ	Foundation
80	Hospital
FY	Veterinary Hospital
HQ	DOT Certified DBE
05	Alaskan Native Corporation Owned Firm
OW	American Indian Owned
XY	Indian Tribe (Federally Recognized)
8U	Native Hawaiian Organization Owned Firm
1B	Tribally Owned Firm
FO	Township
TR	Airport Authority
G9	Other Than One of the Proceeding
JX	Self-Certified HUBZone Joint Venture
1E	Indian Economic Enterprise
1S	Indian Small Business Economic Enterprise
V2 **	Grants
VW **	Contracts and Grants


business_type_lookup <- c(
  "2R" = "U.S Federal Government",
  "2F" = "U.S. State Government",
  "12" = "U.S. Local Government",
  "3I" = "Tribal Government",
  "CY" = "Foreign Government",
  "A7" = "AbilityOne Non Profit Agency",
  "20" = "Foreign Owned",
  "1D" = "Small Agricultural Cooperative",
  "LJ" = "Limited Liability Company",
  "XS" = "Subchapter S Corporation",
  "MF" = "Manufacturer of Goods",
  "2X" = "For Profit Organization",
  "A8" = "Non-Profit Organization",
  "2U" = "Other Not For Profit Organization",
  "HK" = "Community Development Corporation Owned Firm",
  "A5" = "Veteran Owned Business",
  "QF" = "Service Disabled Veteran Owned Business",
  "A2" = "Woman Owned Business",
  "23" = "Minority Owned Business",
  "FR" = "Asian-Pacific American Owned",
  "QZ" = "Subcontinent Asian (Asian-Indian) American Owned",
  "OY" = "Black American Owned",
  "PI" = "Hispanic American Owned",
  "NB" = "Native American Owned",
  "8W" = "Woman Owned Small Business",
  "27" = "Self Certified Small Disadvantaged Business",
  "8E" = "Economically Disadvantaged Women Small Owned Business",
  "8C" = "Joint Venture Women Owned Small Business",
  "8D" = "Joint Venture Economically Disadvantaged Women Small Owned Business",
  "NG" = "Federal Agency",
  "C8" = "City",
  "C7" = "County",
  "ZR" = "Inter-municipal",
  "MG" = "Local Government Owned",
  "C6" = "Municipality",
  "H6" = "School District",
  "TW" = "Transit Authority",
  "UD" = "Council of Governments",
  "8B" = "Housing Authorities Public/Tribal",
  "86" = "Interstate Entity",
  "KM" = "Planning Commission",
  "H2" = "Community Development Corporation",
  "6D" = "Domestic Shelter",
  "M8" = "Educational Institution",
  "G6" = "1862 Land Grant College",
  "G7" = "1890 Land Grant College",
  "G8" = "1994 Land Grant College",
  "HB" = "Historically Black College or University",
  "1A" = "Minority Institution",
  "1R" = "Private University or College",
  "ZW" = "School of Forestry",
  "GW" = "Hispanic Serving Institution",
  "OH" = "State Controlled Institution of Higher Learning",
  "HS" = "Tribal College",
  "QU" = "Veterinary College",
  "G3" = "Alaskan Native Serving Institution",
  "G5" = "Native Hawaiian Serving Institution",
  "BZ" = "Foundation",
  "80" = "Hospital",
  "FY" = "Veterinary Hospital",
  "HQ" = "DOT Certified DBE",
  "05" = "Alaskan Native Corporation Owned Firm",
  "OW" = "American Indian Owned",
  "XY" = "Indian Tribe (Federally Recognized)",
  "8U" = "Native Hawaiian Organization Owned Firm",
  "1B" = "Tribally Owned Firm",
  "FO" = "Township",
  "TR" = "Airport Authority",
  "G9" = "Other Than One of the Preceding",
  "JX" = "Self-Certified HUBZone Joint Venture",
  "JS" = "not in dictionary",
  "JV" = "not in dictionary"
)


