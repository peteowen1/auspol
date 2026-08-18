# A working seat-by-seat simulation, with minor parties able to win

2026-08-18. Supersedes the failed prototype in
[seat-sim-prototype-2026-08-18.md](seat-sim-prototype-2026-08-18.md).

## Result

87 districts simulated candidate-level, 20,000 runs. Preferences distributed
the way the count runs — lowest excluded, transferred at measured rates,
conditional on who remains, until two are left.

| party | median seats | 90% range |
|---|---:|---|
| ALP | **41** | 32–48 |
| LNP | **35** | 29–42 |
| GRN | **5** | 4–7 |
| ONP | **5** | 1–12 |

*(Updated after per-party uncertainty was taken from the model rather than
assumed — see "Statewide uncertainty" below. The figures moved barely at all,
which says the flat ±2 it replaced was a fair guess.)*

The published two-party model gives ALP 39 (90%: 23–51). This gives 41 with a
much narrower range, which is expected: it resolves each seat on its own
composition rather than sliding every seat along one statewide swing.

## Anchor checks — the reason the previous run was binned

| check | result |
|---|---|
| Greens hold their four seats | **PASS** — Brunswick 100%, Melbourne 100%, Richmond 96%, Prahran 90% |
| One Nation does not win inner-city Green seats | **PASS** — its best are outer-suburban |
| One Nation's strength sits in plausible geography | **PASS** — Melton, Greenvale, Sydenham, Cranbourne |

## Seats where a minor party has >=10% chance — 25 of 87

All figures from the final run, after per-party uncertainty was taken from the
model. An earlier draft of this file carried figures from the previous run and
quoted Pascoe Vale at two different values; caught in review.

**Likely minor wins**

| seat | party | prob |
|---|---|---:|
| Brunswick | GRN | 100% |
| Melbourne | GRN | 100% |
| Richmond | GRN | 98% |
| Prahran | GRN | 92% |
| Melton | ONP | 86% |
| Greenvale | ONP | 61% |
| Sydenham | ONP | 56% |
| **Pascoe Vale** | **GRN** | **55%** |

Pascoe Vale is the one seat where a minor party is favoured that does not
already hold it — a Greens gain from Labor.

**Live contests**

| seat | party | prob | favourite |
|---|---|---:|---|
| Cranbourne | ONP | 44% | ALP 55% |
| Ripon | ONP | 34% | LNP 60% |
| Northcote | GRN | 30% | ALP 70% |
| Point Cook | ONP | 29% | ALP 67% |
| Footscray | GRN | 28% | ALP 72% |
| Pakenham | ONP | 28% | LNP 61% |
| St Albans | ONP | 26% | ALP 71% |
| Yan Yean | ONP | 25% | LNP 44% |
| Kororoit | ONP | 23% | ALP 76% |
| Albert Park | GRN | 19% | ALP 52% |

**Longer shots (10–17%)** Sunbury ONP 17%, Morwell ONP 17%, Benambra ONP 14%,
Mulgrave ONP 13%, Mildura ONP 13%, Werribee ONP 10%, Narre Warren North ONP 10%.

## Closest seats

| seat | | | |
|---|---|---|---|
| **Yan Yean** | LNP 44% | ALP 31% | ONP 25% |
| Albert Park | ALP 52% | LNP 29% | GRN 19% |
| Ashwood | ALP 54% | LNP 46% | |
| Pascoe Vale | GRN 55% | ALP 43% | |
| Cranbourne | ALP 55% | ONP 44% | |
| Sydenham | ONP 56% | ALP 39% | |

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
- ~~Statewide party uncertainty is a flat 2.0 points per party.~~ **Fixed
  2026-08-18.** Each party's sd now comes from the fitted trend and is scaled
  by the factor the two-party sd grows by between now and election day
  (1.336 → 2.521, ×1.89 at 102 days out), giving ALP 1.81, LNP 1.89, GRN 1.80,
  ONP 1.92, OTH 1.34. Draws are then renormalised to the forecast total so the
  parties push against each other — an independent draw per party lets them all
  rise at once, which cannot happen to vote shares. The per-party *means* also
  now come from the live trend rather than hardcoded figures.

  The remaining assumption is the scaling itself: the pipeline projects a
  two-party figure but not per-party ones, so the growth factor is borrowed
  from the two-party projection. Stated, not hidden.
- **The minor field keeps its 2022 shape**, scaled to the forecast OTH total.
- **Narracan is excluded** — its 2022 election failed, so it has no first
  preferences to project from.

None of these is hidden in the code; all are named parameters printed at the
top of every run.

## Status

**Not published.** This runs from data fetched into a scratchpad, and the VEC
licence question is unresolved. It is a working prototype whose numbers survive
their anchor checks, not a replacement for the published model.
