# Narracan (ONP 75% ours vs LNP ~83-91% market)
VERDICT: MODEL VIEW, with one soft spot. No bug found: Labor's 7.7 is a consequence of the skipped-Labor baseline plus the One Nation allocation, not a lost-share defect. The soft spot is a search-interest boost that dates from a scandal week.

| Party | Our primary | Our win | TAB | Sportsbet | AEF | TSIO |
|---|---:|---:|---:|---:|---:|---:|
| ONP (Ben Lucas) | 39.5 | 74.9% | 14.4% | 12.9% | 11.6% | 8.9% |
| LNP (Wayne Farnham, sitting) | 35.4 | 25.0% | 82.6% | 85.7% | 88.0% | 91.1% |
| GRN | 9.8 | 0 | 0.3% | n/a | 0.3% | n/a |
| ALP (Jannette Langley) | 7.7 | 0 | 0.6% | 0.5% | 0.03% | n/a |
| OTH_RIGHT (Dethlefs, Family First) | 6.6 | 0.1% | - | - | - | 0.02% |
Sources: forecast-vic2026.json Narracan; docs/benchmarks/vic2026/2026-11-18/*-calls.csv. All four outside views have LNP at 83-91%, so ours is the outlier, not just the bookmakers.

MECHANISM (2022 baseline -> now)
- Baseline is the Jan 2023 supplementary (archive 2022vic-firstprefs.csv; log SUP1): LNP 45.0, GRN 11.1, IND 15.9 (Wolfe 11.0 + 2 others), minor-right 19.8, ONP 6.0, ALP absent (byelection-results.csv). 2018 general: LNP 51.7, ALP 35.5.
- So Labor's "missing share" is not being moved to ONP from a 2022 Labor vote; there was none. Compared with 2022 the ONP gain (+33.5) is funded by IND (-15.9), minor-right (-13), LNP (-9.6) and GRN (-1.3); Labor adds +7.7. The IND and minor-right vote of Jan 2023 was a protest vote in a Labor-less contest, and the model hands it to ONP.
- ONP level: statewide 21.5 (log FP0), ranked across seats by federal Senate vote (ONR1/ONN1; output/onp-senate-vic2026.csv: Narracan 9.16, third behind Morwell 12.0 and Gippsland East 9.27). Rank allocation gives ~35.6, then the xgb search-interest layer adds +4.1 to 39.7 (docs/reviews/salience-vic2026-live-walk-2026-11-12.md row 14). Net: Narracan has the top ONP primary (39.5; Murray Plains 38.5, Mildura 36.6, Morwell 35.3) despite ranking third on Senate vote.
- Labor re-entry: AUSPOL_REENTRY="majors" (published_flags.R:767) fills a major from its own earlier share; it lifted Labor 4.4 -> ~10 in October (contested-seats-light-checks-2026-10-28.md line 117; Narracan ALP 10.11, ONP 34.43 then). BF0b skipped the by-election prior for Narracan ("a major did not stand"), which is correct, as there is no Labor row to use. Why 7.7 now and not 10: the filled Labor share is then squeezed pro rata when ONP is forced up to its allocated 39.5, and ALP statewide is 22.5 against 2018's ~43. I could not find a BV1r FILLED line for vic2026 in refresh.log (only nsw2027's BV1r lines appear, 0 filled), so whether the fill ran in the 19 Nov build is UNCONFIRMED; I did not run R to check.
- No seat poll for Narracan (seat-poll-blend-vic2026.csv has no row). Flows: ONP to ALP 33.7 (FL0); Labor is at 7.7 so it is out of the final two, final pair ONP v LNP, p_pair 0.995, ONP TCP median 52.4 (swing_to_flip 2.4).

STRONGEST ARGUMENT AGAINST US
1. The +4.1 search-interest lift is probably a scandal artefact: vic2026-live-salience.csv Narracan Ben Lucas ONP = 100 (raw 18.4), dated 2026-09-10, one week after he was reported pleading guilty to unregistered-pool/health-code charges and business deregistrations (web: crikey.com.au 3 Sep 2026; abc.net.au 4 Sep 2026). Search interest for bad news is not support. Without it ONP ~35.6 against LNP 35.4, a coin flip, not 75%.
2. Sitting Liberal member (Farnham, 45.0 in 2023 with ONP 6.0), no seat poll, ONP candidate with legal troubles; every external model has LNP 83-91%.
3. Backtest support is thin: ONP seats forecast at 30+ in published-predictions.csv: only 7 (qld2017 1, qld2020 1, sa2026 5); sa2026 mean forecast 32.5 vs actual 32.9, but 1 of 5 won while mean p_win was 0.30. Fine, but n=7 cannot clear it.
For us: Narracan's Senate One Nation vote (9.2) is third of 88 and our statewide ONP 21.5 sits within 1.73 of the polls (S7, limit 2.5).

MODEL-WIDE OR SEAT-SPECIFIC
Mostly the model-wide ONP-high/LNP-low pattern (ONP 15.8 seats vs TAB 12.9, LNP 39.1 vs 44.3). The seat-specific part is the supplementary baseline (Labor absent, 35 points of protest vote free-floating) and the salience lift. Not a defect fix; if anything is worth trying, it is capping or discounting a salience spike that falls in a news-scandal window (Narracan only? UNCONFIRMED across other candidates).
