# Pre-registration: final-three Liberal card shares (`AUSPOL_HTV_FINAL3=1`), 2026-11-27

Written 27 Nov 2026, before any score was computed (only the fitted shares below were looked at). Asked for by Pete on
27 Nov (fix the Labor-v-Greens Liberal flow before polling day if a fix measures well). Starts from the standard
decision rule (`docs/PRE-REGISTRATION-RULES.md`).

## The problem, measured

`htv_card_label_shares()` (`R/htv_flow.R`, `AUSPOL_HTV_LABELS=hybrid`) fits ONE Labor-above share from every earlier
Liberal exclusion in which Labor and the Greens both received votes, cells weighted by seat count. vic2026 live:
61.7% (`HTV14`, 17 cells). `htv_flow_override()` writes it into every `LNP|...ALP+GRN...` key, including the exact
`LNP|ALP+GRN` key that decides a Labor-v-Greens seat.

The transfer files (`external/elections/*-transfers.csv`) show two populations. Final-three exclusions (Liberal votes
went to Labor and the Greens only) against earlier, many-candidate exclusions, vote-weighted share to Labor:

| Election (card) | final-three events, votes, % to ALP | earlier exclusions % to ALP |
|---|---|---|
| fed2013 (ALP>GRN) | 3, 67,567, 65.5 | 47.5 |
| fed2016 (ALP>GRN) | 3, 63,907, 64.7 | 47.9 |
| fed2019 (no card) | 3, 64,255, 59.3 | 56.5 |
| fed2022 (ALP>GRN) | 6, 121,098, 65.5 | 44.0 |
| fed2025 (ALP>GRN) | 9, 208,873, 72.7 | 62.4 |
| vic2010 (ALP>GRN) | 4, 33,923, 66.8 | 61.4 |
| vic2014 (ALP>GRN) | 4, 33,000, 68.4 | 56.6 |
| vic2018 (2 open seats) | 3, 18,393, 56.6 | 65.7 |
| vic2022 (GRN>ALP) | 6, 51,919, 35.0 | none |
| sa2026 (ALP>GRN) | none | 59.7 (18 events) |

## What it changes

`AUSPOL_HTV_FINAL3=1`: a second set of the three card shares is fitted, by the same function, the same labels,
recency weights and shrinkage, and the same time-forward filter (`elections_before()`), from FINAL-THREE exclusions
only (`htv_seat_splits_final3()`). It is written into the exact `LNP|ALP+GRN` key only; wider keys keep the
all-exclusion share. `"0"` (published) is byte-identical. Applied check: `HTV16` prints both share sets per fit.

Dry run (shares only, no score seen), Labor-above share all-exclusion -> final-three:
vic2026 61.7 -> 67.1 (11 cells); fed2025 59.8 -> 63.9; fed2022 59.5 -> 63.6; fed2016 59.7 -> 67.1; vic2022 60.3 ->
64.4 (not used: vic2022's card is Greens-above, 40.2 -> 37.8); vic2018 60.4 -> 66.4; vic2014 57.9 -> 66.1; vic2010:
no earlier final-three Labor-above cell, falls back to the all-exclusion share. Open share vic2026 57.1 unchanged.

**What this does NOT do, said now:** Melbourne fed2025 (actual 79.3%) moves only from 59.8 to 63.9. The seat-level
effect (Liberal voters where the Greens are the threat following the card harder) is not modelled.

## Scores

1. **Primary (flows): log loss of the actual Liberal transfers in final-three exclusions**, two-way (ALP v GRN),
   per event `-(a log p + g log(1-p)) / (a + g)`, `p` the share the model writes into `LNP|ALP+GRN` after the
   simulation's own smoothing toward uniform (`p_eff = (1 - s) p + s / 2`, `s` = `AUSPOL_SMOOTH` as published),
   averaged over events. Elections scored: every election with a card row (the override applies only there) and a
   final-three event: fed2013, fed2016, fed2022, fed2025, nsw2011, nsw2019, nsw2023, qld2020, qld2024, vic2010,
   vic2014, vic2018, vic2022. Each target's share is fitted from earlier elections only. Paired arm minus base, SE
   clustered on election. Elections without a card row are untouched by construction and reported as such.
   Also reported, not decisive: the same score vote-weighted, and without smoothing.
2. **Guard (seats):** `Rscript scripts/quick_arm.R "AUSPOL_HTV_FINAL3=1" --pairs=fed2016,fed2019,fed2022,fed2025,
   vic2014,vic2018,vic2022,qld2020,qld2024,nsw2019,nsw2023,sa2026 --slots=1` (1,000 sims, private quick dir), seat-
   winner log loss pooled over those elections, SE clustered on election.

## Decision rule

- Ship candidate only if the primary is better by more than 1 SE AND the guard is not worse by more than 1 SE.
  Then it goes to Pete with the vic2026 seats that move; it is not flipped here.
- Within 1 SE on the primary: a tie, reported to Pete, not shipped.
- Guard worse by more than 1 SE: refused, whatever the primary says, with the split by election.

**What would make an apparent win unacceptable (named now):** a primary gain carried by federal elections while the
Victorian Labor-above elections (vic2014, and vic2018's open seats) score worse on transfers, or any Victorian
election worse on the seat guard by more than 2 SE of its own paired seat differences. The live use is Victorian.
The 17 Nov per-state shrink raised vic2014's share in the same direction and lost seat log loss there (+0.0044), so
that split is shown on its own.
