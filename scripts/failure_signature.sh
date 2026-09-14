#!/usr/bin/env sh
# Reduce a run_all.R log to a STABLE SET OF FAILURE TOKENS, so the nightly
# alarm can fire on a CHANGE rather than on redness.
#
# Why this exists: the scheduled forecast refresh has been red continuously,
# and an alarm that fires every night is one people stop reading -- the exact
# failure .github/workflows/forecast.yaml's own comments were written to
# prevent, arriving through the alarm instead of through silence. But simply
# muting it would hide a NEW failure behind an old one. So the alarm needs to
# know what "the same as yesterday" looks like, and that needs a signature
# that survives the numbers changing.
#
# Hence tokens carry WHAT and WHO, never HOW MUCH:
#
#   stage:fit_nsw.R                a stage that failed
#   breach:NL3:2027:ONP            a party breaching a named check in a cycle
#
# One Nation's NSW gap moves every time a poll lands; that it is One Nation, in
# 2027, breaching NL3 does not. A second party joining it is a new token and
# does raise the alarm, which is the point.
#
# Usage:
#   scripts/failure_signature.sh run.log
#       -> sorted unique tokens, one per line (empty if nothing failed)
#   scripts/failure_signature.sh run.log .github/known-failures.txt
#       -> a report, and exit 1 if anything is failing that the baseline does
#          not already account for, 0 otherwise
#
# THE COMPARISON LIVES HERE RATHER THAN IN THE WORKFLOW YAML on purpose. Logic
# embedded in a `run:` block cannot be run locally or tested against a
# deliberately broken input, and the last two defects in this repo's alarm were
# both in exactly that kind of untested inline shell -- a grep that matched
# none of the shapes run_all.R emits, and a comment that contradicted the code
# beneath it. The workflow calls this; scripts/test_failure_signature.sh proves
# it on real logs.
#
# POSIX sh + awk only, and deliberately no gawk extensions: ubuntu-latest
# runners default to mawk, so match(s, re, arr) and friends are unavailable.

set -eu

LOG="${1:-/dev/stdin}"
BASELINE="${2:-}"
[ -r "$LOG" ] || { echo "failure_signature: cannot read $LOG" >&2; exit 2; }

