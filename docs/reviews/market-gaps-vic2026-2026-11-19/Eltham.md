# Eltham (North-Eastern Metropolitan), Labor-held (Vicki Ward, since 2014)
VERDICT: MODEL VIEW (leaning; no defect found, but the evidence is thin). The gap is the model-wide pattern, and Eltham has no seat-specific input pushing it.

Win chance (ours = forecast-vic2026.json; others = 2026-11-18 benchmark CSVs). Primary is ours only.
| Party | Our primary % | Ours win | TAB | Sportsbet | AEF | TSIO |
| ALP (Ward, sitting) | 30.8 | 49.9% | 32.7% | 32.0% | 28.3% | 48.0% |
| LNP (Paul Byrnes) | 31.7 | 47.9% | 56.4% | 58.8% | 65.1% | 48.0% |
| ONP (J. Weatherley) | 16.0 | 1.5% | 9.3% | 7.1% | 5.3% | 3.8% |
| GRN (R. Busbridge) | 15.6 | 0.6% | 0.8% | 1.0% | 1.3% | 0.1% |
Gap: ALP +17.2 pts vs TAB (+17.9 vs Sportsbet); LNP -8.5 vs TAB (-10.9 vs Sportsbet). We call it a coin flip; the books call it a Liberal lean.
TSIO matches us almost exactly; AEF is furthest from us. So the model split is not unanimous.

Mechanism (what drives our number):
- Start: 2022 primaries ALP 44.5, LNP 35.6, GRN 13.5 (external/elections/archive/2022vic-firstprefs.csv); 2022 TCP ALP 59.0 / LNP 41.0 (2022vic-tcp.csv). Labor won 2014, 2018, 2022.
- Swing: our ALP primary is -13.7 pts vs 2022. Statewide ALP forecast is 22.5% vs about 36.7% in 2022 (-14), so Eltham just takes the statewide Labor collapse. LNP 35.6 -> 31.7 (-3.9) matches the statewide LNP fall (about -3.8). ONP 0 -> 16.0, below the statewide 21.5.
- Seat polls: none. output/seat-poll-blend-vic2026.csv has no Eltham row. No seat-specific poll input.
- Other seat inputs are small: demo-resid ALP -0.15, GRN -0.29 (output/demo-resid-vic2026.csv); federal swing port 3.09, coef 0.45 (seat-swing-port-vic2026.csv); ONP Senate vote 2.77% (onp-senate-vic2026.csv, low). No leader-seat row. Candidate search interest: Eltham has no 2026 row in vic2026-live-salience.csv (grep found nothing).
- Why Labor wins on this primary split: ALP 30.8 vs LNP 31.7 is a Liberal lead on first preferences, but the final-two is ALP v LNP 94% of the time (p_pair 0.939) and Labor takes it 51.2% of those; leader TCP median 50.1 (q05 43.4, q95 57.1). Labor wins on the 15.6% Greens preferences. One Nation's 16% mostly flows to the Liberals. This is a knife-edge on flows, not a confident Labor call.
- Backtest: Eltham was called Labor correctly in 2014/2018/2022 (published-predictions.csv: p_win 0.84, 0.93, 0.985). It has not shown the model over-calling Labor here. In 2022 we over-predicted ALP (47.5 vs 44.5 actual) and under-predicted LNP (33.0 vs 35.6).
- Other reviews: salience-vic2026-live-walk-2026-11-12.md lists Eltham among seats that flip to LNP in the anchor (a different run), so the seat has been a near-coin-flip in earlier runs too. vic2026-sitting-member-audit-2026-10-25.md verifies Ward as sitting, with no retirement or candidate surprise.

Case for us (what the market may miss): Labor's 2022 base here was strong (TCP 59), and Greens preferences are large (13.5% in 2022, 15.6% forecast). Nothing here is hidden knowledge; the market may be pricing a larger Labor drop in an eastern, Liberal-leaning-historically seat. Strongest argument against us: ALP primary is forecast BELOW the Liberal primary, and One Nation at 16% hands the Liberals most of their preferences; a ~1.5 pt move in flows or primaries flips the seat. The model is carrying a lot of weight on the Greens-to-Labor flow, with no seat poll to check it. Also our ONP win chance (1.5%) is far below the market's 7-9%, which is the one place we are less ONP-friendly than the books.

Pattern: model-wide. We are high on ALP and Greens-flows, low on LNP, the same direction as the statewide pattern (ONP/GRN high, LNP low). Seat-specific: only that Eltham sits right at the knife edge, so the shared bias decides who the favourite is. TSIO agrees with us; AEF and the books do not.
UNCONFIRMED: no web search done on Byrnes or local news; nothing checked for 2026 Nillumbik/Eltham local factors.
