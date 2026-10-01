#!/usr/bin/env bash
# South Australia 2018 House of Assembly results BY POLLING BOOTH, every district.
#
# The commission's results API (scripts/fetch_sa2026.py) serves 2022 and 2026
# only; external/reference/ecsa/ha-2018-03-17.json is an empty response. The
# 2018 booth results live as static pages on the commission's site:
#   https://www.ecsa.sa.gov.au/html/results/2018/<District>2.html  (by booth)
#   https://www.ecsa.sa.gov.au/html/results/2018/<District>.html   (district summary)
# District names are read from the 2018 results index page, not hardcoded.
#
# Raw pages stored unedited at external/reference/ecsa/2018/<District>{,2}.html.
# Idempotent: a page already on disk ending in </html> is skipped. Fails if the
# index lists fewer than 47 districts or any page cannot be fetched whole.
#
# Run from repo root: bash scripts/fetch_ecsa_booths_2018.sh
set -uo pipefail
D="external/reference/ecsa/2018"; mkdir -p "$D"
UA="Mozilla/5.0 (auspol research; github.com/peteowen1/auspol)"
BASE="https://www.ecsa.sa.gov.au"
IDX="$BASE/elections/past-state-election-results?view=article&id=124:2018-state-election-results-breakdown&catid=12:elections"
curl -sfL -A "$UA" "$IDX" -o "$D/index.html" || { echo "ESB!  index fetch failed"; exit 1; }
dists=$(grep -oE '/html/results/2018/[A-Za-z_]+2\.html' "$D/index.html" | sed -E 's#.*/2018/(.*)2\.html#\1#' | sort -u)
n=$(printf '%s\n' "$dists" | grep -c .)
[ "$n" -ge 47 ] || { echo "ESB!  index lists $n districts, expected 47"; exit 1; }
got=0; skip=0; fail=0
while IFS= read -r d; do
  for suf in "" "2"; do
    out="$D/${d}${suf}.html"
    if [ -s "$out" ] && tail -c 200 "$out" | tr 'A-Z' 'a-z' | grep -q "</html>"; then skip=$((skip+1)); continue; fi
    if curl -sfL -A "$UA" -o "$out" "$BASE/html/results/2018/${d}${suf}.html" && tail -c 200 "$out" | tr 'A-Z' 'a-z' | grep -q "</html>"; then
      got=$((got+1))
    else
      fail=$((fail+1)); echo "ESB!  failed: ${d}${suf}"; rm -f "$out"
    fi
  done
done <<< "$dists"
echo "ESB1  SA 2018: $n districts, fetched $got pages, already on disk $skip, failed $fail"
[ "$fail" -eq 0 ]
