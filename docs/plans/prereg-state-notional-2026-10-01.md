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
