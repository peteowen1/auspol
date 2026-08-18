# The observed preference-flow record is 14% carried-forward placeholders

Found 2026-08-18 while checking whether the measured Victorian Greens flow
(79.2, see [vic-preference-flows-2026-08-18.md](vic-preference-flows-2026-08-18.md))
should update the estimator.

## What was found

`analysis/Data/preference-estimates.csv` is the record our estimator treats as
**observed elections**. `flows_for()` and `estimate_flows_for()` take "the mean
of a party's five most recent observed elections". Auditing every region-party
series in that file:

**27 of the 202 observed rows (13.4%) are exact repeats of an earlier value
in the same series** — 29 of the 211 rows in the file, before the
observed-election filter. Not similar: identical, to every decimal place.

Reproducible via `scripts/audit_flow_record.R`, added 2026-08-18 because the
first audit was ad hoc and a later run of the same logic disagreed with the
figures already written here. An audit whose answer depends on when it ran is
not an audit.

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
recorded value. **Of the 121 observed rows from 2004 on, 20 (16.5%) are identical to the
immediately preceding value in their own series**; 21 (17.4%) repeat some
earlier value. The immediate measure is the one that matters here, since that
is what a persistence estimator gets for free.

(Reported first as "19% of 118", which counted rows `is_observed_election()`
never uses, and then as "20 of 121 (17%)" alongside a wrong total of 205
observed rows. Both superseded by `scripts/audit_flow_record.R`.)

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
target set where 16.5% of cases reward persistence by construction.

~~**This may also resolve a puzzle already recorded in `NEXT-STEPS.md`:** that
the linear trend came sixth despite the trends being real and strongly
significant.~~ **Withdrawn 2026-08-18 — tested and false.** The trend ranks
6, 5, 7 across the three cleaning variants and is no better on clean targets.
The existing leave-one-out explanation stands. See
[clean-flow-backtest-2026-08-18.md](clean-flow-backtest-2026-08-18.md).

## What is established and what is not

**Established:**
- 13.4% of the observed record duplicates an earlier value; 16.5% of rows
  from 2004 on duplicate the immediately preceding one.
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

The published two-party figure depends on these flows.

> **Sizing corrected 2026-08-18.** This section first said the Victorian Greens
> error was worth **0.564 points** of published two-party vote. It is worth
> **zero**. `estimate_flow()` averages the five most recent observed elections
> for a party pooled across regions, and Victoria 2022 is the *seventh* most
> recent Greens observation — the 2026 Victorian estimate is built from SA 2026,
> FED 2025, WA 2025, QLD 2024 and NSW 2023. The record error is real and
> verified; it is also inert. Details in
> [vic-preference-flows-2026-08-18.md](vic-preference-flows-2026-08-18.md).
