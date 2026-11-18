# Box Hill (ALP-held, Paul Hamer; North-Eastern Metropolitan)
VERDICT: MODEL VIEW (leaning; not fully proven). No data or pipeline defect found: all 8 candidates are present and unsplit (ind_split False), and the ALP lead rests on Greens preferences, not a bug.

| Party | Our primary % | Our win | TAB | Sportsbet | AEF | TSIO |
|---|---|---|---|---|---|---|
| ALP | 31.7 | 76.3% | 25% | 15% | 23.1% | 71.8% |
| LNP | 31.9 | 21.2% | (rest) | (rest) | 71.4% | 27.6% |
| GRN | 18.8 | 2.1% | - | - | 2.9% | 0.1% |
| ONP | 11.7 | 0.3% | - | - | 1.5% | 0.5% |
(AEF/TSIO read from the two calls files in docs/benchmarks/vic2026/2026-11-18; TAB/Sportsbet figures are from the brief. OTH_RIGHT 4.1, IND 1.2, OTH 0.7 in ours.)

Mechanism (forecast-vic2026.json, seat Box Hill):
- Starting point: 2022 Labor 41.3 / Liberal 35.2 / Greens 14.1 first prefs; TCP ALP 57.2 (2018: 52.1) (external/elections/archive/2022vic-*.csv).
- Statewide ALP level 22.5 (vs ~37 in 2022) drags Labor down only 9.6 points here; LNP down 3.3, GRN up 4.7, ONP 11.7 (onp-senate-vic2026.csv: Senate 1.46% from sa2026 curve, so ONP is not a seat-specific push).
- Result: ALP and LNP tie on primary (31.7 vs 31.9); ALP wins 76% because it is ~80% to win the two-candidate count against LNP (leader TCP median 53.4, q05 46.7, swing_to_flip 3.4), carried by 18.8% Greens preferences.
- No seat poll (grep of seat-poll-blend-vic2026.csv: 0 Box Hill rows; 8 lines total). Search interest: ONP candidate scores 100 of 12.5 raw, others 0 (vic2026-live-salience.csv), no effect on ALP/LNP. Greens candidate had 16.9% in the 2024 Whitehorse council vote (council-history-vic2026.csv). Demographic residual favours ALP +0.53 and GRN +0.43 (demo-resid-vic2026.csv). Federal swing port +3.0 (seat-swing-port).
- Sitting member Hamer holds a 57.2 TCP margin; LNP has a new candidate (Houguet, not sitting).

Strongest argument against us: the call is a coin flip on primaries; we give Labor a 76% edge only because Greens preferences all flow to Labor. If the Greens vote is lower or leaks to the minor right (ONP + OTH_RIGHT + DLP + Family First = ~16 points in ours), or the Liberals lead the primary by a few points, the seat flips. Box Hill was Liberal until 2018 (Robert Clark). Two rivals (AEF, bookmakers) read it Liberal; TSIO agrees with us.
What the market may miss: a 7.2-point 2022 TCP cushion (our median 53.4, 3.4 from flipping) in a seat where Labor TCP rose from 52.1 (2018) to 57.2 (2022).
UNCONFIRMED: local news, candidate quality (Houguet) and any boundary effect; not searched. Backtest track record of our model in comparable inner-east LNP-ALP seats not checked (published-predictions.csv not read beyond its header).

Model-wide or seat-specific? Mostly the model-wide pattern (low LNP, high GRN/ONP shares at the statewide level) with a seat-specific amplifier: a ~0-point primary gap resolved by the preference model. ONP is irrelevant here (0.3% win); the gap is about LNP vs ALP, not ONP.
