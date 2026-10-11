# What a screen can cache across arms (Phase 1 item 2), 2026-10-11

Read-only investigation: nothing was run. Source read: `scripts/backtest_candidate_{fed,vic,nsw,sa,wa,qld}.R`
(vic read end to end, the other five compared by which package functions they call), `scripts/quick_arm.R`,
`R/quick_arm.R`, `R/seat_poll_blend.R`, `R/cross_seat_vote.R`, `R/forecast_statewide.R`, `R/forecast_mode.R`,
`R/candidate_returns.R`, `R/split_slope.R`, `R/salience_*.R`, `R/new_ind_shrink.R`, `R/xgb_flow_override.R`,
`R/xgb_primary_override.R`, `R/fundamentals_tf.R`, `scripts/published_flags.R`.

**Marking.** "Read" = I read the code. "UNVERIFIED" = inferred, or not traced to the bottom. **There are no
per-stage timings in the repo** (the only ones: the 2026-10-07 vic profile in `R/quick_arm.R`, 144 s at 500 sims
and 183 s at 20,000 sims for three pairs, "no single hot spot"; fundamentals 32% of a pair on 2026-10-02, since
fixed; seat-poll blend 27 s of a live vic2026 build, since memoised). The parallel profiling agent owns the
seconds; every cost below is a guess from what the code does and is labelled as one.

## Findings that change the plan

1. **The harness never fits the xgb primary model.** `xgb_primary_override()` (`R/xgb_primary_override.R:29`)
   reads a static file (`output/xgb-primary-asat-predictions.csv`). So "xgb fits" is not a stage to cache. The
   only xgb work per run is `xgb_flow_conditional_override_for()` (`R/xgb_flow_override.R:193`), a per-seat R loop
   that calls `predict` on the flow model; its input is the arm's `shares`, so it is arm-dependent.
2. **Existing caches do not help across arms or across processes, by design.** Every `quick_arm` unit is a
   fresh `Rscript`, so the in-memory memos (`.seat_poll_memo`, `.lr_fit_memo`, `.poll_record_cache`, `.im_cache`,
   `.ip_memo`) start cold each time. The two disk caches that exist are keyed differently:
   `fundamentals_tf` keys on the data and the fitting code only (so it does hit across arms), but
   `.cs_fingerprint()` (`R/cross_seat_vote.R:246`) hashes **every `AUSPOL_*` variable**, so an arm that sets one
   extra switch misses it. The same all-variables key sits in `.seat_poll_memo_key()` (`R/seat_poll_blend.R:63`).
   That is the safe choice for an in-session memo and the wrong one for a cross-arm cache: with it, the cache
   helps only a rerun with an identical environment.
