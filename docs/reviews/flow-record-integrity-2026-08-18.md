# The observed preference-flow record is 14% carried-forward placeholders

Found 2026-08-18 while checking whether the measured Victorian Greens flow
(79.2, see [vic-preference-flows-2026-08-18.md](vic-preference-flows-2026-08-18.md))
should update the estimator.

## What was found

`analysis/Data/preference-estimates.csv` is the record our estimator treats as
**observed elections**. `flows_for()` and `estimate_flows_for()` take "the mean
of a party's five most recent observed elections". Auditing every region-party
series in that file:

**29 of 211 rows (14%) are exact repeats of an earlier value in the same
series.** Not similar — identical, to every decimal place.

| region | party | value | times | years |
|---|---|---:|---:|---|
| **wa** | **NAT** | **5.0** | **10** | 1989, 1993, 1996, 2001, 2005, 2008, 2013, 2017, 2021, 2025 |
| vic | OTH | 49.25 | 4 | 2014, 2018, 2022, 2026 |
| vic | GRN | 81.94 | 3 | 2018, 2022, 2026 |
| nsw | OTH | 48.5 | 3 | 2007, 2011, 2015 |
| wa | GRN | 83.2 | 2 | 2021, 2025 |
| nsw | GRN | 87.1 | 2 | 2019, 2023 |
| qld | KAP | 56.2 | 2 | 2017, 2020 |

…and ten more pairs. **Western Australian Nationals sit at exactly 5.0 for
every election from 1989 to 2025** — ten elections, one number, presented as
ten observations.

The audit was run because of the rule in `CLAUDE.md`: when one entry of
hand-maintained reference data is found wrong, audit the entire set. One error
predicted siblings, and there were 29.

## Why this is not a cosmetic problem

**Our own measurement contradicts one of them.** `2022,vic,GRN FP,81.94` is
recorded as the Victorian 2022 Greens flow. The actual 2022 count, measured
across 29 districts and 211,842 ballots, gives **79.2**. The recorded value is
not the 2022 result; it is the 2018 value carried forward, and 2026's entry is
the same number again.

This is precisely the criticism this project levels at the anchor's One Nation
handling — *"the same borrowed number stands for three future elections as
though it were three estimates"* — and it applies to the Greens and Others in
our own target state. Nobody had checked.

## The consequence for the estimator, which is the serious part

The estimator was chosen by a strict temporal backtest over 103 elections
(`scripts/backtest_flows.R`), scoring each candidate method against the
recorded value. **Of the 118 backtest targets from 2004 on, 22 (19%) are
identical to the immediately preceding value in their own series.**

A target that is a *copy of a prior input* is free money for any method that
predicts persistence, and a penalty for any method that moves away from the
last value. The ranking that resulted:

| rank | method | MAE |
|---:|---|---:|
| 1 | mean of last 5 | 4.815 |
| 2 | last in region | 4.863 |
| 3 | mean of last 3 | 5.027 |
| 6 | linear trend | 5.282 |

The top three are all persistence estimators, separated by 0.2 MAE, on a
target set where 19% of cases reward persistence by construction.

**This may also resolve a puzzle already recorded in `NEXT-STEPS.md`:** that
the linear trend came sixth *"though the trends are real and strong — Greens
+1.10 points/year over 53 elections, One Nation −0.605 over 21, both
p < 0.001."* A trend method is penalised on exactly the contaminated cases,
because a carried-forward target has by definition zero trend.

## What is established and what is not

**Established:**
- 14% of the record duplicates earlier values; 19% of backtest targets do.
- At least one duplicate is demonstrably wrong: Victorian 2022 Greens is
  recorded as 81.94 and measured at 79.2.
- The contamination mechanically favours persistence estimators.

**Not established:**
- Whether the ranking actually changes once contaminated targets are removed.
  The 81% clean majority may still select the same method. **This has not been
  run, and is pre-registered separately in
  [../plans/prereg-clean-flow-backtest.md](../plans/prereg-clean-flow-backtest.md)
  rather than run first and reported after.**
- Whether the other 28 duplicates are wrong or merely unverified. Only the
  Victorian 2022 Greens figure has been checked against a real count.

## Scope of the doubt

Check `G3` re-runs this backtest every pipeline run and fails if the adopted
estimator stops winning. It has been passing against a contaminated target set,
so it has been confirming a choice rather than testing it.

The published two-party figure depends on these flows. The Victorian Greens
error alone is worth **0.564 points** of published ALP two-party vote.
