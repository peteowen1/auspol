# Bendigo East (Northern Victoria): ours ONP 57% vs bookmakers LNP 76-84%
VERDICT: MODEL VIEW (with one UNCONFIRMED data question). No modelling bug found; the gap is the model-wide statewide ONP/ALP-collapse pattern, plus a deliberate choice to ignore the Nationals' 2025 federal strength here. Not run: R, seat trace.

| Party (candidate) | Our primary % | Ours win | TAB | Sportsbet | AEF | TSIO |
|---|---|---|---|---|---|---|
| ONP (Cheryl Hawken) | 26.3 | 57.4% | 13.5% | 19.8% | 11.2% | 4.2% |
| LNP (Andrew Lethlean, The Nationals) | 25.7 | 36.5% | 83.6% | 76.2% | 52.8% | 72.1% |
| ALP (Tim Rickwood) | 24.9 | 5.5% | 2.3% | 3.0% | 33.4% | 23.6% |
| GRN 11.0, OTH_RIGHT 3.9, IND 4.3 (2 cands), OTH 4.1 | | <1% | ANY_OTHER 0.6% | 1.1% | IND 1.9% | ~0 |
Sources: forecast-vic2026.json (seat Bendigo East); docs/benchmarks/vic2026/2026-11-18/{tab,sportsbet,aeforecasts,theswingison}-calls.csv. The ballot's LNP candidate is a NATIONAL, not a Liberal.

MECHANISM (our number)
- Start: 2022 result ALP 48.3, LNP 27.4 (Liberal Darin Schade), GRN 8.7, ONP 5.7 (external/elections/archive/2022vic-firstprefs.csv). Sitting MP Jacinta Allan (then Premier) did NOT recontest (web: Wikipedia candidates list; ABC says she was deposed as premier July 2026). Seat is open, 'sitting' False for every party in the JSON. Whether we model Allan's personal vote leaving is UNCONFIRMED (not traced; I did not run R).
- ALP falls 48.3 -> 24.9 (-23.4). Statewide ALP forecast is 22.5 (vs 36.8 in 2022), so this is the statewide Labor collapse applied here, not seat-specific.
- ONP 5.7 -> 26.3. Statewide ONP forecast 21.5. Seat Senate input is only 5.4% (output/onp-senate-vic2026.csv), 19th highest ONP seat in our forecast but well below the Gippsland/Mildura seats (Senate 8-12%). Our ONP primary is about statewide level + 5, not driven by seat-specific evidence. Search interest: Hawken is the only ONP candidate, share 100, raw 12.5, same as 22 other ONP candidates (output/vic2026-live-salience.csv); model coefficient for this seat is 0 (published-predictions row 'bendigoeast=0'). So no seat-specific ONP lift from search.
- No seat poll (grep of seat-poll-blend-vic2026.csv: no Bendigo row). No council history (all candidates flagged FALSE in council-history-vic2026.csv). Not a leader seat.
- Federal Nationals effect deliberately removed: output/seat-swing-port-vic2026.csv row has lineup3c weight 0.0055; journal 2026-10-28 'Port 3C SHIPPED' says the port stops treating the 2025 Bendigo Nationals-beside-Liberals line-up change as a swing the state seat shares. Nationals' Lethlean took the federal seat of Bendigo to a 1.4% Labor margin (web: ABC news 2026-04-04), the first Nationals top-two finish since 1946. TAB/Sportsbet are plausibly pricing that; we give it ~0 weight. Our LNP primary 25.7 is ~1.7 below 2022 (27.4 Liberal).
- Result: three-way tie on primary (26.3/25.7/24.9), so win chances hinge on flows: ONP leads the final pair ONP v ALP 54% (p_pair), ONP wins that 93% (final_two), TCP median 55.1, swing_to_flip 5.1.

STRONGEST ARGUMENT AGAINST US
1. The market sees a Nationals candidate with a near-win federally in the same area; we zero it out (Port 3C, 'null on the backtests', overridden by Pete's call, not proven right here).
2. ONP 26% rests on a statewide level, not on Bendigo evidence (Senate 5.4%, no search lift, no poll). 2022 ONP here was only 5.7.
3. AEF and TSIO still keep Labor at 24-33%; we give ALP 5.5% despite 24.9% primary, essentially tied. Our ALP 5.5% is the thing the whole field disagrees with: ALP is level on primary with ONP/LNP yet nearly never wins in our sim, which looks flow-driven (preferences from GRN 11% mostly to ALP should favour Labor). Worth one trace of Labor's final-two rate.

MODEL-WIDE OR SEAT-SPECIFIC? Mostly model-wide (ONP high, LNP low: ours ONP 15.8 vs TAB 12.9 seats, LNP 39.1 vs 44.3). Seat-specific pieces: Allan's exit (open seat), Nationals-not-Liberal ticket, and Port 3C removing the federal Bendigo swing. Not a defect like Essendon (ind_split False, one candidate per party except IND/OTH which are two each).
Next check if time: AUSPOL_TRACE_SEAT on Bendigo East for ALP/GRN flows and whether Allan's personal vote is subtracted (R/personal_prior_vote).
