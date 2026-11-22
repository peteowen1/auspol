#!/usr/bin/env bash
# Bundle the machine-local files the WEBSITE election night needs and put the bundle on the night-inputs release, so
# the Actions backup (.github/workflows/night-backup.yaml, source web) runs the same night as the laptop. None of
# them is in git (external/ and output/ are ignored).
#
#   bash scripts/publish_night_inputs.sh            # build the bundle, print its contents, upload nothing
#   bash scripts/publish_night_inputs.sh --upload   # also upload it (replaces the bundle already on the release)
#
# RERUN WITH --upload AFTER ANY OF THESE CHANGES, or the backup runs on the old copy: the VEC venues list
# (places-2026.csv, scripts/build_vec_places_2026.R), the candidate list, the enrolment file, or a rebuild that
# rewrites minor-candidate-oof-resid-v2.csv. The workflow prints each file's sha1 (NBI2) to compare with NBI1 here.
#
# Paths inside the bundle are relative to the repo root; the workflow unpacks it there.
# Check codes: NBI0! (missing input), NBI1 (file list with sha1), NBI3 (uploaded).
set -euo pipefail
[ -f scripts/night_loop.R ] || { echo "NBI0! run from the repo root"; exit 2; }
UPLOAD=0; [ "${1:-}" = "--upload" ] && UPLOAD=1
V=external/reference/vec/2026
FILES=("$V/enrolment/enrolment-2026.csv" "$V/voting-locations/places-2026.csv" "$V/vec-candidates-2026.csv"
       output/council-fp-2022.csv output/minor-candidate-oof-resid-v2.csv)
# the night class split's transfer share is fitted from every transfers file (class_split_transfers())
while IFS= read -r f; do FILES+=("$f"); done < <(ls external/elections/*transfers.csv)
for f in "${FILES[@]}"; do [ -s "$f" ] || { echo "NBI0! missing or empty: $f"; exit 1; }; done
[ "${#FILES[@]}" -ge 6 ] || { echo "NBI0! no transfers files found in external/elections"; exit 1; }
OUT="${TMPDIR:-${TEMP:-/tmp}}/night-web-inputs.tar.gz"
tar --force-local -czf "$OUT" "${FILES[@]}"   # --force-local: a Windows temp path has a colon, which tar reads as a host
echo "NBI1  ${#FILES[@]} files, bundle $(wc -c < "$OUT") bytes: $OUT"
sha1sum "${FILES[@]}" | sed 's/^/NBI1  /'
if [ "$UPLOAD" = 1 ]; then
  gh release upload night-inputs "$OUT" --clobber
  echo "NBI3  uploaded; release asset updated $(gh release view night-inputs --json assets -q '.assets[] | select(.name=="night-web-inputs.tar.gz") | .updatedAt')"
else
  echo "NBI1  not uploaded (pass --upload)"
fi
