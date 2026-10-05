# The pipeline, stage by stage

Pete's reference (asked for 2026-09-18). Two lists that are easy to confuse:

- **The forecast** is what `fit_seats_full.R` does to produce one election's
  seat probabilities. Four steps. This is "the model".
- **The rebuild** is `scripts/rebuild_forecasts.sh`, eight stages. It runs the
  forecast for every historical election "as at" the day before it, and trains
  the xgb models that step 3 of the forecast needs. The AEF-7 ledger is built
  from its output. It is not a different model; it is the same model run at
  many cutoffs.

A fix to the forecast reaches the ledger only through a rebuild. A fix that
only reaches one of the two is a bug (`CLAUDE.md`, "Two XGB-primary override
paths").

## A. The forecast (`fit_seats_full.R`, one election)

| # | step | what it produces | where |
|---|---|---|---|
| 1 | Poll trend + fundamentals | each party's statewide primary vote at the target date (`state_mean`) | `fit_seats_full.R:409`, `trend_as_at()` |
| 2 | Seat baseline projection | `base_pred`: each seat's last result plus the statewide swing, scaled by candidate identity (who returns, who is new, salience screen, departed-leader retention) | `R/dev_slope.R` (`dev_slope()`, `screened_slopes()`), `R/candidate_returns.R`, `R/salience_screen.R` |
| 3 | xgb primary correction | one tree model, trained on every prior election, takes THIS run's `base_pred` as `base_margin` and adds a learned residual | `xgb_primary_predict_live()`, `R/xgb_primary_override.R`; model file `output/xgb-primary-v6-final.model` (live) or `output/xgb-primary-asat/<election>.ubj` (backtest) |
| 4 | Seat simulation | 20,000 draws: correlated statewide shift, seat noise, surge hazard, preference eliminations, winner. Win probabilities, TCP scenarios, share detail | `simulate_seat_contests()`, `src/seat_sim_core.cpp` |

Step 4 in full detail (the ten sub-steps and the per-draw loop) is in
`ARCHITECTURE.md`, "What the simulator actually does, end to end".

Step 3 is the only step with a trained artefact, which is why the rebuild
exists: the six backtest harnesses (`scripts/backtest_candidate_{fed,nsw,qld,
sa,vic,wa}.R`) are step 1, 2 and 4 replayed at a past date, and they need a
step-3 model that had not seen that election.

## B. The rebuild (`scripts/rebuild_forecasts.sh`, all elections)

Each stage is one script; the driver times them and prints the split.

| stage | script | forecast step it runs | output | why this order |
|---|---|---|---|---|
| 1 | six harnesses, `AUSPOL_XGB_PRIMARY=0` | 1, 2, 4 | `output/backtest-*-sharedetail-*.csv`: `base_pred` per (election, seat, party), no xgb | step 3 trains on `base_pred`, so `base_pred` must exist first, without step 3 in it |
| 2 | `pool_sharedetail.R` | | `output/pooled-sharedetail.csv`, 23 pairs | one table of every `base_pred`; refuses if any file had xgb on or fewer sims than `AUSPOL_POOL_MIN_SIMS` |
| 3 | `fit_xgb_primary_v6.R` | | `output/xgb-primary-v6-features.csv`: 41 features per candidate row | the feature matrix both trainers read. Its own leave-one-out predictions file is a diagnostic, not what ships |
| 4 | `fit_xgb_primary_asat.R` | trains step 3, once per election | `output/xgb-primary-asat/<election>.ubj` (19 models), `output/xgb-primary-asat-predictions.csv`, `-manifest.csv` | each model sees only elections with polling day before its target (`election_dates()`). Fewer than 4 prior pairs: no model, harness keeps `base_pred` |
| 5 | `fit_xgb_primary_v6_final.R` | trains step 3, cutoff = now | `output/xgb-primary-v6-final.model` | the live Victoria model. Same recipe as stage 4, all 23 pairs |
| 6 | six harnesses at shipped flags | 1, 2, 3, 4 | `output/backtest-*-allprobs-*.csv` etc: seat probabilities | step 3 now reads the as-at file from stage 4 via `published_flags.R` |
| 7 | `pool_backtests.R`, `build_forecasts_table.R` | | `output/pooled-backtest.csv`; `output/forecasts.csv` (one row per candidate per election, 11,991 rows), `output/forecasts-seats.csv` | the persisted forecasts and the pooled scoreboard |
| 8 | `build_aef_comparison.R`, `build_aef7_tcp_actual.R`, `build_aef7_ledger_data.R`, `build_aef7_ledger_html.R` | | `output/aef-comparison-full.csv`, `output/aef7-tcp-actual.csv`, `output/aef7-ledger-data.json` + `-summary.json`, `output/aef7-ledger.html` | the ledger: the two JSON files substituted into `scripts/templates/aef7-ledger.template.html`. Stage 9 uploads the HTML and this file to the release |
| 9 | `promote_rebuild.R`, `publish_shipped_release.R` (only with `AUSPOL_PUBLISH=1` and 20,000 sims) | | `output/shipped/MANIFEST.json`; the `shipped-models` GitHub release (models plus `candidacies.csv`, which CI cannot build) | the daily forecast workflow downloads these; the manifest's date is what its staleness check reads |

**The daily live forecast** (`.github/workflows/forecast.yaml`, 06:00
Melbourne): fetches polls and election data, downloads the shipped models,
runs `run_all.R` (which ends with `fit_seats_full.R`, `build_page.R` and
`build_forecast_json.R`; a validation breach in another state's stage is a
warning, not a failed forecast), and publishes `forecast-vic2026.json`,
`forecast-history.csv`, seat probabilities, seat shares and the HTML page to
the `forecast-latest` release. The site reads those by fixed URL.

Stages 1 and 6 each run two waves, because nsw, qld and sa score one pair
per run (`AUSPOL_NSW_PAIR`, `AUSPOL_QLD_PAIR`, `AUSPOL_SA_PAIR`); fed, wa and
vic score all their pairs in one run.

`AUSPOL_N_SIMS=5000` is an exploratory run (its models must not ship); the
deciding run is the default 20,000. Measured 2026-09-18 at 5,000 sims:
stages 2 to 5 took 10 minutes, stage 6 about 5, stages 7 and 8 under 2.

## B2. Fresh clone

`output/` is gitignored. Before any harness or the live forecast runs on a
fresh clone: `Rscript scripts/fit_mp_slope.R` (writes
`output/mp-slope-by-target.csv` and `-by-class.csv`; `AUSPOL_MP_SLOPE=1`
errors without them, deliberately), `Rscript scripts/build_candidacies.R`
(needs the commission downloads under `external/`), and `gh release
download shipped-models` for the models. Package functions resolve
`output/` through `out_path()` (the repo root), so scripts can run from
anywhere.

## C0. How to test a theory (the fast loop, 2026-09-20)

1. **Smoke, minutes**: `bash scripts/smoke_pair.sh <harness> [year] [AUSPOL_X=1 ...]`
   runs one harness with the xgb layer off at 500 sims (the base_pred point
   estimate is deterministic, so sims do not matter) and prints, against the
   last rebuild's stage-1 file, which cells moved, each class's RMSE before
   and after, and the biggest moves. If the named seats do not move the
   right way here, there is nothing to rebuild.
2. **Decide, ~40 minutes awake**: `AUSPOL_PUBLISH=1 bash scripts/rebuild_forecasts.sh`
   (stage 1 now runs at 2,000 sims, `AUSPOL_STAGE1_SIMS`; only stage 6 needs
   20,000). Pre-register the criterion first. `AUSPOL_REBUILD_FROM=<n>`
   resumes after a failed stage; `AUSPOL_SKIP_PAIRS` names pairs no harness
   can score. For a stage-6-only arm that cannot reach some backtests,
   `AUSPOL_REBUILD_FROM=6 AUSPOL_REBUILD_ONLY=nsw,qld,sa,vic` reruns only
   those and reuses the rest (about half of stage 6 when fed and wa are
   skipped); it refuses before stage 6, and refuses any reused result older
   than the baseline's as-at predictions. A snapshot of such a run holds only
   the backtests it ran, so score it from `output/` (or `pooled-backtest.csv`),
   not from the snapshot alone.
3. **Ledger**: stage 8 writes `output/aef7-ledger.html`; stage 9 publishes
   it with the models. The per-seat inputs for a worst-seat pass are
   `output/aef7-ledger-data.json` (660 rows) and the stage-6 sharedetail.

Not yet cached: the as-at primary models (stage 4, ~4 min) retrain every
run; the flow models (4b) skip when their config hash is unchanged.

## C. Where the switches live

`scripts/published_flags.R` is the only list of what ships. The six
harnesses and `fit_seats_full.R` both read it. `docs/MODEL-REGISTRY.md`
(generated) shows which script honours which switch.

## D. Refreshing the provisional vic2026 candidate list (until nominations close 9 Nov)

`output/candidacies.csv` vic2026 rows are the UNION of Wikipedia
(`external/reference/wikipedia/vic2026-candidates.csv`, from
`scripts/parse_wikipedia_candidates.py`) and ABC's guide. Refresh the ABC half
and rebuild, one line:

```
powershell.exe -Command 'Rscript "scripts/fetch_abc_vic2026_candidates.R"; Rscript "scripts/build_candidacies.R"'
```

The fetcher saves the raw page dated (`external/reference/abc-vic2026/candidates-YYYYMMDD.html`),
refuses a page without `</html>`, and stops if parsed rows differ from the page's
`<tr style="--pc` count. The build matches on seat + `match_key()`, keeps a
`source` column (wiki / abc / both) and `party_conflict`, logs every class
disagreement (BC10b), and refuses to overwrite `candidacies.csv` if any
non-vic2026 line changed (BC11; previous file kept at
`output/snapshots-candidacies-prev-build.csv`). It supplies NAMES ONLY: votes are
NA, so `zero_unnominated()` (`AUSPOL_NOM_ZERO`) ignores these rows; they feed
candidate features (`candidate_returns()`, `personal_prior_vote()`, salience),
not zeroing. Wikipedia needs its own refresh (`parse_wikipedia_candidates.py`).

## E. November procedure: switching on nomination zeroing (v61, published forecast)

`fit_seats_full.R` zeroes parties with no candidate (and sends their share by
preference flows) ONLY when `AUSPOL_NOM_LIVE=1`. The default `auto` never does,
because the vic2026 list in `output/candidacies.csv` is provisional (Wikipedia,
379 candidacies against vic2022's 731) until nominations close at noon on
9 November 2026. Once the VEC publishes the final list:

1. Load the VEC final list into `output/candidacies.csv` (vic2026 rows, party
   classes from `classify_party()`, same `SURNAME, Given` names as the rest of
   the file). Check the log's per-class line afterwards: `NZL ... candidacies per
   class, seats now/vic2022`.
2. Upload that `candidacies.csv` to the `shipped-models` release. The CI
   forecast job does not read your working copy: it downloads `candidacies.csv`
   from that release (`.github/workflows/forecast.yaml`, "Fetch the trained
   models", about line 168).
3. In `scripts/published_flags.R` change `AUSPOL_NOM_LIVE` from `"auto"` to `"1"`,
   in a commit. This has to be the published value: setting `=1` only in the
   environment makes `fit_seats_full.R` stop at its published-flags check (the
   flag differs from `published_flags.R`) unless `AUSPOL_OUT_SUFFIX` is set, which
   is what you want for a trial run and not for the published one.
4. Run the forecast and read the `NZL` lines. Warnings name ALP/LNP seats with no
   candidacy (a major party can genuinely not stand; those cells ARE zeroed), any
   class standing in under 80% of its vic2022 seat count, and `=1` before
   10 November. With `=1`, every failure STOPS the run (`NZL!!`): an unrecognised
   value, missing `candidacies.csv`, no vic2026 rows, no vic2022 baseline, or
   fewer than 85% of vic2022's candidacies (a load error). The run also checks, at
   the final write, that no zeroed cell was revived by a later step.
