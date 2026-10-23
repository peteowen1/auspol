# Are our two-candidate-preferred (TCP) margins squeezed toward 50? (2026-10-24)

Bottom line: the slope of 1.045 is real arithmetic but is NOT evidence of a stable compression, a stretch on the reported TCP would not change any win probability, and out of sample it makes TCP error slightly worse. Do not build it. Scratch scripts: `C:\Users\peteo\AppData\Local\Temp\claude\C--dev-auspol\597d5a10-bcc6-422e-a23c-66b6c6fb51da\scratchpad\tcp\a.R` and `b.R`. Data: `output/biggest-misses.csv` (metric tcp, 658 seats, 7 AEF-7 pairs).

## Orientation check

- CONFIRMED: `f1` is always the official WINNER. `scripts/biggest_misses.R` takes `f1`, `f2`, `f2cp` from `output/aef7-tcp-actual.csv`, where `f2cp` is the real winner's share. In the 658 rows the minimum `actual` is 50.0 and 100% are at or above 50.
- `ours` is our median share for that same party within the real final two, so it can be below 50 (71 of 658 rows: we had the eventual winner behind).
- The feared bias does not touch the slope. A regression through (50, 50) with no intercept is unchanged when any seat is flipped about 50 (x and y both change sign, so x*y and x^2 are unchanged). I recomputed the slope under five orientations (winner, alphabetical, predicted favourite, ALP-side, random): all give 1.045. The "410 of 658 further from 50" count is also orientation-free.
- What orientation DOES bias: any statistic using a level rather than a distance. Winner-oriented mean(actual) - 50 is 9.89 against 7.99 for ours, and that gap is selection on the outcome. Do not quote it.
- Direction is right: actual regressed on ours (slope above 1 means our margins are too small).
- A milder selection applies to every orientation: we score only the pairing that actually happened. How much this matters is UNCONFIRMED.

## Compression after correction

Slope of (actual - 50) on (ours - 50), no intercept, winner-agnostic; 1.00 is calibrated, above 1 means we under-state the margin. MAE is mean absolute TCP error in points (lower is better); "stretched" applies that row's own fitted slope (in-sample, flattering).

| Pair | n seats | Slope | MAE now | MAE stretched in-sample |
|---|---|---|---|---|
| fed2022 | 151 | 0.989 | 3.02 | 3.03 |
| fed2025 | 150 | 1.129 | 4.95 | 4.75 |
| nsw2023 | 87 | 1.291 | 4.67 | 3.57 |
| qld2024 | 93 | 0.955 | 2.97 | 2.98 |
| sa2026 | 47 | 1.094 | 3.58 | 3.49 |
| vic2022 | 78 | 0.860 | 3.23 | 2.98 |
| wa2025 | 52 | 0.976 | 3.68 | 3.72 |
| All | 658 | 1.045 | 3.79 | 3.75 |

Uncertainty on the pooled 1.045 (95% intervals):
- Seat bootstrap: 1.009 to 1.082. Too narrow, because errors are shared inside an election.
- Resampling the 7 pairs: 0.948 to 1.166, which includes 1.00. Mean of the 7 pair slopes 1.042, SE 0.054 (t about 0.8).
- Seat noise alone (error SD 4.5) would move the slope by only 0.017, so the spread between pairs is real election-to-election variation.

Out of sample: fit one slope on six pairs, score the seventh (leave-one-pair-out): TCP MAE 3.819 against 3.786 with no stretch. Lower is better, so the stretch is worse by 0.03 points. In-sample it gains 0.04 pooled, nearly all from nsw2023.

By size of our predicted lead, oriented to our predicted favourite. Mean ours and actual are the favourite's share (%); bias is actual minus ours (positive = favourite under-called); flipped = the other side won.

| Band of lead | n | Mean ours | Mean actual | Bias | Flipped % |
|---|---|---|---|---|---|
| 0-5 | 204 | 52.59 | 52.79 | +0.20 | 27.0 |
| 5-10 | 200 | 57.59 | 58.03 | +0.44 | 6.5 |
| 10-20 | 237 | 63.84 | 64.47 | +0.63 | 0.8 |
| 20+ | 17 | 72.68 | 72.45 | -0.23 | 0.0 |

Bias is under 0.7 points in every band. With an intercept the pooled fit is actual - 50 = 0.10 + 1.037 x (ours - 50), intercept SE 0.35.

## By contest type

Slope (no intercept; SE is seat-level, not clustered by election, so indicative only) and mean bias for the named side (actual minus ours; positive = that side under-called, in points).

| Contest | n seats | Slope (SE) | Side | Bias | SE |
|---|---|---|---|---|---|
| ALP v LNP | 516 | 1.066 (0.057) | ALP | +0.68 | 0.20 |
| ALP v GRN | 26 | 0.991 (0.074) | ALP | +2.15 | 1.13 |
| ALP v IND/other | 19 | 1.097 (0.063) | ALP | +0.84 | 1.56 |
| LNP v GRN | 7 | 0.904 (0.147) | LNP | -0.54 | 1.29 |
| LNP v IND/other | 54 | 0.773 (0.169) | LNP | +2.16 | 0.80 |
| other pairings | 36 | 1.039 (0.068) | ALP | +1.97 | 0.70 |

LNP v IND/other has a slope below 1 (n = 54), so there is no consistent compression across contest types.

Mean Labor bias in ALP v LNP contests by pair (positive = Labor under-called; points, closer to 0 is better).

