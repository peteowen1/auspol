# auspol speed sweep, second pass (26 Nov 2026)

Read-only. Nothing was run except `runtimes.sh`, `gh run view` and one `gh run download` of a 3 MB scenario artifact (run 45665482641, 25 Nov, into the scratchpad). Builds on `docs/reviews/speed-sweep-pipeline-map-2026-11-26.md` and `speed-sweep-bottlenecks-2026-11-26.md`; their findings (anchor clone, double test run, scenario hand-off gap, projection-mix cache, check_like_ci parallel tests and fingerprint) are not repeated.

MEASURED = read from a run log, step timestamp or the per-stage timer the code itself prints. UNTIMED = my estimate, with how.

Election context: Victoria votes Sat 28 Nov. Anything that edits `.github/workflows/forecast.yaml` or published-path R code (`fit_seats_full.R`, `R/`) waits until after 28 Nov (the 24-hour rule from the first sweep). Nothing below needs to ship before then.

## What the hand-run log says (runtimes.sh auspol 14)

37.6 h logged; every top row is a watch loop (`for i in $(seq 1 57); do gh run view`, `Wait-Process`, `until [ -f DONE ]`) or a 9 to 10 min shell timeout, as the first pass found. No new hand-run script appears. The slow HAND work is the deciding runs and quick_arm, whose caches are already described in `docs/reviews/fast-iter-cacheable-2026-10-11.md` and NEXT-STEPS line 290. The new finding for hand runs is a per-process re-read in finding 8. The rest of this pass is CI, because that is where the user's question (run only what changed) bites.

## The real cost of one daily run (run 45665482641, MEASURED)

Seconds per stage, from `ok (N s)` lines in the log; lower is better.

| Stage (run_all.R order) | Secs | Feeds |
|---|---|---|
| backtest_flows | 2 | flow ranking |
| fit_vic | 20 | `trend-vic-*.csv`, `poll-tracking-vic.csv`, read ONLY by build_page.R:30 |
| fit_federal (validation, `target = FALSE`) | 50 | files no script, R file or workflow reads (grep of `R/`, `scripts/`, `.github/`) |
| fit_nsw (validation, `target = FALSE`) | 21 | same: no reader |
| fit_projection | 96 | `projection-mix.csv`, read by fit_seats_full.R:575 and build_page.R |
| estimate_statewide_cov | 1 | `statewide-cov.rds` |
| fit_seats_full (published) | 127 | everything downstream |
| scorecard, pollster pages, build_page, forecast JSON, party pages | 9, 10, 10, 4, 3 | pages |

The seven first stages run strictly in series (`run_all.R:234` loop over `STAGES`, `run()` at `:78`) although only fit_projection and statewide-cov feed the seat model.

Victorian what-if job, one scenario (MEASURED, downloaded `scn-vic2026-exact-LNP-45665482641`, log `vic-2026-scn-exact-LNP-+0.0.log` lines 300-328, cross-seat cache HIT on both lookups):

| Stage | Secs | Share |
|---|---|---|
| simulate seat contests (C++, 100,000 sims; log line 265: "88 seats x 100000 runs in 34s") | 33.7 | 46% |
| 4. project each seat's primaries | 18.7 | 25% |
| S5 block (sanity check plus per-seat range tables) | 9.2 | 12.5% |
| 3. statewide level | 5.4 | 7% |
| LL1 | 2.9 | 4% |
| flow matrix, load_all, S7 | 3.6 | 5% |
| total | 74 | |

So the first sweep's picture of the scenario cost (45% "project each seat's primaries") is the NSW 20,000-sim table. At the Victorian 100,000 sims the simulation and the S5 block are 58% of every scenario, and stage 4 is only 25% once the cross-seat cache hits.

## Findings

