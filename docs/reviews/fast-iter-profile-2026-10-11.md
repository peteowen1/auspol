# Profile of one harness run, 2026-10-11 (fast-iteration plan, Phase 1 item 1)

Why it matters: a screen is 44 harness runs, so every second a run spends on work that does not change with the arm is
paid 44 times. This measures where the time of ONE run goes, and which parts an arm can actually change.

## 1. What was run

- Harness: `scripts/backtest_candidate_vic.R`, pair **vic2022 (2018 -> 2022)**, **1,000 simulations**.
- Command (the same environment `quick_arm.R` gives a run), from inside the quick_arm scratch root
  `%TEMP%\auspol-quickarm\slot1` (junctions to this checkout's `R/ scripts/ src/ external/`, a copy of `output/`;
  nothing written to the real `output/`):
  `AUSPOL_XGB_PRIMARY=1 AUSPOL_SKIP_PAIRS=wa2021 AUSPOL_N_SIMS=1000 AUSPOL_VIC_PAIR=2022 Rscript <driver>` where the
  driver `source()`s a copy of the harness with `.tt("label")` timers (a `cat` of elapsed seconds) inserted before 24
  top-level statements. The real harness is untouched; the copy and helpers are in the session scratchpad.
- Code state: dev at d99e3c8 plus the working-tree edit to `docs/PETE-ASKED-FOR.md` only. Shipped flags
  (`LEVEL_RECENT=decay`, half-life 20). Machine: one run at a time, foreground.
- Five runs, all pair vic2022, 1,000 sims:

Total wall time of each run, in seconds (lower is faster). "Cross-seat cache" is the on-disk fit cache that
`R/cross_seat_vote.R` keeps in `output/cache/cross-seat`.

| run | what it was | wall seconds | cross-seat cache |
|---|---|---|---|
| 1 | with `Rprof` sampling on, first ever run in this scratch root | 111.8 | cold (profiling itself roughly doubled the time; used for function attribution only) |
| 2 | timers only, baseline switches | **54.0** | warm |
| 3 | timers only, baseline switches again after an unrelated env var was added | 101.3 | cold (see finding 1) |
| 4 | timers only, **one arm switch** `AUSPOL_LEVEL_RECENT=0` | **106.2** | cold |
| 5 | timers only, baseline switches, repeat | **54.0** | warm |

Runs 2 and 5 agree to 0.1 s, so the stage timings below have about 0.1 s of run-to-run noise (n=2).

## 2. The headline finding

**Changing ANY `AUSPOL_*` switch, even one the cross-seat model never reads, makes the run take about twice as long
(54 s -> 106 s), because the cross-seat vote fit (`fit_cross_seat_carry`, ~49 s) is refitted from scratch.**
`.cs_fingerprint()` in `R/cross_seat_vote.R` (line ~244) hashes every set `AUSPOL_*` variable into the cache key, so an
arm run never hits the baseline's cache. Measured: arm run 4 spent 56.1 s between the `before_xgb_primary_override`
and `before_zero_unnominated` timers, the same span took 6.7 s in the warm baseline. In a 22-election screen the arm side
pays this 22 times (the baseline side pays it only on the first build).

Statically (inferred, not run), the code reachable from `fit_cross_seat_carry` reads only `AUSPOL_BYELECTION_MP`,
`AUSPOL_BYELECTION_PRIOR` and `AUSPOL_TIME_FORWARD_FITS`. A level-only arm such as `LEVEL_RECENT` does not feed it.

Also: simulation is **1.8 s of 54 s (3%)** at 1,000 sims, not the ~20% profiled on 2026-10-07; the rest is setup and fitting.

## 3. Ranked stages (warm baseline, run 5)

Seconds each section of the harness took on the warm run (timers placed before each section; section = time to the
next timer), and share of the 53.8 s script total (higher share = bigger target). "Arm-dependent" is a static read
of every `AUSPOL_*` name in the functions called and the functions they call (inferred, an upper bound: a name can
appear in code the section never reaches); "no" means no switch name found. Functions in the last column are named
from the code in that line range; the share-of-profile figures in section 4 support the attributions marked (P).

