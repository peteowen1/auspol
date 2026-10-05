# Departed-hold sweep: primary criterion passes, two guards fail (2026-10-05)

Pre-registration: `docs/plans/prereg-departed-hold-fixed-2026-10-04.md` (8910783).
Scored by `scripts/score_departed_hold_sweep.R` from `scripts/run_departed_hold_sweep.sh`.
16 pairs, five harnesses (fed 7, nsw 2, qld 2, sa 2, vic 3; WA not wired), each run three
ways: HEAD script (base), `AUSPOL_DEPARTED_HOLD=0` (off), `=1` (on), all at
`AUSPOL_XGB_PRIMARY=0` and `AUSPOL_N_SIMS=500` (exploratory size, not the 20,000 deciding
run). 48 runs, all exit 0. 2,872 held cells in 16 pairs. The retrained-xgb arm was NOT run.

## Verdict by clause (each pair is one observation; SE across 16 pairs)

| Clause | Result | Outcome |
|---|---|---|
| 4 Byte-identical where the decay did not fire | base vs off: 0 of 12,291 cells differ; changed cells in rows with no held cell: 0 | **PASS** |
| 1 Primary: mean abs error on held cells | -0.0532 points, SE 0.0256 (2.1 SE); better in 11 of 16 pairs | **PASS** |
| 2 All cells in held rows | -0.0021, SE 0.0068 (0.3 SE) | passes the letter ("must also fall"), indistinguishable from zero |
| 3a Pooled seat log loss | -0.0026, SE 0.0042; better in 6 of 16 pairs | **PASS** |
| 3b Actual-weighted share RMSE | **+0.0199, SE 0.0142 (1.4 SE worse)** | **FAIL** (must not rise by more than 1 SE) |
| Disqualifier: independent win probability falling where an independent won | 60 seats: mean 0.630 -> 0.622, fell in 22, rose in 18 | **FIRES** (net fall); almost all from sa2026 Mount Gambier (0.49 -> 0.20) and Kavel (0.96 -> 0.85); excluding those two the mean change is -0.0015 |
| Disqualifier: gain from New England and Lyne alone | those two are 19% of the total gain; the other 2,870 cells average +0.034 points better | does not fire |

## What moved

Held-cell mean absolute error, points, off -> on (lower is better): GRN 1.94 -> 1.86 (n 1,292),
IND 4.17 -> 4.03 (275), ONP 2.56 -> 2.57 (337), OTH_RIGHT 2.11 -> 2.12 (968). Flagships:
New England 2013 35.9 -> 21.2 (actual 20.4), Lyne 2013 24.0 -> 16.5 (actual 7.6).

The weighted-RMSE rise is a handful of big cells where the decayed class went on to
break out: Kennedy fed2013 OTH_RIGHT 25.8 -> 18.9 (actual 38.9), Mount Gambier sa2026 IND
24.8 -> 21.1 (37.6), Warringah fed2019 IND 7.9 -> 7.2 (44.7), Calare fed2007, Shepparton vic2014,
Cowper fed2022. Of 16 pairs the RMSE got worse in 11; sa2026 alone is -0.131 (better).
Without the single worst pair the mean change is still +0.0143.

## Reading

The mismatch is real (the walk) and holding the cell fixes it where the independent really did
fade (New England, Lyne, Waite, Kavel, Tamworth). But where a held class then BROKE OUT, the
old over-retention was accidentally right, and those few cells dominate an actual-share-weighted
measure and the win probabilities. The rule cannot tell a fading independent from one about to
break out; that is the endorsed-successor / campaign-signal gap named in the prereg.

By the prereg's own decision rule the switch stays off. This is a refusal on a headline-positive
primary result, so it goes to Pete (CLAUDE.md, pre-registration rules).

## Not done

Retrained-xgb arm; the deciding 20,000-simulation run; `fit_seats_full.R` (published script) was
wired and parses but not run; WA not wired.

## Arm B (post hoc, Amendment 1): hold only classes with prior seat share >= 15

Same 16 pairs, same settings, `AUSPOL_DEPARTED_HOLD_MIN_PRIOR=15`
(`scripts/run_departed_hold_sweep_armB.sh`, `ARM=onB` for the scorer). Exploratory by
construction: chosen after arm A's per-cell results on these same pairs.
86 held cells (0 to 28 per pair; fed2025 and sa2022 have none).

| Clause | Arm B result | Outcome |
|---|---|---|
| 4 Byte-identical elsewhere | 0 cells differ off vs base; 0 changed cells outside held rows | pass |
| 1 Primary: held-cell error, pair-clustered | -0.789 points, SE 0.968 over 14 pairs (0.8 SE) | **FAIL** (needs more than 1 SE). Pooled over cells it is 5.81 -> 5.26 (n 86) but a pair with one cell counts as much as a pair with 28 |
| 2 All cells in held rows | -0.139, SE 0.183 | passes the letter, no signal |
| 3a Seat log loss | +0.0008, SE 0.0011 | pass (0.7 SE) |
| 3b Weighted RMSE | -0.0052, SE 0.0050 (1.0 SE better) | pass |
| Disqualifier: IND win probability where IND won | mean 0.630 -> 0.624; fell in 2 seats, rose in 0 | **FIRES** (net fall): Mount Gambier sa2026 0.49 -> 0.22, Kavel sa2026 0.96 -> 0.87 |

What changed against arm A: the RMSE and log-loss damage is gone (the small-class breakouts such
as Kennedy are no longer held). What remains: New England and Lyne are 46% of the (now small)
total gain, so the "gain from two seats" disqualifier is close, and the primary clause cannot be
cleared with 86 cells.

Mount Gambier sa2026 is a genuine retirement (Troy Bell did not stand; Travis Fatchen, a new
independent, polled 27.1 first preferences against our held 21.1 and unheld 24.8): the successor
kept about 0.59 of Bell's 45.7. Same shape as the other retiring sitting independents, whose
successors kept 0.16 (Lyne), 0.33 (New England), 0.43 (Kavel), 0.59 (Mount Gambier). The 0.38
average holds but the spread is wide and nothing the model sees tells the cases apart.

By the prereg's rule arm B is also refused. Both arms stay off; the decision goes to Pete.
