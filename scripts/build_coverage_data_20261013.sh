#!/usr/bin/env bash
# One-off (2026-10-13 coverage program): rebuild the gitignored data the merged NSW/Qld/SA/NT/Hare-Clark branches
# need, in the order their agents gave. Each step logs to deciding-runs/coverage-data/<n>-<name>.log; the script stops
# at the first failure and says which step. Rerunnable: every step overwrites only its own derived outputs.
set -u
cd "$(dirname "$0")/.."
L=deciding-runs/coverage-data; mkdir -p "$L"
run() { local n=$1; shift; echo "=== $n: $* ($(date +%H:%M:%S))"; "$@" > "$L/$n.log" 2>&1 || { echo "!! step $n FAILED (exit $?): see $L/$n.log"; tail -5 "$L/$n.log"; exit 1; }; tail -2 "$L/$n.log"; }
R() { powershell.exe -NoProfile -Command "Rscript '$1'"; }
# 01, 02 done 21:54 (rerunnable)
#run 01-nsw2011-booths python scripts/parse_booths_nsw2011.py
#run 02-nsw2007 python scripts/parse_nsw2007.py
# 03-qld-inputs: its outputs (ecq-2012-qld-firstprefs-kapfix.csv, ecq-qld-winners-2012-2015.csv) were written into external/reference/ecq/ by the Qld agent and the script refuses to overwrite them
run 04-qld2015-booths python scripts/parse_booths_qld2015.py
run 05-sa-results R scripts/build_sa_2010_2014_results.R
run 06-nt-results R scripts/fetch_results_nt.R
run 07-nt-polls R scripts/build_nt_polls.R
run 08-candidacies env AUSPOL_CAND_ALLOW_OTHER_CHANGE=1 powershell.exe -NoProfile -Command "\$env:AUSPOL_CAND_ALLOW_OTHER_CHANGE='1'; Rscript 'scripts/build_candidacies.R'"
run 09-notionals python scripts/build_state_notionals.py
run 10-retirement-derived python scripts/build_retirement_derived.py
run 11-mp-slope R scripts/fit_mp_slope.R
run 12-departed-successor R scripts/fit_departed_successor_rates.R
run 13-hc-data R scripts/build_hare_clark_data.R
run 14-hc-ballots R scripts/build_hare_clark_ballots.R
run 15-hc-tas-flows R scripts/build_hare_clark_tas_flows.R
echo "=== all steps done $(date +%H:%M:%S)"
