# A working seat-by-seat simulation, with minor parties able to win

2026-08-18. Supersedes the failed prototype in
[seat-sim-prototype-2026-08-18.md](seat-sim-prototype-2026-08-18.md).

## Result

87 districts simulated candidate-level, 20,000 runs. Preferences distributed
the way the count runs — lowest excluded, transferred at measured rates,
conditional on who remains, until two are left.

| party | median seats | 90% range |
|---|---:|---|
| ALP | **41** | 30–48 |
| LNP | **34** | 29–43 |
| GRN | **5** | 4–7 |
| ONP | **6** | 1–14 |

The published two-party model gives ALP 39 (90%: 23–51). This gives 41 with a
much narrower range, which is expected: it resolves each seat on its own
composition rather than sliding every seat along one statewide swing.

## Anchor checks — the reason the previous run was binned

| check | result |
|---|---|
| Greens hold their four seats | **PASS** — Brunswick 100%, Melbourne 100%, Richmond 96%, Prahran 90% |
| One Nation does not win inner-city Green seats | **PASS** — its best are outer-suburban |
| One Nation's strength sits in plausible geography | **PASS** — Melton, Greenvale, Sydenham, Cranbourne |

## Seats where a minor party has ≥10% chance — 29 of 87

**Likely minor wins**

| seat | party | prob |
|---|---|---:|
| Brunswick | GRN | 100% |
| Melbourne | GRN | 100% |
| Richmond | GRN | 96% |
| Prahran | GRN | 90% |
| Melton | ONP | 86% |
| Sydenham | ONP | 62% |
| Greenvale | ONP | 64% |

**Live contests**

Cranbourne ONP 48%, Pascoe Vale GRN 47%, Ripon ONP 39%, Pakenham ONP 33%,
Point Cook ONP 32%, Yan Yean ONP 30%, St Albans ONP 29%, Northcote GRN 26%,
Kororoit ONP 26%, Footscray GRN 23%, Sunbury ONP 22%, Morwell ONP 21%,
Benambra ONP 20%.

**Longer shots (10–20%)** Mulgrave, Mildura, Albert Park (GRN 15%),
Narre Warren North, Werribee, Niddrie, Bayswater, South-West Coast,
Narre Warren South.

## Closest seats

| seat | | | |
|---|---|---|---|
| **Yan Yean** | LNP 40% | ALP 31% | ONP 30% |
| **Pascoe Vale** | ALP 50% | GRN 48% | |
| **Cranbourne** | ALP 50% | ONP 48% | |
| Ashwood | ALP 55% | LNP 45% | |
| Ripon | LNP 55% | ONP 39% | |

**Yan Yean is the tossup**, and it is a genuine three-way.

## How the One Nation allocation was fixed

The prototype used a form fitted on SA 2026 whose intercept could not put One
Nation below ~15% in any seat, so it won Richmond and Brunswick. South
Australia contains no seat of that type to fit against.

Replaced with two pieces, each taken from data that can speak to it:

- **Ordering** from **Victorian federal 2025 divisions**, where One Nation
  contested all 38 including inner Melbourne. Leave-one-division-out over five
  pre-named candidate forms selected a linear form on Greens share
  (MAE 2.206 against 2.328 for uniform). The gain is small, but it ranks
  Kooyong 1.0% and Goldstein 1.7% lowest and Gippsland 13.9% highest, which is
  the property that was missing.
- **Magnitude** from **SA 2026's observed relative spread**, measured at a
  22.97% statewide level close to Victoria's forecast 20.9%. The federal fit
  cannot supply this: at a 5.6% mean its relative spread is far wider than a
  party polling 21% exhibits.

Seats are ranked by the Victorian index and quantile-mapped onto the SA spread.

## Honest limitations

- **28% of transfers use a pooled fallback** rather than an exact
  survivor-conditional cell. Every row is smoothed toward uniform at weight
  0.15 so an unobserved destination is never treated as certain zero — the bug
  that sank the prototype.
- **The One Nation ordering is weak.** Beating uniform by 0.12 MAE is a real
  but small edge; seat-level ONP is only slightly predictable, consistent with
  everything else this project has found about seat-level prediction.
- **The magnitude transfer assumes Victoria's spread resembles SA's** at a
  similar statewide level. Untestable until Victoria votes.
- **Statewide party uncertainty is a flat 2.0 points per party**, not
  propagated from the trend model's own covariance.
- **The minor field keeps its 2022 shape**, scaled to the forecast OTH total.
- **Narracan is excluded** — its 2022 election failed, so it has no first
  preferences to project from.

None of these is hidden in the code; all are named parameters printed at the
top of every run.

## Status

**Not published.** This runs from data fetched into a scratchpad, and the VEC
licence question is unresolved. It is a working prototype whose numbers survive
their anchor checks, not a replacement for the published model.
