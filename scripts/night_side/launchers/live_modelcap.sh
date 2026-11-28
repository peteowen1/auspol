#!/usr/bin/env bash
# The model's own per-booth estimates for the booth file: one extra model run on the newest fetch about every 9 minutes,
# from a COPY of the loop with a read-only capture hook. Never uploads; never writes the live night file. Skipped when
# the machine has under 1,300 MB free, so it cannot starve the live run.
exec >> /c/night28/modelcap.log 2>&1
cd /c/dev/auspol || exit 1
B=external/reference/benchmarks/vic2026-night; V=external/reference/vec/2026
export NIGHT_TCP_SEAT_TOTALS=C:/night28/tcpcheck/tcp-seat-totals.json
echo "=== model capture start $(date '+%H:%M:%S')"
while true; do
  free=$(powershell.exe -Command "[int](Get-Counter '\Memory\Available MBytes').CounterSamples.CookedValue" | tr -d '\r')
  if [ "${free:-0}" -lt 1300 ]; then echo "$(date '+%H:%M:%S') MODELCAP skipped: $free MB free"; sleep 240; continue; fi
  rm -rf /c/night28/modelcap/new; mkdir -p /c/night28/modelcap/new /c/night28/modelcap/arch; rm -f /c/night28/modelcap/night-copy.json
  export MODELCAP_DIR=C:/night28/modelcap/new
  ok=$(Rscript $B/night_loop_capture.R --every=5 --max-cycles=1 --source-type=web --source=C:/night28/web --archive=C:/night28/modelcap/arch --state=C:/night28/night-state-vic-2026.rds --ref=output/booths-vic2026-ref.csv --council-lean=output/council-fp-2022.csv --turnout=output/council-district-stats-2022.csv --enrolment=$V/enrolment/enrolment-2026.csv --places=$V/voting-locations/places-2026.csv --out=C:/night28/modelcap/night-copy.json --proj-sd=max --flow-pool=on 2>&1 | grep -E " OK |FAIL|Error" | tail -1)
  if echo "$ok" | grep -q " OK "; then
    st=$(echo "$ok" | sed -E 's/.* OK ([0-9_]+) .*/\1/'); mkdir -p /c/night28/modelcap/cur; rm -f /c/night28/modelcap/cur/*.rds
    cp /c/night28/modelcap/new/*.rds /c/night28/modelcap/cur/ 2>/dev/null; echo "$st" > /c/night28/modelcap/cur/STAMP
    echo "$(date '+%H:%M:%S') MODELCAP $st: $(ls /c/night28/modelcap/cur/*.rds 2>/dev/null | wc -l) seats with units still out"
  else echo "$(date '+%H:%M:%S') MODELCAP FAILED: $(echo "$ok" | cut -c1-160)"; fi
  sleep 420
done
