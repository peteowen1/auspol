# Pre-registration: trend that can follow a surging party (2026-10-08)

Written and committed before any result of this arm is read.

## Why

The statewide trend lags its own polls when a minor party surges:

- **SA 2026** (completed): One Nation forecast 20.3 as at 2026-03-20 against
  22.3 in the last 60 days of polls and 22.9 actual.
- **NSW 2027** (live probe): 19.8 against 25.0 in the last 90 days (S7 breach,
  5.19 points). Two early one-off polls (Redbridge 4, Spectre 16, Dec 2025)
  carry most of it: without them the fit is 23.2.

Two causes, sized on SA 2026 as at the day before polling: the day-0 anchor
at the previous election's share (1.8-2.6% for One Nation, sd 5 points) costs
0.5; the default random-walk volatility costs 1.3; together 1.6 of the 2.6.

## Arm

`AUSPOL_TREND_SURGE="1"` (new; default "0"), read inside `trend_as_at()` so the
live forecast and every harness's time-forward statewide forecast see it:

1. A party whose previous-election share is below `TREND_SURGE_PRIOR_MAX`
   (5 points) is anchored at its first poll with the weak sd, as a party with
   no prior already is (`trend_anchor()`). Two-party is untouched.
2. Per-cycle volatility (`sigmas = "per_cycle"`, estimated from the cycle's
   own polls up to the cutoff, already leak-free) unless the caller set
   `sigmas` explicitly.

## Screen and criterion

**Stage 1, statewide (seconds):** the time-forward statewide forecast
(`trend_as_at()` as at the day before polling) for every completed state
pair with polls, shipped against arm, per party, against the actual statewide
primary. Metric: absolute error, points.

- **Primary (targeted):** mean absolute error over party-elections where the
  party's previous share was below 5 and its actual share at least 10 (the
  surges the arm is for). Lower is better.
- **Guard:** mean absolute error over all other party-elections must not rise
  by more than 0.2 points.

**Stage 2, seats (only if stage 1 passes):** `scripts/quick_arm.R
"AUSPOL_TREND_SURGE=1"` on all 22 pairs. Guard: pooled seat-winner log loss
and the AEF-7 ledger subset not WORSE by more than 1 SE. Then a full 20k arm
before any ship decision, and Pete.

## What would make an apparent win unacceptable

- The gain comes from one election (SA 2026) and every other surge case is
  flat or worse: report each surge case separately.
- Major-party errors rise anywhere by more than 0.5 points (the arm changes
  the volatility of every party, not only surging ones).
- Victoria 2026's live statewide One Nation moves by more than 3 points: that
  would mean the arm acts on a party whose polls already track (S7 passes at
  1.94 there), and it gets reported before anything ships.

## Outcome (added 2026-10-08, text above unedited): NOT BUILT

Written without engaging `reviews/poll-lag-2026-08-19.md`, which had already
pre-registered and refused raising One Nation on this evidence (refusal P3).
Found before any code; Pete chose to keep that verdict. See the review's
2026-10-08 addendum for SA 2026 as new evidence.
