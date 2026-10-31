# Prereg: weight recent elections in the how-to-vote flow rows (AUSPOL_HTV_RECENCY_HL)

Written 2026-10-31, before any run. Pete chose this on 31 Oct ("Weight recent elections").

## Why

`fit_htv_flow_rows()` (`R/htv_flow.R`) sets the Liberal -> Labor share, when Labor and the Greens are both alive,
from the seat-weighted MEAN of every earlier election with the same card label. The Greens-last (labor_above) share
has been rising: vic2018 58, fed2019 59, fed2022 65, qld2024 73, fed2025 73. The mean lags it: fed2025 used 60.4
against 73 actual, and Melbourne fed2025 was called for the Greens at 0.99 partly on it
(`reviews/night-replay-real-feed-2026-10-31.md`).

## Arm

`AUSPOL_HTV_RECENCY_HL=8`: each earlier election's weight is its seat count x 0.5^(age / 8), age in years from that
election to the target. Half-life 8 years, about two to three federal elections. With one old election and nothing
recent, the weights still give the plain mean, so a thin label degrades to today's estimate, not to a cliff
(the repo's shrinkage rule). "0" = the plain mean (today). Applies to both labels and every harness that uses the card
(fed, nsw, qld, vic and the published script; the table has no SA or WA rows).

## Prediction (before running)

fed2022 and fed2025 labor_above shares rise by 2-5 points; vic2022 (greens_above, 35 vs history ~33) barely moves.
Gains in Labor-v-Greens seats (Melbourne, Wills, Cooper, Macnamara; Richmond, Northcote in Victoria). Small pooled.

## Measurement and decision rule

1. Screen on all 35 at 1,000 sims (`scripts/quick_arm.R "AUSPOL_HTV_RECENCY_HL=8" --pairs=all`); only elections with a
   card row can move, and the rest must be byte-identical (if they move, the arm leaks: void).
2. Deciding run: all 35 at 20,000 sims.
3. Ship if pooled seat-winner log loss (lower is better; SE clustered on election) is better, or within 1 SE with the
   moved seats better; and no election worse by more than 2 SE (a refusal by that clause alone goes to Pete).
4. Report the fitted shares per target with and without, and the moved seats' winners.

Also reported, not decided on: half-lives 4 and 16 on the screen, to show sensitivity. Choosing among them after
seeing the results would be tuning on the test, so 8 is the arm.

What would make an apparent win unacceptable: any election without a card row moving.

## Screen (2026-10-31 9:41pm, all 35, 1,000 sims, code ae34ef46)

HL 8: pooled -0.0001 (SE 0.0001), AEF-7 -0.0003 (SE 0.0002), both BETTER by more than 1 SE. 8 of 35 elections moved,
every one with a card row (nsw2019, qld2020, nsw2023, vic2018, fed2025, fed2019, qld2024, vic2022); the rest
byte-identical, so the arm does not leak. Largest: vic2022 0.2430 -> 0.2413 (16 seats). 50 seats moved in all.
Deciding run (all 35, 20k) chained to start after the HL 4 / 16 sensitivity screens: `deciding-runs/*-htv-recency-8`.
