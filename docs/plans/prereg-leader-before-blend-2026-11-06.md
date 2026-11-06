# Pre-registration: the leader-seat bonus before the seat-poll blend (`AUSPOL_LEADER_BEFORE_BLEND`)

Written 2026-11-06 ~7:50pm, before any screen. Found tracing the worst AEF-7 seat (Pete: "keep going and digging").

## What it changes

`leader_seat_bonus()` is fitted as actual minus the as-at tree prediction BEFORE the seat-poll blend (`xgb_pred_seat`).
Every script (six harnesses, NT, `fit_seats_full.R`) adds it AFTER the blend. A leader's seat with seat polls therefore
counts the leader effect twice: the polls already measure it. Melbourne fed2025: tree 49.35 Greens; the blend alone gives
45.94 (checked by calling `seat_poll_blend_apply()` on that row); +2.58 bonus, published 49.26. Bandt got 39.46; Labor won
and we gave it 0.006, the worst seat in AEF-7. Dickson fed2025 (Dutton) got the same +2.58 and is also a top-10 miss
(Labor 0.085). The switch moves the bonus before the blend; an unpolled leader seat is unchanged (the blend does not touch it).

## Known answers, stated before the screen

- Melbourne fed2025 Greens falls from 49.26 toward about 46-47 (the blend pulls part of the bonus back); Labor's win
  probability rises from 0.006.
- Every seat that is not a polled leader seat is byte-identical (common random numbers in `quick_arm.R`).
- Applied check: LS1 prints once per election, from the pre-blend call when on.

## Screen

`scripts/quick_arm.R "AUSPOL_LEADER_BEFORE_BLEND=1" --pairs=all --sims=1000`, baseline the shipped configuration.

- Primary: seat-winner log loss (lower is better) on the leader seats that have seat polls (named from the run's LS1
  lines and the seat-poll table, before reading the result), SE clustered on election.
- Guard: pooled log loss over all 35 elections not worse by more than 1 SE.
- Reported: primary share error on the leader's class in those seats.

The leader seats with polls are few (a handful per polled election), so the primary's own noise is large; a result
within 1 SE is a TIE. Decision rule (standard): primary better by more than 1 SE and the guard holds: recommend the
20k deciding run, then ship; a tie goes to Pete as a correctness fix (the bonus is fitted pre-blend, so pre-blend is
where it belongs) with the split shown; worse: to Pete with the split.

What would make a win unacceptable: the gain coming from unpolled seats (impossible by construction; if any unpolled
seat moves, the plumbing is wrong and the run is void).

## RESULT

(not run)