3. **A hand-written list of "the switches this stage reads" will go stale, and I found it already would.**
   `candidate_returns()` names 11 `AUSPOL_*` variables in its own file, but its callees add more
   (`fit_pairs_for` reads `AUSPOL_TIME_FORWARD_FITS`; `byelection_prior.R`, `state_notional.R` and
   `departed_successor.R` add `AUSPOL_BYELECTION_*`, `AUSPOL_STATE_NOTIONAL`, `AUSPOL_NOTIONAL`,
   `AUSPOL_DEPARTED_SUCCESSOR`; `defector_state.R` adds `AUSPOL_DEFECTOR_STATE`). That is the memory rule ("every
   var the stage reads, directly or via any function it calls") in action, and the reason I propose a
   *recorded* read set (design below), not a typed list.
4. **Where a cache may live matters.** `scripts/quick_arm.R` includes the whole `output/cache/` tree in
   `input_sig` (`SUBDIRS`, line ~109), which is part of every baseline key. A stage cache written into the
   main checkout's `output/cache/` would invalidate every cached baseline each time it grew. The slot copies
   of `output/` are persistent but per-slot and are never copied back. A new cache has to live in the quick_arm
   scratch directory (`qd/`), outside `output/`, and be named by a variable that is **not** `AUSPOL_*`: any new
   `AUSPOL_*` variable changes `.arm_fingerprint` in every output filename and every all-variables memo key
   (`.arm_fingerprint` excludes only `AUSPOL_OUT_SUFFIX`). Use e.g. `QUICKARM_STAGE_CACHE`.
5. **RNG is not a coupling problem on the default path.** Both simulation sites are immediately preceded by
   `set.seed(SEED)` (vic lines 849 and 989), and `statewide_draws_as_at()` seeds itself
   (`R/forecast_mode.R:~224`). A cached stage that skips a `set.seed` (e.g. `breakout_mix` `set.seed(1)`, off by
   default) cannot change the simulation draws. Re-check this per harness if a stage is added between the last
   `set.seed` and the simulation (the `FLOW_UNC` branch re-seeds inside a loop; it is off).
6. **The most useful split is "does the stage read the arm's `shares`?"** For the motivating case (a statewide
   level arm such as `AUSPOL_LEVEL_RECENT`) `sb` changes, so everything downstream of `shares` must rerun, but
   a long list of stages depends only on (target election, files, switches) and not on `shares`. Those are
   the cacheable ones (rows marked "no shares" below).

## Design the table assumes (record the read set, then validate it)

Key = hash of: code (hash of `R/` + `src/`, which `quick_arm` already computes as `code_hash`), the stage's
arguments by VALUE (election labels, and for any stage that takes `shares`, a digest of the matrix), and the
size+mtime of every file the stage reads. Not in the key: the environment. Instead, on a miss the stage runs
with `Sys.getenv` shimmed to log every name it asks for (and `Sys.getenv()` with no argument is an error that
stops the cache from being used), and the entry is stored with the *names and values read*. On lookup the
entry is a hit only if every recorded name has the same value now. This is dynamic dependency tracking; it is
sound because the stage is deterministic given what it reads, and a switch read only on one branch is caught
because the branch variable is itself in the read set. Files are the weaker half: the shim cannot see
`fread`s, so file stamps come from a declared list per stage (column "files read"), which is where the risk is.

## The table

One line on the columns: **stage** = what runs; **switches read** = `AUSPOL_*` found in the file(s) named, plus
known callees (incomplete by construction, see finding 3); **random?** = uses RNG; **cached now?** = existing
cache and its scope; **safe?** = "no shares" means the output does not depend on the arm's primaries;
**key** = what to hash beyond code. Cost column is a code-size guess, NOT a measurement (L/M/S = likely a
large/medium/small share of a ~50-60 s single-pair run).

| # | stage | file:line | switches read | files read | random? | cached now? | safe to cache? | proposed key (beyond code hash) | cost guess |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Statewide forecast: `forecast_statewide_or_oracle` -> `forecast_statewide_for` -> `statewide_draws_as_at` -> `flows_for`, `trend_as_at`/`fit_trend` (sparse solve per party), `project_result`, bucket total/ratio | `R/forecast_statewide.R:307`, `R/forecast_mode.R:72`, `R/projection.R:64`, `R/trend.R:366` | `FORECAST_MODE FUND_TIME_FORWARD BUCKET_SPLIT(_SRC) BUCKET_TOTAL(_SRC) IND_TREND MINOR_POLL_ADJ LEVEL_RECIPE CLOSE_PROPORTIONAL ANCHOR_IMPLIED ANCHOR_EXHAUST OTHERS_SCALE LIVE_LEVEL_ANCHOR TIME_FORWARD_FITS` (+ `LEVEL_RECENT*` in the tail) | polls via `load_polls` (**external/aus-polling-analyser clone**), `load_prior_results`, `load_election_cycles`, `load_preference_flows`, candidate-bucket model files | yes, seeded inside (`set.seed(42)`, n >= 20000 draws) | partly: fundamentals_tf on disk (narrow key); `level_recent` fit + poll record in-process only | **trend part: yes** (no shares). Split it: cache `trend_as_at` result and the raw draws; leave `level_recent_apply` (the part a level arm changes) outside the cache | (region, year, as_at, parties), recorded read set, stamps of the poll files + anchor clone HEAD, `candidacies.csv` | L (guess; ~7 party trend solves + 20k draws) |
| 2 | Pooled leave-future-out fits that loop over up to 21 earlier pairs, each calling `candidate_returns`: `fit_defector_discount`, `fit_minor_defector_discount`, `fit_major_departed_slope` (and `fit_departed_origin_return` if on) | `R/candidate_returns.R:1138,1392`, `R/split_slope.R:720`, harness vic ~L400-460 | `DEFECT_POOLED DEFECT_BY_LEVEL DEFECT_CONSERVE MINOR_DEFECT_CONSERVE DEFECTOR_STATE TIME_FORWARD_FITS SLOPE_SHRINK BYELECTION_MP BYELEC_*` (+ callees) | `output/candidacies.csv` (2.6 MB, re-`fread` by every one of these calls), external `byelections/` tables | no | no (only the cross-seat sub-part inside `personal_prior_vote`) | **yes, no shares** | (target election), recorded read set, stamps: `candidacies.csv`, `external/reference/byelections/*` | L-M (guess: ~4 functions x ~21 pairs of name matching) |
| 3 | `.returns <- candidate_returns(.ea,.eb)` and `personal_prior_vote(.ea,.eb, discounts)` incl. cross-seat credit | `R/candidate_returns.R:44,527`, `R/cross_seat_vote.R:300` | the 11 above + `CROSS_SEAT_VOTE BYELEC_LEVEL` (+ callees) | `candidacies.csv`, byelection files | no | cross-seat carry + by-election rows on disk, but **all-variables key** (misses on any extra arm switch) | yes, no shares (inputs are election labels + discounts from row 2) | (ea, eb, discount values), recorded read set, same stamps. Replace the all-vars key in `.cs_fingerprint` with the recorded read set | M |
| 4 | Salience: `salience_permit_for` (-> `governed_population`) and `surge_hazard_for` (-> `surge_training_population` over up to 9 pairs; ridge-logistic with 7 lambdas x leave-one-election-out folds) | `R/salience_screen.R:378,135`, `R/salience_surge.R:76,173` | `SALIENCE_BLEND SALIENCE_PCTILE_NZ SALIENCE_SMOOTH SALIENCE_SURGE_V2 SURGE_*` (surge_v2 list is in the harness, so key on its target-time-forward contents) | `output/salience-v6.csv`, `candidacies.csv` | no (ridge fit is deterministic) | no | **yes for the fit** (no shares). `blend_salience_shares` (needs shares) stays outside | (target, prev, region, train-pair list), recorded read set, stamps of the two files | M-L (guess: 63 ridge fits + two corpus passes per run) |
| 5 | Seat-poll blend inputs: `seat_poll_blend_table` -> `seat_poll_weight`, `seat_poll_weights_split`, `seat_poll_decay_params`, `seat_poll_ind_weight`, `seat_poll_model_var`, `seat_poll_shares` (loops earlier elections) | `R/seat_poll_blend.R:484,419,276,964,193,32` | the 14 `SEAT_POLL_*` in the file (`BLEND COALITION_DEDUP DECAY FIRM_FLOOR HANDKEYED IND_MAP IND_WEIGHT MATCH MRP_NAME PRECISION_BLEND PRIOR PRIOR_SD SOURCES W_SINGLE_CLUSTER`) | `external/reference/polls/seat-polls/seat_polls.csv`, `hand_keyed_primaries.csv`, `output/candidacies.csv`, `endorsement-features.csv`, `xgb-primary-asat-predictions.csv`, `forecasts.csv` | no | in-process memo only, all-variables key | **yes, no shares** (reads forecasts, not the arm's primaries). `seat_poll_blend_apply` (cheap) stays outside; **cache the returned table with its `w` attribute** | (target), recorded read set, the existing file-stamp list in `.seat_poll_memo_key` (already correct and complete as far as I read) | M (the 2026-10-10 note: 18 of 27 s on a live build; backtest calls it for 1 election but the weight fits walk earlier ones) |
| 6 | New-independent shrink fit: `new_ind_cells` + `new_ind_fit` (per earlier pair) | `R/new_ind_shrink.R:120,219` | `NEW_IND_SHRINK NEW_IND_SHRINK_CAP REENTRY IND_*` | `candidacies.csv`, `output/xgb-primary-v6-features.csv`, by-election table | no | no | yes for the **fit** (`fit$factor`, no shares). `new_ind_shrink_apply` mixes in `shares`, keep outside | (target), recorded read set, stamps | S-M |
| 7 | Re-entry (majors mode): `reentry_majors_fill` | `R/reentry_prior.R:708,814` | `REENTRY REENTRY_* NOM_LIVE TIME_FORWARD_FITS` | `candidacies.csv` | no | no | **no** for a level arm (uses `state_share` = `sb`); yes for non-level arms, via a shares digest in the key | digest(`mat`, `state_share`, `stand`), read set | S-M (UNVERIFIED) |
| 8 | Per-seat xgb flow override: `xgb_flow_conditional_override_for` (+ `htv_flow_override`) | `R/xgb_flow_override.R:193`, `R/htv_flow.R:94` | `XGB_FLOWS FLOW_ASAT HTV_FLOW FLOW_MODEL_TAG FLOW_CELL_SD` | flow model (`.model`), `xgb-flows-v1-features.csv`, cols json, `candidacies.csv` via `candidate_returns` | no (predict only) | no | **no for a primary- or level-changing arm** (loop reads `shares[si, ]`); yes if keyed on a digest of `shares` (hits for arms that leave primaries byte-identical: sim-only, calibration, seat-sd arms). The `key_rates` pre-aggregation of `hist` (no shares) is cacheable alone | digest(`shares`), read set, model + feature stamps | M-L (guess: R loop over ~90 seats x data.table ops) |
| 9 | Fixed-file readers: `state_notional_prior`, `byelection_prior`, `departed_successor_rates`, `statewide_cor`, `xgb_primary_override` incl. `xgb_base_delta_apply`, `seat_swing_port_adj`, `leader_seat_apply`, `demographic_residual_apply`, `zero_unnominated_at` (x2), `breakout_mix_args` | `R/state_notional.R:24`, `R/byelection_prior.R:84`, `R/statewide_cor.R:36`, `R/xgb_primary_override.R:29`, `R/seat_swing_port.R:195`, `R/leader_seat.R:142`, `R/demographic_residual.R:192`, `R/nomination_zero.R:281`, `R/breakout_mix.R:499` | various (see files) | one csv/rds each | no | `breakout`: disk (off by default); others no | mostly cheap reads. Not worth caching except `candidacies.csv` itself (stage 10) | n/a | S each |
| 10 | `candidacies.csv` parse (2.6 MB, `fread` repeated: `candidate_returns`, `personal_prior_vote`, `fit_defector_discount`, `surge_training_population`, `governed_population`, `zero_unnominated_at`, ...) | ~15 call sites, `grep candidacies.csv R/` | none | the file | no | no | yes: one per-process parse shared by all callers, keyed on size+mtime | (stamp) | S-M (guess: a dozen-plus parses of 2.6 MB per run) |
| 11 | `simulate_seat_contests` (C++ core) | `R/seat_sim.R:352` | `SIM_ENGINE BREAKOUT_MIX FLOW_CELL_SD` + every argument | none | **yes** (the arm's own draws) | no | **no** (arm-dependent by construction; ~20% of a run per the 2026-10-07 profile). Item 3's delta re-simulation is the only lever here | n/a | ~20% (measured 2026-10-07) |
| 12 | Scoring and write: `tcp_scenarios`, `seat_share_rmse`, glm slope, `fwrite` x4 | harness tail | none | writes `output/backtest-*` | no | no | no, arm-dependent and cheap | n/a | S |
| fed | Federal-only: inlined statewide at harness ~L992 (`statewide_draws_as_at`), `trend_flow_matrix` (L562), `state_poll_pool_apply` (L1489), `state_deviation_apply` (L1529), 7 pairs, no `seat_swing_port_apply` | `scripts/backtest_candidate_fed.R` | `STATE_POLL_POOL STATE_DEV` + stage 1 list | `state-deviation-features.csv`, polls | seeded | no | the statewide part: same as row 1. `state_poll_pool_slope` / `state_deviation_b` fits (inside `*_apply`) look like pure functions of earlier elections (UNVERIFIED) | as row 1 | stage 1 dominates here |
| nsw/sa/qld | `onp_senate_alloc` (L763/L819/L696), nsw `fit_major_conditional_slopes` (L670) | harnesses | `ONP_*` (UNVERIFIED) | senate files | no | no | not traced; likely cacheable | n/a | S-M (UNVERIFIED) |
| wa | no `statewide_cor`, no `surge_hazard_for`, no `departed_successor_rates`; otherwise the same stages | `scripts/backtest_candidate_wa.R` | | | | | rows 1-6 apply | | smaller (about 45 s per run, per the plan) |

## Stages that are NOT cacheable across a level arm

Rows 7, 8, 11, 12, plus `dev_slope`/`screened_slopes` and the rest of the `shares` pipeline in vic L500-L830
(cheap vectorised code, UNVERIFIED but no fitting loop was seen). A level arm changes `sb`, so these must rerun.
If the arm is sim-only (spread, shrink, seat-sd) rows 7 and 8 become cacheable through a `shares` digest.

## Expected saving per arm

**Labelled estimate; not measured; the profiling agent's numbers replace it.**

- A level arm reruns rows 7, 8, 11, 12 and the cheap `shares` code. Rows 1 (trend half), 2, 3, 4, 5, 6, 10 hit.
  If those are 40-60% of a ~50-60 s run (my guess from what they do, 3-4 fitting loops over 21 pairs plus one
  ridge CV plus a trend fit), a warm arm saves about 20-35 s per election. 22 elections at 2 slots is about
  11 min of arm today, so about 5-7 min warm. **This does not reach "under 5 minutes" by itself.** The first
  arm after a code edit is cold and pays the same as today, plus the cost of writing the entries.
- A sim-only arm (seat spread, shrink): add rows 7 and 8 via the `shares` digest and everything except
  row 11/12 hits; the floor is startup (`load_all` + compiling check) + simulation + scoring, about 25-30% of
  a run (guess). That is where the cache plus the delta re-simulation of item 3 meet.
- **Unmeasured fixed cost**: `devtools::load_all()` plus Rscript start per unit is the same for every unit and
  no stage cache removes it. Worth the profiler measuring.

## Riskiest key

**Row 2 and 3 (the pooled fits and `personal_prior_vote`) are the most likely to miss an input**, for three
reasons found while reading: (a) the switches they read are spread over at least six files and are not all in
the file that names the function (finding 3); (b) they read external by-election tables under
`external/reference/byelections/` that `quick_arm`'s `input_sig` hashes by tree but a stage key must stamp
separately; (c) the existing cross-seat cache already shows both failure modes (a key that is too wide, so it
never hits, and a hand-listed code set `fns <- c(".cs_match", ...)` that misses any helper not in the list).
This is exactly where the recorded read set (not a typed list) is worth its extra machinery.

**Second riskiest: row 1**, because it reads the polling-anchor clone outside `output/` and the statewide
number is what every other row hangs from. A stale clone already flipped a verdict once (memory
"Check the anchor clone's freshness"), so the key must include the clone's HEAD and working-tree state, as
`quick_arm`'s `external_id` does.

## How to prove each key before trusting it (house rule: a check must fail on broken input first)

For each cached stage: (1) run cold and warm and diff the returned object byte for byte
(`identical()`); (2) change ONE switch the stage is known to read and confirm a miss; (3) change one the stage
does not read and confirm a hit; (4) touch (mtime) one declared file and confirm a miss; (5) edit a helper in
`R/` the stage calls transitively and confirm a miss. Step 2 is the one that catches a stale switch list;
the recorded read set makes it automatic for switches but not for files, so step 4 stays manual per stage.

## Not done / unverified

- No stage was timed; all cost labels are guesses.
- Only the Victorian harness was read end to end; NSW, SA, QLD, WA and fed were compared by which package
  functions they call (the per-harness table), not read line by line. Stages unique to them (rows fed, nsw/sa/qld)
  are not traced.
- `reentry_majors_fill`, `leader_seat_apply`, `demographic_residual_apply`, `zero_unnominated_at`,
  `departed_successor_rates` were seen as fixed-file readers, not opened. The claim "cheap" for them is
  unverified.
- I did not check `devtools::load_all()` start-up cost or whether the compiled `src/` is rebuilt per slot.
- Whether `Sys.getenv` can be shimmed at package level without changing behaviour (e.g. code that calls
  `Sys.getenv()` for the whole table, as the existing memo keys do) was not tested; those call sites
  (`.cs_fingerprint`, `.seat_poll_memo_key`, `.arm_fingerprint`) must be allowed to read everything or be
  rewritten to the recorded-set scheme.
