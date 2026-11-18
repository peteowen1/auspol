# Melton: our LNP 52% / ONP 42% vs books ONP ~50%, LNP 28-36%

VERDICT: MODEL VIEW (with one soft spot). Not a bug like Essendon; the gap is mostly the model-wide One Nation/Coalition pattern, narrower here than elsewhere.

Table (win chance; ours also shows forecast first-preference %, forecast-vic2026.json Melton row)
| Party | Ours prim % | Ours win | TAB | Sportsbet | AEF | TSIO |
| LNP (Bingham) | 26.8 | 52.3% | 28.2% | 35.6% | 55.9% | 51.8% |
| ONP (Katselis) | 24.2 | 42.1% | 49.7% | 50.0% | 22.0% | 47.2% |
| ALP (Borg) | 24.6 | 4.8% | 20.9% | 12.1% | 20.6% | 0.9% |
| GRN / OTH_RIGHT / IND / OTH | 9.8 / 5.8 / 4.3 / 4.5 | 0.2 / 0.5 / 0.1 / 0 | 0.3 / - / ANY_OTHER 1.0 | 1.0 / - / 1.5 | 0.5 / - / IND 0.9 | - |
(bookmaker rows: docs/benchmarks/vic2026/2026-11-18/*-calls.csv). Books give ONP the lead; AEF and TSIO give LNP the lead like us. Gap on ONP is -8 points TAB, -8 Sportsbet; on LNP +24 TAB, +17 Sportsbet; ALP we are 16 / 7 below TAB / Sportsbet.

Mechanism (what drives our number)
- Start: 2022 firstprefs ALP 37.7, LNP 24.3 (Graham Watt), IND Birchall 9.1, Bingham (IND) 5.8 (external/elections/archive/2022vic-firstprefs.csv). 2022 TCP ALP 54.6 / LNP 45.4. Forecast LNP final-two TCP median 55.1 vs ALP (final_two in the JSON), swing_to_flip 5.1.
- Three-way tie on primaries: LNP 26.8, ALP 24.6, ONP 24.2. ALP falls 13 points from 2022, ONP gets about 24 in a seat where its federal Senate vote was only 6.2% (output/onp-senate-vic2026.csv). So the ONP number comes from the statewide level (ONP 21.5), not a local base. Seat polls: none for Melton (no row in output/seat-poll-blend-vic2026.csv). Search interest: output/vic2026-live-salience.csv has only a header, no Melton rows.
- Independents: the strong 2022 independent, Ian Birchall (9.1%, also 10.5% in 2018), is NOT on the 2026 ballot (output/candidacies.csv, 11 Melton candidates, none Birchall). The forecast IND is only Perera/Faruq/Fraser, 4.3% total (Faruq got 12.3% in the 2024 council, output/council-history-vic2026.csv; ind-split-fit shows n_cred=0). ind_split is false and the three are summed as one IND class, so a small Essendon-type lumping effect exists, but it is irrelevant: IND win chance 0.1%, split or not.
- Candidate fact worth knowing: Jarrod Bingham, our Liberal candidate, ran as an independent in 2022 (5.8%) and 2018 (6.8%). Do not treat him as a sitting Liberal; the model has him as a non-sitting LNP (sitting:false), so whether his earlier votes carry over is only in the generic mapping. UNCONFIRMED whether the model credits those votes.
- Volatility: the forecast moved from ONP 67.6% / LNP 23.5% (docs/benchmarks/vic2026/2026-10-22/ours-calls.csv) to ONP 42 / LNP 52 now, so this seat is a near coin flip between three parties and sensitive to small input changes.

Why the market may be right and we may be wrong (strongest argument against us)
- ALP 24.6% primary and 4.8% win chance is the weak point: a seat Labor held 54.6 TCP in 2022, with a safe-seat history. Books give ALP 12-21%, AEF 21%. Our ALP is below both books and AEF; TSIO has ALP lower still (0.9%). Our ONP win chance is high relative to AEF but low relative to books.
- Backtest: where the model forecast ONP at 15-35% primary, it was too high federally (fed2019/22/25: 18.0 vs 15.3, 16.3 vs 13.6, 16.5 vs 14.1; output/published-predictions.csv, n=4-6 seats each), too high in qld2020 (17.5 vs 13.5, n=20), but too LOW in qld2017 (18.4 vs 23.8, n=34) and sa2026 (22.6 vs 25.7, n=35). The most recent One Nation surge (SA 2026) was under-called, which supports the model's view and the books' ONP lean over AEF.

Defect check: no duplicated-candidate or lumping bug found that moves a favourite; ONP, LNP, ALP each carry one named candidate. Did not run R; ind_split fit rows only.

Is it the model-wide pattern? Mostly yes: ONP/GRN high and LNP low in aggregate. Melton is the reverse of that for LNP (we have LNP as favourite and above ONP, while books have ONP first), so here our One Nation is LOWER than the books', which does not fit the "we are too high on ONP" pattern. Seat-specific part: books price ONP at 50% on a three-way split with no seat poll, while our model puts the three within 2.6 points and lets LNP preferences decide.
