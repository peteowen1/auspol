# Essendon: ours IND 65% (Yildiz) vs market LNP 47%

1. VERDICT: UNCLEAR, leaning partial DEFECT (over-call). The 18 Nov split fixed the one-candidate bug, but the class total it splits (22.4) is still inflated by "three candidates" and one councillor's vote, and Labor's 11% is far below any rival's.

2. Table (win chance; ours primary = forecast first-preference %). Source: forecast-vic2026.json Essendon; benchmarks/vic2026/2026-11-18/*-calls.csv
| Party | Ours primary | Ours win | TAB | Sportsbet | AEF | TSIO |
|---|---|---|---|---|---|---|
| IND (class of 3; Yildiz leads) | 22.4 (class total) | 64.7 | 7.5 (any other) | 9.5 (Yildiz) | 13.8 | n/a |
| LNP Le Deux | 22.2 | 15.0 | 46.9 | 47.0 | 38.0 | 42.4 |
| ALP Theodosis | 19.8 | 11.0 | 35.6 | 32.3 | 37.2 | 9.7 |
| GRN Williams | 17.3 | 6.7 | 0.7 | 2.2 | 1.3 | 17.6 |
| ONP Barnes | 14.8 | 2.6 | 9.3 | 6.1 | 9.7 | 28.0 |
Note TSIO also has Labor at 9.7, so our Labor view is not unique; the three Labor-friendly sources (TAB, Sportsbet, AEF) are all ~32-37.

3. Mechanism (docs/reviews/essendon-ind-trace-2026-11-18.md, a trace at the published config; refresh.log lines 17111, 17218, 17278):
- 2022 result: ALP 41.1 / LNP 29.5 / GRN 15.2, TCP ALP 62.5 (2022vic-firstprefs/-tcp.csv). Sitting member Danny Pearson retired (candidacies.csv: no incumbent; web: Wikipedia via search). Labor is an open seat with a new candidate.
- IND class: nobody independent in 2022. Own-vote substitute: Yildiz 23.5 in Pascoe Vale 2018 x carry 0.592 = 13.9 (refresh.log 17111). Base 11.5 before the xgb trees, 22.6 after (+13.2): search-interest rise `jump` +4.0 (live-salience.csv: Yildiz 9.2, jump 0.875), `n_cand_now`=3 +3.7, council_pct 45.9 (Ava Adams, Moonee Valley 2024; council-history-vic2026.csv) +2.3, council_elected +1.0.
- Labor 19.8 = -21 points on 2022 against a statewide ALP forecast of 22.5 (about -14.5); the extra ~-6.5 is independents and One Nation (ONP 14.8, matches onp-senate-vic2026.csv 14.6) taking Labor's open-seat vote.
- Split (ind_split true, CLS3 gate: 2+ independents with a record): the class total is NOT changed (walk doc: primary ranges unchanged); the junior takes 0.01-0.50 of the class, so Yildiz holds roughly 50-99% of 22.4, i.e. ~11-22 points. Final two IND v LNP in 34.5% of sims, leader wins that 97% (TCP median 56.2).
- No seat poll for Essendon in seat-poll-blend-vic2026.csv. No Essendon row in byelection data used.

4. Why I do not call it clean MODEL VIEW:
- Double counting: the trees add +3.7 for "three candidates in the class" and +2.3 for Adams's council vote, then the split hands the leader most of that total while Yildiz's own record is the 13.9 carry. Adams (the local councillor, 45.9% in 2024) is not the one credited as leader; Yildiz is a Merri-bek councillor from a neighbouring ward (web: ABC/Wikipedia search result), his Pascoe Vale 2018 vote is a different seat. The prereg's own backtest: several-independents seats were over-called 29.9 vs 23 won (z -2.6) BEFORE the split; the post-split calibration is not in the files I read (UNCONFIRMED).
- Roughly 5-6 points of the class total are structural (n_cand + council) and would go if the class were scored per person; that alone would put the leader near 14-16, level with ONP/GRN, not clearly top-two. Our own p_pair is only 34.5%, so 65% rests on winning from other pairings (IND v ALP/GRN) too.
- Strongest defence of our view: four-way race at 15-22 each, Labor open seat, ONP/GRN both polling well, search interest for Yildiz rising, a 56% TCP vs LNP needs only a modest preference lead. The market has no good price for IND (TAB lumps it into "any other"), and Sportsbet's single price for Yildiz is 9.5%.
- Strongest argument against us: every rival (including the one with 13.8) is 5x lower; Labor at 11% despite 62.5% TCP in 2022 is hard to defend on the data (3 of 4 outside sources 32-37%).

5. Pattern: Not the model-wide ONP/GRN pattern (our ONP 2.6% here, below the market's 6-9%; GRN 6.7 vs 1-2 is the usual Greens-high pattern, minor). The gap is seat-specific: independent class and Labor. Suggested follow-up: score the lead independent's own primary (print it) and re-run with n_cand_now fixed at 1 for the split seats; if the lead IND drops under ~15 the 65% should fall toward ~40%.
Evidence limits: I did not run R; the lead IND's own simulated primary was not available in any file (UNCONFIRMED).
