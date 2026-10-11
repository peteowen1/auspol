# CI deciding run: design and review (2026-10-11)

Plan item: `plans/fast-iteration-plan-2026-10-11.md`, Phase 1 item 5. File: `.github/workflows/deciding-run.yml`
(new, uncommitted, never pushed, never triggered). Status: YAML parses (python `yaml`); no `actionlint` on this machine.

## What it does

`workflow_dispatch` inputs: `arm` (required, `"AUSPOL_X=1 AUSPOL_Y=0"`), `base` (extra baseline switches, default shipped),
`sims` (default 20000), `pairs` (optional restriction, e.g. `vic2022`), `label`, `inputs_tag` (default `backtest-inputs`),
`anchor_sha` (default: the anchor's HEAD, resolved once), `comment_on` (optional PR/issue number).

Three stages:

1. `plan`: validates inputs (name=value form, no shell metacharacters, every switch must be in `scripts/published_flags.R`,
   the three switches the run forces are refused, arm must differ from base), pins the anchor commit, builds the matrix.
2. `run`: matrix of 22 elections x {base, arm} = 44 jobs, `fail-fast: false`. Each job is `quick_arm.R`'s `run_unit()` on a clean
   machine: all `AUSPOL_*` unset, then base/arm switches, plus forced `AUSPOL_XGB_PRIMARY=1`, `AUSPOL_SKIP_PAIRS=wa2021`,
   `AUSPOL_N_SIMS=<sims>`, plus the harness's own one-election selector; then `quick_hd1_check()` proves the named
   switches were applied and nothing leaked. Uploads `sharedetail.csv`, `allprobs.csv`, `run.log` as artifact `res-<role>-<id>`.
3. `score`: refuses to pool if any of the 44 outputs is missing (a shrunken set of elections is not a result), then runs the
   same paired scoring as the tail of `scripts/quick_arm.R` (`quick_share_diff`, `quick_seat_ll`, `quick_max_diff`,
   `quick_ledger_ll`) at two log-loss floors (1e-6, the harnesses' own; 0.5/N, quick_arm's). Writes the job summary, an artifact
   `deciding-run-results-<label>`, and optionally an issue/PR comment. It does NOT apply the pre-registered clauses: read the
   table against the plan's committed criteria (per-election table includes the worst single election).

## Matrix layout (same list as `quick_units()` in `R/quick_arm.R`; 22 elections)

| harness | selector variable | values | jobs (x2 roles) |
|---|---|---|---|
| fed | `AUSPOL_FED_PAIRS` | 2007 2010 2013 2016 2019 2022 2025 | 14 |
| wa | `AUSPOL_WA_PAIR` | 2001 2005 2008 2013 2017 2025 (wa2021 skipped) | 12 |
| vic | `AUSPOL_VIC_PAIR` | 2014 2018 2022 | 6 |
| nsw | `AUSPOL_NSW_PAIR` | 2019 2023 | 4 |
| qld | `AUSPOL_QLD_PAIR` | 2020 2024 | 4 |
| sa | `AUSPOL_SA_PAIR` | 2022 2026 | 4 |

Splitting fed/wa/vic into one election per job (rather than `rebuild_forecasts.sh` stage 6's one-run-per-harness) is what
`quick_arm.R` already does and its header says it was checked against full runs; but it has NOT been checked at 20,000
sims against a stage-6 run. Do that comparison once (see "Open checks").

## Expected runtime per job (estimates, not measured on a runner)

Sources: `rebuild_forecasts.sh` comments (fed 7 pairs about 4.8 min at 20k sims), `output/rebuild-*.log` (stage 6, 9 runs on
2 to 6 local slots: 424 to 449 s wall), the plan's table (one run 125 to 400 s at 20,000 sims; 50 to 110 s at 1,000), and one
clean-room run done for this review (vic2022, 500 sims, from the packaged inputs: 123 s wall on this desktop including the C++
compile, so setup plus fitting is about 2 minutes and sims are the smaller part).

| job | harness compute at 20k | runner setup (R deps from cache or RSPM binaries, compile, bundle + anchor download) | per job |
|---|---|---|---|
| fed (one election) | about 1.5 to 3 min | 4 to 6 min | 6 to 9 min |
| wa, vic, nsw, qld, sa (one election) | about 1 to 3 min | 4 to 6 min | 5 to 9 min |
| plan / score | seconds / 1 to 2 min | 2 to 4 min | about 5 min |

Free public-repo concurrency is about 20 jobs, so 44 jobs run in about 3 waves: expect 20 to 30 minutes wall for a full run,
about 10 minutes for the one-pair dry run. Memory: fed peaks about 2.3 GB, a runner has 16 GB.

## Every input a harness needs, and where CI gets it

| input | size | CI source |
|---|---|---|
| R code, `DESCRIPTION`, `src/*.cpp`, tracked `external/reference` files (16), `output/mp-slope-by-class.csv` | git | checkout |
| R packages (data.table, xgboost, Matrix, Rcpp, devtools, pkgbuild, glmnet, jsonlite, digest) | - | `setup-r-dependencies` (same as `forecast.yaml`) |
| `external/aus-polling-analyser/analysis` | about 585 MB sparse | sparse clone pinned to one sha (as `forecast.yaml`, plus pinning so base and arm read identical polls) |
| `output/` top-level inputs (1,286 files, 336 MB uncompressed: `xgb-primary-asat-predictions.csv`, `level-recent.csv`, `candidacies.csv`, `xgb-primary-v6-features.csv`, `state-deviation-features.csv`, `salience-v6.csv`, flow features, council/census tables, `aef-comparison-full.csv`, ...) | in bundle | **NEW release asset `backtest-inputs.tgz`** |
| `output/{booths,cache,shipped,xgb-base-ref,xgb-primary-asat,xgb-primary-v6-models}/` (the six subdirectories `quick_arm.R` copies) | in bundle | same bundle |
| `external/elections/` (23 MB, parsed commission results) | in bundle | same bundle. `forecast.yaml` can fetch only SA/VIC/QLD and its comments say the NSW and federal fetchers fail on a runner, so the bundle is the only source |
| `external/reference/{polls,leaders,byelections,htv,climate200,anchor-corrections,council,retirements,wikipedia,successors,abc-vic2026,state-elections-statewide.csv}` | in bundle | same bundle (excludes the 3 GB raw commission downloads) |

Why not the `shipped-models` release: it holds the live-forecast inputs (final models, `candidacies.csv`, `level-recent.csv`,
features), but not the as-at predictions and models (`xgb-primary-asat*`, `xgb-base-ref`, `xgb-primary-v6-models`,
state-deviation features, salience table, ...) that a stage-6 backtest reads, which are built by stages 1 to 5 locally.

## Blockers

1. **The `backtest-inputs.tgz` release asset does not exist.** Pete (or the orchestrator, from the machine that ran the last
   rebuild) must create it; I did not upload anything. Packaging command below. Without it every `run` job fails at
   "Fetch the harness inputs" (by design, loudly).
2. **The bundle goes stale.** It must be rebuilt after any rebuild stage 1 to 5 (anything that changes `output/`). Add it to
   `promote_rebuild.R`/`publish_shipped_release.R` as stage 9 work, or the deciding run measures old as-at models while the
   checkout is new code. Record the git sha in `backtest-inputs.MANIFEST.txt` (the workflow downloads it if present).
3. **A switch that needs data not in the bundle** (a new input produced by an experiment's own script) would fail or silently
   fall back; the HD1 check only proves the switch was applied. Read the `XG4!`-style lines in `run.log`.
4. `external/reference/aec/booths` (672 MB) is excluded; `R/departed_fed.R` reads it. The clean-room vic2022 run showed no
   missing-input line, but a federal job could differ. Check on the fed dry run (below) before trusting fed numbers.
5. Not blocking, but the anchor repo drifts: `anchor_sha` pins it per run, and should match the sha the as-at predictions were
   built with, or runs differ from local ones.

## Packaging the inputs (run once, in `C:\dev\auspol`, Git Bash)

```
{ ls -p output | grep -v / | grep -v '^backtest-' | sed 's|^|output/|'
  for d in booths cache shipped xgb-base-ref xgb-primary-asat xgb-primary-v6-models; do echo output/$d; done
  echo external/elections
  for d in polls leaders byelections htv climate200 anchor-corrections council retirements wikipedia successors abc-vic2026 state-elections-statewide.csv; do echo external/reference/$d; done
} > /tmp/list.txt
tar --force-local -czf backtest-inputs.tgz --exclude='external/reference/polls/demosau' --exclude='external/reference/successors/*.pdf' -T /tmp/list.txt
git rev-parse HEAD > backtest-inputs.MANIFEST.txt
gh release create backtest-inputs --notes "harness inputs for deciding-run.yml" 2>/dev/null || true
gh release upload backtest-inputs backtest-inputs.tgz backtest-inputs.MANIFEST.txt --clobber
```

I built this bundle locally: 1,320 entries, 140 MB, 27 s (kept in the session scratchpad, not uploaded). Check that nothing
private is in it before uploading to a public release (it contains `candidacies.csv`-style data already public via `shipped-models`,
plus council/census tables; look through the list).

## What was actually tested here

- YAML parses; matrix builder run (22 units; `pairs=vic2022` gives 2); input-validation script run on five cases (accepts a good
  arm; rejects forced switch, unregistered switch, shell metacharacters, arm identical to base).
- Clean room: `git archive HEAD` plus the bundle plus the anchor `analysis/` directory, nothing else, ran
  `backtest_candidate_vic.R` for vic2022 at 500 and 1,000 sims to completion; 20 `BYW1!` lines, the same count as the local
  cached run. The run step's HD1 verification code ran correctly on the arm log and collected both CSVs.
- The `score` step run on real cached vic2018/vic2022 baseline and arm outputs (Q0 to Q3 printed, per-election table, both
  floors). Q4 not exercised (no `aef-comparison-full.csv` in that test).
- NOT done: any run on GitHub; a like-for-like numeric comparison of clean-room against local output (the local caches predate
  the 20-day default, so the 0.87 to 0.90 point max difference I saw is explained by config, not shown to be zero); R setup on a
  runner; `max-parallel` behaviour.

## Security hardening (after the automated review)

Done: all third-party actions pinned to full commit SHAs with the tag in a comment (`r-lib/actions` v2 =
`f9a764fe...`, `actions/checkout` v4, `upload-artifact` v4, `download-artifact` v4; resolved with `gh api`, all lightweight
tags pointing to commits); workflow default `permissions: contents: read`, with `issues`/`pull-requests: write` only on the
`score` job (the only one that comments); `GITHUB_PAT` removed (no `Remotes:` in DESCRIPTION, so it is not needed). User
inputs reach scripts only through `env:` and are regex-validated in `plan`; the only inline expansions are `inputs_tag` and
`comment_on` inside `gh` arguments (trusted: only people who can dispatch the workflow can set them).

## Dry run (do this first; two jobs, about 10 minutes)

After the bundle exists and the workflow is on a pushed branch:

```
gh workflow run deciding-run.yml --ref dev -f arm="AUSPOL_LEVEL_RECENT_HALFLIFE=10" -f pairs=vic2022 -f sims=500 -f label=dry
gh run watch
```

Then a fed check, because it is the largest harness and `aec/booths` is excluded: `-f pairs=fed2019 -f sims=500`.
Open check once the workflow works: run the full 22 at `sims=20000` with `arm="AUSPOL_LEVEL_RECENT_HALFLIFE=10"` and compare to
the local 10-day deciding run (code c633fd8, in `output/`) to prove the per-election split reproduces a stage-6 run.
