# South Australia cannot tell us whether the One Nation seat count is right

Measured 2026-08-19. **Nothing changed.**

**This document originally claimed the seat model under-calls One Nation by
about half. That claim is retracted.** It rested on a comparison that ignored
rank, and once South Australia's own rates are given honest intervals, the
model's answer sits comfortably inside them. The retraction is kept in place
rather than the document rewritten to look right from the start.

## What South Australia actually shows

SA voted in March 2026 — the only completed election where One Nation contested
at the level Victoria is forecasting. Derived from first preferences plus the
full transfer record:

**One Nation won 7 of 47 districts on 22.9% of the statewide vote.** An
independent won one.

Split by where it started, which is the part that matters:

| One Nation's rank on first preferences | districts | won | mean primary | mean preferences gained |
|---|---:|---:|---:|---:|
| **1st** | 4 | **4** | 33.8% | +19.5 |
| **2nd** | 30 | **3** | 25.3% | +11.4 |
| 3rd | 5 | 0 | 16.4% | +1.9 |
| 4th | 8 | 0 | 13.0% | +1.2 |

Leading on primaries converted every time; running second converted **3 times in
30**.

## The first comparison was wrong

I fitted a logistic curve of win probability on One Nation's first-preference
*share alone*, applied it to Victoria's projected shares, and got 6.2 expected
seats against the model's 2.96.

**That is confounded by rank.** SA's high-share districts were mostly ones where
One Nation *led*; Victoria's high-share seats are ones where it runs **second**
behind the Coalition. The share-only curve reads Victoria's 31% seats as if they
were SA's 31% seats, which were a different situation.

## The rank-aware comparison, and why it still cannot settle anything

Victoria's projected ranks across 87 seats: One Nation **1st in 2**, **2nd in
36**, lower in 49. Applying SA's observed rates:

| | expected One Nation seats |
|---|---:|
| point estimate (2 × 1.00 + 36 × 0.10) | **5.6** |
| **95% range from SA's own rates** | **1.6 to 11.6** |
| what the Victorian model expects | **2.96** |

The rates are 4 of 4 and 3 of 30. Their binomial intervals are 0.398–1.000 and
0.021–0.265 — wide enough that **the model's 2.96 is not distinguishable from
the SA-implied estimate.** The point estimate is about double; the evidence
cannot support that at any useful confidence.

## What this does and does not change

- **It does not show the model is wrong.** 2.96 is inside the range.
- **It does not reframe the three refused experiments.** I wrote that they had
  been "guarding against movement in the direction the evidence supports."
  There is no such evidence. That sentence is withdrawn; the refusals stand on
  their own pre-registered terms and nothing external contradicts them.
- **It does establish something narrower and useful.** One Nation wins these
  seats from second place about a tenth of the time, and Victoria has 36 seats
  where it is projected second. That is the quantity to watch, and it is now
  measured rather than assumed.
- **The `sPolls` idea is dead as a shortcut.** Nothing here substitutes for
  Victorian evidence, of which there is none: One Nation has never contested a
  Victorian state election at this level.

## What I got wrong, and why

Two failures of the same kind in one document.

1. **Comparing on a variable that was not the operative one.** Share, not rank.
   The confound was visible in SA's own table the moment it was split.
2. **Quoting a point estimate from tiny samples without an interval.** 4 of 4
   and 3 of 30 cannot distinguish 2.96 from 5.6, and I published "under-calls by
   about half" from exactly those numbers.

The second is the one to watch: this is the second retraction of the session
after a `+0.108` seat-count figure that turned out to be Monte Carlo noise. Both
were point estimates from thin evidence, presented as findings. The habit to
break is quoting a difference before asking what range the data actually
supports.

`scripts/compare_onp_seats_sa.R` now reports the interval alongside the point
estimate, so the number cannot be quoted without it.
