# Prereg: the trees' `level_pred` with and without the recent-poll blend (audit F12)

Written 2026-10-25, before any run. Nothing below has been run. Finding:
[reviews/audit-f8-f19-status-2026-10-25.md](../reviews/audit-f8-f19-status-2026-10-25.md) F12, first raised in
[reviews/pipeline-overwrite-audit-2026-10-18.md](../reviews/pipeline-overwrite-audit-2026-10-18.md) F12.

## Why

The trees are trained on one statewide level and served another.

- **Training.** `scripts/build_level_pred.R:105-108` calls `forecast_statewide_for()` (`R/forecast_statewide.R:56`),
  which has no recent-poll blend, and writes `output/level-pred.csv`. `scripts/fit_xgb_primary_v6.R:334-344` reads it
  as the `level_pred` feature (`AUSPOL_LEVEL_MODE=pred`), and `R/party_surge.R:119-123` reads it for the surge levels.
- **Live.** `scripts/fit_seats_full.R:638-642` overwrites `state_mean` with `level_recent_apply()` (the 20-day
  half-life blend, `AUSPOL_LEVEL_RECENT=decay`, shipped 11 Oct). `.level_split` is built from that blended
  `state_mean` (`:1426-1427`), and `xgb_primary_predict_live()` serves it as `level_pred`
  (`R/xgb_primary_override.R:275-276`) and derives the surge levels from the same vector (`:500`).
- **Backtests.** No mismatch. Stage 6 harnesses blend their base (`R/forecast_statewide.R:407`,
  `backtest_candidate_fed.R:1365`), but the trees' other features, `level_pred` included, come from the stage-3
  features file through `xgb_base_delta_apply()` (only `base_pred` is refreshed), and the harnesses' surge levels read
  `level-pred.csv`. So every backtest number scores **blended base, unblended `level_pred`**. Live runs **blended base,
  blended `level_pred`**: a configuration no backtest has scored.

Size today (live walk log `deciding-runs/20261025-minor-additive-walk/add.log:28`, one decimal):
ALP 25.2 -> 24.6 (-0.6), LNP 29.3 -> 28.9 (-0.4), GRN 14.2 -> 14.3 (+0.1), so about +0.9 is pushed pro rata into the
classes the blend does not fit (`R/level_recent.R:309`): roughly ONP +0.6 and the others bucket +0.3 (my arithmetic
from the final ONP 21.77 and OTH 10.34; the new `LLP1` line prints the exact per-class figures). It reaches every
cell's `level_pred`. Because the trees train with `AUSPOL_TRAIN_DEMEAN=1`, a class level moves
cells only through interactions (`dev_prev`, `level_contested`, `contest_base_gap`'s ONP fill), so the cell effect is
probably a few tenths at most. **UNVERIFIED**: no run.

## The two switches (both "0" in `published_flags.R`; off, every output is byte-identical)

1. **`AUSPOL_LIVE_LEVEL_PRED_TREND=1`**, diagnostic, live only. `fit_seats_full.R` keeps `.state_mean_trend`, the
   level just before the blend (after the rescale to 100), and serves it to `xgb_primary_predict_live()` as
   `state_mean` (so `level_pred` and the surge levels) with its own bucket split (`.level_split_xgb`). `base_margin`,
   `.level_split` (read by `AUSPOL_LEVEL_CONSERVE`) and every other use of `state_mean` keep the blended level.
   Refuses to run with `AUSPOL_FORCE_FP` or `AUSPOL_LIVE_LEVEL_ANCHOR=1`, whose shifts land after the capture. Prints
   `LLP1` at default too (blended minus pre-blend, per class).
2. **`AUSPOL_LEVEL_PRED_RECENT=1`**, the fix, training side. `build_level_pred.R` applies
   `level_pred_recent_apply()` (`R/level_recent.R`) to each poll-based pair: `level_recent_apply()` at
   `as_at = polling day`. Time-forward by construction and tested: only state polls dated before polling day and
   federal breakdowns whose fieldwork ended before it count, and the blend constant `k` is fitted on elections dated
   before the pair (`elections_before()`). A pair whose blend fails stops the build (`LPR2!`), and the file gains a
   `level_recent` column only under the switch. `rebuild_forecasts.sh` builds `fed-state-breakdowns.csv` and
   `level-recent.csv` before stage 3 under the switch (both read polls and candidacies only). The blend settings
   follow `published_flags.R` when unset.

## Part A: the diagnostic (a live walk diff)

Two runs of `fit_seats_full.R` at published flags, same seed, same inputs, same day: base, and
`AUSPOL_LIVE_LEVEL_PRED_TREND=1`. Not `quick_arm.R`, which reuses cached tree predictions.

**Read before any result:** the arm's `LLP1` line says "PRE-BLEND", the base's says "BLENDED", and both print the
same per-class gap (expected ALP about +0.6, LNP +0.4, GRN -0.1, ONP about -0.6 and the split bucket about -0.3,
pre-blend minus blended). `FSLR` and `XG0s` are identical in both logs. If not, the walk did not test this.

**Expected, written now:**

- `base_pred` and `base_margin` identical in every cell (only tree features change).
- Cells move in the direction of the level they are served: ALP and LNP cells slightly up, ONP cells down, most where
  ONP is new to the seat (its `contest_base_gap` fill is `level_pred * n_seats` spread over new entrants). Mean
  |change| per cell under 0.3 points; no cell over 1.0.
- Seat-winner probabilities move most in the close ONP-against-ALP seats of today's walk
  (`seat-probs-vic-2026-walk-add.csv`, ONP 0.50-0.70): Melton, Wendouree, Sydenham, Essendon, Shepparton,
  Narre Warren North, Cranbourne, Yan Yean, Niddrie, Mill Park, Macedon, Hastings. Direction: ONP down, ALP up.
  59 seats have a winner between 0.3 and 0.7; expect none to move by more than 0.05.

**What it decides.** Nothing about the fix on its own; it sizes the mismatch. But note: the arm is the configuration
the backtests scored (blended base, unblended `level_pred`), so shipping the diagnostic needs no deciding run of
its own; it makes live match the scored numbers. That choice is Pete's. If the largest cell change is under 0.2 points
and no winner probability moves by 0.02, F12 is a parity note and Part B can wait for a scheduled rebuild.

## Part B: the real fix (an isolated rebuild from stage 3)

Neither arm shows in `quick_arm.R`. Both sides rebuild, because the code has moved since the last publish
(`AUSPOL_MINOR_ADDITIVE` shipped today), so the 21 Oct publish is not a like-for-like baseline.

- **Copies.** Two isolated copies at the same commit, as `deciding-runs/decay4-rebuild/chain.sh` does (robocopy
  excluding `deciding-runs` and `.claude`, `git checkout <sha> -- .`, refuse below 8 GB available, never publish):
  - base: `env AUSPOL_REBUILD_FROM=3 bash scripts/rebuild_forecasts.sh`
  - arm: `env AUSPOL_REBUILD_FROM=3 AUSPOL_LEVEL_PRED_RECENT=1 bash scripts/rebuild_forecasts.sh`
  Run one after the other (memory watchdog), detached as a Scheduled Task.
- **Stages that rerun:** 3 (`build_level_pred.R`, `fit_xgb_primary_v6.R`; the arm first runs the two 5b level
  builders), 4 (as-at models), 4b/4c (flow models; 4b skips current ones), 5 (production model), 5b, 6 (six
  harnesses at 20,000 sims; harness surge levels also read the new `level-pred.csv`), 7 (pool, spread tables,
  possibly a second 6-7 pass), 8 (ledger). Stages 1-2 are reused: the base_pred training rows do not depend on
  `level-pred.csv`.
- **Time:** stage 3 took 439-452 s in recent rebuilds; stages 4-8 took 1 h 43 min on 25 Oct (decay4, stage 6 ran twice).
  The two 5b builders add a few minutes (**UNVERIFIED**). About 2 hours per side, 4 hours for both.
- **Reproduction checks, before scoring:**
  1. The arm's `s3_level.log` shows `LPR2 recent-poll blend applied to N of N poll-based pairs` with N = the pairs
     with a poll trend, and `LPR1` lines whose `w` is non-zero for the recent elections; the base log has no `LPR` line.
  2. `level-pred.csv` differs between the copies only in ALP/LNP/GRN and the pro-rata classes of blended pairs, and
     the arm's per-pair blend matches the harness blend (`*r` codes in the base's stage-6 logs) to 2 decimals.
  3. The base reproduces the latest publish's pooled log loss to 3 decimals, or the cause of the difference is named.

