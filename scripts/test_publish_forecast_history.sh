#!/usr/bin/env bash
# Tests for scripts/publish_forecast_history.sh against a local store
# (HISTORY_LOCAL_DIR), plus one HTTP case against a throwaway local server.
# Every guard is shown failing on the input it exists to catch.
#   bash scripts/test_publish_forecast_history.sh
set -uo pipefail
S="${HISTORY_SCRIPT:-$(cd "$(dirname "$0")" && pwd)/publish_forecast_history.sh}"   # override only to test the tests
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
L=$T/r2; H=auspol/history
fail=0
check() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }
run() { HISTORY_LOCAL_DIR=$L FORECAST=$1 PAGEDATA=$2 bash "$S" >"$T/log" 2>&1; }

# Minimal fixtures with the fields the script reads.
echo '{"built_at":"2026-10-06T23:45:58+0000","git_sha":"aaa","n_sims":20000,"seats":[{"seat":"A"},{"seat":"B"}]}' > $T/f1.json
echo '{"built_at":"2026-10-08T00:01:00+0000","git_sha":"bbb","n_sims":20000,"seats":[{"seat":"A"},{"seat":"B"}]}' > $T/f2.json
jq '.n_sims = 99' $T/f2.json > $T/f2b.json
echo '{"meta":{"as_of":"2026-10-06"}}' > $T/p1.json
echo '{"meta":{"as_of":"2026-10-08"}}' > $T/p2.json
echo '{"meta":{}}' > $T/pbad.json

run $T/f1.json $T/p1.json; check "first run starts an index" '[ $? -eq 0 ] && [ "$(jq ".forecast|length" $L/$H/index-vic2026.json)" = 1 ]'
check "backup index written" '[ -f $L/$H/index-vic2026.backup.json ]'
run $T/f2.json $T/p2.json; check "next day appends" '[ "$(jq -c "[.forecast[].as_at]" $L/$H/index-vic2026.json)" = "[\"2026-10-06\",\"2026-10-08\"]" ]'
check "index key is the full R2 key" '[ "$(jq -r ".forecast[0].key" $L/$H/index-vic2026.json)" = "auspol/history/forecast-vic2026-2026-10-06.json" ]'
run $T/f2b.json $T/p2.json; check "same-day rerun replaces, does not duplicate" '[ "$(jq ".forecast|length" $L/$H/index-vic2026.json)" = 2 ] && [ "$(jq .n_sims $L/$H/forecast-vic2026-2026-10-08.json)" = 99 ]'
run $T/f2.json $T/pbad.json; check "missing as_of still records forecast, warns" '[ $? -eq 0 ] && grep -q "::warning::" $T/log'
cp $L/$H/index-vic2026.json $T/good.json
echo '{"forecast":"oops"}' > $L/$H/index-vic2026.json
run $T/f2.json $T/p2.json; rc=$?; check "corrupt index aborts" '[ $rc -ne 0 ] && grep -q "not a valid index" $T/log'
rm $L/$H/index-vic2026.json
run $T/f2.json $T/p2.json; rc=$?; check "lost index with a backup refuses to restart" '[ $rc -ne 0 ] && grep -q "backup exists" $T/log'
cp $T/good.json $L/$H/index-vic2026.json
jq '.forecast += [.forecast[0]]' $T/good.json > $L/$H/index-vic2026.json
run $T/f2.json $T/p2.json; check "duplicate date in old index does not jam the guard" '[ $? -eq 0 ]'

# Non-404 HTTP status must abort, not reset (R2 mode against a local 500 server).
PORT=$(( 20000 + RANDOM % 20000 ))
python -c "
import http.server
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(s): s.send_response(500); s.end_headers(); s.wfile.write(b'boom')
    def log_message(s,*a): pass
http.server.HTTPServer(('127.0.0.1',$PORT),H).serve_forever()" &
SRV=$!; sleep 2
HISTORY_PUBLIC_BASE=http://127.0.0.1:$PORT FORECAST=$T/f1.json PAGEDATA=$T/p1.json bash "$S" >"$T/log" 2>&1; rc=$?
kill $SRV 2>/dev/null
check "HTTP 500 read aborts" '[ $rc -ne 0 ] && grep -q "not a 404" $T/log'

[ $fail -eq 0 ] && echo "ALL PASS" || { echo "SOME FAILED"; exit 1; }
