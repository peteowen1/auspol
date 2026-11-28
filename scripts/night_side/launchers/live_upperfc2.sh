#!/usr/bin/env bash
# LIVE upper-house FORECAST v2 (Pete, 10:20pm): pass 1 = the upper-house model on the live lower-house first preferences
# with the narrowing measured tonight; pass 2 = the same model after blending in the de-biased upper-house COUNT.
exec >> /c/night28/upperfc.log 2>&1
cd /c/dev/auspol || exit 1
U="C:\Users\peteo\AppData\Local/Temp/claude/dc1a17ec65ae517e/84b0a040-f8c3-4d70-ae3c-76955732c65d/scratchpad/upperlive"
echo "=== upper forecast v2 start $(date '+%H:%M:%S')"
while true; do
  if Rscript "$U/mk_live2.R" base C:/night28/forecast-night.json "$U/pre" "$U/live" > "$U/mk.log" 2>&1 && Rscript scripts/build_upper_house_forecast.R --dir="$U/live" --out="$U/pass1.json" --sims=4000 > "$U/build1.log" 2>&1      && Rscript "$U/mk_live2.R" blend C:/night28/forecast-night.json "$U/pre" "$U/live" "$U/pass1.json" C:/night28/raw-vic2026.json C:/night28/raw-upper-house-vic2026.json > "$U/mk2.log" 2>&1      && Rscript scripts/build_upper_house_forecast.R --dir="$U/live" --out="$U/upper-house-forecast-live.json" --sims=4000 > "$U/build.log" 2>&1; then
    up=$(timeout 90 wrangler r2 object put "inthegame-data/auspol/night/upper-house-forecast-live-vic2026.json" --file "$U/upper-house-forecast-live.json" --content-type application/json --cache-control "public, max-age=60" --remote 2>&1 | grep -E "Upload complete|rror" | head -1)
    echo "$(date '+%H:%M:%S') UPPERFC v2 $(grep -m1 'narrowing' "$U/mk.log" | cut -c1-70) | $(grep -E '^ +Coalition +[0-9]' "$U/build.log" | tail -1) | $up"
  else echo "$(date '+%H:%M:%S') UPPERFC FAILED: $(tail -1 "$U/build.log" | cut -c1-160)"; fi
  sleep 420
done
