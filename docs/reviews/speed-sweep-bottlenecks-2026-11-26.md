# auspol hand-run bottlenecks (read-only sweep, 26 Nov 2026)

Method: `bash ~/.claude/lib/runtimes.sh auspol 14` and the raw `~/.claude/runtime-log.csv` rows since 12 Nov; read the scripts behind the top rows. Nothing was run.

## What the runtime log really says (14 days, auspol)

- 37.9 h logged in total, but most of the top rows are WATCH loops (`for i in $(seq 1 57); do gh run view ...`, `until [ -f $D/DONE ]`, `Wait-Process`). A row of 9 to 10 min is the shell tool's timeout, not a job. They inflate the table and are not compute.
- Real compute, by script (MEASURED from the log, sum of foreground rows):
  - `scripts/check_like_ci.R`: 60 runs, 378 min. Run lengths in minutes: 25 runs at 3, 3 at 4, 1 at 5, 3 at 6, 5 at 7, 6 at 8, 4 at 9, 2 at 10, plus one 96 min row (14 Nov 13:28, almost certainly a stalled or suspended process, not the script).
  - `scripts/build_data_registry.R`: 37 rows, but the 10-min rows are all 16 to 21 Nov, before a722377f made it a 20 s script. Already fixed.
  - `scripts/build_model_registry.R`: about 25 runs of 40 to 50 s (about 20 min), with a few 200+ s rows when the machine was busy.
  - Deciding runs (`deciding-runs/*`), `quick_arm.R`, `rebuild_forecasts.sh`: long, but already heavily cached (below).
- Already done, so NOT findings: tests skip when tracked non-doc files are unchanged (`check_like_ci.R:53-69`), `R CMD check` skips when the package fingerprint is unchanged, `--no-tests` inside the check, the clean-copy check, registry `file.size()`, quick_arm baseline reuse by harness-code signature and canary (`scripts/quick_arm.R:276-330`), cross-seat cache keyed by read set (`R/cross_seat_vote.R:241-275`, fixes the 10 Oct 54 s to 106 s finding), `AUSPOL_REBUILD_ONLY`/`AUSPOL_REBUILD_FROM` (`rebuild_forecasts.sh`).
- Already queued in `docs/NEXT-STEPS.md`, skipped here: read-set keys for defectors / personal prior / departed slope / salience (line 290), stage 4 xgb.cv one fold per election (line 368), fed `PARTY_COR` loop leak and resume cache (line 374).
- Retiring code: none found for these scripts (the R port rule in the global notes covers AFL/NRL, not auspol).

## Findings (most valuable first)

### 1. Run the test suite in parallel in check_like_ci.R
- `scripts/check_like_ci.R:72` calls `testthat::test_dir("tests/testthat", ...)` serially. `DESCRIPTION` has no `Config/testthat/parallel`. The machine has 24 cores. 165 files in `tests/testthat`.
- Suite length: the script's own comment says the in-check tests cost "~3 of the check's 9 minutes", and 25 of 60 runs are 3 min (suite only). So about 3 min per run that is not skipped. MEASURED as 3 min (from comment and run-length spread); the parallel speedup is UNTIMED (estimate 3x, so about 2 min saved per run, about 35 non-skipped runs in 14 days is about 70 min).
- Why slow: one process, 165 files, one after another.
- Fix: in `check_like_ci.R` set `Sys.setenv(TESTTHAT_PARALLEL = "true", TESTTHAT_CPUS = 6)` and call `test_dir(..., load_package = "source")` with `Config/testthat/parallel: true` locally only (do not add to DESCRIPTION, so CI is unchanged). 21 test files touch `Sys.setenv`/`options`, which is safe per worker process but any test sharing `output/` files or a tempdir name would race: run the suite once parallel and once serial and compare the pass counts. Mind memory: each worker loads the package (check free RAM first).
- Profile one unit: `powershell.exe -Command 'Rscript scripts/check_like_ci.R --tests-only --force-tests'` (prints `suite took N s`), then the same with `TESTTHAT_PARALLEL=true TESTTHAT_CPUS=6`.
- Stale risk: none for data; risk is test isolation (a flaky test that passes serially).

