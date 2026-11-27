# Pre-registration: election-night projection, lane A (booth-level swing, vote-type pooling, representativeness sd)

Written 27 Nov 2026 (night before the Victorian election), BEFORE any arm was scored. Plan:
`docs/plans/overnight-2026-11-27-night-fixes.md` (lane A, Pete's items 2, 3, 4).

## The problem

The night projection gives every uncounted unit of a seat the seat's counted swing, pooled by booth type. The first
booths in are not like the ones still to come. Mildura vic2022: at 7pm, 4 booths (0.9% counted) projected the Coalition
at 31.7% (final 45.0); at 8pm, 18 booths (15%) still 39.0. Pooled over three replayed nights, the major parties'
projection RMSE under 0.5% counted is 6.15 points, against the 3.5 the projection sd table assumes.

## Arms (each its own switch, default off and byte-identical when off; `tests/testthat/test-night-lane-a.R`)

- **A1 booth-level swing** (`night_booth_update(booth_reg_k = 5)`, extraction `--booth-reg=5`): each uncounted
  ordinary booth's swing = the seat's ordinary swing + beta x (its reference share - counted booths' reference share).
  beta = within-seat slope of counted booths' swing on reference share (booth-total weights), partial-pooled toward the
  slope pooled over all seats' counted booths at that snapshot by n / (n + 5), n counted ordinary booths; clipped to
  [-1, 1]. k = 5 fixed in advance, no sweep.
- **A2 vote-type pooling** (`type_pool_k = 5`, `--type-pool=5`; needs `gap_k`, which the live night runs at 5): each
  type's swing = w x its own counted swing + (1 - w) x (seat's ordinary-equivalent swing + the type's pooled gap),
  w = m / (m + 5), m its counted votes in median-ordinary-booth units. Ordinary-equivalent = every counted type's swing
  minus its gap, vote-weighted. Fixes a seat with only its early vote in projecting ordinary booths at the raw early swing.
- **A1+A2** together (`--booth-reg=5 --type-pool=5`).
- **A3 representativeness sd** (`rep_sd = c(a, b)`): sd^2 = sd_table^2 + unc_frac^2 x (a x rep_dist^2 + b x
  swing_sd^2 / (n_ord + 1)). rep_dist = size-weighted reference-share distance (points) between uncounted and counted
  units; swing_sd = spread of counted booth swings (points). a, b fitted by Gaussian likelihood, LEAVE-ONE-NIGHT-OUT
  (fit on two nights, score the third). Fitted on top of whichever mean arm wins the mean screen (or base if none).
- **Unit sizes from the VEC's 2026 early/postal counts**: NOT built tonight. No pre-election early/postal count by
  district is on disk for vic2022, fed2022 or fed2025 (`external/reference/vec-early-vote-2026/` holds 2026 only), so
  this sub-fix cannot be tested on any replay. Stated plainly rather than built untested.

## Scoring (scripts/fit_night_projection_sd.R extraction, no simulation, snapshots to 21:00, cand_ref copy, gap_k 5,
total = "expected"; scorer `laneA_score.R` in the session scratchpad, copied to the RESULT section)

- Cells: (night, snapshot, seat, class) with true counted share (counted votes / final votes) under 15%.
- **Primary, mean arms (A1, A2, A1+A2): projection RMSE (points) of first preferences, all classes, pooled over the 3
  nights**, SE of the arm-minus-base squared-error difference clustered on (night, seat). Pass: arm RMSE below base
  and the MSE difference more than 1 SE below zero.
- **Primary, sd arm (A3): mean Gaussian log score** (-log density of the error under the arm's sd), scored
  leave-one-night-out; pass: better than the table sd by more than 1 SE (clustered on night, seat).
- Major parties (ALP, LNP) reported alongside, not decisive.
- **Named targets** (reported, not decisive): Mildura vic2022 LNP at 19:00 and 20:00.
- **Guards** (a fail refuses the arm): no counted-share bin (<0.5, 0.5-1, 1-2, 2-5, 5-10, 10-15%) worse by more than
  1 SE; no night worse (point estimate of RMSE above base by more than 1 SE). Cells 15-50% reported as a do-no-harm check.
- What would make an apparent win unacceptable: a gain carried by one night while another is worse (guard); a win in
  the mean that only comes from clipping; any fitted constant scored in-sample.

## Additions (written ~10pm 27 Nov, after review, BEFORE any arm was scored; the clauses above are unedited)

1. **A1b** (`booth_reg_all = TRUE`, `--booth-reg=5 --booth-reg-all=1`): the A1 offset also applied to every uncounted
   non-ordinary unit with a reference (the early and postal blocks). Reason: in Mildura vic2022 49% of the final votes
   were early and none were counted by 9pm, so an ordinary-only A1 leaves most of the projection untouched. Same
   criterion and guards as A1.
2. **A3 control**: A3 must also beat the count-only `"fitted"` sd curve (refused at the seat level tonight) on the same
   cells and the same leave-one-night-out split; if it does not, it is that refused arm again. A3 is screen-only either
   way: a pass goes to the main session's seat-level replay, it is not shipped from this screen.
3. A2's booth-size unit uses REFERENCE booth totals (a live feed's uncounted units hold nothing; a replay's hold the
   final result, which would leak). Fixed before the a2 arm ran.

## RESULT

Extraction: `scripts/fit_night_projection_sd.R --extract-only=1 --max-time=21:00 --rep-diag=1 [arm flags]`, code from
this branch (`NRCODE ... agent-ae47cc1c59d6b5cf5` read in every log). Scorers: `laneA_score.R` (means), `laneA_sd.R`
(A3) in the session scratchpad `laneA/`. RMSE in share points, lower is better; dMSE = arm squared error minus base,
negative is better, SE clustered on (night, seat). Cells: (night, snapshot, seat, class), counted share = counted votes
over final votes.

**Off is identical.** The base run on this branch (all switches off, diag columns on) reproduced the earlier main-code
extraction exactly: max |difference| 0 in projection and sd on all 16,546 rows (vic2022 1,293, fed2022 7,878, fed2025
7,375). The unit test also pins the switches-off output to values computed with the pre-lane-A code (403f3f9d).

**Found on the way, fixed separately (0fb2b74d): the vic2022 replay never projected uncounted ordinary booths.** The
2022 set-up polling list has no Classification, so no placeholders were made; the vic2022 rows above (and the whole
vic2022 base the night replays measured) projected the uncounted remainder at the early/postal reference shares. That
is why every arm moved vic2022 by ~0 and Mildura not at all. Every number below uses vic2022 re-extracted on the
corrected place list (placeholders per snapshot: 1,729 at 6:03pm, 1,542 at 7pm, 843 at 8pm, 325 at 9pm). The corrected
base is WORSE on vic2022 under 15% counted (RMSE 3.196 -> 3.457 points, 621 cells): the old base was wrong in a way that
happened to score better.

### Mean arms, cells under 15% counted (7,378 cells, 369 seat-nights; fed2022 3,336, fed2025 3,421, vic2022 621)

Projection RMSE of first preferences, share points, lower is better. dMSE = arm minus base mean squared error, negative
is better, (SE) clustered on night x seat.

| arm | RMSE base | RMSE arm | pooled dMSE (SE) | fed2022 dMSE (SE) | fed2025 dMSE (SE) | vic2022 dMSE (SE) | verdict |
|---|---|---|---|---|---|---|---|
| A1 booth swing, ordinary booths (k 5) | 2.742 | 2.792 | +0.276 (0.162) | +0.242 (0.266) | **+0.557 (0.219)** | **-1.091 (0.384)** | FAIL (primary worse; fed2025 worse 2.5 SE) |
| A1b booth swing, all units | 2.742 | 2.835 | +0.520 (0.213) | +0.440 (0.338) | **+0.903 (0.286)** | -1.166 (0.698) | FAIL (primary worse 2.4 SE; fed2025 3.2 SE) |
| A2 vote-type pooling (k 5) | 2.742 | 2.742 | +0.001 (0.001) | 0 exactly | 0 exactly | +0.007 (0.011) | FAIL (no effect) |
| A1 + A2 | 2.742 | 2.792 | +0.276 (0.162) | +0.242 (0.266) | +0.557 (0.219) | -1.090 (0.384) | FAIL (same as A1) |

Majors only (ALP, LNP; 2,418 cells): base 3.297, A1 3.449, A1b 3.534. A1's worst seats: Grey 2022 (+669 summed squared
error), Whitlam 2025 (+412), Riverina 2025 (+215); best Herbert 2022 (-255), Mulgrave vic2022 (-168).

