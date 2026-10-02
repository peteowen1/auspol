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

## RESULT, 2026-10-02 16:25: REFUSED on the Brier guard

Stage 6 on v58's stages 1-5, mixed by stage 6b (eps 0.003-0.03 per election;
live vic2026 0.003). Matches the offline estimate to four decimals.
1. 22-election log loss 0.3444 -> 0.3396 (-0.0048) -- PASS.
2. Victoria 0.2696 -> 0.2688 -- PASS.
3. Accuracy 0.8802 -> 0.8802 -- PASS; Brier 0.0894 -> 0.0904 (+0.0010 > 0.0005) -- FAIL.
AEF-7 ledger 0.2686 -> 0.2725 (every AEF-7 election pays the premium; none had
a zero-probability winner). 16 of 22 elections worse; gains fed2010 -0.086,
nsw2019 -0.058, fed2013 -0.047, vic2014 -0.013.
Reading: blanket insurance trades everyday sharpness (Brier) for rare
catastrophic misses (log loss). The upsets it rescues were predicted at 5-9%,
like hundreds who went nowhere, so the next attempt has to put the probability
on the RIGHT candidates (what distinguishes Wilkie/Oakeshott/McGowan/Butler),
not on all of them. Code kept behind AUSPOL_UPSET_FLOOR (off); the stage-6b
step is reusable for a targeted weight.

Implementation bugs found and fixed while running (none affected the scored
result): a misplaced `$a` emptied the table; a placeholder election zeroed SA's
win files; NSW win files name the probability `p`.
