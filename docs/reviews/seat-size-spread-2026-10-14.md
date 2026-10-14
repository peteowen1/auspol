# Seat-size spread: small seats are called too confidently (2026-10-14, AUSPOL_SIZE_SD, built off)

## Why

NT favourites the model called 0.90-0.97 (mean stated 0.945) won 8 of 19; the rest of the country won 93.9% at the
same stated level (506 seats). Not one statewide swing: favourites of both sides lose in every NT election.

## Measured

`scripts/diag_spread_by_size.R`: published-path primary-share error divided by the simulation's own per-cell sd
(1.10 + 8.67 sqrt(p(1-p))), 13,685 cells, 35 elections. 1.00 = spread right, above 1 = too narrow.

| formal votes | seats | ratio |
|---|---|---|
| under 8k (91% NT) | 80 | 2.06 |
| 8-15k (no NT) | 50 | 2.00 |
| 15-30k | 811 | 1.14 |
| 30-60k | 950 | 1.07 |
| 60k+ | 1,039 | 0.94 |

## The arm

`scripts/fit_spread_by_size.R` -> `output/spread-by-size.csv`: per target, on EARLIER elections only, a weighted
fit of log(ratio) on log formal votes over ten size bins; slope shrunk by w = max(0, 1 - se^2/b^2); widening
relative to the training cells' median size, never narrowing (factor >= 1). Slope about -0.21 (se ~0.05) once 10+
earlier elections exist; a 5k-vote seat gets ~1.5x, a 20k seat ~1.15x. `R/size_sd.R` `size_sd_apply()` merges it
into the sd override (pmax), seat size from the PREVIOUS election's formal votes. Wired into all seven harnesses and
fit_seats_full.R. Off = override unchanged.

## Screen 1 (quick_arm, 1,000 sims, AEF-7 + NT, 755 seats)

Seat-winner log loss, lower is better: pooled 0.3414 -> 0.3203 (-0.0211, SE 0.0147, BETTER by more than 1 SE).
nt2024 -0.289, nt2016 -0.205, nt2020 -0.158, wa2025 -0.004, qld2024 -0.003, vic2022 +0.000, **sa2026 +0.014**,
fed unchanged. AEF-7 ledger 0.2659 -> 0.2662 (+0.0003, SE 0.0012). No share moved (spread only), so the
share-level criterion is not assessable by design.

Next: screen the other 25 elections; then the 20k deciding run on all 35; the rebuild and publish need
fit_spread_by_size.R in rebuild_forecasts.sh and spread-by-size.csv shipped before it can go live.
