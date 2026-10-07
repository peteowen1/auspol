# The 0.38 departed rate: 15 cases, not 305, and applied to the wrong population

2026-10-07. Found while making the shipped `departed_rate = c(IND = 0.38)`
(`screened_slopes()`, `R/dev_slope.R`) time-forward, after the successor-flag
prereg named it as a leak (`docs/plans/prereg-departed-successor-flag-2026-10-07.md`).

## 1. The constant has no fitting script and its n does not reproduce

`docs/reviews/departed-leader-retention-2026-09-15.md` reports "sitting member
departs: n = 305, prev 46.7 -> now 17.8, retained 0.38", and the code's
docstring calls it "a well-powered sample, not the thin-data case". No script
was committed. `scripts/fit_departed_rate_asat.R` rebuilds the population from
the review's own definition (non-major class >= 15% at the previous election,
its leader elected, leader not standing in the seat again, keyed on the person):

    ANCHOR  all cells: n = 15 over 11 elections, prev 44.8 -> now 17.1,
            retention 0.381 (SE 0.078, clustered on election)

Same rate, one twentieth of the n. `elected` is populated in every election
except vic2010 (checked), so the count is not a missing-flag artefact. Most
likely explanation, NOT confirmed (the original code is gone): the review's
table counted joined rows, not cells. About 20 candidate rows per seat x 15
cells is about 300, and a ratio of means is nearly invariant to duplicating
each cell. The "~300 cases each, not thin data" reasoning in the review and the
docstring does not hold. The real n is about 15 and the SE about 0.08.

## 2. Time-forward, the rate is lower for every earlier target

`output/departed-rate-by-target.csv` (cells strictly before each target's polling day):
0.17 (fed2004, n 1), 0.21-0.30 for most 2007-2022 targets, 0.34 for 2024-25
targets, 0.38 only for vic2026 (all 15). wa1996 and wa2001 have no earlier
cell. Every backtest before this used a rate that included later elections.

## 3. The decay applies a sitting-member rate to mostly non-sitting cells

The decay fires for every departed IND class leader, not only sitting members.
On the successor population (`output/departed-ind-successors.csv`, IND leader
>= 10% who did not stand again; ratio of means; outcome data, no flags used):

| who departed | cells | retention |
|---|--:|--:|
| sitting member | 12 | 0.38 |
| leader who had not won | 66 | 0.63 |
| all | 82 | 0.55 |

So the 0.38, applied before renormalisation, ends up effectively ~0.6, which is
accidentally near-right for the 66 non-sitting cells. That is a plausible
reason both hold arms (`docs/reviews/departed-hold-sweep-2026-10-05.md`) were
refused: holding at exactly 0.38 cut the non-sitting majority well below their
real 0.63. Plausible, not tested.

## Status

- Leak: LIVE (shipped constant unchanged). Fix built (`fit_departed_rate_asat.R`), not wired.
- The sitting / not-sitting split was formed AFTER seeing these numbers; any arm
  using it needs a prereg that says so.
- Nothing here touches the successor flags, which are not yet coded.

## Result: the sitting split, screened 2026-10-07 — REFUSED

`scripts/quick_arm.R "AUSPOL_DEPARTED_SUCCESSOR=sitting" --slots=1` on the 13 non-WA elections with
arm cells, 1,000 sims, common random numbers (`$TEMP/qa_sitting.log`; code fd99ced). Lower is better on
every line.

| measure | baseline -> arm | change |
|---|---|---|
| share squared error, 153 changed cells | 7178.2 -> 7397.9 | +219.7 (+3%), SE 614.8, clustered on 12 elections |
| seat-winner log loss, 1,450 seats | 0.2848 -> 0.2851 | +0.0003, SE 0.0005 |
| AEF-7 ledger subset, 529 of 681 seats | 0.2752 -> 0.2767 | **+0.0014, SE 0.0013: worse by more than 1 SE** |

Only fed2013 gains (New England and Lyne: squared error -492.6, log loss -0.0025). sa2026 loses most
(log loss +0.0123): Kavel and Mount Gambier's sitting members were followed by successors who kept
0.43 and 0.59, which the ~0.35 sitting rate cuts. By the prereg's decision rule and the screen rule
("WORSE is a reason to stop") the switch stays off; no 20k run. It goes to Pete as a refusal.

What it shows: whether the departed member was sitting does not separate fading successors from
holding ones; the successor does. That is the hand-coded flag's question (still open). The leak in the
shipped 0.38 remains LIVE; the time-forward rates are lower than 0.38, so a plain time-forward
swap would cut these same cells further and is unlikely to help either (untested).