**The split is by night type, not noise:** the booth-share slope helps the one Victorian night by 2.8 SE and hurts both
federal nights. Not tuned (k fixed in advance); the federal nights are 11 times the cells. Recorded, not acted on.

A2 is a no-op by construction on the federal nights (only ordinary places are counted there by 9pm, so each type's
pooled swing equals the old ordinary-swing-plus-gap) and nearly so on vic2022 (the early unit counts as one block).

**Named target, Mildura vic2022, Coalition (final 45.0) / independents (final 41.2):**

| snapshot | corrected base | A1 | A1b |
|---|---|---|---|
| 7pm | 34.1 / 43.5 | 38.8 / 38.5 | 44.0 / 32.8 |
| 8pm | 40.1 / 45.8 | 41.1 / 45.0 | 43.0 / 43.3 |
| 9pm | 42.8 / 42.1 | 43.0 / 42.0 | 44.3 / 40.9 |

A1b fixes the Coalition in Mildura at 7pm and over-corrects the independents (32.8 against 41.2).

### A3 representativeness sd (fitted leave-one-night-out), cells under 15% counted

Mean Gaussian log score (negative log density of the error), lower is better. Fitted on the corrected base:
sd^2 = sd_table^2 + unc_frac^2 x a x rep_dist^2, a = 0.0458 (all three nights; held-out fits 0.039-0.064). b (the
booth-swing spread term) fitted to 0 on every split.

