#!/usr/bin/env bash
# Parish schools resolve to their PARISH's EIN, not their DIOCESE's.
#
# A Catholic parish elementary school is usually not separately incorporated:
# the parish is the legal entity behind the SAM registration and holds the
# employer EIN. Matching the school to that named parish is a legitimate
# federated match, the same shape as a Salvation Army corps resolving to its
# territorial HQ. Reaching past the parish to the diocesan group-ruling EIN is
# not -- that EIN covers hundreds of unrelated subordinates and identifies
# nothing about which one registered.
#
# Written as shell, not R: BMF-GREP.tsv is ~309MB and fread on it exits without
# output. Pre-filter the EINs of interest, then join in awk.
#
# Exempt: registrants that ARE a diocesan schools office ("Catholic Schools
# Diocese of X") legitimately carry a diocesan EIN.
set -euo pipefail
cd "$(dirname "$0")"
OUT=QC-PARISH-SCHOOL-EINS.csv

cat run-out/*.tsv > /tmp/all.tsv

# school/academy `match` rows carrying an EIN, reached via parish/diocese reasoning
awk -F'\t' 'BEGIN{OFS="\t"}
  $1!="uei" && $6=="match" && $5!="" \
  && toupper($2) ~ /SCHOOL|ACADEMY|HIGH/ \
  && tolower($10 $11) ~ /parish|diocese|diocesan|archdiocese|group exemption/ \
  {print $5,$1,$2,$8}' /tmp/all.tsv | sort -u > /tmp/school_eins.tsv

# join those EINs to their BMF names
awk -F'\t' 'NR==FNR{u[$1]=$2; n[$1]=$3; c[$1]=$4; next}
  ($1 in u){sub(/\r$/,""); print $1"\t"u[$1]"\t"n[$1]"\t"c[$1]"\t"$2}' \
  /tmp/school_eins.tsv BMF-GREP.tsv | sort -u > /tmp/school_bmf.tsv

echo "school/academy match rows via parish-diocese reasoning: $(wc -l < /tmp/school_eins.tsv)"
echo "  of those, EIN resolved in BMF-GREP:                   $(cut -f1 /tmp/school_bmf.tsv | sort -u | wc -l)"

# the defect: EIN is a diocese-level record AND the registrant is not itself a
# diocesan schools office
{ echo "uei,sam_name,ein_found,bmf_name,confidence"
  awk -F'\t' 'BEGIN{OFS=","}
    toupper($5) ~ /DIOCESE|ARCHDIOCESE|CATHOLIC BISHOP/ \
    && toupper($3) !~ /CATHOLIC SCHOOL(S)? (SYSTEM)?[ -]*DIOCESE|SCHOOLS OF SPECIAL EDUCATION/ \
    { gsub(/,/," ",$3); gsub(/,/," ",$5); print $2,$3,$1,$5,$4 }' /tmp/school_bmf.tsv
} > "$OUT"

echo "  diocese-level EINs on individual schools (defects):   $(( $(wc -l < "$OUT") - 1 ))"
echo "wrote $OUT -- re-adjudicate these rows, do NOT bulk-reclassify."
