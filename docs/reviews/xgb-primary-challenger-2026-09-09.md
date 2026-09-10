# XGBoost as a primary-share challenger model — 2026-09-09, session parked overnight

Pete's idea: candidate/class primary vote share has enough interacting inputs
(own prior share, seat lean, statewide level, salience, surge, same/new
status...) that a tree-boosted model might find structure the hand-built
`dev_slope()`/`conditional_slopes()` system misses. Tested directly rather
than argued about. **It works, better than anything else tried today** — but
it has a specific, diagnosed weakness that isn't fixed yet.

## The reference result (v1) — the one to build on tomorrow

`scripts/fit_xgb_primary.R` + `scripts/fit_xgb_primary_cv.R`. Feature matrix
at (pair, seat, party) granularity across all 22 backtest pairs (13,314
cells after dropping 727 where a class got zero votes that cycle). Features:
the shipped model's own `pred_share`, the class's own prior seat share `x`,
statewide `level_prev`/`level_now`, `dev_prev`, candidate counts, same/MP
flags, party and region one-hot. Trained via `xgb.cv` with folds **grouped
by election pair** (leave-one-pair-out, matching the harness discipline, not
a random split) to pick `nrounds`; out-of-fold predictions are genuinely
held-out.

- **Primary-share RMSE: 4.4657 (shipped) → 4.0132 (xgb v1), a 10.1%
  reduction, improving in every jurisdiction** (fed 4.26→3.69, nsw
  5.25→4.99, qld 3.79→3.32, sa 5.26→4.84, vic 4.45→4.02, wa 4.98→4.77).
- **Seat log loss** (xgb primaries substituted into the actual
  `simulate_seat_contests()` pipeline via `R/xgb_primary_override.R`,
  wired into all 6 backtest harnesses behind `AUSPOL_XGB_PRIMARY=1`):
  **pooled 0.3358 → 0.3122, a 7.0% reduction, paired t = −2.89** (clears a
  2.08 SE bar decisively — the only arm today that did). Better in 17 of 22
  pairs. Floor seats (winner given ≤1e-4) improved 4 → 3.
- **Against AEF on the 7 comparable elections, the gap more than halves**:
  0.3196 (shipped) vs AEF's 0.2855 → 0.300 (xgb) vs 0.2855. Still behind
  AEF, most of the way there.
- Feature importance is sane: `pred_share` dominates (68% of gain) — xgb is
  mostly correcting our own number, not ignoring it — then `x` (26%),
  `level_now` (4%). Nothing exotic doing the work.

**Two real caveats, not yet resolved:**
- SA (+0.048) and vic2014/vic2018 got WORSE. WA showed the biggest gains but
  had the weakest feature coverage (many seats fall back to the shipped
  value — historical WA redistributions break seat-name matching, a known
  issue this repo has hit before) — the WA result deserves a sanity check,
  not blind trust.
- **On the worst-20-seats-vs-AEF table specifically, xgb is WORSE than the
  shipped model** (mean abs error on the actual winner's primary: shipped
  14.54, AEF 6.72, xgb v1 **15.18**). The pooled win comes from the broad,
  ordinary population of seats, not from fixing the rare independent
  emergences that dominate our biggest actual misses.

## Why it fails on the rare cases — diagnosed, not fixed

Traced directly on sa2026 ONP (Narungga, Taylor, MacKillop, Chaffey,
Elizabeth): the shipped model already undershoots the ONP surge in these
seats (established earlier in the session — the flat "new"-candidate
constant problem). XGBoost, trained on the pooled population, **shrinks
those already-low predictions further** rather than correcting them upward
— Narungga went 28.2 (shipped) → 23.8 (xgb), actual is 37.5.

This is the FOURTH mechanism today to hit the identical wall (after the
dispersion-slope arm's IND crush, the flat "new" ONP constant, and the
class-level slope work): **a model fit on the bulk/ordinary population
underserves rare emergence events, whether the model is a hand-built
constant or a learned tree ensemble.** The one thing that has actually
worked all day is a deterministic, non-statistical override — the salience
screen's `permit=TRUE → slope=1.0` rule, which doesn't try to learn the
rare case at all, it just detects and exempts it.

### Attempts to fix it, all tested, none there yet

- **v2** (`fit_xgb_primary_v2.R`): added salience features (`jump`,
  `governed`, `permit`) as raw xgb inputs. **Made SA ONP WORSE** (4.94
  shipped → 5.52 v1 → **6.51 v2**). Feature importance for `permit`: 0.0005,
  essentially ignored — a signal covering a few hundred of 14,495 rows can't
  win a split competition against everything else.
- **v3** (`fit_xgb_primary_v3.R`): added surge-v2 hazard (`surge_h`,
  `is_recipient`) on top of v2. Same story — importance 0.0017, SA ONP
  **5.70**, marginally worse again. Pooled RMSE barely moved (10.13% →
  10.26%, noise-level).
