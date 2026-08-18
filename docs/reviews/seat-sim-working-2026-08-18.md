# A working seat-by-seat simulation, with minor parties able to win

2026-08-18. Supersedes the failed prototype in
[seat-sim-prototype-2026-08-18.md](seat-sim-prototype-2026-08-18.md).

## Result

87 districts simulated candidate-level, 20,000 runs. Preferences distributed
the way the count runs — lowest excluded, transferred at measured rates,
conditional on who remains, until two are left.

| party | median seats | 90% range |
|---|---:|---|
| ALP | **41** | 24–51 |
| LNP | **38** | 29–54 |
| GRN | **5** | 3–7 |
| ONP | **3** | 0–7 |

**Superseding the ranges first published here (ALP 32–48).** The simulation was
rebuilding the statewide distribution rather than inheriting the projection,
producing an implied two-party of 49.23 ± 1.52 against the projection's
48.00 ± 2.52 — centred 1.2 points too favourable to Labor and roughly 40% too
tight, because drawing each party independently and renormalising cancels the
Labor-versus-Coalition movement that seats actually respond to. The statewide
draw is now anchored to the projection and lands at 47.97 ± 2.519.

The correction is what makes the two seat models comparable: the two-party
model gives ALP 39 with a 90% range of 23–51 against this 41 and 24–51. While
the ranges disagreed, one of them was simply wrong.

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

## Seats where a minor party has >=10% chance — 14 of 87

Regenerated from `output/seat-probs-vic-2026.csv` after the projection-anchoring
fix. **Every probability here is lower than first published**, because the
uncorrected run was about 40% too confident.

| seat | party | prob | favourite |
|---|---|---:|---|
| Brunswick | GRN | 100% | GRN 100% |
| Melbourne | GRN | 99% | GRN 99% |
| Richmond | GRN | 95% | GRN 95% |
| Prahran | GRN | 72% | GRN 72% |
| Melton | ONP | 57% | ONP 57% |
| Pascoe Vale | GRN | 49% | GRN 49% |
| Northcote | GRN | 43% | ALP 57% |
| Greenvale | ONP | 36% | ALP 48% |
| Footscray | GRN | 30% | ALP 69% |
| Sydenham | ONP | 25% | ALP 44% |
| Cranbourne | ONP | 21% | ALP 60% |
| Point Cook | ONP | 18% | ALP 65% |
| Pakenham | ONP | 18% | LNP 73% |
| Ripon | ONP | 16% | LNP 75% |

## Closest seats

| seat | favourite | prob |
|---|---|---:|
| Sydenham | ALP | 44% |
| Greenvale | ALP | 48% |
| Niddrie | ALP | 49% |
| Pascoe Vale | GRN | 49% |
| Sunbury | ALP | 53% |
| Albert Park | ALP | 55% |

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
