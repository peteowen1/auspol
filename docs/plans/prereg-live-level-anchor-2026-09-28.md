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