### 2. Overlap the suite and the R CMD check
- `check_like_ci.R:72` (suite) then `:196-205` (rcmdcheck) run back to back. The check works on a copied clean tree (`.src`) and does not read the suite's results, so they are independent. Full runs (tests plus check) are 7 to 10 min: 20 of 60 runs. MEASURED: those run lengths; saving UNTIMED (estimate: the shorter half, about 3 min, saved per full run, about 20 runs, about 60 min in 14 days).
- Fix: start the check with `callr::r_bg()` before the suite, collect it after. Memory: two R processes plus compile; check free RAM (about 8 GB) first.
- Profile: time each half from the script's own lines (`suite took`, `R CMD check N s`).
- Stale risk: none (same inputs). Combine with 1 only if memory allows.

### 3. build_model_registry.R: the switch scan is a regex over every token, per switch per file
- `scripts/build_model_registry.R:56-58` (`mentions`) runs a PCRE `grepl` over all parse tokens of a file, once per (switch, file). The matrix is 335 published switches times (the harness files at `:162`, plus 128 `R/*.R` files at `:84-86`, `:1152`). The parse itself is cached (`code_tokens`, `:44-55`), so the repeat cost is the regex.
- Cost: runs take 40 to 50 s each, about 25 runs in 14 days (about 20 min) MEASURED. How much of the 40 s is the regex is UNTIMED (estimate 25 to 35 s, from 335 x about 170 files = about 57k regex passes over every token of each file).
- Fix: per file, once, extract the set of names: `unique(unlist(regmatches(tok, gregexpr("AUSPOL_[A-Z0-9_]+", tok))))`, then `mentions(sw, f)` is `sw %in% names_in(f)`. Equivalent to the lookaround regex because maximal runs of `[A-Z0-9_]` end where the lookahead needs them to. Keep the fixture test at `:63-76` as the proof.
- Profile: `Rscript -e "Rprof('mr.out'); source('scripts/build_model_registry.R'); Rprof(NULL)"` (write to a temp file), or time lines 84-86 and 1152 only.
- Stale risk: none, it is a pure function of the files.

### 4. check_like_ci.R: fingerprint and file copy are redone on every call, even when both halves skip
- `check_like_ci.R:35-44` copies every git-tracked file into a temp root BEFORE the skip test at `:53-69`; the skip fingerprint only needs the md5 list. A skipped-suite run still costs the copy plus `.pkg_fingerprint()` (per-file regex over .Rbuildignore for every tracked file, `vapply` over `f` times `ign`). The 3-minute runs may partly be this.
- Saving: UNTIMED. The log has 3 runs of 1 min and 9 of 2 min, which are the floor for a fully skipped run; a skipped run at 1 to 2 min could be about 20 s. About 12 such runs, so about 15 min in 14 days.
- Fix: compute `.tnd`/`.tfp` first, copy the tracked tree only when the suite will run; precompute the `.Rbuildignore` match once with a single regex rather than `vapply` per path per pattern.
- Profile: `Rscript scripts/check_like_ci.R` with nothing changed, wrapped in `system.time`.
- Stale risk: low; the fingerprint inputs do not change.

### 5. Poll loops count as hand-run time and hide the real list
- Not a speedup of compute, but 30 of the top 40 rows in `runtimes.sh auspol 14` are watch loops (`gh run view` every 10 s, `until [ -f DONE ]`). Each timed-out 10-minute poll then gets re-armed. Using `run_in_background` plus the completion notice, or `gh run watch --exit-status` once, removes about 4 h of logged waiting and makes the table readable. MEASURED: row counts from the log; value is attention, not wall time.

## Not found / not checked

- Deciding-run scripts (`scripts/deciding_run.ps1`, `quick_arm.R`) and `rebuild_forecasts.sh` were read at their headers and cache sections only; the 10 Oct profile (`docs/reviews/fast-iter-profile-2026-10-11.md`) and NEXT-STEPS line 290 already cover the remaining per-run setup cost. I did NOT check whether `backtest_*` or NRL-style replays reuse output by file name alone for auspol.
- No O(n^2) hot spots confirmed: `rbind`/`c()` growth in `R/byelection_prior.R:106-142` and `R/candidate_returns.R:216-244,1078` are per-by-election or per-seat loops over tens of rows (not timed, likely negligible).
- The 96 min `check_like_ci.R` row (14 Nov) is probably a stalled process; it was not diagnosed.
