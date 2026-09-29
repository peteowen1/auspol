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
