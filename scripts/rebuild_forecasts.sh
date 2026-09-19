#!/usr/bin/env bash
# ONE COMMAND that rebuilds the backtests the way production is built, end to
# end, in the only order that is not circular. Pete, 2026-09-18: the AEF-7
# ledger must be built by the production pipeline, not a parallel one, so a
# fix in either place always flows through to the other.
#
#   1. six harnesses at AUSPOL_XGB_PRIMARY=0  -> the TRUE shipped-model
#      base_pred per (pair, seat, class), no xgb layer (the non-circular
#      baseline; scripts/pool_sharedetail.R's header explains why this order)
#   2. pool_sharedetail.R                       -> pooled-sharedetail.csv
#   3. fit_xgb_primary_v6.R                     -> xgb-primary-features-v6.csv
#      (fresh base_pred + every feature; its leave-one-out OOF file is a
#      diagnostic now, not what ships)
#   4. fit_xgb_primary_asat.R                   -> one model per election, "as
#      at" the day before it, and the predictions file the harnesses read
#   4b. fit_xgb_flows_asat.R                 -> one flow model per election from earlier
#      elections only (read under AUSPOL_FLOW_ASAT=1; skips models already current)
#   5. fit_xgb_primary_v6_final.R               -> the PRODUCTION model, same
#      recipe, cutoff = now, same features vintage
#   6. six harnesses at shipped flags (AUSPOL_XGB_PRIMARY=1 reading the as-at
#      file via published_flags.R)              -> seat probabilities
#   7. pool_backtests.R + build_forecasts_table.R -> forecasts.csv,
#      forecasts-seats.csv, and the pooled scoreboard
#   8. build_aef_comparison.R + build_aef7_tcp_actual.R + build_aef7_ledger_data.R
#      -> ledger JSON
#   9. (AUSPOL_PUBLISH=1) promote_rebuild.R + publish_shipped_release.R -> the
#      shipped-models release the daily forecast job downloads
#
# AUSPOL_N_SIMS defaults to 20000 -- the DECIDING run, because stage 3 trains
# on base_pred, which is a simulation mean, and pool_sharedetail.R refuses
# anything thinner (AUSPOL_POOL_MIN_SIMS). For a fast end-to-end proof of the
# chain, AUSPOL_N_SIMS=5000 also lowers that guard to match, so the run goes
# through -- but its models are exploratory and must not ship. Harness
# stages run in parallel -- ~12GB free RAM was enough at 5000 (measured
# 2026-09-18); check free memory before a 20000-sim run. Every stage is timed
# and the split printed at the end, because the bottleneck pass is part of
# the job (~/.claude/CLAUDE.md).
set -euo pipefail
cd "$(dirname "$0")/.."
export AUSPOL_N_SIMS="${AUSPOL_N_SIMS:-20000}"
export AUSPOL_POOL_MIN_SIMS="${AUSPOL_POOL_MIN_SIMS:-$AUSPOL_N_SIMS}"
if [ "$AUSPOL_N_SIMS" -lt 20000 ]; then echo "!! AUSPOL_N_SIMS=$AUSPOL_N_SIMS: exploratory run, its models must not ship"; fi
LOG="output/rebuild-forecasts-logs"; mkdir -p "$LOG"
declare -A T0 TT
stage() { T0[$1]=$(date +%s); echo "=== [$1] $(date +%H:%M:%S) ==="; }
done_stage() { TT[$1]=$(( $(date +%s) - T0[$1] )); echo "=== [$1] done in ${TT[$1]}s ==="; }
# EVERY PAIR, not every harness. fed/wa/vic score all their pairs in one
# run; nsw, qld and sa score ONE pair per run, selected by AUSPOL_NSW_PAIR /
# AUSPOL_QLD_PAIR / AUSPOL_SA_PAIR (defaults 2023 / 2024 / 2026). The first
# version of this script ran each harness once, and pool_sharedetail.R
# correctly refused to pool: nsw2019, qld2020 and sa2022 still had an older,
# contaminated file as their newest. Two waves, because the second-pair runs
# are small and the big three plus the flagship pairs already load the box.
run_wave() {  # $1 = XGB_PRIMARY value, $2 = log tag, then "harness:ENV=val" specs
  local xgb="$1" tag="$2"; shift 2
  local pids=()
  for spec in "$@"; do
    local h="${spec%%:*}" envs="${spec#*:}"; [ "$envs" = "$spec" ] && envs=""
    local name="$h"; [ -n "$envs" ] && name="${h}_${envs##*=}"
    ( [ -n "$envs" ] && export "$envs"; AUSPOL_XGB_PRIMARY="$xgb" Rscript "scripts/backtest_candidate_${h}.R" ) \
      > "$LOG/${tag}_${name}.log" 2>&1 &
    pids+=($!)
  done
  local fail=0
  for p in "${pids[@]}"; do wait "$p" || fail=1; done
  if [ "$fail" -ne 0 ]; then echo "!! a harness failed -- see $LOG/${tag}_*.log"; exit 1; fi
}
free_gb() { local v; v=$(powershell.exe -Command "[int]((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory/1MB)" 2>/dev/null | tr -d '\r\n'); case "$v" in ""|*[!0-9]*) echo 0 ;; *) echo "$v" ;; esac; }
run6() {  # $1 = XGB_PRIMARY value, $2 = log tag -- all 23 pairs across the six harnesses
  # Six harnesses in parallel need ~10GB free at 20,000 sims (fed peaks ~2.3GB). On
  # 2026-09-18 23:40 a six-wide wave was killed by the memory watchdog with 4GB free
  # (Chrome + other Claude sessions held the rest); waves of two fit. Measured, not
  # guessed: the threshold is what the killed and the surviving runs had.
  local fg; fg=$(free_gb)
  if [ "${fg:-0}" -ge 10 ]; then
    run_wave "$1" "$2" fed wa vic nsw:AUSPOL_NSW_PAIR=2023 qld:AUSPOL_QLD_PAIR=2024 sa:AUSPOL_SA_PAIR=2026
    run_wave "$1" "$2" nsw:AUSPOL_NSW_PAIR=2019 qld:AUSPOL_QLD_PAIR=2020 sa:AUSPOL_SA_PAIR=2022
  else
    echo "!! only ${fg}GB free -- running the harnesses two at a time (slower, survives the memory watchdog)"
    run_wave "$1" "$2" fed vic
    run_wave "$1" "$2" wa nsw:AUSPOL_NSW_PAIR=2023
    run_wave "$1" "$2" qld:AUSPOL_QLD_PAIR=2024 sa:AUSPOL_SA_PAIR=2026
    run_wave "$1" "$2" nsw:AUSPOL_NSW_PAIR=2019 qld:AUSPOL_QLD_PAIR=2020
    run_wave "$1" "$2" sa:AUSPOL_SA_PAIR=2022
  fi
}

