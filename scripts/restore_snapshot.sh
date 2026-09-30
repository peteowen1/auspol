#!/usr/bin/env bash
# Put a rebuild snapshot back into output/ (a copy; seconds, not a rebuild).
# Usage: bash scripts/restore_snapshot.sh output/snapshots/<name>
# A snapshot holds only what its run wrote, so a stage-6 run's snapshot
# restores stages 6-8 on top of the stage 1-5 files already in output/.
set -euo pipefail
SNAP="${1:?usage: restore_snapshot.sh output/snapshots/<name>}"
# A trailing slash (tab completion adds one) left the prefix unstripped and
# restored into output/output/snapshots/... while reporting success.
SNAP="${SNAP%/}"
[ -d "$SNAP" ] || { echo "!! no snapshot at $SNAP"; exit 1; }
n=0
while IFS= read -r -d '' f; do rel="${f#$SNAP/}"; case "$rel" in /*|output/*) echo "!! refusing to restore $f to output/$rel"; exit 1;; esac; mkdir -p "output/$(dirname "$rel")"; cp -p "$f" "output/$rel"; n=$((n+1)); done < <(find "$SNAP" -type f -print0)
echo "RS1 restored $n files from $SNAP into output/"
# Files a LATER run wrote that the snapshot does not hold stay behind, newer
# than everything restored, and "newest file" pickers (the ledger) take them:
# 114 such files survived a restore on 2026-09-30. Move them aside, not delete.
ASIDE="output/.unrestored/$(date +%Y%m%d-%H%M%S)"
m=0
while IFS= read -r -d '' f; do rel="${f#output/}"; [ -e "$SNAP/$rel" ] && continue
  mkdir -p "$ASIDE/$(dirname "$rel")"; mv "$f" "$ASIDE/$rel"; m=$((m+1))
done < <(find output -type f -newer "$SNAP" -not -path "output/snapshots/*" -not -path "output/.unrestored/*" -print0)
[ "$m" -gt 0 ] && echo "RS2 moved $m file(s) written after the snapshot, and not in it, to $ASIDE"
exit 0
