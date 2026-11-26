# auspol pipeline map and re-run opportunities (26 Nov 2026)

Read-only sweep. Nothing was run, edited or installed. Repo: peteowen1/auspol (public, so GitHub runner minutes are free; wall-clock is the cost that matters). Evidence is `file:line` or a run-log timing. MEASURED = taken from a run log or step timestamps. UNTIMED = my estimate, with how I made it.

Election context: the Victorian election is Sat 28 Nov. Findings 5, 6 and 7 mostly speed up Victorian what-if jobs, whose value falls after that date unless the daily run moves to NSW 2027. Per the 24-hour rule, none of the workflow edits should merge before the 28 Nov election.

## 1. Workflows ranked by wall-clock

Minutes of wall-clock per run from `gh run list --limit 100` (check) and `--limit 60` (forecast); lower is better. n = runs counted.

| Workflow | Trigger | Typical wall-clock | n | Notes |
|---|---|---|---|---|
| Forecast refresh (daily) | inthegame-blog worker dispatches 17:30 UTC; GitHub `37 17` cron is the fallback (`forecast.yaml:19-20`) | 33-45 min (run 45665482641: 17:30:30 to 18:11:26 UTC = 41 min) | 7 daily runs in the last 7 days | Pipeline job 13 min, then 16 scenario jobs, then publish |
| Forecast refresh (manual) | workflow_dispatch | 13-35 min | about 30 in 2 days | Same refresh job; scenarios only when asked (`forecast.yaml:969`) |
| R-CMD-check | every push to dev or main (`check.yaml:4`) | median 5.1 min | 76 finished + 24 cancelled in 100 runs (24-25 Nov) | About 380 runner-minutes in 2 days |
| Election-night backup | manual only, break-glass | 14-52 min (set by the `minutes` input) | 8 | Not an optimisation target; it exists for 28 Nov |
| Scheduler outside GitHub | inthegame-blog worker `*/30` cron dispatches the daily run (`forecast.yaml:12-17`); local one-shot Scheduled Tasks for deciding runs and rebuilds (`CLAUDE.md:485-499`) | n/a | n/a | The 0-minute "Forecast refresh (daily)" rows (e.g. 45733573162, 9 s) are the gate skipping the GitHub fallback because the worker's run already went (`forecast.yaml:74-110`). They are not cache hits |

Correction to carry forward: the daily run is NOT skipped when nothing changed. The gate (`forecast.yaml:85-110`) only skips a second daily run within 12 hours. Every worker-dispatched daily run does the full refresh. A "skip when inputs unchanged" gate is also not safe here, because the forecast moves with days-to-election even on a day with no new poll.

## 2. Pipeline A: Forecast refresh, daily (run 45665482641, 25 Nov, 100,000 sims)

Seconds per step, from step timestamps in `gh run view --json jobs`; lower is better. "Cached?" says where, and whether the folder survives between runs. Runners start from a clean checkout, so anything under `output/` or `external/` is wiped each run unless a GitHub Actions cache step restores it.

