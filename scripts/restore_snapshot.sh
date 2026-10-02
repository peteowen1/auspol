#!/usr/bin/env bash
# Put a rebuild snapshot back into output/ (a copy; seconds, not a rebuild).
# Usage: bash scripts/restore_snapshot.sh output/snapshots/<name> [--strict]
# A snapshot holds only what its run wrote, so a stage-6 run's snapshot
# restores stages 6-8 on top of the stage 1-5 files already in output/.
#
# Files a LATER run wrote that the snapshot does not hold are newer than
# everything restored, and "newest file" pickers (the ledger) take them: 114
# such files survived a restore on 2026-09-30. They are moved aside (never
# deleted) to output/.unrestored/ when the snapshot is a full rebuild
# (-from1, so it holds every stage) or --strict is given. For a partial
# snapshot they are only listed: they may be the stage 1-5 files it needs.
set -euo pipefail
SNAP="${1:?usage: restore_snapshot.sh output/snapshots/<name> [--strict]}"
STRICT="${2:-}"
# A trailing slash (tab completion adds one) left the prefix unstripped and
# restored into output/output/snapshots/... while reporting success.
SNAP="${SNAP%/}"
[ -d "$SNAP" ] || { echo "!! no snapshot at $SNAP"; exit 1; }
n=0
while IFS= read -r -d '' f; do rel="${f#$SNAP/}"; case "$rel" in /*|output/*) echo "!! refusing to restore $f to output/$rel"; exit 1;; esac; mkdir -p "output/$(dirname "$rel")"; cp -p "$f" "output/$rel"; n=$((n+1)); done < <(find "$SNAP" -type f -print0)
echo "RS1 restored $n files from $SNAP into output/"

move=0; case "$SNAP" in *-from1) move=1;; esac; [ "$STRICT" = "--strict" ] && move=1
# output/booths/ and the council, LGA-overlap and Senate tables are skipped: they are INPUTS
# (parsed from raw pages by scripts/parse_*.py / build_*), not rebuild outputs; a restore
# on 2026-10-02 moved the council tables aside too.
# output/booths/ was the first: (parsed from raw commission pages by
# scripts/parse_booths_*.py), not a rebuild output. A restore on 2026-10-01 moved
# it aside and the notional builder then skipped every pair and still exited 0.
ASIDE="output/.unrestored/$(date +%Y%m%d-%H%M%S)-$$"
m=0; k=0; failed=0
while IFS= read -r -d '' f; do rel="${f#output/}"; [ -e "$SNAP/$rel" ] && continue
  k=$((k+1))
  if [ "$move" = 1 ]; then
    mkdir -p "$ASIDE/$(dirname "$rel")"
    if mv "$f" "$ASIDE/$rel"; then m=$((m+1)); else failed=$((failed+1)); fi
  fi
done < <(find output -type f -newer "$SNAP" -not -path "output/snapshots/*" -not -path "output/.unrestored/*" -not -path "output/booths/*" -not -path "output/cache/*" -not -name "council-results-*.csv" -not -name "council-history*.csv" -not -name "lga-district-overlap*.csv" -not -name "senate-*.csv" -not -name "onp-senate-*.csv" -print0)
if [ "$move" = 1 ]; then
  [ "$m" -gt 0 ] && echo "RS2 moved $m file(s) written after the snapshot, and not in it, to $ASIDE"
  [ "$failed" -gt 0 ] && echo "RS2! $failed file(s) could NOT be moved (held open?) -- they will beat the restored files in newest-file pickers"
elif [ "$k" -gt 0 ]; then
  echo "RS2! $k file(s) in output/ are newer than this partial snapshot and not in it; left in place (pass --strict to move them aside):"
  find output -type f -newer "$SNAP" -not -path "output/snapshots/*" -not -path "output/.unrestored/*" -not -path "output/booths/*" -not -path "output/cache/*" -not -name "council-results-*.csv" -not -name "council-history*.csv" -not -name "lga-district-overlap*.csv" -not -name "senate-*.csv" -not -name "onp-senate-*.csv" | while IFS= read -r f; do [ -e "$SNAP/${f#output/}" ] || echo "   $f"; done | head -20
fi
exit 0
