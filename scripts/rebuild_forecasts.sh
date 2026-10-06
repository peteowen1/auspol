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
#   3. build_level_pred.R -> level-pred.csv (the level_pred feature: time-forward,
#      rebuilt every run -- it was frozen at 13 Sep and missed the v51 leak fix),
#      then fit_xgb_primary_v6.R                -> xgb-primary-features-v6.csv
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
#   8. build_aef_comparison.R + build_aef7_tcp_actual.R + build_aef7_ledger_data.R + build_aef7_ledger_html.R
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
# Pairs no harness can score under the published flags: wa2021 has no fittable
# poll trend, so forecast mode (published 1 since 2026-09-19) skips it and the
# pooling stages must not fall back to a stale file. Remove it from this default
# when WA 2017-2021 polling reaches the anchor.
export AUSPOL_SKIP_PAIRS="${AUSPOL_SKIP_PAIRS:-wa2021}"
# EVERY STAGE SEES THE PUBLISHED CONFIGURATION. Unset switches take their
# scripts/published_flags.R value here, once, so the fit scripts (which read only
# the environment) cannot fall back to a code default that differs from what
# ships (v57's x_notional_adj, 2026-10-02). A switch the caller set wins.
PUBFLAGS=$(Rscript scripts/export_published_flags.R) || { echo "!! export_published_flags.R failed"; exit 1; }
eval "$PUBFLAGS"
echo "   published switches exported for unset names: $(printf '%s
' "$PUBFLAGS" | grep -c '^export')"
# AUSPOL_REBUILD_FROM=<n> resumes at stage n (1-9), e.g. after a later stage failed
# with the harness outputs already fresh on disk. Default 1 = everything.
FROM="${AUSPOL_REBUILD_FROM:-1}"
at_least() { [ "$FROM" -le "$1" ]; }
if [ "$AUSPOL_N_SIMS" -lt 20000 ]; then echo "!! AUSPOL_N_SIMS=$AUSPOL_N_SIMS: exploratory run, its models must not ship"; fi
LOG="output/rebuild-forecasts-logs"; mkdir -p "$LOG"
# AUSPOL_REBUILD_ONLY=nsw,qld,sa,vic reruns only those backtests at stage 6
# and reuses the others' results -- for an arm whose change cannot reach them
# (the departed-member arms touched nsw/qld/sa/vic and still paid ~7 minutes
# for fed and wa). Stages 1-5 change every backtest's inputs, so it is only
# allowed from stage 6; each reused result is checked in reuse_check().
if [ -n "${AUSPOL_REBUILD_ONLY:-}" ] && [ "$FROM" -lt 6 ]; then
  echo "!! AUSPOL_REBUILD_ONLY needs AUSPOL_REBUILD_FROM >= 6: stages 1-5 change every backtest"; exit 1
fi
# A typo ("nsw, qld", "vict") would otherwise quietly REUSE the harness it
# meant to run: every name must be one of the six, comma-separated, no spaces.
if [ -n "${AUSPOL_REBUILD_ONLY:-}" ]; then
  for _h in ${AUSPOL_REBUILD_ONLY//,/ }; do
    case "$_h" in fed|wa|vic|nsw|qld|sa) ;; *) echo "!! AUSPOL_REBUILD_ONLY: '$_h' is not one of fed,wa,vic,nsw,qld,sa"; exit 1 ;; esac
  done
  case "$AUSPOL_REBUILD_ONLY" in *" "*) echo "!! AUSPOL_REBUILD_ONLY: no spaces, e.g. nsw,qld"; exit 1 ;; esac