tokenise() {
awk '
  # "!! VALIDATION STAGE FAILED: NSW cycles" -> stage:NSW cycles
  /VALIDATION STAGE FAILED:/ {
    i = index($0, "VALIDATION STAGE FAILED:")
    s = substr($0, i + length("VALIDATION STAGE FAILED:"))
    gsub(/^[ \t]+|[ \t\r]+$/, "", s)
    if (s != "") print "stage:" s
    next
  }

  # A stage failure, WITH THE REASON IN THE TOKEN.
  #
  # ALL FOUR labels stage_failure_label() can emit (R/stage_failure.R): the
  # first version matched only CHECK FAILED and FAILED (unclassified), so a
  # CRASHED or FAILED (no error text) stage produced NO TOKEN AT ALL. An empty
  # token set is a subset of any baseline, so the alarm said "nothing new" and
  # stayed silent on a crash -- in a target stage like fit_vic.R, which is not
  # wrapped by the validation tryCatch in run_all.R, that was the only line
  # there was. A mute button, found by review 2026-09-14.
  # (No apostrophes below this point: the awk program is single-quoted, and one
  # in a comment closes it -- which is how this very block first failed.)
  #
  # AND THE ERROR TEXT, not just the script name. `stage:fit_nsw.R` matches
  # that script failing for ANY reason, so with it in the baseline a brand-new
  # NL4 breach -- or a crash -- would have been muted by an entry whose written
  # justification is specifically about NL3 and One Nation. Carrying the reason
  # means a different failure in the same script is a different token, and
  # therefore an alarm. Same review.
  /(CHECK FAILED|CRASHED|FAILED \(no error text\)|FAILED \(unclassified\)): scripts\// {
    kind = "UNCLASS"
    if (index($0, "CHECK FAILED:")) kind = "CHECK"
    else if (index($0, "CRASHED:")) kind = "CRASH"
    else if (index($0, "FAILED (no error text):")) kind = "NOTEXT"

    i = index($0, "scripts/")
    s = substr($0, i + length("scripts/"))
    sub(/[ \t(].*$/, "", s)

    # Everything after "-- Error: " identifies WHICH check or crash it was:
    # "nrow(bad_conv) == 0 is not TRUE", "NL3 breached on 1 NSW cycle(s)...".
    # Truncated, because the tail carries paths and timings that churn.
    why = ""
    j = index($0, "-- Error: ")
    if (j > 0) {
      why = substr($0, j + length("-- Error: "))
      gsub(/[ \t\r]+/, " ", why)
      sub(/^ /, "", why)
      why = substr(why, 1, 60)
      sub(/ +$/, "", why)
    }
    if (s != "") print "stage:" s ":" kind ":" why
    next
  }

  # "=== NL3 BREACH ON AN NSW CYCLE (not the published forecast) ===" sets the
  # code for the indented lines that follow it. $2 is the code.
  /^=== / && /BREACH/ { code = $2; next }

  # A blank line or a new "===" heading ends the block, so a later stray line
  # cannot inherit a stale code.
  /^[ \t]*$/ { code = ""; next }
  /^=== / { code = ""; next }

  # "    2027 ONP fitted 21.29 against 24.67 from 3 polls (bound 2.5)"
  # Leading whitespace is not a field in awk, so $1 is the year and $2 the
  # party. Also matches "2026 S7 COULD NOT RUN: ...", deliberately: a check
  # that could not run is its own distinct token, not a silent pass.
  code != "" && $1 ~ /^[0-9][0-9][0-9][0-9]$/ && $2 ~ /^[A-Za-z]/ {
    print "breach:" code ":" $1 ":" $2
    next
  }
' "$LOG" | LC_ALL=C sort -u
}

if [ -z "$BASELINE" ]; then
  tokenise
  exit 0
fi

[ -r "$BASELINE" ] || { echo "failure_signature: cannot read $BASELINE" >&2; exit 2; }

TMP="${TMPDIR:-/tmp}/fs.$$"
mkdir -p "$TMP"
trap 'rm -rf "$TMP"' EXIT

tokenise > "$TMP/now"
# Comments and blank lines are for humans; strip them before comparing.
sed -e 's/#.*$//' -e 's/^[ \t]*//' -e 's/[ \t\r]*$//' "$BASELINE" \
  | grep -v '^$' | LC_ALL=C sort -u > "$TMP/known"

LC_ALL=C comm -23 "$TMP/now" "$TMP/known" > "$TMP/new"
LC_ALL=C comm -13 "$TMP/now" "$TMP/known" > "$TMP/gone"

if [ -s "$TMP/now" ]; then
  echo "Failing now:"
  sed 's/^/  /' "$TMP/now"
else
  echo "Failing now: nothing."
fi

# A baseline entry that has stopped failing is REPORTED, never auto-removed.
# Deleting it is a decision -- the failure may simply not have been reached
# this run -- and a stale entry would mute the failure if it came back, so it
# needs a human to look. Reporting it is how anyone finds out it is ready to go.
if [ -s "$TMP/gone" ]; then
  echo
  echo "In the baseline but NOT failing this run -- consider deleting these"
  echo "lines from $BASELINE, and check the failure is really fixed rather"
  echo "than merely not reached:"
  sed 's/^/  /' "$TMP/gone"
fi

if [ -s "$TMP/new" ]; then
  echo
  echo "NEW failures, not accounted for by $BASELINE:"
  sed 's/^/  /' "$TMP/new"
  exit 1
fi

echo
echo "Nothing new: every failure this run is already in $BASELINE."
exit 0
