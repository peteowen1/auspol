#!/usr/bin/env bash
# Every federal SENATE first-preference result by polling place, 2004-2025, every
# state and territory, from the AEC tally room. Raw files, never edited:
#   external/reference/aec/booths/senate/fed<year>-<STATE>-SenateDivisionFirstPrefsByPollingPlaceDownload-<event>-<division>.csv
#
# Why: a district's One Nation vote at a state election tracks its Senate One
# Nation vote (Pete's chart, 2026-10-01), and One Nation is on every Senate
# ballot, so the Senate gives every party's geography where the House only
# shows the parties that fielded a candidate. Pete: "scrape EVERY senate result
# so we can use it for each election". scripts/build_onp_senate.R reads these.
#
# Idempotent: a file already on disk with a header is skipped, so a rerun only
# fetches what is missing. Writes a per-run tally at the end; a division menu
# that lists no files is reported, not silently skipped.
#
# Run from repo root: bash scripts/fetch_aec_senate_booths.sh
set -uo pipefail
D="external/reference/aec/booths/senate"; mkdir -p "$D"
UA="Mozilla/5.0 (auspol research; github.com/peteowen1/auspol)"
# AEC tally-room event ids
declare -A EV=([2004]=12246 [2007]=13745 [2010]=15508 [2013]=17496 [2016]=20499 [2019]=24310 [2022]=27966 [2025]=31496)
STATES="NSW VIC QLD WA SA TAS ACT NT"
got=0; skip=0; fail=0; empty_menus=""
for yr in 2004 2007 2010 2013 2016 2019 2022 2025; do
  ev=${EV[$yr]}
  for st in $STATES; do
    menu=$(curl -sL -A "$UA" "https://results.aec.gov.au/$ev/Website/SenateDivisionDownloadMenu-$ev-$st-Csv.htm")
    files=$(printf '%s' "$menu" | grep -oE "Downloads/SenateDivisionFirstPrefsByPollingPlaceDownload-$ev-[0-9]+\.csv" | sort -u)
    if [ -z "$files" ]; then empty_menus="$empty_menus fed$yr-$st"; continue; fi
    n=0
    for p in $files; do
      out="$D/fed$yr-$st-$(basename "$p")"
      if [ -s "$out" ] && head -2 "$out" | grep -q "PollingPlace"; then skip=$((skip+1)); continue; fi
      if curl -sfL -A "$UA" -o "$out" "https://results.aec.gov.au/$ev/Website/$p" && head -2 "$out" | grep -q "PollingPlace"; then
        got=$((got+1)); n=$((n+1))
      else
        fail=$((fail+1)); echo "FAS!  failed: $p"; rm -f "$out"
      fi
    done
    echo "FAS1  fed$yr $st: $(printf '%s\n' $files | wc -l) divisions listed, $n fetched now"
  done
done
echo "FAS2  fetched $got, already on disk $skip, failed $fail"
[ -n "$empty_menus" ] && echo "FAS2! menus listing no polling-place files:$empty_menus"
exit 0
