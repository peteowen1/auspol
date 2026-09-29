# Pre-registration: the live forecast's statewide LEVEL anchored as the backtests' is

Written 2026-09-28, before running. A parity fix, not a model experiment.

## The defect

Backtests: `forecast_statewide_or_oracle()` hands the seat model
`colMeans()` of the ANCHORED statewide draws, so every seat swings toward a
level whose implied two-party equals the projection (trend mixed with
leave-one-out fundamentals).

Live (`scripts/fit_seats_full.R`): the seats are built from `state_mean`,
the raw trend endpoints (line ~522). The two-party anchoring (line ~1180)
moves only the draws, and `simulate_seat_contests()` subtracts their mean
(`R/seat_sim.R:970`), so the fundamentals pull never reaches a seat.

The ledger therefore scores a recipe production does not run. Size on
2026-09-27 (stale local polls): Labor -0.04 first preference; it varies by
cycle with the trend-fundamentals gap.

## The change

Behind `AUSPOL_LIVE_LEVEL_ANCHOR` in `fit_seats_full.R` only: right after
`state_mean` is built, shift Labor by `delta = pj$mean - implied(state_mean)`
and the Coalition by `-delta`, with `implied` computed with the same
`flow_of()` the draws' anchoring uses. The draws' own anchoring then finds a
mean gap of about zero, as the backtests' does after their anchoring.

## Criterion

1. **Backtests untouched**: nothing under `R/` or the harnesses changes, so
   no ledger number can move. Checked by `git diff --stat` naming only
   `fit_seats_full.R`, `published_flags.R` and docs.
2. **Live level lands**: after the shift, `implied(state_mean)` equals
   `pj$mean` within 0.01, and the draws' anchoring (line ~1180) reports a
   mean shift `mean(d)` within 0.10 of zero (it was the full gap before).
3. **Proven to fire**: a run with the switch at 0 reproduces today's
   published level exactly, and a run with a deliberately large gap
   (`AUSPOL_FORCE_FP` moving Labor 3 points) shows the shift pulling it back
   toward the projection.

If all three hold, it SHIPS (default "1"), because the ledger has measured
this behaviour all along; it is logged as a production change with the
before/after statewide numbers, not as a ledger version.

## AMENDMENTS (added 2026-09-28 after the first runs; the text above is unedited)

1. **Criterion 3 as written cannot work.** The level shift sits BEFORE
   `AUSPOL_FORCE_FP` by design (a forced vote must stay forced), so forcing
   Labor cannot show the shift pulling it back. Replaced by: the switch-off
   run must print the shift as zero and leave the level where the trend put
   it, and the switch-on run must print a shift equal to
   `projection - trend implied`. Both are read from `LL1`.
2. **Criterion 2's second half rested on a wrong premise and exposed a
   second parity defect.** `LL2` read -0.971 (off) and -1.011 (on): the
   draws imply a two-party ~1 point off the level whatever the level is,
   because the draws counted the unpolled bucket twice (OTH took the whole
   `state_mean[["OTH"]]`; IND and OTH_RIGHT were added on top). Fixed as
   `LL3` behind `AUSPOL_LIVE_DRAW_BUCKET` (default "1"): the draws' bucket
   classes take their split of the total, exactly as the seat shares and
   the backtests do. Criterion 2's second half then applies as written.

First-run results (poll clone 1d60706, 25 Sep): level off 47.88 implied vs
projection 47.93; on, ALP +0.04 / LNP -0.04, implies 47.93 (criterion 2a
PASS). Expected seats ALP 34.96 -> 35.09, LNP 34.43 -> 34.31, no favourite
changes.

3. **Amendment 2's diagnosis was WRONG** (the double count is real and
   fixed, but it was not the cause of LL2's -1.0: LL2 still read -1.013
   with it fixed). The cause: the trend endpoints sum to 97.93, not 100.
   LL1 had computed the level's implied two-party on the unscaled total
   (47.88) while the level the seats carry, once renormalised, implies
   48.90 -- the same as the trend's two-party series. So the parity gap is
   ~1 point of Labor two-party, not the 0.04 first reported. LL1 now closes
   the total as the backtests do (OTH = 100 - the rest) and anchors that.

## RESULT (2026-09-28)

- Criterion 1: only `fit_seats_full.R`, `published_flags.R` and docs change.
- Criterion 2: PASS. Level implies 47.93 = projection; LL2 draws' shift
  +0.002 (was -0.969 with the switch off).
- Criterion 3 (as amended): PASS. Off prints ALP +0.00; on prints ALP -0.97
  / LNP +0.97, OTH 10.58 -> 12.65 (remainder).
- Effect on the live forecast (seed 42, 20,000 sims, polls to 9 Sep):
  expected seats ALP 34.89 -> 31.07, LNP 34.36 -> 36.61, ONP 13.45 ->
  14.89; P(ALP majority) 0.114 -> 0.048, P(LNP majority) 0.104 -> 0.174;
  seven favourites change.

**Not shipped: held for Pete** (`AUSPOL_LIVE_LEVEL_ANCHOR` default "0"),
because of the size and because half of it is the remainder-OTH closure,
which is the likely source of the backtests' +2 others-bucket bias
(`prereg-others-bucket-size-2026-09-27.md`). `AUSPOL_LIVE_DRAW_BUCKET`
(the double count) ships at "1".
