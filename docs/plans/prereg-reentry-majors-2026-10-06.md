# Pre-registration: majors-only re-entry carry (2026-10-06)

Written BEFORE the arm ran. Pete chose it after the general re-entry prior was refused
(prereg-reentry-prior-2026-09-07.md, One Nation over-filled in qld2020).

Rule (`AUSPOL_REENTRY="majors"`): ALP, LNP or GRN contesting a seat it skipped at the previous election
takes its share at the last earlier election it contested that seat, swung by the statewide change
(dev_slope); no earlier contest under the seat name means no fill. Dry run (corpus, pre-renormalisation):
7 cells over 22 pairs (vic2022 Richmond LNP, wa2013 Churchlands LNP, three sa2026 GRN, two wa2005);
squared error on the 5 with a shipped row -871. Live vic2026: Narracan ALP 29.3.

Arm: rebuild from stage 1 (the fill lands in base_pred, which the xgb layer trains on), baseline
`output/snapshots/base-reentry` (shipped + Kennedy split). With 7 cells no aggregate test has power, so:

1. PRIMARY (targeted): summed squared error of the published seat share on the filled cells falls.
2. GUARD: seat-winner log loss over 22 elections (SA6) rises by no more than 1 SE.
3. GUARD: AEF-7 ledger rises by no more than 1 SE.
4. DISQUALIFIER: any single election's seat-winner log loss rises by more than 0.005 for a reason other
   than the filled cells (i.e. the xgb retrain moved unrelated seats materially).

Ship if 1 passes, 2 and 3 hold and 4 does not fire; otherwise off and to Pete.
