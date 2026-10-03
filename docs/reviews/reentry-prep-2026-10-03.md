# Re-entry prior (`AUSPOL_REENTRY`): decision prep, 2026-10-03

Read-only investigation. Nothing in R/ or scripts/ was edited and nothing was run.
Status: the switch is OFF and was never decided. This file is what Pete needs to
decide it, and the exact rebuild to measure it.

## 1. The criterion, quoted

### 1a. The original (docs/plans/prereg-reentry-prior-2026-09-07.md, lines 54-68)

> Primary: **PB3f, pooled seat log loss excluding floor seats** (currently 0.3056
> over 2,045 seat-elections), and the **floor count** (currently 5). ...
> Co-primary: **pooled seat-share RMSE.** ...
> Guards: per-jurisdiction log loss (all six), and accuracy.
>
> **Decision rule.** Adopt if PB3f improves or is unchanged within 0.001 while the
> floor count falls, AND pooled RMSE does not worsen by more than 0.05, AND no
> jurisdiction's log loss worsens by more than 0.01.

Refusal section (lines 85-98): (1) losers inflated: report count of re-entry cells
projected above 15% that finished below 5%, refuse if the RMSE gain is smaller than
the log-loss gain; (2) a gain confined to WA: sign must hold in at least 3
jurisdictions; (3) IND ratio (1.36) driven by a handful of cases: report its value
with the top five removed, below 1.0 means refuse.

### 1b. It was superseded in the 2026-09-08 plans (do not decide against 1a alone)

Four follow-up preregs exist (`prereg-reentry-{bounded,defended-nonmajor,lean-gap,
flatratio-variance,personal-vote-priority}-2026-09-08.md`). The live criterion text
is in `prereg-reentry-lean-gap-2026-09-08.md`, lines 60-78:

> Primary: PB3f over 22 pairs and 2,050 seat-elections. Prior OFF is 0.3149 (floor 4);
> prior ON with no arm is 0.3139 (floor 3).
> Co-primary: the count of re-entry cells predicted above 40 must fall to 0, and the
> largest prediction must be below 40. Currently 5 and 74.3.
> Guards: pooled seat-share RMSE; per-jurisdiction log loss against prior OFF,
> tolerance two standard errors of that jurisdiction's own paired difference.
> Decision rule. Adopt an arm if clause 1 (the tail) is met, AND PB3f is at least as
> good as prior OFF's 0.3149, AND no jurisdiction breaches its two-SE tolerance.

Outcome on 2026-09-08 (same file, lines 265-290): arm D (`AUSPOL_REENTRY_GAP=winsor`)
was REFUSED by clause 1 (two new floor seats via the flat-ratio major-party path:
Alfred Cove, Churchlands), primary effect 0.85 SE. "`AUSPOL_REENTRY` stays 0." Arm H
(variance widening, `AUSPOL_REENTRY_SD_K`) was refused at its own rule
(`docs/reviews/arm-h-variance-widening-2026-09-08.md`). Seed-averaged 20k-sim result
(`docs/backlog/journal-2026-09-07-to-08-reentry.md` lines 105-123): WA, SA, fed 2007-16
better; Victoria flat; fed 2019-25 flat/worse; NSW and QLD worse (1-4 seats each, mostly
Kiama, Traeger, Hill, Burdekin). No pooled 22-pair seat-weighted number was ever computed.

**So "never decided" is partly wrong: it was tested and refused on the 09-08 clause,
then never revisited after the model changed (v6 xgb, as-at models, v59-v61).** The
decision Pete needs is whether to re-test arm D on today's pipeline, and against which
criterion (see section 6).

## 2. Where the switch is read (call sites, function-name grep, comments excluded)

Only ONE place reads `AUSPOL_REENTRY`:

- `R/reentry_prior.R:673`, inside `reentry_apply_harness()` (defined at line 671):
  `if (!identical(Sys.getenv("AUSPOL_REENTRY", "0"), "1")) return(mat)`.
  Its sub-switches: `AUSPOL_REENTRY_SPLIT` (129, 179), `_GAP` (135, 415), `_LINK` (149),
  `_WINSOR` (409).
