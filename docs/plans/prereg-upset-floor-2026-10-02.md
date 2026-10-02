# Pre-registration: upset insurance (`AUSPOL_UPSET_FLOOR = "1"`)

Registered 2026-10-02 before running. Pete chose it over first hunting for the
upset signal ("Build and pre-register it").

## Problem
Seven seat-elections in v58 gave the winner under 1 in 10,000 (five exactly 0)
and carry 13% of all log loss; Barwon 2019 alone decided two verdicts today.

## Change
Stage 6b (scripts/apply_upset_floor.R, R/upset_floor.R): win probabilities
mixed as (1 - eps) * p + eps * w, w = the seat's independent/minor contenders
predicted at >= 2%, in proportion to predicted share; eps fitted per target on
EARLIER elections' raw probabilities by log loss (0 with fewer than 2 earlier
pairs). Live Victoria: eps fitted on all 22 pairs, applied after S5.
Offline on v58: 22-election log loss 0.3444 -> 0.3396, Victoria -0.0008, 16 of
22 elections slightly worse (the premium), large gains where upsets happened.

## Run
`AUSPOL_UPSET_FLOOR=1 AUSPOL_REBUILD_FROM=6` on v58's stages 1-5, against v58
(`output/snapshots/20261002-1435-0a481f6-from3`).

## Criteria
1. PRIMARY: 22-election per-election log loss lower by more than 0.0020 (the
   ensemble's seed range).
2. GUARD: Victoria seat log loss not worse by more than 0.0018.
3. GUARD: accuracy (winner called) not worse by more than 0.001; Brier not
   worse by more than 0.0005.
Reported: elections worse, the eps per election, the ledger.
