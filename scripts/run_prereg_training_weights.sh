#!/usr/bin/env bash
# Runs the arms of docs/plans/prereg-training-weights-2026-10-13.md one after another: each a rebuild from stage 4
# (as-at and production vote-share models refitted, harnesses rerun) with vic2010 IN training, then saves the
# per-election scores. P0 (vic2010 in, unweighted) is the already-measured bundle run
# (deciding-runs/bundle-20261013/pooled-backtest.csv). Waits for memory before each arm (scratch memready.ps1 rule:
# >8 GB free, or >6 GB with no other session's R job). Leaves output/ in the LAST arm's state: rerun the published
# configuration (AUSPOL_REBUILD_FROM=4, no switches) before any publish. AUSPOL_TRAIN_SKIP_PAIRS=none, not empty:
# rebuild_forecasts.sh exports the published value (vic2010) for any switch that is unset OR EMPTY.
set -u
cd "$(dirname "$0")/.."
OUTD=deciding-runs/prereg-training-weights; mkdir -p "$OUTD"
MEM=${MEMREADY:-}
arms=("P1|AUSPOL_TRAIN_DECAY_H=8 AUSPOL_TRAIN_COMPLETENESS=1"
      "P2|AUSPOL_TRAIN_DECAY_H=8"
      "P3|AUSPOL_TRAIN_DEMEAN=1"
      "P4|AUSPOL_TRAIN_DEMEAN=1 AUSPOL_TRAIN_DECAY_H=8")
for a in "${arms[@]}"; do
  name=${a%%|*}; sw=${a#*|}
  if [ -s "$OUTD/$name.csv" ]; then echo "$name already done, skipping"; continue; fi
  if [ -n "$MEM" ]; then until powershell.exe -NoProfile -File "$MEM" | grep -q READY; do sleep 60; done; fi
  echo "=== $name ($sw) start $(date +%H:%M)"
  env $sw AUSPOL_TRAIN_SKIP_PAIRS=none AUSPOL_ASAT_FORCE=1 AUSPOL_REBUILD_FROM=4 AUSPOL_REBUILD_SLOTS=2 \
    bash scripts/rebuild_forecasts.sh > "$OUTD/$name.log" 2>&1
  st=$?
  echo "=== $name exit $st at $(date +%H:%M)"
  [ $st -eq 0 ] && cp output/pooled-backtest.csv "$OUTD/$name.csv"
done
