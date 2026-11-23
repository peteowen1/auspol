#!/usr/bin/env bash
# ELECTION NIGHT, VICTORIA 2026, ONE COMMAND: the website fetcher and the night loop with the flags the website
# source needs (21 Nov 2026 dry run: the three-flag runbook stopped on NW9! for want of --turnout).
#
#   bash scripts/night_vic2026.sh <results index URL> <work dir> [--upload] [--upload-key=KEY] [--every=90] [--max-cycles=N] [--dry-2022] [--parallel=4]
#       [--retries=3] [--retry-pause=5,15,30]   (the GitHub backup passes --retries=6 --retry-pause=120; see the fetcher)
#
#   <results index URL>  the VEC page that links EVERY district's result page (2022's was
#                        .../2022-state-election-results; its /results-by-district child links none), or
#                        auto (find 2026's on https://www.vec.vic.gov.au/results/state-election-results) / auto:YEAR
#   <work dir>           snapshots in <work dir>/web, raw archive in /archive, logs and the JSON beside them
#   --upload             publish each good cycle to the live page's file (auspol/night/vic2026.json). Off by default,
#                        so a rehearsal can never overwrite the live page.
#   --upload-key=KEY     publish each good cycle to another file under auspol/night/ instead (tests, and the Actions
#                        backup's test key auspol/night/test-vic2026.json, which the live page never reads).
#   --every=N            seconds between fetches (default 90; one fetch of 174 pages takes about a minute)
#   --parallel=N         pages in flight at once (default 4). 1 = one at a time with a pause, about 5 minutes a fetch:
#                        for an address the VEC site rate-limits (HTTP 999 from a GitHub runner, 22 Nov 2026).
#   --max-cycles=N       stop both after N snapshots / N cycles (tests)
#   --dry-2022           rehearsal on the 2022 pages: drops Narracan (no 2022 page) and passes --allow-unmatched=1.
#                        Refuses --upload and the live key.
#
# Run from the repo root. Today's afternoon forecast state is downloaded into <work dir> (never into output/).
# The fetcher runs in the background and is stopped when the loop ends or this script is interrupted (Ctrl+C).
set -u
[ $# -ge 2 ] || { sed -n 2,24p "$0"; exit 2; }
INDEX="$1"; WORK="$2"; shift 2
UPLOAD=0; EVERY=90; MAXC=0; DRY=0; PAR=4; LIVE_KEY=auspol/night/vic2026.json; KEY=""; RETRIES=3; RPAUSE=5,15,30
for a in "$@"; do case "$a" in
  --upload) UPLOAD=1; KEY="$LIVE_KEY" ;; --upload-key=*) UPLOAD=1; KEY="${a#*=}" ;; --every=*) EVERY="${a#*=}" ;; --max-cycles=*) MAXC="${a#*=}" ;; --parallel=*) PAR="${a#*=}" ;; --dry-2022) DRY=1 ;;
  --retries=*) RETRIES="${a#*=}" ;; --retry-pause=*) RPAUSE="${a#*=}" ;;
  *) echo "NV1! unknown argument: $a"; exit 2 ;; esac; done
[ "$DRY" = 1 ] && [ "$KEY" = "$LIVE_KEY" ] && { echo "NV1! --dry-2022 with the live key would put 2022 results on the live page; refusing"; exit 2; }
[ "$UPLOAD" = 1 ] && [ -z "$KEY" ] && { echo "NV1! --upload-key= needs a key"; exit 2; }
[ -f scripts/night_loop.R ] || { echo "NV1! run from the repo root"; exit 2; }

V=external/reference/vec/2026
REF=output/booths-vic2026-ref.csv; LEAN=output/council-fp-2022.csv; TURN=output/council-district-stats-2022.csv
ENR=$V/enrolment/enrolment-2026.csv; PLACES=$V/voting-locations/places-2026.csv; CANDS=$V/vec-candidates-2026.csv
for f in "$REF" "$LEAN" "$TURN" "$ENR" "$PLACES" "$CANDS"; do [ -s "$f" ] || { echo "NV2! missing or empty input: $f"; exit 1; }; done

# auto: the VEC's results landing page links each state election's results page, named inconsistently
# (2018: /2018-state-election, 2022: /2022-state-election-results), so take the one link that starts with the year.
# Not found means the page is not up yet: say so and stop, rather than run on a guessed address.
case "$INDEX" in auto|auto:[0-9][0-9][0-9][0-9])
  YR=2026; [ "$INDEX" != auto ] && YR="${INDEX#auto:}"
  LAND=https://www.vec.vic.gov.au/results/state-election-results
  PAGE=$(curl -fsSL --retry 3 --max-time 60 -A "auspol election-night reader (personal, non-commercial)" "$LAND") \
    || { echo "NV0! could not read $LAND"; exit 1; }
  HITS=$(printf '%s' "$PAGE" | grep -oE "href=\"/results/state-election-results/${YR}-[a-z-]*\"" | sort -u | sed -E 's/^href="|"$//g')
  N=$(printf '%s' "$HITS" | grep -c . || true)
  [ "$N" = 1 ] || { echo "NV0! $N link(s) on $LAND start with /results/state-election-results/${YR}- (need exactly 1): ${HITS:-none}"; exit 1; }
  INDEX="https://www.vec.vic.gov.au$HITS"
  echo "NV0  index found: $INDEX" ;;
