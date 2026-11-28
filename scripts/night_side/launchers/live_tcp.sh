#!/usr/bin/env bash
# Seat-level two-candidate totals from the VEC district pages, every 6 minutes, while the by-booth 2CP pages are down.
# Also the guard: model 2CP v counted 2CP per seat (C:/night28/tcpcheck/check.log). Reads the night file; never writes it.
exec >> /c/night28/tcp.log 2>&1
cd /c/dev/auspol || exit 1
echo "=== tcp totals start $(date '+%H:%M:%S')"
while true; do
  python -I external/reference/benchmarks/vic2026-night/check_tcp.py C:/night28/forecast-night.json C:/night28/tcpcheck > /c/night28/tcpcheck/check.log 2>&1
  echo "$(date '+%H:%M:%S') $(head -1 /c/night28/tcpcheck/check.log | cut -c1-110) | $(tail -1 /c/night28/tcpcheck/check.log | cut -c1-110)"
  timeout 90 wrangler r2 object put "inthegame-data/auspol/night/tcp-totals-vic2026.json" --file C:/night28/tcpcheck/tcp-seat-totals.json --content-type application/json --cache-control "public, max-age=60" --remote 2>&1 | grep -E "Upload complete|rror" | head -1
  sleep 300
done
