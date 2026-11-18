# Wendouree (Ballarat, Western Victoria): ours ONP 42% favourite; TAB ALP 36%, Sportsbet ALP 45%

VERDICT: MODEL VIEW. A genuine three-way seat; the gap is the model-wide One Nation surge plus Labor's 2022 base falling away. No defect found (one candidate per party, ind_split false, no duplicated candidates).

Probabilities are win chances, forecast primary in brackets (percent, ours only; higher is better for that party).
| Party | Ours win (primary) | TAB | Sportsbet | AEF | TSIO |
|---|---|---|---|---|---|
| ONP | 42.4% (24.6) | 30.4% | 31.4% | 13.2% | 46.1% |
| LNP | 34.0% (25.4) | 32.4% | 22.5% | 32.5% | 33.5% |
| ALP | 23.1% (29.2) | 35.7% | 44.6% | 54.0% | 19.7% |
| GRN | 0.3% (12.6) | 0.6% | n/a | 0.3% | 0.6% |
Gap on ALP: -12.6 pts vs TAB, -21.5 vs Sportsbet. ONP +12.0 vs TAB, +11.0 vs Sportsbet. TSIO is MORE One Nation than us.
Source: forecast-vic2026.json seats[Wendouree]; docs/benchmarks/vic2026/2026-11-18/*-calls.csv.

Mechanism (what drives our number)
- Start: 2022 first prefs ALP 47.6, LNP 29.7, GRN 10.4, others ~12 (external/elections/archive/2022vic-firstprefs.csv); 2PP ALP 63.5 (2022vic-tcp.csv). Sitting member Juliana Addison (ALP) re-contesting (candidacies; sitting-member audit 25 Oct).
- Forecast ALP primary 29.2 = down 18.4 pts from 2022 (statewide ALP 22.5 forecast). ONP 24.6 has no 2022 vote; the new-seat rule allocates ONP by Senate rank: Wendouree Senate ONP 5.17% (output/onp-senate-vic2026.csv), rank 27 of 88; our ONP primary rank is 26 of 88. So it is mid-pack, not an outlier.
- Seat polls: none (output/seat-poll-blend-vic2026.csv has no Wendouree row). Council history: none for any candidate. Leader-seat bonus: none. Demographic adjustment tiny (ALP -0.55, demo-resid-vic2026.csv).
- Search interest: ONP candidate Stuart Robinson sal_raw 12.5, share 100 (vic2026-live-salience.csv, fetched 10 Sep). 12.5 is the same default value shared by about 15 other ONP candidates in that file, so it carries no seat-specific signal.
- Result: ALP leads on primary but is squeezed on the final count. Median ONP-v-ALP 2CP is ONP 52.4 (q05 46.0, q95 58.0); swing to flip is 2.4 pts; P(ONP beats ALP in a ONP-ALP final) 0.75; that pairing occurs 55% of the time. The seat is a coin flip across three parties, and 42/34/23 reflects ONP and LNP each taking the other's preferences better than ALP does.

Why the market may be missing it (model view)
- Statewide ONP 21.5% forecast vs market-implied seats 12.9 to 13.6 vs our 15.8. Wendouree sits in the Ballarat belt with a ~5% federal Senate ONP vote, roughly one-third of the way up the state ranking, so it is a mid-profile ONP seat.
- Strongest argument AGAINST us: 2022 ALP margin was 13 pts on 2CP; the model removes 18 pts of primary vote on the strength of a statewide swing alone, with no seat poll to confirm it. ONP primary 24.6 has no local test (no ONP candidate here in 2022, no council record, default search interest). AEF puts ONP at 13% and ALP at 54%, and Sportsbet has LNP at only 22%. Our own q05-q95 for ALP primary (21.5 to 36.6) and the 2.4-pt flip margin show the call is fragile.
- Track record: the only ONP-surge backtest, sa2026 (output/published-predictions.csv, ONP rows with forecast primary at least 18, n=26) had mean forecast 25.3 vs actual 28.4, and sum of ONP win probabilities 4.81 vs 4 wins. That is mildly under-called on share and about 0.8 seats over-called on wins, n small; it does not show systematic over-calling. Not checked: wa2025 and qld2024 gave no rows meeting that cut.

Model-wide or seat-specific
- Mostly the model-wide pattern (ONP and GRN high, LNP and ALP low): our ONP expected seats 15.8 vs 12.9 / 13.6 for TAB / Sportsbet. The seat-specific part is only that the ONP/LNP/ALP three-way is evenly balanced here, so a small statewide shift flips the favourite. If statewide ONP were nearer the market's view, ALP would return to favourite here. The Wendouree ALP deficit was also flagged earlier (seat-outperf-missing-from-live-model-2026-09-17.md: "Wendouree ALP +0.134", read as a seat-level ALP effect missing from the live model; I did not trace the full context).
- Not checked: web candidate or news context (no search done); fitted ONP flow numbers for this seat (log has no Wendouree lines).