| rank | harness lines | section | seconds | % of 53.8 | arm-dependent (switches found) | main functions |
|---|---|---|---|---|---|---|
| 1 | 763-771 | xgb override, independent-person/typical/mixture applies (cross-seat fit read from cache) | 6.7 (**56.1 on an arm run**) | 12.5 (**53 on arm**) | yes: DEPARTED_SUCCESSOR IND_MIXTURE IND_PERSON IND_TYPICAL NEW_IND_SHRINK REENTRY XGB_BASE_* XGB_PRIMARY(_OOF); the fit inside: BYELECTION_MP BYELECTION_PRIOR TIME_FORWARD_FITS | `xgb_primary_override`, `ind_person_apply` -> `ind_person_carry_fit` -> `.cs_cached` -> `fit_cross_seat_carry` (P: 30.4 of 71.6 profiled s cold), `.cs_fingerprint` (P: 1.7) |
| 2 | 952-1023 | breakout mix, flow-conditional override, surge-mixture args | 6.6 | 12.3 | yes: BREAKOUT_* FLOW_ASAT FLOW_CELL_SD XGB_FLOWS XGB_PRIMARY_LIVE SEAT_POLL_COALITION_DEDUP BYELEC_DEPARTED IND_MIXTURE | `breakout_mix_args`, `xgb_flow_conditional_override_for` (P: 4.5), `ind_mixture_surge`; own sim `s1` only if FLOW_UNC |
| 3 | 562-600 | transferred-vote removal, departed-member slopes | 6.5 | 12.1 | yes: BYELEC_DEPARTED BYELECTION_MP BYELECTION_PRIOR SLOPE_SHRINK TIME_FORWARD_FITS | `fit_major_departed_slope` (P: 4.2), `fit_departed_origin_return`, `route_departed_origin`, `personal_prior_vote` |
| 4 | 550-562 | split-slope context and sitting-member carry | 5.7 | 10.6 | yes: SPLIT_SLOPE TIME_FORWARD_FITS BYELEC_LEVEL CROSS_SEAT_VOTE DEFECT_* DEFECTOR_STATE MINOR_DEFECT_CONSERVE | `personal_prior_vote` (P: 6.1), `split_slope_context`, `.cs_prep` (P: 6.4), `byelection_table` (P: 5.2) |
| 5 | 849-932 | salience surge hazard | 5.1 | 9.5 | yes: SALIENCE_PCTILE_NZ SALIENCE_SMOOTH | `surge_hazard_for` (P: 3.4), `surge_training_population` (P: 2.4), `governed_population` (P: 2.6) |
| 6 | 771-836 | nomination zeroing, seat-poll blend, residual appliers | 4.2 | 7.8 | yes: NOM_ZERO NOM_ZERO_ORDER SEAT_POLL_* (about 16 names) TIME_FORWARD_FITS | `seat_poll_blend_apply` (P: 1.6), `leader_seat_apply`, `education_residual_apply`, `demographic_residual_apply`, `departed_fed_apply` |
| 7 | 451-519 | candidate returns, defector discounts | 3.9 | 7.3 | yes: BYELEC_DEPARTED BYELECTION_MP BYELECTION_PRIOR DEFECT_BY_LEVEL DEFECT_POOLED DEFECTOR_STATE TIME_FORWARD_FITS | `candidate_returns` (P: 4.2), `fit_defector_discount` (P: 4.7) |
| 8 | 519-550 | dispersion, conditional slopes, minor-defector discount | 3.1 | 5.8 | yes: DEFECT_*, DISPERSION_SLOPE, TIME_FORWARD_FITS | `fit_minor_defector_discount` (P: 1.6), `fit_conditional_slopes`, `fit_dispersion_slopes` |
| 9 | 14-15 | `devtools::load_all()` + published defaults | 3.0 | 5.6 | no (sets the switches) | `load_all`, `harness_defaults.R` |
| 10 | 5.2-7.5 | statewide forecast (`forecast_statewide_or_oracle`) | 2.3 | 4.3 | yes: LEVEL_RECENT(+HALFLIFE) LEVEL_RECIPE FUND_* BUCKET_* ANCHOR_* OTHERS_SCALE FORECAST_MODE TIME_FORWARD_FITS | this is the stage a level arm exists to change |
| 11 | 310-350 | first preferences, notional prior, flow pooling, flow matrix | 2.1 | 3.9 | mostly no: STATE_NOTIONAL WA_DROP_3C WA_DROP_LNP | `state_notional_prior`, `pool_configured_flows`, `build_flow_matrix` (P: 1.3), `byelection_table` |
| 12 | (main sim) | `simulate_seat_contests` at 1,000 sims | 1.8 | 3.3 | yes: SIM_ENGINE (plus all inputs it is handed) | C++ core |
| 13 | 596-632 | screened slopes, permits | 1.1 | 2.0 | yes: BYELECTION_MP BYELECTION_PRIOR (via `salience_permit_for`) | `screened_slopes`, `conditional_slopes` |
| 14 | 758-763 | new-independent shrink, typical, base-stage person apply | 1.3 | 2.4 | yes: NEW_IND_SHRINK(_CAP) IND_TYPICAL(_STAT) TIME_FORWARD_FITS | `new_ind_shrink_apply`, `ind_typical_apply` |
| 15 | other | everything else (winners, reentry, base pred, zeroing late, scoring, write) | ~0.8 | 1.5 | various | |

