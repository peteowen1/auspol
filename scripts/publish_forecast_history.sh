#!/usr/bin/env bash
# Keep a dated copy of each published Victorian forecast, so the ITG pages can
# show the forecast "as at <date>" (peteowen1/inthegame-blog#610).
#
# The daily run overwrites auspol/forecast-vic2026.json and vic-page-data.json
# on R2, and output/forecast-history.csv keeps chamber-level numbers only, so
# without this every past day's per-seat forecast is lost for good.
#
# Layout on R2 (bucket inthegame-data):
#   auspol/history/forecast-vic2026-<YYYY-MM-DD>.json   byte-identical copy, dated by built_at (UTC)
#   auspol/history/vic-page-data-<YYYY-MM-DD>.json       byte-identical copy, dated by meta.as_of
#   auspol/history/index-vic2026.json                    {"forecast": [...], "page_data": [...]}
#   auspol/history/index-vic2026.backup.json             same, so a lost index is detected, not restarted
# Dates: forecast entries use built_at's UTC date; page-data entries use
# meta.as_of as the page builder writes it. They are separate lists, not a join.
# Dated copies rather than a flattened table: every field the JSON carries is
# kept, and a reader gets back exactly the shape it already parses.
#
# Rules (from the request, 2026-10-07):
#   - Read the previous index first. ONLY an HTTP 404 means "no history yet";
#     any other status, or a body that is not a valid index, aborts.
#   - Never publish an index with fewer entries than the one read.
#   - Re-publishing the same date replaces that date's copy and index entry.
#   - Non-fatal: the workflow step runs with continue-on-error, after the live
#     files are already published, so this can never block them.
#
# Backends: R2 by default (read over the public URL, so the HTTP status is exact;
# write with wrangler). HISTORY_LOCAL_DIR=<dir> reads and writes a local
# directory instead, for tests (scripts/test_publish_forecast_history.sh).
set -euo pipefail

FORECAST=${FORECAST:-output/forecast-vic2026.json}
PAGEDATA=${PAGEDATA:-output/vic-page-data.json}
PREFIX=auspol/history
INDEX_KEY=$PREFIX/index-vic2026.json
BACKUP_KEY=$PREFIX/index-vic2026.backup.json
PUBLIC=${HISTORY_PUBLIC_BASE:-https://pub-ee4bf5b599a047f9ac2b9facc1587008.r2.dev}
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# get KEY OUT -> prints ok | absent; exits non-zero on anything else
get_obj() {
  if [ -n "${HISTORY_LOCAL_DIR:-}" ]; then
    if [ -f "$HISTORY_LOCAL_DIR/$1" ]; then cp "$HISTORY_LOCAL_DIR/$1" "$2"; echo ok; else echo absent; fi
    return 0
  fi
  # Cache-buster: the object is served with a short max-age; a stale index
  # would silently drop a date written minutes earlier.
  local code
  code=$(curl -sS -o "$2" -w '%{http_code}' --max-time 60 "$PUBLIC/$1?nocache=$(date +%s%N)") || { echo "history: read of $1 failed (network)" >&2; return 1; }
  case "$code" in
    200) echo ok ;;
    404) echo absent ;;
    *) echo "history: read of $1 returned HTTP $code -- not a 404, aborting" >&2; return 1 ;;
  esac
}

put_obj() {  # put KEY FILE CACHE_SECONDS
  if [ -n "${HISTORY_LOCAL_DIR:-}" ]; then
    mkdir -p "$(dirname "$HISTORY_LOCAL_DIR/$1")"; cp "$2" "$HISTORY_LOCAL_DIR/$1"; return 0
  fi
  wrangler r2 object put "inthegame-data/$1" --file "$2" --content-type application/json \
    --cache-control "public, max-age=$3" --remote >/dev/null
}

