VERDICT: MODEL VIEW (contestable, not a defect). Our Greens 70% rests on Labor's primary falling 43.1 -> 22.7 (-20 pts) while Greens rise 22.4 -> 25.1; no bug found, but it is the model-wide "Greens high, Labor low" pattern plus one seat-specific input (Greens candidate's 2024 council result).

Table (win chance; forecast primary % in brackets for ours; 2022 actual primary: ALP 43.1, GRN 22.4, LNP 17.9, left IND/OTH 11.8):
| Party | Ours win (primary) | TAB | Sportsbet | AEF | TSIO |
| GRN | 70.0% (25.1) | 30.6% | 30.2% | 24.6% | 62.9% |
| ALP | 17.4% (22.7) | 63.6% | 59.9% | 66.6% | 31.7% |
| IND | 12.1% (17.7) | 1.8% "any other" | 3.8% "any other" | 1.4% | -- |
| ONP | 0.1% (9.0) | 1.8% | 3.8% | 3.1% | 2.1% |
| LNP | 0.1% (10.5) | 2.3% | 2.3% | 4.3% | 1.6% |
Sources: forecast-vic2026.json seat Footscray; docs/benchmarks/vic2026/2026-11-18/*-calls.csv. Note TSIO (62.9% GRN) agrees with us, so the market is not unanimous across models.

Mechanism (evidence):
- Starting result: 2022 ALP 43.1 (Katie Hall, sitting), GRN 22.4 (Elena Pereyra), TCP ALP 54.2 / GRN 45.8 (external/elections/archive/2022vic-firstprefs.csv, -tcp.csv). The Greens already got 45.8% two-party last time, so a 3.25-pt swing flips it (final_two swing_to_flip 3.25; Greens TCP median 53.25, q05 47.8).
- Statewide: forecast ALP 22.5 vs roughly 37 in 2022; Footscray ALP falls by more (-20). demo-resid ALP 0.62 / GRN 0.77 (output/demo-resid-vic2026.csv) and seat-swing-port coef 0.45 on a 4.4 fed swing (seat-swing-port-vic2026.csv) feed this; I did not decompose each piece.
- NO seat poll: output/seat-poll-blend-vic2026.csv has no Footscray row. Nothing anchors the seat to a measured Labor level.
- Candidate: Pereyra won a Maribyrnong council seat with 30.0% in 2024 (council-history-vic2026.csv). 13 Nov fix (PR #229) moved Footscray Greens to 0.519 (journal-2026-11-11-queue-history.md); other Greens/Labor inner seats (Pascoe Vale) were adjusted the same day. This is the main seat-specific push; the market may be underrating it, or may be right that council votes overstate state support (UNCONFIRMED).
- Independents: 4 IND candidates, ind_split false (Cumming, Dinh, Marsh, Ibrahim); IND 17.7% primary but only 12.1% win, and Footscray ind-split fit gives credible-count 1 of 4 (ind-split-fit-vic2026.csv). The IND class is LARGE (17.7) mostly from Cumming's old 7.7-14.9% history x 0.59 carry (log line CSV1). Not an Essendon-style sum-of-three bug here: IND win_prob is 12%, and Footscray was reviewed 18 Nov as "4, 17.7%, 0.12" (ind-split-armk-live-walk). Possible mild over-weight on IND, which would take votes from Labor/Greens, not decide the favourite.
- Search interest (vic2026-live-salience.csv): only Marsh (IND) and Lopez (ONP) rows, from 10 Sep; no direct effect on Greens/Labor.
- One Nation: senate_pct 1.8 (onp-senate-vic2026.csv) yet our ONP primary is 9.0; not decisive (win 0.1%) but a likely over-call of the statewide surge in a low-ONP seat.

Strongest argument against us: backtest. In published-predictions.csv Footscray's Greens were over-called in 2014 (+3.1) and 2018 (+3.8), under-called 2010 (-4.0) and 2022 (-3.1). Across 149 GRN seats forecast at 20%+ the mean error is +0.94 pts, win-called 27, won 33 (not over-called overall). Our 25.1 vs ALP 22.7 is a 2.4-pt gap inside wide intervals (GRN q05-q95 17.7-32.6; ALP 15.2-30.3), so 70% is confident for a seat with no poll. Labor also wins on preferences from a left-leaning IND/OTH field only if the Greens finish third, which our final_two gives 46.6% of paths.
Market may be missing: Pereyra's 30% council vote, the 45.8% Greens TCP already banked in 2022, and the statewide Labor slump. Market may be right about: sitting-member effect (Hall; Labor held 78% TCP in 2018) and no seat poll to confirm the collapse.

Model-wide or seat-specific: mostly the model-wide pattern (GRN 7.5 seats vs market 5.3; ALP ~23 all round) amplified by one seat-specific input (council result). Not a defect; the first thing to check if wanted: how much of the -20 Labor drop is demo-resid/seat-swing-port vs statewide (not decomposed here; no R run).
