#!/usr/bin/env bash
# Upload one election-night JSON to the inthegame-data R2 bucket (map #148, page #162).
#
#   bash scripts/night_publish_r2.sh <file.json> [r2-key]      # default key auspol/night/vic2026.json
#   NIGHT_R2_DRY=1 bash scripts/night_publish_r2.sh <file.json>  # validate and print the command, upload nothing
#
# Same mechanism as the daily forecast (.github/workflows/forecast.yaml: wrangler r2 object put), with a 30-second
# cache instead of 5 minutes so readers see each cycle. Refuses (exit 2) a file that is missing, not valid JSON, or
# has no `night` block, so a damaged or afternoon file can never overwrite the live night file. The token is read by
# wrangler from CLOUDFLARE_API_TOKEN (never passed on the command line, never written anywhere).
# Check codes: NWU1 (bad input or key outside auspol/night/), NWU2 (upload failed, with wrangler's last line, token scrubbed), NWU3 (uploaded).
set -euo pipefail
f="${1:-}"; key="${2:-auspol/night/vic2026.json}"
# only ever writes under auspol/night/, so a mistyped key can never overwrite the afternoon forecast
case "$key" in auspol/night/*.json) ;; *) echo "NWU1! refusing key '$key': must be auspol/night/<name>.json" >&2; exit 2 ;; esac
if [ -z "$f" ] || [ ! -s "$f" ]; then echo "NWU1! no such file or empty: '$f'" >&2; exit 2; fi
python -I -c 'import json,sys; d=json.load(open(sys.argv[1],encoding="utf-8")); n=d.get("night"); sys.exit(0 if isinstance(n,dict) and n.get("snapshot_stamp") and d.get("seats") else 3)' "$f" 2>/dev/null \
  || { echo "NWU1! $f is not a night JSON (needs valid JSON with a night block carrying snapshot_stamp, and seats)" >&2; exit 2; }
cmd=(wrangler r2 object put "inthegame-data/$key" --file "$f" --content-type application/json --cache-control "public, max-age=30" --remote)
if [ "${NIGHT_R2_DRY:-0}" = "1" ]; then echo "NWU3  dry run, would run: ${cmd[*]}"; exit 0; fi
if [ -z "${CLOUDFLARE_API_TOKEN:-}" ]; then echo "NWU2! CLOUDFLARE_API_TOKEN is not set; nothing uploaded" >&2; exit 1; fi
# 90-second cap so a hung upload cannot stall the polling loop; on failure print wrangler's last line, token scrubbed
log="$(mktemp)"; trap 'rm -f "$log"' EXIT
if ! timeout 90 "${cmd[@]}" >"$log" 2>&1; then
  why="$(grep -v '^\s*$' "$log" | tail -n 1 | sed "s|${CLOUDFLARE_API_TOKEN}|<token>|g")"
  echo "NWU2! upload of $f to $key failed: ${why:-no output (timed out or wrangler not on PATH)}" >&2; exit 1
fi
echo "NWU3  uploaded $f -> https://pub-ee4bf5b599a047f9ac2b9facc1587008.r2.dev/$key"
