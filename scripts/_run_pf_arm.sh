#!/usr/bin/env bash
# Runs all 22 canonical pairs for ONE (primary x flows) arm/seed.
#
# The 2x2 Pete asked for on 2026-09-11: does the XGBoost primary challenger
# and the XGBoost flow model ADD, OVERLAP, or INTERFERE? Four cells:
#
#   PRIM=0 FLOW=0   shipped primaries, table flows          (the baseline)
#   PRIM=0 FLOW=1   shipped primaries, xgb flows
#   PRIM=1 FLOW=0   xgb primaries,     table flows
#   PRIM=1 FLOW=1   xgb primaries,     xgb flows
#
# All four run from ONE code state. The earlier ship_s*/xgb_s* directories are
# NOT reused: they predate the 2026-09-11 fix that populated dest_same /
# dest_same_mp at inference (R/xgb_flow_override.R), and predate the primary
# override defaulting to the v6 oof file rather than v1's, so their flow and
# primary arms both measure something else.
#
#   PRIM=0|1  FLOW=0|1  SEED=<n>  NSIMS=<n>  ENGINE=cpp|r
set -u
PRIM="${PRIM:?}"; FLOW="${FLOW:?}"; SEED="${SEED:?}"; NSIMS="${NSIMS:?}"; ENGINE="${ENGINE:?}"
ARM="p${PRIM}f${FLOW}"
LOGDIR="C:/dev/auspol/output/_pfrun/${ARM}_s${SEED}"
mkdir -p "$LOGDIR"
cd "C:/dev/auspol" || exit 1

export AUSPOL_XGB_PRIMARY="$PRIM"
export AUSPOL_XGB_FLOWS="$FLOW"
export AUSPOL_SIM_ENGINE="$ENGINE"
export AUSPOL_N_SIMS="$NSIMS"
export AUSPOL_SEED="$SEED"
export AUSPOL_OUT_SUFFIX="-pf${ARM}s${SEED}"

run () {  # run <label> <script> [extra env assignments...]
  local label="$1"; shift
  local script="$1"; shift
  local log="$LOGDIR/${label}.log"
  if [ -f "$log" ] && grep -qE "log score|log [0-9]" "$log"; then
    echo "SKIP $label (already has results)"; return 0
  fi
  echo "RUN  $label -> $log"
  env "$@" Rscript "$script" > "$log" 2>&1
  echo "DONE $label rc=$?"
}

run fed   scripts/backtest_candidate_fed.R
run nsw19 scripts/backtest_candidate_nsw.R AUSPOL_NSW_PAIR=2019
run nsw23 scripts/backtest_candidate_nsw.R AUSPOL_NSW_PAIR=2023
run qld20 scripts/backtest_candidate_qld.R AUSPOL_QLD_PAIR=2020
run qld24 scripts/backtest_candidate_qld.R AUSPOL_QLD_PAIR=2024
run sa26  scripts/backtest_candidate_sa.R
run vic   scripts/backtest_candidate_vic.R
run wa    scripts/backtest_candidate_wa.R
echo "ARM $ARM SEED $SEED COMPLETE"