The arm-run differs from the baseline in row 1 only (+49 s); every other section was within 0.5-1.0 s of the baseline
(its own noise, plus the 0.2 s `LEVEL_RECENT` effect in the statewide stage).

## 4. Function-level shares (from the profiled run 1, which is cold and about 2x inflated)

These come from `Rprof` on run 1 (71.6 s of R samples out of a 111.8 s wall; cache cold, profiling overhead doubles
wall). Use them as shares of where the cold run's R time goes, not as seconds. Cumulative R-sampled seconds, lower
levels are inside higher ones:

| function | sampled s | share of 71.6 |
|---|---|---|
| `ind_person_apply` (everything under it is the cross-seat fit) | 38.2 | 53% |
| `fit_cross_seat_carry` | 30.4 | 42% |
| `.cs_match` / `byelection_winner_rows` (inside the fit) | 11.3 / 10.7 | 16% / 15% |
| `.cs_prep` | 6.4 | 9% |
| `personal_prior_vote` | 6.1 | 8.5% |
| `byelection_table` | 5.2 | 7% |
| `fit_defector_discount` | 4.7 | 6.6% |
| `xgb_flow_conditional_override_for` | 4.5 | 6.3% |
| `elections_before`, `classify_party` (called from many places) | 4.3, 4.1 | 6% each |
| `fit_major_departed_slope` | 4.2 | 5.9% |
| `candidate_returns` | 4.2 | 5.8% |
| `surge_hazard_for` | 3.4 | 4.7% |
| `simulate_seat_contests` | 1.1 | 1.5% |

## 5. What would most cut screen time

Marked as inferred where I did not run it. The single biggest item is the cross-seat fit cache key: the fit costs
about 49 s of a 106 s arm run (46%), is rerun for every arm election although the fit appears to depend only on the
corpus, the by-election files and three switches (static read, inferred), and is thrown away because `.cs_fingerprint()`
hashes all `AUSPOL_*` variables. Keying it on only the switches it reads (verify by running one election with the
narrowed key and checking the cached result is byte-identical to a cold run with the arm switch set, for an arm that does
and one that does not touch `BYELECTION_*`/`TIME_FORWARD_FITS`) would take an arm run from ~106 s to ~54 s, about a 2x
screen speed-up on the arm side with no change to results; it also makes the baseline cache reusable by a differently
switched run. The next layer, once that is done, is that sections 2-8 in the table (about 30 s of the 54 s) are fits
that mostly do not depend on the level-type switches, but each reads a different subset of `BYELEC*`, `DEFECT*`,
`TIME_FORWARD_FITS`; the same switch-aware caching (the house pattern in `R/seat_poll_blend.R`) could shrink the warm run
toward the 3 s of setup plus the statewide stage plus 2 s of simulation for a pure-level arm. Fewer simulations help very
little: simulation is 1.8 s. Load time (3.0 s) is paid in every run and could be shared by running several elections
in one process (inferred; not tested).

## 6. Caveats

- One pair on one harness; fed and WA harnesses (~100 s and ~45 s at 1,000 sims by the plan's figures) were not run.
- Stage seconds are single timer deltas (n=2 warm runs, 0.1 s apart), not repeated profiles; sub-second rows are rounded.
- "Arm-dependent" columns are a static name search through the call graph (`codetools::findGlobals`), so they list
  switches a function can read, not switches that changed its output in this run. Only the cross-seat row was
  confirmed by measurement (run 4 against run 5).
- Run 3 was cold for an unintended reason (an env var set to empty); it is kept as further evidence that any extra
  `AUSPOL_*` variable changes the key. I deleted one cached file (`f44bcdc00421822b.rds`) from the scratch root's
  cross-seat cache by mistake; it is only scratch cache and regenerates.
- Some per-stage timers sit inside `if` branches of the harness (for example `FLOW_UNC`); only the paths taken by
  the shipped configuration were timed.
