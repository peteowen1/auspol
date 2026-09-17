# Repo speed-up opportunities, 2026-09-17

Written mid-session, deliberately fast/complete over polished — context was
about to compact. **Purpose: if runtime halves, we can do twice as much
measurement in the same session.** Everything below is either verified today
or clearly labeled as unverified/a next step. Test each one before trusting
it, same discipline as everything else in this repo.

## Session context this was written in

Long session: shipped `seat_prev_pcv` NA-fill (PR #46), fixed a stale
published snapshot and two separate live train/serve mismatches (PR #46,
#48), ran and closed two pre-registrations (minor-defector rate refused,
major-defector conservation settled), found and fixed a real live bug
(minor-to-major `personal_prior_vote()` substitution erasing a retiring
major incumbent's base — PR #49, **already affecting the live Victoria
forecast**, fixed and merged). Then tested `AUSPOL_XGB_BASE_MARGIN`
(residual-to-`base_pred` training) — refused on the full 23-pair pooled
bar but won clearly on AEF7 (the 7 pairs with an external published
benchmark). **Pete's call: use AEF7 as the fast-iteration decision
criterion going forward** (not necessarily replacing the all-23 pooled bar
for a final ship decision, but for quick iteration — the two are in
tension and haven't been formally reconciled).

**In flight when this was written**: a background fork
(`a392063075f8f98cc`) is regenerating v6/v7/the shipped snapshot to
actually ship `base_margin` (or not, depending on what a fresh v7f-vs-v6-
base_margin comparison shows), regenerating the live forecast, retraining
the final model, and building a worst-seats-vs-AEF table restricted to
AEF7. **Check `ListAgents` / wait for its notification before assuming
its outcome.**

## What prompted this: Pete's direct question

*"we've spent all day running arms - i thought we were saving stuff so we
didnt have to spend 3 hours running everything every time?"*

Fair complaint. Partly justified by genuine cause (code kept changing --
new bug fixes, new flags -- so "fresh" often meant something real
changed), partly a real gap: no discipline for checking "does a cached
artifact already reflect current code + flags" before defaulting to
rerun. The stale-snapshot bug found earlier today (a 3-day-stale
published-model file) made this worse by teaching over-correction toward
"just regenerate everything," which is itself expensive.

## Ideas from CITIUS (a peer Claude session, different verse, same
## problem independently)

1. **`compare_arm_fingerprints.R`** — a ~40-line tool that diffs two
   cached arms' fingerprints and asserts they differ ONLY in the field
   under test, printing the diff. Lets you say "the arms differ only in
   the mechanism" instead of hoping so. citiusverse's own fingerprint
   (`_arm.rds`: 52 settings + md5s of history/store/calibration/aging/
   shock files) caught data drift but NOT code drift — CITIUS added a
   column to a script's history keep-list today and the cache was still
   accepted, because no fingerprint field moved. Fix queued there: md5 of
   the script + git SHA of the package, added to the fingerprint.

2. **Report a zero-movement bucket FIRST, before any other result.**
   CITIUS almost shipped "altitude doesn't help" today: a column had been
   narrowed out upstream so the mechanism literally couldn't fire, both
   arms produced byte-identical predictions, and the pooled MAE looked
   perfectly respectable for both. Now reports: if rows the mechanism
   touches are not identical between arms, nothing else is readable; if
   EVERY row is identical, there is no experiment. **Same shape as this
   repo's own catch earlier today** — a fork's first backtest pass
   silently compared `output/xgb-primary-shipped-oof-predictions.csv`
   against itself (both arms read the frozen snapshot, not the file being
   swapped) and got byte-identical Brier scores across all six harnesses
   before catching it.
   **Implementation subtlety CITIUS flagged after building it**: bucket
   the invariance check on movement EXACTLY zero (`|B-A|/A == 0`), not
   "below a small threshold" — a `<=0.01%` threshold at first pass
   included rows that genuinely moved a little and made a healthy run
   report `t=4.53, p<0.0001` on its own guard, i.e. flagged a working
   comparison as broken. The check is ~6 lines: per-row relative
   movement, bucket, print the exact-zero bucket's share first.

3. **Shrink the unit of value below the unit of the run.** Not "be more
   disciplined" — make the cheap, provably-current partial result the
   easy path so the reflex to regenerate everything has less pull.
   citiusverse went per-meet cache -> per-chunk writes -> an ability cache
   keyed only on settings that can actually change an ability (excluding
   simulation-only knobs, so a marks arm and a full-simulation arm share
   the cache). Measured 171s -> 25s on the same 8 meets.
   **Key design choice CITIUS called out**: the cache fingerprint is an
   EXCLUSION list (name the fields that can't affect output, hash
   everything else) not an INCLUSION list (name the fields that can).
   The failure modes aren't symmetric — a stale exclusion list gives a
   missed cache hit (slow but correct); a stale inclusion list gives a
   wrong cache hit (fast but silently wrong). For our
   `AUSPOL_XGB_SKIP_TRAIN` idea (item 4 below), the equivalent is:
   fingerprint the feature matrix + training setup, exclude only what's
   applied strictly after the model already exists (SHAP extraction,
   downstream reporting) — never the reverse.

## Ideas found in auspol today, verified

1. **DONE, 2026-09-17.** WA and VIC were the two of six harnesses with no
   per-pair restriction flag (fed/nsw/qld/sa all had one). Added
   `AUSPOL_WA_PAIR` and `AUSPOL_VIC_PAIR` to `scripts/backtest_candidate_wa.R`
   and `scripts/backtest_candidate_vic.R` — comma-separated target year(s),
   e.g. `AUSPOL_WA_PAIR=2013`, default unset = all pairs (unchanged
   baseline behaviour). Verified both fire (single-pair run prints
   `BW0p`/`BV0p` and scores only that pair) and that an unset run still
   covers all pairs (VIC: 3/3, `BV5 ... 933 rows over 3 pair(s)`). Not yet
   committed. Regenerated `docs/MODEL-REGISTRY.md` to pick up the two new
   switches (harness-only, correctly not in `published_flags.R` — same
   category as the existing `AUSPOL_{NSW,QLD,SA}_PAIR`, which aren't
   there either).

2. **`output/` is 1.8GB across 5,263 CSV files, 4,915 of them
   `backtest-*.csv`.** Verified via `du -sh` / `ls | wc -l`. Doesn't slow
   any single run much, but this volume is *why* "newest file per pair"
   (the convention `pool_backtests.R`/`pool_sharedetail.R` both use) is
   fragile — it's picking one file out of thousands by mtime, which is
   exactly the mechanism behind the stale-snapshot bug and the
   arm-mixing bug (`AUSPOL_AEF_RUNDIR` exists in `build_aef_comparison.R`
   specifically because of this). **Worth an archival pass**: keep N
   newest per pair, or move anything not matching a current arm
   fingerprint into a dated subfolder. Not yet built. Riskier than #1 --
   check nothing still-needed gets swept before automating this.

3. **CLOSED, verified 2026-09-17 — do not build this.** Checked whether
   `.arm_fingerprint` includes a code version (the exact gap CITIUS found
   in `_arm.rds`) before building anything for it, per this repo's own
   "ask what the system already has" rule. It already does: every
   harness's `CAL_TAG` appends `.code_tag`
   (`scripts/harness_defaults.R:45-52`) — the short git commit SHA, plus
   an `x` suffix when `R/` or `scripts/` carry uncommitted changes — on
   top of `.arm_fingerprint`'s hash of every set `AUSPOL_*` variable. A
   code change with no flag change DOES change the output filename here.
   No auspol equivalent of CITIUS's queued `_arm.rds` fix is needed.

4. **Real redundant compute: full feature-build + full `xgb.cv` rerun
   even when only the training SETUP changes, not the features.** Every
   plain-vs-`base_margin` comparison today reran `fit_xgb_primary_v6.R`
   from scratch (~2-3 min each), even on pairs where the 41-column
   feature matrix was byte-identical between runs and only the
   `xgb.DMatrix` base_margin/label setup differed. `AUSPOL_XGB_SKIP_TRAIN`
   already exists (caches the feature matrix, skips training, built for
   `scripts/shap_from_cached_model.R`) but isn't wired into the
   compare-flags workflow. **A CITIUS-style fingerprint on the OOF
   output (git SHA + every set `AUSPOL_*` var) would let a script/fork
   check "has this exact config already been measured" before re-running
   the ~2-3 min `xgb.cv`, not just the fast feature build.** Not yet
   built — this is the single biggest per-iteration time cost after the
   WA/VIC pair-restriction gap, since it applies to EVERY future flag
   comparison, not just base_margin.

5. **GPU acceleration — checked, currently blocked, not a quick win.**
   This machine has an NVIDIA GPU (`nvidia-smi` confirms CUDA 13.2
   driver), and `xgb.cv` (the actual ~2-3 min bottleneck in every v6/v7
   run, on a 13,739x41 matrix with 23-fold CV) is exactly the shape GPU
   histogram training helps with. **Benchmarked directly**: CPU vs
   `device="cuda"` on synthetic data matching real dimensions gave
   `1.0x` speedup, because the installed R `xgboost` build (3.2.1.1)
   silently falls back to CPU with a warning
   (`"Device is changed from GPU to CPU as we couldn't find any available
   GPU on the system"`) — it's a CPU-only build, not a driver/hardware
   problem. **Would need a CUDA-enabled xgboost reinstall to actually
   test this lever** — a separate, possibly fiddly task on Windows, not
   attempted today. Worth doing if the per-iteration cost of #4 above is
   still too high after fixing #1 and #4.

## Not yet investigated, worth a look next session

- **`fit_xgb_primary_v7.R`'s own runtime** — it's an "800+ line
  exploratory file" per its own header, fits multiple arms (`v7c`, `v7f`,
  possibly more) sequentially via separate `xgb.cv` calls each. Never
  timed directly today. If it fits N arms sequentially and they're
  independent, could they run in parallel (multiple R processes, or
  xgboost's own multi-threading budget split across arms)?
- **Candidate/salience/census data-build scripts** (`build_candidacies.R`,
  `build_data_registry.R`, `fetch_*` scripts) — never profiled, assumed
  fast (parsing pre-fetched files) but never actually timed. Cheap to
  check with `Sys.time()` deltas before assuming they're not worth
  touching.
- **Whether `xgb.cv`'s `nrounds=2000` ceiling wastes anything** — early
  stopping already halts around 150-280 rounds in every observed run
  today (232 for the base_margin variant, 237 for plain), so the 2000
  ceiling itself isn't obviously wasteful, but not confirmed with a
  proper profile.
- **Whether the six harnesses' full Monte Carlo simulation step
  (post-swing, `AUSPOL_N_SIMS`) is still the "45s vs ~11min, C++ vs R"
  win from 2026-09-07** given ten days of feature additions since then
  (salience, surge, defector discounts, census, base_margin) — the
  compiled core itself hasn't changed, but worth reconfirming the
  claim still holds rather than assuming.

## Built, 2026-09-17: `scripts/compare_arm_outputs.R`

CITIUS's zero-movement-bucket-first discipline (item 2 above), generalised
into a standalone tool: takes two output CSVs, a set of key columns and a
value column, joins on the keys, and prints the exact-zero-movement bucket
FIRST — before any RMSE/mean-move stat — flagging both failure shapes
(>=99.9% identical = no experiment ran; <0.1% identical when a targeted
change was expected = touched more than intended). Bucketed on movement
EXACTLY zero per CITIUS's own correction, not a threshold.

Dry-run against today's cached base_margin OOF predictions
(`output/_prereg_basemargin/oof-{BASELINE,BASEMARGIN}.csv`) reproduced the
known result exactly: 0% in the zero bucket (base_margin is a training-wide
change, so touching every row is correct here, not a confound), and the
per-pair breakdown correctly re-surfaces sa2026/wa2013/wa2021 as the largest-
movement pairs, matching this morning's SHAP-based finding.

```
Rscript scripts/compare_arm_outputs.R <file_a> <file_b> [key_cols] [value_col]
```

Next real use: point it at any future flag-comparison OOF pair before
reading its headline metric.

## Plan: test these out

In priority order (cheapest + highest-value first):
1. Add `AUSPOL_WA_PAIR` and `AUSPOL_VIC_PAIR` restriction flags,
   mirroring `AUSPOL_SA_PAIR`'s existing pattern exactly. Verify with a
   quick single-pair run that it actually restricts (same discipline as
   every other flag in this repo: prove it fires, don't assume).
2. Check `.arm_fingerprint`'s actual composition (`grep -rn
   "arm_fingerprint"`) — confirm or deny the code-version gap before
   building a fix for something that might already be handled.
3. If the gap is real: design a fingerprint (git SHA + sorted list of
   every set `AUSPOL_*` var) written alongside `xgb-primary-v6-oof-
   predictions.csv` and the harnesses' own outputs, plus a
   `compare_arm_fingerprints`-equivalent that asserts two runs differ
   only where expected.
4. Output/ archival pass — LOWER priority than 1-3, and riskier (don't
   want to sweep something still-referenced). Do this only after 2-3
   exist, since a real fingerprint system makes "is this file still
   canonical" answerable instead of guessed.
5. GPU xgboost reinstall — only if 1-4 don't get iteration time down
   enough on their own. Separate, standalone task; don't block on it.
