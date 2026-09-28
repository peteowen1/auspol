# Pre-registration: a sitting-member adjustment in the baseline (base_pred)

Written 2026-09-28, before running. Pete: "target-seat signals"; CLAUDE.md:
a primary-vote fix must reach base_pred, not only the xgb layer (the xgb
version, rebuild D, barely moved its targets).

## Evidence (v45 outputs, major-party rows, actual minus base_pred)

incumbent party, member stands again +1.77 (SE 0.20, 705 seats);
incumbent party, member gone -0.71 (SE 0.46, 187); challenger major, member
gone +1.22 (SE 0.41, 187); challenger, member stands +0.39 (SE 0.17, 823).
Measured before the seat context was completed; the fit uses the completed
flags (v46), so every training election contributes.

## The change (`AUSPOL_SITTING_MEMBER_ADJ=1`)

An additive shift to `base_pred` for ALP/LNP rows in three groups: incumbent
party with its member standing again, incumbent party whose member is gone,
the other major in a seat whose member is gone. For each target election the
shift per group is fitted ONLY on earlier elections (`elections_before()`),
as the mean residual `actual - base_pred`, shrunk toward 0 by its precision
measured ACROSS ELECTIONS (seats within one election share a swing, so the
standard error comes from per-election means, not seats):

    m  = mean of per-election mean residuals, se = sd / sqrt(n_elections)
    shift = m * m^2 / (m^2 + se^2)          (0 with fewer than 3 earlier elections)

Applied in `scripts/fit_xgb_primary_v6.R` (the feature table: as-at and
production models read it, so every backtest gets it) and in live
`xgb_primary_predict_live()` for vic2026 (fitted on all earlier elections,
coefficients written to `output/sitting-member-shift.csv`). `base_pred_raw`
keeps the unadjusted value.

## Criterion

Rebuild against v46: seat log loss on the ledger (0.2822) AND all elections
(0.3193, stage-9 pooled; 0.2987 over forecasts-seats.csv): ships if neither
rises by more than its noise and at least one falls; weighted primary RMSE
reported. Named targets: the four residual groups above move toward 0 in
the FINAL predictions, and Parramatta / Monaro / Camden Labor move toward
actual.

**Unacceptable**: a shift fitted on its own or a later election (each pair
prints n and the latest election used).
