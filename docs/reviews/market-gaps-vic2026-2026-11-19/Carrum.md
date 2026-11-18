# Carrum (ALP 2022: Sonya Kilkenny, 49.9% first pref, TCP 59.8-40.2 vs Liberal)

1. VERDICT: MODEL VIEW (with a thin edge). No defect found in the inputs; the gap is the model-wide One Nation surge landing on a seat where Labor's 2022 lead is only moderate. Not verified by tracing code (no R allowed).

2. Win chance, then forecast first-preference % (ours only). Higher = more likely. Seat read from files.
| Party | Ours win | Ours primary % | TAB | Sportsbet | AEF | TSIO |
|---|---|---|---|---|---|---|
| ONP (Mathews) | 37.6% | 24.6 (q05-q95 17.8-32.0) | 17.6% | 14.8% | 15.1% | 27.0% |
| ALP (Kilkenny, sitting) | 32.7% | 31.7 (23.8-39.3) | 33.3% | 35.4% | 40.1% | 34.2% |
| LNP (Shelley) | 29.5% | 25.1 (17.3-32.4) | 47.8% | 48.8% | 44.6% | 38.7% |
| GRN / OTH_RIGHT / other | 0.1% / 0.2% / 0 | 9.9 / 3.9 / 4.8 | 0.4% / - / 0.9% | - / - / 1.1% | 0.2% / - / 0.04% | ~0 |
Gap: ONP ours 37.6 vs TAB 17.6 = +20.0 pts (vs Sportsbet +22.8). LNP ours 29.5 vs TAB 47.8 = -18.3 (vs Sportsbet -19.3). ALP is level with TAB (-0.6). So the disagreement is ONP vs LNP for the non-Labor lead, not about Labor.

3. Mechanism (files read):
- Start: 2022 firsts ALP 49.9, LNP 30.3, GRN 7.6, OTH_RIGHT 7.1 (Freedom 4.0 + Family First 3.1), OTH 2.8, IND 2.3 (external/elections/archive/2022vic-firstprefs.csv). 2022 TCP ALP 59.8 / LNP 40.2 (2022vic-tcp.csv).
- Forecast has ONP 24.6 and LNP 25.1 level, ALP down 18 points to 31.7. ONP's 24.6 is rank 24 of 88 seats (our ONP mean statewide 21.5%), so Carrum is mid-pack, not an outlier.
- Seat inputs: no seat poll (seat-poll-blend-vic2026.csv has 0 Carrum rows). No live search-interest rows (vic2026-live-salience.csv has none). ONP's federal Senate vote here 4.92% vs state median 3.59% (rank 28th highest of 88; onp-senate-vic2026.csv), a mild above-average ONP seat. Candidate Mathews has no council history (council-history-vic2026.csv). Port from federal swing 0.86, coef 0.45 (seat-swing-port-vic2026.csv). Demographic adjustment small (ALP -0.20, GRN -0.22; demo-resid-vic2026.csv).
- No independent, ind_split False; 3 minor OTH candidates (VS, AJP, Cannabis) counted separately, so no Essendon-style merge. Not a candidate-count defect.
- Final-two: ONP vs ALP 56.9% of sims; ONP wins that pairing 64.6%; ONP TCP median 51.4, swing to flip 1.38 pts (forecast.json final_two). ALP wins only 32.7% overall, so we think Labor is genuinely beatable.

4. MODEL VIEW. What the market may be missing: our ONP statewide level is 21.5% versus the market's implied ONP seat count (12.9-13.6 vs our 15.8). A seat that went 49.9% Labor only needs a 14-point ALP fall to be level, which our statewide ALP 22.5 implies. Strongest argument AGAINST us: (a) ONP's 24.6 is first-time, no council or seat-poll support, and backtest ONP over-prediction in 5-50% prior-share seats is +2.1 pts (n=140 ONP rows with ours>10, published-predictions.csv), so Carrum ONP may be ~2 pts too high, enough to flip it; (b) we give the Liberals only 29.5% although they are level on primaries (25.1 vs 24.6) and held 40.2% TCP in 2022, whereas all four rivals give LNP the most; the LNP-ONP split of the anti-Labor vote is our weakest link (preference flow ONP-to-LNP not checked here); (c) the market and AEF both rate ONP only 15-17%, so we are the outlier of the 5 except TSIO (27%).

5. Pattern: model-wide ONP-high / LNP-low pattern (ONP 15.8 vs 12.9-13.6 seats; LNP 39.1 vs 44.3-44.8), applied to a seat with average ONP signal and no seat-specific evidence either way. Nothing seat-specific found. UNCONFIRMED: web check of local candidates not done; preference flows and the 0.86 federal swing coefficient not traced to code.
