#!/usr/bin/env sh
# Prove scripts/failure_signature.sh BOTH stays quiet on a known failure and
# fires on a new one. A baseline that only ever says "nothing new" is a mute
# button, and this repo's rule is to prove a check fails on a deliberately
# broken input before trusting it to pass.
#
# Run:  sh scripts/test_failure_signature.sh

set -eu
cd "$(dirname "$0")/.."
SIG=scripts/failure_signature.sh
T="${TMPDIR:-/tmp}/fstest.$$"
mkdir -p "$T"
trap 'rm -rf "$T"' EXIT
FAILED=0

check() {  # check <label> <expected exit> <actual exit>
  if [ "$2" = "$3" ]; then
    printf '%-58s exit=%s (want %s)  PASS\n' "$1" "$3" "$2"
  else
    printf '%-58s exit=%s (want %s)  **FAIL**\n' "$1" "$3" "$2"
    FAILED=1
  fi
}

cat > "$T/baseline" <<'EOF'
# a comment, and a blank line, both of which must be ignored

stage:NSW cycles
stage:fit_nsw.R:CHECK:NL3 breached on 1 NSW cycle(s)
breach:NL3:2027:ONP
EOF

# 1. The real shape of a current run: only the known NSW failure.
cat > "$T/known_only.log" <<'EOF'
--- NSW cycles (scripts/fit_nsw.R) ---
!! VALIDATION STAGE FAILED: NSW cycles
   CHECK FAILED: scripts/fit_nsw.R (exit 1) after 20 s -- Error: NL3 breached on 1 NSW cycle(s)
=== NL3 BREACH ON AN NSW CYCLE (not the published forecast) ===
    2027 ONP fitted 21.29 against 24.67 from 3 polls (bound 2.5)
EOF
set +e; sh "$SIG" "$T/known_only.log" "$T/baseline" > "$T/out1"; check "1. only the known NSW failure -> quiet" 0 $?; set -e

# 2. The numbers move, as they do every time a poll lands. Still quiet.
sed 's/21.29 against 24.67 from 3 polls/19.80 against 25.10 from 7 polls/' \
  "$T/known_only.log" > "$T/moved.log"
set +e; sh "$SIG" "$T/moved.log" "$T/baseline" > /dev/null; check "2. same failure, different numbers -> quiet" 0 $?; set -e

# 3. A SECOND party breaches the same check. Must fire.
cp "$T/known_only.log" "$T/newparty.log"
echo '    2027 GRN fitted 9.10 against 12.90 from 9 polls (bound 2.5)' >> "$T/newparty.log"
set +e; sh "$SIG" "$T/newparty.log" "$T/baseline" > "$T/out3"; check "3. a NEW party breaches NL3 -> fires" 1 $?; set -e
grep -q "breach:NL3:2027:GRN" "$T/out3" || { echo "   (did not name the new token)"; FAILED=1; }

# 4. A different stage fails as well. Must fire.
cp "$T/known_only.log" "$T/newstage.log"
printf '!! VALIDATION STAGE FAILED: federal cycles\n   CHECK FAILED: scripts/fit_federal.R (exit 1)\n' >> "$T/newstage.log"
set +e; sh "$SIG" "$T/newstage.log" "$T/baseline" > "$T/out4"; check "4. an extra stage fails -> fires" 1 $?; set -e
grep -q "stage:fit_federal.R" "$T/out4" || { echo "   (did not name the new stage)"; FAILED=1; }

# 5. A check that could not RUN is its own token, never a silent pass.
cat > "$T/errored.log" <<'EOF'
=== S7 BREACH ON THE PUBLISHED FORECAST'S OWN TREND ===
    2026 S7 COULD NOT RUN: length(fits) > 0L is not TRUE
EOF
set +e; sh "$SIG" "$T/errored.log" "$T/baseline" > "$T/out5"; check "5. the check itself errored -> fires" 1 $?; set -e

# 5b. A CRASH in a target stage. run_all.R does not wrap target stages in its
#     validation tryCatch, so "CRASHED: scripts/fit_vic.R ..." is the ONLY line
#     there is -- no "VALIDATION STAGE FAILED" to fall back on. The first
#     version of the tokeniser matched neither label, produced zero tokens, and
#     an empty set is a subset of any baseline, so the alarm said "nothing new"
#     on a crashed live forecast. Found by review; this is its regression test.
cat > "$T/crash.log" <<'EOF'
--- Victoria (live target) (scripts/fit_vic.R) ---
Error in run(s) :
  CRASHED: scripts/fit_vic.R (exit 1) after 4 s -- Error: object 'x' not found
EOF
set +e; sh "$SIG" "$T/crash.log" "$T/baseline" > "$T/out5b"; check "5b. a target stage CRASHED -> fires" 1 $?; set -e
grep -q "stage:fit_vic.R:CRASH" "$T/out5b" || { echo "   (did not emit a CRASH token)"; FAILED=1; }

# 5c. A DIFFERENT check failing in a script the baseline already lists. The
#     coarse token `stage:fit_nsw.R` used to match this and mute it, even
#     though the baseline entry is justified only for NL3 and One Nation.
cat > "$T/otherchk.log" <<'EOF'
!! VALIDATION STAGE FAILED: NSW cycles
   CHECK FAILED: scripts/fit_nsw.R (exit 1) after 20 s -- Error: NL4a acf1 out of bounds for 2 party-cycles
EOF
set +e; sh "$SIG" "$T/otherchk.log" "$T/baseline" > "$T/out5c"; check "5c. a DIFFERENT check in a known script -> fires" 1 $?; set -e
grep -q "NL4a" "$T/out5c" || { echo "   (did not distinguish it from the known NL3 failure)"; FAILED=1; }

# 5d. "FAILED (no error text)" -- the fourth label, also unmatched before.
cat > "$T/notext.log" <<'EOF'
   FAILED (no error text): scripts/build_page.R (exit 1) after 2 s
EOF
set +e; sh "$SIG" "$T/notext.log" "$T/baseline" > "$T/out5d"; check "5d. FAILED (no error text) -> fires" 1 $?; set -e

# 6. A clean run. Quiet, and every baseline line reported as ready to delete.
: > "$T/clean.log"
set +e; sh "$SIG" "$T/clean.log" "$T/baseline" > "$T/out6"; check "6. nothing failed -> quiet" 0 $?; set -e
grep -q "NOT failing this run" "$T/out6" || { echo "   (did not report the stale baseline)"; FAILED=1; }

# 7. THE REGRESSION THIS WAS BUILT FROM, on the two real CI logs if present:
#    the run before fit_federal.R was fixed must fire, the one after must not.
for pair in "/tmp/clean_before.log:1:before the conv=52 fix" "/tmp/clean_now.log:0:after it"; do
  f=${pair%%:*}; rest=${pair#*:}; want=${rest%%:*}; label=${rest#*:}
  if [ -r "$f" ]; then
    set +e; sh "$SIG" "$f" .github/known-failures.txt > /dev/null; check "7. real CI log, $label" "$want" $?; set -e
  else
    printf '%-58s SKIPPED (no %s)\n' "7. real CI log, $label" "$f"
  fi
done

echo
if [ "$FAILED" = 0 ]; then echo "all checks behave as specified"; else echo "SOMETHING IS WRONG"; exit 1; fi