- **v4** (`fit_xgb_primary_v4.R`): Pete's idea — upweight rows flagged
  `permit`/`is_recipient` 8x in `xgb.DMatrix`'s `weight` argument (evaluated
  unweighted, so this isn't scoring our own thumb on the scale). **Worked
  partially**: on the 4,421 flagged rows, RMSE improved 5.41 → 4.92 (9%),
  and SA ONP improved to 5.36 (better than v1/v3, still worse than
  shipped's 4.94). But pooled improvement DROPPED to 8.49% (from v1's
  10.13%) — a third of all rows getting 8x weight is too broad a brush,
  it's not actually "rare" any more at that scale, and it costs the bulk
  fit.

**Reference point going forward is v1** (no salience/surge features, no
weighting) — the strongest pooled result, at the known cost of the
worst-case seats.

## For tomorrow

1. **Tighten what counts as "rare"** before reweighting again — `permit`/
   `is_recipient` fired on 30% of rows, nowhere close to rare. A narrower
   flag (e.g. `permit AND jump above some higher percentile`, or restricting
   to classes/tiers this session already knows are thin) might get the
   weighting benefit without the aggregate cost.
2. **Try the deterministic-override idea directly**, not just weighting:
   for flagged rows, don't ask xgb to predict at all — keep the shipped
   model's (or the salience screen's) value outright, same as the actual
   forecast pipeline already does. That sidesteps the "rare pattern loses
   the statistical vote" problem entirely rather than fighting it with
   weight.
3. **Sanity-check WA's result** before trusting it — lowest feature
   coverage of any jurisdiction, largest gains. Could be real (WA's
   baseline log loss is the worst in the corpus, so there's genuinely more
   room) or could be an artefact of which cells fell back to the shipped
   value.
4. **Investigate the Victoria 2014/2018 and SA regressions** the same way
   the SA ONP one was diagnosed here — by seat, not just by pair.
5. Consider whether a **blend** (shipped model where thin/rare-flagged,
   xgb where the bulk of ordinary cells sit) beats either pure model — v4's
   partial result suggests the right answer is somewhere between "trust xgb
   everywhere" and "trust xgb nowhere," not at either end.

## Also parked today, negative results (own-seat multi-election lean)

Pete's separate idea — use several past elections' seat lean, decayed,
instead of just the last one — was tested three independent ways on real
federal 2pp data (140 seats, 4 real cycles: 2016/2019/2022/2025) and found
**no usable signal** in any of them:

- Decayed weighted average of past leans: best weight found gives a 0.5%
  RMSE improvement, statistically indistinguishable from zero (t = −0.12,
  better in exactly 140 of 280 seat-folds — a coin flip).
- Momentum extrapolation (does last swing's direction persist?):
  correlation(last delta, next delta) = **−0.10** — mild reversion, not
  momentum. Same near-zero result as the decayed average (they're the same
  linear-predictor family in disguise).
- Volatility-bucketing (are stable seats at least more predictable, even if
  we can't say which direction?): correlation(past volatility, future
  prediction error) = **0.04** — essentially zero. Even the most stable
  third of seats gets ZERO benefit from weighting in older history.

Explicitly NOT written off — Pete's instruction was "park it, not kill it."
**What's untested**: using FEDERAL results as a correlated signal for a
STATE seat's lean (genuinely different data, not just re-slicing the same
seat's own past) — that's a real idea nothing here rules out, it just needs
seat-boundary matching infrastructure that doesn't exist yet.

## Also refused today, for completeness

`docs/plans/prereg-dispersion-slope-2026-09-09.md` — replacing the flat
"new"-candidate slope with corr × sd-ratio, fit leave-one-out. Two rounds
(all 4 classes, then GRN/ONP only after Pete correctly identified IND and
OTH_RIGHT aren't real single-brand parties). Both refused on the
pre-registered pooled-log-loss bar. Full detail in that plan file.

## Repo state as of this write-up

- `R/split_slope.R` carries `fit_dispersion_slopes()`, inert
  (`AUSPOL_DISPERSION_SLOPE=0` in `published_flags.R`).
- `R/xgb_primary_override.R` and `scripts/fit_xgb_primary*.R` (v1-v4) are
  new, uncommitted. `AUSPOL_XGB_PRIMARY` is wired into all 6 backtest
  harnesses but **not into `fit_seats_full.R`** (the published forecast) —
  this is exploratory only, nothing here has touched the live Victorian
  forecast.
- `output/xgb-primary-oof-predictions.csv` (v1, the reference) and
  `-v2`/`-v3`/`-v4` variants are on disk, gitignored.
- All experimental backtest output files were cleaned up after scoring;
  `scripts/pool_backtests.R` reads the clean shipped baseline (0.3358)
  as of this write-up, not any of today's arms.
- **Nothing from today has been committed.** `git status` shows the
  dispersion-slope work (R/split_slope.R, 6 harness edits,
  published_flags.R, tests) and the new xgb scripts/R file as modified/
  untracked. Held for Pete to review in the morning rather than committed
  unasked.
