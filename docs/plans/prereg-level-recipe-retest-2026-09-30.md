# Pre-registration: poll trend alone vs fundamentals-anchored level, retested leak-free

Written 2026-09-30 08:45, before either rebuild. Retest of
`prereg-level-recipe-2026-09-28.md`, which kept "anchored" (0.2943 vs "live"
0.2966) on 28 Sep, BEFORE the statewide fundamentals and mix were made
time-forward (v51). Pete, walking Parramatta: the last four NSW polls averaged
Labor 36.8 (actual 37.0); our statewide Labor was 32.7 after anchoring the
primaries to a two-party projection that gives the fundamentals 20% weight.

## Why a retest is owed

- The anchoring moved NSW 2023 Labor 35.3 -> 32.7 and the Coalition 33.5 ->
  36.1 (`statewide_draws_as_at()`, with and without `tpp_target`).
- The time-forward mix for nsw2023 at 1 day out: held-out error with the
  fundamentals 1.69, poll trend alone 1.67 (31 earlier elections). The
  fundamentals weight earns nothing on the eve of an election.
- The 28 Sep choice was measured with leaked fundamentals.

## Arms (both FULL rebuilds: the level feeds stage-1 `base_pred`)

- **Y2 (baseline):** v52 as published config (demographic correction and
  leader-seat bonus on), no environment.
- **Z:** Y2 plus `AUSPOL_LEVEL_RECIPE=live` (trend endpoints rescaled to 100,
  not anchored to the projection).

## Decision rule

1. **Primary: pooled seat log loss** over all matched elections
   (`compare_rebuilds.R` CR2 per-election mean) improves.
2. **And primary-vote RMSE** over all rows improves.
3. **Guard:** AEF-7 ledger seat log loss does not worsen by more than 0.003.
4. Reported: statewide majors' miss per election (Labor, Coalition), nsw2023
   Parramatta, per-election table.

Z ships if 1-3 hold; otherwise anchoring stays and the finding is recorded.
Not tested here and queued: anchoring only at horizons where the blend beats
the trend (7+ days), which matters for the live forecast before election day.

## AMENDMENT (2026-09-30 08:55, after Y2 launched and before its stage 3; the text above is unedited)

