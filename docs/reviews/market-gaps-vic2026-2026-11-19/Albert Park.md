# Albert Park (Southern Metropolitan): our GRN 49% vs bookmakers' ALP
1. VERDICT: MODEL VIEW (weakly defensible, high variance). No defect found; the gap is the model-wide Labor-collapse/Greens-high pattern landing on a three-way seat. Not checked: the exact flow/preference path (no R allowed).
2. Table (primary% -> win%). Ours from forecast-vic2026.json; others from 2026-11-18 *-calls.csv (no primary for the others):
| Party | Ours primary | Ours win | TAB | Sportsbet | AEF | TSIO |
| ALP (Nina Taylor, sitting) | 24.5 | 37.1 | 63 | 55 | 40 | 81 |
| GRN (Sonya Semmens) | 24.9 | 49.0 | 18 | 15 | 16 | 5 |
| LNP (Andrew Cook) | 26.9 | 11.6 | 16 | 22 | 38 | 13 |
| ONP (Tam Lindrum) | 11.1 | 0.4 | 1 | 7 | 4 | 1 |
| IND (Dragwidge, King) | 10.8 | 2.0 | 2 (any other) | 2 | 1 | ~0 |
(Sportsbet ALP/LNP/GRN = 54.6/22.1/15.0; TAB 63.2/15.6/18.1; AEF 40.5/38.2/16.1; TSIO 80.7/12.5/5.2.)
3. Mechanism:
- Start, 2022 (external/elections/archive/2022vic-firstprefs.csv): ALP 36.4, LNP 29.8, GRN 20.9, IND (Dragwidge) 5.9. 2018: ALP 43.4, LNP 31.3, GRN 16.6.
- Our 2026 primaries: ALP -11.9, GRN +4.0, LNP -2.9, ONP +11.1 (new), IND +4.9. Statewide levels (ours) ALP 22.5, GRN 14.3, ONP 21.5; ALP is down about 14 statewide, so the seat's ALP fall is in line, not an outlier.
- NO seat poll for this seat (no Albert Park row in output/seat-poll-blend-vic2026.csv). So it is statewide swing plus demographics: output/demo-resid-vic2026.csv adj ALP 0.66, GRN 0.77; output/seat-swing-port-vic2026.csv coef 0.45 (fed swing 1.39).
- ONP 11.1%: driven by the statewide surge, not local evidence. output/onp-senate-vic2026.csv puts the seat's federal ONP Senate vote at only 1.7%; floor 1.6%. Salience file output/vic2026-live-salience.csv has "Tammy Lindrum" (sal 100, raw 12.5, fetched 10 Sep), but the candidate is "Tam Lindrum": possible name mismatch, small effect UNCONFIRMED. ONP only 0.4% to win, so it matters only as vote it takes from the LNP/ALP.
- IND 10.8%: Dragwidge (5.9% in 2022) plus Adrian King (25.7% in the 2024 Port Phillip council poll, council-history-vic2026.csv). Not a split bug: ind_split=False, fit gives 2 candidates, 1 credible (ind-split-fit-vic2026.csv); IND win 2%.
- Result is a near three-way tie (24.9/24.5/26.9). Final two is GRN v LNP in 56% of sims; GRN wins that pair 84% (TCP median 53.8, q05-q95 47.1-58.9). That route is the whole GRN lead. It needs LNP to finish ahead of Labor, then Labor preferences to flow to the Greens.
4. MODEL VIEW. Evidence the market may be missing: Labor's statewide collapse (22.5%) falls on a seat Labor held on only 36%, and the Greens have Prahran-type inner-city momentum (Prahran by-election, Feb 2025: Greens 36.2 vs Liberal 36.2; external/reference/byelections/byelection-results.csv). Strongest argument against us: (a) the 84% GRN-beats-LNP conditional rests on preference flows with no local poll; (b) Labor is the sitting member with 2022 primary 36.4 vs GRN 20.9, a 15.5-point gap we close entirely on the statewide model; (c) markets (TAB 63%, TSIO 81%) price Labor's incumbency and Port Phillip base; (d) LNP is the seat's biggest primary at 26.9% yet only 11.6% to win, which only holds if Labor and Greens preferences stack against it. Our own 3 Oct run had ALP 78% / GRN 15% (docs/reviews/abc-vic-coverage-forecasts-2026-10-03.md): the 40-point move since then is statewide-level movement, so it is volatile. AEF (ALP 40 / LNP 38 / GRN 16) agrees with us on a very uncertain seat but disagrees on who is second.
- Backtest check (output/published-predictions.csv, GRN ours 18-32 with prior share 15-26, n=151): mean over-call 1.0 points; ONP 6-16 (n=366): 0.3 points over. No large historic bias.
5. Mostly the model-wide pattern (ONP and Greens high, Labor and Coalition low), not seat-specific. Seat-specific pieces: no seat poll; thin ONP-evidence (senate 1.7%); the three-way spread makes the favourite fragile. Our GRN 49% is "favourite" by a few points, not a strong call. Web search not used.
