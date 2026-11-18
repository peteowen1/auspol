# Frankston (ALP-held, Paul Edbrooke) - ours ONP 42.1% / LNP 35.8% / ALP 21.3%

1. VERDICT: MODEL VIEW (weakly; leaning to UNCLEAR on flows). No bug found: the seat is a three-way tie on primaries and ONP wins because it is the likelier final-two leader. The one input I could not read is the preference flow behind that (UNCONFIRMED, the flow model is not in a CSV).

2. Table (win chance; ours first, then bookmakers and rival models; sources: forecast-vic2026.json, benchmarks/vic2026/2026-11-18/*-calls.csv)
| Party | Our primary % | Ours | TAB | Sportsbet | AEF | TSIO |
| ONP (Paul Stafford) | 23.4 (q05-q95 16.7-31.0) | 42.1 | 21.8 | 19.0 | 16.9 | 32.3 |
| LNP (Bree Ambry) | 24.6 (16.9-32.2) | 35.8 | 43.8 | 44.9 | 52.4 | 40.6 |
| ALP (Edbrooke, sitting) | 27.4 (19.9-35.4) | 21.3 | 33.6 | 34.7 | 27.8 | 25.4 |
| GRN | 12.4 | 0.4 | 0.4 | - | 2.3 | 1.5 |
Gap vs TAB / Sportsbet: ONP +20.4 / +23.1 points, LNP -8.0 / -9.1, ALP -12.3 / -13.4. TSIO is nearer to us (ONP 32%).

3. Mechanism
- Past results (external/elections/archive): 2022 ALP 41.6, LNP 29.4, GRN 12.7; TCP ALP 58.7 / LNP 41.3. 2018 ALP 45.9 / LNP 32.7. Labor safe on 2022 numbers; the whole gap is the 2026 swing.
- No seat poll: seat-poll-blend-vic2026.csv has 0 Frankston rows. No search-interest row: output/vic2026-live-salience.csv (44 rows) has no Frankston or Stafford/Ambry. salience-vic2026-live-walk-2026-11-12.md line 39 shows Frankston flipped LNP 0.410 -> ONP 0.429 when the salience feature went on, so it is a tiny, near-tie move, not the driver.
- ONP level: statewide 21.5 (forecast). Seat ONP 23.4, ranked 32nd of 88 ONP primaries (Narracan 39.5 top). Not an outlier. Federal Senate ONP here is 4.37% (output/onp-senate-vic2026.csv; rank 36/88, state top is Morwell 12.0), so the seat has a below-average ONP profile; ONP had no 2022 vote here, so the new-seat rule allocates by Senate rank (published_flags.R AUSPOL_ONP_NEWSEAT_RULE=1, ONP_ORDER=senate_rank).
- Labor 27.4 (-14 vs 2022) and LNP 24.6 (-5) both fall; statewide ALP 22.5, LNP 30.7. A 3.0-point spread across the top three, so the win goes to whoever is in the final two.
- Final two (forecast json): ONP v ALP in 52.8% of sims; ONP beats ALP 76.8% (TCP median 52.7). ONP wins by taking LNP-leaning preferences; the flow table is not in a CSV here, so this is UNCONFIRMED.
- Candidates: ONP Paul Stafford, a first-time ONP candidate here (output/candidacies.csv: only a 2026 row); ind_split false, IND 4.5 across 3 candidates (no Essendon-style merge).

4. MODEL VIEW: what the market may be missing: ONP is polling at 21.5% statewide and every seat is a near-three-way where the preference-collecting party wins. Strongest argument against us: ONP is only 3rd on our own primaries (23.4 vs LNP 24.6 vs ALP 27.4) yet we give it the most wins, and Frankston's Senate ONP profile is below average (4.4%, rank 36/88). ONP over-calls historically: in published-predictions.csv ONP seats we forecast at 15%+ (n=108, mostly federal QLD) averaged about 1.6 points above actual (sign of `miss` inferred as ours-actual; UNCONFIRMED). ONP seats with a 0.3-0.6 win chance: only 4 scored, 2 won, too thin to say. Nothing local (no seat poll, no search-interest, no known strong candidate) supports ONP over LNP here; the whole case is the statewide level plus flows. No web search done (UNCONFIRMED any local news).

5. Pattern: model-wide One Nation high / Coalition low (ours 15.8 ONP seats vs TAB 12.9, LNP 39.1 vs 44.3), not seat-specific. Frankston is a typical mid-table case where that pattern bites hardest: a close three-way, so a small ONP-over-LNP flow edge swings 20 points of win chance.
