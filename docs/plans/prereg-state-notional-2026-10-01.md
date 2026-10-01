# Pre-registration: state notional priors (`AUSPOL_STATE_NOTIONAL = "1"`)

Registered 2026-10-01, before any harness run with the switch on (one
500-simulation smoke test of vic2014 confirmed only that it runs: 88 of 88
districts scored; its files were moved out of `output/` unread for scoring).

## Change

On a state pair preceded by a redistribution (`STATE_REDISTRIBUTIONS`,
R/state_notional.R: vic2014, vic2022, nsw2023, sa2022, sa2026, wa2008, wa2013,
wa2017, wa2025 among the harness pairs), the prior first preferences are
replaced by the notional built from booth results on the target's boundaries
(scripts/build_state_notionals.py), in all five state harnesses, so it reaches
base_pred; the same notionals feed the xgb layer's `x_notional_adj`. Mirrors
federal `AUSPOL_NOTIONAL = "2"`. Pre-check (scripts/eval_state_notionals.py):
the notional beats the raw prior on every redistribution pair, swing-adjusted
seat-share error.

## Run

`AUSPOL_STATE_NOTIONAL=1 AUSPOL_REBUILD_FROM=1 bash scripts/rebuild_forecasts.sh`
against v56 (`output/snapshots/20260930-2115-72387b7-from1`).

## Criteria (seat log loss clamped at 1e-6; SE clustered on seat)

1. PRIMARY (targeted): seat log loss on seats scored in BOTH runs within the
   redistribution pairs: mean change < 0.
2. GUARD, all 22 elections, seats scored in both runs: per-election mean change
   not worse than +1 SE.
3. GUARD, Victoria (vic2014/2018/2022, seats in both runs): not worse than +1 SE.
4. Primary-vote RMSE, xgb layer, rows in both runs: not worse by more than 0.02.

Newly scored seats (renamed districts) are reported separately: count, their
log loss, and the pair's mean. UNACCEPTABLE if the renamed seats' log loss is
more than twice their pair's same-name mean -- that would mean the notional is
wrong, not that the seats are hard.

## Decision

Scoring a district the backtests silently dropped is a correctness fix (Pete's
call on the federal equivalent, 2026-09-05), so this ships if 2-4 hold and the
unacceptable clause does not fire, even if 1 is flat. If 1 is worse, it does not
ship and comes back to Pete.
