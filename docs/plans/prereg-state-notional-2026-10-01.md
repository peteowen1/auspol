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

## Amendment (visible addition, 2026-10-01 18:15): first run void -- builder bug

The first rebuild (`output/snapshots/20261001-1756-2177e4a-from1`) passed every
criterion as written (C1 -0.0184, SE 0.0099; C2 -0.0108, SE 0.0052; Victoria
+0.0058, 0.5 SE; RMSE 4.1617 -> 4.1384; ledger 0.2741 -> 0.2664 on a changed
seat set) but is VOID: the notionals took party classes from the candidacy
corpus, which labels some parties differently from the district files the
harnesses score against (WA 2005's whole 5.2% minor-right vote became "other").
Found because Victoria's primary RMSE rose 4.30 -> 4.57 and Malvern 2014's
Coalition moved 57.0 -> 47.6 in the as-at model with near-identical inputs.
Fixed in scripts/build_state_notionals.py (`reconcile()`; every pair's
statewide class shares now equal the district file's). The deciding run is a
rerun of the same command; criteria and clauses unchanged. Victoria's primary
RMSE, which surfaced the bug, is reported alongside.

## RESULT (deciding run), 2026-10-01 18:40: PASSES

`output/snapshots/20261001-1823-2b63f47-from1` against v56.

| criterion | result | bar |
|---|---|---|
| C1 redistribution pairs, seats in both (n 533) | -0.0153 log loss (SE 0.0096) | < 0 |
| C2 all 22 elections, seats in both | -0.0085 (SE 0.0038) | not worse than +1 SE |
| C3 Victoria, seats in both (n 239) | -0.0109 (SE 0.0098) | not worse than +1 SE |
| C4 primary RMSE, rows in both (11,643) | 4.1617 -> 4.1438 | not worse by > 0.02 |
| renamed seats | 65 newly scored; log loss below their pairs' same-name mean in every pair | unacceptable if > 2x |

Ledger 0.2741 -> 0.2662 (AE Forecasts 0.2851 -> 0.2829: the seat set grew by
60 scored seats, so the gap is the comparable figure: 0.0110 -> 0.0167).

Reported alongside, as the amendment requires: Victoria's primary RMSE
4.2976 -> 4.4567, almost all vic2014 in the xgb layer (Coalition 5.04 -> 6.59).
NOT the notional: vic2014 base_pred improves (Coalition 4.88 -> 4.69, Labor 3.34
-> 3.04), and Malvern's xgb inputs are identical in both runs while its as-at
prediction moves 57.0 -> 48.6 -- the vic2014 as-at model, trained on few
earlier elections, reshuffled when wa2008 gained 21 seats and corrected priors.
That instability is a property of the as-at models, recorded as a finding.

## FINAL v57 run (with Narracan), 2026-10-02 00:05 -- passes; ships

`output/snapshots/20261001-2353-a78e0ae-from1`, published switches only. All
681 AEF-7 seats compared (coverage guard AC9). C1 -0.0109 (SE 0.0090); C2
-0.0066 (SE 0.0040); C3 Victoria -0.0030 (SE 0.0062); C4 4.1617 -> 4.1501.
Ledger 0.2741 (660 seats, AEF 0.2851) -> 0.2700 (681, AEF 0.2825); same 660
seats 0.2741 -> 0.2735. Narracan: ours 0.96 LNP, AEF 0.95, LNP won.

RUN-TO-RUN NOISE, recorded because it changes how every result is read: this
run differs from the 18:23 run only by Narracan (one seat) and a retrain, yet
the like-for-like AEF-7 change moved from -0.0050 to -0.0006. Retraining the
as-at xgb models moves the ledger by ~0.005, the size of most tested effects.
Until that noise is measured (same inputs, different seeds), a single-rebuild
difference under ~0.005 is not evidence either way.
