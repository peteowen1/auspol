#!/usr/bin/env bash
# Nomination day in one command (docs/PIPELINE.md section E, steps 1 and 4). Built 8 Nov 2026.
#
#   bash scripts/nomination_day.sh <path to State2026MediaFileCandidatesV2.xml>            the real run
#   bash scripts/nomination_day.sh --dry-run <any VEC Candidates xml, e.g. the 2022 one>   scratch only
#   bash scripts/nomination_day.sh [--dry-run] --web[=<saved pages folder>]               the VEC website's district
#     pages instead of the media-feed XML (9 Nov 2026: list published, feed access not granted); fetch_vec_candidates_web.R
#
# 1. fetch_vec_candidates.R: keeps the XML as received, writes vec-candidates-2026.csv (VC1!-VC9 refuse bad files)
# 2. build_candidacies.R: vic2026 rows from the VEC list (BC10v names/class changes, BC11 guards other years)
# 3. refresh_local_poll_inputs.sh, then a TRIAL forecast with zeroing ON (AUSPOL_NOM_LIVE=1, AUSPOL_OUT_SUFFIX=-nomtrial,
#    so nothing published is overwritten), printing every NZL line.
# It STOPS there. Steps 2-3 of section E -- upload candidacies.csv to the shipped-models release and set
# AUSPOL_NOM_LIVE="1" in published_flags.R -- happen only after the NZL lines are read (the gate is manual by
# Pete's choice and never opens on date alone).
#
# --dry-run writes to a scratch folder and points every reader there (AUSPOL_VEC_CANDIDATES, AUSPOL_CAND_OUT,
# AUSPOL_NOM_LIVE_FILE); output/candidacies.csv and external/reference/vec/2026 are not touched.
set -euo pipefail
DRY=0
if [ "${1:-}" = "--dry-run" ]; then DRY=1; shift; fi
XML="${1:-}"
WEB=0; WEB_FROM=""
case "$XML" in --web) WEB=1 ;; --web=*) WEB=1; WEB_FROM="${XML#--web=}" ;; esac
[ "$WEB" = 1 ] || { [ -n "$XML" ] && [ -f "$XML" ]; } || { echo "usage: bash scripts/nomination_day.sh [--dry-run] <Candidates xml> | --web[=<saved folder>]"; exit 1; }
LOG=output/nomination-day-logs; mkdir -p "$LOG"
R() { powershell.exe -Command "Rscript $*"; }   # arrow segfaults under Git Bash R

if [ "$DRY" = 1 ]; then
  # relative and inside the gitignored log folder: Git Bash and Windows R must resolve it the same way
  # (a detached launch has no TEMP, and "/tmp" means different folders to the two; 8 Nov dry run)
  S="$LOG/dry"; rm -rf "$S"; mkdir -p "$S"
  cp output/candidacies.csv "$S/candidacies.csv"
  export AUSPOL_VEC_CANDIDATES="$S/vec-candidates-2026.csv" AUSPOL_CAND_OUT="$S/candidacies.csv" AUSPOL_NOM_LIVE_FILE="$S/candidacies.csv"
  OUTDIR="$S"; echo "NOM0 DRY RUN: scratch $S (output/candidacies.csv untouched)"
else
  OUTDIR="external/reference/vec/2026"; echo "NOM0 REAL RUN on ${XML}"
fi

echo "== 1. VEC candidates"
if [ "$WEB" = 1 ]; then
  R "scripts/fetch_vec_candidates_web.R --year=2026 '--out=$OUTDIR'${WEB_FROM:+ '--from=$WEB_FROM'}" 2>&1 | tee "$LOG/1-fetch.log" | grep -E "^VW" || true
else
  R "scripts/fetch_vec_candidates.R '--file=$XML' --year=2026 '--out=$OUTDIR'" 2>&1 | tee "$LOG/1-fetch.log" | grep -E "^VC" || true
fi
grep -qE "^V[CW][0-9]*!|^Error" "$LOG/1-fetch.log" && { echo "NOM1!! the fetcher refused or warned -- see $LOG/1-fetch.log"; exit 1; }
[ -f "$OUTDIR/vec-candidates-2026.csv" ] || { echo "NOM1!! no vec-candidates-2026.csv written"; exit 1; }

echo "== 2. build candidacies"
# The queued vic2006 winners fix (and what follows from it: vic2010 historic_elected, sa2026's 8 Cheltenham absent-vote
# rows) lands with this build, so BC11's "other elections changed" guard is opened -- and replaced by a check that
# NOTHING outside that list moved (found by the 8 Nov dry run).
CAND="${AUSPOL_CAND_OUT:-output/candidacies.csv}"; cp "$CAND" "$LOG/candidacies-before.csv"
AUSPOL_CAND_ALLOW_OTHER_CHANGE=1 R "scripts/build_candidacies.R" > "$LOG/2-build.log" 2>&1 || { echo "NOM2!! build_candidacies.R failed -- see $LOG/2-build.log"; exit 1; }
python -I - "$LOG/candidacies-before.csv" "$CAND" <<'PY' || { echo "NOM2!! an election outside the expected list changed -- see above; old file at $LOG/candidacies-before.csv"; cp "$LOG/candidacies-before.csv" "$CAND"; exit 1; }
import csv, sys, collections
def load(p):
    d = collections.defaultdict(set)
    with open(p, encoding="utf-8") as f:
        for r in csv.reader(f):
            if r and r[0] not in ("election", "vic2026", "nsw2027"): d[r[0]].add(tuple(r))
    return d
a, b = load(sys.argv[1]), load(sys.argv[2])
changed = {e: (len(a[e] - b[e]), len(b[e] - a[e])) for e in set(a) | set(b) if a[e] != b[e]}
ok = {"vic2006", "vic2010", "sa2026"}
for e, (o, n) in sorted(changed.items()): print(f"NOM2  {e}: {o} rows replaced by {n}" + ("" if e in ok else "   <-- NOT EXPECTED"))
sys.exit(0 if set(changed) <= ok else 1)
PY
grep -E "^BC10v|^BC11|^NZL|candidacies per class" "$LOG/2-build.log" || true

echo "== 3. trial forecast, zeroing ON (suffix -nomtrial)"
bash scripts/refresh_local_poll_inputs.sh > "$LOG/3a-polls.log" 2>&1 || { echo "NOM3!! poll refresh failed -- see $LOG/3a-polls.log"; exit 1; }
export AUSPOL_NOM_LIVE=1 AUSPOL_OUT_SUFFIX=-nomtrial
R "scripts/fit_seats_full.R" > "$LOG/3-forecast.log" 2>&1 || { echo "NOM3!! trial forecast failed -- see $LOG/3-forecast.log"; grep -E "NZL!!" "$LOG/3-forecast.log" || true; exit 1; }
grep -E "^NZL" "$LOG/3-forecast.log" || echo "NOM3! no NZL lines in the trial forecast log -- zeroing may not have run"
echo
echo "NOM9 done. Read the NZL lines above (majors with no candidate, classes under 80% of vic2022's seats)."
[ "$DRY" = 1 ] && echo "NOM9 dry run: nothing to upload." || echo "NOM9 next (manual): upload output/candidacies.csv to shipped-models, set AUSPOL_NOM_LIVE=\"1\" in published_flags.R, commit, rebuild/publish."
