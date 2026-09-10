#!/usr/bin/env bash
# Runs all 22 canonical pairs for ONE arm/seed. Each harness invocation is a
# separate Rscript process writing its own log, so a death partway loses only
# the remaining harnesses, not the completed ones.
#   ARM=ship|xgb  SEED=<n>  NSIMS=<n>  ENGINE=cpp|r
set -u
ARM="${ARM:?}"; SEED="${SEED:?}"; NSIMS="${NSIMS:?}"; ENGINE="${ENGINE:?}"
LOGDIR="C:/dev/auspol/output/_flowrun/${ARM}_s${SEED}"
mkdir -p "$LOGDIR"
cd "C:/dev/auspol" || exit 1

if [ "$ARM" = "xgb" ]; then export AUSPOL_XGB_FLOWS=1; else export AUSPOL_XGB_FLOWS=0; fi
export AUSPOL_SIM_ENGINE="$ENGINE"
export AUSPOL_N_SIMS="$NSIMS"
export AUSPOL_SEED="$SEED"
export AUSPOL_OUT_SUFFIX="-fr${ARM}s${SEED}"

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

run fed  scripts/backtest_candidate_fed.R
run nsw19 scripts/backtest_candidate_nsw.R AUSPOL_NSW_PAIR=2019
run nsw23 scripts/backtest_candidate_nsw.R AUSPOL_NSW_PAIR=2023
run qld20 scripts/backtest_candidate_qld.R AUSPOL_QLD_PAIR=2020
run qld24 scripts/backtest_candidate_qld.R AUSPOL_QLD_PAIR=2024
run sa26  scripts/backtest_candidate_sa.R
run vic   scripts/backtest_candidate_vic.R
run wa    scripts/backtest_candidate_wa.R
echo "ARM $ARM SEED $SEED COMPLETE"
