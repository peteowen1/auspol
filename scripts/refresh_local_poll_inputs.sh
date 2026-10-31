#!/usr/bin/env bash
# Bring a local checkout's poll inputs up to what the daily forecast run reads (.github/workflows/forecast.yaml,
# "Our own poll source" and "The Poll Bludger's poll tables"), so a local fit_seats_full.R run matches the live site.
# 2026-10-31: a local run on a 5-day-old anchor clone and a 13 Oct Wikipedia scrape gave One Nation 14.2 seats against
# the live site's 16.6, and an artifact was built from it.
#
#   bash scripts/refresh_local_poll_inputs.sh
#
# Writes output/polls-wiki/ (gitignored), which poll_layer() reads when it is newer than the local scrape folder.
# Needs gh (release downloads) and network access to Wikipedia and The Poll Bludger. Check codes RLP1-RLP4.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "RLP1 anchor clone before: $(git -C external/aus-polling-analyser log -1 --format='%h %ci')"
git -C external/aus-polling-analyser pull -q --ff-only
echo "RLP1 anchor clone now:    $(git -C external/aus-polling-analyser log -1 --format='%h %ci')"

mkdir -p output/polls-wiki
gh release download shipped-models -p statewide_polls_wiki.csv -p firm_alias.csv -p bludgertrack_polls.csv -p pb_llm_polls.csv \
  -D output/polls-wiki --clobber
for f in statewide_polls_wiki.csv firm_alias.csv bludgertrack_polls.csv pb_llm_polls.csv; do
  test -s "output/polls-wiki/$f" || { echo "RLP2! output/polls-wiki/$f downloaded empty"; exit 1; }
done
echo "RLP2 published poll tables downloaded"

LT=$(mktemp -d)
if AUSPOL_POLL_BASE="$LT" AUSPOL_POLL_ONLY=vic2026_opinion,nsw2027_opinion,fed2028_leaders Rscript scripts/fetch_statewide_poll_samples.R > "$LT/fetch.log" 2>&1 \
   && AUSPOL_LIVE_PAGES=vic2026_opinion,nsw2027_opinion,fed2028_leaders Rscript scripts/merge_live_poll_pages.R output/polls-wiki/statewide_polls_wiki.csv "$LT/statewide_polls_wiki.csv" "$LT/merged.csv" > "$LT/merge.log" 2>&1 \
   && test -s "$LT/merged.csv"; then
  mv "$LT/merged.csv" output/polls-wiki/statewide_polls_wiki.csv
  grep -E "^PM" "$LT/merge.log" || true
  echo "RLP3 live Wikipedia pages refetched and merged"
else
  echo "RLP3! live poll pages not refreshed; the published table is used. Logs: $LT"
  tail -n 20 "$LT/fetch.log" "$LT/merge.log" 2>/dev/null || true
fi

BT=$(mktemp -d)
if AUSPOL_BT_RAW="$BT" AUSPOL_BT_OUT="$BT/bludgertrack_polls.csv" Rscript scripts/build_bludgertrack_polls.R --fetch=fed2028,vic2026 --keep=output/polls-wiki/bludgertrack_polls.csv > "$BT/build.log" 2>&1 \
   && test -s "$BT/bludgertrack_polls.csv"; then
  mv "$BT/bludgertrack_polls.csv" output/polls-wiki/bludgertrack_polls.csv
  grep -E "^BK" "$BT/build.log" || true
  echo "RLP4 BludgerTrack tables refreshed"
else
  echo "RLP4! BludgerTrack tables not refreshed; the published table is used. Log: $BT/build.log"
fi
