# Pre-registration: sitting-member defector carry pooled by federal vs state (2026-10-05)

Committed BEFORE the arm runs, with its scoring script `scripts/score_defector_by_level.R`.
Rules followed: `docs/PRE-REGISTRATION-RULES.md`.

## Why

Pete asked (2026-10-05): *"model what performs best - is shrunk measure better than no carry? does
it matter based on who they are?"* `docs/reviews/defector-carry-2026-10-05.md` (18 cases, time-forward,
15 scored): no carry RMSE 23.2 (SE 3.7), one shrunk pooled carry 14.2 (2.4), shrunk by jurisdiction
12.6 (2.1). Federal members keep far less of their old vote (mean 0.23, n = 7) than state members
(0.56, n = 11). `fit_defector_discount()` fits ONE all-level median (0.30-0.44), too high federally and
too low for the states. Made visible by the leader-leak fix (`c0a3e85`): Dobell 2013 (Thomson) and
Monash 2025 (Broadbent) now lead their class and are over-carried.

## The change (one change)

`AUSPOL_DEFECT_BY_LEVEL=1`: in `fit_defector_discount()` (R/candidate_returns.R) the sitting-member
rate `discount_mp` is the target's level (federal, or any state) median, partially pooled toward the
all-level median, `w = tau^2 / (tau^2 + se^2)`, `se = 1.2533 sd / sqrt(n)`, `tau^2` the between-level
variance net of noise (0 when not separable, which returns the old pooled rate). Time-forward exactly
as before (`fit_pairs_for()`). Every caller (the six harnesses and `fit_seats_full.R`, through
`personal_prior_vote()` and the harnesses' own calls) reads this one function, so it reaches base_pred
AND, through the stage-3/4 rebuild, the xgb layer.

Dry run of the fitted rate per target (switch off -> on): fed2010 0.566 -> 0.566 (one earlier federal
case, not separable); fed2013 0.439 -> 0.230; fed2016 0.355 -> 0.178; fed2019 0.313 -> 0.201; fed2022
0.435 -> 0.211; fed2025 0.374 -> 0.160; states 0.27-0.44 -> 0.39-0.64 (wa2017 0.272 -> 0.622, sa2026
0.374 -> 0.541).

NOT in this arm (a separate later change, one change per round): wider uncertainty for defector rows
(the survivors Cregan, Ward, Ellis, Graham kept 30+ and no carry reaches them); the surname+initial
collision inside the model (Trevor vs Tony SMITH, Casey fed2022).

## How it runs

One full rebuild (`scripts/rebuild_forecasts.sh`, all stages, `AUSPOL_PUBLISH` unset, 20,000 sims)
with `AUSPOL_DEFECT_BY_LEVEL=1` exported, on `dev` at the commit that adds this file. Baseline: the
bug-fix rebuild `output/snapshots/20261005-1615-7d2b36c-from1` (same code, switch off). Scored with
`Rscript scripts/score_defector_by_level.R <baseline> <arm>`.

## Target cells (14)

A member elected for ALP/LNP/NAT at the previous election (by-election override applied) standing in
the same seat under another class; first names must agree in their first two letters. Listed by the
scorer's DL1 line: Ryan 2010, Dobell 2013, Tangney 2016, Hughes 2022, Calare 2025, Monash 2025,
Morwell vic2018, Kiama nsw2023, Kavel / Narungga / Waite sa2022, MacKillop sa2026, Whitsunday
qld2020, Hillarys wa2017.

## Criteria (decided in this order)

1. **PRIMARY** (scoped to the change): summed squared error of `xgb_pred` against actual on the 14
   target cells, paired. Passes if it falls by more than 1 SE (SE = sd of per-cell change x sqrt(n);
   unit = seat-election). Dry-run SE on the bug-fix comparison: about 196 on a total near 2,100.
2. **GUARD, seat log loss**: AEF-7 ledger (681 seats, 7 pairs), mean per-seat change, SE clustered on
   pair. Holds if the increase is at most 1 SE.
3. **GUARD, primary**: whole-table squared error (about 11,846 matched rows), mean change, SE clustered
   on election. Holds if the increase is at most 1 SE.
4. **DISQUALIFIER**: any defector who actually WON (dry run: Calare 2025, Kiama 2023, Kavel 2022,
   Narungga 2022, Morwell 2018) loses more than 0.05 win probability.

Decision: ship (`AUSPOL_DEFECT_BY_LEVEL = "1"` in `scripts/published_flags.R`) only if 1 passes, 2 and 3
hold, and 4 does not fire. Otherwise the switch stays off and the split goes to Pete, per "clause
refusals go to Pete". No criterion is changed after the run; any amendment is a visible addition below.

## What would make an apparent win unacceptable (named in advance)

- The primary passes only because of the federal cells while a state cell named above (Hillarys
  wa2017, MacKillop sa2026) gets more than 10 points worse: reported to Pete as a split, not shipped
  silently.
- Calare 2025 (Gee won, federal rate falls 0.374 -> 0.160): if his win probability falls past the
  disqualifier, the arm does not ship however good the primary is.
- The fed2010 rate is unchanged by construction (one earlier federal case); Ryan 2010 is not evidence
  either way.

## Power (MDE)

14 cells; the primary's SE is about 196 against an expected change of a few hundred (hand estimate:
Hughes about -280, Tangney -158, Kavel -180, Kiama -120, but Hillarys about +400 and MacKillop about
+370 at the state rate). The primary can come out within 1 SE either way; INCONCLUSIVE is a possible and
reportable outcome, and is not a refusal of the idea.

