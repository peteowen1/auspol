VERDICT: MODEL VIEW (fragile). No bug found; the gap is a ~3.6-point difference in Greens-vs-Labor two-candidate vote, and the market is mostly pricing Labor incumbency/history.

| Party | Ours primary | Ours win | TAB | Sportsbet | AEF | TSIO |
|---|---|---|---|---|---|---|
| GRN | 28.1 | 69.5% | 38.6% | 36.3% | 32.8% | 25.4% |
| ALP | 25.7 | 29.3% | 56.7% | 54.8% | 55.1% | 70.1% |
| ONP | 13.6 | 0.4% | 1.4% | 4.9% | 6.7% | n/a |
| LNP | 16.0 | 0.4% | 2.5% | 2.8% | 5.3% | n/a |
(source: forecast-vic2026.json seats[Pascoe Vale]; benchmarks/vic2026/2026-11-18/*-calls.csv). Others 13.6 (five candidates), OTH_RIGHT 2.9.

Mechanism:
- Start: 2022 first prefs ALP 38.8, GRN 22.4, LNP 21.0, others 17.8 (external/elections/archive/2022vic-firstprefs.csv). 2022 TCP was ALP 52 / GRN 48 (2022vic-tcp.csv), i.e. already near a coin-flip.
- Statewide levels (ALP 22.5 vs about 36.7 in 2022) take Labor down 13.1 here to 25.7. Greens go up 5.7 (statewide only +2.8): seat is inner-north with demographic residual GRN 0.75 / ALP 0.50 (output/demo-resid-vic2026.csv) and a Greens candidate who is a sitting Merri-bek councillor, 27.3% at the 2024 council election (output/council-history-vic2026.csv). Seat swing port: coef 0.45 on fed swing 5.66 (seat-swing-port-vic2026.csv).
- No seat poll for Pascoe Vale (no row in seat-poll-blend-vic2026.csv; only 8 lines total). So nothing local anchors it.
- One Nation: Senate vote 14.6% curve-implied (onp-senate-vic2026.csv), forecast 13.6 primary. ONP/LNP are not contenders, so this seat is not driven by the ONP surge itself; the effect is indirect (it eats Labor/Coalition share and leaves Greens vs Labor decided on preferences).
- Final two: GRN v ALP p_pair 64%; Greens TCP median 51.56 (q05 45.6, q95 58.1), swing_to_flip only 1.56 points. 66% Greens given that pair = 69.5% overall.
- Others: five minor candidates, 13.6% total, in line with 2022 (about 15%). The 11/18 ind_split fix did lift Greens here (57.9% -> 69.5%, docs/backlog/journal-2026-11-11-queue-history.md) by correctly treating them as five separate candidates, not one. ind_split=false now; no IND class. The Yildiz carry (23.5% in 2018) is credited to Essendon, not here.

Strongest argument against us:
- Incumbent Labor MP (Cianflone, sitting: true) held 52-48 TCP in 2022, and the model's 3.6-point TCP flip comes from a statewide Labor collapse applied to this seat; we have Greens ahead on primary (28.1 v 25.7) after Labor falls 13 points. Labor "~23 seats everywhere" implies the market thinks Labor holds its inner-north heartland.
- Backtest on Greens in seats with prior share >=18% (n=30, published-predictions.csv, vic2010-2022): our primary runs +1.8 points too high on average (e.g. Northcote 2022 predicted 38.3, got 30.0, p_win 82% and lost). Where we gave Greens >0.4 win chance, they won 7 of 9 (78%) vs 85% stated, so mild over-confidence, small n.
- The Greens could win the primary but still lose on Labor-leaning preferences from LNP/ONP/Others; the market can see the preference pattern, we use fitted flows (UNCONFIRMED here, flows not inspected).

Not confirmed: local news/candidate strength (no web search done). TSIO at 25% is the most extreme: it, like the 4 other sources, favours Labor.

Model-wide or seat-specific: the model-wide Greens-high / Labor-flat pattern (ours 7.5 GRN seats vs market ~5.2) applies, but this seat is the sharpest case because a 3.6-point TCP difference flips a near-tie from 40% to 70%. Seat-specific part is the council-incumbent Greens candidate and demographic residual; both are defensible but untested here. Treat 70% as overconfident; the backtest suggests shading toward ~55-60%, but that is my judgement, not a measured recalibration.