| # | Stage | Secs | Inputs | Outputs | What forces a re-run | Cached between runs? |
|---|---|---|---|---|---|---|
| 0 | gate job | 3 | earlier runs of this workflow | run=true/false | every run | n/a |
| 1 | setup-r + setup-r-dependencies | 33 + 54 | DESCRIPTION | R and packages | every run | Yes, by the setup action's own package cache (second and later runs 36-38 s in the scenario jobs) |
| 2 | Fetch the anchor's poll data | 139 (121 and 118 on two other days) | aus-polling-analyser repo, `analysis/` | `external/aus-polling-analyser` | every run; anchor repo commits about twice a day | No. `forecast.yaml:179-200` clones every time |
| 3 | Election results (VEC, SA, QLD) | 0 on a hit | VEC and others | `external/elections` | fetch scripts change | Yes: `actions/cache` key `elections-v5-<hash of fetch scripts>` (`forecast.yaml:205-249`) |
| 4 | Fetch the trained models and tables | 55 (52, 54 on other days) | `shipped-models` release, about 35 `gh release download` calls plus about 8 `Rscript` launches to read flags (`forecast.yaml:282-520`) | `output/*.model`, `*.csv` | every run | No |
| 5 | Run the pipeline (`run_all.R`) | 335 (274 and 429 on other days) | everything above | seat probabilities, JSON, pages | every run | Partly, see rows 5a-5k |
| 5a | backtest_flows.R | 2 | past elections | flow ranking | every run | No (cheap) |
| 5b | fit_vic.R | 19 | polls | Victorian trend | polls change daily | No (needed) |
| 5c | fit_federal.R | 43 | polls | federal cycles (validation, `target = FALSE`, `run_all.R:47`) | skipped under `--quick` | No |
| 5d | fit_nsw.R | 20 | polls | NSW cycles (validation) | skipped under `--quick` | No |
| 5e | fit_projection.R | 98 | historical polls, results, flows, `R/` | `output/projection-mix.csv` (read by `fit_seats_full.R:575`, `build_page.R:164`) | every run | No. Uses only past elections (`R/projection.R:289-330` loops `polled-elections.csv` years), so its inputs do not change on a day with no edit to history |
| 5f | estimate_statewide_cov.R | 2 | election results | `statewide-cov.rds` | every run | No (cheap) |
| 5g | fit_seats_full.R (published run) | 110 | all of the above | seat sims, night state | every run | In-process only. `ind-person` cache printed MISS on this run ("no earlier cells entry in output/cache/cross-seat") because `output/cache` is empty on a fresh runner |
| 5h-5k | scorecard, pollster pages, build_page, forecast JSON, party pages | 9 + 10 + 9 + 3 + 3 | stage outputs | pages and JSON | every run | No (cheap) |
| 6 | Publish: release, R2, dated R2 copy | 16 + 27 + 6 | outputs | forecast-latest, R2 | every run | n/a |
| 7 | NSW 2027 forecast, then its R2 publish | 63 + 13 + 7 | shipped-models, fit_seats_full.R | NSW outputs | every run while `AUSPOL_PUBLISH_NSW2027=1` | No |
| 8 | Upload outputs, hand scenario inputs | 2 + 23 | outputs | artifact `scenario-inputs-<run>` | every run | n/a |
| 9 | 16 scenario jobs (vic2026 x 8, nsw2027 x 8) | 340-1016 each, plus 36-207 setup | the artifact above | `seat-*-scn-*` files | every run | No. Each job runs `build_scenarios.R`, which launches nine separate `Rscript fit_seats_full.R` processes (`build_scenarios.R:64`) |
| 10 | publish-scenarios | 47 | 16 artifacts | `scenario-<election>.json` | every run | n/a |

Critical path (run 45665482641, UTC): pipeline ends 17:41:02, scenario jobs start 17:43:46 (2 min 44 s later, spent on publishing and the NSW step), the slowest scenario job (vic2026 ALP polled) ends 18:10:36 (1,610 s, of which 577 s was a slow R install), publish-scenarios ends 18:11:25.

Per-scenario cost inside a Victorian job: 74-83 s each, nine per job (log lines 16213-16221 of the vic LNP exact job). The NSW run of `fit_seats_full.R` printed its own stage table (42 s): "project each seat's primaries" 45%, "simulate seat contests" 25%, "statewide 2026, from the model" 13%. The Victorian table is swallowed by `run_all.R`'s stage capture, so Victorian shares are UNTIMED.

## 3. Pipeline B: R-CMD-check (run 45725051861, 25 Nov)

Seconds per step; lower is better.

| # | Stage | Secs | Inputs | What forces a re-run | Cached? |
|---|---|---|---|---|---|
| 1 | setup-r + dependencies | 23 + 34 | DESCRIPTION | every push | Yes, setup action cache |
| 2 | check-r-package (`R CMD check --as-cran`, includes the tests) | 180 | code | every push | No |
| 3 | "Confirm the synthetic-data tests actually ran": `testthat::test_local()` (`check.yaml:62-71`) | 95 | the same tests | every push | No. It runs the full suite a second time just to count assertions |

## 4. Pipeline C: hand-run rebuild and deciding runs (local, not scheduled)

Already mapped and queued elsewhere, so not re-analysed. `rebuild_forecasts.sh` has nine stages (header lines 7-30) and resumes with `AUSPOL_REBUILD_FROM`. Stage 4 (`fit_xgb_primary_asat.R`) took 1,664 s for 31 models; the speed options are already in `docs/NEXT-STEPS.md:368-373`. Caching ideas for the backtest harness are in `docs/reviews/fast-iter-cacheable-2026-10-11.md` and `docs/NEXT-STEPS.md:290`. `runtimes.sh auspol 14` shows 37.9 hours of logged work in 14 days; the top entry is one 96.6-minute run, and several 9.0-10.0 minute entries are the shell tool's timeout, not real job lengths.

## 5. Ranked opportunities

Savings are per run, in seconds of wall-clock; higher is better. "Basis" says MEASURED or UNTIMED and how.

