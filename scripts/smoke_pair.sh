#!/usr/bin/env bash
# THE FAST LOOP: test a base_pred change on ONE pair in minutes, not a rebuild.
#
#   bash scripts/smoke_pair.sh sa 2026                 # AUSPOL_SA_PAIR=2026
#   bash scripts/smoke_pair.sh vic                     # all three vic pairs
#   bash scripts/smoke_pair.sh nsw 2023 AUSPOL_STATE_DEV=2   # extra switches
#
# Runs the harness with the xgb layer OFF (base_pred only: the sharedetail
# point estimate is deterministic, so 500 sims is as good as 20,000 for it),
# (the file carries an -n500- tag), then scripts/smoke_diff.R prints what moved
# against the newest stage-1 file of the last rebuild (the reference
# vintage): cells changed, the largest moves, and each class's RMSE against
# the actual result before and after. Two to five minutes per harness.
#
# What it does NOT do: retrain the as-at xgb models or touch the ledger. A
# change that moves the right cells the right way here still needs the full
# rebuild (scripts/rebuild_forecasts.sh) as its deciding run; a change that
# moves nothing here has no reason to be rebuilt at all.
set -euo pipefail
H="${1:?harness: fed nsw qld sa vic wa}"; shift || true
PAIR="${1:-}"; if [[ -n "$PAIR" && "$PAIR" =~ ^[0-9]{4}$ ]]; then shift; else PAIR=""; fi
export AUSPOL_XGB_PRIMARY=0 AUSPOL_SMOKE_SIMS="${AUSPOL_SMOKE_SIMS:-500}" AUSPOL_N_SIMS="$AUSPOL_SMOKE_SIMS"
case "$H" in nsw) [ -n "$PAIR" ] && export AUSPOL_NSW_PAIR="$PAIR" ;; qld) [ -n "$PAIR" ] && export AUSPOL_QLD_PAIR="$PAIR" ;; sa) [ -n "$PAIR" ] && export AUSPOL_SA_PAIR="$PAIR" ;; esac
for kv in "$@"; do export "$kv"; done
LOG="output/smoke-$H${PAIR:+-$PAIR}.log"
echo "smoke: $H ${PAIR:-all pairs} | sims $AUSPOL_N_SIMS | extra: $* | log $LOG"
Rscript "scripts/backtest_candidate_$H.R" > "$LOG" 2>&1 || { echo "harness FAILED, see $LOG"; tail -5 "$LOG"; exit 1; }
grep -E "^(SP1|BS0|BV0|BW0|BQ0|BN0|BF0)" "$LOG" | head -12 || true
Rscript scripts/smoke_diff.R "$H" "$PAIR"
