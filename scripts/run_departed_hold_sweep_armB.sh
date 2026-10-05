#!/bin/bash
# Prereg docs/plans/prereg-departed-hold-fixed-2026-10-04.md, exploratory sweep: base (HEAD script), off, on.
cd /c/dev/auspol
S="C:/Users/peteo/AppData/Local/Temp/claude/C--dev-auspol/bfbfaf62-5b8a-4aec-b519-082e07efaa33/scratchpad"
run1() { # harness pairvar pairval arm
  h=$1; pv=$2; pl=$3; arm=$4; d="$S/sweep/${h}_${pl}_${arm}"; mkdir -p "$d"
  ls output > "$d/before.txt"
  if [ "$arm" = base ]; then script="$S/sweep/base_$h.R"; hv=""; else script="scripts/backtest_candidate_$h.R"; fi
  case $arm in onB) hv="AUSPOL_DEPARTED_HOLD=1 AUSPOL_DEPARTED_HOLD_MIN_PRIOR=15 AUSPOL_DEPARTED_HOLD_DUMP=$d/held.csv";; base) hv="";; off) hv="AUSPOL_DEPARTED_HOLD=0";; on) hv="AUSPOL_DEPARTED_HOLD=1 AUSPOL_DEPARTED_HOLD_DUMP=$d/held.csv";; esac
  t0=$(date +%s)
  env $pv=$pl AUSPOL_XGB_PRIMARY=0 AUSPOL_N_SIMS=500 $hv timeout 900 powershell.exe -Command "Rscript '$script'" > "$d/run.log" 2>&1
  echo "$h $pl $arm exit=$? $(( $(date +%s) - t0 ))s" >> $S/sweep/progressB.txt
  ls output > "$d/after.txt"; comm -13 <(sort "$d/before.txt") <(sort "$d/after.txt") > "$d/new.txt"
  while read f; do mv "output/$f" "$d/"; done < "$d/new.txt"
}
: > $S/sweep/progressB.txt
for p in 2007 2010 2013 2016 2019 2022 2025; do run1 fed AUSPOL_FED_PAIRS $p onB; done
for p in 2019 2023; do run1 nsw AUSPOL_NSW_PAIR $p onB; done
for p in 2020 2024; do run1 qld AUSPOL_QLD_PAIR $p onB; done
for p in 2022 2026; do run1 sa AUSPOL_SA_PAIR $p onB; done
for p in 2014 2018 2022; do run1 vic AUSPOL_VIC_PAIR $p onB; done
echo DONE >> $S/sweep/progressB.txt
