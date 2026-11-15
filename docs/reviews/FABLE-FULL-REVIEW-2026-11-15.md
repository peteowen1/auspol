# Fable full review, 15 Nov 2026

## Pick up from here

Written 9:10pm Sunday 15 Nov 2026. **All five sections are finished; none is in progress.** The work list
below runs top to bottom. Full briefs are the "Issue N" blocks further down this file; each item here adds
what must not change, the proof, and what it collides with.

Rules for every item: work on `dev`; run `powershell.exe -Command 'Rscript "scripts/check_like_ci.R"'`
before any push (exit code 0 is the proof for R changes); review the diff before opening a PR; edit YAML
and anything with backslashes with the Edit tool only. **Never dispatch `forecast.yaml` to test a change:
a dispatch publishes to the live site.** Items A1 to A3 all edit `.github/workflows/forecast.yaml`, so do
them one after another in one PR, not in parallel.

**A. Safe, independent, no decision needed**

- **A1. Manual forecast runs skip the 16 what-if jobs** (Issue 7). File: `.github/workflows/forecast.yaml:21-34`
  (inputs) and `:801-804` (the `scenarios` job's `if`). Change: add boolean input `scenarios`, default
  false; job condition becomes not-quick AND (scheduled OR `inputs.daily` OR `inputs.scenarios`). Must
  not change: anything in the `refresh` job; the daily run must still build scenarios. Proof:
  `python -I -c "import yaml;yaml.safe_load(open('.github/workflows/forecast.yaml'))"` exits 0, and the
  next 4:30am daily run still uploads `scenario-vic2026.json` (check its `built_at`). 20 minutes. Haiku.
- **A2. Quiet five false daily warnings, fix stale comments** (Issue 6). Files: `forecast.yaml:244, 248,
  341, 342, 346` (warn only when the flag in `scripts/published_flags.R` needs the file; the pattern to
  copy is at `:251`), `:354`, `:499`, `:582`, and `docs/PIPELINE.md:50` (04:30, not 06:00). Must not
  change: which files are downloaded when a flag is on; any `exit 1` guard. Proof: same YAML parse; the
  next daily run's annotations show none of the five. 1 hour. Haiku. After A1 (same file).
- **A3. Alarm on a new validation failure even when the job is green** (Issue 2). File: `forecast.yaml`,
  new step after "Keep a dated copy of the forecast on R2" and before the NSW step; reuse the issue code
  at `:709-792`. Also delete the two NL3 lines at the end of `.github/known-failures.txt`. Must not
  change: the publish steps; a validation breach must still not block publishing. Per Pete's B3 answer,
  DO add the new `fit_nsw.R` failure to the baseline, with the reason (NSW One Nation poll noise 3.04
  against a limit of 3.0 on 24 polls; nothing published reads the stage) and "REMOVABLE WHEN: the limit
  is reviewed after 28 Nov". Proof: `sh scripts/test_failure_signature.sh`
  passes, and `sh scripts/failure_signature.sh <a run.log> .github/known-failures.txt` exits 1 on the
  15 Nov log (get it with `gh run view 43621475293 --log`). 1-2 hours. Sonnet. After A2 (same file).
- **A4 is BUILT, 15 Nov 9:45pm, NOT committed** (Pete said go). `scripts/build_forecast_json.R`, +60 lines,
  uncommitted on `dev`: names come from the `source == "vec"` rows of `output/candidacies.csv` (the file
  the model reads and the workflow already downloads), `sitting` stays with the Wikipedia table matched on
  seat and surname, a new `candidates` array lists every candidate of a class, NSW keeps Wikipedia. Proved
  on tonight's `-llp1` run: 572 of 572 cells with a vote named (was 353), Croydon's Liberal is Toby
  Wooldridge, 67 of 67 sitting members flagged; a list cut to 88 rows stops the build (`FJ5!`, exit 1);
  `scripts/check_like_ci.R` exit 0 (5,308 passed, 0 failed). **Left to do: review the diff, commit, open
  the PR, and tell the `inthegame-blog` session the `candidates` array exists.** It also turned up A7 below.
- **A7. NEW, found while building A4: nominated candidates published at 0%, and a wrong "elected" flag in
  the model's input.** (1) Four seat-classes have candidates on the final list and a published primary of
  exactly 0: Prahran Independents (4 candidates), Ripon Independents (2), Mildura Others (2: Victorian
  Socialists, Animal Justice), Kew Other-right (1). Confirmed in `output/seat-shares-vic-2026-llp1.csv`
  and the live file. The class had no vote there last time and nothing gives a new entrant a share.
  (2) `output/candidacies.csv` has `historic_elected` TRUE on 69 vic2026 rows against 67 sitting members;
  the extra two are Preston's independent William Fowles and Evelyn's Family First candidate Michelle
  O'Brien, and neither holds that seat. The model reads this column for its sitting and departed member
  flags. Whether Fowles is deliberate (elected in Ringwood in 2022) and where O'Brien's flag comes from
  (`scripts/build_candidacies.R`, the vic2026 `historic_elected` join) is NOT checked. Do: trace both
  rows through `build_candidacies.R`; for (1) list what `fit_seats_full.R` does for a class with a
  candidate and no base (grep `NZL`, `new_ind`, `FS1L`). Must not change: anything, until the trace is
  read by Pete or Opus; this is a model change 13 days out. Half a day. Sonnet to trace, Opus to judge.
- **A4 as first written (kept for the brief).** File: `scripts/build_forecast_json.R:28-33`
  and `:83-89`, `:133-141`. Source: `external/reference/vec/2026/vec-candidates-2026.csv` (columns
  `district`, `ballot_position`, `name`, `registered_name`, `independent`). Must not change: NSW 2027
  (keeps Wikipedia), any number in the JSON, the existing `candidate` and `sitting` field names. Proof:
  build locally with `AUSPOL_OUT_SUFFIX=-llp1 Rscript scripts/build_forecast_json.R` (the `-llp1` seat
  files from tonight are in `output/`), then confirm Croydon's Liberal/National name is one of FARR,
  VANDERWOLF, SCHWAB, THOMAS, WOOLDRIDGE, GRIMSHAW, BRINDLEY, FERNANDO and that every ALP, LNP, GRN and
  ONP cell with a vote has a name. 2-3 hours. Sonnet. Independent of A1-A3.
- **A5. Poll layering log lines** (Issue 8). File: `R/poll_source.R:513-560` (the pairing loop and the
  disputed-pair rule) and the `PZ1` message at `:627`. Must not change: which polls the trend reads
  (log lines only). Grep `R/` and `scripts/` first to confirm `PZ6` and `PZ7` are unused codes. Proof:
  a new test in `tests/testthat/` plus `check_like_ci.R`. 3 hours. Sonnet. Independent.
- **A6. Put the statewide vote the forecast uses into the JSON** (Issue 4, repo half).
  `fit_seats_full.R` already writes `output/statewide-level-vic-2026.csv` (columns `party, level`; seen
  tonight), so only `scripts/build_forecast_json.R` changes: add a `statewide` block with `forecast_level`
  from that file and `seats_mean` (mean of the seat primaries). Must not change: existing fields. Proof:
  the block equals the `FP0` log line of the same run. 1 hour. Sonnet. After A4 (same file). The blog
  change waits for decision B2.

**B. DECIDED by Pete, 15 Nov 9:15pm (clicked answers): he took the first option on all four.** So
B1 = relabel the two-party line and add the polls' own figures as dots (Issue 5 is unblocked); B2 = tiles
show the level the forecast uses (the blog half of Issue 4 is unblocked, after A6); B3 = add the
`fit_nsw.R` failure to `.github/known-failures.txt` with its reason, removable after 28 Nov (do it inside
A3; the token is `stage:fit_nsw.R:CHECK:sd_from_link(e$sigma_obs, share, sc) <= 3 is not TRUE` plus
`stage:NSW cycles`); B4 = leave `AUSPOL_LIVE_LEVEL_PRED_TREND=1`. None is recorded in `docs/DECISIONS.md`
yet: the morning session files them. The options as they were put:

- **B1. Two-party chart label**: relabel as implied from primaries and plot the polls' own figures
  (mine), or fit the line to the polls' figures. Then Issue 5.
- **B2. Party tiles**: show the level the forecast uses (mine), or keep the trend and add a sentence.
  Then the blog half of Issue 4 (tell the `inthegame-blog` session; do not edit that repo from here).
- **B3. NSW check failing since 13 Nov**: list it in `.github/known-failures.txt` with the reason until
  after 28 Nov (mine), or change the 3.0 limit at `scripts/fit_nsw.R:185` now.
- **B4. Pre-blend level switch**: leave `AUSPOL_LIVE_LEVEL_PRED_TREND=1` as it is (mine). Measured tonight
  (finding 1.4): turning it off moves one seat-party cell by more than 2 points (Essendon Independent
  39.8% to 36.8%) and swaps the nominal favourite in one three-way seat (Benambra: Independent 35.6%
  against One Nation 35.4%, becoming 34.2% against 36.2%). Expected seats move by at most 0.12.

**C. Larger pieces**

- **C1. Find why the 88 seats average Labor 23.56 against a statewide input of 22.51** (what is left of
  finding 1.4; the level switch is ruled out). Add a log line in `scripts/fit_seats_full.R` printing the
  mean seat share per party after each step (base, nomination zeroing, trees, seat-swing port, seat
  polls, final) beside `FP0`, run once with `AUSPOL_OUT_SUFFIX=-trace` (6.5 minutes locally), and report
  which step adds the point. Must not change: any published number (byte-compare `seat-probs` with
  tonight's `-llp1` file). Half a day. Sonnet, Opus to read the result.
- **C2. Score the 14-day forecast** (Issue 9). Opus. Days. Write the criterion first.
- **C3. Take validation-only stages off the publish path** (Issue 10). Sonnet. Half a day. After A1-A3
  (same workflow) and after 28 Nov unless Pete wants it sooner.
- **C4. After 28 Nov only**: section 2 items 2.1, 2.4, 2.5 (one harness, delete the retired two-party
  model, prune refused switches).
- **C5. Local forecast run is 6.5 minutes against 79 seconds on the runner** (section 3). Cache the
  `ind_person` step. Sonnet. Half a day.

---

Review of `auspol`. Focus: polls in, forecast out, what the site shows.
Started 7:33pm Sydney time, Sunday 15 Nov 2026.

**Status: COMPLETE, all five sections, finished 7:55pm Sunday 15 Nov; finding 1.4 measured 8:48-9:02pm
after Pete said go.** The review itself changed nothing but this file and ran no model. The two forecast
runs afterwards wrote 18 suffixed files to the gitignored `output/` folder (`*-vic-2026-llp1.*` and
`*-llp0.*`) and refreshed `output/polls-wiki/` with `scripts/refresh_local_poll_inputs.sh`; no published
file name was written, and nothing was committed.

## Needs Pete's decision

1. **The two-party chart on the site (finding 1.5).** The line says Labor 47.6; five of the six recent
   polls that publish a two-party figure say 43 to 45. The line is built from primaries and past
   preference flows, not from those figures.
   - Option A (mine): keep the line, relabel it "implied by first preferences and past preference flows",
     and plot the polls' own figures as dots so the gap is visible and explained.
   - Option B: fit the line to the polls' published figures.
   - What separates them: A is a wording change that matches what the seat forecast does; B puts a
     number on the site that the forecast does not use.
2. **The party tiles (finding 1.3).** They show the poll trend (Labor 23.4, One Nation 20.7); the seat
   forecast starts from the trend blended toward the last 20 days of polls (Labor 22.5, One Nation 21.5).
   - Option A (mine): show the level the forecast uses, with the trend chart unchanged beneath.
   - Option B: keep the tiles and add one sentence about the blend.
   - What separates them: whether the tiles mean "the polls today" or "what the forecast assumes".
3. **The NSW check that now stops the stage (finding 1.2).** NSW One Nation's poll noise is fitted at
   3.04 points against a limit of 3.0, on 24 polls.
   - Option A (mine): list it in `.github/known-failures.txt` with that reason until after 28 Nov, and
     fix the alarm so the next new failure is seen.
   - Option B: change the limit now.
   - What separates them: B is a model-check change two weeks before an election for a stage nothing
     published reads.
4. **The pre-blend level switch (finding 1.4, measured 15 Nov 9:02pm).** Turning
   `AUSPOL_LIVE_LEVEL_PRED_TREND` off moves one seat-party cell by more than 2 points (Essendon
   Independent 39.8% to 36.8%) and swaps the nominal favourite in Benambra, a three-way seat (35.6% against
   35.4% becomes 34.2% against 36.2%). Expected seats move by at most 0.12.
   - Option A (mine): leave it on, as decided 26 Oct.
   - Option B: turn it off.
   - What separates them: nothing measurable in the forecast; A keeps the live trees on the recipe they
     were trained with.

## Top 10

Ranked by harm to what a reader sees, then by how cheap the fix is.

| # | finding | kind | live | size | who |
|---|---|---|---|---|---|
| 1 | Site names candidates from a 16 Oct Wikipedia table: 219 of 572 cells nameless, at least 2 wrong names (1.1) | wrong output | yes | 2-3 h | Sonnet |
| 2 | A new failure in the daily run cannot raise the alarm; one has been failing since 13 Nov (1.2) | wrong output | yes | 1-2 h | Sonnet |
| 3 | The 88 seats average Labor 1.05 above the statewide input; cause not found. The pre-blend level switch was measured 15 Nov and is NOT it (1.4) | wrong output, size unknown | yes | half a day | Sonnet, Opus reads |
| 4 | Party tiles on the site are not the statewide vote the forecast uses (1.3) | wrong output | yes | 2 h + blog | Sonnet, Pete's wording |
| 5 | Two-party line sits above 5 of 6 recent polls' own figures, unlabelled (1.5) | wrong output | yes | 1 h | needs Pete |
| 6 | Five daily warnings for switches that are off, a stale known-failures file, stale workflow comments (1.6, doc gaps) | tidy-up | yes | 1 h | Haiku |
| 7 | Manual forecast runs launch 16 what-if jobs each: about 2,200 job-minutes last week (3) | wasted time | yes | 20 min | Haiku |
| 8 | No guard when two polls of one firm inside 4 days are paired on date alone; no missing-poll list (1.6, 5.3) | wrong output, not seen yet | latent | 3 h | Sonnet |
| 9 | The published track record is day-before only and on 681 of 2,931 seats; nothing scores the 14-day forecast the site shows (4.1, 4.2) | wrong output (overstated) | yes | days | Opus |
| 10 | Four validation-only stages and an unread covariance matrix sit on the publish path (2.2) | tidy-up | yes | half a day | Sonnet |

## Top 10 as ready-to-paste issues

Not filed. Each is written for a cheaper model to pick up cold.

**Issue 1. Site: take vic2026 candidate names from the VEC final list, not the Wikipedia table**

`scripts/build_forecast_json.R:30` reads names and `sitting` from
`external/reference/wikipedia/vic2026-candidates.csv` (380 rows, last regenerated 16 Oct). The final
list is `external/reference/vec/2026/vec-candidates-2026.csv` (734 candidates). On the live
`forecast-vic2026.json` of 15 Nov, 219 of 572 seat-party cells with a vote have `candidate: null`, and
Croydon names a Liberal ("Grant Hutchinson") who is not among Croydon's 8 nominated candidates.
Question: for each seat and party class, who is on the ballot? Use the same class mapping the model uses
(`classify_party()`; see how `scripts/build_candidacies.R` turns the VEC file into classes). Where a
class has more than one candidate, publish all names in ballot order (new field `candidates`), keep
`candidate` as the first. Keep `sitting` from the existing source. NSW 2027 keeps Wikipedia.
Done means: every ALP, LNP, GRN and ONP cell with a vote in all 88 seats has a name; no published name is
absent from the VEC file for that seat; a log line `FJ4` prints named cells of total and the script stops
below 95% for the four main classes; `scripts/check_like_ci.R` passes; the two examples above are right
in a local build.

**Issue 2. Daily run: raise the alarm on a NEW validation failure even when the job is green**

`.github/workflows/forecast.yaml:431-433` turns a non-zero `run_all.R` into a warning so the Victorian
forecast still publishes, and the alarm step (`:710`) only runs `if: failure()`. So
`scripts/failure_signature.sh` can print "NEW failures" and nobody is told. It has done so since 13 Nov:
`scripts/fit_nsw.R:185` stops on `sd_from_link(e$sigma_obs, share, sc) <= 3 is not TRUE` (runs
43418778677, 43473478623, 43621475293).
Do: add a step after the publish steps, daily runs only, that runs
`sh scripts/failure_signature.sh run.log .github/known-failures.txt`; on exit 1 or 2 open or comment the
existing "Forecast refresh is failing" issue with the diff (reuse the alarm's issue code). Delete the two
NL3 lines from `.github/known-failures.txt` (they no longer fail). Do not add the new failure to the
baseline without Pete's answer to decision 3.
Done means: a dispatch with `alarm_test=true` on a branch where `fit_nsw.R` fails produces an issue
comment while the forecast still publishes; a run with only known failures stays silent;
`scripts/test_failure_signature.sh` still passes.

**Issue 3. Re-walk `AUSPOL_LIVE_LEVEL_PRED_TREND` at today's gap, and log what the seats add up to**

DONE in part 15 Nov 9:02pm: the two runs below were made and the switch moves almost nothing (finding
1.4 has the table). What remains is the last paragraph, the per-step log line: work item C1 at the top.

`scripts/published_flags.R:692` serves the tree model the statewide level from before the recent-poll
blend. It shipped 26 Oct after a walk in which no seat moved, when the two levels were about 0.6 apart.
On 15 Nov the run log says `LLP1 ... blended minus pre-blend: LNP -0.33, ALP -0.91, GRN -0.06, ONP +0.86`,
and the 88 published seats average Labor 23.56 against a statewide input of 22.51.
Do (in a worktree if a scheduled rebuild is registered): run `scripts/refresh_local_poll_inputs.sh`, then
`AUSPOL_OUT_SUFFIX=-llp1 Rscript scripts/fit_seats_full.R` and
`AUSPOL_LIVE_LEVEL_PRED_TREND=0 AUSPOL_OUT_SUFFIX=-llp0 Rscript scripts/fit_seats_full.R` (about 80 s
each; the suffix lets a non-published value run). Diff the two `seat-probs-vic-2026-*.csv` and
`seat-shares-vic-2026-*.csv`.
Report: number of seats whose favourite changes, the largest probability move, and the vote-weighted
statewide share per party in each run beside `FP0`. Also say how much of the Labor +1.05 comes from
nomination zeroing (`NZP2`: 141.2 points freed over 40 cells).
Done means: a short review file with that table; if any favourite changes or any probability moves more
than 2 points, stop and put it to Pete. Separately add a permanent log line in `fit_seats_full.R`
printing the seats' vote-weighted statewide share beside `FP0`.

**Issue 4. Publish the statewide vote the forecast uses and show it in the site tiles**

`scripts/build_page.R:431,476` publishes `fp_now` from `trend_as_at()` (the poll trend). The seat
forecast starts from the blended level printed as `FP0` in `fit_seats_full.R`'s log. On 15 Nov they
differ by 0.9 for Labor and 0.8 for One Nation.
Do: `fit_seats_full.R` already writes the `FP0` values to `output/statewide-level-<tag>.csv` (columns
`party, level`; confirmed 15 Nov), so read that file and add them to `forecast-<election>.json` as `statewide` with fields
`trend`, `forecast_level`, `seats_implied`. Blog change (separate repo, tell that session): tiles read
`forecast_level`; method text mentions the 20-day blend. Wait for Pete's answer to decision 2 before the
blog change.
Done means: the JSON carries all three per party, they are equal to the log lines of the same run, and a
check stops the build if the file is older than the seat files.

**Issue 5. Label the site's two-party line for what it is**

The `TPP_ALP` series in `vic-page-data.json` (`scripts/build_page.R`, `proj` at `:477`) is implied from
primary trends and past flows (47.55 on 15 Nov); the six latest polls with a published figure average
44.5. Blocked on Pete's decision 1. If A: add each poll's published two-party figure to the `polls`
array (field `tpp`, already in `recent`), and change the blog's chart heading and tooltip
(`politics/_forecast-body.qmd:590-640`).
Done means: the chart shows the dots, the heading says how the line is built, and no number changes.

**Issue 6. Quiet the daily run's false warnings and fix stale comments**

`forecast.yaml:244, 248, 341, 342, 346` warn every day about files for switches published off
(`AUSPOL_SEAT_POLL_BLEND=1` not 3, `AUSPOL_DEPARTED_FED=0`, `AUSPOL_UPSET_FLOOR=0`, `AUSPOL_XGB_BOOTH=0`,
`AUSPOL_XGB_SENATE=0`). Read each flag from `scripts/published_flags.R` (the pattern is at `:251`) and
only download and warn when the published value needs the file. Fix the stale text at `:354` (rebuild
time), `:499` (eyeball comment) and `:582` (NSW step name), and `docs/PIPELINE.md:50` (04:30, not 06:00).
Done means: a daily run's annotations list only real problems; `actionlint` or a dry dispatch passes.
Use the Edit tool for the YAML (backslashes).

**Issue 7. Do not run the what-if scenario jobs on manual forecast runs**

`forecast.yaml:801-804`: the `scenarios` matrix (16 jobs, 248 job-minutes on 15 Nov) runs on every
non-quick run. Add a boolean input `scenarios` (default false); run the matrix when the run is daily or
the input is true. `publish-scenarios` and `scenario-alarm` already depend on it.
Done means: a manual dispatch finishes after `refresh`; a `daily=true` dispatch still publishes
`scenario-vic2026.json`; the what-if page's "as of" still matches the daily forecast.

**Issue 8. Poll layering: log date-only matches with different numbers, and list polls left out**

`R/poll_source.R:74` pairs polls of one firm within 4 days whatever their numbers; `:536-547` keeps the
anchor's row when a pair disagrees by more than 2 points and no two-party figure settles it. In the last
week of a campaign that can drop a new poll. Add to `poll_layer()`'s log: a `PZ6` line per pair matched
on the date window whose Labor, Coalition, Greens or One Nation figures differ by more than 3 points,
and a `PZ7` line listing our rows that were dropped (suspect, or lost a disputed pair). Surface both in
the workflow summary.
Done means: a unit test with two polls of one firm 3 days apart and 5 points different shows the line;
the 15 Nov poll set produces zero `PZ6` lines for the vic2026 cycle (or each one is explained); no change
to which polls the trend reads.

**Issue 9. Score the forecast at the horizon the site publishes at**

Every backtest is the day before polling day. Build the 14-day version for one election first:
vic2022 through `scripts/backtest_candidate_vic.R` with the poll cutoff 14 days earlier and the as-at
tree model unchanged (find the `as_of` argument to `trend_as_at()`). Report seat log loss, favourite
accuracy and first-preference error by party against the day-before run, same seed, same seats.
Then put the all-elections figure beside the AEF-7 one in `track_record`: 0.3202 on 2,931 seats (35
elections) from `output/published-predictions.csv`, with the naive "last time's leader" rate (78.2%).
Done means: a review file with the vic2022 table and seat count, a statement of whether the 14-day
forecast is calibrated by band, and the two new `track_record` fields in the JSON. Write the criterion
before running (`docs/PRE-REGISTRATION-RULES.md`).

**Issue 10. Take validation-only stages off the publish path; delete the unread covariance stage**

`scripts/run_all.R:45-61`. Nothing published reads the outputs of `fit_federal.R`, `fit_nsw.R` or
`backtest_flows.R`, and `estimate_statewide_cov.R` writes an identity matrix on the runner for a switch
that is off (`AUSPOL_PARTY_COR`, `published_flags.R:81`). First prove it: on a clean checkout with only
the daily inputs, run `fit_vic.R`, `fit_projection.R`, `fit_seats_full.R`, `fit_scorecard.R`, the page
and JSON builders, and confirm the published files are byte-identical to a full `run_all.R`. Then move
the three validation stages to a weekly workflow that fails when they fail, and delete the covariance
stage with its readers (`fit_seats_full.R:249-264`, `:1743-1765`) unless Pete wants the refused arm kept.
Done means: byte-identical published outputs, the daily log loses its `CV0!` lines, the weekly job is
green or red on its own, `docs/PIPELINE.md` and `docs/MODEL-REGISTRY.md` are regenerated.

## Decisions made while reviewing

- `docs/reviews/` holds 322 files. I read the queue (`docs/NEXT-STEPS.md`), `docs/PIPELINE.md`, the
  daily workflow and `CLAUDE.md` in full, and searched `docs/DECISIONS.md`, `docs/PETE-ASKED-FOR.md`, the
  reviews and the journals by keyword for each finding before writing it. I did not read all 322 reviews
  end to end. None of findings 1.1 to 1.5 appears in them.
- The focus line was "polls in, forecast out, what the site shows", so the model internals (leakage in
  the backtests, the seat simulator, the night model) were not re-audited. The 18 Oct pipeline audit and
  the queue already cover them.
- No subagents were used: every check was a direct read or a small script.
- The blog repo (`C:\dev\inthegame-blog`) was read, not changed. Blog-side fixes are named but belong to
  that repo's session.
- I did not run the forecast during the review. Pete said go afterwards, and finding 1.4 was then
  measured with two local runs (8:48-9:02pm); the result is in 1.4.
- The "Pick up from here" block was added at 9:10pm at Pete's request, relayed by the DEV session.

## 1. Wrong numbers

**What was traced.** Three things a reader sees on https://inthegame.blog/politics/vic, each followed
back to its source, using the files the site read at 4:39am on 15 Nov 2026 (daily run 43621475293,
commit `c6843f2`) and that run's log:

1. The party tiles under "The polls" (Liberal/National 31.0, Labor 23.4, One Nation 20.7, Greens 14.4,
   Others 10.5) and the poll dots: `vic-page-data.json` `fp_now` and `polls` <- `scripts/build_page.R`
   <- `trend_as_at()` <- `load_polls()` <- `R/poll_source.R` (Wikipedia + BludgerTrack + the anchor's file).
2. One seat card (Albert Park: Greens 48.9%, Labor 37.5%, with candidate names): `forecast-vic2026.json`
   <- `scripts/build_forecast_json.R` <- `seat-probs-vic-2026.csv` / `seat-shares-vic-2026.csv` <-
   `scripts/fit_seats_full.R`, plus the candidate table.
3. The run itself: which inputs were missing, stale or failed while the run finished green.

**What checked out (confirmed by running, so nobody re-checks it):**

- The site's poll dots equal the published poll snapshot: 81 polls this cycle in both, 0 in one and not
  the other; latest poll 13 Nov (Lighthouse). No poll appears twice under the 31-day same-numbers rule.
- Seat win probabilities add to 1 in all 88 seats; the JSON equals the CSV in all 425 seat-party rows;
  expected seats per party equal the sum of seat probabilities (Labor 24.28 both ways); seat primaries add
  to 100 in all 88 seats; 88 of 88 seats simulated.
- Live files were 15 hours old when read (built 4:39am 15 Nov); models promoted 13 Nov 9:25pm.

### 1.1 The site names candidates from a Wikipedia table of 16 Oct, not the final nominations list

- Kind: wrong output
- `scripts/build_forecast_json.R:30` (`candidates_file`), used at `:134-140`
- Evidence: the seat cards' `candidate` and `sitting` fields come from
  `external/reference/wikipedia/vic2026-candidates.csv` (380 rows, last regenerated 16 Oct, commit
  `f9197a68`). The VEC's final list has 734 candidates (`external/reference/vec/2026/vec-candidates-2026.csv`,
  loaded 9 Nov) and the model itself uses it. On the live site: 219 of 572 seat-party cells that have a
  vote show no name (One Nation 58 of 88, Other-right 66 of 79, Independents 37 of 54, Liberal/National
  21 of 88, Labor 14 of 88, Greens 12 of 88, Others 11 of 87); 8 seat favourites have no name (7 One
  Nation, plus Shepparton's Liberal/National at 94%). 15 of the 380 Wikipedia names are not on the VEC
  list for their seat by surname (some are spelling variants, not all checked). Two checked by hand:
  Croydon shows "Grant Hutchinson" as the Liberal favourite at 94.8%, and no Hutchinson is among
  Croydon's 8 nominated candidates; Mildura shows "Ali Cupper" (Independent, 0%), who did not nominate.
  Where two candidates share a class the first Wikipedia row wins (`nm[1]`).
- Confirmed by running: a Python count over the live `forecast-vic2026.json`, and a surname match of the
  Wikipedia table against the VEC list; `grep -iE "^2026,(Croydon|Mildura)," external/reference/vec/2026/vec-candidates-2026.csv`
- Live right now: yes.
- Fix: read vic2026 names from the VEC file (ballot order; class from the same `classify_party()` call
  the model uses), keep Wikipedia only for `sitting`, and where a class has two candidates list both or
  name the one with the higher prior vote. Add a count line (`FJ4 named cells N of M`) and stop if fewer
  than 95% of major-party cells are named after nominations close.
- Size: 2-3 hours. Sonnet.

### 1.2 A new failure in the daily run is invisible: the run is green and the alarm cannot fire

- Kind: wrong output (a check that cannot fail)
- `.github/workflows/forecast.yaml:431-433` (the pipeline step swallows `run_all.R`'s exit code) and
  `:710` (the alarm runs only `if: failure()`); `scripts/fit_nsw.R:185`
- Evidence: `scripts/fit_nsw.R` has stopped on `sd_from_link(e$sigma_obs, share, sc) <= 3 is not TRUE`
  (NSW One Nation poll noise fitted at 3.04 points against a limit of 3.0) in 3 of the 3 runs read since
  13 Nov 10:39pm (runs 43418778677, 43473478623, 43621475293). It passed in the 13 Nov 4:30am run
  (43270170588, `ok (16 s)`). All four runs concluded `success`. The alarm's own comparison, run on the
  15 Nov log, prints "NEW failures, not accounted for" and exits 1, but that script is only called from
  the alarm step, which needs a failed job, and from the run summary, which nobody is told to read. So
  the rule in `.github/known-failures.txt` ("anything NOT in this list raises the alarm") has not been
  true since validation breaches stopped failing the job on 19 Sep. The same file is also stale the other
  way: its two NL3 lines no longer fail (NSW One Nation now tracks its polls, 13 Nov run).
- Confirmed by running: `sh scripts/failure_signature.sh <run.log from run 43621475293> .github/known-failures.txt` (exit 1)
- Live right now: yes. Effect on published numbers: none found. Nothing reads `fit_nsw.R`'s output files
  (grep of `R/` and `scripts/`); the NSW 2027 forecast comes from `fit_seats_full.R`. What is lost is the
  NSW trend checks (N1-N3, NL2-NL4), which have not run for three days, and any future new failure in
  any validation stage.
- Fix: after the publish steps, add a step that runs `failure_signature.sh` and, on exit 1 in a daily
  run, opens or comments the alarm issue (the existing alarm body can be reused). Then decide the NSW
  assertion itself: 3.04 against 3.0 on 24 polls is the limit being marginal, not a broken fit. Delete the
  two stale NL3 lines.
- Size: 1-2 hours for the alarm (Sonnet); the 3.0 limit needs Pete or Opus.

### 1.3 The party tiles on the site are not the statewide vote the seat forecast uses

- Kind: wrong output (two numbers for one thing)
- `scripts/build_page.R:431` and `:476` (`fp_now` from `trend_as_at()`); `scripts/fit_seats_full.R` (log lines `FP0`, `LLP1`)
- Evidence, 15 Nov run. Statewide first-preference vote, %, three versions:

  | party | site tile (`fp_now`, the poll trend) | what the seat forecast starts from (`FP0`, after the 20-day recent-poll blend) | unweighted mean of the 88 published seat primaries |
  |---|---|---|---|
  | Liberal/National | 31.0 | 30.68 | 30.68 |
  | Labor | 23.4 | 22.51 | 23.56 |
  | One Nation | 20.7 | 21.51 | 21.08 |
  | Greens | 14.4 | 14.34 | 14.86 |
  | Others (all) | 10.5 | 10.96 | 9.83 |

  The tile and the forecast's own level differ by 0.9 for Labor and 0.8 for One Nation, in opposite
  directions. The site text says "The poll trend gives each party a statewide vote", which leaves out the
  blend. `vic-page-data.json` also carries a third set (`track.fitted`: Labor 22.1, One Nation 22.8, from
  `fit_vic.R`'s other trend model); the site does not show it.
- Confirmed by running: read `FP0` and `LLP1` in the run log; means computed from the live `seat-shares-vic-2026.csv`.
- Live right now: yes.
- Fix: publish the level the forecast uses (`FP0`) in `forecast-vic2026.json` and show that in the tiles,
  or keep the tiles and add one line saying the forecast leans further toward the last 20 days of polls.
  Either way write `FP0` to a file so the page builder cannot drift from it.
- Size: 2 hours here plus a blog change. Sonnet. Wording is Pete's.

### 1.4 The seats do not add back to the statewide vote, and the tree model is fed the level before the blend

- Kind: wrong output (unverified size)
- `scripts/published_flags.R:692` (`AUSPOL_LIVE_LEVEL_PRED_TREND = "1"`); log lines `LLP1`, `NZP2`
- Evidence: in the table above the 88 seats average Labor 23.56 against a statewide input of 22.51
  (+1.05), and all Others 9.83 against 10.96 (-1.13). Two things act here and I did not separate them.
  (a) Nomination zeroing removes 141.2 points of share across 40 seat-classes with no candidate (1.6
  points a seat) and hands them on by preference flows; that is intended. (b) The tree model is given the
  statewide level from BEFORE the recent-poll blend (Labor 23.43, One Nation 20.65), by a decision of 26
  Oct taken after a walk in which no seat moved. That walk was done when the gap between the two levels
  was about 0.6 points; on 15 Nov it is Labor -0.91, One Nation +0.86, and it grows as the last 20 days
  of polls take over. The seat mean for Labor (23.56) sits on the pre-blend level (23.43), not the
  blended one. Means are unweighted by enrolment.
- **MEASURED 15 Nov, 8:48-9:02pm (Pete said go): (b) is not the cause.** Two local runs at HEAD
  (`23f2d832`), same refreshed polls, 20,000 simulations, seed 42, differing only in the switch
  (`AUSPOL_OUT_SUFFIX=-llp1` at the published "1", `-llp0` at "0"). Win probability, 425 seat-party cells:

  | measure | published setting | switch off |
  |---|---|---|
  | mean seat primary, Labor | 23.56 | 23.62 |
  | mean seat primary, One Nation | 21.08 | 21.13 |
  | expected seats, Labor / Liberal-National / One Nation | 24.53 / 39.72 / 14.90 | 24.65 / 39.79 / 14.79 |
  | chance of a Liberal-National majority | 30.1% | 30.3% |

  One cell moves by more than 2 points (Essendon Independent 39.8% to 36.8%); none by more than 5. The
  nominal favourite changes in one seat, Benambra, a three-way seat where Independent 35.6% and One
  Nation 35.4% become 34.2% and 36.2%. The mean absolute primary move is under 0.1 points for every
  party except Other-right (0.19). So the 26 Oct decision still holds at today's gap, and the Labor
  +1.05 comes from somewhere else: nomination zeroing, the trees, or the unweighted mean. Not isolated.
- Confirmed by running: `AUSPOL_OUT_SUFFIX=-llp1 Rscript scripts/fit_seats_full.R` and
  `AUSPOL_LIVE_LEVEL_PRED_TREND=0 AUSPOL_OUT_SUFFIX=-llp0 Rscript scripts/fit_seats_full.R`, then a diff
  of `output/seat-probs-vic-2026-llp{1,0}.csv` and `seat-shares-vic-2026-llp{1,0}.csv`.
- Live right now: the +1.05 is; the level switch is cleared.
- Fix: work item C1 at the top of this file (print the mean seat share after each step beside `FP0`).
- Size: half a day. Sonnet, Opus to read the result. Pete's call on the switch is B4 (my pick: leave it).

### 1.5 The two-party trend line on the site sits above five of the six recent polls' own two-party figures

- Kind: wrong output (label)
- `scripts/build_page.R:477` (`proj`), the `TPP_ALP` series in `trend`; blog `politics/_forecast-body.qmd:590-640`
- Evidence: the site's "Labor's two-party-preferred vote" line ends at 47.55 (95% band 44.98 to 50.12).
  The six most recent polls that published a two-party figure give Labor 43, 44, 44, 46, 45, 45 (mean
  44.5; 7 Nov back to 8 Oct). Five of the six are below the band. The line is not fitted to those
  figures: it is built from the primary-vote trends and past preference flows (One Nation to Labor 33.7%,
  the mean of the last five elections). The polls' own figures imply about 23%.
- Confirmed by running: read from the live `vic-page-data.json` (`recent`, `trend`, `onp`).
- Live right now: yes. The seat forecast does not use this number (seats use per-seat flow models).
- Fix: Pete's call, see "Needs Pete". The 27-28 Sep refusal of the anchor-implied arm
  (`AUSPOL_ANCHOR_IMPLIED`) was about the seat forecast, not about what this chart should be called.
- Size: 1 hour. Needs Pete.

### 1.6 Smaller (confirmed in the 15 Nov run log unless an item says otherwise)

- **Five warnings every day for switches that are off** (`forecast.yaml:244`, `:248`, `:341`, `:342`,
  `:346`): "runs WITHOUT the joint blend / departed-member blend / upset floor / booth / Senate features".
  The published values are `AUSPOL_SEAT_POLL_BLEND=1`, `AUSPOL_DEPARTED_FED=0`, `AUSPOL_UPSET_FLOOR=0`,
  `AUSPOL_XGB_BOOTH=0`, `AUSPOL_XGB_SENATE=0`, so nothing is missing. Kind: tidy-up, but it trains the
  reader to skip the warning list, which is where 1.2 lives. Fix: warn only when the published flag asks
  for the file. 30 minutes, Haiku.
- **The statewide covariance stage writes a matrix nothing reads** (`scripts/run_all.R:61`): on the runner
  it finds 1 of 10 election pairs, prints about 40 `CV0!` lines and writes the identity fallback;
  `AUSPOL_PARTY_COR` is published "off" (`published_flags.R:81`). See Simplify.
- **The site says the tree model was "trained on 22 past state and federal elections"**; the manifest in
  the same JSON says 35 pairs and 2,931 seat-elections. Blog text, `politics/_forecast-body.qmd:1361`.
  Fix: fill it from `track_record.pairs`. 15 minutes in the blog repo.
- **`leaders.as_of` is 6 Nov** while polls run to 13 Nov. Not checked whether the three later polls
  carried leader ratings; unverified.
- **BludgerTrack's Victorian table has the same file stamp (11 Nov 3:45pm) on the 13, 14 and 15 Nov
  runs** (`BK1 vic2026: 69 rows`). That is their file, not ours, and Wikipedia covered the 13 Nov poll.
  No line warns when the stamp is more than N days old in the last fortnight. Low.
- **Read only, not run: a new poll can be swallowed by an older one from the same firm.**
  `R/poll_source.R:74` pairs any two polls of one firm with midpoints within 4 days, whatever their
  numbers, and `:536-547` keeps the anchor's row when the two disagree and neither fits a published
  two-party figure. A firm polling twice inside 4 days in the final week, with one poll in each source,
  would lose the newer one. Not seen in the 81 polls so far. The cheap guard is a log line listing pairs
  matched on date alone with any party more than 3 points apart.
- One Redbridge row to look at with the `poll-feed-check` skill: 14 Jul 2026 (26/26/12/27, Wikipedia
  only, no two-party figure) against 23 Jun 2026 (26/26/13/27). Different by one Greens point; unverified
  whether it is a second poll or a re-report.

## 2. Simplify

Nothing here should be touched before 28 Nov except 2.2 and 2.3, which only take things out of the daily
run. Line counts are `wc -l` on 15 Nov.

### 2.1 Seven backtest harnesses that are copies of one another

- Kind: tidy-up
- `scripts/backtest_candidate_fed.R:1` (2,058 lines), `_nsw.R` (1,439), `_qld.R` (1,313), `_sa.R` (1,520),
  `_vic.R` (1,239), `_wa.R` (966), `_nt.R` (973): 9,508 lines.
- Evidence: `CLAUDE.md` spends a whole section on "a fix to one harness is a fix to all of them", records
  the rule failing twice on one parameter, and `docs/MODEL-REGISTRY.md` exists to police it. The registry's
  columns are `fed | nsw | qld | sa | vic | wa`: the Northern Territory harness is not in it, and
  `CLAUDE.md` still says there are six.
- Read only, not run.
- Live right now: yes (the duplication; no wrong number found from it today).
- Fix: one harness that takes a jurisdiction config (pair list, flow source, seat-name map, which fetchers),
  proven byte-identical on all 35 pairs before the copies are deleted. Removes roughly 6,000-7,000 lines,
  the parity rule, and most of the registry. What could break: any per-state special case that only lives
  in one copy; the proof is the byte-identical rerun.
- Size: a week. Fable or Opus. After 28 Nov.

### 2.2 Four daily stages that only validate, on the path that publishes

- Kind: tidy-up / wasted time
- `scripts/run_all.R:45-61`: `backtest_flows.R` (118 lines), `fit_federal.R` (646), `fit_nsw.R` (536),
  `estimate_statewide_cov.R` (362)
- Evidence: nothing in the published path reads what `fit_federal.R` and `fit_nsw.R` write (grep for their
  output names finds only themselves and two one-off scripts). The covariance stage writes an identity
  matrix on the runner (1 of 10 pairs available) for a switch that is off (`AUSPOL_PARTY_COR="off"`,
  refused 16 Oct). They cost about 55 seconds of the 4.5-minute pipeline step and most of its log noise
  (about 40 `CV0!` lines a day), and when one fails nobody is told (1.2).
- Confirmed by running: stage times and `CV0!`/`CV1!` lines read from run 43621475293's log.
- Live right now: yes.
- Fix: move the three validation stages to their own weekly workflow whose failure does fail the job.
  Delete `estimate_statewide_cov.R` and the `AUSPOL_PARTY_COR` / `AUSPOL_COV_TF` branches (362 lines plus
  the readers in `fit_seats_full.R:249-264` and `:1743-1765`) unless the refused arm is to be retried.
  What could break: `fit_projection.R` if it turns out to read a federal or NSW file I did not find; run
  it alone on a clean checkout to prove it.
- Size: half a day. Sonnet.

### 2.3 The page builder still makes a page and eleven fields nobody reads

- Kind: tidy-up
- `scripts/build_page.R:509-513` (writes `output/victoria-2026.html` from `scripts/page-template.html`),
  `:208` (a second full trend fit, used only for the `onp` field), `:260-388` (`seat_rows`)
- Evidence: the site reads six fields of `vic-page-data.json` (`trend`, `polls`, `fp_now`, `scorecard`,
  `meta`, `leaders`, plus `mix`). It never reads `data_status`, `onp`, `recent`, `track`, `track_bound`,
  `proj`, `seats`, `seat_rows`, `seats_by_party` or `seats_in_play` (grep of `inthegame-blog/politics`).
  `seat_rows` carries a two-party figure per seat from the retired two-party view (Northcote "81.7"),
  beside a win probability from the candidate model. The standalone HTML (174 KB) is uploaded to the
  release daily; I found no link to it.
- Confirmed by running: `grep -rhoE "\b(pd|pageData|page)\.[a-z_]+" politics/*.qmd` in the blog repo.
- Live right now: yes.
- Fix: drop the HTML page, its template and the unread fields; move the three numbers the workflow
  summary prints (`forecast.yaml:451-461`) to `forecast-vic2026.json`. Roughly 300 of 568 lines plus the
  template. What could break: the workflow's "Summarise" step and the artifact upload, which name the
  HTML file; and anyone who opens the HTML by hand (ask Pete).
- Size: half a day. Sonnet.

### 2.4 The retired two-party seat model is still in the package

- Kind: tidy-up
- `R/seats.R:1` (248 lines), `scripts/fit_seats.R` (215), `scripts/test_seat_probability_calibration.R`
  (130), `tests/testthat/test-seats.R`
- Evidence: `CLAUDE.md` says it is retired, must never be tuned, and is to be deleted once anything it
  can still do is ported. `simulate_seats()` is called only from those three files.
- Confirmed by running: `grep -rnE "simulate_seats\(" R scripts tests`
- Live right now: yes (dead weight; three drifts onto it are recorded for 20 Aug).
- Fix: delete the four files and the export; rerun `check_like_ci.R`. What could break: `build_page.R`'s
  `seat_rows` baseline if it leans on anything in `R/seats.R` (goes away with 2.3).
- Size: 2 hours. Sonnet. After 28 Nov.

### 2.5 318 switches, 106 of them off, in a 153 KB file

- Kind: tidy-up
- `scripts/published_flags.R:1` (910 lines, 153,636 bytes)
- Evidence: 318 `AUSPOL_*` entries; 106 are published at `"0"`, `"off"` or `"none"`; 21 say REFUSED on
  their own line. Every refused arm keeps a branch alive in `R/` and in seven harnesses, and each daily
  run prints "published flags applied to 300 unset switch(es)". The file's comments are the history of
  each switch, which the decision journals already hold.
- Confirmed by running: `grep -cE '^\s+AUSPOL_[A-Z0-9_]+\s+= ' scripts/published_flags.R` and two filters on it.
- Live right now: yes.
- Fix: after the election, delete refused arms whose prereg says "do not rerun without a new idea"
  (switch, branch, tests), and cut each remaining comment to one line plus a pointer to its decision.
  What could break: an archived deciding run can no longer be reproduced from HEAD; tag the commit first.
- Size: 2-3 days, in small PRs. Sonnet with an Opus-written list of which arms go.

Held back (a later decision): 202 of 525 scripts (23,685 of 91,816 lines) are named by no other script,
R file, workflow, test or `docs/PIPELINE.md`; 146 of them have not changed in 30 days. About 97 are
one-off `test_`, `score_`, `screen_`, `compare_` and `diag*` files (about 10,100 lines) that could move to
`scripts/archive/`. The parsers and fetchers in that list are hand-run data builders and should stay.

## 3. Speed, cost and storage

Measured on the 15 Nov daily run (43621475293) with `gh run view --json jobs`, and `gh run list`.

Job time in one daily forecast run, minutes (lower is better):

| part | minutes | note |
|---|---|---|
| `refresh` job, start to finish | 10.8 | the forecast is on the site about 9 minutes after the trigger |
| - pipeline step (`run_all.R`) | 4.5 | `fit_projection.R` 88 s (19 s two days earlier), `fit_seats_full.R` 79 s, `fit_federal.R` 40 s |
| - cloning the anchor's repository | 2.0 | for a file that supplied 1 of this cycle's 81 polls on its own |
| - model downloads | 0.7 | 52 assets on the release, 46 MB in all |
| 16 what-if scenario jobs | 248 | Victoria 16-22 minutes each, NSW 7-11 |
| whole run | 259 | wall clock 34 minutes |

- The repository is public, so Actions minutes cost nothing. The cost is queue time and noise.
- 16 forecast runs started in the last 7 days: 7 daily, 9 by hand. Each run by hand also starts the 16
  scenario jobs unless `quick` is ticked.
- `R-CMD-check` ran 184 times in 7 days at about 5 minutes; of the last 12, 3 were cancelled and 2 failed.
- Release storage is small: `shipped-models` 46 MB. Two leftovers from 11 Sep are still there
  (`xgb-flows-v1-loo-models.zip` 8.5 MB, `xgb-primary-v6-oof-predictions.csv` 1.1 MB).
- Local `output/` holds 7,141 files; a plain `ls output | grep` took over two minutes and `du` on the
  repo had not finished after ten. Its size is NOT measured here for that reason.
- Format: the largest CSVs on the release are 8.8, 5.5 and 3.9 MB. Parquet would shrink them but the
  runner would then need `arrow`; not worth it.

The three cheapest wins:

1. **Do not run the 16 scenario jobs on runs started by hand** (`forecast.yaml:801-804`): add a
   `scenarios` input, default off for manual runs, on for the daily one. Nine manual runs last week were
   about 2,200 job-minutes of what-if runs for forecasts that were replaced within hours. 20 minutes. Haiku.
   Kind: wasted time. Live.
2. **Stop cloning the anchor's repository** (`forecast.yaml:114-125`): take the commit hash with
   `git ls-remote` and fetch the poll CSVs and the seat files the pipeline reads by raw URL. Two minutes
   off every run and one less way to fail. First list exactly which files under `analysis/` are read
   (`load_polls()`, `load_seats()`, `election-cycles.csv`). 2 hours. Sonnet. Kind: wasted time. Live.
3. **Clear `output/` of suffixed runs** (`-scn-*`, `-board*`, `-trial`, `-arm`, `-base`, old `backtest-*`
   files): every directory scan in every script and every registry build pays for 7,141 files. Move
   anything older than the last published rebuild to a dated folder outside the repo. Needs Pete's yes
   (it is his disk and some are evidence for reviews). 1 hour.

**Measured 15 Nov, 8:48pm: a local forecast run takes 6.5 minutes against 79 seconds on the runner.**
`scripts/fit_seats_full.R`, two runs, 388 s and 397 s (3.1 to 4.2 GB of memory free). Its own timing
table: "project each seat's primaries" 316 s (82%), of which the `ind_person` step is 190 s, the seat-poll
blend 35 s and `own_prev` 23 s; the simulation itself is 31 s. The runner skips those because it reads
shipped tables ("sources absent"); a local run rebuilds them from the election files every time. Kind:
wasted time. Live. Fix: cache `ind_person`'s result keyed on every file and switch it reads (the 11 Oct
speed item in `docs/NEXT-STEPS.md` names the same pattern for four other steps, not this one). Worth
about half of every local walk. Half a day, Sonnet. If the run is killed, nothing is on disk: every
output is written at the end; at 6.5 minutes that is tolerable, and the cache would fix most of it.

Already known and not repeated: stage 4 of the rebuild (1,664 s for 31 models) and the read-set cache
keys, both in `docs/NEXT-STEPS.md` under "Harness and pipeline hygiene" and the 11 Oct speed item.
`fit_projection.R` taking 88 s on one day and 19 s on another with identical check lines is unexplained;
time it twice locally before believing either.

## 4. Scorecard

The repo already has one: the AEF-7 ledger (7 elections, 681 seats, against AE Forecasts), published in
`forecast-vic2026.json` as `track_record` and quoted on the site. Three numbers, with what each cannot see.

### 4.1 Seat log loss on every as-at election, not only the seven

How far the stated seat probabilities were from what happened; lower is better; 0.693 is a coin flip
between two candidates.

- How to compute: `output/published-predictions.csv` (one row per candidate; `p_win`, `won`), winner's
  probability floored at 1e-6, mean over seats.
- Today (computed 15 Nov from the 13 Nov rebuild, 19,616 rows): **0.3202 on 2,931 seats in 35 elections**
  (standard error 0.032, treating each election as one observation). On the 681 AEF-7 seats the published
  figure is 0.2532 against AE Forecasts' 0.2825.
- Baselines: a coin flip 0.693. "Whoever led on first preferences last time wins" is right in 2,220 of
  2,839 seats (78.2%); a forecaster who said exactly that rate would score 0.524. Ours picks the winner
  in 2,595 of 2,931 (88.5%).
- Reliability by band (seats where the favourite was given that chance, and how often it won):

  | favourite's stated chance | seats | won | rate |
  |---|---|---|---|
  | 95% or more | 1,625 | 1,602 | 98.6% |
  | 80 to 95% | 619 | 543 | 87.7% |
  | 60 to 80% | 486 | 337 | 69.3% |
  | under 60% | 201 | 113 | 56.2% |

- Run-to-run movement with nothing changed: zero for the published run (seed 42; the two 19 Sep history
  rows from different commits are identical). Across seeds at 20,000 simulations it has not been
  measured on the pooled figure; `quick_arm.R` treats differences under one standard error as noise.
- What the site's figure cannot see: the 28 elections outside AEF-7, where we are worse (Northern
  Territory 2024 0.875, WA 2001 0.855, Queensland 2017 0.599). 11 seats where the winner was given under
  0.1% carry 14.4% of the whole log loss. The site quotes the 681-seat figure and the words "22 past
  elections".
- Confirmed by running: a Python pass over `output/published-predictions.csv` (anchors checked first:
  the naive rule scores below the model, and the 95%+ band wins 98.6%).

### 4.2 Statewide vote error at the horizon the site is actually publishing at

- Every backtest scores the forecast made the day before polling day. The site has published a forecast
  every day since 19 Sep, 70 days out. The only horizon evidence is two-party: `mix` in
  `vic-page-data.json` gives a held-out mean error of 1.80 points at 14 days and 1.66 at 1 day (lower is
  better; the poll trend alone 2.00 and 1.75; fundamentals alone 2.69).
- What is missing: first-preference error by party at 14, 28 and 60 days, and seat log loss at those
  horizons. Nothing on disk gives it; `scripts/screen_level_share.R` (about 10 s, all elections) is the
  place to add a horizon argument.
- Baseline to beat: the poll trend alone at the same horizon, and the previous result.
- Not computed here (needs a model run per horizon).

### 4.3 The live-only path, which no backtest exercises

- Switches that act only in the published Victorian run: `AUSPOL_LIVE_LEVEL_PRED_TREND`,
  `AUSPOL_MINOR_ADDITIVE`, `AUSPOL_NOM_LIVE`, `AUSPOL_HTV_CARD_P`, the live bucket split, the live
  poll-page refresh. The ledger cannot see any of them.
- The number: after 28 Nov, seat log loss and first-preference error for vic2026 from the last published
  `forecast-vic2026.json` (not from a rebuild), against the four captured benchmarks. The scorer exists
  (`scripts/score_benchmarks_vic2026.R`); the results file does not.
- Until then the only check is the daily diff: `forecast-history.csv` has 109 rows over 55 days. A line
  in the run summary saying "expected seats moved by X since yesterday; polls added: N" would make an
  unexplained jump visible the day it happens.

## 5. What to build next

Ranked by value over effort.

1. **"What changed since yesterday" on the site.** Dated copies of the forecast have been on R2 since 7
   Oct and nothing reads two of them together. A reader in the last fortnight wants to know which seats
   moved and which poll moved them. First step: a script that diffs today's and yesterday's dated JSON
   into `changes-vic2026.json` (chamber odds, the ten biggest seat moves, polls added). Hours for the
   file, a day for the page.
2. **Show the statewide vote the forecast uses, and how it got there.** One row per party: poll trend,
   after the recent-poll blend, implied by the 88 seats. It answers "why does the forecast have Labor at
   22.5 when the tile says 23.4", and it is the standing check for finding 1.4. First step: write `FP0`
   and the vote-weighted seat total to a small CSV in `fit_seats_full.R`. Hours.
3. **A missing-poll monitor.** Each morning, list polls that appear on Wikipedia, BludgerTrack or the
   anchor's file and are not in the 81 the trend read, plus the age of each source, in the run summary.
   The `poll-feed-check` skill does this by hand against X; this is the automatic half. First step: have
   `poll_layer()` return its dropped and unmatched rows, which it already computes. Hours.
4. **Score the forecast at 14, 28 and 60 days out** (4.2). Readers are looking at a 14-day forecast with
   a day-before track record beside it. First step: one election (vic2022) through the as-at path with
   the poll cutoff moved back 14 days, trees unchanged. Days.
5. **Candidate cards from data already on disk.** Final nominations (734 candidates, ballot order),
   council history, endorsements, search interest and the how-to-vote card are all in the pipeline and
   none reaches the site beyond a name. First step: fix 1.1, then add ballot position and "sitting /
   stood before / councillor" badges to the seat JSON. Days.
6. **A public "how we did" page, ready before the count.** The scorer and four benchmark captures exist.
   What is missing is the results file and a page that fills in as seats are declared. First step: fix
   the `district, winner, status` file format against the VEC website pages the night code already
   reads. Days, and it has a deadline.
7. **A morning note to Pete.** Run conclusion, new failures (1.2), polls added, biggest seat moves, in
   The Daily Eight or by email. It closes the gap that let three days of a failing stage go unseen.
   First step: reuse the run summary text. Hours.

### Documentation gaps

- `CLAUDE.md` says there are six harnesses and that `pool_backtests.R` covers "22 pairs and 2,050
  seat-elections"; there are seven harnesses and the manifest says 35 pairs and 2,931.
  `docs/MODEL-REGISTRY.md` (regenerated 15 Nov) has no Northern Territory column.
- `docs/PIPELINE.md:50` says the daily forecast runs at 06:00 Melbourne; the workflow is triggered at
  04:30. The same file says 19 as-at models and 23 pairs; NEXT-STEPS says 31 models.
- `.github/known-failures.txt` lists two NL3 failures that no longer fail and does not list the one that
  does (1.2).
- `forecast.yaml:582` names the NSW step "off until the repository variable AUSPOL_PUBLISH_NSW2027 is 1";
  it is on and publishing. `forecast.yaml:499` has a comment about keeping the page for a human to
  eyeball, above a step that publishes unattended. `forecast.yaml:354` says a rebuild takes 25 minutes.
- `scripts/build_forecast_json.R:28-30` describes the Wikipedia candidate table as the source of names;
  nothing says it stopped being the right one on 9 Nov (1.1).
- The site's method text ("trained on 22 past state and federal elections", "The poll trend gives each
  party a statewide vote") is in the blog repo and is out of date on both counts.
- A recorded decision I would reopen: 26 Oct, `AUSPOL_LIVE_LEVEL_PRED_TREND=1`
  (`docs/backlog/journal-decisions-2026-10-23-to-10-31.md:34` and `:57`). It was right on its evidence:
  no seat moved. The evidence was a gap of about 0.6 points between the two levels; the gap is now 0.9
  and rising, so the walk needs repeating before polling day (1.4), not the decision reversing on my
  say-so.
