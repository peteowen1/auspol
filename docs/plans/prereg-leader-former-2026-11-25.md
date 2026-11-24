# Pre-registration: former leaders' seats (`AUSPOL_LEADER_FORMER`), 25 Nov 2026

Committed before the screen runs.

## What changes

The leader-seat bonus adds a party's points in its CURRENT leader's seat but never takes back the
previous leader's personal vote where that leader has gone. Found 24 Nov tracing Mulgrave (Andrews).
`AUSPOL_LEADER_FORMER=1` adds a row per former-leader seat (the seat a party's leader held at the
previous same-jurisdiction election, where that party's leader now sits elsewhere), fitted exactly like
the leader-seat bonus: actual minus as-at tree prediction less the class's median miss, time-forward,
partially pooled by role, pooled mean shrunk toward 0. Pete chose "Build it anyway" (25 Nov) after being
told it cannot flip Mulgrave.

Sizing before any code (live as-at predictions): 36 former-leader seats, mean -1.70 points, SE 0.82,
shrunk -1.38. On this checkout's 13 Nov predictions the fitted value for vic2026 is -1.04 (all roles
pooled; tau^2 = 0).

## Screen and decision rule

`scripts/quick_arm.R "AUSPOL_LEADER_FORMER=1" --pairs=<every pair with a former-leader seat>` at the
default sims, against the published config.

- PRIMARY (targeted): squared error of the former leader's party's primary at the former-leader seats,
  arm vs baseline, SE clustered on election. Ship if lower.
- DO-NO-HARM: pooled seat-winner log loss over the touched pairs not worse by more than 1 SE, and no
  single election worse by more than 0.01.

What would make an apparent win unacceptable: an untouched pair moving (must be byte-identical), or the
log line `LS1` not naming the expected former-leader seats on a pair where they exist.
