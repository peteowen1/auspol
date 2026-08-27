#!/bin/bash
# Sequentially fetch salience for every election with results data but no
# salience yet, one election per Rscript process (so a killed process only
# loses its own in-flight batch -- fetch_salience_v6.R caches per-batch to
# RDS and is idempotent, so re-running an already-partial election just picks
# up where it left off).
#
# Adaptive throttle backoff lives INSIDE fetch_salience_v6.R now (per-batch,
# within one election). This wrapper adds a second, coarser layer: if an
# election comes back with a high dropped-batch rate, it's a sign the whole
# run (not just one batch) is under pressure, so the gap before the NEXT
# election lengthens too.
set -uo pipefail
cd "$(dirname "$0")/.."

LOG="${1:-$TEMP/fetch_remaining_salience.log}"
BASE_GAP=180   # seconds between elections when nothing looks throttled

ELECTIONS=(fed2007 fed2010 fed2013 fed2016 fed2025 nsw2019 sa2022 vic2014 \
           qld2020 qld2024 wa1996 wa2001 wa2005 wa2008 wa2013 wa2017 wa2021 wa2025)

echo "=== fetch_salience_v6_remaining.sh starting $(date) ===" >> "$LOG"
echo "Elections queued: ${ELECTIONS[*]}" >> "$LOG"

gap=$BASE_GAP
for el in "${ELECTIONS[@]}"; do
  # Skip if this election's rows are already in salience-v6.csv (resumable
  # across separate launches of this wrapper, not just within one).
  if [ -f output/salience-v6.csv ] && awk -F, -v e="$el" '$2==e{found=1} END{exit !found}' output/salience-v6.csv; then
    echo "$(date '+%F %T')  SKIP ${el} -- already in output/salience-v6.csv" >> "$LOG"
    continue
  fi

  echo "$(date '+%F %T')  START ${el}" >> "$LOG"
  AUSPOL_SALIENCE_ELECTION="$el" Rscript scripts/fetch_salience_v6.R >> "$LOG" 2>&1
  rc=$?
  echo "$(date '+%F %T')  END ${el} (exit $rc)" >> "$LOG"

  # Coarse health check: count throttle-backoff lines and dropped-batch counts
  # for THIS election's run only (since the last START marker).
  section=$(awk -v e="START ${el}" '$0 ~ e{f=1} f' "$LOG")
  throttle_hits=$(echo "$section" | grep -c "S6T " || true)
  dropped=$(echo "$section" | grep "S6-2 stage 1:" | tail -1 | grep -oE "[0-9]+ dropped" | grep -oE "^[0-9]+" || echo 0)

  if [ "$throttle_hits" -gt 5 ] || { [ -n "$dropped" ] && [ "$dropped" -gt 20 ]; }; then
    gap=$((gap * 2))
    echo "$(date '+%F %T')  ${el}: ${throttle_hits} throttle hits, ${dropped} dropped -- doubling inter-election gap to ${gap}s" >> "$LOG"
  else
    gap=$BASE_GAP
  fi

  echo "$(date '+%F %T')  sleeping ${gap}s before next election" >> "$LOG"
  sleep "$gap"
done

echo "=== fetch_salience_v6_remaining.sh finished $(date) ===" >> "$LOG"
