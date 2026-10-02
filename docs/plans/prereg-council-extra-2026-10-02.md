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
