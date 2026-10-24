# Backtest seat probabilities vs bookmaker seat odds (2026-10-24)

Pete asked whether our model's disagreements with the Victorian 2026 seat markets mean anything. The only way to
know is to score past elections where both forecasts exist. The odds come from scrapes Pete saved at the time.

## Data

| election | odds taken | books | seats | file |
|---|---|---|--:|---|
| fed2022 | 20 May 2022 (election 21 May) | Sportsbet, TAB | 151 | `external/reference/historical-odds/petes-2022-scrapes/2022-05-20_{sb,tab}_afe22.rds` |
| fed2025 | 22–23 Apr 2025 (election 3 May) | Sportsbet, TAB, BetR | 150 | `external/reference/historical-odds/afe2025/*_wide.csv` (from `C:/dev/afe2025`, committed there 2025-04-23) |
| sa2022 | 18 Mar 2022 (election 19 Mar) | Sportsbet | 47 | `petes-2022-scrapes/2022-03-18_SA_election_2022.rds` |
| qld2020 | file saved 28 Oct 2020 (election 31 Oct) | not recorded | 93 | `petes-2022-scrapes/Queensland_state_election_2020.xlsx` |

Copied unchanged from `C:/Users/peteo/OneDrive/Documents/code/archive/aus_fed_election_2022/` and
`C:/dev/afe2025/data/`. Daily Sportsbet files for fed2022 run 10–21 May 2022 and SA 2022 7–18 Mar 2022.

Ours: the published-path backtest probability of the actual winner's class, from `output/biggest-misses.csv`
(`logloss` rows, written 2026-10-23 from the runs `pool_backtests.R` scored).

## Method (`scripts/score_backtest_vs_market.R`)

- Margin removed per seat and book with the power method (`oddsdata::implied_probs`), then averaged across books.
- Bookie labels mapped to our classes. When the winner's class has no named runner, the book's "any other" price is
  used for it.
- A seat with a price at or below 1.00 leaves that book entirely: TAB 2025 lists 29 favourites at "1". Dropping only
  the favourite would let margin removal inflate the longshots.
- Log loss of the actual winner, clamped at 1e-6. Lower is better.

## Result

Mean log loss per seat, lower is better. `diff` is ours minus market; SE treats seats as independent, which
understates it because seats within an election share a statewide swing.

| election | seats | ours | market | 50/50 blend | diff | SE | our favourite right | market favourite right |
|---|--:|--:|--:|--:|--:|--:|--:|--:|
| fed2022 | 151 | 0.216 | 0.429 | 0.302 | −0.214 | 0.029 | 92.7% | 88.7% |
| fed2025 | 150 | 0.368 | 0.396 | 0.361 | −0.028 | 0.035 | 84.0% | 80.7% |
| sa2022 | 47 | 0.218 | 0.266 | 0.227 | −0.048 | 0.053 | 91.5% | 91.5% |
| qld2020 | 93 | 0.217 | 0.318 | 0.257 | −0.101 | 0.029 | 92.5% | 81.7% |
| pooled | 441 | 0.268 | 0.377 | 0.304 | | | | |

## Why this flatters us

**The backtest is not a forecast made before the election.** Every one of these elections was in the set used to
design and tune the model (all 22 pairs, AEF-7 included). The harnesses are time-forward on data, but feature
choices, switches and constants were kept or refused after seeing these results. The bookies' prices were genuine
forecasts. So "ours beats the market" here is an upper bound on how we would have done live.

Also: the fed2025 odds are 10 days before polling day while our backtest uses polls to the end; qld2020 is 3 days.

What survives that: fed2022 and qld2020 are each about 7 and 3.5 SE in our favour, far larger than the other two.
fed2025 and sa2022 are within noise. The only clean test is Victoria 2026, scored on the freeze-date captures.

## Seats to read before trusting the Victorian disagreements

Largest misses relative to the market (we gave the winner much less):
fed2025 Monash (ours 0.17, market 0.69), Dickson (0.08 vs 0.31), Wannon (0.20 vs 0.51), Berowra (0.50 vs 0.99);
fed2022 Fowler (IND, 0.09 vs 0.30); qld2020 Pumicestone (0.27 vs 0.63); sa2022 Finniss (0.53 vs 0.97).
Monash, Wannon and Fowler had prominent independents or defectors, the same weak spot as Benambra and Mildura in 2026.

Per-seat table: `output/backtest-vs-market-seats.csv`.