A second leak, found tracing step 3 of the nsw2023 Labor level (32.7
statewide, 31.3 in the seat model): `output/level-pred.csv`, the `level_pred`
xgb feature, was built by `scripts/build_level_pred.R` on LEAVE-ONE-OUT
fundamentals and the all-elections mix, last on 13 Sep, and is not in the
rebuild pipeline, so v51's time-forward fix never reached it. Rebuilt
time-forward at 08:53 (before Y2's stage 3 reads it). Leak-free it is also
more accurate: mean |level - actual| 2.06 -> 1.90 over 160 cells (majors 2.92
-> 2.71); nsw2023 Labor 31.3 -> 32.7.

So **Y2 = v52 config + this leak fix**, and ships whatever it scores, as
every leak fix has. After Y2, `build_level_pred.R` joins the rebuild pipeline
before stage 3, so arm Z builds its level under its own recipe. The Y2-vs-Z
rule above is unchanged.

## RESULT, Y2 (full rebuild 08:46-09:12, stage-6 files in output/rebuild-Y2/sharedetail/) = v52

Against fresh v51 (R2): primary RMSE all rows 4.2065 -> 4.1924 (MSE -0.119,
clustered SE 0.073); pooled seat log loss per-election mean -0.0010 (SE
0.0047, better in 7 of 16); AEF-7 ledger 0.2753 -> 0.2726; TCP MAE 3.80 ->
3.75; accuracy 88.2% -> 88.9%; leader seats 5.41 -> 4.97. Large moves both
ways from the retrained as-at models (fed2013 -0.030, vic2018 +0.051,
fed2025 +0.019). Ships as v52 (leak fix). Note for scoring full rebuilds:
stage 1 writes share-detail files with the same git tag as stage 6; score only
files written after stage 6 starts.

## RESULT, Z vs Y2 (full rebuild 09:13-09:32; stage-6 files in output/rebuild-Z/sharedetail/)

**Refused on the primary.** Pooled seat log loss per-election mean +0.0003
(SE 0.0091), 0.3411 -> 0.3430, better in 7 of 16: fails "must improve".
Primary RMSE 4.1924 -> 4.1653 (passes); AEF-7 ledger 0.2726 -> 0.2672 (guard
passes). Anchoring stays.

The split is by era: Z better in wa2017 (-0.110), fed2019 (-0.041), vic2018
(-0.015), wa2025 (-0.011) and the seven ledger elections together; worse in
fed2007 (+0.031), wa2008 (+0.050), wa2013 (+0.029), wa2005 (+0.023), fed2016
(+0.019), fed2013 (+0.018). Statewide level error, majors 2.71 -> 2.65;
nsw2023 Labor 32.7 -> 36.1 (actual 37.0). A rule choosing by era would be
chosen after seeing this, so it is not proposed.

Caveat: "live" bundles two changes (no anchor AND proportional rescale to
100), so this did not isolate the anchor. Queued: a new prereg for the anchor
alone.

## CORRECTION, 2026-09-30 20:40: Z PASSES criterion 1 over all 22 elections (the result above is left unedited)

Criterion 1 asked for pooled seat log loss "over all matched elections". The
tool used, `compare_rebuilds.R`, read `forecasts-seats.csv`, which until
20:10 today held NO NSW, Queensland or SA seats (their allprobs files carry
no `pair` column and `build_forecasts_table.R` dropped them silently). So the
+0.0003 above is over 16 of 22 elections.

Rescored from Y2's and Z's own stage-6 allprobs files, still in `output/`
(tags `ga91e234x`, `g631395a`; reduced-sims stage-1 files excluded; wa2021
skipped as the rebuild does). 2,059 seat-elections, 22 elections. Seat log
loss, lower is better, d = Z - Y2:

| elections | per-election mean d | SE | Z better in |
|---|---|---|---|
| the 16 the old table held | +0.0003 | | (reproduces the figure above exactly) |
| **all 22** | **-0.0031** | 0.0067 | **13 of 22** |
| the 6 that were missing | nsw2019 -0.0009, nsw2023 -0.0269, qld2020 -0.0120, qld2024 -0.0074, sa2022 -0.0039, sa2026 -0.0218 | | 6 of 6 |

Seat-weighted 0.3617 -> 0.3605. Criterion 2 (primary RMSE 4.1924 -> 4.1653)
and the ledger guard (0.2726 -> 0.2672) passed as recorded. **Z passes every
clause as written.** The era split above still holds within the federal and
WA elections.

What this does NOT do: ship Z. It was measured against v52; v53-v55 changed
the corrections on top. The live forecast already uses this recipe for its
level (`R/forecast_mode.R:173`), so the backtests score a different recipe
from what ships. Next: a full rebuild of v55 with `AUSPOL_LEVEL_RECIPE=live`,
same criteria, all 22 elections.

## RESULT ON v55, 2026-09-30 21:20: PASSES, ships as v56

Full rebuild with `AUSPOL_LEVEL_RECIPE=live`
(`output/snapshots/20260930-2115-72387b7-from1`) against v55 (stages 1-5 from
`20260930-1607-33a848a-from1`, stage 6-8 `20260930-1807-3c1a1db-from6`).
Scored from each run's own stage-6 allprobs, all 22 elections, 2,059
seat-elections (the scorer refuses fewer than 22).

| criterion (lower is better) | v55 | live | |
|---|---|---|---|
| 1. seat log loss, per-election mean change | | **-0.0024** (SE 0.0071) | better in 12 of 22; seat-weighted 0.3642 -> 0.3627 |
| 2. primary RMSE, all 11,643 rows (points) | 4.2111 | **4.1617** | |
| guard: ledger seat log loss (AEF 0.2851) | 0.2761 | 0.2741 | |
| reported: ledger weighted primary RMSE | 4.926 | 4.953 | slightly worse |
| reported: ledger accuracy | 88.94% | 88.64% | |

Same era split as Z: better fed2010 -0.032, fed2019 -0.036, nsw2023 -0.026,
vic2018 -0.019, wa2017 -0.110, wa2025 -0.023, and all four Qld/SA pairs;
worse fed2007 +0.031, fed2013 +0.025, wa2008 +0.050, wa2013 +0.043, wa2005
+0.023, fed2025 +0.020, nsw2019 +0.014. **Passes both criteria and the
guard.** `AUSPOL_LEVEL_RECIPE = "live"` in `published_flags.R`, so the
backtests now score the recipe the live forecast uses.

**Amendment, 21:50 (a visible addition; the result above is unedited).** The
review gate found that the live forecast has anchored its level since
2026-09-28 (`AUSPOL_LIVE_LEVEL_ANCHOR = "1"`, `fit_seats_full.R` LL1), so
"live" in the backtests alone would score a level the live forecast does not
use. Parity needs `AUSPOL_LIVE_LEVEL_ANCHOR = "0"` with it. Live effect,
`fit_seats_full.R` twice with `AUSPOL_OUT_SUFFIX` (20,000 sims each, polls to
2026-09-09): statewide two-party 47.93 anchored -> 48.90 un-anchored (Labor
first preference +0.97). Expected seats ALP 31.2 -> 34.7, Coalition 36.1 ->
34.3; P(Labor more seats than the Coalition) 0.39 -> 0.53; Labor majority
0.05 -> 0.11, Coalition majority 0.18 -> 0.12. HELD for Pete's decision.
