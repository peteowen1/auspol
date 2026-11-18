# Hastings (Eastern Victoria): ours ONP 65% vs bookmakers' LNP ~71-75%
1. VERDICT: MODEL VIEW (no defect found; fragile, rests on the statewide One Nation level). Candidates are one each, ind_split False, no multi-candidate merge; ONP and LNP are only 2.4 points apart on primary (31.6 vs 29.2).
2. Win chance (primary %) - ours from forecast-vic2026.json; others from 2026-11-18 *-calls.csv:
| Party | Ours win (primary) | TAB | Sportsbet | AEF | TSIO |
| ONP | 64.7% (31.6) | 19.9% | 21.7% | 16.9% | 8.7% |
| LNP | 34.5% (29.2) | 75.0% | 70.6% | 72.9% | 73.8% |
| ALP | 0.7% (23.4) | 4.6% | 6.0% | 9.4% | 17.2% |
| GRN | 0.1% (10.5) | 0.3% | 0.8% | 0.2% | 0.1% |
(Other: IND Smart 1.1, OTH Coulson+Denman 4.3. Final two ONP v LNP 52%; ONP TCP median 50.2, q05-q95 45.5-55.9, so a near coin flip within the pair.)
3. Mechanism:
- Start: 2022 Labor (Mercurio, sitting) won on TCP 51.4-48.6 (2022vic-tcp.csv); primaries LNP 39.8, ALP 37.3, GRN 10.0 (2022vic-firstprefs.csv). Hastings is a marginal Labor seat, not a Coalition one.
- Level: statewide forecast ONP 21.5 (forecast json statewide[]). Hastings ONP 31.6 = about +10 over statewide, an ONP-heavy outer seat. Rank 10th of 88 on ONP primary.
- ONP seat profile: onp-senate-vic2026.csv Hastings 6.60% (15th of 88; state-wide Senate ONP is low, so this is only mildly above average). Our ONP/Senate ratio 4.79 sits mid-range of comparable seats (Pakenham 5.74, Bass 4.67, Eureka 4.15, Ripon 3.79). Not an outlier.
- No seat polls (Hastings absent from seat-poll-blend-vic2026.csv); no search-interest rows (vic2026-live-salience.csv has no Hastings row); no council history for any candidate (council-history-vic2026.csv, all FALSE); fed swing port 1.94, coef 0.45 (seat-swing-port-vic2026.csv).
- Candidate: ONP Peter Angelico is a nominated, unsourced newcomer (candidacies.csv line 19307, vec_official). LNP Frank Schiefler also new (Hutton did not recontest). Labor ALP primary 23.4 is a ~14-point fall from 37.3, the model-wide Labor collapse.
- Earlier snapshot: 22 Oct ours ONP 52 / LNP 44 / ALP 3; rose to 65 by 19 Nov as statewide ONP rose (ours-calls.csv 2026-10-22).
4. MODEL VIEW: the market may be pricing Hastings as a Liberal-leaning seat (LNP led 2022 primaries) and discounting an untested ONP candidate; we price the statewide ONP surge landing on an outer fringe seat with Labor collapsing, so the first-preference race is ONP 31.6 v LNP 29.2 and flows decide. Strongest argument against us: no seat poll, no local-profile feature (salience, council) supports Angelico; the whole gap is the 10-point ONP lift over statewide, which depends on the ONP statewide level (21.5, vs bookmakers' lower ONP seat count 12.9-13.6). Also LNP preferences should heavily favour ONP? We have not traced flows (UNCONFIRMED). The 28 Oct review (contested-seats-vic2026-2026-10-28.md, lines 59-75) held the same call and noted the 'no candidate named' worry; that is now resolved (candidate named). Track record: ONP backtests under-call rather than over-call (sa2026 -3.1 pts over 24 high seats, 4 won vs 4.8 expected; qld2017 -3.7, 9 seats, 0.91 expected, 1 won; published-predictions.csv), so history does not say we over-call ONP.
5. Pattern: model-wide ONP-high / LNP-low pattern, not seat-specific. Nothing special in Hastings beyond being a marginal-Labor outer seat with a mid-high ONP Senate base. Nearby seats with the same split (Bass, Pakenham) show the same direction. Not checked: LNP/ONP flows, web candidate news (not searched).
