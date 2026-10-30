# Independent gap carry where nobody re-stands: the walk (2026-10-30)

Follow-up to the refused `AUSPOL_IND_GAP_RESTAND=1` (prereg `plans/prereg-ind-gap-restand-2026-10-25.md`, RESULT).
Question: if slope 0 on the old gap is too blunt, what carry rate does the data say? Answer: the one that ships.
Pete closed the line on this evidence (DECISIONS 2026-10-30).

Built by `scripts/walk_ind_gap_carry.R` from `output/candidacies.csv` (official results); rows in
`ind-gap-carry-rows-2026-10-30.csv`. For every seat where the IND class had candidates last time and none of them
stands for it again, with an IND standing now: `prev` = IND class share last time, `lp`/`ln` = statewide (federal:
national) IND share of formal votes at the previous / current election, `got` = IND class share now. The carry rate
is the no-intercept least-squares slope of `got - ln` on `prev - lp`: 0 means the old gap vanished, 1 that all of it
carried. 513 seat-elections in 35 pairs (vic2026 and nsw2027 have no results yet).

Carry rate by size of the old gap; the shipped slope on these seats is 0.326 (`screened_slopes()` new-candidate IND)
or 0.38 (departed-leader rate, `AUSPOL_HONOUR_DEPARTED=1`):

| old gap above the level | n | carry rate |
|---|---|---|
| at or below 0 | 245 | 0.02 |
| 0-5 points | 137 | 1.39 (small denominators, noisy) |
| 5-15 points | 74 | 0.53 |
| over 15 points | 57 | 0.34 |
| all | 513 | 0.357 |

By jurisdiction: fed 0.42 (166), vic 0.27 (83), qld 0.24 (78), nsw 0.39 (72), wa 0.26 (68), sa 0.54 (26), nt 0.31 (20).

Single rows run from about 0 to about 1: Pascoe Vale vic2022 -0.05 (32.9 -> 4.2), Kennedy fed2013 -0.02 (Katter to
his own party), Kimberley wa2001 0.05, New England fed2013 0.32, Calare fed2007 0.44, Mount Gambier sa2010 0.99. So the
Pascoe Vale over-call is spread around a correct average, not a bias a fitted rate would remove.

Left as an idea, not pursued: below-level seats carry about 0 while the model applies 0.33. The gaps there are a few
points, so the cells would move well under a point.

Not checked: whether a feature of the departing candidate (sitting member, elected, years held) separates the low
rows from the high ones. That is the only version that could beat the average, and it overlaps the hand-coded
successor table (`AUSPOL_DEPARTED_SUCCESSOR`).
