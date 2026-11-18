# Bentleigh (Southern Metropolitan) - ours ALP 50.3% vs market LNP 71-79%
VERDICT: MODEL VIEW (leaning, not proven). No seat-specific bug found; the gap is Labor's sitting-member margin versus a statewide Labor collapse the market prices harder.

| Party | Ours primary % | Ours win | TAB | Sportsbet | AEF | TSIO |
|---|---|---|---|---|---|---|
| ALP (Staikos, sitting) | 33.8 | 50.3% | 25.4% | 16.9% | 27.4% | 46.9% |
| LNP (Putt) | 33.0 | 48.6% | 70.8% | 79.1% | 68.2% | 52.5% |
| ONP (Lonsing) | 15.4 | 0.9% | 2.5% | 3.1% | 4.2% | 0.5% |
| GRN (Proctor) | 13.4 | 0.2% | 0.6% | n/a | 0.2% | 0.04% |
Gap: ALP ours minus TAB +24.9 pts, minus Sportsbet +33.3 pts. LNP -22.2 / -30.5 pts. A coin-flip for us; the market has it a clear Liberal gain.
(forecast-vic2026.json seats[Bentleigh]; benchmarks/vic2026/2026-11-18/{tab,sportsbet,aeforecasts,theswingison}-calls.csv). Our final-two: ALP v LNP 97.1% of sims, ALP TCP median 50.07 (q05 43.5, q95 57.1); needs only a 0.07 swing to flip.

Mechanism (inputs):
- Start: 2022 ALP 45.8 / LNP 36.3 / GRN 10.7 on firstprefs; TCP ALP 58.0 (2022vic-tcp.csv). Staikos has held since 2014 (50.8, 61.9, 58.0 TCP).
- Our swing: ALP 45.8 -> 33.8 (-12.0); LNP 36.3 -> 33.0 (-3.3); GRN 10.7 -> 13.4; ONP 0 -> 15.4. ONP takes most of the lost ALP vote and little from the Liberals.
- Seat polls: none for Bentleigh (no row in output/seat-poll-blend-vic2026.csv). Seat search interest: no row in vic2026-live-salience.csv or ind-split-fit. Council history: all six candidates are new to council (council-history-vic2026.csv), so no local-candidate effect. No by-election covering it.
- ONP: onp-senate-vic2026.csv gives Bentleigh a Senate ONP vote of only 2.5%, but a floor_pct of 14.56 (source sa2026, n_fit 47, r2 0.87); our 15.4 is that floor. This is the model's statewide-surge shape, not local evidence. Worth checking: 2.5% to 15.4% is a big lift for a wealthy-ish bayside seat (UNCONFIRMED how the floor is applied here).
- seat-swing-port-vic2026.csv: fed_swing 2.90, coef 0.45; demo-resid ALP +0.36 (small positive for Labor).
- Statewide forecast ALP 22.5 (brief); our ALP at 33.8 here is +11 above that, reflecting a retained sitting-member and inner-south base.

Is it a defect? Checked: single-candidate fields (candidates = one name per party, no ind_split, IND 0 - no Essendon-type merge); correct candidates and incumbent flag (candidacies.csv vic2026 rows); results file correct (matches 2022 TCP). refresh.log has no Bentleigh lines. Nothing broken found.

Model view / evidence market may be missing: sitting member with a 58% TCP margin that grew in 2018; ALP-held on 8.0 TCP margin; the backtest hit this exact seat (vic2018: ALP 40.0 predicted vs 50.2 actual, a +10.2 under-call; vic2022: ALP 48.4 pred vs 45.8, over-call 2.6). Backtest mean ALP miss across all 88 seats: vic2018 +2.1 (under-called), vic2022 -1.1 (over-called) (published-predictions.csv), so no stable bias to correct.
Strongest argument against us: 12-point ALP primary drop yet a 50% win chance is only possible because we let ONP draw from Labor and not the Liberals; ONP preferences go mostly to LNP, so the ALP lead on TCP depends on an ONP vote of 15%. If ONP falls short here (Senate ONP is 2.5%), ALP primary rises and Labor wins more safely; if ONP is as strong, LNP gets its preferences and wins. Our ALP TCP q05-q95 straddles 50 by a wide margin; with no seat poll, the interval is wide and the market's lean may reflect Sportsbet/TAB pricing the statewide Labor loss as uniform (a uniform loss of ~14.5 pts would flip a seat held at 58 TCP only if the swing exceeds 8, which the market evidently assumes). UNCONFIRMED: whether any bookmaker has local knowledge (no web search done).

Pattern: mostly the model-wide one (ONP 21.5 statewide high, LNP low, ALP seats ~23 everywhere), plus a seat-specific piece: ONP of 15.4 in a seat where its Senate vote is 2.5%, and a Labor sitting-member margin the model credits more than the market. TSIO (46.9 ALP) agrees with us; AEF and bookmakers do not. Worth a look: how ONP floor_pct (14.56) was set for this seat.
