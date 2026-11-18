# Sourced by the forecast workflow's download steps. Wraps `gh` so that
# `gh release download` gets up to three attempts, 15 s apart; every other gh
# call passes straight through.
#
# Why: on 19 Nov 2026 at 4:34am the daily forecast died on "release not found"
# for xgb-flows-tf2-asat-manifest.csv, seconds after two files from the same
# release downloaded fine. The release and the asset were intact (last touched
# 13 Nov). One failed API call left the previous day's forecast live.
#
# A file that is genuinely missing still fails, after about 30 s, and the
# caller's own ::error:: line still names it.
gh() {
  if [ "${1:-}" = release ] && [ "${2:-}" = download ]; then
    local attempt
    for attempt in 1 2 3; do
      command gh "$@" && return 0
      if [ "$attempt" -lt 3 ]; then
        echo "GHR1 gh release download failed (attempt $attempt of 3): $*; retrying in 15 s" >&2
        sleep 15
      fi
    done
    echo "GHR1! gh release download failed 3 times: $*" >&2
    return 1
  fi
  command gh "$@"
}
