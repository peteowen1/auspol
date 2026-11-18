# Mordialloc: ALP 62% (ours) vs LNP favourite (TAB/Sportsbet/AEF)
1. VERDICT: MODEL VIEW (mostly the model-wide pattern; no defect found). Seat has no seat polls, no independent split, clean candidate list; gap is "how far Labor falls and where One Nation preferences go".
2. Table (win chance; our primary in brackets). Market columns have no primaries.
| Party | Ours | TAB | Sportsbet | AEF | TSIO |
| ALP | 62.2% (32.9) | 31.8 | 33.6 | 32.2 | 53.2 |
| LNP | 33.0% (28.0) | 56.2 | 54.3 | 58.4 | 40.2 |
| ONP | 4.3% (18.4) | 11.2 | 10.8 | 8.5 | 6.6 |
| GRN | 0.3% (14.0) | 0.4 | - | 0.9 | 0.1 |
Source: forecast-vic2026.json (seat Mordialloc); benchmarks/vic2026/2026-11-18/*-calls.csv.
3. Mechanism (all read from files):
- Start: 2022 primaries ALP 44.0, LNP 31.4, GRN 10.3, IND 7.4 (O'Donnell, not standing now), TCP ALP 58.2 (archive/2022vic-firstprefs.csv, -tcp.csv). 2018 TCP ALP 62.9, 2014 52.1: Richardson has held it three times.
- Forecast primaries: ALP 32.9 (-11.1 on 2022), LNP 28.0 (-3.4), ONP 18.4, GRN 14.0 (+3.7). Statewide ALP level 22.5 vs 36.7 in 2022; LNP 30.7 vs 34.5 (statewide[] in the json). So Mordialloc ALP falls less than ALP statewide (-14), as a sitting-minister-type seat with a 2022 margin.
- Median ALP two-candidate-preferred 51.17%, swing to flip only 1.17 pts, 85% chance the final two are ALP v LNP (final_two). 62% is a thin-margin call, not a confident one.
- Seat polls: none (seat-poll-blend-vic2026.csv has no Mordialloc row). Search interest: no live row (vic2026-live-salience.csv empty for the seat). Council history: all four new candidates have zero council runs (council-history-vic2026.csv). ind_split false; IND primary 0 (no credible independent). demo-resid ALP +0.10 (negligible). seat-swing-port: fed_swing 3.88, coef 0.45.
- Not a counting defect: candidates are one per party (ALP Richardson, LNP O'Halloran, ONP Ticehurst, GRN Breskin); OTH_RIGHT has two minor names (Potucek, Versteegen) at 4.2% total, not a mis-merge. Primaries sum to 100.0.
- Sitting member verified (docs/reviews/vic2026-sitting-member-audit-2026-10-25.md). No Mordialloc lines in refresh.log (no warning code fired).
4. MODEL VIEW. What the market may be missing: Richardson's 2022 TCP margin of 8.2 pts and a new, council-untested Liberal candidate (the 2022 Liberal was Pease; LNP lineup changes each cycle: Wreford, Gledhill, Pease, O'Halloran). TSIO, a model, lands at 53% ALP, so a rival model sees it our way.
Strongest argument against us: ONP at 18.4% (market implies ~11%) is the preference pool that mostly goes to LNP, and the model's 1.17-pt flip margin is inside normal error. If the One Nation level is too high statewide, ALP primary and TCP both move; if ONP preferences favour LNP more than the flow table says, ALP drops under 50%. Also onp-senate-vic2026.csv has Mordialloc Senate share 2.76% (curve fit sa2026, r2 0.87), a low base: the 18.4% rests mainly on the statewide level, not a local signal. Not checked (UNCONFIRMED): flow table for ONP->LNP in this seat; local web news.
Backtest (output/published-predictions.csv, 19,616 rows, 35 pairs): ALP primary over-called by +1.06 pts on average, LNP +0.52, GRN +0.83, ONP -0.46 (ONP under-called historically). ALP-favourite seats at 50-75% win prob: forecast avg 62.8%, actual 63.1% (n=233); LNP at 25-45%: forecast 34.4%, actual 36.9% (n=195). So the 62/33 split is calibrated in the band historically.
5. Pattern: model-wide, not seat-specific. Our LNP is 5 seats low statewide (39.1 vs 44-45) and Mordialloc is a Labor-held seat flipping to LNP in the markets only. The seat-specific part is just the thin margin: it sits on the ALP/LNP knife edge, so a small shift in statewide LNP moves it a lot. Resolving it needs the statewide ONP-vs-LNP question, not a Mordialloc fix.