| Rank | Opportunity | Where | Saving | Basis | Stale-data risk |
|---|---|---|---|---|---|
| 1 | Anchor clone fetches the repo's top-level files (404 of them are checked out) and only then `analysis/`. Use `--no-checkout`, set sparse paths, then check out, or fetch only the needed CSVs | `forecast.yaml:179-200` | about 100 s of 139 | Step time MEASURED on 3 runs (139, 121, 118 s). Saving UNTIMED: the log shows a 127 s gap before "Updating files 0% (1/404)" and the poll CSVs themselves are a few MB | None if the same commit is fetched; `AUSPOL_ANCHOR_SHA` is still recorded |
| 2 | R-CMD-check runs the whole test suite twice. Drop the second run and read counts from the check's own test output, or run check with `--no-tests` and keep the counting step | `check.yaml:55-71` | about 95 s of 5 min (3-5 min total) per push, 76 finished runs in 2 days | Second step MEASURED at 95 s. The check step's own test share is UNTIMED | Low. Must keep the "passed >= 150" guard working |
| 3 | Hand the Victorian scenario jobs their inputs straight after the pipeline step, not after publishing and the NSW step | `forecast.yaml:807-860` (upload steps), scenario `needs: refresh` at 964 | about 2.7 min off the daily critical path | MEASURED gap between pipeline end (17:41:02) and scenario start (17:43:46). Saving is UNTIMED because it needs a job split | Medium. Scenarios would start before the publish succeeds, so a failed publish still burns scenario jobs; keep the alarm logic |
| 4 | Cache `projection-mix.csv` (fit_projection.R) keyed on `R/` code, the history files and the polls dated up to each region's last held election | `run_all.R:49`, `R/projection.R:289-330` | 98 s | Stage MEASURED. Needs a check first: UNVERIFIED that no current-cycle poll reaches `build_projection_data()`; I read the loop over `polled-elections.csv` only | Real: a key that misses an input serves an old mix. Poll rows revised in history must be in the key |
| 5 | Cache the shipped-models downloads keyed on the release's asset ids and `updatedAt`, and fetch in one `gh release download` call | `forecast.yaml:282-520` | about 40 s of 55 | Step MEASURED (52-55 s). Saving UNTIMED: about 35 download calls plus 8 R launches for flags, estimated at 1 s each | Medium: a re-uploaded asset with the same name must change the key; `updatedAt` does change on upload |
| 6 | Scenario jobs: run the nine offsets in one R process, or save the state `fit_seats_full.R` builds before it reads `AUSPOL_FORCE_FP` (line 690) and load it. Stages before line 686 (setup, flow matrix, statewide 2026 level, LL1) do not depend on the forced value | `build_scenarios.R:64`, `fit_seats_full.R:272-680` | about 1.5-2 min per scenario job (9 launches) | UNTIMED. NSW table shows setup + stages 1-3 + LL1 about 24% of 42 s; applied to Victoria's 75 s gives 15-20 s x 9 | Medium: a saved state must be keyed on the code, flags and today's levels. Shelf life ends after 28 Nov for Victoria |
| 7 | Split each Victorian scenario job in two (offsets -10 to 0 and +2.5 to +10) so the slowest job is about half as long | `forecast.yaml:972-980` | up to about 5-6 min on the critical path | UNTIMED. Victorian jobs took 770-1,065 s (typical) for 9 scenarios; half would be about 6.5 min plus 1.5 min setup | Low for data. But 8 to 16 Victorian jobs plus 8 NSW jobs is 24 jobs at once, above the 20 a free account runs in parallel, so some would queue. Shelf life ends after 28 Nov |
| 8 | STALE-DATA RISK (not a speed-up): scenario output reuse is by file existence and modified time against the level file only, not by code, flags or sims | `build_scenarios.R:56-60` | none | n/a | CI is safe (artifacts start empty). A local re-run after a code change inside the same day would silently skip every scenario whose files are newer than `statewide-level-*.csv` |

Not queued: I searched `docs/NEXT-STEPS.md` and `docs/DECISIONS.md` for these items and found none of ranks 1-8 listed. The only speed items there are the rebuild stage 4 and the harness caches (Pipeline C). The upper-house-only run (PR #285, `forecast.yaml:115-155`) is already live, so it is not repeated here.

Things looked at and left alone: the election-results cache (`forecast.yaml:205-249`) is correct and has a safe save-only-on-success pattern; fit_federal and fit_nsw (63 s together) are validation-only stages but I did not trace their consumers, so they are not listed as skippable; the NSW scenario jobs (8 of 16) are not on the critical path because Victoria's jobs are slower; the night-backup workflow is break-glass and retires after 28 Nov.

## 6. Finish line check

Done means the file exists with one table per pipeline and a ranked table, each with a header line; at most 8 findings returned. Not done: no change was made and no timing was taken beyond what the run logs already hold. To turn UNTIMED into MEASURED, time `git clone --no-checkout` on one runner (rank 1) and print `fit_seats_full.R`'s stage table for a Victorian scenario (rank 6, `output/fit-seats-timing-*-scn-*.csv` is already written per scenario and uploaded in the scenario artifacts for 2 days).
