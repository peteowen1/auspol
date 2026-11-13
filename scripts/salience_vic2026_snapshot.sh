#!/usr/bin/env bash
# One vic2026 salience snapshot, all four steps on ONE window end (the steps must share AUSPOL_SALIENCE_TO; without
# it the builder falls back to 6 Oct and finds 0 batches). Written 13 Nov 2026 for the 25-27 Nov final snapshot.
#   bash scripts/salience_vic2026_snapshot.sh 2026-11-26
# Steps: main fetcher (~100 Google requests) -> ladder (~100, 2 passes, ~12 min) -> builder -> link into
# output/salience-v6.csv. Resumable: cached queries are kept, so rerun after a throttle stop (fetcher exit 3).
# Ships nothing: stage 9 (AUSPOL_REBUILD_FROM=9 AUSPOL_PUBLISH=1 bash scripts/rebuild_forecasts.sh) publishes it.
# Codes SVS0-SVS5.
set -euo pipefail
TO="${1:?usage: salience_vic2026_snapshot.sh YYYY-MM-DD (the window end, usually yesterday)}"
[[ "$TO" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || { echo "SVS0! window end must be YYYY-MM-DD, got '$TO'"; exit 2; }
cd "$(dirname "$0")/.."
export AUSPOL_SALIENCE_TO="$TO"
ANCHOR="${AUSPOL_SALIENCE_ANCHOR:-Ben Carroll}"
# the anchor must be the current Premier: Allan's series linked 0 of 101 batches after she was replaced (4 Nov)
HG=$(python -c 'import csv; print("|".join(sorted({r["head_of_govt"] for r in csv.DictReader(open("external/reference/leaders/leaders.csv", encoding="utf-8")) if r["election"] == "vic2026"})))')
[[ "$HG" == "$ANCHOR" ]] || { echo "SVS0! anchor '$ANCHOR' is not leaders.csv's vic2026 head of government '$HG'"; exit 2; }
LOG=output/salience-snapshot-logs; mkdir -p "$LOG"
echo "SVS0  window end $TO, anchor $ANCHOR, logs in $LOG/"
run() {  # step name, script
  echo "SVS$1  $(date +%H:%M:%S) $2"
  local rc=0; Rscript "scripts/$2" > "$LOG/$TO-$2.log" 2>&1 || rc=$?
  if [[ $rc -eq 3 ]]; then echo "SVS$1! $2 THROTTLED by Google: cached queries are kept, rerun this command later"; exit 3; fi
  if [[ $rc -ne 0 ]]; then echo "SVS$1! $2 failed (exit $rc); tail of its log:"; tail -15 "$LOG/$TO-$2.log"; exit 1; fi
}
run 1 fetch_salience_vic2026_full.R
grep -E "^(F|S)[A-Z]*[0-9]" "$LOG/$TO-fetch_salience_vic2026_full.R.log" | tail -3 || true
run 2 fetch_salience_vic2026_ladder.R
grep -E "^LF(2|9)" "$LOG/$TO-fetch_salience_vic2026_ladder.R.log" || true
run 3 build_vic2026_salience_jump.R
grep -E "^VJ(3|6|7)" "$LOG/$TO-build_vic2026_salience_jump.R.log" || true
sed -n '/^VJ8/,/^VJ3/p' "$LOG/$TO-build_vic2026_salience_jump.R.log" | grep -v '^VJ3' || true   # the namesake list
run 4 link_vic2026_salience.R
tail -3 "$LOG/$TO-link_vic2026_salience.R.log"
echo "SVS5  $(date +%H:%M:%S) done. Read VJ6 link quality above (11 Nov: shared peak median 56, 0 steps over 1.5x), then publish with stage 9."
