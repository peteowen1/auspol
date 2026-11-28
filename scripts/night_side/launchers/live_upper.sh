#!/usr/bin/env bash
# Upper house (Legislative Council) raw pages for the live night (Pete via ITG, 8:50pm): the 8 VEC region summary pages,
# every 10 minutes, one at a time, saved raw to C:/night28/upper/<YYYYMMDD_HHMMSS>/ with a DONE marker. If ITG's parser
# exists (external/reference/benchmarks/vic2026-night/upper_parse.py <folder> <out.json>) and writes valid JSON with
# "regions", it is uploaded to auspol/night/raw-upper-house-vic2026.json. Nothing here touches the Assembly run.
exec >> /c/night28/upper.log 2>&1
cd /c/dev/auspol || exit 1
UA="auspol election-night reader (personal, non-commercial)"
B=https://www.vec.vic.gov.au/results/2026-results/region-election-page/region-summary-page
REG="Eastern-Victoria North-Eastern-Metropolitan Northern-Metropolitan Northern-Victoria South-Eastern-Metropolitan Southern-Metropolitan Western-Metropolitan Western-Victoria"
PARSER=external/reference/benchmarks/vic2026-night/upper_parse.py
echo "=== upper start $(date '+%H:%M:%S')"
while true; do
  ST=$(date +%Y%m%d_%H%M%S); D=/c/night28/upper/$ST; mkdir -p "$D"; ok=0
  for r in $REG; do
    code=$(curl -s -o "$D/$r.html" -w '%{http_code}' --max-time 60 -A "$UA" "$B/$r-Region-results")
    if [ "$code" = 200 ] && grep -q "</html>" "$D/$r.html"; then ok=$((ok+1)); else rm -f "$D/$r.html"; echo "$(date '+%H:%M:%S') UPPER page failed: $r ($code)"; fi
    sleep 1
  done
  if [ "$ok" = 8 ]; then date '+%Y-%m-%dT%H:%M:%S+1100' > "$D/DONE"; else echo "$(date '+%H:%M:%S') UPPER $ST: $ok of 8 pages, no DONE"; fi
  if [ "$ok" = 8 ] && [ -f "$PARSER" ]; then
    if python -I "$PARSER" "$D" /c/night28/raw-upper-house-vic2026.json.tmp && python -I -c "import json,sys; d=json.load(open(sys.argv[1],encoding='utf-8')); assert len(d['regions'])>=1" /c/night28/raw-upper-house-vic2026.json.tmp; then
      mv /c/night28/raw-upper-house-vic2026.json.tmp /c/night28/raw-upper-house-vic2026.json
      up=$(timeout 90 wrangler r2 object put "inthegame-data/auspol/night/raw-upper-house-vic2026.json" --file C:/night28/raw-upper-house-vic2026.json --content-type application/json --cache-control "public, max-age=60" --remote 2>&1 | grep -E "Upload complete|rror" | head -1)
      echo "$(date '+%H:%M:%S') UPPER $ST: 8 pages, parsed, $up"
    else echo "$(date '+%H:%M:%S') UPPER $ST: parser failed or wrote invalid JSON; nothing uploaded"; fi
  else echo "$(date '+%H:%M:%S') UPPER $ST: $ok of 8 pages saved$([ -f "$PARSER" ] || echo '; no parser yet')"; fi
  sleep 600
done
