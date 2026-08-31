#!/bin/bash
# Wait for the stage-2 prefetch to finish, then run stage-1 at the same rate.
# Sequential, not parallel: 2.5 req/s measured clean, 5 req/s is untested.
cd "C:/Users/jdlec/Dropbox/00 - URBAN/00-GITHUB/npmatch"
LOG=data-dev/no-research/prefetch-s2.log
for i in $(seq 1 240); do
  grep -q "^done\." "$LOG" && break
  sleep 30
done
"/c/Program Files/R/R-4.4.2/bin/Rscript.exe" data-dev/no-research/12_pp_prefetch.R \
  data-dev/no-research/QUEUE-FULL-S1.csv 2.5 > data-dev/no-research/prefetch-s1.log 2>&1
echo "STAGE1 PREFETCH DONE"
