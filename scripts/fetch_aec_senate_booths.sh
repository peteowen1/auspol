#!/usr/bin/env bash
# Every federal SENATE first-preference result by polling place, 1998-2025, every
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
# 2004 is NOT in this loop: its division menus do not exist; the per-state zips below fetch it.
for yr in 2007 2010 2013 2016 2019 2022 2025; do
  ev=${EV[$yr]}
  for st in $STATES; do
    menu=$(curl -sfL -A "$UA" "https://results.aec.gov.au/$ev/Website/SenateDivisionDownloadMenu-$ev-$st-Csv.htm") || { fail=$((fail+1)); echo "FAS!  menu fetch failed: fed$yr $st"; continue; }
    files=$(printf '%s' "$menu" | grep -oE "Downloads/SenateDivisionFirstPrefsByPollingPlaceDownload-$ev-[0-9]+\.csv" | sort -u)
    if [ -z "$files" ]; then empty_menus="$empty_menus fed$yr-$st"; continue; fi
    n=0
    for p in $files; do
      out="$D/fed$yr-$st-$(basename "$p")"
      # complete = header present AND data rows after it (a body cut off after
      # the header used to pass and was then skipped on every rerun)
      if [ -s "$out" ] && head -2 "$out" | grep -q "PollingPlace" && [ "$(wc -l < "$out")" -gt 3 ]; then skip=$((skip+1)); continue; fi
      if curl -sfL -A "$UA" -o "$out" "https://results.aec.gov.au/$ev/Website/$p" && head -2 "$out" | grep -q "PollingPlace" && [ "$(wc -l < "$out")" -gt 3 ]; then
        got=$((got+1)); n=$((n+1))
      else
        fail=$((fail+1)); echo "FAS!  failed: $p"; rm -f "$out"
      fi
    done
    echo "FAS1  fed$yr $st: $(printf '%s\n' $files | wc -l) divisions listed, $n fetched now"
  done
done
# 2004: the old results site keeps the same files as per-state zips under
# /12246/results/External/ (not the division menus above).
for st in $STATES; do
  csv="$D/fed2004-$st-SenateStateFirstPrefsByPollingPlaceDownload-12246-$st.csv"
  if [ -s "$csv" ]; then skip=$((skip+1)); continue; fi
  z="$D/fed2004-$st-SenateStateFirstPrefsByPollingPlaceDownload-12246.zip"
  if curl -sfL -A "$UA" -o "$z" "https://results.aec.gov.au/12246/results/External/SenateStateFirstPrefsByPollingPlaceDownload-12246-$st.zip"; then
    unzip -o -q -j "$z" "*.csv" -d "$D/tmp04" && mv "$D/tmp04/"*.csv "$csv" && rm -rf "$D/tmp04"; got=$((got+1))
  else fail=$((fail+1)); echo "FAS!  2004 $st failed"; fi
done
# 1998 and 2001: only in the AEC's election-statistics archives (raw
# SPPVOTE / SCANDS: Senate votes by polling place NAME, no polling-place id).
S="external/reference/aec/stats"; mkdir -p "$S"
for f in aec-2001-election-statistics.zip aec-1993-1996-1998-election-statistics.zip; do
  [ -s "$S/$f" ] || curl -sfL -A "$UA" -o "$S/$f" "https://www.aec.gov.au/About_AEC/Publications/statistics/files/$f" || { fail=$((fail+1)); echo "FAS!  $f failed"; }
done
# Extract only when missing: re-extracting both archives every run made a rerun
# that fetched nothing take 5.5 minutes (2026-10-02).
[ -s "$S/y2001/data/import/sppvote.txt" ] || unzip -o -q "$S/aec-2001-election-statistics.zip" "data/import/*" -d "$S/y2001" 2>/dev/null
[ -s "$S/y9398/data/import/tables98/SPPVOTE.TXT" ] || unzip -o -q "$S/aec-1993-1996-1998-election-statistics.zip" "data/import/tables98/SPPVOTE.TXT" "data/import/tables98/SCANDS.TXT" -d "$S/y9398" 2>/dev/null
echo "FAS3  1998/2001 Senate by polling place: $(wc -l < "$S/y9398/data/import/tables98/SPPVOTE.TXT" 2>/dev/null) / $(wc -l < "$S/y2001/data/import/sppvote.txt" 2>/dev/null) rows"
echo "FAS2  fetched $got, already on disk $skip, failed $fail"
[ -n "$empty_menus" ] && echo "FAS2! menus listing no polling-place files:$empty_menus"
# FAIL LOUDLY. This used to end in an unconditional `exit 0`, so a failed
# download or an empty division menu left a partial Senate set that the
# builders downstream read as complete.
[ "$fail" -eq 0 ] && [ -z "$empty_menus" ]
