# Narre Warren South (Labor-held, SE Metro) - gap to the bookmakers

VERDICT: MODEL VIEW. Sportsbet already makes One Nation (ONP) favourite (36.6%); only TAB differs (favourite LNP 36.1%). No defect found: 8 distinct candidates, ind_split False, no merged-candidate pattern like Essendon.

| Party | Our primary % | Ours win | TAB | Sportsbet | AEF | TSIO |
|---|---|---|---|---|---|---|
| ONP (Trevor Hammond) | 24.5 | 48.4% | 29.3% | 36.6% | 15.4% | 69.3% |
| ALP (Stefan Koomen) | 30.4 | 30.5% | 33.5% | 27.8% | 37.1% | 10.6% |
| LNP (Norliah Peterson) | 23.2 | 20.2% | 36.1% | 34.4% | 47.0% | 19.7% |
| GRN / IND+OTH | 10.6 / 3.7 | 0.1% / 0 | 0.5% / 0.5% | - / 1.2% (any other) | 0.1% / 0.4% | 0.3% / 0.1% |
Gap (ours minus market): ONP +19.1 pts vs TAB, +11.8 vs Sportsbet; LNP -15.9 vs TAB, -14.2 vs Sportsbet. ALP -3 vs TAB, +2.7 vs Sportsbet. Every figure from forecast-vic2026.json and the 2026-11-18 *-calls.csv files. Raw odds row (bookmaker-odds.csv): best prices ONP 0.48 / LNP 0.35 book share.

MECHANISM (from the files)
- Starting point: 2022 first prefs ALP 48.0, LNP 28.7, GRN 6.6, minor right 13.6 (christian/freedom/Lib Dem), 2-party ALP 58.5 (archive/2022vic-firstprefs.csv, -tcp.csv). Sitting member Gary Maas is not a 2026 candidate (candidacies has no row; audit doc says retirement unconfirmable) so ALP sitting=False and the incumbent bonus is gone.
- Swing: seat-swing-port-vic2026.csv gives fed_swing 8.69 pts, coef 0.45 (n_fit 666). This is the anchor-file federal swing ported to the seat, and it drives ALP 48 -> 30.4.
- ONP level: statewide ONP 21.5; the seat gets 24.5 (primary_q 17.7-31.8). The Senate curve (onp-senate-vic2026.csv) puts ONP Senate vote here at 4.6%, floor 1.6%, fitted on sa2026 (n 47, R2 0.87) - ONP is not obviously strong on the old Senate vote, so the seat number comes from the statewide level plus the outer-suburban profile.
- Seat polls: none (seat-poll-blend-vic2026.csv has no row). Search interest: ONP Hammond sal_share 0 / raw 0; Scott Watson (IND) 100 / 12.5 (vic2026-live-salience.csv, fetched 2026-09-10). Council history: no candidate has any (council-history-vic2026.csv). So no local candidate evidence helps ONP.
- Result: three-way primary 30.4 / 24.5 / 23.2. ONP wins by preferences; final_two ONP v ALP p_pair 68.8%, ONP wins that pair 69.0%, swing_to_flip 1.75 pts, leader TCP median 51.75 (q05 45.6, q95 57.5). So 48% is a call on a 1.75 pt edge, not a safe seat.
- Neighbours show the same shape: Cranbourne ONP 37.7%, Narre Warren North ONP 20.2%, Pakenham ONP 91.9% (ours); markets rate Narre Warren North ONP 46.4% (TAB) / 29.2% (Sportsbet).

WHAT THE MARKET MAY BE MISSING (our view) AND THE ARGUMENT AGAINST US
- For us: this is an outer south-east suburb where a 13.6% minor-right vote in 2022 and a Labor exit of ~18 pts of primary leave a large pool that ONP can take; Sportsbet agrees on ONP. Backtest (published-predictions.csv, ONP rows, ours 20%+ primary, n=36): mean ours 25.4 vs actual 28.1, 6 won, mean p_win 0.18. So ONP at high forecast levels was under-, not over-called.
- Against us: (1) ONP has zero measured local profile here (no search interest, no council, no seat poll), the candidate is a one-name unknown; (2) the model's LNP primary of 23.2 is below 2022's 28.7 while TAB and AEF both put LNP first, and AEF has ONP at 15%; (3) ONP win probability rests on a 1.75 pt swing_to_flip with the preference flow to ONP not inspected in this pass.
- Not confirmed: whether Hammond or Koomen have any local profile (no web search done). UNCONFIRMED.

MODEL-WIDE OR SEAT-SPECIFIC
Mostly the model-wide pattern (ONP 15.8 expected seats vs 12.9 TAB / 13.6 Sportsbet; LNP 39.1 vs 44.3 / 44.8). Seat-specific parts: Labor's sitting member gone, an unusually large minor-right pool, and a very tight three-way. Our ONP call here is 19 pts above TAB, a bigger than average gap, but 12 pts above Sportsbet, which is closer to average.
Not run: no R, no seat trace (AUSPOL_TRACE_SEAT) - flows and the base_pred vs xgb split were not inspected, so the preference step is unverified.
