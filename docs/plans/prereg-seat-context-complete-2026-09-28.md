# Pre-registration: complete the seat-context features for every training election

Written 2026-09-28, before building. Pete's rule (same day): incomplete data
gets COMPLETED, not routed around.

## The gap

`output/xgb-primary-v6-features.csv`: on 13 of 22 training pairs (every
federal pair to 2016, qld2020, vic2014, vic2018, wa2001-wa2017) these are
100% missing, because they come from the anchor's seat files, which cover
recent elections only: `is_incumbent_party_i`, `retirement_i`,
`soph_cand_i`, `soph_party_i`, `margin`, `prev_swing` (and `fed_swing` on
state pairs). 1,626 of 3,528 major-party rows have no incumbent party.

## The build (`scripts/build_seat_context.R` -> `output/seat-context.csv`)

Per pair and seat, from our own corpus (CLAUDE.md: one source of truth,
`classify_party()` over primary data, never a field someone else classified):
- sitting member and incumbent class: the previous election's winner in the
  seat (`elected`, else highest primary), replaced by a by-election winner
  from `external/reference/byelections/` where one intervened; seats matched
  by `normalise_seat()`;
- retiring: the sitting member is in `external/reference/retirements/retirements.csv`
  for this election (reason kept);
- first-term member standing (`soph_cand`) / first-term party (`soph_party`):
  the seat changed hands at the previous election;
- margin and previous swing: from two-candidate results where held, else the
  first-preference lead, with a column saying which.

## Validation, before any use

On the 9 pairs where the seat file has values, agreement between the seat
file and the rebuilt value must be at least 95% for incumbent class and
retiring, and the margin correlation at least 0.9; every disagreement is
listed. Then the features are FILLED where missing only (existing values
untouched), behind `AUSPOL_SEAT_CONTEXT_FILL=1`.

## Criterion

Rebuild against v45: seat log loss (ledger, 0.2815) and the all-22 pooled
(0.3193) reported; ships if the all-22 pooled does not rise (the 13 filled
pairs are older, so the pooled number is the primary measure here).
