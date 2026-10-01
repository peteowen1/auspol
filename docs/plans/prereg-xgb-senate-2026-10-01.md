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

## RESULT (full coverage, 98.8%), 2026-10-01 14:55 -- passes as written, NOT shipped

`output/snapshots/20261001-1449-d4b2f74-from3` against v56. OTH_RIGHT 3.708 ->
3.506, GRN 2.676 -> 2.619, OTH 2.239 -> 2.011, ONP 3.212 -> 3.030; ALP 5.200 ->
5.296, LNP 5.431 -> 5.460; all rows 4.1617 -> 4.1206. Seat log loss, 22
elections, -0.0007 (SE 0.0049, better in 9). Ledger 0.2741 -> 0.2716. The
elections that gained coverage: 5.141 -> 5.069. Every clause passes.

But Victoria, the live target, got worse: seat log loss +0.0323 over 239
seats (SE 0.0126, 2.6 SE), every Victorian election worse; Victorian Labor
primary RMSE 5.23 -> 5.89 (Northcote, Richmond, Hawthorn) while its Greens,
Other and minor-right errors fell. That was not a pre-registered condition,
and it is exactly the shape the first check predicted: no Senate signal for
Labor or the Coalition, so their Senate shares add noise. Pete's call: test
the minor parties only.

## Arm "minor" (`AUSPOL_XGB_SENATE = "minor"`), registered 2026-10-01 15:00 before running

Same features, NA for ALP/LNP/NAT rows. Same criteria, PLUS: Victoria's seat
log loss (239 seats, three elections) must not be worse than v56's by more
than one SE clustered on seat. Ships only if all hold.

## RESULT, arm "minor", 2026-10-01 15:35: REFUSED

`output/snapshots/20261001-1525-eaf85f1-from3`. Victoria guard passes (+0.0037,
SE 0.0059, 0.6 SE) but the primary criterion fails: GRN 2.676 -> 2.682,
OTH_RIGHT 3.708 -> 3.691; all-rows RMSE 4.1617 -> 4.1765 (worse); ledger 0.2741
-> 0.2759. Blanking the majors removed the minor-party gains and still moved
the majors (Victorian LNP 5.30 -> 5.81) through the row renormalisation. Neither
arm ships; AUSPOL_XGB_SENATE stays "0".

Not yet tried, and the obvious next candidate: `senate_dev` alone for every
class (the geography net of the state level). The full arm's Victorian Labor
damage plausibly comes from `senate_pct`, the raw level, since Victorian Labor
runs far ahead of its Senate vote at state elections. Three arms on the same
backtests is a garden of forking paths: a fourth must be pre-registered with
the Victoria guard and judged by the same bar, and its result reported as the
third attempt, not the first.
