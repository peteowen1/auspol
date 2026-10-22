# Prereg: shorter training half-life for the trees (AUSPOL_TRAIN_DECAY_H 8 -> 4)

Written 2026-10-22, before any run. Code at the commit that adds this file; pipeline code unchanged since 50a389c.
Pete chose to run it (22 Oct, over my lean to leave it).

## Why

The 21 Oct publish completed the incumbent/retiring fill for 11 old elections (nsw2011/15, nt2016-24, qld2012-17,
sa2010-18). The 24 elections whose inputs did not change got worse by +0.0040 (SE 0.0012) through the retrained trees
alone. The fill was checked and is not wrong in the 11 (NEXT-STEPS, 22 Oct). So the trees now learn more from old rows,
and it costs the recent elections. The shipped training weight already discounts old rows: a row `age` years before
the target counts 0.5^(age/8) (`fit_xgb_primary_asat.R:98`, shipped 13 Oct as part of P4). Only 8 and Inf were ever
measured (`plans/prereg-training-weights-2026-10-13.md`). A half-life of 4 years cuts a 2012 row's weight for a 2024
target from 0.35 to 0.12.

## The run

- **Arm:** `AUSPOL_TRAIN_DECAY_H=4`, everything else at published flags. One isolated copy of the repo, rebuilt from
  stage 4 (the as-at tree models) at 20,000 sims. Never publishes. `deciding-runs/decay4-rebuild/chain.sh`.
- **Baseline:** the 21 Oct publish (`output/snapshots/20261021-1734-50a389c-from3/published-predictions.csv`), not a
  second rebuild. Why that is enough: on 20 Oct a baseline rebuild at the same code reproduced the published pooled
  0.3256.
- **Reproduction check, before anything is scored:** fed2007, wa2001, wa2005 and wa2008 did not move between the 19 and
  21 Oct publishes (no as-at trees train for them). They must be byte-identical between arm and baseline. If not, the
  run is not comparable and nothing below is read.

## Criterion (the standard rule, `PRE-REGISTRATION-RULES.md`)

Seat-winner log loss on the published path, lower is better, SE clustered on election, floor 1e-6. Scorer:
`Rscript scripts/score_contest_feats.R deciding-runs/decay4-rebuild/base <arm copy> 1e-6 docs/plans/decay4-targets-2026-10-22.csv`
(dry run 22 Oct, self against self: 2,267 target seats in 24 elections, change 0.0000).

1. **Primary:** the 2,267 seats of the 24 elections the refresh did not touch (the drift being chased), better by more
   than 1 SE.
2. **Guard:** all 2,931 seats in 35 elections, not worse by more than 1 SE.
3. **Leave-one-election-out** on the primary holds.
4. **No election worse** by more than 2 SE of its own seats.
5. Without the two largest-gain seats the primary keeps its sign.

Reported, not voted: AEF-7 (681 seats) against AEF's 0.2825; the 11 refilled elections; Ipswich West, Morwell and
Kalamunda; the 1e-4 floor; primary-vote RMSE.

## Named in advance: what would make a win unacceptable

(a) The gain lives only at the 1e-6 floor (the 1e-4 floor disagrees in sign).
(b) The primary gain is the three upsets of 21 Oct alone (Ipswich West, Morwell, Kalamunda): it must hold with them
    removed. Getting back what retraining took on three long shots is not a model improvement.
(c) The 11 old elections get worse by more than 2 SE as a group: a half-life that only works by forgetting the
    elections we just completed is the opposite of what completing them was for.

Shipping is Pete's call on the result.
