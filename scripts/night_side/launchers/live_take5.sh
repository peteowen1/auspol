#!/usr/bin/env bash
# LIVE election night, take 5 (11:05pm): also --flow-pool=on (the preference flow counted tonight in seats with the same final pair is applied to seats with no count for theirs; Pete: urgent, Ripon); take 4 (10:35pm): also NIGHT_TCP_SEAT_TOTALS (the model reads the VEC seat-level two-candidate totals); take 3 (6:31pm): as take 2, plus --proj-sd=max (Pete, AskUserQuestion 6:30pm): the projection
# error is widened in the first few percent counted, after Gippsland East went to 99% One Nation on one 36-vote booth.
exec >> /c/night28/run.log 2>&1
cd /c/dev/auspol || exit 1
export NIGHT_TCP_SEAT_TOTALS=C:/night28/tcpcheck/tcp-seat-totals.json
IDX=https://www.vec.vic.gov.au/results/2026-results/district-election-page
echo "=== take5 start $(date '+%Y-%m-%d %H:%M:%S'): --proj-sd=max --flow-pool=on"
until bash scripts/night_vic2026.sh "$IDX" C:/night28 --upload --parallel=2 --every=120 --loop=--proj-sd=max --loop=--flow-pool=on; do echo "=== stopped with an error at $(date '+%H:%M:%S'); retrying in 60 s"; sleep 60; done
echo "=== live end $(date '+%Y-%m-%d %H:%M:%S')"
