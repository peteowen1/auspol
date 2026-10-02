# Pre-registration: fuller council history (`AUSPOL_COUNCIL_EXTRA = "1"`)

Registered 2026-10-02 before any rebuild with it on.

## Why
Two of the largest remaining independent misses had a local profile our
council data could not see: Dai Le (Fowler 2022; Fairfield councillor and
deputy mayor) because Fairfield runs its own elections, and Michael Regan
(Wakehurst 2023; Northern Beaches mayor) because councillors chose him, so he
was recorded as a councillor only.

## Data
- external/reference/council/nsw-self-run.csv: 24 NSW council-years that ran
  their own elections (2012: 15, 2016: 5, 2017: 1, 2021: 2, 2024: 2), 1,451
  rows; 23 with full first preferences, Liverpool 2024 elected-only. Group
  ticket votes are on the first-listed candidate in some sources and excluded
  in others (affects council_pct, not elected/mayor flags).
- external/reference/council/mayors.csv: 858 council-chosen mayor terms (Vic
  68 of 79 councils, 578 terms; NSW 30 councils; WA 38), 725 verified.
A mayor term counts if it began in a year BEFORE the election year, within 10
years, in a council overlapping the seat (5% either way), same as results.

## Dry run (council history, v59 vs this)
70 candidacies gain a council record from the NSW additions; 74 newly count as
mayor. Dai Le fed2022: no record -> elected councillor (27.3%, 2021). Regan
nsw2023: councillor -> mayor.

## Criteria (rebuild from stage 3 against v60)
1. PRIMARY: primary RMSE on the rows whose council features changed improves
   by more than 1 SE (seat-clustered).
2. GUARD: 22-election log loss not worse by more than 0.0020.
3. GUARD: Victoria seat log loss not worse by more than 0.0018.
4. GUARD: all-row primary RMSE not worse by more than 0.01.
UNACCEPTABLE: the changed rows improve while the rest get worse by more than
guard 4 allows.
Then the live forecast with and without (Victoria; which candidates gain a
mayor flag).

## RESULT, 2026-10-03 00:15: FAILS
`output/snapshots/20261003-0013-74b088e-from3` against v60 (config-identical
`-2212-579df5c-from6`). 1. Changed rows (117, 94 seats): per-seat squared-error
change -1.56 (SE 2.02) -- under 1 SE, FAIL. 2. 22-election 0.3434 -> 0.3458,
FAIL. 3. Victoria 0.2654 -> 0.2678, FAIL. 4. all-row RMSE 4.0438 -> 4.0402.
Ledger 0.2686 -> 0.2681. Dai Le fed2022 10.7 -> 12.2 (actual 29.5); Regan
nsw2023 10.1 -> 11.2 (35.9). Not shipped; both data files stay as reference.
Note: former mayors are also among the largest OVERCALLS (Pascoe Vale 2022
18.0 vs 4.2, Geelong 2022 14.9 vs 3.2) -- local profile does not separate
winners from also-rans on its own.
