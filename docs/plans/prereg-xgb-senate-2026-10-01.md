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

## Interim result (84.4% coverage), 2026-10-01 13:45 -- the text above is unedited

Rebuild `output/snapshots/20261001-1340-f0af798-from3` against v56. Primary
RMSE, xgb layer (points, lower is better): OTH_RIGHT 3.708 -> 3.611, GRN 2.676
-> 2.642, OTH 2.239 -> 2.105, ALP 5.200 -> 5.241, all rows 4.1617 -> 4.1370.
Seat log loss, 22 elections: -0.0023 (SE 0.0021, better in 11). Ledger 0.2741
-> 0.2712, weighted primary RMSE 4.953 -> 4.806. The four no-Senate elections
were not worse (5.141 -> 5.122). Passes every clause as written.

## Amendment (visible addition): the deciding run uses 98.8% coverage

Found DURING this run, by searching other sources at Pete's request: 2004
Senate booths (old AEC results site), 1998 Senate booths (AEC statistics
archive), and WA 2001/2005/2013 booth -> district maps by venue name
(scripts/build_wa_name_maps.py, validated 97.6-98.9% on wa2017/wa2025 true
maps). Coverage 84.4% -> 98.8%, every election covered. The deciding run is a
stage-3 rebuild with the full tables, SAME criteria and clause; the
unacceptable-win clause's "no-Senate elections" no longer exist, so it is
checked on the elections that gained coverage instead (fed2007, wa2001,
wa2005, wa2013): they must not get worse by more than one SE.
