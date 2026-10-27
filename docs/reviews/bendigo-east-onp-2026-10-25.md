# Bendigo East under `AUSPOL_ONP_ORDER=senate_rank`: One Nation 0.69, against 0.37 today and the market's 0.29

2026-10-25. The question: is the jump a defect in the Senate ranking for this seat, or something the market is missing?
Pete wants to ship `senate_rank` live.

## Verdict

**The Senate ranking is not wrong for Bendigo East. The 2025 House ranking was the odd one out.** The Senate number lines
up with every other One Nation measurement we have for this seat (2022 House rank 70 of 88, 2025 Senate rank 66, and 5.7%
at the 2022 state election, second of the four seats One Nation contested). Only the 2025 House vote (rank 43) disagrees,
and that is the election where Andrew Lethlean stood for the Nationals in federal Bendigo for the first time. Lethlean is
also the Nationals candidate in Bendigo East in 2026. The 0.69 comes from three things together: the Senate allocation
(+5.35 points), a +3.4 point One Nation lift from the xgb layer that also appears under the House ordering, and a three-way
contest that is close enough for either of them to change which party runs third. **Verdict: not a defect in
`senate_rank`. Ship it without a Bendigo-East-specific fix.** The gap to the market comes from the xgb lift (cause not
traced) and from the Nationals' strength, which the model only gets through the seat-swing port. See "What to do" for the
port arm.

## How this was traced

