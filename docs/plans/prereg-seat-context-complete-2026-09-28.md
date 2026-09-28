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

## RESULT and AMENDMENT (2026-09-28; the text above is unedited)

Validation PASSED: incumbent class 98.9%, retiring 97.0% agreement over 971
seats where the seat file has values (disagreements: mid-term party
switchers, and the Shooters, which the seat file files as IND). First-term
flags agree 73-98% and were NOT filled. The fill reached 12 training pairs
(incumbent missing on major rows 46.1% -> 0.0%).

Rebuild F vs v45: all 16 elections in forecasts-seats.csv, 1,590 seats,
seat log loss 0.2984 -> 0.2987 (+0.0003; mean per-election change -0.0012,
SE 0.0027; better in 8, worse in 4, the 4 earliest unchanged). Ledger 0.2815
-> 0.2822. Weighted primary RMSE 4.978 -> 4.947, TCP MAE 3.86 -> 3.85.

**By the bar as written it fails (the pooled number rose by 0.0003).
AMENDMENT, stated as such: Pete chose to ship it** (2026-09-28) because it is
the correct data, it removes the "blank incumbent = older election" label the
trees could split on, the log-loss change is noise, and primary error
improves. Ships as ledger v46.