### 1. Scenario jobs run their 9 offsets one at a time on a runner that has spare cores
- `scripts/build_scenarios.R:62-64` loops `for (i in seq_len(nrow(plan)))` and calls `system2("Rscript", "scripts/fit_seats_full.R", ..., wait)` once per offset. The C++ core is single-threaded by contract (it draws from R's own RNG in order, `src/seat_sim_core.cpp:1-12`, no OpenMP in `src/`), so each scenario uses one core of the runner.
- Cost, MEASURED: nine scenarios of 77 to 87 s (`BSC3` lines, vic LNP exact job) = 11.5 min of a 13 to 17 min job. The slowest job (ALP polled) was 1,610 s, of which 577 s was an R install. Sum of all 16 jobs = 12,091 s (201 runner-minutes): Victoria 7,751 s, NSW 4,340 s.
- Fix: give `build_scenarios.R` a `--slots=N` and run N scenarios concurrently (`parallel::mclapply(..., mc.cores = N)` on Linux, or `xargs -P`). Scenario files are suffix-named so they do not collide; the cross-seat cache is read-only on a hit (the artifact carries `output/`, `forecast.yaml:1051-1059`). Run `nproc` and `free -g` in the job first: GitHub's standard Linux runner for a public repo is 4 vCPU and 16 GB (UNVERIFIED here, from memory of GitHub's docs). Memory per process is UNTIMED; the fp draw array alone is 100,000 x 88 x about 7 parties x 8 bytes = about 490 MB (code at `seat_sim_core.cpp:113`), so budget 2 to 3 GB per process and start with 3.
- Saving: UNTIMED. 9 x 77 s serial becomes 3 waves of about 100 s (a 1.3x contention allowance) = 5 min, so about 6 min per Victorian job and about 2.5 min per NSW job, on the critical path (the whole run ends when the slowest scenario job does, 45 min today).
- Stale risk: none for data (same code, same inputs). Race: two processes missing the cross-seat cache at once both write the same `.rds`; avoid by running the first scenario alone, then the rest in parallel.
- Why this beats the first sweep's rank 7 (split into 16 Victorian jobs): that goes to 24 jobs against a 20-job limit; this uses cores already paid for.
- Profile one unit: in a scratch checkout with `output/` from a downloaded `scenario-inputs-<run>` artifact, `time Rscript scripts/build_scenarios.R --target=vic2026 --parties=LNP --modes=exact --offsets=0,2.5,5` then the same with `--slots=3`; compare `BSC3` seconds and peak memory.
- After 28 Nov (workflow and script change). Value continues for NSW afterwards.

