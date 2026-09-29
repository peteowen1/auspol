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