**Criterion** (the standard rule, `docs/PRE-REGISTRATION-RULES.md`): seat-winner log loss on the published path,
lower is better, floor 1e-6, SE clustered on election. Scorer `scripts/score_contest_feats.R <base> <arm> 1e-6`
(dry-run it self against self first: change 0.0000). Every election is touched (every pair's `level_pred` moves),
so the primary is the whole scored set; print election and seat counts first.

1. **Primary:** all scored elections (35 elections, 2,931 seats at the 25 Oct run), better by more than 1 SE.
2. **Leave-one-election-out** on the primary keeps the sign in every drop.
3. **No election worse** by more than 2 SE of its own seats.
4. Without the two largest-gain seats the primary keeps its sign.
5. **Primary-vote RMSE** over all cells not worse by more than 1 SE (clustered on election).

Reported, not voted: AEF-7 (681 seats) against AEF's 0.2825; the 1e-4 floor; the live forecast after the retrain
(default flags, so blended `level_pred` served to trees that were trained on it) against today's, per class and for
the Part A seats.

**Named in advance, what would make a win unacceptable:**

- (a) The gain lives only at the 1e-6 floor (the 1e-4 floor disagrees in sign).
- (b) The gain is in elections with almost no late polls (blend weight under 0.2) while those with a real blend are
  flat or worse: then it is retraining noise, not the blend.
- (c) Federal pairs carry the gain while the state pairs, the ones like Victoria, are worse as a group by more than
  1 SE.

**If it refuses:** the trees are better off not seeing the blend. Then the consistent configuration is Part A's
(serve the trees the pre-blend level), and the question becomes whether to ship that switch. Shipping either is
Pete's call on the result.

## Out of scope, noted

Stage 1 still builds the training `base_pred` with `AUSPOL_LEVEL_RECENT=0` (`rebuild_forecasts.sh:245`) while live
`base_margin` is blended. That is the base side of the same blend, already scored by the stage-6 base-delta path, and
not what F12 is about.
