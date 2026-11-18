# Pre-registration: several independents in one seat, split by expected points (18 Nov 2026)

Written before any simulation. Trace and backtest evidence: `docs/reviews/essendon-ind-trace-2026-11-18.md`.

## Why

The model forecasts every independent in a seat as one `IND` class and simulates it as one candidate. In seats with
two or more independents that over-calls the class: where we gave it 20%+, 29.9 expected wins against 23 actual
(45 seat-elections, z = -2.6); single-independent seats are calibrated (55.0 against 56). Live, it makes Essendon
(Yildiz, Adams, Mohamud together 22.4%) an 85% independent seat.

The 6 Nov class split (`AUSPOL_CLASS_SPLIT`, `plans/prereg-class-split-2026-11-06.md`) counted the two leading
candidates separately but sized the junior from per-candidate vote predictions, which cannot tell a winner from a
minnow (Kooyong 2022: Ryan and Anderson both predicted 4.9%, junior fraction 0.50 against an actual 0.01). It was
refused twice because it cost the seats the class won.

## What changes (Pete walked it 18 Nov; "lets design now", "try both")

Same split machinery, independents only, new sizing (`AUSPOL_CLASS_SPLIT_MODE`, `R/class_split.R`
`class_split_fit_pts()`, inputs `output/ind-split-candidates.csv` from `scripts/build_ind_split_inputs.R`):

- Each independent's expected vote in points = an intercept by credential known before the election (`MP`,
  `councillor` elected before that year, `prior5` an earlier non-major vote of 5%+, `none`), shrunk toward the pooled
  mean, plus `b` x the run's own forecast of the class. Fitted on second-placed independents at EARLIER elections
  only, against our published-path class forecast. Fitted for vic2026: b = 0.092; intercepts none 1.13, MP 1.61,
  prior5 1.80, councillor 2.61.
- The junior is the candidate with the second-highest expectation; its fraction of the class is its points over the
  class forecast in that simulation, bounded to (0.01, 0.5). Spread: the RMSE of that fraction on earlier elections.
- **Arm C (`pts_cred`)**: as above.
- **Arm K (`pts_carry`)**: as C, but a candidate with an earlier non-major vote expects carry x that vote, carry the
  earlier elections' ratio of vote to earlier vote (vic2026: same seat 0.797, another seat 0.585), with no class term.

Offline check before writing this (seats we gave independents 20%+; mean absolute error of the junior fraction,
lower is better): won seats old 0.184, C 0.099, K 0.092; lost seats old 0.209, C 0.124, K 0.122.

## Known answers, stated before the screen

- Waite sa2022 (0.70 now) and Monash fed2025 (0.61 now): independent win probability must fall.
- Kooyong fed2022 and Indi fed2025: must not fall by more than 0.10 (the 6 Nov failure).
- A seat with fewer than two independents is byte-identical to the baseline.
- Applied check: the `CLS1`/`CLS2` lines for every election, read before any result; an election with no split
  scores 0.0000 and would read as no effect.

## Screen

`scripts/deciding_run.ps1` (detached), `quick_arm.R` with `--pairs=all --sims=1000`, baseline the published
configuration (`AUSPOL_CLASS_SPLIT=0`), common random numbers. Arms: `AUSPOL_CLASS_SPLIT=1 AUSPOL_CLASS_SPLIT_MODE=pts_cred`
and `... =pts_carry`.

- **Primary: seat-winner log loss (lower is better) over seat-elections with two or more independents** (defined
  from nominations, not outcomes), SE clustered on election.
- Guard 1: seats the independents WON (the 6 Nov failure set), not worse by more than 1 SE.
- Guard 2: pooled log loss over all elections not worse by more than 1 SE, and no election worse by more than 2 SE
  of its own seats.
- Reported: Waite, Monash, Kooyong, Indi before and after; leave-one-election-out on the primary.

## Decision rule (standard, `docs/PRE-REGISTRATION-RULES.md`)

- An arm whose primary is better by more than 1 SE with both guards holding passes.
- Both pass: ship the one with the lower primary; within 1 SE of each other, `pts_cred` (fewer inputs).
- Primary within 1 SE: a tie; goes to Pete with the split by seat. A guard fails: goes to Pete; not shipped on my call.

Unacceptable win: the gain coming from seats whose junior polled under 2% (generic independent deflation, not the fix).
Reported as its own line.

Shipping also needs: Essendon, Kew and Footscray traced with the switch on, `check_like_ci.R`, review, and a green
daily run. If it refuses, the fallback is a note on the Edge Board and the live page that Essendon's 85% combines
three independents.

## RESULT, arm C (`pts_cred`), 18 Nov 3:08pm: REFUSED on guard 1

Deciding run `deciding-runs/20261118-1321-indsplit-cred` (code 7194dfef, 1,000 sims, all 35 elections, 70 harness
runs, 6,383 s). Applied: seats moved in 34 of 35 elections. Scored with `scripts/score_ind_split_screen.R` (arm key
25bac0b25a7e, baseline 945382e1244b). Seat-winner log loss, lower is better; SE clustered on election.

| Set | Seats (elections) | Base | Arm - base (SE) | Verdict |
|---|---|---|---|---|
| Primary: 2+ independents on the ballot | 485 (35) | 0.4333 | -0.0027 (0.0047) | within 1 SE (tie) |
| Guard 1: seats the independents won | 92 (27) | 0.6839 | **+0.0663 (0.0148)** | **WORSE, fails** |
| Guard 2: all seats | 2,919 (35) | 0.2738 | -0.0005 (0.0008) | within 1 SE; no election worse by 2 SE |

quick_arm's own pooled line agrees: 0.3033 -> 0.3034 (SE 0.0008). Known answers: Waite 0.709 -> 0.543 and Monash
0.606 -> 0.470 fell as required; Kooyong 0.582 -> 0.433 and Indi 0.965 -> 0.845 fell by more than the 0.10 allowed.
Same failure as 6 Nov, smaller: the split still costs the seats an independent won. Not shipped; goes to Pete.

## Amendment 1 (18 Nov ~3:40pm, AFTER arm C's refusal above; Pete chose "Rescreen anyway")

Visible addition; nothing above is edited. It favours a later answer by construction, so it is held to the same
guards, not looser ones.

- Change: the spread of the junior fraction, pooled 0.153-0.157, is fitted separately for a junior with no
  credential and one with any, each as the RMSE over earlier seats weighted by our class forecast
  (`AUSPOL_CLASS_SPLIT_SD=by_junior`, `class_split_fit_pts()`). fed2022: none 0.135, credentialed 0.117; fed2025:
  0.133 / 0.133; vic2026: 0.130 / 0.143.
- Stated before the rescreen, from a measurement Pete saw: in the group holding most won seats (no-credential
  junior, class 15%+, 82 seats, 25 won) the spread is 0.119 against 0.156, so the expected gain is small and the
  likeliest outcome is the same guard-1 failure.
- Arm: `AUSPOL_CLASS_SPLIT=1 AUSPOL_CLASS_SPLIT_MODE=pts_cred AUSPOL_CLASS_SPLIT_SD=by_junior`, same screen, same
  primary, guards and known answers. Arm K (`pts_carry`) is recorded when its screen ends but is not amended.
