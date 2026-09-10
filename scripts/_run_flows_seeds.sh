#!/usr/bin/env bash
# Runs ONE arm across several seeds, sequentially. Launch two of these (one per
# arm) to get both arms measured at the SAME sim count and the SAME seeds.
#
# Matched sim counts are not a nicety. Pooled seat log loss here is set as much
# by how many seats sit at the eps = 1e-6 floor as by anything else
# (CLAUDE.md), and fewer sims put MORE seats at exactly zero -- so an arm run
# at 5,000 against a baseline run at 20,000 carries a systematic penalty that
# has nothing to do with the model being tested.
#   ARM=ship|xgb  SEEDS="1 2 3"  NSIMS=<n>  ENGINE=cpp|r
set -u
ARM="${ARM:?}"; SEEDS="${SEEDS:?}"; NSIMS="${NSIMS:?}"; ENGINE="${ENGINE:?}"
for s in $SEEDS; do
  echo "=== ARM=$ARM SEED=$s NSIMS=$NSIMS ENGINE=$ENGINE ==="
  ARM="$ARM" SEED="$s" NSIMS="$NSIMS" ENGINE="$ENGINE" \
    bash "C:/dev/auspol/scripts/_run_flows_arm.sh"
done
echo "ARM $ARM ALL SEEDS COMPLETE"
