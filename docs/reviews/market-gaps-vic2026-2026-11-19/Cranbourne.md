# Cranbourne (South-Eastern Metropolitan): ours ALP 56.8%, books favour ONP

VERDICT: MODEL VIEW (weakly; no defect found). Reverse of the usual pattern: we are LOWER on One Nation than TAB/Sportsbet, and the gap is a close ALP-v-ONP two-way race (p_pair 0.874), not a bug.

| Party | Our primary % | Ours win | TAB | Sportsbet | AEF | TSIO |
|---|---|---|---|---|---|---|
| ALP (Richards, sitting) | 34.4 | 56.8% | 36.4% | 30.4% | 40.8% | 18.6% |
| ONP (Hirst) | 24.6 | 37.7% | 47.4% | 44.8% | 21.3% | 67.3% |
| LNP (Tripodi) | 19.6 | 4.7% | 15.1% | 23.5% | 37.9% | 13.8% |
| OTH_RIGHT / GRN / other | 8.0 / 8.8 / 4.6 | 0.9 / 0.0 / 0 | GRN 0.5, other 0.5 | other 1.4 | ~0 | OTH_RIGHT 0.2 |
Gap: ALP +20.4 pts v TAB, +26.4 v Sportsbet; ONP -9.7 v TAB, -7.1 v Sportsbet. Books and TSIO are far apart from AEF, so there is no market consensus on the other side of us either.
(Source: forecast-vic2026.json seats[Cranbourne]; docs/benchmarks/vic2026/2026-11-18/*-calls.csv.)

MECHANISM (what drives our number)
- Starting point: 2022 first prefs ALP 46.2, LNP 27.5, GRN 5.6, other-right 14.9 (Christian 5.5, DLP 5.0, Freedom 4.4) (external/elections/archive/2022vic-firstprefs.csv). ALP 2018 50.3.
- Our ALP primary falls 11.8 pts to 34.4 (q05-q95 26.3-42.3); statewide ALP forecast 22.5. The ALP "demographic residual" is +0.18 for this seat (output/demo-resid-vic2026.csv), i.e. a mild help to ALP, -0.09 for GRN.
- One Nation: 2025 Senate ONP vote in the seat 5.52% (output/onp-senate-vic2026.csv), above the state median 3.59 (22nd of 88) but nowhere near ONP strongholds (max 12.0). We give ONP 24.6 primary, a 10-pt gap behind ALP; ONP wins mainly by collecting LNP (19.6) and other-right (8.0) preferences. final_two: ALP v ONP, ALP TCP median 50.7, swing_to_flip only 0.66 pt, ALP wins that pair 57.5%.
- Seat polls: none for Cranbourne (no row in output/seat-poll-blend-vic2026.csv). Search interest: no Cranbourne row in output/vic2026-live-salience.csv (44 rows); the 12 Nov salience walk showed the feature moved us TOWARD the books: ONP 0.323 -> 0.526, ALP 0.633 -> 0.441 (docs/reviews/salience-vic2026-live-walk-2026-11-12.md, lines ~51-52). Today's ONP 0.377 is after later changes; I did not trace why it is below that 12 Nov "on" figure (UNCONFIRMED).
- Candidate: ONP candidate Andrew Hirst is now named (output/candidacies.csv; nominations 9 Nov). On 28 Oct "no ONP candidate named" was one suggested reason the books looked high; that reason is gone, and our ONP chance rose 0.22 -> 0.38 since then (docs/reviews/contested-seats-vic2026-2026-10-28.md; live-walk-contested-seats-2026-10-28.md). Other candidates: Craig Baird (Libertarian, 15.2% in Casey council 2024, output/council-history-vic2026.csv) counted under OTH_RIGHT; Shane Foreman Family First.
- Not a simulation bug: ind_split False, no independent candidates, 8 candidates map to 6 classes sensibly (one candidate per class except OTH_RIGHT 2, OTH 2: both minor).

IF MODEL VIEW: what the market may be missing
- Labor has held it since 2014-ish with a sitting member and ALP 46% in 2022; a 10-pt primary lead is large for ONP to overcome. Seat is multicultural outer south-east (Casey), where Senate ONP 5.5% is only mid-table. (Demographic claim is my inference, UNCONFIRMED.)
- History: our ONP calibration in sa2026 was good (docs/reviews/contested-seats-vic2026-2026-10-28.md: 34 seats <10%: 0 won, 0.7 expected; 10-30%: 2 won, 2.0 expected), but our ONP VOTE was under-called by 2.5-3.8 pts in every third of seats there and 4.6-6.2 in qld2017. That is the strongest argument against us: if ONP primary is under-called by ~3-4 pts here, the pair flips (swing_to_flip is only 0.66 pt). I did not recompute from published-predictions.csv (not opened).
- Books are probably pricing the statewide ONP surge and Labor's weak statewide position rather than local data; AEF (ONP 21%) and TSIO (ONP 67%) bracket us widely, so the market is not obviously better informed.

MODEL-WIDE v SEAT-SPECIFIC
- Direction is NOT the model-wide pattern: model-wide we are HIGHER on ONP (15.8 v 12.9/13.6 expected seats) but here LOWER (37.7 v 47.4/44.8). So this is seat-specific: our model ranks Cranbourne's ONP profile (Senate 5.5%, ALP-heavy base) as only a mid-strength ONP seat while the books treat it as a likely ONP gain. Our LNP number (4.7%) is far below Sportsbet's 23.5%, the model-wide "LNP low" pattern.
- Recommendation: no fix needed on evidence read; worth one check of the ONP primary under-call in similar Labor-held outer seats before 28 Nov.