- A copy of `scripts/fit_seats_full.R` with a print added after every stage (`scratchpad/fit_trace.R`, written by
  `scratchpad/make_trace.R`; the published script was not edited). It ran once with `AUSPOL_ONP_ORDER=senate_rank` and
  `AUSPOL_OUT_SUFFIX=-trace-bendigo-onr`, at 21:24 to 21:30. It reproduces the walk exactly: One Nation 31.02, win
  probability 0.6905 (the walk's `seat-probs-vic-2026-walk-onr.csv` has 0.6905).
- Outputs and the log (`fit-trace-onr.log`, UTF-16, plus a UTF-8 copy) are in `deciding-runs/20261025-bendigo-east/`.
  `output/S7-BREACH.txt` was backed up and restored.
- The base (House ordering) arm was not traced stage by stage. Its allocation target (21.62) and final share (26.01) are
  computed from the same functions (`onp_rank_ratio()`, `onp_cv_force()`) and the walk outputs. The stages after the
  allocation are not ordering-specific, so the base column below is inferred for those stages and marked as inferred.

## The row, stage by stage

Bendigo East primary vote shares (percent of formal vote) after each stage of `fit_seats_full.R`, under `senate_rank`.
The last column is One Nation under the shipped House ordering. Bold marks the stages that move One Nation, the Coalition
(LNP, the Nationals here) or Labor by more than a point.

| Stage | ALP | LNP | ONP | GRN | IND | OTH_RIGHT | OTH | ONP, House order |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 2022 result (Allan, Liberal Schade, ONP Mihail) | 48.30 | 27.38 | 5.70 | 8.66 | 3.52 | 2.99 | 3.45 | 5.70 |
| **Swing to statewide level** (ALP slope 0.620 departed, LNP 0.877) | 31.86 | 22.69 | (5.70) | 11.50 | 2.59 | 2.86 | 1.56 | |
| **One Nation allocation + fill** | 31.85 | 22.68 | **26.97** | 11.50 | 2.59 | 2.86 | 1.56 | **21.62** |
| New-independent shrink | 32.02 | 22.80 | 27.11 | 11.56 | 2.05 | 2.88 | 1.57 | |
| **xgb live** | 29.89 | 22.25 | **30.52** | 10.90 | 1.82 | 2.92 | 1.69 | (about +3.4, inferred) |
| **Seat-swing port** | **23.91** | **28.24** | 30.52 | 10.90 | 1.82 | 2.92 | 1.69 | |
| Seat-poll blend | 23.91 | 28.24 | 30.52 | 10.90 | 1.82 | 2.92 | 1.69 | |
| Demographic correction | 23.50 | 28.51 | 30.83 | 10.67 | 1.83 | 2.95 | 1.71 | |
| Leader seat / departed fed | 23.50 | 28.51 | 30.83 | 10.67 | 1.83 | 2.95 | 1.71 | |
| Salience blend (hazard 0.083, ONP) | 23.43 | 28.43 | 31.02 | 10.64 | 1.83 | 2.94 | 1.70 | |
| **Final** | 23.43 | 28.43 | **31.02** | 10.64 | 1.83 | 2.94 | 1.70 | **26.01** |
| **Win probability** (20,000 sims) | 0.008 | 0.300 | **0.691** | 0.001 | | 0.001 | | ONP **0.367**, LNP 0.595, ALP 0.035 |
| Market, 24 Oct (margin removed) | 0.053 | 0.643 | 0.286 | | | | | |

Neighbours under `senate_rank` (same stages, the trace's other four seats). One Nation allocation, House order then Senate
order, and final shares:

| Seat | ONP rank House / Senate (of 88) | ONP target House to Senate | final ALP / LNP / ONP | port (ALP) | xgb ONP lift |
|---|---|---|---|---:|---:|
| Bendigo East | 43 / 66 | 21.62 to 26.97 | 23.4 / 28.4 / 31.0 | -5.98 | +3.41 |
| Bendigo West | 29 / 50 | 16.97 to 23.60 | 23.5 / 26.4 / 24.0 | -5.14 | +0.18 |
| Euroa | 80 / 81 | 33.65 to 33.81 | 13.6 / 38.6 / 35.9 | -0.24 | +1.66 |
| Benambra | 67 / 82 | 27.07 to 33.92 | 4.1 / 35.8 / 33.9 | -1.47 | -0.33 |
| Shepparton | 83 / 80 | 34.09 to 33.65 | 2.5 / 41.3 / 36.2 | -0.18 | +3.01 |

### In plain words

1. **2022.** Jacinta Allan (Labor, then Premier) 48.3, Liberal 27.4, Greens 8.7, One Nation 5.7. One Nation stood in only
   four Victorian seats in 2022. Bendigo East was its second best, after Morwell (6.1), ahead of Macedon (3.6) and
   Pakenham (3.4).
2. **Allan is not standing, and the model knows it.** `candidate_returns()` gives Bendigo East ALP `same = FALSE`,
   `mp_departed = TRUE`, so Labor's deviation from the state average is carried at the departed-member slope 0.620, not
   the sitting-member 0.922. Labor goes 48.3 to 31.9, against about 36.3 under uniform swing, so about 4.4 points of
   Allan's personal vote are removed. The Nationals candidate gets no personal-vote credit (`same = FALSE`, no own-prior
   row). No other stage gives Labor a sitting-member bonus here. The leader-seat bonus goes to Niddrie, Melbourne and Kew.
   This handling looks correct.
3. **One Nation allocation.** Victoria's statewide One Nation share is 21.77. Each seat gets that times a ratio taken
   from South Australia's 2026 spread, handed out by rank. On the 2025 House vote in its booths (4.61%) Bendigo East
   ranks 43rd of 88 (48th percentile) and gets 21.6. On the 2025 Senate vote (5.43%) it ranks 66th (74th percentile) and
   gets 27.0. The fill takes almost nothing from the others here, because the 2022 row already had 5.7 of One Nation in it.
4. **xgb live adds +3.4 to One Nation** (Labor -2.1, Nationals -0.6). Across all 88 seats the gap between the final One
   Nation share and the allocation target averages +0.53 (sd 1.97). Bendigo East's +4.06 is 7th of 88, and it is +4.40
   under the House ordering, so it does not depend on which ordering is used. It is not simply the 2022 One Nation
   history: Pakenham gets +3.9, but Morwell gets 0.0 and Macedon -1.1. **Cause not traced** (no SHAP decomposition was
   run). The candidates are this seat's surge hazard (0.083, One Nation; the xgb layer reads it, XG5), its 2022 One
   Nation share as `seat_prev_pcv`, and the departed-member features.
5. **Seat-swing port: Labor -5.98, Nationals +5.56.** This is the 2025 federal Bendigo swing to the Coalition, which
   came when the Nationals stood there for the first time. One Nation is untouched.
6. **The contest.** On the final point shares, a hand walk through the printed flows (One Nation 31.0, Nationals 28.4,
   Labor 23.4) goes like this. After the minor candidates' preferences: One Nation 33.0, Nationals 29.9, Labor 24.8,
   Greens 12.3. After the Greens' preferences (68% to Labor): One Nation 35.0, **Labor 33.2, Nationals 31.8**. The
   Nationals come third, their preferences elect One Nation over Labor, and One Nation wins. Under the House ordering
   (One Nation 26.0) the same walk ends One Nation 30.3, Nationals 33.6, Labor 36.1. One Nation is excluded and the
   Nationals beat Labor about 53.7 to 46.3 (the sim's median is 55.9). Without Allan, Labor and the Nationals finish
   within about 1.5 points of each other after preferences, and whichever of them comes third hands the seat to the
   other side. That is why a 5-point move in One Nation turns 0.37 into 0.69. This walk uses point shares and the
   conditional flow cells printed in the trace. It is a reading of the mechanism, not the simulation.
7. **Each piece is needed on its own.** Take away the xgb lift (One Nation about 27.6, Labor about 24.8, Nationals about
   29.0, approximate) and the walk ends with One Nation third. Take away the Senate shift and you get the base arm, where
   One Nation is also third. On the point estimate, One Nation leads only with both. (Inferred from the hand walk. Not
   simulated.)

## Is the Senate ranking a defect here?

**No, as far as the data shows.** Every One Nation measurement for this seat, set side by side:

| Measure | Bendigo East | Rank of 88 (higher = stronger One Nation) |
|---|---:|---:|
| 2022 federal House ONP, transposed to the state seat | 5.26% | 70 |
| 2025 federal Senate ONP, same booths | 5.43% | 66 |
| 2025 federal House ONP, same booths | 4.61% | **43** |
| 2022 state ONP (one of only 4 seats contested) | 5.70% | 2nd of 4 (Morwell 1st) |

Senate divided by House ONP, 2025, over all 88 seats: median 0.79 (interquartile range 0.67 to 0.96). Bendigo East is
1.18, the 4th highest of 88. Its House vote was squeezed, and Bendigo West (1.12, 7th) was squeezed the same way. That
is the Lethlean effect the `senate_rank` prereg names. Nothing seat-specific is pushing the Senate figure up: the Senate
ballot is the same statewide, Bendigo East sits between Bendigo West (4.0) and the rural northern seats (7.9 to 8.2) as
its mixed urban and rural booths would suggest, and the 2022 House and state results put it in the same place. No
transposition error was found: the House figures in `federal-transposed-to-state.csv` and `house-onp-by-district.csv`
agree (4.61), and 88 of 88 seats have a Senate share.

## Which input makes 0.69, and how big each one is

| Input | ONP points | Same under the House order? | Defect? |
|---|---:|---|---|
| Senate rank 66 instead of House rank 43 | +5.35 | no, this is the arm | No. Matches 2022 House and 2022 state (above) |
| xgb live lift | +3.41 | yes, +4.40 total lift in the base | **Unclear**, 7th largest of 88, cause not traced |
| Port moves Labor -5.98 to the Nationals | 0 (ONP) | yes | Changes who runs third (below) |
| Salience, demographic | +0.50 | yes | small |
| Allan's departure (slope 0.620) | Labor -4.4 vs uniform | yes | No, handled correctly |
| Flow `ALP|LNP+ONP` = 34.5% to One Nation, n = 3 exclusions | used only if Labor is third | yes | Thin (3 events), but not what decides this seat |

## Is the market missing something?

Partly the reverse: the market probably sees something the model is weak on. It has the Nationals at 0.64. The model
gives the Nationals 28.4 only because the port moves 5.6 points from Labor. Before the port they sit at 22.3, below
Labor and One Nation. The Nationals candidate is the same man whose federal campaign lifted the Coalition primary in
Bendigo from 26.6 to 40.2 in 2025: Andrew Lethlean polled 29.7 as the Nationals candidate, beside a Liberal on 10.5
(`output/candidacies.csv`, fed2025 Bendigo). The model gives him no personal vote. On One Nation itself, the House-order model
(0.37) was already above the market (0.29). The market has no published One Nation primary for this seat (none found), so
whether it disagrees with the 31.0 or only with the order of finish cannot be checked.

## What to do

1. **Ship `senate_rank` without a Bendigo East fix.** The ranking change here is backed by three independent measures.
   The 0.69 is the arm doing what it is meant to do in a seat where the House vote was squeezed, compounded by a
   three-way contest that a 5-point move can flip. Report Bendigo East as a known high-leverage seat: the win probability
   moves about 0.3 per 5 points of One Nation.
2. **Hold `AUSPOL_SEAT_SWING_PORT_3C` for Bendigo East specifically.** The arm's reason is that the 2025 Bendigo swing
   was a line-up change (Nationals standing for the first time), not a mood. In Bendigo East the line-up change carries
   over: the Nationals stand in 2026, where a Liberal stood in 2022, and with the same candidate. Removing about 5.7
   points of the Nationals' share here (-5.98 to -0.28 on Labor) would most likely leave the Nationals third. That makes
   the race One Nation against Labor and probably raises One Nation's chance further, away from the market. **Inferred
   from the hand walk, not run.** The 3C live walk should report Bendigo East's winner probabilities before that arm
   ships. A better rule would key on whether the 2026 state line-up repeats the federal change, not only on whether the
   federal line-up changed.
3. **Trace the xgb +3.4 (open).** A SHAP decomposition of the Bendigo East ONP row under `xgb_primary_predict_live()`
   would say whether it is the surge hazard, the 2022 One Nation share or the departed-member features. It is present in
   the shipped forecast today, so it is not a reason to hold `senate_rank`.

## Not verified

- The base arm's per-stage numbers after the allocation (only its target and final share were computed).
- The cause of the xgb lift.
- The hand preference walks are point-estimate readings with the printed flow cells. `LNP|ALP+ONP` was not printed, so
  the final One Nation against Labor count is not given.
- The effect of the 3C arm on Bendigo East's win probabilities (direction reasoned, not run).