fi
# SNAPSHOT EVERYTHING THIS RUN WRITES (Pete, 2026-09-30: "shouldn't restoring be
# instant?"). A marker is touched now; at the end every file under output/ newer
# than it is copied to output/snapshots/<time>-<git>/, so switching back to an
# earlier run is scripts/restore_snapshot.sh (a copy), not a 10-minute rebuild.
SNAP_MARK="output/.rebuild-start"; touch "$SNAP_MARK"
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
  # A QUEUE, not fixed waves (Pete, 2026-09-30, "any other bottlenecks?"): the
  # fixed pairs waited for their slower half, and the federal harness (7 pairs,
  # ~4.8 min) left its partner idle -- 9.4 min of wall-clock for 13.9 min of
  # work. Now the next harness starts as soon as a slot frees, longest first.
  # Slots by free memory: 6 at >= 10GB (as before), 3 at >= 6GB (fed peaks
  # ~2.3GB, the rest less), else 2. Two copies of one harness never run at
  # once (nsw/qld/sa run twice, and they have never been run concurrently).
  local slots=2
  if [ "${fg:-0}" -ge 10 ]; then slots=6; elif [ "${fg:-0}" -ge 6 ]; then slots=3; fi
  echo "   ${fg}GB free -- ${slots} harness slots"
  local specs=(fed wa vic nsw:AUSPOL_NSW_PAIR=2023 qld:AUSPOL_QLD_PAIR=2024 sa:AUSPOL_SA_PAIR=2026
               qld:AUSPOL_QLD_PAIR=2020 nsw:AUSPOL_NSW_PAIR=2019 sa:AUSPOL_SA_PAIR=2022)
  if [ -n "${AUSPOL_REBUILD_ONLY:-}" ] && [ "$2" = "s6" ]; then
    local keep=() s
    for s in "${specs[@]}"; do
      if [[ ",${AUSPOL_REBUILD_ONLY}," == *",${s%%:*},"* ]]; then keep+=("$s"); else reuse_check "$s"; fi
    done
    specs=("${keep[@]}")
    echo "   AUSPOL_REBUILD_ONLY=${AUSPOL_REBUILD_ONLY}: running ${#specs[@]} of 9 backtest runs, reusing the rest"
  fi
  run_queue "$1" "$2" "$slots" "${specs[@]}"
}
# A SKIPPED backtest must already have a full-sims, xgb-layer result newer
# than this baseline's as-at predictions (stage 4), or stage 7 would pool a
# result from a different model with nothing to say so. Refuse instead.
reuse_check() {  # $1 = "harness[:ENV=year]"
  local h="${1%%:*}" yr="" pat f
  [[ "$1" == *=* ]] && yr="${1##*=}"
  case "$h" in nsw|qld) pat="backtest-${h}${yr}-sharedetail-" ;; *) pat="backtest-${h}-sharedetail-" ;; esac
  # SA's file names carry no election, so sa2022 and sa2026 would both match
  # the newest SA file: take the newest whose own pair column is the one wanted.
  f=""
  local c
  for c in $(ls -t output/${pat}*.csv 2>/dev/null | grep -v -- '-n[0-9]*-'); do
    if [ -z "$yr" ] || [ "$(sed -n 2p "$c" | awk -F, '{print $5}' | tr -d '"\r')" = "${h}${yr}" ]; then f="$c"; break; fi
  done
  if [ -z "$f" ] || [ ! "$f" -nt output/xgb-primary-asat-predictions.csv ] || ! sed -n 2p "$f" | grep -qE ',1\s*$'; then
    echo "!! AUSPOL_REBUILD_ONLY: cannot reuse ${1}: newest result '${f:-none}' is missing, older than this baseline's as-at predictions, or not an xgb-layer run -- run it too"
    exit 1
  fi
  echo "   reusing ${1}: $(basename "$f")"
}
run_queue() {  # $1 = XGB_PRIMARY, $2 = log tag, $3 = slots, then "harness:ENV=val" specs, longest first
  local xgb="$1" tag="$2" slots="$3"; shift 3
  local pending=("$@") fail=0
  declare -A running=()   # pid -> harness
  while [ "${#pending[@]}" -gt 0 ] || [ "${#running[@]}" -gt 0 ]; do
    # Launch what fits: a free slot and no copy of that harness already running.
    local next=() launched=0
    for spec in "${pending[@]}"; do
      local h="${spec%%:*}" busy=0
      for p in "${!running[@]}"; do [ "${running[$p]}" = "$h" ] && busy=1; done
      if [ "${#running[@]}" -lt "$slots" ] && [ "$busy" -eq 0 ]; then
        local envs="${spec#*:}"; [ "$envs" = "$spec" ] && envs=""
        local name="$h"; [ -n "$envs" ] && name="${h}_${envs##*=}"
        ( [ -n "$envs" ] && export "$envs"; AUSPOL_XGB_PRIMARY="$xgb" Rscript "scripts/backtest_candidate_${h}.R" ) \
          > "$LOG/${tag}_${name}.log" 2>&1 &
        running[$!]="$h"; launched=1
      else
        next+=("$spec")
      fi
    done
    pending=("${next[@]}")
    [ "${#running[@]}" -eq 0 ] && break
    # Wait for any one harness; -p names the job reaped, so its slot is freed
    # exactly once and its own exit status is the one checked (a second `wait`
    # on a reaped pid would report "not a child" as a failure).
    local done_pid="" st=0
    wait -n -p done_pid "${!running[@]}" || st=$?
    [ "$st" -ne 0 ] && { fail=1; echo "!! harness ${running[$done_pid]:-?} exited $st"; }
    unset "running[$done_pid]"
  done
  if [ "$fail" -ne 0 ]; then echo "!! a harness failed -- see $LOG/${tag}_*.log"; exit 1; fi
}

