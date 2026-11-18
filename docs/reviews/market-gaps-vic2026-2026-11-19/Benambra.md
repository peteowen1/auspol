# Benambra (open seat: Liberal Bill Tilley retiring)
VERDICT: MODEL VIEW (fragile, one feature carries it). Not a bug like Essendon: ind_split False, one real independent (Lachie McKeeman); but the Independent number rests on a search-interest feature we cannot independently check.

| Party | Ours primary / win | TAB | Sportsbet | AEF | TSIO |
|---|---|---|---|---|---|
| ONP (Sheppard) | 28.8 / 38.3% | 12.5% | 15.9% | 7.6% | 40.3% |
| IND (McKeeman) | 26.9 / 31.6% | any-other 6.8% | 5.2% | 1.7% | other-left 21.6% |
| LNP (Martin) | 26.9 / 29.6% | 80.5% | 77.5% | 90.3% | 38.1% |
(forecast-vic2026.json, Benambra; benchmarks vic2026/2026-11-18/*-calls.csv). Other: GRN 5.2, ALP 3.4, OTH_RIGHT 6.7, OTH 2.2 primary, ~0 win.

Who the independent is: Dr Lachlan "Lachie" McKeeman, Wodonga GP, CFA volunteer, endorsed by Community for Benambra, nominated 9 Nov (web: bordermail.com.au; ABC guide; tallyroom.com.au/vic2026/benambra2026). He succeeds Jacqui Hawkins (not recontesting; web: Tally Room reader comment, UNCONFIRMED). Hawkins took 31.7% primary in 2022 and lost the two-candidate count 49.1 to 50.9 (external/elections/archive/2022vic-tcp.csv); 2018 was 47.55 to 52.45. Whether McKeeman is Hawkins's organisation's pick: Community for Benambra backing is web-reported, link to Hawkins UNCONFIRMED.

Mechanism (what drives our numbers):
- Start: Hawkins 31.7 carried to the IND cell, Tilley 42.9 LNP (2022 firstprefs). Departed-independent successor rate 0.511 cut IND to 16.7, trees to 12.8, final 12.96 on 25 Oct (docs/reviews/mildura-benambra-trace-2026-10-25.md l.55-70): IND win 0.3%, LNP 95%.
- Since then the search-interest corpus (salience-v6.csv vic2026 rows: McKeeman jump 0.676, Martin jump -5.0; Martin has low search interest) feeds the xgb layer (log XG5: 546/616 seat-classes matched; DS3b says the surge-v2 blend is OFF, so it is the feature only). 12 Nov walk (salience-vic2026-live-walk-2026-11-12.md l.46-74): IND primary 9.6 -> 27.4, LNP 37.6 -> 28.0, LNP win 75% -> 28.8%, IND 0.1% -> 27.4%, ONP 24.8 -> 43.6%. So the whole gap to the market is this one feature, not the base model.
- No seat poll for Benambra (absent from seat-poll-blend-vic2026.csv). ONP: statewide level 21.5 plus a 2026 Senate ONP score of 8.2 for the seat (onp-senate-vic2026.csv; column meaning not checked).

Case for us (market may be missing): a near-miss independent (49.1% TCP) facing a retiring incumbent and a new Liberal who ran in Indi in 2019 (web: tallyroom); the Liberal's 2022 43% lost its personal vote. Tally Room commenters see a McKeeman/ONP fight for second (UNCONFIRMED, comments). TSIO also has the Liberal only at 38%.
Strongest case against: (1) the search-interest effect is one input moving IND 9.6 -> 27 and the Liberal 37.6 -> 28 in one seat; the surge-v2 salience use was switched OFF on 31 Oct as no net gain (published_flags.R l.61). (2) Backtest for new independent successors with prev share >= 15 is mixed: Indi 2019 under-called (22.7 vs 32.4), Warringah 2019 (20.7 vs 44.7), Cowper 2022 (4.7 vs 26.3) but Barker/Boothby/Sturt over-called (published-predictions.csv, not scored per seat here). (3) Liberal 26.9 primary is down 16 points from Tilley; ONP 28.8 in a seat with no ONP history and no polls. Three-way spread 26.9/26.9/28.8 means any win probability ~30-38% each; the market's 80% Liberal implies a tail we hold at 30%. Expect our 26.9 IND is 2x the 12.96 the trace had.

Model-wide vs seat-specific: seat-specific. ONP 38% vs market 12-16% fits the model-wide ONP-high pattern (ours 15.8 seats vs 12.9/13.6), but the Liberal collapse to 30% and IND at 32% are from the new-independent plus search-interest path; AEF is the outlier in the other direction (LNP 90%).
Recommendation (mine): not a defect to fix; flag as high model-risk. Cheap check: re-run this seat with the McKeeman and Martin salience rows set to the no-data default and report IND/LNP (IND ~13, LNP ~90% from 25 Oct trace suggests that is the market view).
