# Pre-registration: federal Senate geography as xgb features (`AUSPOL_XGB_SENATE=1`)

Written 2026-10-01, before the rebuild. Pete: "do we use senate results only for
ON - or have we tested usefulness for ALP/LNP/GRN and any others as well?"

## Evidence so far

Regressing v56's remaining primary error on each class's Senate deviation
(8 state elections, t clustered on election): Labor 0.8, Coalition -0.4,
Greens 1.9, minor right (OTH_RIGHT) 3.1, Other 2.5, Independents 1.0, One
Nation -0.3. In-sample, so an upper bound.

## The change

`senate_pct` and `senate_dev` per (pair, seat, party) as xgb features
(R/senate_features.R): state pairs from the federal election before them via
the booth maps (16 cycles, including new maps for qld2017, wa2008, wa2017,
wa2025, vic2014); federal pairs from the previous federal election's Senate
vote in the same-named division. Coverage 84.4% of 14,069 rows; NA for
fed2007, wa2001, wa2005, wa2013. Live vic2026 reads a shipped slice.

## Measurement

Rebuild from stage 3 (features, as-at models, production model, stage 6) on
top of v56 (`output/snapshots/20260930-2115-72387b7-from1`, stages 1-2
unchanged).

1. **Primary (targeted):** xgb-layer primary RMSE for OTH_RIGHT and GRN rows
   over all 22 elections, must fall; reported per class for all classes.
2. **Guard:** pooled seat log loss over 22 elections not worse by more than
   one SE clustered on election; primary RMSE over all rows not worse; ledger.
3. **Reported:** AEF-7 metrics; per-election seat log loss; WA and fed2007
   (the NA rows) separately, since a feature missing for a block of elections
   can act as a label for it.

Unacceptable-win clause: if the gain comes only from elections with Senate
data while the NA elections (wa2001, wa2005, wa2013, fed2007) get worse by
more than one SE, the feature is labelling jurisdictions, not adding
geography -- report it, do not ship it.
