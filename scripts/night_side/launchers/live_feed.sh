#!/usr/bin/env bash
# "Latest booths in" feed for the live night. Reads C:/night28/web only. Log: C:/night28/feed.log
exec >> /c/night28/feed.log 2>&1
cd /c/dev/auspol || exit 1
echo "=== feed start $(date '+%Y-%m-%d %H:%M:%S')"
cp -n /c/night28/test-booth-seen.csv /c/night28/booth-seen.csv
Rscript external/reference/benchmarks/vic2026-night/feed_watch.R C:/night28/web C:/night28/booth-feed-vic2026.json C:/night28/booth-seen.csv auspol/night/booth-feed-vic2026.json
echo "=== feed end rc=$? $(date '+%Y-%m-%d %H:%M:%S')"
