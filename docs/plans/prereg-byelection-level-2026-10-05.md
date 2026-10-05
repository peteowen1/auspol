# Pre-registration: by-election winners get a sitting-member level; the major that lost keeps its departed flag (2026-10-05)

Committed BEFORE the arm runs, with `scripts/score_byelection_level.R`.

## Why

Pete chose both (2026-10-05, quiz): a NON-MAJOR by-election winner is credited "the level a sitting
non-major member typically holds", not nothing and not the by-election share; and a major that lost
the seat at a by-election keeps its 'member departed' flag. Lyne 2010 (Oakeshott, 9.0 vs 47.8) and
Orange 2019 (Donato, 16.4 vs 56.2) are the two worst rows in the table. Measurement:
`docs/reviews/byelection-level-2026-10-05.md` (five winners: RMSE 24.1 today, 6.9 with a flat level
of about 41, 16.5 with the by-election share; the departed effect is 2.2 points, SE 2.7, n = 11, not
separable on its own).

## The change (two switches, one arm)

- `AUSPOL_BYELEC_LEVEL=1`: `personal_prior_vote()` adds each non-major by-election winner with
  `own_prev_pcv` = `fit_sitting_minor_level()` = the median next-election share of members elected in
  a non-major class who stood again in the same seat, over pairs strictly before the target.
  Dry run: fed2010 41.6 (n = 8), nsw2019 39.5 (n = 17), fed2019 39.9 (n = 19).
- `AUSPOL_BYELEC_DEPARTED=1`: `candidate_returns()` keeps `had_mp` for a major that held the seat at
  the general election and lost it at the by-election, so `mp_departed` fires. Dry run: Orange, Wagga
  Wagga (nsw2019) and Lyne (fed2010) LNP FALSE -> TRUE.

Both reach base_pred, and through the stage-3/4 rebuild the xgb layer. Victoria 2026: vic2022 -> vic2026
by-elections (if any) are affected the same way; the live diff is reported with the result.

## How it runs

One full rebuild, both switches exported, `AUSPOL_PUBLISH` unset, on `dev` at the commit adding this
file. Baseline: `output/snapshots/20261005-1825-28d4602-from1` (the shipped configuration with the
federal defector carry). Scored with `Rscript scripts/score_byelection_level.R <baseline> <arm>`.

## Target cells (from the scorer's dry run)

- A, the winners (primary): fed2010 Lyne IND, fed2019 Mayo IND, fed2019 Wentworth IND, nsw2019 Orange
  OTH_RIGHT, nsw2019 Wagga Wagga IND.
- B, the majors that lost the seat (secondary): fed2010 Lyne LNP, fed2019 Wentworth LNP, fed2025 Aston
  LNP, nsw2019 Orange LNP, nsw2019 Wagga Wagga LNP, nsw2023 Bega LNP, qld2024 Ipswich West ALP,
  sa2026 Black LNP, sa2026 Dunstan LNP.

## Criteria (in order)

1. PRIMARY (A): summed squared error must fall by more than 2 SE AND by at least 20% of the baseline.
   (Dry run on two snapshots that never touched these cells: -115, SE 78, 3% of 3,627: a 1-SE bar
   passed on noise, so the bar is set here, before the arm.)
2. SECONDARY (B): must not get worse by more than 1 SE.
3. GUARD ledger seat log loss: increase at most 1 SE (clustered on pair).
4. GUARD whole-table primary squared error: increase at most 1 SE (clustered on election).
5. DISQUALIFIER: a winner in A who won again (Lyne, Mayo, Orange, Wagga Wagga in the dry run) loses
   more than 0.05 win probability. No winners found = UNVERIFIABLE = fires.

Ship both switches if 1 passes and 2-5 hold. If 1 passes but 2 is breached, ship
`AUSPOL_BYELEC_LEVEL` only and take the departed split to Pete. Otherwise both stay off and the split
goes to Pete. Amendments are visible additions below; nothing above is edited after the run.

## Named in advance

- Mayo 2019: Sharkie already has a general-election record (2016), so the max() keeps the larger of
  her own record and the level; her row should move little. Wentworth: Phelps lost in 2019, so a
  higher level over-calls her (actual 33.0); this is the expected cost.
- Lyne 2010 was skipped by the existing by-election baseline because Labor did not stand; this arm
  does not touch that baseline, only the personal vote.

## Result (2026-10-05, arm `output/snapshots/20261005-2023-2bc7581-from1` vs `20261005-1825-28d4602-from1`) -- primary FAILS by its 2-SE clause; to Pete

| Criterion | Result | Verdict |
|---|---|---|
| 1 PRIMARY (A, 5 winners) | 3,512.1 -> 982.6 (-72%), change -2,529.5, SE 1,318.5 = 1.92 SE | FAIL (2 SE needed; the 20% part passes) |
| 2 SECONDARY (B, 9 majors that lost) | 805.5 -> 342.6 (-57%), SE 348.0 | holds |
| 3 GUARD ledger log loss | 0.2827 -> 0.2822 (SE 0.0013) | holds (AEF 0.2825) |
| 4 GUARD whole-table | RMSE 3.832 -> 3.819 (SE 0.238) | holds |
| 5 DISQUALIFIER | Lyne 0.000 -> 0.792, Mayo 0.882 -> 0.951, Orange 0.008 -> 0.758, Wagga Wagga 0.394 -> 0.947 | does not fire |

Cells: Lyne 9.0 -> 32.1 (47.8); Orange 17.5 -> 33.8 (56.2); Wagga Wagga 26.5 -> 35.6 (46.1); Wentworth
23.9 -> 39.1 (33.0, the named cost); Mayo 40.6 -> 43.6 (34.2). Arm logged `BYL1`/`BYD1` in stage 1
(Lyne 41.6). By the rules both switches stay off; the 2-SE clause was added after the scorer's noise
dry run (-3%), and this arm is -72% at 1.92 SE, so the decision goes to Pete.
