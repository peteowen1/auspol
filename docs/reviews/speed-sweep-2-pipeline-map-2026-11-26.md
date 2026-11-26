# auspol pipeline map, second pass (26 Nov 2026)

Read-only. Nothing was run, edited or installed. Builds on `docs/reviews/speed-sweep-pipeline-map-2026-11-26.md` and `speed-sweep-bottlenecks-2026-11-26.md` (anchor clone, double test run, scenario hand-off gap, projection-mix cache, parallel tests are NOT repeated). MEASURED = from a run log or step timestamp (`gh run view --json jobs`, `gh run view --log`). UNTIMED = my estimate, with how I made it. Sydney time throughout (the daily run starts 4:30am).

Election context: Victorian election is Sat 28 Nov. Every change to `.github/workflows/forecast.yaml` or `scripts/run_all.R` below is marked AFTER 28 Nov (the daily run must not change before then); only read-only checks are safe before.

## 1. What actually runs, ranked by wall-clock

Wall-clock minutes per run (created to last job done), last 100 `forecast.yaml` runs (8 Nov to 26 Nov); lower is better. n = runs.

| Kind | Trigger | n | Typical min | Notes |
|---|---|---|---|---|
| Daily refresh | inthegame-blog worker dispatch 4:30am Sydney (`forecast.yaml:12-20`) | 17 | 32-45 | Full pipeline + NSW 2027 + 16 scenario jobs. Two outliers: 18 Nov 270 min and 20 Nov 320 min (section 5, finding 8) |
| Manual full run (workflow_dispatch, not `daily`) | by hand | 6 in 23-26 Nov | 32.6, 34.1, 36.2, 41.8, 42.6, 50.8 (sum 238 min) | Every manual dispatch with `only=all` reruns everything; the 41.8 and 50.8 min ones also ran all 16 scenario jobs. MEASURED |
| Fallback schedule `37 17` | GitHub cron | many | 0.1-0.2 | Gate skips: the worker's run already went (`forecast.yaml:74-110`). Not a cache hit |
| upper-house only | `only=upper-house` (PR #285) | few | about 1 | The one stage-selection mode that exists (`forecast.yaml:115-155`) |
| R-CMD-check | every push | ~76 per 2 days | 4.5-6 | Covered by the first sweep |
| Election-night backup | manual | 8 | 14-52 | Break-glass, retires after 28 Nov |
| Scheduler outside GitHub | Scheduled Tasks for deciding runs and full rebuilds (`CLAUDE.md` "deciding run", `scripts/scheduled_rebuild.ps1`) | n/a | n/a | Local, one-shot, not recurring |

## 2. Pipeline A: daily refresh, with what depends on what

Seconds are from run 45665482641 (25 Nov) and 45762768823 (26 Nov); lower is better. "Skippable alone?" says whether the stage can be left out when only one area changed, from reading what reads its output.

| Stage | Secs | Reads | Writes / consumed by | Skippable alone? | Cached between runs? |
|---|---|---|---|---|---|
| backtest_flows | 2 | past results | flow ranking, read by every flow consumer | No, must precede flow consumers | No (cheap) |
| fit_vic | 19 | polls | `trend-vic-*.csv`, `L3-BREACH.txt` (run_all reads the marker, `run_all.R:277`) | Alarm only; the published trend comes from `trend_as_at()` (`CLAUDE.md` "Two trend-model paths") | No |
| fit_federal | 43 | fed polls | `trend-fed-*.csv`, `hyperpars-fed.csv` ... NOTHING in `R/` or `scripts/` reads them (grep: only `fit_federal.R` and `docs/DATA-DICTIONARY.md` name them) | Yes, validation only (`run_all.R:47` `target = FALSE`) | No |
| fit_nsw | 20 | NSW polls | `trend-nsw-*.csv`, `NL3-BREACH.txt` (alarm only) | Yes, validation only (`run_all.R:48`) | No |
| fit_projection | 98 | history, polls, flows | `projection-mix.csv`, read by `fit_seats_full.R:575`, `build_page.R:164` | Only if its inputs unchanged (first sweep rank 4) | No |
| estimate_statewide_cov | 2 | results | `statewide-cov.rds` | No (cheap) | No |
| fit_seats_full (Vic) | 110-127 | everything above + shipped models | seat sims, night state, level files | Needed for any lower-house change | in-process only; `output/cache/cross-seat` starts empty on a runner (`IPC1! ... MISS`, log line 17394) |
| fit_scorecard, pollster pages | 9 + 10 | polls, results | pages | These do NOT read `fit_seats_full` outputs (scorecard reads polls and results; `PPG1` log lines) so they could run beside it | No |
| build_page, forecast JSON, party pages | 9 + 3 + 3 | seat outputs | pages and JSON | Yes, if seat outputs are loaded from the last release (the `only=upper-house` pattern) | No |
| Publish release + R2 + dated copy | 49 | outputs | forecast-latest, R2 | n/a | n/a |
| NSW 2027 forecast + 2 R2 steps | 63 + 13 + 7 = 83 | shipped models, `fit_seats_full.R` with `AUSPOL_TARGET=nsw2027` | NSW JSON, page data | Yes, on its own trigger (finding 2) | No |
| Scenario inputs hand-off | 25 | outputs | artifact | n/a | n/a |
| 16 scenario jobs (8 Vic, 8 NSW) | see section 3 | artifact | `scenario-*.json` | Yes, `inputs.scenarios` already gates manual runs | No |

## 3. Pipeline A2: the 16 what-if jobs

Per-scenario seconds from `BSC3` log lines of run 45762768823 (100,000 sims); lower is better. Each job runs nine `Rscript fit_seats_full.R` processes one after another (`build_scenarios.R:64`).

| Part | Secs | Notes |
|---|---|---|
| Vic scenario, 1st of 9 in a job | 106, 128, 87 | first process also misses the cross-seat cache |
| Vic scenario, 2nd to 9th | 94-97, 116, 79 | MEASURED: first minus rest is 8-12 s, that is all the existing disk cache saves |
| Vic job total | 13.7-29.4 min (typical 14-19) | 8 jobs; 72 scenarios a day. The slowest sets the end of the run |
| NSW job total | 6.5-19.2 min (typical 9-11) | 8 jobs; sum of the 8 = about 85 min runner time (run 45762768823) and 88 min (run 44783954601). Not on the critical path |
| R setup per job | 59 s median (23 + 36 in run 45665482641); outliers 287-412 s, three 10-min timeouts in one job on 20 Nov | |

NSW stage table (log line 18322, 47 s total, MEASURED): stage 4 "project each seat's primaries" 20.6 s (43.5%), simulate 13.2 s (28.0%), stage 3 "statewide 2026" 5.6 s, LL1 2.9 s, S5 2.2 s, load_all 1.2 s, flow matrix 0.9 s, S7 0.5 s. Named sub-steps inside stage 4: `own_prev` 6.1 s, `xgb_flows` 4.1 s, `xgb_live` 1.2 s, `own_prev_xgb` 1.0 s, `new_ind` 0.9 s, `new_ind_lift` 0.7 s. The Victorian table is swallowed by the stage capture (log line 17472 says only "127 s total").

## 4. What does a forced level touch in fit_seats_full.R? (answers the re-simulate-only question)

Line numbers in `scripts/fit_seats_full.R`; "depends on forced level" means the value changes between two scenarios.

| Stage (lines) | Depends on forced level? | Evidence |
|---|---|---|
| setup, flags, flow matrix, 2022 shares, stage 3 statewide, S7, LL1 (32-602, 603-671) | No: all before `FORCE_FP` is read at 690 (the comment at 612 says so) | NSW 12.0 s of 47 s |
| `candidate_returns` (981), `own_prev` and `own_prev_xgb` (1114, 1125), `surge_hazard_for` (1221), `fit_conditional_slopes` (1277) | No: take election pair and corpus, not `state_mean` | NSW 7.3 s of 47 s. Queued as read-set cache keys, `docs/NEXT-STEPS.md:291` ("~25 s of a 54 s vic run") |
| ONP ratio (898), permit (985), `fit_dispersion_slopes` (1273), `dev_slope` base (1380), ONP target (1459), level split (1525), xgb level and `xgb_primary_predict_live` (1547, 1620) | Yes: all read `state_mean` | This is why a saved `seat_state_sim` dump cannot be reused |
| Statewide draws (1744 onward), simulate (1933) | Yes: draws regress on the forced level (`FORCE_DRAWS_RULE`, 715-770) | |

Verdict: a re-simulate-only path is NOT possible. `seat_state_resim()` (`R/seat_state.R:146`) takes new shares, but the shares matrix is the output of stage 4, and stage 4 (and the xgb trees) is what the forced level changes. What IS possible is to compute the level-independent part once per job (about 38% of an NSW run, 19.3 s of 47 s: 12.0 + 7.3), then run only the level-dependent part nine times.

## 5. Ranked opportunities

Savings are wall-clock seconds or minutes per run unless said; higher is better. Timing: MEASURED or UNTIMED with how estimated. "When" says whether it is safe before the 28 Nov election.

| Rank | Opportunity | Where | Saving | Basis | Stale-data risk | When |
|---|---|---|---|---|---|---|
| 1 | Stage selection for dispatches: `only=` choices beyond `upper-house` | `forecast.yaml:43-47`, `run_all.R` | 25-45 min per manual run that changes one area; 6 full manual runs in 4 days cost 238 min | MEASURED durations. Saving UNTIMED: a pages-only run is about 3 min (fetch release 20 s + build_page 9 + JSON 3 + publish 49 s) | Medium. See design below | After 28 Nov |
| 2 | NSW 2027 off the daily path: run it when its inputs change, or weekly | `forecast.yaml:726-800`, matrix at 975 | 83 s on the daily critical path, plus about 85 runner-min of NSW scenarios (8 jobs) | MEASURED (steps 16-18 = 63+13+7 s; job sums above). NSW jobs are not critical, so wall-clock gain is the 83 s | Medium: the page's history gets fewer rows | After 28 Nov; needs Pete |
| 3 | Run 3 scenarios at once inside each job (a 4-vCPU runner, one R process each) | `build_scenarios.R:64` | Vic job 14-19 min down to about 6-8 min; ends the run 8-10 min earlier | UNTIMED: the code is single-threaded (no `parallel`, `future`, openmp anywhere in `R/`, `src/`, `fit_seats_full.R`), nine runs of 94-116 s each, so 3 at once is about 3 x 100 s per wave | Low for data (files are suffixed per scenario). Check that two processes writing one `output/cache/cross-seat` key cannot corrupt it, and memory (3 x one R process) | After 28 Nov |
| 4 | Validation stages `fit_federal` + `fit_nsw` weekly, not daily | `run_all.R:47-48` | 63 s | MEASURED by the first sweep (43 + 20 s) | None for the forecast (no reader of their outputs). Cost: a poll-tracking breach (FL3/NL3) is noticed up to a week late | After 28 Nov |
| 5 | Run independent `run_all.R` stages together | `run_all.R:40-80` | about 60 s now (about 85 s if rank 4 is not done) | UNTIMED. Stages fit_vic 19, fit_federal 43, fit_nsw 20, fit_projection 98, covariance 2 = 182 s serial. None read another's output from `output/` (grep of `fread/readRDS` in the five scripts: none); helper code in `R/` not traced. Parallel on 4 vCPU would end near the longest (98 s). Also scorecard + pollster pages (19 s) beside `fit_seats_full` | Low | After 28 Nov |
| 6 | Save the level-independent part of `fit_seats_full.R` once per scenario job | `fit_seats_full.R:32-671` and returns/own_prev/hazard | about 19 s x 8 per NSW job, about 25 s x 8 per Vic job (3-3.5 min a job) | NSW MEASURED (19.3 of 47 s); Vic UNTIMED, from NEXT-STEPS:291 | Medium: the saved prefix must be keyed on code, flags and the day. Overlaps first sweep rank 6, adds the verdict in section 4 | After 28 Nov (Vic shelf life ends then) |
| 7 | `actions/cache` for `output/cache/cross-seat` | `forecast.yaml` before the pipeline step | about 10 s on the refresh run and on the first process of each scenario job | MEASURED as first-minus-rest (8-12 s per job). Refresh-run saving UNTIMED | Low: entries are keyed by content hash of the corpus, code and switches read (`R/cross_seat_vote.R:238-262`); a wrong restore misses, it does not serve old data. Note the cache key does not hash `external/` files other than by-elections | After 28 Nov |
| 8 | Tail risk: R install hangs and queueing | `forecast.yaml:980-1010` | removes 36-minute outliers | MEASURED: 20 Nov scenario job (vic GRN polled) took 56 min (10-min timeouts of setup-r and dependencies, each retried; run 44783954601); 18 Nov the `refresh` job started 3.5 h after the gate (4:30am gate, 8:00am start; run 44359441198, cause not visible in the job data: UNVERIFIED). 2 of 17 daily runs | n/a | After 28 Nov |

## 6. Design: stage selection (rank 1) and skip-if-unchanged

Proposed `only` values for `workflow_dispatch`, and what each loads from the last published run (the `only=upper-house` job already loads `night-state-vic-2026.rds` and `seat-shares-vic-2026.csv` from `forecast-latest`, refusing two files more than 10 min apart, `forecast.yaml:128-135`). Seconds are the stage times in section 2; lower is better.

| `only=` | Runs | Loads from forecast-latest | Approx. time |
|---|---|---|---|
| `upper-house` | exists | night state, seat shares | 1 min |
| `pages` | build_page, forecast JSON, party pages, pollster pages, publish | seat sims, level files, models | about 3 min |
| `lower-house` | everything except NSW and scenarios | models | about 24 min (daily minus 83 s NSW minus scenarios) |
| `scenarios` | the 16 jobs and publish-scenarios | `scenario-inputs-<run>` artifact or the published night state | about 20 min |
| `nsw2027` | NSW steps only (83 s) plus its 8 scenario jobs | models | about 4 min + scenario jobs |
| `all` (default) | today's behaviour | nothing | 32-45 min |

Mechanics: add `if: inputs.only == 'all' || contains(fromJSON('["lower-house"]'), inputs.only)` per step or job. The gate must also accept these (today it refuses everything except `all`, `forecast.yaml:89`). Add one concurrency group per `only` value (as PR #285 did) so a pending `pages` run cannot cancel a pending daily.

Skip-if-unchanged per stage (for the daily run, the stages whose inputs really do hold still):

| Stage | Hash of | Skip when equal | Why the whole daily run is NOT skippable |
|---|---|---|---|
| fit_projection | `R/` + history files + polls up to each region's last election + flows | yes (first sweep rank 4) | The forecast moves with days-to-election even on a day with no new poll (first sweep section 1) |
| fit_federal / fit_nsw | `R/` + fed or NSW poll rows + ISO week | yes | |
| NSW 2027 forecast | `R/` + shipped-models manifest + NSW poll rows + ISO week | yes; the ISO week makes it recompute weekly even with no poll | |

A skip that serves an old file by name is the stale-data trap: store the hash next to the output and compare it to a hash of this run's inputs, never skip on "the file exists".

Callers to check before gating anything on a flag: `inputs.quick` (skips the slow stages and the seat model, `forecast.yaml:965`), `inputs.scenarios` (turns scenarios on for a manual run), the worker's `daily=true`, and `scripts/rebuild_forecasts.sh` / `deciding_run.ps1` which call `run_all.R` or `fit_seats_full.R` directly. A new `run_all.R --only=` must default to today's order.

## 7. After 28 Nov: the roles flip

After Saturday the Victorian forecast, its 8 scenario jobs (about 135 runner-min, 14-29 min wall each) and its R2 publishing have no audience, while NSW (election in March 2027) becomes the live target. If the Victorian daily run is retired or put on a slow cadence, the daily path loses most of its 32-45 min. UNTIMED: remaining work is the NSW pipeline, about 83 s of forecast plus 8 jobs of 6.5-19 min. This needs a Pete decision on what the Victorian page shows after the election, so it is not listed as a ranked saving.

## 8. Checked and left alone

- Hot code: no O(n^2) found. Stage 4's loops (`fit_seats_full.R:1377-1420`, `:1466-1500`) run over parties, not seats; `personal_prior_vote` uses keyed `match` and `%in%`. The R simulation loop at `R/seat_sim.R:1579` only runs when `AUSPOL_SIM_ENGINE=r`; published runs use the C++ engine. To find the unnamed 10 s of NSW stage 4, profile one run: `Rprof` over `AUSPOL_TARGET=nsw2027 Rscript scripts/fit_seats_full.R` (47 s; Pete to approve, not run here).
- `fit_vic` (19 s): its L3 marker is read by `run_all.R:277`, so it feeds an alarm; left alone.
- Local caching (quick_arm baselines, `rebuild_forecasts.sh` stages, harness caches) is already covered by the first sweep and `docs/NEXT-STEPS.md:290,368,374`.
- Concurrency: 16 scenario jobs plus one refresh job is 17, under the 20-job limit for public repos, but a push-triggered R-CMD-check in the same window takes more (R-CMD-check runs every push). Rank 3 reduces job count pressure only if jobs are merged, so keep 16.