## Dry run of the scorer on a known answer

Scoring the pre-fix rebuild against the bug-fix rebuild (both known): DL3 reproduces the ledger's
0.2796 -> 0.2874 and reports BREACHED; DL4 reports the whole-table RMSE 3.909 -> 3.872 and HOLDS;
DL1 drops the Casey name clash and Speirs (not sitting). So each check fires on a case where it should.

## Result (2026-10-05, arm snapshot `output/snapshots/20261005-1756-986b89f-from1`) -- REFUSED by its criteria

Scored with the committed scorer against `output/snapshots/20261005-1615-7d2b36c-from1`. The arm
logged the dry-run rates (`DEF-L` lines in stage 1 and 6 logs, e.g. fed2013 0.230, wa2013 0.644).

| Criterion | Result | Verdict |
|---|---|---|
| 1 PRIMARY, 14 cells | 2,162.7 -> 2,207.0, change +44.3, SE 750.6 | FAIL (within 1 SE: inconclusive) |
| 2 GUARD ledger log loss | 0.2874 -> 0.2855, change -0.0019, clustered SE 0.0046 | holds |
| 3 GUARD whole-table | RMSE 3.848 -> 3.853, mean sq change +0.040, SE 0.149 | holds |
| 4 DISQUALIFIER | Calare fed2025 (Gee, won) 0.980 -> 0.899 | FIRES |

The split named in advance as unacceptable happened: all five federal cells improved (Hughes 25.1 ->
16.2 vs 7.4; Tangney 24.8 -> 15.6 vs 11.9; Dobell 23.1 -> 15.6 vs 12.2; Monash 34.1 -> 29.5 vs 27.3;
Calare 52.1 -> 45.7 vs 39.5), the state survivors improved (Kavel 28.4 -> 31.0 vs 50.5, win probability
0.80 -> 0.93; Kiama 25.9 -> 29.5 vs 38.8, 0.48 -> 0.76; Waite, Narungga), and three state cells got much
worse (Hillarys wa2017 21.7 -> 43.9 vs 20.1; MacKillop sa2026 26.7 -> 35.3 vs 14.8; Morwell vic2018
29.5 -> 37.5 vs 28.2). Cause of the state damage: the state rate for early targets is fitted from 3
cases (wa2017: est 0.693, se 0.152 from a 3-point sd, weight 0.83), so the shrinkage does not pull it
back; the se formula is overconfident at tiny n. Calare's disqualifier fired while Gee's primary moved
TOWARD his actual (13.6 over -> 6.2 over). Switch stays off; the split goes to Pete.
