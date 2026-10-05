# Pre-registration: two arms, cross-seat personal vote and the WA swing nudge (2026-10-05)

Committed BEFORE either arm runs, with `scripts/score_arm.R`. Baseline for both: the shipped rebuild
`output/snapshots/20261005-2142-f35d761-from1`. Each arm is one full rebuild (`AUSPOL_PUBLISH` unset)
on `dev` at the commit adding this file, scored against the baseline. One change per arm.

## Arm A: cross-seat personal vote (`AUSPOL_CROSS_SEAT_VOTE=1`)

Pete (2026-10-05): a PERSONAL vote earned in another seat or jurisdiction follows the person: won as
an independent, or by a sitting non-major member or by-election winner; party-label votes stay with
the party (`R/cross_seat_vote.R`). Credit = carry x best qualifying prior, carry fitted time-forward on
the same population (0.40-0.49), shrunk toward the same-seat returning ratio. Ambiguous matches are
refused (2 refused). Smoke (base_pred, all federal pairs, switch on vs off, same code): 151 of 7,357
cells move; federal squared error -1,707 (fed2016 -561, fed2022 -724, fed2025 -429, fed2019 +9);
Fowler IND 2.2 -> 13.3 (actual 29.5), Cowper IND 4.9 -> 11.7 (29.6), Fremantle 2025 IND 2.9 -> 12.6 (23.0).

Score: `Rscript scripts/score_arm.R <baseline> <armA> 0.5 all`.

1. PRIMARY (SA2): squared error of xgb_pred on cells whose base_pred moved > 0.5 points must fall by
   more than 2 SE AND by at least 10%. Dry run on the by-election arm: 37 cells, -67%, PASS; on two
   identical snapshots it stops (no vacuous pass).
2. GUARD (SA3): ledger seat log loss may rise by at most 1 SE (clustered on pair).
3. GUARD (SA4): whole-table squared error may rise by at most 1 SE (clustered on election).
4. Named in advance: fed2019 is flat in the smoke (+9); Horan (Riverstone nsw2023, possibly a
   different person) is credited; the source seat's class base is not reduced when a candidate moves
   (Bedford, Florey). A primary that passes only through fed2022 Fowler is reported as such.

## Arm B: WA in the seat-swing nudge, shrunk per state, no cliff (`AUSPOL_SEAT_SWING_PORT_WA=3`, `AUSPOL_SEAT_SWING_PORT_NOCLIFF=1`)

Pete (2026-10-05): WA gets the nudge, with each state's coefficient shrunk toward the all-state pool,
and a weak signal shrunk rather than cut off. Built: booth-to-district maps for wa2013 (approximate,
2007 boundaries with renames) and wa2021; wa2008, wa2017, wa2025 existed. Dry run: between-state
variance is 0 for every target, so every state gets the pooled coefficient, WA's weaker own fit
(~0.16-0.21) pulls the pool down: vic2026 (LIVE) 0.436 -> 0.374, nsw2023 0.392 -> 0.332, qld2024
0.423 -> 0.364, sa2026 0.423 -> 0.362, wa2025 0 (not applied) -> 0.369; the no-cliff rule gives
vic2018 0, nsw2019 0.002, qld2020 0.080. CLAUDE.md: when between-group variance is barely
estimable, shrinkage under-separates groups, so the OUTCOME decides.

Score: `Rscript scripts/score_arm.R <baseline> <armB> 0.5 wa` (WA) and `... 0.5 vic,nsw,qld,sa`.

1. PRIMARY (SA5, WA): mean seat-winner log loss over the WA elections the nudge reaches (wa2013,
   wa2017, wa2025) must fall by more than 0.010 per seat AND by more than 1 SE. The 0.010 is the noise
   floor measured in the dry run: an arm that never touched WA moved wa2017 by -0.0114 and wa2013 by
   +0.0069 through xgb retraining alone.
2. GUARD (SA5, other states): mean seat-winner log loss over vic, nsw, qld, sa may rise by at most 1 SE
   (their coefficients fall by ~0.06).
3. GUARD (SA3 ledger, SA4 whole table): at most +1 SE each.
4. Named in advance: the live Victorian coefficient falls 0.436 -> 0.374 under this arm. If the WA
   primary passes but the other-state guard is breached, the split goes to Pete (WA-only application
   is the fallback: mode 2).

Decision: an arm ships only if its primary passes and its guards hold; otherwise the switch stays off
and the result goes to Pete. Amendments are visible additions below.

## Arm A result (2026-10-05, `output/snapshots/20261005-2339-2424e08-from1`, 43 min) -- REFUSED, to Pete

| Criterion | Result | Verdict |
|---|---|---|
| 1 PRIMARY (99 cells whose base_pred moved, 13 elections) | 4,306.7 -> 4,000.7 (-7%), SE 623.3 | FAIL |
| 2 GUARD ledger | 0.2827 -> 0.2834 (SE 0.0016) | holds |
| 3 GUARD whole table | RMSE 3.810 -> 3.811 (SE 0.109) | holds |

Federal cells improved (fed2016 -494, fed2022 -451, fed2025 -121: Fowler IND 5.2 -> 13.6 vs 29.5,
Cowper IND 6.9 -> 13.9 vs 29.6, Fremantle 2025 IND 14.1 -> 22.8 vs 23.0). The credit LOWERED two
classes it should have left alone: sa2022 Stuart IND (Brock) 25.0 -> 18.2 (actual 48.5; +535) and
wa2017 Baldivis IND 10.5 -> 7.2 (23.9). The credit (carry x prior = 22.4 for Brock) REPLACES the class
base, so where the class already had more, the arm took it away. Seat log loss over 22 elections
0.2903 -> 0.2918. The switch stays off. Cost: stages 1, 3 and 6 ran about twice as long, because the
carry is refitted on every personal_prior_vote() call.