# STAGE 1 AT REDUCED SIMS. The sharedetail point estimate (base_pred) is
# deterministic -- seat_share_rmse(shares, fb) on the pre-simulation matrix --
# so 20,000 draws buy nothing here; the draws matter at stage 6. 2,000 keeps
# the totals/allprobs files it also writes sane and cuts stage 1 by ~80%.
# pool_sharedetail's sims floor follows it for this stage only.
# STATE NOTIONALS first (AUSPOL_STATE_NOTIONAL, v57): the harnesses read them as
# the prior on redistribution pairs and stage 3 reads them for x_notional_adj.
# Rebuilt every run from output/booths/ so they can never lag the booth data
# (an input built outside this script goes stale: level-pred.csv, 2026-09-28).
# Its own checks (class shares equal the district files; unchanged-boundary
# pairs reproduce the actual result) fail the rebuild rather than warn.
if at_least 1; then
  python scripts/build_state_notionals.py > "$LOG/s1_notionals.log" 2>&1 || { echo "!! build_state_notionals.py failed its checks -- see $LOG/s1_notionals.log"; exit 1; }
fi
# ENDORSEMENT FEATURES (AUSPOL_XGB_ENDORSE): only when the switch is on.
if at_least 3 && [ "${AUSPOL_XGB_ENDORSE:-0}" = "1" ]; then
  python scripts/build_endorsement_features.py > "$LOG/s3_endorse.log" 2>&1 || { echo "!! build_endorsement_features.py failed -- see $LOG/s3_endorse.log"; exit 1; }
fi
# BOOTH FEATURES (AUSPOL_XGB_BOOTH): read by stage 3 and the live forecast.
# Only when the switch is on: a refused feature must not be able to fail a
# production rebuild on a bad input (review, 2026-10-02).
if at_least 3 && [ "${AUSPOL_XGB_BOOTH:-0}" = "1" ]; then
  python scripts/build_booth_features.py > "$LOG/s3_booth.log" 2>&1 || { echo "!! build_booth_features.py failed -- see $LOG/s3_booth.log"; exit 1; }
fi
# COUNCIL HISTORY (AUSPOL_XGB_COUNCIL): read by stage 3 and the live forecast.
# Rebuilt whenever stage 3 runs, from the parsed council results on disk.
if at_least 3; then
  python scripts/build_council_history.py > "$LOG/s3_council.log" 2>&1 || { echo "!! build_council_history.py failed -- see $LOG/s3_council.log"; exit 1; }