- Not in `scripts/published_flags.R` and not in `scripts/export_published_flags.R`
  (grep: no match), so the rebuild does not export it; it defaults to "0".

Callers of `reentry_apply_harness()` (all backtest harnesses, none in the live script):

| harness | call line | post-swing fill line |
|---|---|---|
| backtest_candidate_vic.R | 421 | 652-666 (fill into `shares`) |
| backtest_candidate_fed.R | 717 | (see grep `REENTRY_CELLS`; sd use at 1796) |
| backtest_candidate_nsw.R | 408 | sd use at 981 |
| backtest_candidate_qld.R | 394 | sd use at 1002 |
| backtest_candidate_sa.R | 452 | sd use at 1154 |
| backtest_candidate_wa.R | 471-491 (own inline version, calls `reentry_fit` / `apply_reentry_prior` directly) | sd use at 706 |

Related: `protect_personal_vote_cells()` (`R/candidate_returns.R:1131`) is called from
the harnesses (vic line 658) and only fires when `REENTRY_CELLS` is populated.
`reentry_sd_matrix()` (`R/reentry_prior.R:585`) is gated by `AUSPOL_REENTRY_SD_K` (0).

**`scripts/fit_seats_full.R` (the published forecast) has no reference to re-entry at
all** (grep for `reentry`/`REENTRY` in fit_seats_full.R, rebuild_forecasts.sh,
published_flags.R, harness_defaults.R, fit_xgb_primary_v6.R, build_forecasts_table.R:
zero matches). So turning the switch on affects backtests and the xgb training data
only. It cannot change the live Victoria 2026 forecast without new wiring.

## 3. Does it reach base_pred / dev_slope() AND the xgb layer?

Order of operations in a harness (vic as the example):

1. `REENTRY_CELLS` computed from the previous-election matrix (vic:421).
2. `dev_slope()` / `split_dev_slope()` builds the post-swing `shares` (vic:637-638).
   The re-entry prior is NOT inside `dev_slope()`; it is written on top of the
   post-swing result at vic:652-666 (the comment says it was moved there so the value
   is not swung twice).
3. `xgb_primary_override(shares, pair)` runs later (vic:746) and, when
   `AUSPOL_XGB_PRIMARY=1`, replaces every cell that has a prediction in
   `output/xgb-primary-asat-predictions.csv` (`R/xgb_primary_override.R:21-95`, the
   `out[hit, p] <- pmax(0, v[hit])` loop).

Consequences:

- **Stage 1 (`AUSPOL_XGB_PRIMARY=0`)**: re-entry is in the sharedetail `base_pred`. This
  is the only way it reaches the xgb layer: `fit_xgb_primary_v6.R` takes
  `pred_share` from the stage-2 sharedetail pool and renames it `base_pred` (lines
  294-296), then uses it as a feature (line 695), and `base_pred` is also the
  `base_margin` when `AUSPOL_XGB_BASE_MARGIN` is on (line 734). Stages 3-5 retrain
  on it.
- **Stage 6 (`AUSPOL_XGB_PRIMARY=1`)**: the re-entry fill is overwritten by the xgb
  prediction for every cell in the cache. The fill survives at stage 6 only for cells
  with no row in the cache (n_miss in the `XG1` log line). So the stage-6 effect
  comes through xgb, which was trained on a re-entry-aware `base_pred`.
- **Stale-cache trap**: `xgb_primary_override()` reads a static file. Running only
  stage 6 with the switch on changes nothing (`R/xgb_primary_override.R:35-52` warns
  only if code files are newer; `reentry_prior.R` is NOT in its `.oof_deps` list, so
  it would not even warn). The switch must be on from stage 1.