| Pair | n seats | ALP bias | SE |
|---|---|---|---|
| fed2022 | 124 | -0.25 | 0.31 |
| fed2025 | 115 | +4.18 | 0.37 |
| nsw2023 | 66 | +0.86 | 0.71 |
| qld2024 | 85 | -0.18 | 0.40 |
| sa2026 | 13 | -1.48 | 1.31 |
| vic2022 | 65 | -1.90 | 0.39 |
| wa2025 | 48 | +0.04 | 0.67 |
| All | 516 | +0.68 | 0.20 |

The fed2025 Labor under-call (+4.2, SE 0.37) is CONFIRMED and large, but the pooled mean is only +0.68 because vic2022 goes the other way. The sign changes by election, which points to a statewide or national swing miss rather than a TCP property.

Why the slope exceeds 1 in fed2025 and nsw2023, from bias split by which side we favoured (mean actual minus ours, ALP share):
- fed2025: +4.9 in Labor-favoured seats and +3.2 in Coalition-favoured seats. A near-constant Labor push, which a slope through 50 partly reads as stretch.
- nsw2023: +3.2 in Labor-favoured seats and -3.2 in Coalition-favoured seats. A genuine spread miss (slope 1.29, 1.37 with an intercept).
- vic2022: -2.3 and -1.1, slope 0.86.
- All ALP v LNP: +1.16 in Labor-favoured, -0.05 in Coalition-favoured.
Adding election intercepts moves the ALP v LNP slope from 1.054 to 1.084, so the signal is election-specific, not a level shift alone.

## Code path

- Primaries are simulated per seat-draw in `simulate_seat_contests()` (`R/seat_sim.R`; hot loop in `src/seat_sim_core.cpp`; R fallback at `R/seat_sim.R:1553-1560` and `1697-1699`). The lowest candidate is excluded and the pot is split by `split_flow()`, repeated until two remain.
- TCP is written as `tcp_share = v[winner] / sum(v[alive])` (`src/seat_sim_core.cpp:314` and `:420`): a deterministic function of that draw's simulated primaries and flow draws. Nothing independent is drawn for TCP.
- The winner is the larger of the two final counts. The `shrink` coin toss (`:317`, `:422`) can overrule which party is credited in `wins`/`totals`, but `R/seat_sim.R:375` says TCP is taken before it.
- `tcp_scenarios()` (`R/tcp_scenarios.R`) reports, per pairing, the MEDIAN across that pairing's draws of f1's share. That is the `ours` column. Its spread around 50 is set by the spread of simulated primaries and flows.

## Does a stretch change win probabilities

No. In a single simulation the winner is whoever has the larger final count, which is exactly TCP above or below 50. A monotone stretch around 50 on `tcp_share` keeps every draw on the same side of 50, so every draw keeps its winner and `win_prob`, and so seat log loss, is unchanged. A stretch on the reported median changes only the displayed figure and TCP MAE (the biggest-misses table and the ledger two-candidate measure).

The only way a TCP-motivated change moves win probability is by acting on the primaries or flows BEFORE the count. That is a different change: it widens the dispersion of simulated seat outcomes and must be judged on pooled seat log loss.

Rough check that win probabilities are not too tight (UNCONFIRMED against pooled seat log loss by band): in the 0-5 band the favourite lost 27% of the time at a mean lead of 2.6 points, and in the 5-10 band 6.5% at a lead of 7.6. An error SD of about 4.5 predicts roughly 28% and 5%. The 2026-10-19 miss diagnosis (`docs/reviews/miss-diagnosis-aef7-2026-10-19.md`, line 17) reached the same view for the coin-flip seats.

## Prior work

Searched `docs/` for TCP with stretch, dispersion, compress or spread. No earlier refusal of a TCP stretch found (UNCONFIRMED beyond that grep). Closest: `docs/reviews/tcp-gap-diagnosis-2026-09-29.md` (the 655-seat two-candidate gap to AE Forecasts is mostly nsw2023 +124.7 and vic2022 +71.3 in summed excess points, i.e. how the swing was distributed by seat type) and `docs/reviews/miss-diagnosis-aef7-2026-10-19.md` (the worst TCP misses trace to Labor and One Nation primaries). The request is logged at `docs/PETE-ASKED-FOR.md:35`.

## Recommendation

1. Do not build the stretch factor. The pooled slope 1.045 has a pair-clustered interval of 0.95 to 1.17; pair slopes run from 0.86 to 1.29 with no common sign; LNP v IND is below 1; leave-one-pair-out TCP MAE is worse (3.819 vs 3.786); and it cannot change P(win), the metric that ships. It would improve only TCP MAE, and only in sample.
2. What the data does show is election-level error: fed2025 Labor +4.2 across ALP v LNP seats, vic2022 -1.9, and a spread miss in nsw2023 (Labor-favoured +3.2, Coalition-favoured -3.2). The right levers are the statewide or national swing level, how the swing is distributed by seat type (the parked seat-type swing item), and the One Nation under-call from the 2026-10-19 diagnosis. Those act on primaries and flows, so they move both TCP and win probability.
3. If Pete still wants a stretch, test it where it can matter: a dispersion multiplier on the simulated seat swing or flow deviation before the count, scored by pooled seat log loss on all 22 pairs, time-forward, shrunk toward 1.00, with the criterion committed first. The pair-clustered intervals above say not to expect it to clear.
4. Caveats: seven elections, with nsw2023 carrying most of the stretch signal; the sa2026 Coalition-favoured cell is a single seat.