[ -s "$FORECAST" ] || { echo "history: $FORECAST missing or empty" >&2; exit 1; }
F_DATE=$(jq -er '.built_at[0:10]' "$FORECAST")
F_BUILT=$(jq -er '.built_at' "$FORECAST")
F_SHA=$(jq -r '.git_sha // ""' "$FORECAST")
[[ "$F_DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || { echo "history: bad built_at date '$F_DATE'" >&2; exit 1; }
N_SEATS=$(jq '.seats | length' "$FORECAST")

status=$(get_obj "$INDEX_KEY" "$WORK/old.json")
if [ "$status" = absent ]; then
  # The index is also kept as a backup copy. A 404 on the index while the
  # backup exists means the index was deleted or is unreachable, not that there
  # is no history: starting over would drop every earlier date from the index.
  bstatus=$(get_obj "$BACKUP_KEY" "$WORK/backup.json")
  if [ "$bstatus" != absent ]; then
    echo "history: index 404 but its backup exists -- refusing to start a new index (restore $INDEX_KEY from $BACKUP_KEY)" >&2
    exit 1
  fi
  echo '{"forecast": [], "page_data": []}' > "$WORK/old.json"
  echo "history: no index and no backup yet (404) -- starting one"
fi
# A 200 must be a real index: both arrays present, every entry dated.
jq -e '(.forecast | type == "array") and (.page_data | type == "array")
       and all(.forecast[], .page_data[]; (.as_at | type == "string"))' "$WORK/old.json" >/dev/null \
  || { echo "history: existing index is not a valid index, aborting" >&2; exit 1; }
OLD_F=$(jq '[.forecast[].as_at] | unique | length' "$WORK/old.json")
OLD_P=$(jq '[.page_data[].as_at] | unique | length' "$WORK/old.json")

# Dated copies first, then the index, so the index never names a missing file.
F_KEY=$PREFIX/forecast-vic2026-$F_DATE.json
put_obj "$F_KEY" "$FORECAST" 3600
jq --arg d "$F_DATE" --arg b "$F_BUILT" --arg s "$F_SHA" --arg k "$F_KEY" --argjson n "$N_SEATS" \
  '.forecast = ([.forecast[] | select(.as_at != $d)] + [{as_at: $d, built_at: $b, git_sha: $s, key: $k, n_seats: $n}] | sort_by(.as_at))' \
  "$WORK/old.json" > "$WORK/new.json"

if [ -s "$PAGEDATA" ] && P_DATE=$(jq -er '.meta.as_of' "$PAGEDATA") && [[ "$P_DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  P_KEY=$PREFIX/vic-page-data-$P_DATE.json
  put_obj "$P_KEY" "$PAGEDATA" 3600
  jq --arg d "$P_DATE" --arg k "$P_KEY" \
    '.page_data = ([.page_data[] | select(.as_at != $d)] + [{as_at: $d, key: $k}] | sort_by(.as_at))' \
    "$WORK/new.json" > "$WORK/new2.json" && mv "$WORK/new2.json" "$WORK/new.json"
else
  echo "::warning::history: $PAGEDATA missing or has no YYYY-MM-DD meta.as_of -- page data NOT recorded this run (forecast was)"
  PAGE_MISSING=1
fi

NEW_F=$(jq '.forecast | length' "$WORK/new.json")
NEW_P=$(jq '.page_data | length' "$WORK/new.json")
if [ "$NEW_F" -lt "$OLD_F" ] || [ "$NEW_P" -lt "$OLD_P" ]; then
  echo "history: new index is smaller than the one read ($NEW_F < $OLD_F or $NEW_P < $OLD_P), refusing" >&2
  exit 1
fi
put_obj "$INDEX_KEY" "$WORK/new.json" 60
put_obj "$BACKUP_KEY" "$WORK/new.json" 60
echo "history: forecast $NEW_F date(s): $(jq -r '[.forecast[].as_at] | join(", ")' "$WORK/new.json")"
echo "history: page data $NEW_P date(s): $(jq -r '[.page_data[].as_at] | join(", ")' "$WORK/new.json")"
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  echo "Forecast history: $NEW_F forecast date(s), $NEW_P page-data date(s); latest $F_DATE${PAGE_MISSING:+ (page data MISSING this run)}" >> "$GITHUB_STEP_SUMMARY"
fi
