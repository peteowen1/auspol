# Macedon (Northern Victoria), Labor-held, Mary-Anne Thomas not standing (Annette Death for ALP)
VERDICT: MODEL VIEW (weak, close to a coin-flip on who is the favourite). No defect found; ONP 41% / LNP 32% / ALP 21% is a three-way tie on primaries.

| Party (candidate) | Our primary % | Our win | TAB | Sportsbet | AEF | TSIO |
|---|---|---|---|---|---|---|
| ONP (Parolin) | 22.0 | 40.5% | 22.9% | 20.2% | 5.1% | 24.7% |
| LNP (Kendall) | 22.8 | 32.1% | 61.4% | 66.5% | 63.4% | 50.6% |
| ALP (Death) | 24.1 | 21.2% | 14.4% | 11.4% | 27.7% | 23.2% |
| IND (Bonanno, Seton) | 11.4 | 4.7% | 0.9% (any other) | 1.0% | 2.4% | n/a |
| GRN (McRae McLeod) | 13.7 | 1.2% | 0.5% | 0.9% | 1.4% | 1.4% |
Source: forecast-vic2026.json Macedon row; docs/benchmarks/vic2026/2026-11-18/*-calls.csv.

Mechanism (evidence):
- Starting point 2022 firsts (external/elections/archive/2022vic-firstprefs.csv): ALP 41.4, LNP 30.0 (Dominic Bonanno), GRN 12.5, IND 5.4, ONP 3.6. 2022 TCP ALP 59.5 / LNP 40.5 (2022vic-tcp.csv).
- Our LNP primary falls 30.0 -> 22.8 and ONP rises 3.6 -> 22.0, in line with statewide levels (LNP 30.7, ONP 21.5). ALP 41.4 -> 24.1.
- Dom Bonanno, the 2022 Liberal candidate, now runs as an Independent (output/candidacies.csv vic2026 rows) with a second IND (Seton). Our model gives IND 11.4%, taking right-of-centre vote from the Liberal. Markets give independents ~1%.
- Seat polls: none for Macedon (seat-poll-blend-vic2026.csv has only a 'macedon=0.0128' entry in a shared weights field, no row). Live search-interest file has no Macedon row either. So no seat-level evidence moves it; it is statewide model plus 2022 base.
- ONP Senate profile (output/onp-senate-vic2026.csv): Macedon 4.9% vs median 3.6%, rank 60 of 88 (above-median, not exceptional). Our Macedon ONP primary 22.0 vs statewide-seat median 20.3 (rank 51 of 88): near the middle.
- Win chance comes from preferences more than primaries: final_two ONP v ALP in 49% of runs, ONP wins that pair 76% (median ONP TCP 52.8%, swing_to_flip 2.8). LNP leads on primary only 22.8 vs 22.0, so LNP-vs-ONP is a coin-flip, then ALP/ONP preferences decide.
- Bookmakers may be pricing the Liberal as the natural consolidator of the anti-Labor vote (LNP was 43.1% first prefs in 2014 and Bonanno still got 30.0% in 2022; output/ files). UNCONFIRMED, no web check. TSIO (LNP 50.6 / ONP 24.7 / ALP 23.2) is closest to us in shape.

Strongest argument against us: a 3-point ONP-to-LNP primary gap is within noise and our own 5-95% bands overlap fully (ONP 15.3-29.7, LNP 15.1-30.1); we assume ONP wins ~55% of the Liberal-ONP head-to-head and ALP voters preference ONP above LNP, while the model has no seat poll and no ONP organisation signal (candidate Parolin: UNCONFIRMED, no web check made). Backtest (output/published-predictions.csv, ONP rows, n=101 with predicted share 15-30): mean forecast p_win 4.3% vs actual 4.0%, share bias -1.7 (we UNDER-called ONP share); in the 9 rows with p_win 0.2-0.6 mean p 31.6% vs actual 22% won (tiny n, over-call, weak). So no sign of a systematic ONP over-call at these levels, but the sample of genuine contenders is small.

Model-wide vs seat-specific: mostly the model-wide ONP-high / Coalition-low pattern (ONP 22 vs statewide median seat 20; LNP down 7 pts, same as statewide). Seat-specific piece: the Bonanno IND splitting the right (our IND 4.7% win is small; not a bug like Essendon: ind_split=False, two IND candidates carried as one IND class, 11.4% total is plausible for a former Liberal candidate). Not checked: whether Bonanno's 11.4% is too high (no 2022 IND of that size; ind-split-fit shows Macedon IND pts_cred 1.13).