- Against the table sd (the original criterion): 2.3911 -> 2.3761, diff -0.0149 (SE 0.0048). Every night better
  (vic2022 -0.027 (0.012), fed2022 -0.011 (0.007), fed2025 -0.017 (0.008)). No bin worse by over 1 SE (largest
  +0.0014 (0.0026) at 5-10%). Gain is almost all in the first 0.5% counted (-0.111, SE 0.031). **PASSES.**
- Against the count-only "fitted" curve refit on the same split (addition 2): -0.052 (SE 0.079), not separable, and
  fed2022 WORSE by 0.148 (SE 0.021). **FAILS the added control clause.**
- On the first, old-vic run the 10-15% bin was worse by 2.1 SE; on the corrected base it is not.

So A3 passes the original criterion and fails the control added before scoring. Per the clause-refusal rule this goes to
Pete, not to me: the recommendation is NOT to ship, because it does not beat a curve already refused at the seat level.

### Not built

Unit sizes from the VEC's 2026 early/postal counts: no pre-election early/postal count by district exists on disk for
any replayed night, so it cannot be tested on a replay. Not built.

### Seat-level replay commands (main session), if wanted

Flags now on `night_replay_vec.R` / `night_replay_feed.R` (via `night_lane_a_args()`, NRV1A / NRF1A print what applied):
`--booth-reg=5` (A1), `--booth-reg-all=1` (with it, A1b), `--type-pool=5` (A2), `--rep-sd=0.0458,0` (A3). None passed the
projection screen outright; the only one worth a seat-level look is A3 (`--rep-sd=0.0458,0`), and only to settle the
control clause.

