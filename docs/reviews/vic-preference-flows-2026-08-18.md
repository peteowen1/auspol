# Victorian preference flows, measured from the 2022 count

Acquired and parsed 2026-08-18, per
[../plans/preference-data-acquisition.md](../plans/preference-data-acquisition.md).

## What was fetched

All 88 Victorian districts, two VEC pages each — the per-district results page
(candidate, party, first preferences) and the per-district distribution page
(every exclusion with exact ballots to each remaining candidate).

| | count |
|---|---:|
| districts with a published distribution | **76** |
| districts won on first preferences, no distribution held | 11 |
| Narracan — 2022 election failed, no result at this URL | 1 |
| exclusion events parsed | **452** |
| individual transfer rows | 2,348 |
| candidates with party | 731 across 87 districts |

**Every one of the 452 exclusions reconciles exactly** — transferred votes equal
the excluded candidate's pile in all cases. That is the check that caught a bad
row in the SA data, and it passes cleanly here.

For scale: the SA attempt this work started from had **97** events across 16
districts, aggregated to party classes before parsing. This is 4.7× the events,
and **candidate-level** — every minor party and independent excluded separately
with its own destinations, rather than averaged into one bucket beforehand.

The 11 seats without a distribution are not a failure: a candidate reaching an
absolute majority on first preferences ends the count. Dandenong's Labor
candidate took 54.87%, so no preferences were distributed. It does mean the
matrix is estimated only from seats that went to preferences, which skews
toward fragmented and competitive ones.

## The finding that affects the published number

**The model's Greens preference flow is 4.3 points too generous to Labor.**

| | to ALP | n | votes |
|---|---:|---:|---:|
| **measured, GRN excluded with ALP and LNP remaining** | **79.2** | 29 | 211,842 |
| model's Victorian estimate (`flows_for()`) | 83.5 | — | — |

This is the largest and best-powered cell in the entire dataset — 29 districts
and over 211,000 ballots — and it is the exact configuration the model's
scalar describes: a Greens candidate excluded in a Labor-versus-Coalition
contest.

> ### ⚠ SIZING CORRECTED 2026-08-18 — the effect on the published number is ZERO
>
> This section first sized the discrepancy at **−0.564 points** of published
> two-party vote. **That was wrong, on two counts**, and the corrected answer
> changes whether the finding is worth acting on.
>
> 1. It assumed the model's flow *becomes* 79.2. It does not. `estimate_flow()`
>    returns the **mean of the five most recent observed elections for that
>    party, pooled across regions**, so one changed input moves the estimate by
>    at most a fifth of its own change.
> 2. **Victorian 2022 is not among those five.** Asking the function directly,
>    the 2026 Victorian Greens estimate of 83.461 is built from
>    **SA 2026, FED 2025, WA 2025, QLD 2024, NSW 2023**. Victoria 2022 is the
>    seventh most recent Greens observation and fell out of the window when
>    South Australia voted in March.
>
> **Correcting the Victorian 2022 record therefore moves the published forecast
> by exactly nothing.** The record error is real and verified; it is also inert.
>
> What the check did surface is more interesting than the error: **the
> Victorian Greens flow is estimated with no Victorian data in it at all.** The
> pooled estimate is 83.461 against a measured Victorian value of 79.2 — a
> 4.26-point gap between what the model assumes for Victoria and what Victoria
> actually did. Whether that argues for region-awareness is answered below, and
> the answer is no: `last_in_region` was the method most flattered by
> carried-forward targets and fell from 2nd to 6th once they were removed
> ([clean-flow-backtest-2026-08-18.md](clean-flow-backtest-2026-08-18.md)).

For reference, the arithmetic that produced the withdrawn figure: at a
renormalised Greens share of 13.12%, a flow moving 83.5 → 79.2 would be worth
0.564 points **if the flow itself moved**, which it does not.

**Caveat, and it is not small.** 79.2 is measured across the 29 districts where
the Greens were excluded with exactly Labor and the Coalition remaining. That is
not the official statewide Victorian figure, which would be computed across all
districts. It is a large sample of the right quantity, not a census of it.

**Not changed.** The estimator that produces 83.5 was chosen by a pre-registered
temporal backtest (`scripts/backtest_flows.R`), and replacing its output with a
single election's observation is exactly the kind of after-the-fact substitution
this project pre-registers against. What this measurement legitimately does is
raise a question about the estimator: it pools across regions, and the most
recent Victorian election delivered 79.2 while the pooled estimate says 83.5.
Whether pooling helps or hurts is testable and should be tested.

## The second finding: the OTH bucket is hiding two opposite behaviours

The model gives everything outside ALP/LNP/GRN/ONP a single flow of **48.9%**
to Labor. Measured in the two-party configuration:

| excluded class | to ALP | n | votes |
|---|---:|---:|---:|
| independents | **61.1** | 5 | 47,949 |
| minor-right (Family First, Freedom, Lib Dems, DLP …) | **35.4** | 2 | 9,169 |
| the single blended figure the model uses | 48.9 | — | — |

48.9 sits almost exactly between them, which is what a blend does. The error it
makes is therefore not in the average but per seat: it understates Labor where
the minor field is independents and overstates it where the field is
minor-right. Independents are a large bloc in Victoria — 99 exclusion events
and 171,476 ballots, the second largest after the Greens.

This is the concern raised on 2026-08-17 and recorded as unevaluable from SA
transfer tables. Victorian candidate-level data evaluates it. The `n` on
minor-right is only 2 in the strict two-party configuration, so the direction
is established more firmly than the magnitude.

Note also that the model has **no independent class at all** — independents are
inside OTH. The 2026 seat file lists an independent as the expected challenger
in South-West Coast, so this is not hypothetical.

## What Victoria cannot answer

**One Nation.** It contested 5 of 88 Victorian districts in 2022 and appears in
only **2** exclusion events totalling 9,291 ballots. The single two-party cell
(`ONP → {ALP+LNP}`) has n = 1. Victorian data cannot estimate One Nation's flow,
which is the party the whole seat rebuild is about.

So the two sources are complementary rather than competing:

- **Victoria 2022** — Greens, independents, minor-right, and the general OTH
  field. Well powered, candidate-level, the right jurisdiction.
- **SA 2026** — One Nation, and only One Nation. 16 districts, party-class
  level, thin.

Any claim about One Nation's seat prospects still rests on the SA sample.

## Coverage

52 conditional cells; **27 at n ≥ 3, 25 below**. Better than the SA attempt's
28 cells with most at n ≤ 2, but still thin once conditioned. The pooled
by-excluded-party table is well powered throughout (GRN n=49, OTH_RIGHT n=156,
OTH n=130, IND n=99); it is the survivor-set conditioning that thins it.

Files: `matrix_pooled.csv`, `matrix_conditional.csv`, `transfers.csv`,
`candidates.csv` — in the session scratchpad, not committed pending the licence
question below.

## Licence — now blocking

The VEC publishes no copyright, Creative Commons or terms-of-use statement on
any of these pages, and `vec.vic.gov.au/copyright` returns 404. This data has
been fetched for analysis, which is unproblematic. **Committing it to the repo
— the approved plan — is redistribution, and should not happen until the
licence question already awaiting Pete is resolved**, particularly given the
repo-public decision is open.
