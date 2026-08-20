# The published model, scored in Victoria: 87.2% over 164 district-elections

Run 2026-08-20. `scripts/backtest_candidate_vic.R`, output `output/backtest-vic.csv`.

Two pairs, both newly possible after the VEC archive was found this morning:
**2014 → 2018** and **2018 → 2022**. Until today the repo held one Victorian
election's seat-level first preferences, so the model that publishes every
Victorian seat number had never been scored in Victoria.

## Results

| | districts | accuracy | Brier | log score | slope |
|---|---:|---:|---:|---:|---:|
| **VIC 2014 → 2018** | 88 | **80 (90.9%)** | **0.0840** | 0.397 | 0.512 |
| **VIC 2018 → 2022** | 76 | 63 (82.9%) | 0.0981 | 0.270 | 2.128 |
| **pooled** | **164** | **87.2%** | **0.0906** | — | — |
| NSW 2023, for comparison | 88 | 80.7% | 0.1468 | 0.856 | 0.541 |

**Victoria scores considerably better than NSW** — 87.2% against 80.7%, and a
Brier 38% lower. Some of that is real (Victoria's 2018 was a landslide with
fewer close contests) and some is that NSW 2023 elected nine independents to
Victoria's three.

Nothing leaks: each pair swings from the earlier election's district first
preferences, uses the earlier election's flow matrix, and 2018 is scored against
the VEC's own declared winners.

## The two pairs disagree about confidence, which is worth noting

- 2014 → 2018: slope **0.512** — overconfident.
- 2018 → 2022: slope **2.128** — *under*confident.

Opposite errors on adjacent elections. Pooled they cancel, which is exactly why
a single-election calibration figure should not be trusted — and this repo has
now produced calibration slopes of 0.260, 0.512, 0.541, 0.974 and 2.128
depending on which election it looked at.

## Independents again, and the same shape as NSW

| party that won | seats | mean probability we gave it | called correctly |
|---|---:|---:|---:|
| ALP | 103 | 0.890 | 91 |
| LNP | 52 | 0.857 | 48 |
| **Greens** | 6 | **0.447** | 3 |
| **independents** | 3 | **0.275** | 1 |

The majors are handled well. The two worst misses in 2014 → 2018 are **Morwell
(independent, we gave 0.000)** and **Mildura (independent, 0.022)** — both seats
an independent won from nowhere, the same failure the NSW backtest found and the
same one three rounds of modelling could not fix endogenously.

Prahran is the other instructive miss: the Greens won it from **third place on
first preferences**, and the model gave them 0.053.

## Caveats

- **2018 → 2022 truth is weaker.** No archived winners file exists for 2022, so
  the 2026 seat file's incumbent is used, with Mulgrave, Warrandyte and Narracan
  excluded because by-elections have since changed them.
- **Nine districts are unscorable in 2018 → 2022** — Ashwood, Berwick, Eureka,
  Glen Waverley, Greenvale, Kalkallo, Laverton, Pakenham, Point Cook — created
  by the 2021 redistribution with no 2018 baseline to swing from. Named in the
  run rather than silently dropped.
- **Neither pair tests the One Nation allocation**, which is the most-doubted
  part of the live forecast: One Nation contested no Victorian seats in 2014 or
  2018 and four in 2022.
