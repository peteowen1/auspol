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

## Result (25 Nov 2026, 11:15am; screen `deciding-runs/20261125-leader-former/screen.log`, 35 elections, 1,000 sims)

Run exactly as written above. **REFUSED by the do-no-harm clause; the primary passes, within noise.**
(CORRECTION, same morning: a first reading quoted quick_arm's Q2, which scores ALL 145 changed cells including the
other parties in those seats, as the primary; it is not. Q2: 3003.0 -> 3016.9, +13.9, SE 127.9.)
- PRIMARY, as defined (the former leader's party at the former-leader seats; 39 scored of 42, scratchpad
  `former_seats_detail.R` over the screen's cache): squared error 1338.0 -> 1298.0 (-40.0, SE 103.5 clustered on 27
  elections; 13 elections better, 9 worse). Mean error +2.03 -> +1.07 points (we over-call the old leader's party);
  mean absolute error 4.53 -> 4.61; 16 seats closer, 16 further, 7 unchanged. Lower, so it passes as written, but
  well inside one SE.
- WINNER CALLS at those 39 seats: log loss of the actual winner 0.1124 -> 0.1369 (worse). The cost is in close
  seats the old leader's party HELD: Wentworth fed2019 0.337 -> 0.220, Clayfield qld2020 0.663 -> 0.484, Cottesloe
  wa2021 0.645 -> 0.472; helped Dawesville wa2025 0.467 -> 0.583.
- DO-NO-HARM: pooled seat-winner log loss 0.2984 -> 0.2988 (+0.0003, SE 0.0002) over 2,931 seats: worse by more than 1 SE.
  No single election worse by more than 0.01 (largest wa2021 +0.0053). AEF-7 0.2400 -> 0.2398 (-0.0003, SE 0.0004).
- Untouched elections byte-identical: 13 of 35.
Decision goes to Pete (clause refusal on a change he asked for).