### 2. NSW 2027 is rebuilt and re-published daily; it is also 36% of what-if runner time
- `forecast.yaml:726-733` runs the NSW forecast on every refresh while `AUSPOL_PUBLISH_NSW2027=1`, then two publish steps (`:760`, `:790`). MEASURED 63 s + 13 s + 7 s = 83 s, all before "Hand the scenario jobs their inputs" (`:822`), so it sits on the critical path of every daily run. `forecast.yaml:975` adds 8 NSW scenario jobs: 4,340 s of runner time (72 minutes) per day, 36% of all scenario time, for a 13 March 2027 election (`R/election_dates.R:29`).
- What an NSW run depends on: the NSW poll file, the shipped-models tables, and the date. It does not read any Victorian output (`:740-758` downloads its own inputs). Its polls move rarely: `build_pollster_pages` logged 35 polls this cycle.
- Fix: stop the daily NSW work; run NSW (forecast plus scenarios) (a) weekly, and (b) when a hash of `external/aus-polling-analyser/analysis/Data/poll-data-nsw.csv` differs from the hash stored on the last NSW publish (store it as a release asset `nsw2027-inputs.sha` next to `forecast-history-nsw2027.csv`, `:753`), and (c) on `workflow_dispatch` `only=nsw2027`. Gate it in the existing `gate` job (`:74-110`).
- Saving: MEASURED 83 s off the daily critical path; MEASURED 72 runner-minutes per day (6 of 7 days saved if weekly = about 62 min per day on average). Wall-clock of the scenario phase does not fall (Victoria's jobs are the slowest), so the saving is runner minutes (free) and fewer jobs competing for the 20-job concurrency limit, plus about 1.4 min on the critical path.
- Stale risk: the NSW page is up to a week behind the days-to-election clock unless a new poll arrives; shorten to every 2 to 3 days as the March election nears. The page already shows its build time. Decide with Pete; it changes what NSW readers see.
- After 28 Nov. This is also the natural time: once Victoria is over, NSW becomes the live forecast and the Victorian jobs become the part to drop (finding 3).
- Profile: already measured; `gh run view <id> --json jobs --jq '.jobs[] | "\(.name) \((.completedAt|fromdateiso8601)-(.startedAt|fromdateiso8601))"'`.

### 3. Stage selection: the general design, and which stages are safe to skip
The workflow has one selector, `only: all | upper-house` (`forecast.yaml:43-47`, gate at `:88-89`, job at `:115`). Proposed generalisation, from the dependency reading above:

| Selector | Runs | Reads | Must not skip? |
|---|---|---|---|
| `only=upper-house` (exists) | one job | published `night-state-vic-2026.rds`, `seat-shares-vic-2026.csv` | n/a |
| `only=lower-house` | run_all.R stages 5 to 12 for Victoria, no scenarios, no NSW | everything fetched | the daily one, always |
| `only=scenarios` | scenario matrix only | the latest `scenario-inputs` artifact, or a rebuild of it | needs inputs from a refresh run; artifacts live 2 days (`:1047`) |
| `only=nsw2027` | NSW step plus NSW scenarios | NSW polls, shipped tables | see finding 2 |
| `only=pages` | scorecard, pollster pages, build_page, JSON, party pages | `output/` from the last refresh | they read fit_seats_full outputs |

Inside `run_all.R`, add `--only=<stage,...>` and `--skip=<stage,...>` (today only `--quick` and `--stale-ok`, `run_all.R:14-18`), and give each STAGES entry declared `inputs` (files, globs, env) and `outputs`. A per-stage skip-if-inputs-unchanged hash is safe only for stages that are a pure function of data that does not move daily:
- Safe to skip when unchanged: fit_federal (50 s) and fit_nsw (21 s). Nothing reads their outputs (grep above); they exist to raise FL3/NL3 breaches on unpublished cycles. Skip unless the federal or NSW poll file hash changed OR it is Monday; this keeps the weekly check and loses nothing downstream. The first sweep left these as "consumers not traced": traced now, none.
- Safe with a per-fit key: fit_projection (finding 4).
- NOT safe to skip: fit_vic, fit_seats_full, build_*. The forecast moves with days-to-election even with no new poll (first sweep's correction stands).
- Stale risk: a skipped validation stage hides a breach for up to a week; `run_all.R:373-380` already refuses to read an old NL3 marker when NSW was skipped, so the alarm logic copes.
- Saving: MEASURED 71 s of stage time on the daily run if skipped (and about 0 s of wall-clock if finding 5 is done first, because both would hide behind fit_projection, so do finding 5 first and 3 second).
- UNTIMED effort: about 1 day. After 28 Nov.

### 4. fit_projection refits 424 historical trends from scratch every day (96 s)
- `R/projection.R:289-410` (`build_projection_data`): for 4 regions x each polled election (fed 20, nsw 10, vic 10, qld 13 = 53 elections in `polled-elections.csv`, counted) x `HORIZONS = c(1, 7, 14, 30, 90, 180, 365, 730)` (`scripts/fit_projection.R:37`) = 424 serial `trend_as_at()` calls (`:380`). MEASURED 96 s for the stage on 25 Nov (about 0.2 s per fit, derived). Every one is a past election (rows without an `@TPP` actual are skipped, `:332-334`), so its inputs are history that changes only if the anchor revises a poll row.
- Fix, two parts, both independent of the first sweep's whole-file cache (rank 4), which a revised poll would invalidate for all 424 fits at once:
  1. Cache each fit by key (polls in that cycle window up to `as_at`, priors, flows `fl`, `nu`, sigmas, weights, `...`, the namespace code hash as in `R/ind_person.R:107-114`). A revised old poll then refits only its cycle.
  2. On the cold fits, `parallel::mclapply` over (region, year) on Linux (the runner), serial on Windows. Fits are independent and use no shared state beyond read-only `polls`.
- Saving: MEASURED 96 s now; warm cache leaves about 3 to 5 s (UNTIMED; the fundamentals and mix fit after it are small). Even cold, 4 cores gives about 30 s (UNTIMED: 96 / 3.5).
- Stale risk: key must include everything `trend_as_at()` reads, including `AUSPOL_*` switches it reads (use the read-set recorder `.cs_rec` pattern, `R/cross_seat_vote.R:262-290`). Prove with a deliberately edited poll row that the key changes.
- Profile one unit: `Rscript -e "devtools::load_all(); print(system.time(build_projection_data(horizons=30, regions='vic', verbose=FALSE)))"` (write it to a temp file under the scratchpad, not inline, per the repo's R rule), then multiply by 53 x 8.
- After 28 Nov (published path).

### 5. run_all.R runs seven independent stages end to end (about 91 s of wall-clock)
- Reading the outputs above: fit_vic, fit_federal, fit_nsw and fit_projection write files that none of the others read. fit_vic's files are read only by build_page (`build_page.R:30`); fit_federal and fit_nsw have no reader; fit_projection and statewide-cov feed fit_seats_full. `run_all.R:234` still runs them one by one: 20 + 50 + 21 + 96 + 1 = 188 s MEASURED.
- Fix: launch the independent stages with `system2(wait = FALSE)` (or `callr::r_bg`), each already writing to its own temp stdout and stderr files in `run()` (`run_all.R:99`), then collect in STAGES order so the summary and the duplicate-check-code guard (`CODE_OWNER`) see the same order. Keep backtest_flows first (it is the stated ordering guard, `:34-38`) and fit_seats_full after fit_projection and statewide-cov. Lane A: fit_projection (96 s). Lane B: fit_vic, fit_federal, fit_nsw (91 s). Join, then statewide-cov, then fit_seats_full.
- Saving: about 91 s of the 335 s pipeline step (MEASURED stage times; the overlap is UNTIMED, assumes 4 vCPU and that two R processes do not slow each other more than about 10%). On Windows memory is shorter; keep a `--serial` switch (the repo's rule against running big jobs together applies to local runs).
- Stale risk: none for data. Risk is the interleaved log and the check-code summary; the summary parsing is per stage already.
- Profile: print each stage's own `ok (N s)` in a run with and without; or run `fit_federal.R` and `fit_projection.R` side by side under `time` on a quiet machine.
- After 28 Nov.

### 6. The cross-seat cache misses every day on a fresh runner (about 36 s of the 127 s seat stage, plus the NSW miss)
- `R/ind_person.R:90-97` says the person cells and carry-fit cases cost "~36 s of a ~73 s scenario on CI (run 45500128541)" and are cached on disk under `output/cache/cross-seat`. The scenario jobs get the cache because the refresh job uploads all of `output/` (`forecast.yaml:822-833`). The refresh job itself starts with an empty `output/`: log lines 17357-17358 of run 45665482641 read `IPC1! ind-person cache MISS (cells) ... no earlier cells entry in output/cache/cross-seat`, and the NSW step missed too (`key part(s) changed: args`, line 18094).
- Fix: an `actions/cache` restore of `output/cache/cross-seat` before "Run the pipeline" and a save after it, the same pattern as `forecast.yaml:205-249`. The R-side key already covers corpus, by-election files, pairs and a hash of every function (`.ip_key_parts`, `R/ind_person.R:107-114`), so a restored stale entry simply misses; it cannot serve wrong data. Use `restore-keys` with a prefix so the folder is restored even after a code edit (the newest entry is then dead weight, harmless).
- Saving: UNTIMED but anchored: about 36 s on the Victorian published run (comment above, a different run's measurement) and the NSW miss (its SQ2 table shows `own_prev` 5.5 s and `ind_person` smaller). Requires that the corpus hash is stable day to day: the key includes `corpus = h(as.data.frame(C))`. If the candidacies file downloaded from shipped-models changes daily, the cache never hits; check two consecutive logs' `IPC1` lines after the first day.
- Stale risk: none by construction (key checks content). Cache size: the folder is not on this machine (`output/cache` is empty locally), measure it in the first run.
- After 28 Nov (workflow edit).

### 7. The S5 block builds 100,000 strings per seat, twice, and takes 9.2 s of a 74 s scenario
- `scripts/fit_seats_full.R:2122-2282`. Measured: the timer row "S5, the seat-total sanity check" is 9.2 s in the Victorian scenario at 100,000 sims (12.5% of the run; 3.6 to 4.2 s at 20,000 sims in the NSW and local tables), because it also covers the whole range-table build below it.
- Why slow: for each of 88 seats, `.tcp` (`:2214-2232`) and `.pairs` (`:2242-2260`) each compute `ifelse(w < r, paste(w, r, sep = "|"), paste(r, w, sep = "|"))` on 100,000 draws (two pastes per seat per table, evaluated eagerly by `ifelse`), then `table()` over 100,000 strings, and `.prim` (`:2206-2211`) does 88 x ~7 `quantile()` calls on 100,000-long slices of a 3-D array. The pair string is computed twice per seat for the same draws.
- Fix: compute the pair once as an integer code (`pmin(w, r) * K + pmax(w, r)` if the codes are integers; otherwise `match()` into a small lookup first), count with `tabulate`, and share it between `.tcp` and `.pairs`. Replace the per-cell `quantile` with `matrixStats::colQuantiles` on a matrix or one `data.table` grouped sort. Output must stay byte-identical (`fwrite` of three CSVs; the test is to diff them before and after on one scenario).
- Saving: UNTIMED. The stage is MEASURED at 9.2 s; I estimate 5 to 7 s saved (the three CSV writes and the per-cell sorts will remain). It applies to the daily run (9 s at 100k), 72 Victorian scenarios and 72 NSW scenarios: about 5 min of Victorian job time per day and about 6 s off the critical path of every run.
- Stale risk: none if output is byte-identical; this is the published path, so a diff test is the gate.
- Profile one unit: add `Rprof` around lines 2206-2260, or `system.time` on `.tcp` alone, using a saved night state. Or read `output/fit-seats-timing-vic-2026-scn-*.csv` (note: the scenario artifact does not upload these timing files, only `scenario-logs/`; the SQ1 table is in the log).
- After 28 Nov (published-path R code).

### 8. What-if "re-simulate only" is not exact, and the right cut is smaller (answer to the 72-scenario question)
- What depends on the forced level, read from the code: forcing sets `state_mean` at `fit_seats_full.R:724-780`, after the statewide stages. Stage 4 then reads it at `:898` (`onp_model_ratio(level=...)`), `:985` (permit), `:1273` (dispersion slopes), `:1380` (every party's `dev_slope`), `:1547` (the xgb trees' level `.xgb_level`) and `:1605`/`:1730` (level_conserve). Stage 5 re-anchors the draws to it. So each seat's shares change with the forced level before any simulation: a pure re-simulation from the saved pre-simulation state (`R/seat_state.R`, `night-state-*.rds`, `fit_seats_full.R:2074`) would hold the shares fixed and be wrong by the level response. I do not recommend building it.
- What does not depend on it, MEASURED in the scenario table: load_all 1.3 + flow matrix 1.8 + statewide level 5.4 + S7 0.5 + LL1 2.9 = 11.9 s of 74 s (16%), all before the forcing at `:690`. Plus the level-free fits in stage 4 (`own_prev` 3.6 s, `own_prev_xgb` 1.0, `returns`, `permit`, the surge hazard) already queued as NEXT-STEPS line 290 (read-set keys). Together about 17 s per scenario that 8 of 9 scenarios in a job could skip.
- Fix: one R process per job that loops over the offsets after running everything above once (needs the top-level script wrapped in a function, or a `source()` of a split-out first half): saves about 12 s x 8 = 1.6 min per job (MEASURED shares, UNTIMED extrapolation). Smaller than finding 1 and conflicts with it (one process cannot also be 3 processes), so do finding 1 first.
- Dedupe: `build_scenarios.R:48` plans `polled +0.0` for each of the 4 parties; all four must equal the published run (CSC7, `combine_scenarios.py:206-244`, tolerance 0.005 after a 0.0004 observed gap), and `exact +0.0` is distinct. Running one party's `polled +0.0` and checking CSC7 on it, then copying its files for the other three, drops 3 of 72 Victorian runs (4%). UNTIMED; low value.
- N is coupled: CSC7 compares scenarios to the published 100,000-sim run, so cutting the scenarios to 20,000 sims (what NSW does) would fail CSC7's 0.005 tolerance (20,000-sim noise on a 0.5 probability is 0.0035 per run).
- After 28 Nov.

## Additional notes (not returned as findings)

- Per-process re-read (hand runs, the cross-seat fit): `R/byelection_prior.R:201-218` (`byelection_winner_rows`) calls `byelection_table()` (an `fread` of 1,078 rows plus `classify_party` on every row, `:25-35`) and re-reads and re-classifies `byelection-winners.csv`, once per election pair. `R/cross_seat_vote.R:62-82` (`.cs_byelection_rows`) calls it in `lapply(prs[ok], ...)` for every pair (22 to 40) and `candidate_returns.R:79,377,762` calls it three more times per target. `fast-iter-profile-2026-10-11.md` section 4 measured `byelection_winner_rows` 10.7 s sampled on a cold, profiler-inflated run (about 5 s real, UNTIMED). Fix: memoise the two parsed and classified tables per process keyed on `tools::md5sum`. Only helps cold hand runs and the cache-miss path (findings 6); low priority.
- Where I looked and found nothing worth listing: `build_scenarios.R` skip rule (already named by the first sweep, rank 8); `estimate_statewide_cov` (1 s); pages after the seat stage (3 to 10 s each).
- Not retiring: none of the code above is on a port or frozen-language plan; the two-party seat model is retired but not touched here.
- Not checked: whether `build_page.R` reads seat probabilities (it lists only `projection-mix.csv`, `trend-vic-2026.csv`, the scorecard and the poll-tracking table as inputs, `build_page.R:30-36`, but may read more later); the scorecard, pollster pages and page build could run beside fit_seats_full if it does not. Not measured: memory per scenario process, and the NSW per-stage table is only available for the published NSW run.