esac

mkdir -p "$WORK/web" "$WORK/archive"
STATE="$WORK/night-state-vic-2026.rds"
gh release download forecast-latest -p night-state-vic-2026.rds -D "$WORK" --clobber || { echo "NV3! could not download the night state"; exit 1; }
[ -s "$STATE" ] || { echo "NV3! night state missing after download: $STATE"; exit 1; }
echo "NV3  night state $(wc -c < "$STATE") bytes, release asset updated $(gh release view forecast-latest --json assets -q '.assets[] | select(.name=="night-state-vic-2026.rds") | .updatedAt')"

FETCH_ARGS=(--index="$INDEX" --out="$WORK/web" --every="$EVERY" --max-cycles="$MAXC" --parallel="$PAR" --retries="$RETRIES" --retry-pause="$RPAUSE")
LOOP_ARGS=(--every=30 --max-cycles="$MAXC" --source-type=web --source="$WORK/web" --archive="$WORK/archive" --state="$STATE"
           --ref="$REF" --council-lean="$LEAN" --turnout="$TURN" --enrolment="$ENR" --places="$PLACES" --out="$WORK/forecast-night.json")
if [ "$DRY" = 1 ]; then
  PY="$(command -v python3 || command -v python || true)"   # GitHub's Ubuntu runners have no `python`
  [ -n "$PY" ] || { echo "NV4! no python3 or python on PATH"; exit 1; }
  D=$("$PY" -c "import csv,sys; print(','.join(sorted({r['district'].replace(' District','') for r in csv.DictReader(open(sys.argv[1], encoding='utf-8-sig'))} - {'Narracan'})))" "$CANDS") || { echo "NV4! could not build the 2022 district list"; exit 1; }
  FETCH_ARGS+=(--districts="$D"); LOOP_ARGS+=(--allow-unmatched=1)
  echo "NV4  DRY RUN on 2022 pages: $(echo "$D" | tr ',' '\n' | wc -l) districts, Narracan dropped, unmatched seats allowed"
fi
[ "$UPLOAD" = 1 ] && LOOP_ARGS+=(--upload-key="$KEY")
echo "NV5  upload: $([ "$UPLOAD" = 1 ] && echo "ON, to $KEY$([ "$KEY" = "$LIVE_KEY" ] && echo " (THE LIVE PAGE)")" || echo off); fetch every ${EVERY}s; work dir $WORK"

# Set before either starts, so an interrupt between the two launches cannot leave one behind. Ctrl+C / TERM exit 130
# (and the EXIT trap then stops both); without the explicit exit the script carried on and printed a false NV8.
FPID=""; LPID=""
trap '[ -n "$FPID" ] && kill "$FPID" 2>/dev/null; [ -n "$LPID" ] && kill "$LPID" 2>/dev/null' EXIT
trap 'echo "NV9  interrupted; stopping the fetcher and the loop"; exit 130' INT TERM
Rscript scripts/fetch_vec_web_snapshot.R "${FETCH_ARGS[@]}" > "$WORK/fetch.log" 2>&1 &
FPID=$!
echo "NV6  fetcher started (pid $FPID, log $WORK/fetch.log); starting the loop (log $WORK/archive/night-loop.log)"
Rscript scripts/night_loop.R "${LOOP_ARGS[@]}" &
LPID=$!
# Whichever ends first. A fetcher that DIES (wrong index page, VWF2!) would otherwise leave the loop waiting on an
# empty folder with nothing said until its 20-minute stale warning: stop and say so at once.
wait -n "$FPID" "$LPID"; FIRST=$?
if kill -0 "$LPID" 2>/dev/null; then          # the loop is still running, so it was the fetcher that ended
  if [ "$FIRST" -ne 0 ]; then
    echo "NV8! the fetcher stopped (rc $FIRST); the loop is being stopped too. Last lines of $WORK/fetch.log:"
    tail -4 "$WORK/fetch.log"
    kill "$LPID" 2>/dev/null; exit 1
  fi
  wait "$LPID"; RC=$?                          # a bounded fetcher (--max-cycles) finished cleanly: let the loop finish
else
  RC=$FIRST
fi
# a fetcher that died early leaves the loop waiting forever on the night; say so at the end of a bounded run
grep -E 'VWF[0-9]!|Error' "$WORK/fetch.log" | tail -3
echo "NV7  loop ended rc=$RC; snapshots with DONE: $(ls "$WORK"/web/*/DONE 2>/dev/null | wc -l)"
exit $RC
