# Primary-vote misses: what the four investigations found, and the fix order (2026-10-05)

Pete asked to fix as many of the primary misses as possible, fast. Sized from `output/forecasts.csv`
(as-at, 11,905 rows, 18 elections, total squared error 194,679): the worst 100 rows are 21.1% of
squared error, the worst 500 are 45.8%. Four read-only Sonnet investigations, one review each:

- A `docs/reviews/byelection-incumbents-2026-10-05.md`
- B `docs/reviews/cross-seat-personal-vote-2026-10-05.md`
- C `docs/reviews/worst-overcalls-2026-10-05.md`
- D `docs/reviews/breakout-signals-2026-10-05.md`

## Bugs (checked against the code by the main session, all live)

| # | Bug | Where | Reach |
|---|---|---|---|
| 1 | Class leader chosen by the ACTUAL result: a backtest picks whose history counts by who won; live (pcv NA) the order is arbitrary | `R/candidate_returns.R:310`, `:535` | 389 seat-class groups with 2+ candidates where someone stood before (surname key, rough); OTH_RIGHT 137, IND 97, LNP 82 |
| 2 | WA party abbreviations misclassified: wa2001 has no ONP rows, OTH_RIGHT exists only in wa2025; AC, LCWA etc. land in OTH while the results files expand them via `WA_PARTY` | `scripts/build_candidacies.R:485` | Agent C: seats whose actual shares sum below 97 carry 7.8% of squared error (WA part traced only) |
| 3 | Salience permit lookup takes the FIRST row per seat when a class has 2+ candidates (Dobell 2016 IND permitted by row order) | `stats::setNames(as.logical(pv$permit), pv$seat)` in all six harnesses and `scripts/fit_seats_full.R:1048` | 239 conflicting (seat, class) cells over 22 pairs (agent C, not recounted) |
| 4 | v61 nomination zeroing never applied in the as-at forecasts table, so `forecasts.csv` still scores parties that did not stand | `build_forecasts_table.R`, `fit_xgb_primary_asat.R` (no `zero_unnominated` call) | 95 cells actual 0, forecast >= 3: 1.45% of squared error |

**Status 2026-10-05:** all four merged into local `dev` (c54973d, 56a8a01 + 19fa670, c0a3e85), not
yet pushed (PR #90 open from `dev`). Bug 1 moved 1,214 of 11,532 (seat, class) leaders over 22 pairs;
bug 3 moved 114 of 5,528 class permits (Dobell fed2016 IND now FALSE).

**Still open, found while fixing bug 3: the salience data carries the same leak.**
`output/salience-v6.csv` holds rows only for some candidates per class, apparently the one with the
best ACTUAL result, so which candidate got a Trends series was chosen by the outcome. In 181
classes the history-based leader has no salience row; the fix returns TRUE where the screen makes no
claim and NA (never a permit) otherwise. Rebuilding the salience population on pre-election
information is NOT done.

Fixing 1 makes the backtests measure what ships; expect IND/minor scores to get WORSE, not better.

## Model changes (design with Pete on rows first)

- **Person-history table** (A + B): one table of every person's earlier results across seats,
  jurisdictions and by-elections (`output/nsw-byelection-prevpcv.csv` is built and never read; the
  Lyne 2008 by-election result is on disk). Credit a shrunk fraction of the best prior IND or
  by-election vote through `own_prev_pcv`, reaching base_pred AND the xgb layer. Keep the defeated
  party's departed flag. Reach: 18 cross-seat rows (+10.9 pts under-call, SE 3.2), ~2.7%; by-election
  winners 43 rows 2.6%. Worked example: Orange 2019.
- **Defectors** (C): no "changed party" feature; xgb adds 5.8-6.7 to Hughes/Tangney. Realised carry
  median 0.21 vs fitted 0.355-0.435 (7 federal cases). 0.54%.
- **Breakouts with no signal** (D): 16 rows, 5.2%. No mean shift fixes them; wider uncertainty does.
  Endorsement (v59) added ~0 to the 2022 teals. State Trends series are on disk but never built.

## Order

1. Bugs 1-4, in parallel, each measured on its own target cells and on all six harnesses.
2. Rebuild the as-at forecasts and re-rank the worst rows: the list above changes once the bugs go.
3. Person-history table, designed on Orange 2019 with Pete, then prereg, then build.
