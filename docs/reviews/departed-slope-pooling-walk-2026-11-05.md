# Major departed-member slope: what "toward the pooled slope" would give (walk for Pete, 2026-11-05)

Prep for the 27 Oct decision (DECISIONS: "Major departed slope below 40 seats: tau^2 arm toward the pooled slope,
not the existing `AUSPOL_SLOPE_SHRINK`"). Nothing built, nothing screened. Computed from `fit_major_departed_slope()`'s
own fitted rows (`R/split_slope.R:720`, time-forward: only pairs before each target), today's `output/candidacies.csv`
(22,358 rows, 44 elections). Script: scratchpad `dep2.R` (not committed; one call per target, ~2 s each).

## What the slope is

When a Labor or Coalition member retires or leaves, how much of the seat's old lean (its share minus the statewide
level last time) carries to the new candidate. 1 = all of it, 0.6 = 60%. The fit is a regression through the origin of
`actual_now - level_now` on `prior - level_prev` over every earlier departed-member seat. Below 40 seats the shipped
code throws the estimate away and uses 1.

## The cells (slope multipliers; SE clustered by election, the larger of that and the ordinary SE)

Shipped = what the published model uses today. Own = the cell's own estimate, which the cliff discards below 40.
Pooled = ALP and LNP departed seats fitted together. Present = members who stayed (the other tier), for contrast.

| target | shipped ALP / LNP | own ALP (SE, n, elections) | own LNP (SE, n, elections) | pooled (SE) | present ALP / LNP |
|---|---|---|---|---|---|
| fed2007 | 1 / 1 | 0.303 (0.240, 6, 2) | 0.874 (0.314, 14, 2) | 0.689 (0.318) | 0.988 / 0.798 |
| fed2010 | 1 / 1 | 0.555 (0.153, 27, 5) | 0.800 (0.135, 38, 5) | 0.713 (0.131) | 0.942 / 0.890 |
| sa2010 | 1 / 1 | 0.502 (0.180, 20, 4) | 0.794 (0.198, 30, 4) | 0.682 (0.177) | 0.968 / 0.907 |
| wa2001 | 1 / 1 | no rows | no rows | - | - |
| wa2005 | 1 / 1 | 0.252 (0.284, 5, 1) | 0.581 (0.120, 5, 1) | 0.439 (0.148) | 0.985 / 0.643 |
| wa2008 | 1 / 1 | 0.486 (0.207, 17, 3) | 0.844 (0.216, 26, 3) | 0.709 (0.205) | 0.961 / 0.886 |
| nsw2011 | 0.554 / 0.777 | 0.554 (0.107, 40, 6) | 0.777 (0.116, 52, 6) | 0.688 (0.104) | 0.931 / 0.896 |
| vic2010 | 0.554 / 0.777 | same rows as nsw2011 | | | |
| vic2026 (live) | 0.618 / 0.641 | 0.618 (0.036, 250, 33) | 0.641 (0.055, 270, 34) | 0.630 (0.036) | 0.922 / 0.876 |

**The finding:** every cell the cliff snaps to 1 has its own estimate below 1, all twelve of them (0.25 to 0.87), and the
well-measured live value is 0.62-0.64. The 1.0 fallback is the outlier, which is why `AUSPOL_SLOPE_SHRINK` (shrinks toward
1) helped early targets and was still refused 29 Sep: it pulled the recent, well-measured cells toward the wrong number.
The present-member slopes (0.80-0.99) are a different quantity and not a candidate target.

## Option A: DerSimonian-Laird across the two parties (Pete's "tau^2" wording)

`mu` = precision-weighted mean of the ALP and LNP departed slopes; `tau^2` = the between-party variance; each cell
`mu + tau^2/(tau^2 + se^2) * (own - mu)`.

| target | mu | tau^2 | ALP own -> shrunk | LNP own -> shrunk |
|---|---|---|---|---|
| fed2007 | 0.514 | 0.0849 | 0.303 -> 0.388 | 0.874 -> 0.680 |
| fed2010 | 0.693 | 0.0092 | 0.555 -> 0.654 | 0.800 -> 0.729 |
| sa2010 | 0.634 | 0.0068 | 0.502 -> 0.611 | 0.794 -> 0.658 |
| wa2005 | 0.531 | 0.0066 | 0.252 -> 0.510 | 0.581 -> 0.547 |
| wa2008 | 0.657 | 0.0193 | 0.486 -> 0.604 | 0.844 -> 0.712 |
| nsw2011 / vic2010 | 0.657 | 0.0124 | 0.554 -> 0.603 | 0.777 -> 0.714 |
| vic2026 (live) | 0.625 | 0.0000 | 0.618 -> 0.625 | 0.641 -> 0.625 |

Weakness: tau^2 from two cells is itself barely estimable (CLAUDE.md shrinkage limits). It runs 0.000 to 0.085
across these targets, and at vic2026 it is 0, so live collapses both parties onto one slope (a 0.007 / 0.016 move).

## Option B: same target, tau^2 from earlier elections instead of two cells

Estimate the between-party variance time-forward from the per-election ALP-minus-LNP departed-slope gaps of earlier
pairs (many cells, not two), then shrink each party's cell toward the pooled slope with that tau^2. Not computed yet.
The live move would be no larger than Option A's, and the early-target numbers would differ mainly at fed2007.

## What I would ask Pete

1. Target: the pooled ALP+LNP departed slope (both options use it). Recommended; the alternatives (1, or the present slope)
   are contradicted by every cell above.
2. A or B for tau^2. My pick: B, because it does not ask two numbers for their own spread, and its cost is about
   one more function. Then prereg (clauses as in `plans/prereg-slope-shrink-rescreen-2026-10-25.md`: AEF-7 do-no-harm,
   the eight cliff elections targeted, all 35 guard) and screen.
