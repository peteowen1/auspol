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

(filled in after the runs)
