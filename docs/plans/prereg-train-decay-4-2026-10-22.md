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

## RESULT (2026-10-25; appended, nothing above edited)

Run 25 Oct 14:31-16:14 (`schtasks /run /tn auspol-decay4-rebuild` at 14:31 with 8,465 MB available; earlier tries at
14:19 and 14:22 refused themselves at 7,358 and 7,817 MB). Isolated copy `C:\dev\auspol-iso-decay4`, rebuilt from stage
4 at 20,000 sims with `AUSPOL_TRAIN_DECAY_H=4` (stage 6 ran twice: spread tables refitted, SPZ3). Code measured: the
copy's HEAD reads 37ccddf, but chain.sh then ran `git checkout 883a773 -- .`, so every tracked file is at 883a773. The
only extra files are R/fp_now.R, R/grn_tree_shrink.R and R/ind_return.R, which were added later and which no 883a773
code calls. Baseline: the 21 Oct publish at 50a389c. 50a389c..883a773 touches only scripts/ges_read_calls.js,
jago_calc.js and snapshot_benchmarks.R, none of them in the pipeline, so both sides ran the same pipeline code.
Logs and scores: `deciding-runs/decay4-rebuild/{arm.log,score.txt,extras.txt}`.

**Reproduction check: PASS.** fed2007, wa2001, wa2005 and wa2008 are byte-identical in `ours` and `p_win`.

Seat-winner log loss change, arm minus baseline (lower is better), floor 1e-6, SE clustered on election:

| scope | elections | seats | change | SE |
|---|--:|--:|--:|--:|
| 1. primary: 24 untouched elections (named targets) | 24 | 2,267 | -0.0007 | 0.0011 |
| 2. guard: all seats | 35 | 2,931 | +0.0001 | 0.0010 |
| (b) primary without Ipswich West, Morwell, Kalamunda | 24 | 2,264 | +0.0001 | 0.0011 |
| (c) the 11 refilled elections | 11 | 664 | +0.0026 | 0.0014 |
| AEF-7 (reported) | 7 | 681 | -0.0006 | 0.0020 |

1. Primary: within 1 SE, so it does NOT pass.
2. Guard: PASS.
3. Leave-one-election-out: FAIL (better by more than 1 SE in 1 of 24 drops).
4. No election worse by more than 2 SE of its own seats: FAIL. vic2010 is +0.0155 (own SE 0.0053, z 2.90).
   nsw2023 (z 1.96) and nsw2015 (z 1.86) are close behind.
5. Without the two largest-gain seats (fed2010 Ryan, qld2024 Ipswich West), the sign is lost (+0.0002): FAIL.
(a) Floor: the result at the 1e-4 floor is the same to 4 decimals, so this is not a floor artefact.
(b) Unacceptable win: the whole primary gain is the three 21 Oct upsets. Ipswich West 0.021 -> 0.054, Morwell
    0.032 -> 0.059, Kalamunda 0.072 -> 0.095. With those three removed the change is +0.0001.
(c) The 11 refilled elections are worse by +0.0026 (1.9 SE). That is under the 2 SE bar, but it points the wrong way.
Reported: AEF-7 absolute log loss is 0.2652 for the baseline and 0.2646 for the arm (AEF 0.2825). Primary-vote RMSE over
all 19,616 cells is 4.1127 for the baseline and 4.1259 for the arm (worse).

**Verdict: REFUSED.** The primary is not better by more than 1 SE, and clauses 3, 4 and 5 fail. The gain that does
appear is the three long-shot upsets, which is exactly what clause (b) names as unacceptable. No clause refused a
headline-positive result, so nothing needs a decision from Pete under rule 9. `AUSPOL_TRAIN_DECAY_H` stays at 8. The
copy `C:\dev\auspol-iso-decay4` (16 GB) can be deleted; it was left in place, since agents do not delete.
