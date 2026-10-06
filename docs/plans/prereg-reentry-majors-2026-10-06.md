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

## Result (2026-10-06, rebuild from stage 1) -- REFUSED, switch stays "0"

Filled 4 cells (Richmond LNP 10.1 against 18.8 -- the forecast Liberal statewide fell 42.0 -> 31.4 since
2014; sa2026 MacKillop, Mount Gambier, Narungga GRN 7.1-7.9). Churchlands wa2013 was NOT filled: the
harness corpus has no earlier LNP contest under that name (the dry run used a wider history). Ledger
0.2738 -> 0.2751 (SE 0.0010, guard breached); 22 elections +0.0016 (SE 0.0012). DISQUALIFIER 4 FIRES:
elections with no filled cell moved -- wa2005 +0.041, wa2017 +0.011, fed2025 +0.005 -- so the xgb retrain
from stage 1 moves unrelated seats by more than a 4-cell fix can show. The noise floor of a stage-1
rebuild (switch 0 vs switch 0) was never measured; it should be before the next stage-1 arm.
output/ restored to the baseline afterwards.