stage "1-harnesses-base_pred"; run6 0 s1; done_stage "1-harnesses-base_pred"
stage "2-pool-sharedetail";    Rscript scripts/pool_sharedetail.R      > "$LOG/s2_pool.log" 2>&1; done_stage "2-pool-sharedetail"
stage "3-features";            Rscript scripts/fit_xgb_primary_v6.R    > "$LOG/s3_v6.log"   2>&1; done_stage "3-features"
stage "4-asat-models";         Rscript scripts/fit_xgb_primary_asat.R  > "$LOG/s4_asat.log" 2>&1; done_stage "4-asat-models"
stage "4b-asat-flow-models";   Rscript scripts/fit_xgb_flows_asat.R    > "$LOG/s4b_flows.log" 2>&1; done_stage "4b-asat-flow-models"
stage "5-production-model";    Rscript scripts/fit_xgb_primary_v6_final.R > "$LOG/s5_final.log" 2>&1; done_stage "5-production-model"
stage "6-harnesses-shipped";   run6 1 s6; done_stage "6-harnesses-shipped"
stage "7-pool-and-forecasts";  Rscript scripts/pool_backtests.R        > "$LOG/s7_pool.log" 2>&1
                               Rscript scripts/build_forecasts_table.R > "$LOG/s7_forecasts.log" 2>&1; done_stage "7-pool-and-forecasts"
stage "8-ledger";              Rscript scripts/build_aef_comparison.R  > "$LOG/s8_comp.log" 2>&1   # aef-comparison-full.csv, the ledger's seat-probability input -- was missing from the first draft, so the ledger's log loss came out identical to the run before (2026-09-18)
                               Rscript scripts/build_aef7_tcp_actual.R > "$LOG/s8_tcp.log" 2>&1
                               Rscript scripts/build_aef7_ledger_data.R > "$LOG/s8_ledger.log" 2>&1; done_stage "8-ledger"

# 9. PROMOTE AND PUBLISH (AUSPOL_PUBLISH=1). The daily forecast workflow downloads
# the `shipped-models` release; on 2026-09-19 it was found eight days behind the
# code. A rebuild that ships is not shipped until the release carries it, so the
# driver does it, gated so an exploratory run cannot publish by accident.
if [ "${AUSPOL_PUBLISH:-0}" = "1" ] && [ "$AUSPOL_N_SIMS" -ge 20000 ]; then
  stage "9-promote-publish";  Rscript scripts/promote_rebuild.R > "$LOG/s9_promote.log" 2>&1 && Rscript scripts/publish_shipped_release.R > "$LOG/s9_publish.log" 2>&1; done_stage "9-promote-publish"
  grep -h "^PA5\|^PR4  uploaded\|^PR1!" "$LOG/s9_promote.log" "$LOG/s9_publish.log" || true
elif [ "${AUSPOL_PUBLISH:-0}" = "1" ]; then
  echo "!! AUSPOL_PUBLISH=1 ignored: exploratory sims (AUSPOL_N_SIMS=$AUSPOL_N_SIMS) must not ship"
fi

echo; echo "=== stage split (seconds) ==="
total=0; for k in "${!TT[@]}"; do total=$(( total + TT[$k] )); done
for k in $(printf '%s\n' "${!TT[@]}" | sort); do printf '  %-26s %6ds  %3d%%\n' "$k" "${TT[$k]}" $(( 100 * TT[$k] / total )); done
echo "  total: ${total}s"
grep -h "^XA4  pooled\|^FT1\|^AEFL5" "$LOG/s4_asat.log" "$LOG/s7_forecasts.log" "$LOG/s8_ledger.log" 2>/dev/null || true
# THE INPUTS THAT CAN SILENTLY DO NOTHING, said out loud at the end: a missing how-to-vote or
# by-election table, a fit that could not be made, a seat that did not match. Review gate 2026-09-19.
echo; echo "=== input-switch coverage (stage 6 logs) ==="
grep -h "^HTV0!\|^HTV9!\|^BF0b!\|^BF0o!\|^BF0m!\|SKIPPED" "$LOG"/s6_*.log 2>/dev/null | sort | uniq -c | sort -rn | head -20 || true
grep -h "^HTV1\|^BF0b " "$LOG"/s6_*.log 2>/dev/null | sed "s/ (.*//" | sort | uniq -c | head -30 || true
