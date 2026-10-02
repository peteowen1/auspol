# Pre-registration: every pollster's state crosstabs (`AUSPOL_STATE_POLL_EXTRA = "1"`)

Registered 2026-10-02 before any harness run with it on. Pete: "surely we have
state level polling for all the federal polls as well?"

## Change
scripts/build_state_deviation_features.R adds readings from
external/reference/polls/state-federal/state-federal-polls.csv (two-party,
fieldwork ending in the 90 days before polling day): a state-year the anchor
and Newspoll lack is ADDED (only Tasmania 2022 qualifies, 10 Roy Morgan
readings); a Newspoll-only state-year (fed2025 mainland) is REPLACED by the
mean over every pollster (10-23 readings each). Anchor years untouched.
Dry run (state_poll_dev): fed2022 tas 0 -> -0.11; fed2025 nsw 1.33 -> -0.63,
qld 0.80 -> -0.06, sa 1.78 -> -0.77, vic -0.83 -> -4.23, wa -0.25 -> -0.41.
The baseline builder reproduces the shipped features file byte for byte.

Federal-only by construction: only fed2022 and fed2025 cells change, and the
correction's coefficients for every federal pair are refitted from them.

## Criteria (federal harness, all 7 pairs, rebuild from stage 6 vs v59)
1. PRIMARY: federal pooled primary RMSE, fed2022 + fed2025 seats, improves by
   more than 0.031 (the single-seed RMSE range, plans/noise-floor).
2. GUARD: 22-election log loss not worse by more than 0.0020.
3. GUARD: no federal pair's seat log loss worse by more than 0.011.
UNACCEPTABLE: the gain comes from one state while the other states of the same
election get worse.
Expected: small. The Tasmanian row this was aimed at carries little, and
Braddon 2025 has no statewide Tasmanian reading at all.

## RESULT, arm 1, 2026-10-02 21:50: FAILS
`output/snapshots/20261002-2149-c49ee12-from6` against v59 (`-2028-d79df9c-from5`).
fed2025 seat log loss 0.3570 -> 0.4104, final primary RMSE 3.431 -> 3.741;
fed2022 0.2568 -> 0.2566; other pairs identical. 22-election 0.3440 -> 0.3464
(guard 2 FAILS); ledger 0.2712 -> 0.2829. Mechanism: a 90-day all-pollster
mean lags the late Labor move, so every 2025 state read low for Labor (mean
deviation +0.57 -> -1.22) and the correction lowered Labor everywhere.

## AMENDMENT A2 (added after arm 1's result; original clauses unedited)
`AUSPOL_STATE_POLL_EXTRA = "2"`: the same rows, then in EVERY federal year the
seat-weighted mean state deviation is subtracted, so the feature is relative
(one definition for the one coefficient). Same criteria 1-3 and the same
unacceptable clause, against v59. Flagged in advance: it was designed after
seeing arm 1 fail, and against what happened its correlation is lower than
the shipped feature's (0.552 over 31 state-years against 0.620 over 30).
