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