- **Which function matters for the published forecast**: `xgb_primary_predict_live()`
  (`R/xgb_primary_override.R:170`, called at `scripts/fit_seats_full.R:1139`,
  `AUSPOL_XGB_PRIMARY_LIVE = "1"` at `published_flags.R:87`). `xgb_primary_override()`
  is the backtest counterpart only (the file's own header, line 3). Live takes
  `shares` from `fit_seats_full.R`, which has no re-entry step, as the model input
  (base_margin / base_pred feature). Even if the stage-1..5 models are retrained on
  re-entry-aware `base_pred`, live serving would feed them a `base_pred` WITHOUT the
  re-entry fill: a train/serve mismatch. To ship, the same fill must be added to
  `fit_seats_full.R` before `xgb_primary_predict_live()` (and nominations/standing
  list needed live, as with `zero_unnominated()`, NEXT-STEPS item 1).

## 4. Which pairs and seats it touches (rerun only what is stale)

A cell qualifies only if the class has a candidate standing at the target election and
no prior-election vote in that seat. The original prereg counted 1,026 seat-party rows
over 22 pairs (the harness comment in vic says 1,418 earlier; the two numbers disagree,
unresolved). By group, from the 09-08 runs: WA, SA, fed 2007-16, fed 2019-25, Victoria
(3 pairs), NSW (2019, 2023), QLD (2020, 2024) were all affected.

Richmond 2022 is the vic2022 pair. Whether Richmond's Liberals is a re-entry cell
(Liberals did not stand in Richmond 2018, or stood and the standing list differs) is NOT
confirmed here; check `REENTRY_CELLS` output in the vic log line `BV1r  re-entry prior:
N cell(s) filled | largest: ...` and `output/candidacies.csv`.

Because the switch changes `base_pred` in every harness, and stage 3-5 retrain on
`base_pred`, **nothing downstream is reusable**: every pair's xgb-layer result changes.
"Rerun only what is stale" therefore means: everything from stage 1, but all nine
stage-1 and nine stage-6 harness runs (fed, wa, vic, nsw x2, qld x2, sa x2). The only
saving is `AUSPOL_REBUILD_ONLY`, which is forbidden below stage 6 by the script
(`rebuild_forecasts.sh:68-71`). Cells that cannot move: any pair/seat where every class
contested the previous election (pilbara wa2001 per the original prereg dry-run case 3).

## 5. Commands

Run from `C:\dev\auspol`. Check free memory first (the script picks harness slots by
free GB; 20,000 sims at six-wide needs ~10 GB; another session may hold memory, see
memory note "memory-watchdog-kills-wrappers"). Do not run `R CMD check` concurrently.

Baseline: the current v61 ledger, already built (AEF-7 ledger 0.2677 over 681 seats;
22-election log loss 0.3413; all-row primary RMSE 4.044, per NEXT-STEPS 2026-10-03). Copy
`output/` results first (stage 9 promotes; see below) so arm and baseline can be compared.

Arm D as it was defined on 2026-09-08 (lean-gap winsor):

```
bash scripts/rebuild_forecasts.sh        # NOT with --promote; see stage 9 note
```
with these env vars set in the same shell, before it:
```
export AUSPOL_REENTRY=1
export AUSPOL_REENTRY_GAP=winsor
# AUSPOL_REENTRY_SPLIT defaults to 1; AUSPOL_REENTRY_LINK defaults to log; leave both.
# AUSPOL_N_SIMS defaults to 20000 in the script (the deciding run); AUSPOL_STAGE1_SIMS=2000.
```
The rebuild script exports the published flags for anything unset, so the arm sits on the
published configuration. Ensure stage 9 does NOT publish an arm run to the shipped
release: stage 9 (`rebuild_forecasts.sh:246-252`) runs `promote_rebuild.R` and
`publish_shipped_release.R`. UNCONFIRMED: the exact gate that stops stage 9 (read lines
238-252 before launching; I did not read them). Safest: `AUSPOL_REBUILD_FROM` stays 1 and
check the script for a "no-promote" variable first, or snapshot `output/` and restore.
Memory note "hand-reruns-contaminate-output": a by-hand run left in `output/` can be
published by the ledger.

Optional cheaper first look before the 40-minute rebuild (does NOT replace it; it
cannot show the xgb effect): the vic log `BV1r` lines from one harness at stage-1 settings:
```
$env:AUSPOL_REENTRY=1; $env:AUSPOL_REENTRY_GAP='winsor'; $env:AUSPOL_XGB_PRIMARY=0; $env:AUSPOL_N_SIMS=2000
powershell.exe -Command 'Rscript "scripts/backtest_candidate_vic.R"'
```
Read `BV1r  re-entry prior: N cell(s) filled | largest: ...` and look for Richmond/LNP.
(Hand run: move its output file out of `output/` afterwards.)

Resume points if a stage dies: `AUSPOL_REBUILD_FROM=<n> bash scripts/rebuild_forecasts.sh`
with the same `AUSPOL_REENTRY*` exports (they must be identical on resume, or the
stages disagree).

## 6. How to read the result

Compare arm against the baseline rebuild on the same code, same seed (`AUSPOL_SEED` 42),
same 20,000 sims, using `scripts/pool_backtests.R` output (stage 7, newest file per pair
with timestamp and code tag; confirm the tag shows the arm, not an older run) and
`scripts/compare_rebuilds.R`.

1. The tail clause first (lean-gap clause 1): count of re-entry cells predicted above
   40 must be 0 and the largest prediction below 40. Read from the `BV1r` "largest:"
   lines in each stage-1 log (`output/rebuild-forecasts-logs/s1_*.log`). The refused
   2026-09-08 arm D had 2 new floor seats, so look at Alfred Cove and Churchlands
   (WA) first.
2. PB3f (pooled seat log loss excluding floor seats) over 22 pairs, and floor count;
   must be at least as good as the baseline, within the original rule's 0.001.
3. Co-primary RMSE (all-row primary RMSE; 4.044 baseline) must not worsen by more than
   0.05. Original prereg: log-loss gain larger than RMSE gain means refuse.
4. Per-jurisdiction log loss: not worse than two SE of that jurisdiction's own paired
   per-seat difference (09-08 rule), or 0.01 (09-07 rule). Decide which BEFORE running.
5. Named cells: Richmond 2022 Liberals (actual 18.8, ours 0.0), Kimberley wa2001 (actual
   42.2), Pilbara wa2001 (must be unchanged), Kiama nsw2023, Traeger and Hill qld2024,
   Burdekin qld2020, Alfred Cove and Churchlands wa2008. Check the `XG1` log line count
   of cells replaced vs kept, to know how much of the fill survived into stage 6.
6. Refusals: sign in at least three jurisdictions; per-seat delta trace so one seat
   crossing the 1e-6 floor does not carry the pooled number (this caught arm H and
   the NSW/QLD story).
7. Both layers: report base_pred (stage-1 sharedetail) and the final xgb-layer number
   for Richmond separately, per `docs/CLAUDE.md` "test base_pred AND the xgb layer".

## 7. What I could not confirm

- Whether Richmond 2022 Liberals is actually a re-entry cell, and where the 0.0 comes
  from (not traced; the DECISIONS.md line is the only source seen). The re-entry fit
  may not fill it (e.g. Liberals did contest Richmond 2018, or a nomination zeroing
  step, v61 `zero_unnominated`, set it to 0, which is a different mechanism).
  Check that first; it decides whether this switch is even the cause.
- Which criterion Pete regards as binding (09-07 vs 09-08 lean-gap), and whether the
  09-08 refusal on clause 1 still stands on the current pipeline.
- Whether the fed harness fill line mirrors vic's (I read vic 421-666 only; fed and the
  others were located by grep, not read).
- Stage 9 behaviour for an arm run (not read past line 252's grep hit): confirm it will
  not promote or publish.
- The wall-clock of the rebuild and memory headroom now (NEXT-STEPS says ~40 min; fed is
  431 s critical path).
- The count of qualifying cells: 1,026 (prereg) vs 1,418 (harness comment).
- Whether any test or doc references that I missed in `tests/` (grep of R/, scripts/
  only for the call sites; tests/ was only included in a file-list grep, which showed
  none).
- Live wiring: fit_seats_full.R has no re-entry call; I did not design it.
