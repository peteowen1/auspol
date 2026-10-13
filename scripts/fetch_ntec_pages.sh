#!/bin/bash
# Download the NT Electoral Commission's Legislative Assembly results pages
# (2016, 2020, 2024: one page per division plus the two summaries) and the 2012
# results book, into external/reference/ntec/raw/. Raw pages are kept; parsing
# is scripts/fetch_results_nt.R.
#
# The site sits behind Cloudflare: plain fetchers get 403 or a "Just a moment"
# challenge page, a browser user agent gets the page. A challenge page is
# retried with a back-off rather than saved, and a file already on disk is
# skipped, so a rerun only fills gaps. 2024's links point at
# /current-elections/, which now redirects to /past-elections/legislative-assembly/.
#
# Run from the repo root: bash scripts/fetch_ntec_pages.sh
set -u
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36"
BASE="https://ntec.nt.gov.au/elections/past-elections/legislative-assembly"
RAW="external/reference/ntec/raw"
mkdir -p "$RAW/div"
get() {  # $1 url, $2 out
  [ -s "$2" ] && ! grep -q "Just a moment" "$2" && return 0
  for t in 1 2 3 4; do
    curl -sL -A "$UA" -o "$2" "$1"
    grep -q "Just a moment" "$2" || return 0
    sleep $((t * 5))
  done
  echo "!! still a challenge page after 4 tries: $1"
}
get "$BASE" "$RAW/past-elections-index.html"
get "$BASE/pdf-results/2012_la_general_election.pdf" "$RAW/2012_la_general_election.pdf"
for y in 2016 2020 2024; do
  get "$BASE/$y-territory-election" "$RAW/la$y-index.html"
  get "$BASE/$y-territory-election/results" "$RAW/la$y-results.html"
  for u in $(grep -o 'href="[^"]*"' "$RAW/la$y-results.html" | grep -i "$y-territory-election/results/" | sed 's/href="//;s/"$//' | sort -u); do
    get "${u/current-elections/past-elections/legislative-assembly}" "$RAW/div/$y-$(basename "$u").html"
    sleep 1
  done
done
# The 2012 book as text: -layout for the summary tables, -raw for the distributions.
command -v pdftotext >/dev/null && {
  pdftotext -layout "$RAW/2012_la_general_election.pdf" "$RAW/2012_la_general_election.txt"
  pdftotext -raw "$RAW/2012_la_general_election.pdf" "$RAW/2012_la_general_election_raw.txt"
}
echo "pages on disk: $(ls "$RAW/div" | wc -l)"
