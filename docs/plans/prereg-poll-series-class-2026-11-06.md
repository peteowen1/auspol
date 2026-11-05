# Pre-registration: statewide poll columns classified by full party name (`AUSPOL_POLL_SERIES_CLASS=name`)

Written 2026-11-06 12:50am, overnight (Pete asleep; decisions saved for the morning), before any screen of this switch.

## What it changes

`statewide_draws_as_at()` folds a fitted poll series that is not a simulation class into its class with
`classify_party(name = q, code = q)`, where `q` is the poll file's column code. By code alone KAP, UAP and FF classify as
OTH and SAB as OTH, so they are skipped and their share is dropped before the level is rescaled to 100; their
candidates are classified by full name as OTH_RIGHT (KAP, UAP, FF) and IND (SA-Best). `name` classifies the column by
the party's full name (`.POLL_SERIES_NAME`), so the statewide class level and the seats count a party in the same class.

Measured statewide level moves, day before polling day (`psc.R`, 6 Nov 12:47am; arm minus off, points):
sa2018 IND +21.25, ALP -7.93, LNP -9.05, GRN -2.14; qld2015 OTH_RIGHT +7.48, ALP -2.94, LNP -3.22; sa2010 OTH_RIGHT +3.08;
fed2019 OTH_RIGHT +2.85; fed2022 OTH_RIGHT +2.99; fed2025 OTH_RIGHT +1.79; qld2024 OTH_RIGHT +1.39. 14 other targets unchanged.
(qld2017 is unchanged because its Katter series ends before the newest poll and so never reaches the fold: the interaction
with `AUSPOL_STATEWIDE_ENDPOINT` is not tested here.)

## Known answer, stated before the screen

sa2018 actual: ALP 32.8, LNP 38.0, SA-Best 14.2, GRN 6.7 (approx., from the commission's totals). The current backtest gives
SA-Best's ~21 polled points to nobody and rescales the rest up, so its IND level is far below 14 and its majors above
their results; the arm should move IND toward 14 and the majors down. If the screen shows sa2018 WORSE on seats, look for
a second mechanism before reading it as "the fix hurts".

## Screen

`quick_arm.R "AUSPOL_POLL_SERIES_CLASS=name" --pairs=fed2019,fed2022,fed2025,sa2010,sa2018,qld2015,qld2024 --sims=1000`,
baseline the shipped configuration. Before reading numbers: PSC1 lines name each reclassified series, and the moved
pairs are exactly these seven.

- Primary: pooled seat-winner log loss over the seven, SE clustered on election.
- Reported: share squared error on moved cells; sa2018 and qld2015 separately.

## Decision rule (standard rule)

- Better by more than 1 SE: recommend shipping (with a level-pred rebuild and tree retrain).
- Within 1 SE: goes to Pete as a correctness fix on a tie (same class at statewide and seat level is the
  one-source-of-truth rule in CLAUDE.md).
- Worse by more than 1 SE: to Pete with the split.

Nothing ships overnight.

## Amendments

(none)
