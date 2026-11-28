#!/usr/bin/env bash
# Raw-count side process for the live night. Reads C:/night28/web only. Log: C:/night28/raw.log
mkdir -p /c/night28/web
exec >> /c/night28/raw.log 2>&1
cd /c/dev/auspol || exit 1
echo "armed $(date '+%H:%M:%S'), waiting for 18:00"
while [ "$(date +%H%M)" -lt 1800 ]; do sleep 5; done   # never before 6pm (standing rule)
echo "=== raw start $(date '+%Y-%m-%d %H:%M:%S')"
Rscript external/reference/benchmarks/vic2026-night/raw_watch.R C:/night28/web C:/night28/raw-vic2026.json auspol/night/raw-vic2026.json
echo "=== raw end rc=$? $(date '+%Y-%m-%d %H:%M:%S')"