fi
if at_least 1; then stage "1-harnesses-base_pred"; AUSPOL_XGB_BASE_RECORD=1 AUSPOL_N_SIMS="${AUSPOL_STAGE1_SIMS:-2000}" run6 0 s1; done_stage "1-harnesses-base_pred"; fi
if at_least 2; then stage "2-pool-sharedetail";    AUSPOL_POOL_MIN_SIMS="${AUSPOL_STAGE1_SIMS:-2000}" Rscript scripts/pool_sharedetail.R      > "$LOG/s2_pool.log" 2>&1; done_stage "2-pool-sharedetail"; fi
if at_least 3; then stage "3-features";            Rscript scripts/build_level_pred.R > "$LOG/s3_level.log" 2>&1; Rscript scripts/fit_xgb_primary_v6.R    > "$LOG/s3_v6.log"   2>&1; done_stage "3-features"; fi
if at_least 4; then stage "4-asat-models";         Rscript scripts/fit_xgb_primary_asat.R  > "$LOG/s4_asat.log" 2>&1; done_stage "4-asat-models"; fi
if at_least 4; then stage "4b-asat-flow-models";   Rscript scripts/fit_xgb_flows_asat.R    > "$LOG/s4b_flows.log" 2>&1; done_stage "4b-asat-flow-models"; fi
if at_least 5; then stage "5-production-model";    Rscript scripts/fit_xgb_primary_v6_final.R > "$LOG/s5_final.log" 2>&1; done_stage "5-production-model"; fi
if at_least 6; then export AUSPOL_STAGE6_START=$(date +%s); rm -rf output/upset-floor-raw; stage "6-harnesses-shipped";   run6 1 s6; done_stage "6-harnesses-shipped"; fi
# 6b UPSET INSURANCE (AUSPOL_UPSET_FLOOR=1, R/upset_floor.R): mixes THIS run's
# stage-6 win probabilities with a time-forward-fitted floor for minor
# contenders, in place (raw copies kept), before anything scores them.
if at_least 6 && [ "${AUSPOL_UPSET_FLOOR:-0}" = "1" ]; then
  Rscript scripts/apply_upset_floor.R > "$LOG/s6b_upset.log" 2>&1 || { echo "!! apply_upset_floor.R failed -- see $LOG/s6b_upset.log"; exit 1; }
  grep -E "^UF9" "$LOG/s6b_upset.log"
fi
if at_least 7; then stage "7-pool-and-forecasts";  Rscript scripts/pool_backtests.R        > "$LOG/s7_pool.log" 2>&1
                               Rscript scripts/build_forecasts_table.R > "$LOG/s7_forecasts.log" 2>&1; done_stage "7-pool-and-forecasts"; fi
if at_least 8; then stage "8-ledger";              Rscript scripts/build_aef_comparison.R  > "$LOG/s8_comp.log" 2>&1   # aef-comparison-full.csv, the ledger's seat-probability input -- was missing from the first draft, so the ledger's log loss came out identical to the run before (2026-09-18)
                               Rscript scripts/build_aef7_tcp_actual.R > "$LOG/s8_tcp.log" 2>&1
                               Rscript scripts/build_aef7_ledger_data.R > "$LOG/s8_ledger.log" 2>&1; Rscript scripts/build_aef7_ledger_html.R > "$LOG/s8_ledger_html.log" 2>&1; done_stage "8-ledger"; fi

# 9. PROMOTE AND PUBLISH (AUSPOL_PUBLISH=1). The daily forecast workflow downloads
# the `shipped-models` release; on 2026-09-19 it was found eight days behind the
# code. A rebuild that ships is not shipped until the release carries it, so the
# driver does it, gated so an exploratory run cannot publish by accident.
if [ "${AUSPOL_PUBLISH:-0}" = "1" ] && [ "$AUSPOL_N_SIMS" -ge 20000 ]; then
  # Old logs removed first: on 2026-09-28 a refused promote left the 20 Sep
  # publish log in place and the grep below printed its "uploaded" line.
  stage "9-promote-publish";  rm -f "$LOG/s9_promote.log" "$LOG/s9_publish.log"
  if Rscript scripts/promote_rebuild.R > "$LOG/s9_promote.log" 2>&1 && Rscript scripts/publish_shipped_release.R > "$LOG/s9_publish.log" 2>&1; then
    grep -h "^PA0\|^PA5\|^PR4  uploaded\|^PR1!" "$LOG/s9_promote.log" "$LOG/s9_publish.log" || true
  else
    echo "!! stage 9 FAILED -- nothing published; see $LOG/s9_promote.log / s9_publish.log"; tail -3 "$LOG/s9_promote.log" "$LOG/s9_publish.log" 2>/dev/null
  fi
  done_stage "9-promote-publish"
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

# Snapshot: every file this run wrote (see SNAP_MARK above), logs included.
SNAP="output/snapshots/$(date +%Y%m%d-%H%M)-$(git rev-parse --short HEAD)-from${FROM}"
mkdir -p "$SNAP"
find output -type f -newer "$SNAP_MARK" -not -path "output/snapshots/*" -print0 |
  while IFS= read -r -d '' f; do mkdir -p "$SNAP/$(dirname "${f#output/}")"; cp -p "$f" "$SNAP/${f#output/}"; done
echo "SNAP1 wrote $(find "$SNAP" -type f | wc -l) files ($(du -sh "$SNAP" | cut -f1)) to $SNAP -- restore with: bash scripts/restore_snapshot.sh $SNAP"
