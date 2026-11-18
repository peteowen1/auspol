# Mill Park (28 Nov 2026) - ours ONP 54% vs bookmakers' ALP
VERDICT: MODEL VIEW (leaning; one UNCONFIRMED data gap). Retirement is handled as a new-candidate open seat; the gap is the model-wide ONP/statewide-ALP-collapse pattern applied to a 3-way seat with no seat poll.

| Party (candidate) | Our primary % | Our win | TAB | Sportsbet | AEF | TSIO |
|---|---|---|---|---|---|---|
| ONP (Tsoutsoulis) | 24.1 | 53.7% | 27.8% | 31.6% | 13.1% | 31.0% |
| LNP (Drysdale) | 23.2 | 26.9% | 16.4% | 22.6% | 43.8% | 32.3% |
| ALP (Nealy) | 27.9 | 18.6% | 54.8% | 44.7% | 42.5% | 36.5% |
Others: GRN 10.0, OTH_RIGHT 5.1, IND 4.9, OTH 4.9, all <0.5% to win (forecast-vic2026.json). Raw TAB price ONP 2.90, ALP 2.00 (bookmaker-odds.csv).

Mechanism (evidence):
- Retirement: Lily D'Ambrosio is stepping down (web: ABC, Wikipedia, announced 30 Jul 2026). Forecast lists ALP candidate Nealy with sitting=false (JSON); candidacies.csv vic2026 row ALP NEALY (VEC official). So the model treats it as an open seat: no sitting-member bonus, ALP base decays (AUSPOL_MAJOR_DEPARTED / HONOUR_DEPARTED on, published_flags.R l.32-42). Handled, not ignored.
- Start: 2022 ALP 49.9% (down 12.8), LNP 25.9, GRN 7.3, Freedom 7.0 (external/elections/archive/2022vic-firstprefs.csv; candidacies.csv). ONP did not stand in 2022.
- Our ALP primary 27.9 is -22 points on 2022; statewide ALP forecast is 22.5 (json statewide). ONP 24.1 vs a seat Senate-vote proxy of 5.3% (onp-senate-vic2026.csv: senate_pct 5.27, floor_pct 1.59, fitted from SA 2026). So ONP's seat value comes from the statewide 21.5 surge, not from local ONP strength.
- No seat poll: Mill Park is absent from seat-poll-blend-vic2026.csv (7 rows, none this seat). Salience: Nealy jump 0.03, Tsoutsoulis 0 (vic2026-salience-jump.csv), so search interest adds nothing for ONP.
- Demographic residual: ALP +0.16 (helps ALP), GRN -0.16 (demo-resid-vic2026.csv). Fed swing port -0.51, coef 0.45 (seat-swing-port-vic2026.csv): negligible.
- Final two ONP v ALP in 64% of sims; ONP wins the pair 80%; swing_to_flip only 3.2 pts; ONP TCP median 53.2 (q05 46.8). Three-way: ALP 27.9 / ONP 24.1 / LNP 23.2 are within 5 points, so the win chance is driven by preference flows and wide primary bands (ONP q05-q95 17-32).

Possible defect, UNCONFIRMED: council-history-vic2026.csv shows Nealy council_any=FALSE, n_council_runs=0 although web (ABC) says she was mayor 2024-25. If the council-experience feature is meant to lift candidates with a council record, ALP may be under-credited. Likely small; the council feature reaches few seats (not checked in R; no R allowed). Check her council name vs the council file.

Strongest argument against us: a safe-Labor outer-north seat (62.7% ALP in 2018) where ONP's local base is thin (fed Scullin ONP 6.6% web: ABC; Senate proxy 5.3%). Our ONP primary is 4.5x its local Senate proxy. Neighbours show the same shape (Thomastown ALP 55 / ONP 29, Bundoora ALP 86, Broadmeadows ALP 78) yet Mill Park sits well above them with no seat-specific evidence; ALP 18.6% here vs 34-55% next door looks seat-noisy. Retirement worth maybe a few points only; Nealy being a recent mayor argues for a smaller open-seat penalty.
For us: three-way split lets a 24% ONP win; TSIO also has ONP at 31%; Sportsbet 32%.

Model-wide or seat-specific: model-wide (ONP 15.8 seats vs 12.9/13.6 markets; ALP statewide collapse), amplified here by the open seat and no seat poll. Not an Essendon-type bug: 8 distinct candidates, ind_split false, one IND (McLindon) simulated alone.
Not checked: backtest over-call of ONP in metro-north ALP seats (published-predictions.csv); whether Mill Park's ALP drop is mostly the statewide level or the departed decay (needs R trace).
