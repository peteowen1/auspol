# Every hard-coded number in the model

The standing rule for this project: **an assumption should be estimated from
data so it moves when the evidence moves.** A number frozen in a file cannot
respond to a new election, and nothing fails when it goes stale — which is how
`2026,vic,ONP FP,25.5` came to sit in the published forecast for months. See
`docs/reviews/onp-preference-flows-2026-08-15.md` for how that one ended.

This file is the complete inventory. Every constant in `R/` and `scripts/` is
listed, with what it does, whether it *can* be derived from data, and its
status. **A constant that is not in this file is a bug in this file.**

Status key: **ESTIMATED** — derived from data, moves as data arrives ·
**ESTIMABLE** — could be, currently is not · **FIXED** — cannot or should not
be estimated, with the reason given.

Last audited 2026-08-21 (line citations re-checked and new rows added 2026-10-19, see "Added 2026-10-19" at the end); two rows added 2026-09-06 (below, "Added 2026-09-06") after a documentation review found them missing.

---

## 1. Model priors — the ones that matter

These enter the posterior directly. Getting one wrong changes the published
number without anything failing.

| Constant | Where | What it is | Status |
|---|---|---|---|
| `sigma_obs` | `trend.R` | Poll observation noise | **ESTIMATED** — `estimate_trend_sigmas()`, exact log marginal likelihood |
| `sigma_rw` | `trend.R` | Daily random-walk step | **ESTIMATED** — same |
| per-cycle sigmas | `hyperpars.R` | Volatility for one cycle | **ESTIMATED** — `estimate_cycle_sigmas()`, shrunk to pooled |
| firm noise factors | `hyperpars.R` | Per-pollster noise | **ESTIMATED** — `estimate_firm_factors()` |
| preference flows | `flow_model.R` | Where minor-party preferences go | **ESTIMATED** — mean of last 5 observed, method chosen by backtest (check `G3`) |
| scale (logit/points) | `trend.R` | Which scale each party is fitted on | **ESTIMATED** — per party by comparable log evidence |
| trend/fundamentals mix | `projection.R` | Weight by horizon | **ESTIMATED** — backtests: earlier elections only since v51 (`projection_mix_tf()`); live: all past elections |
| ridge penalty | `fundamentals.R` | Fundamentals shrinkage | **ESTIMATED** — leave-one-election-out within the elections before the target (`fundamentals_tf()`, v51) |
| `szc_sd_pts` | `trend.R` | Strength of the soft sum-to-zero constraint on house effects — how far the polling industry as a *whole* may sit from the truth | **ESTIMATED 2026-08-16 — now 1.5.** Chosen by held-out error over a pre-registered grid (`scripts/tune_szc.R`, check `G4`). See §6. |
| `sigma_house_pts = 3` | `trend.R`, `hyperpars.R` | Prior sd on a single pollster's house effect | **TESTED 2026-08-16, KEPT.** Held-out error over a pre-registered grid is a smooth U with its minimum at exactly 3 (`scripts/tune_sigma_house.R`, check `G5`). See §6b. |
| `SEAT_POLL_TOTAL_TOL` | `seat_poll_blend.R` (`SEAT_POLL_TOTAL_TOL`) | 5 points: a poll whose primaries sum to 100 +/- 5 without a duplicated Nat figure, and above 105 with it, has the Nat figure dropped as a merged-cell copy (`AUSPOL_SEAT_POLL_COALITION_DEDUP`, shipped 2026-10-07). | **CHOSEN**: Wikipedia primaries are rounded to whole points, so complete polls sum to 97-103; the one case (fed2022 Nicholls) is 141 vs 100. Not estimable: there is one duplicate in 1,210 polls. |
| `SEAT_POLL_IND_MAP_MIN_OTH` | `seat_poll_blend.R` | 10 points: a poll's OTH figure at least this big, with IND blank and an IND candidate in the seat, is read as the independent (`AUSPOL_SEAT_POLL_IND_MAP`, off). | **CHOSEN** from the fed2022 YouGov table (genuine catch-all OTH 2-8; teals 17-24). Misses Bradfield (5) and Calare (11, excluded by the next constant). Could be estimated once more than one MRP house leaves IND blank. PREREG PENDING. |
| `SEAT_POLL_IND_MAP_KNOWN_FRAC` | `seat_poll_blend.R` | 0.5: skip the remap when one of our OTH/OTH_RIGHT/ONP as-at predictions is at least this fraction of the poll's OTH figure (Katter in Kennedy). | **CHOSEN** by hand so Kennedy and Bass skip while Goldstein and Mackellar remap; as-at predictions only. Not fitted. PREREG PENDING. |
| `PUBLIC_SEAT_POLLSTERS` | `seat_poll_blend.R` | Pollsters whose direct seat polls count as independent under `AUSPOL_SEAT_POLL_SOURCES="public"` | **CHOSEN BY PETE 2026-09-29** (allowlist over a sponsor-only filter); being tested, `plans/prereg-seat-poll-public-only-2026-09-29.md`. Not estimable: it is a definition. |
| `AUSPOL_SEAT_POLL_PRIOR` | `seat_poll_blend.R` (`.seat_poll_prior()`) | Prior mean for the seat-poll blend weight. **0.75 is shipped** (`scripts/published_flags.R` `AUSPOL_SEAT_POLL_PRIOR = "0.75"`; code fallback in `.seat_poll_prior()`, `R/seat_poll_blend.R`, also 0.75); "0" would shrink the fitted weight toward 0, so an election with no earlier polled cells blends nothing (fed2016, fed2019). | **CHOSEN BY PETE 2026-10-09**, knowingly hindsight-informed (fed2022's fitted weight was 0.751). SHIPPED 2026-10-09 (PR #110). Combined by precision with the time-forward slope, so it fades as polled elections accumulate (vic2026: 0.373 -> 0.394). Not fitted. Corrected 2026-10-19: this row said shipped "0" (nightly audit, issue #109). |
| `AUSPOL_SEAT_POLL_PRIOR_SD` | `seat_poll_blend.R` (`.seat_poll_prior()`) | 0.25: sd of that prior ("weak"). One earlier election at se 0.35 moves the weight about a third of the way to its own slope. | **CHOSEN** (2026-10-09) to make Pete's "weak prior" a number. ESTIMABLE in principle from the spread of per-election slopes once more polled elections exist (six now). |
| `SEAT_POLL_HALFLIFE_PRIOR` | `seat_poll_blend.R` (`SEAT_POLL_HALFLIFE_PRIOR`) | 60 days: prior half-life of a seat poll's recency weight under `AUSPOL_SEAT_POLL_DECAY` (replaces the 90-day hard window). | **CHOSEN BY PETE 2026-10-09** as a prior; the half-life itself is **ESTIMATED** time-forward (`seat_poll_decay_params()`, SPD line): fed2025 54 days, sa2026/vic2026 34. |
| `SEAT_POLL_HALFLIFE_LOGSD` | `seat_poll_blend.R` (`SEAT_POLL_HALFLIFE_LOGSD`) | 0.7: prior sd of log(half-life); 2-sd range 15-245 days. | **CHOSEN** (2026-10-09) to make the prior weak. |
| poll-match window | `poll_source.R` (`poll_layer(window = 4L)`, `.ps_merge_own()`) | 4 days: two rows of one firm whose fieldwork midpoints are this close may be the same poll (closest midpoint, then closest numbers, wins). | **CHOSEN** 2026-10-12 (own-poll-source prereg): weekly pollsters publish 7 days apart. Not estimated. Added to this file 2026-10-13 (missing since the ship). |
| same-poll far window | `poll_source.R` (`.ps_same_poll_far()`) | 31 days, primaries within 0.5 point: one firm's rows with the same Labor, Coalition (and Greens / One Nation where both report) figures are one poll dated differently. | **CHOSEN** 2026-10-13 after Resolve's two-month Victorian polls sat 14-29 days apart across sources (counted twice). Two real polls of one firm with identical primaries inside 31 days merge into one: accepted cost. |
| Poll Bludger confirm window | `poll_source.R` (`.ps_pb_confirm()`) | post 1 day before to 45 days after the poll's midpoint, every major party within 2 points: a post confirms an AE-only poll and its numbers replace AE's. | **CHOSEN** 2026-10-13: Newspoll's state polls pool two or three months, so the post comes long after the midpoint; 2 points matches the dispute threshold below. Measured: 232 rows switch, 6 disagree. |
| dispute threshold | `poll_source.R` (`poll_layer()`) | 2 points on any major party: our row and AE's disagree; the one fitting the poll's own two-party figure by at least 1 point more wins. | **CHOSEN** 2026-10-12 (prereg Amendment 1). |
| implied two-party weights | `poll_source.R` (`.ps_implied()`) | ALP + 0.83 GRN + 0.35 ONP + 0.45 rest: rough national flows used only to tell two copies of one poll apart, never a forecast input. | **CHOSEN** from typical federal flows; the per-election fitted flows exist (`flows_for()`) but are not needed to separate a swapped row. |
| self-check limits | `poll_source.R` (`wiki_polls()`, `bludgertrack_polls()`) | swap back when e_swapped < 1.5 and e_as_read > 5 with One Nation < 10; "suspect" when e_as_read > 5. | **CHOSEN** 2026-10-12 from the RedBridge Vic (ON 24) false swap. |
| `SEAT_POLL_FLOOR_PRIOR` | `seat_poll_blend.R` (`SEAT_POLL_FLOOR_PRIOR`) | 16 points^2 (sd 4): non-sampling error variance of a seat poll before any data. | **CHOSEN**; the floors per group (mrp/direct/sponsored) are **ESTIMATED** time-forward and shrunk toward it (vic2026: 5.4 / 5.1 / 6.5 sd). |
| `SEAT_POLL_FLOOR_K` | `seat_poll_blend.R` (`SEAT_POLL_FLOOR_K`) | 10 pseudo seat-elections pulling each group's floor toward the pooled floor. | **CHOSEN** (2026-10-09). ESTIMABLE as a between-group variance once groups are larger. |
| `SEAT_POLL_N_FALLBACK` | `seat_poll_blend.R` (`SEAT_POLL_N_FALLBACK`) | 600: seat sample size for a direct poll with none recorded, only when no earlier direct poll records one (otherwise the earlier median, ~750-800). | **CHOSEN**; overridden by data from fed2019 on. |
| `SEAT_POLL_MODEL_VAR_PRIOR` | `seat_poll_blend.R` (`SEAT_POLL_MODEL_VAR_PRIOR`) | 25 points^2 (sd 5): our seat primary error before any polled election, for `AUSPOL_SEAT_POLL_PRECISION_BLEND`. | **CHOSEN** from the AEF-7 ledger's primary RMSE (5.13); per-class values are **ESTIMATED** time-forward and shrunk toward it (`seat_poll_model_var()`). |
| `AUSPOL_LEVEL_CONSERVE_LAMBDA` | `level_conserve.R` | 1: strength of `AUSPOL_LEVEL_CONSERVE` (shares = (1 - lambda) current + lambda raked). | **CHOSEN** by the pre-registration (plans/prereg-level-conserve-2026-10-25.md): 1 primary, 0.5 sensitivity. ESTIMABLE time-forward as the least-squares coefficient of actual-minus-current implied share on raked-minus-current, over earlier elections (the prereg's fitted sensitivity, computed from the `LCV1` log lines; not built as a switch). |
| `AUSPOL_LEVEL_CONSERVE_HOLD` | `level_conserve.R` | `""`: classes held out of `AUSPOL_LEVEL_CONSERVE`'s rake (arm: `IND`). | **CHOSEN** by Amendment 1 of the prereg (2026-10-29, Pete), from one traced failure (fed2022 teal seats). A class list, not a number; which classes the level model cannot see is ESTIMABLE time-forward as each class's level miss against its seats' implied share over earlier elections, not built. |
| IND gap-restand slope | `ind_gap_restand.R`, `dev_slope.R` (`screened_slopes()`, `conditional_slopes()`) | 0: the slope on the IND class's old seat gap where none of the class's earlier candidates re-stands, under `AUSPOL_IND_GAP_RESTAND=1` (the cell starts from the statewide IND level). | **CHOSEN** (Pete approved the rule 2026-10-25; plans/prereg-ind-gap-restand-2026-10-25.md). ESTIMABLE time-forward as the no-intercept slope of the next deviation on the old deviation over earlier elections' no-re-stander IND cells (the walk measured realised retention about 0 for Pascoe Vale; `departed-leader-retention-2026-09-15.md` measured 0.38 over all departed leaders, a superset). |
| hybrid swing logit clamp | `R/dev_slope.R` (`dev_slope()`, `form = "hybrid"`) | shares clamped to [0.01, 99.99] points before the logit, under `AUSPOL_SWING_FORM=hybrid` | **CHOSEN**, a numerical guard so the logit is finite at 0 and 100; a cell whose shrunk value is 0 or below is returned as exactly 0, as the points form does. Not a model constant: no forecast cell sits within 0.01 of either bound by design (plans/prereg-swing-form-hybrid-2026-10-30.md). |
| rake tolerances | `level_conserve.R` (`level_conserve_rake()`) | converge at worst class gap < 1e-8 points, at most 10,000 sweeps; REFUSE (stop) if the gap is still > 0.01 points. | **NUMERICAL**, not a model constant: a feasible problem converges far inside 1e-8; 0.01 is the prereg's own stopping tolerance, kept as the refusal bar. |
| level-conserve seat weights | `level_conserve.R` (`level_conserve_weights()`) | formal votes per seat at the previous election (`output/candidacies.csv`); an unmatched seat gets the median. | **CHOSEN** by the pre-registration (knowable before polling day). |
| `POLL_RECORD_HALFLIFE` | `poll_record.R` | 30 days: a past poll's weight in its firm's track record halves every 30 days before that election's polling day (statewide arm `weights = "record"`). | **CHOSEN** (2026-10-09) so final-month polls dominate a firm's record without a hard cut-off. ESTIMABLE by the same held-out score. |
| `POLL_RECORD_K` | `poll_record.R` | 12 pseudo-polls pulling a firm's track record to the pooled record. | **CHOSEN** to match `estimate_firm_factors()`'s `k0 = 12`. |
| `k0 = 25` | `hyperpars.R` | Shrinkage of per-cycle sigmas toward pooled | **CANNOT BE TUNED ON FORECAST ERROR — it does not reach the forecast.** See §6c. |
| `FP_EXTRA_SD = 2.419` | `fit_seats_full.R:163` via `fp_extra_sd_env()` (`R/forecast_statewide.R:466`); a switch (`AUSPOL_FP_EXTRA_SD`) since 2026-10-19 | Statewide first-preference error the trend posterior does not contain, added in quadrature | **ESTIMATED, ADOPTED 2026-08-19.** Coverage of the raw band is 69.8% at a nominal 95%; the structure (additive in points, not multiplicative) was chosen by testing alternatives against the residuals, and the value is the two-party projection error pre-registered in `prereg-fp-widening-choice.md`. See `reviews/fp-widening-choice-2026-08-19.md`. |
| `SEED = 42` | `fit_seats_full.R:168` | Simulation seed | **FIXED.** Overridable via `AUSPOL_SEED` only so a change can be checked for stability across seeds. |
| `k0 = 12` | `hyperpars.R` | Shrinkage of firm noise factors | **Affects the published scorecard, not the forecast.** See §6c. |
| `clip = c(0.6, 2.0)` | `hyperpars.R` | Bounds on a firm's noise multiplier | **Affects the published scorecard, not the forecast.** See §6c. |

## 2. Reference sample sizes

| Constant | Where | What it is | Status |
|---|---|---|---|
| `SEAT_SWING_COEF = c(fed = 0.7452)` | `seat_swing.R` | How far a seat departs from the statewide swing | **RE-VALIDATED AND CUT 2026-08-20.** Was four terms; re-validation on five elections and 629 seats found `retirement`, `soph_cand` and `soph_party` worth **-0.0008** pooled against uniform swing, and `fed_swing` alone beats all four on held-out MAE (3.3655 vs 3.4249). See `reviews/seat-swing-revalidation-2026-08-20.md`. `fed_swing` itself is still validated on two elections only. |
| `POLL_TRACKING_BOUND = 2.5` | `poll_tracking.R` | Maximum permitted |fitted endpoint − mean of the final 90 days of polls|, asserted by `L3`/`FL3`/`NL3` | **ESTIMATED from data.** The 99th percentile of that quantity over 154 party-cycles with complete actuals, rounded up to 0.5 (percentile 2.429), by `scripts/calibrate_poll_tracking.R`. Calibrated on the same model path the checks assert on — per-cycle sigmas and firm factors — after review caught the first derivation using `trend_as_at()` defaults (percentile 2.478 over 138 rows; the bound was 2.5 either way). The *rule* was committed in `plans/prereg-per-party-poll-check.md` before the number was computed, with a refusal condition above 5.0. Replaced a `sum = 100 ± 5` check the model does not promise. |
| `window = 90`, `min_polls = 3` | `poll_tracking.R` | The poll window `POLL_TRACKING_BOUND` is measured over, and the floor below which a party is reported but not asserted on | **FIXED.** 90 days matches the window already used in `test_others_bias.R` rather than being tuned here. The floor exists so a party with no recent polls cannot pass vacuously — `NA > bound` is `NA`. |
| `BINOMIAL_REF_N = 2500` | `scales.R` | Sample size for the binomial noise floor, wherever it **halts a run or makes a published claim about a named firm** (`H1`, `L4b`/`FL4b`/`NL4b`, the scorecard's *Variability*) | **FIXED — cannot be estimated**, no sample-size column exists. Deliberately the *largest* common sample: smallest binomial sd, weakest floor, so it under-calls herding rather than over-calling it. |
| `BINOMIAL_SENSITIVE_N = 1500` | `scales.R` | The same floor where it only **reports** a signal (`ratio_sens` in the fit scripts) | **FIXED, deliberately different.** Smaller sample means a higher floor and a more sensitive test — right for "look here", wrong for "stop the run". Resolved 2026-08-16: this was previously mistaken for drift, and the real defect was the scorecard using the sensitive value for a published claim about named companies. |

## 3. Data-quality thresholds

Operational guards on input parsing, not model inputs. They decide whether to
trust a file, not what the forecast says.

| Constant | Where | What it guards |
|---|---|---|
| `sum_range = c(97, 103)` | `fold.R:40` | First preferences summing near 100 → a party was folded into OTH |
| `95`–`105` | `load_polls.R:107` | Sanity bound on reported FP sums |
| `> 0.02` | `load_polls.R:112` | Share of malformed rows tolerated before erroring |
| `n > 100`, `< 60`, `< 380` | `load_polls.R:144` (`< 60`), `fundamentals.R:108` (`< 380`); the `n > 100` floor was not found in `load_polls.R` on 2026-10-19 (unverified) | Row-count floors that catch `fread` stopping early on a ragged row — the bug that once trained the fundamentals on 62% of the data |
| `min_year = 1990` | several | Start of the modern polling record |
| `min_polls`, `min_firm_polls` | several | Minimum data before fitting |
| `PARTY_INCLUSION_FLOOR = 8` (`scales.R`) | `fit_vic.R:184,196`, `fit_nsw.R:105,234,290,303` (checked against the code 2026-10-25; the earlier `200,256,269` were stale line numbers, not other uses); federal does NOT use this constant: it has its own hardcoded `>= 25` (`fit_federal.R:57,138,223`) | **Which parties exist in the forecast at all** — not an input-sanity guard, which is how it was filed until 2026-08-19 and why nobody looked at it. A party under the floor is not fitted, so its vote stays inside `OTH`. Lowering it is monotonically worse (tested 2026-08-19). **Tried at 15, reverted, both 2026-08-24** (`plans/prereg-inclusion-floor-15-adoption.md`): floor 15 beats 8 by 0.061 MAE, three times the adoption bar, but folds One Nation from NSW 2027 (21.0% on 8 polls) into `OTH`, where a party polling in the twenties cannot be told apart from the rest. Adopted first with that cost disclosed (Victoria 2026, the only published forecast, is unaffected — verified byte-identical), then reverted: a live-cycle party going invisible is not acceptable even in an unpublished cycle. `scripts/test_inclusion_floor.R`'s anchor check (`IF6`) is what surfaced this, unweakened, and stays wired in for any future attempt. Extracted into a single named constant regardless of the reverted value, replacing four independent hardcoded `8`s this file had already flagged as a sister-copy risk. `fit_vic.R:115` AND `fit_nsw.R:116` each carry a separate `parties_in(n = 8)` default (validation-cycle noise-factor estimation, not the live party set) — a distinct constant, currently at the same value by coincidence rather than by the same name. **Two more hardcoded thresholds sit beside it and are NOT this constant** (listed 2026-10-25 so they are not mistaken for it): the estimation floor `counts >= 20` (`fit_vic.R:84`; `fit_nsw.R:66` as `.est_floor`, env `AUSPOL_NSW_EST_FLOOR`, default 20) and the per-cycle walk fit `cnt >= 15` (`walk_of()` at `fit_vic.R:157`, `fit_nsw.R:198`), a party needs 15 polls in the cycle to get its own fitted random walk. Neither is in this file as its own row. |
| `warn_days = 21`, `stale_days = 60` | `freshness.R:63` | When poll data is old enough to warn, then stop -- but only when OUR COPY is old; a region whose pollsters published nothing new warns (PFQ1!) and carries on (since 2026-11-01, after NSW's 60 quiet days halted the Victorian forecast) |
| `SHARE_CLAMP = c(0.25, 99.75)` | `scales.R:19` | Keeps logit finite at the boundary |
| `EXHAUST_LIMIT = 0.02` | `fetch_preferences_wa.R` | Exhaustion rate above which an election's transfers may not be pooled with full-preferential ones. NSW runs ~12% and is excluded outright; the seven admitted WA elections run 0.15–0.88%. **FIXED, and deliberately not raised**: WA 2001 measured 2.27% and was named in `TRANSFERS_EXCLUDED` instead, because moving a threshold to admit the one election that failed it is choosing the number after seeing the answer. |
| `TRANSFERS_EXCLUDED = "wa2001"` | `fetch_preferences_wa.R` | The named consequence of the line above. Its first preferences and winners are still used — exhaustion cannot affect either. |
| `WA_PARTY` (39 codes; counted 2026-10-25) | `R/wa_party.R:17` (one copy; read by `fetch_preferences_wa.R` and `build_candidacies.R`) | Party code → name, because the WAEC publishes a code and no name and a bare code classifies as OTH. **FIXED, and machine-checked**: WF1c requires every name to be one the WAEC itself publishes, WF5 requires our winners to reproduce its declared seat counts, and an unknown code aborts. |
| `EXTERNAL_FLOWS$*$dates` (10 dates: Queensland 2, Western Australia 7, South Australia 1 -- `sa2026` added after this row said 9) | `R/external_flows.R:15` | Polling days for the Queensland, Western Australian and South Australian elections, deciding what a backtest may see. **FIXED and hand-entered** — neither commission publishes a machine-readable polling day with its results — so each is checked against the year in its own election key, which catches the mistyped year that hand-entered tables actually suffer. |
| `88` seat floor | `fit_seats_full.R` (SUP1 block) | The number of Victorian seats that must reach the simulation: all 88 districts since 2026-09-19, Narracan via its January 2023 supplementary election (its 2022 poll was deferred by a candidate's death); `build_page.R` asserts the same 88. **FIXED**, and it is a floor rather than a printed number because the count used to reach the simulation only as a `cat()` line — a lost seat would have printed a different, equally plausible figure. |
| `vic2026 = "2026-11-28"` | `R/election_dates.R` (`election_dates()`) | The Victorian polling day (moved out of fit_seats_full.R's former `VIC_2026`; every election's date now lives in `election_dates()`). **FIXED**: it is a legislated date, not an estimate. |

These are **FIXED by intent.** They encode "does this input look like what we
expect", and a threshold estimated from the same data it is meant to police
would move to accommodate corruption — the guard-that-passes-wrongly failure
this codebase has hit five times.

## 4. Computation and presentation

**FIXED**, no modelling content: `n_sims` (20000/50000 simulation draws),
`w_grid`/`lambdas` (search grids, resolution not assumption), optimiser bounds
and starts in `optim_boxed`, `window = 30` (days counted as "final poll"),
`horizons = c(30, 90, 180, 365, 730)`, plot colours and alphas, the 180-day
leader-caveat window, and `G3`'s 0.15 MAE tolerance.

Two of these are closer to judgement than the rest and are worth revisiting if
they ever look load-bearing: `window = 30` decides which poll counts as a
firm's last, and the `G3` tolerance decides how far the adopted estimator may
fall behind before someone is told.

`AUSPOL_SPREAD_RERUN_TOL` = 0.02 (`scripts/compare_spread_tables.R`, added
2026-10-14) is **CHOSEN**: how far any scored target's seat-size widening
factor (at 2k/5k/10k/20k formal votes) may move between the table stage 6 read
and stage 7's refit before `rebuild_forecasts.sh` reruns stages 6-7. A 2%
change in a seat's sd is well inside simulation noise on a seat probability;
the cost of a lower bound is a 57-minute rerun, not accuracy.

## 4b. The candidate-level seat path (added 2026-08-18)

These live in `scripts/fit_seats_full.R` and the three functions it calls. The
path does not feed the published page, but the rule applies the same: a
constant absent from this file is a bug in this file.

| constant | value | where | status |
|---|---:|---|---|
| `SMOOTH` | 0.15 | `distribute_preferences()` | **FIXED, and load-bearing** |
| `min_n` | 3 | `build_flow_matrix()` (`R/flow_matrix.R:42`, the argument default `min_n = 3L`) | **FIXED** — judgement |
| `SEAT_SD` | 3.5 | `fit_seats_full.R` | **ESTIMATED** |
| `ONP_B1 = -0.0968` | `fit_seats_full.R` | Greens-share coefficient for the One Nation ordering | **RETIRED 2026-08-20 as the ordering rule.** On NSW 2023 it reached Spearman +0.331 against the actual One Nation ordering and MAE 3.287 -- *worse* than a uniform allocation's 2.595. Replaced by each district's transposed federal One Nation vote (+0.814, MAE 1.594). See `reviews/onp-allocation-federal-2026-08-20.md`. |
| `ONP_CAP = 80` | `fit_seats_full.R` | Ceiling on any district's One Nation share | **SANITY BOUND, not a modelling choice.** Inert on real data (the maximum allocation is 33.0). It exists so a future statewide forecast times the largest quantile ratio cannot exceed 100 and drive the fill negative. |
| One Nation spread (`AUSPOL_ONP_CV`) | SA 2026 observed, partially pooled | `fit_seats_full.R` | **ESTIMATED, ADOPTED 2026-09-09 at CV 0.365** — see below and `reviews/onp-concentration-validated-2026-09-09.md` |
| per-party statewide sd | from the trend | `fit_seats_full.R` | **ESTIMATED** |
| `N_SIMS` | 20000 | `fit_seats_full.R` | FIXED, no modelling content |
| S5 median-gap bound | 5 seats | `fit_seats_full.R` | **FIXED** — pre-registered |
| S5 width-ratio bounds | 0.7 – 1.4 | `fit_seats_full.R` | **FIXED** — pre-registered |
| `PREV_TPP` (Victoria 2022) | 55.00 | `fit_seats.R` (the retired two-party path; `fit_seats_full.R` no longer has it) | **FIXED** — a recorded result |
| 2018/2014 Victorian TPP | 57.60 / 51.99 | `fit_seats_full.R`, `fit_seats.R` | **FIXED** — recorded results |

**S5's two bounds are pre-registered check bounds** and belong to the family in
§5: assertions written before the result was seen, so estimating them from the
results they police would make them unfailable. They were chosen against a
known-bad case — the pre-anchoring run had a width ratio of 0.57 and must fail,
the corrected one 0.96 and must pass — and verified to do both.

**The three Victorian two-party figures are recorded election results**, not
assumptions: 55.00 in 2022, 57.60 in 2018, 51.99 in 2014. They cannot be
estimated because they already happened. They appear in two scripts, which is
duplication worth removing if a third ever wants them.

**`SMOOTH` is not presentation.** A flow row carries 0% for a destination that
never co-occurred in the source data; renormalising that row over the survivors
hands them the entire transfer. At `SMOOTH = 0` One Nation wins Richmond. It
mixes every row with a uniform over the survivors so absence of evidence is not
read as certainty. It is **FIXED rather than estimated because there is nothing
to estimate it against** — the quantity it guards is precisely the one never
observed. Its own test asserts that a wide enough value flips the winner, so it
cannot silently become inert.

**`min_n = 3`** decides when a survivor-conditional rate is trusted over the
pooled one. Judgement, not measurement: below it a rate can rest on a single
seat. Cells below the bar are still reported in `coverage`, so what was
withheld is visible.

**`SEAT_SD = 3.5`** is the within-region seat deviation from
`seat_swing_spread()`, the same figure the two-party seat model uses.

**`ONP_B1 = −0.0968`** orders seats by Greens share, fitted on the 38 Victorian
federal 2025 divisions by leave-one-division-out over five pre-named forms.
Checked on 2026-08-18: the coefficient is negative in NSW, Queensland and WA
too, so the relationship replicates. **It beats a uniform allocation by only
0.122 MAE** — real and small. Trust the One Nation *total*, not any one seat.

**The One Nation spread** is taken from SA 2026's observed relative
distribution, measured at 22.97% statewide against Victoria's forecast 20.9%.
Estimated, but from a different state, because Victoria has never had a large
One Nation vote to measure its own. Checked within 1.41× against a 1.5 bar.
See `docs/plans/prereg-onp-allocation-vic.md`.

**Updated 2026-09-09 — the CONCENTRATION (not the ordering) is now partially
pooled, not SA's raw shape.** `docs/reviews/onp-concentration-validated-
2026-09-09.md` found two things: SA 2026 cannot test this allocation
out-of-sample (it IS the training data — the earlier claim that it could was
struck), and the concentration question is answerable across the whole
corpus. Fitted on 49 (election, party) observations restricted to parties
contesting ≥90% of seats, concentration is roughly **constant with level**
(CV ∝ level^-0.128, not the level^-1 one candidate assumption implied), giving
a corpus-typical CV of **0.479** at Victoria's ~21% forecast level against
SA's own **0.346** — SA sits 1.4 residual sd low, not wrong, just imprecise
on its own (R² 0.063, n=49).

**Partially pooling SA's precise 47-seat observation (log-se 0.104) against
that noisy corpus relationship (scatter 0.229 in logs, weight 0.83 on SA's
own value) gives CV = 0.365.** `AUSPOL_ONP_CV` is set to this, replacing the
unset default that used SA's raw shape (delivered CV 0.327).

**Measured seat effect, all else held fixed:**

| `AUSPOL_ONP_CV` | ONP median seats | 90% range |
|---|--:|---|
| 0.327 (SA's raw shape, shipped until 2026-09-09) | 9 | 3–18 |
| **0.365 (partially pooled, now shipped)** | **10** | **4–20** |
| 0.48 (corpus-typical — NOT adopted, discards SA's own precise observation) | 14 | 6–24 |

Pete's call, 2026-09-09: publish the uncertainty rather than a bare point —
this row's status line and the seat range above are the record of that, and
`AUSPOL_ONP_CV=0.365` is now a **published default** in
`scripts/published_flags.R`, not a diagnostic override.

## 4c. Missing until 2026-08-21, and why that matters

Found by a sweep of `R/` and `scripts/` against this file, prompted by the
inventory's own rule. **Two of these reach the published seat counts and one
was added the same morning the file was stamped "audited"** -- the audit line
and the code diverged inside a single day, which is precisely the silent
staleness this file exists to prevent. That is the finding, more than any
individual number below.

| Constant | Where | What it does | Status |
|---|---|---|---|
| `SHRINK = 0.01` | `fit_seats_full.R` (`SHRINK`, `AUSPOL_SHRINK`) | Per-draw calibration shrink toward a coin toss in close seats. Added 2026-08-21 at 0.10; **lowered to 0.02 on 2026-09-06**. A scalar shrink caps every seat at `1 - shrink/2`, so 0.10 meant no seat could be called above 0.95 — measured max p was 0.9505 with 19 of 150 federal seats against that ceiling, costing ~0.006 of mean log loss on the cap alone. Swept on fed2025: 0.10→0.3042, 0.05→0.2933, **0.02→0.2891**, 0.00→0.2914. Three seeds at 0.02 mean 0.2886 against AE Forecasts' 0.3025. Validated election-wide before shipping: federal mean log 0.4154→0.4047 (better in 5 of 6 pairs, Brier in 6 of 6), Victoria 0.3020→0.2997, NSW 0.4062→0.3822, SA 0.3976→0.3857, WA accuracy 87.0%→87.3%. **Lowered again to 0.01 on 2026-09-06**: six federal pairs give mean log loss 0.10=0.4154, 0.02=0.4047, 0.01=0.4096, 0.00=0.4282, and 0.02's edge over 0.01 is one seed and not established as significant while 0.01 has the best mean Brier (0.0982). Stays NON-ZERO because 0.00 costs 0.0235 of mean log loss against 0.02, concentrated in fed2013 (+0.0975) and fed2022 (+0.0243) — a risk invisible on fed2025 alone. Expected to be superseded by the per-seat `AUSPOL_INSURGENCY_SHRINK`. | **ESTIMATED** — swept on held-out log loss, then checked election-wide as a do-no-harm guard. |
| `LAMBDA = 0.5` | `estimate_statewide_cov.R:215` | Shrinks the statewide party-correlation matrix toward independence. Written to `cor_shrunk`, which `R/statewide_cor.R:48` reads for `fit_seats_full.R` when `AUSPOL_PARTY_COR` is on. **Unread at published flags since 2026-10-16** (`AUSPOL_PARTY_COR="off"`, `reviews/party-cor-time-forward-2026-10-16.md`). | **FIXED, pre-registered.** Half weight on a correlation estimated from few cycles; the alternative was to estimate the shrinkage from the same small sample that produced the correlation. |
| `COV_TF_K = 5` | `estimate_statewide_cov.R` (`cov_time_forward()`, `R/statewide_cor.R`) | Pairs at which the time-forward correlation reaches half of LAMBDA: `w_n = LAMBDA * n / (n + K)`. Only read under `AUSPOL_COV_TF=1` (default 0, OFF). For n < 3 the matrix is the identity (the w -> 0 limit). | **CHOSEN**, not fitted: a smooth replacement for a min-pairs cliff. ESTIMABLE by held-out seat log loss across the 22 pairs; not yet done. |
| `1.96` | `trend.R:426-427`, `projection.R:574`, `fit_seats_full.R` (`growth` and `trend_sd`) | The Gaussian 95% quantile, used to build the published bands and to turn a band back into a simulation sd. | **FIXED, and worth flagging**: §6c records that the model deliberately does *not* assume the error distribution is normal, yet this constant assumes it at five sites. A correctness matter, sized before it is worth changing. |
| `SA_RESPONSE` (6 coefficients) | `fit_seats_full.R` (`SA_RESPONSE`, used in the `AUSPOL_FORCE_FP` block) | Where a party's statewide gain or loss comes from, fitted on South Australia 2026. `LNP −0.846, ALP −0.123, IND −0.086, OTH_RIGHT −0.074, GRN 0.063, OTH 0.065`. Reached only under `AUSPOL_FORCE_FP`, so **not on the default publish path**. | **ESTIMATED** from one election, which is its weakness. |
| `ANCHOR_K = 0` | `trend.R:82` | Weight on the previous election result as an anchor for the trend, defaulting `trend_anchor()` and `fit_trend()` — both on the published path. | **FIXED at 0.** Built and refused on a wrong theory; see `reviews/poll-lag-2026-08-19.md`. Same tested-and-kept shape as `sigma_house_pts` in §6b. |
| `AUSPOL_ANCHOR_SD_MULT = "1"` | `trend_anchor()` in `R/trend.R`; `scripts/published_flags.R` | "1" | **ARM, not shipped** (arm ANC, `plans/prereg-poll-lean-2026-11-02.md`): how hard day 0 is pinned to the previous result. A number multiplies the anchor sd, "none" starts from the first poll, "gap:<g>" widens the sd by `sqrt(1 + (gap/g)^2)` with the first-poll distance. Grid {1, 2, 4, none, gap:0.5, gap:1, gap:2}, picked time-forward by `scripts/screen_poll_lean_anc.R`. Vic One Nation 19.52 at "1", 21.42 at "none". |
| `POLL_LEAN_PARTIES` | `R/poll_lean.R` | ALP, LNP, GRN, ONP, OTH | **FIXED** (arm REC, `plans/prereg-poll-lean-2026-11-02.md`): parties a company's lean against results is measured for. Recency weight reuses `POLL_RECORD_HALFLIFE` (30 days); shrinkage is DerSimonian-Laird to zero, no n floor. Not on the published path: REC NOT PASSED 2 Nov (-0.0154, SE 0.0216). |
| `AUSPOL_LEVEL_RECENT_CLS = "ALP,LNP,GRN"` | `lr_classes()` in `R/level_recent.R`; `scripts/published_flags.R` | "ALP,LNP,GRN" | **ARM BLD, NOT PASSED 2 Nov** (`plans/prereg-poll-lean-2026-11-02.md` Amendment 1): classes the recent-poll blend moves. Adding ONP was +0.0690 worse (SE 0.0551, 35 elections). OTH is refused by the code. |
| `1.5` party-sd fallback | `fit_seats_full.R` (`psd`) | Used when a party has no estimated statewide sd. | **FIXED**, and it should be visible when it fires: a fallback nobody sees is a number nobody checks. |
| `0.489` flow fallback | `fit_seats_full.R` (`ll_flow()` and `flow_of()`) | Preference rate used when the matrix has no cell for a pair. | **FIXED**, same caveat. |

Also absent and lower priority, none on the default publish path: `TARGET`,
`TOL`, `N_REP`, `FLOOR_R` in `calibrate_onp_ordering.R:18-21`; `VIC_MEAN = 20.2`
(`compare_onp_seats_sa.R:68`) and the `tgt` vector (`:105`), which are frozen
snapshots of the model's own output and so carry their own staleness risk;
`MATERIAL`/`COVER` in the `compare_*` scripts; `SITTING_CUT = 15` in the two
`fit_independent_*` scripts; `LIVE = 2026` in `fit_vic.R:59`; and the
`nrow(d) < 3L` floor inside `estimate_flow()` (`flow_model.R:137`), which is
distinct from `build_flow_matrix()`'s documented `min_n = 3`.

Deliberately not listed: `CHAMBER = 88`, `MAJORITY = 45` and `PREV_SEATS = 56`
in `fit_seats.R`. That is the retired two-party path — see the top of
`CLAUDE.md` — and inventorying a dead file would imply it is live.

## 5. Pre-registered check bounds

Every `require ...` in `scripts/fit_*.R` — `V2` requires the 2018 endpoint in
33–46, `A1` requires 51–56, and so on. These are **FIXED and must stay so.**
They are assertions written *before* results were seen; estimating them from
the results they police would make them unfalsifiable, which is the entire
point of pre-registering them. They are listed in `ARCHITECTURE.md`, not here.

## 6. Estimated: the sum-to-zero prior, 0.3 -> 1.5

Resolved 2026-08-16 after one false start. Two independent lines of evidence,
and they agree.

### Line 1: what the record says the industry actually does

Consensus of the final polls at every completed election since 1990, against
the result. `OTH` excluded -- its −5.3 average miss is the known
fold-into-Others parsing artefact, not pollster bias.

| Window | n party-elections | sd of miss |
|---|---:|---:|
| final 14 days | 147 | **1.61** |
| final 30 days | 187 | 1.94 |
| final 60 days | 209 | 2.14 |

The spread shrinks as the window narrows, so wider figures partly measure
opinion moving rather than pollsters erring. **About 1.5.** Mean miss +0.09:
the field is not biased in a direction, it misses *together*, in a direction
that varies by election.

### Line 2: held-out error, over a pre-registered grid

`scripts/tune_szc.R`, criterion and grid and decision rule all fixed in
[plans/prereg-szc-v2.md](plans/prereg-szc-v2.md) and committed before running.
Leave-one-election-out, 195 election-horizon pairs:

| `szc_sd_pts` | held-out MAE |
|---:|---:|
| 0.30 (incumbent) | 2.0850 |
| 0.75 | 2.0852 |
| **1.50** | **2.0588** |
| 3.00 | 2.0593 |

**Adopted 1.5**: beats the incumbent by 0.0262, clearing the pre-registered
0.02 materiality bar; both 1.5 and 3.0 qualified and rule 5 takes the smaller.

Two things about the shape matter more than the winner. It is a **step, not a
slope** -- 0.3 and 0.75 are identical to four figures, and so are 1.5 and 3.0
-- so the gain comes from loosening the prior *at all*, not from landing on a
finely-tuned value. And the two lines of evidence were computed from entirely
different quantities and still agree on ~1.5.

**Honest caveat: the gain clears the bar by 0.006.** Had the threshold been
0.03 this would have failed. The rule is satisfied because it was fixed in
advance, but 1.3% on 195 pairs is not decisive.

### Why it matters beyond the number

Forcing house effects to cancel more tightly than reality supports pushes
genuine industry-wide error into the latent trend, where it is treated as
truth. The page's own leading caveat says the polls could be wrong together
and nothing here detects it -- at 0.3 the model was *assuming it away*, not
merely failing to notice.

### The false start, kept because the lesson is the expensive part

A first attempt picked 1.5 by judgement and tested it against four checks
written beforehand. Three passed; the fourth (SZ2: "house effects must grow")
failed, and the change was reverted as committed. SZ2 was watching the wrong
quantity -- `szc` constrains the weighted *mean* of house effects, which does
respond correctly (0.13 → 3.17 across the grid), not their individual size.

Held-out error had improved in that run too, but it was **not** a
pre-registered criterion, and adopting the change on it afterwards is exactly
what pre-registration exists to prevent. Hence v2: stop picking the value,
estimate it, and fix the criterion first. Full record in
[reviews/szc-prior-2026-08-16.md](reviews/szc-prior-2026-08-16.md).

Also recorded there: the sensitivity sweep used to justify v1 **predicted the
wrong sign** on the check it was most worried about, because it ran
`fit_cycle_trends` bare while the pipeline has firm factors, the fold
correction and estimated per-cycle sigmas. A stripped-down harness is not the
model.

### When to re-run

`scripts/tune_szc.R` takes about four minutes, too slow for every pipeline
run. Re-run it when the election record grows -- a new completed election is
new evidence about how far the industry misses -- and commit the result.

## 6b. Tested and kept: the house-effect prior

`sigma_house_pts` is the prior sd on ONE pollster's house effect, where
`szc_sd_pts` governs how far they may all sit from the truth together. Grid,
criterion and rule fixed in
[plans/prereg-sigma-house.md](plans/prereg-sigma-house.md) before running.

| `sigma_house_pts` | held-out MAE |
|---:|---:|
| 1 | 2.0689 |
| 2 | 2.0599 |
| **3 (incumbent)** | **2.0588** |
| 5 | 2.0725 |
| 8 | 2.0763 |

**Kept at 3**, which is the minimum of the grid outright rather than surviving
on the tie-break.

The shape matters as much as the winner. This is a **smooth U with an interior
minimum**, unlike the two constants tested before it: `szc_sd_pts` was a step
function where everything below 1 behaved identically and everything above did
too, and the default-versus-per-cycle model comparison was pure noise with
alternating signs. Here both directions are genuinely worse — too tight (1)
costs 0.010, too loose (8) costs 0.018 — so 3 is a real optimum and the
hand-set value was well chosen.

That is worth recording as a positive result. Three constants have now been
put through the same procedure and they came back differently: one was wrong
and moved, one is right and stays, one turned out not to matter. Auditing a
constant is not the same as changing it.

## 6c. Three constants that cannot be tuned the way the others were

Checked 2026-08-16 before running their grids, and the check is the result.

Held-out forecast error is the criterion used for `szc_sd_pts`,
`sigma_house_pts`, the mix weight, the ridge penalty and the flow estimator.
**It is the wrong criterion for these three, because none of them reaches the
forecast.**

Tracing what the published page actually depends on:

- The headline and the chart both come from `trend_as_at()`, which calls
  `fit_trend()` with `firm_factors = NULL` and default volatility.
- `output/projection-mix.csv` comes from `build_projection_data()`, same path.
- `output/trend-vic-2026.csv` is required but **no longer read**.

So:

| Constant | Reaches the forecast? | What it does reach |
|---|---|---|
| `k0 = 25` (cycle-sigma shrinkage) | **No** | The V/A/N validation checks in the fit scripts |
| `k0 = 12` (firm-factor shrinkage) | **No** | The published pollster scorecard |
| `clip = c(0.6, 2.0)` | **No** | The published pollster scorecard |

Running a held-out-MAE grid on any of them would have produced a flat line and
an authoritative-looking "KEEP", which is worse than not running it: a
meaningless number wearing the same format as three meaningful ones.

**What they would need instead.** For the firm factors, the honest question is
whether an estimated factor predicts a pollster's *future* accuracy out of
sample — a different and harder test than forecast MAE, and one the scorecard
half-implements already (`pollster_lean_predicts_error`). For `k0 = 25`, the
question is whether per-cycle shrinkage improves the validation fits, which
matters for confidence in the model rather than for the number it produces.

**Worth a decision separately:** the page publishes per-pollster noise factors
that play no part in the forecast. That is not wrong, but a reader could
reasonably assume otherwise, and the scorecard does not say so.

## 7. What to do next

In priority order, by how much each touches the published number:

1. ~~**`szc_sd_pts`**~~ — **done 2026-08-16**, now estimated at 1.5 (§6).
2. ~~**`sigma_house_pts`**~~ — **tested 2026-08-16, kept at 3** (§6b). It is
   the outright minimum of a smooth U, so the hand-set value was right.
3. ~~**`k0` and `clip`**~~ — **checked 2026-08-16**: none of them reaches the
   forecast, so held-out error cannot judge them (§6c). What they need instead
   is written there.
4. ~~**`n_ref` vs `n = 2500`**~~ — **resolved 2026-08-16**, and not as
   described: the fit scripts deliberately use both, one to halt and one to
   report. Now two named constants with their jobs written down. The real
   defect was the scorecard using the sensitive value for a published claim
   about named companies; it now uses the conservative one.

The one lesson worth carrying: **check what a constant reaches before
measuring how much it matters.** Item 3 was queued as three tuning grids and
resolved by ten minutes of tracing, because none of the three touches the
forecast at all. Running them would have produced flat lines wearing the same
format as three meaningful results.

Sizing comes before building in each case: if varying the constant across a
plausible range barely moves the forecast, it is a correctness matter and gets
recorded here rather than modelled.

## `level_sd` — seat variance that scales with the level of the share

`c(1.10, 8.67)`, giving `sd = 1.10 + 8.67 * sqrt(p * (1 - p))` in place of a
flat `seat_sd` of 3.5. Set `AUSPOL_LEVEL_SD=off` to reproduce the flat form.

**From data, not chosen.** Fitted over 9,015 seat-party observations across 17
election pairs; the slope coefficient jackknifes to 6.82–7.29 over those pairs.
It is the TOTAL residual form (`1.68 + 7.85 * sqrt(p(1-p))`) with the statewide
component removed in variance, because `party_sd` is added separately and
feeding the total in would count it twice.

**Adopted 2026-08-27** on `docs/reviews/level-variance-2026-08-27.md`. Federal
seats called 99%+ and lost fall from 23 to 12 across 886 seat-elections; Brier
and log loss improve in every subset on both federal and NSW 2023. Victoria 2026
medians move ALP 37→35 with every other party unchanged, under the
stop-and-report threshold of 3.

**Known limitation:** the form is global. NSW excluding independent wins was
already calibrated at 0.959 and this overshoots it to 1.272, so the
miscalibration it fixes is concentrated in IND seats while the correction is
applied to every class. A class-specific form is the open follow-up.

## Candidate-conditional slopes + salience screen (arm CS)

Default ON in `fit_seats_full.R` since 2026-08-27. `AUSPOL_DEV_SLOPE_MODE=off`
reproduces uniform swing exactly (proven byte-identical, not asserted).

**Cannot run yet for Victoria 2026**: `candidate_returns()` and
`salience_permit_for()` need vic2026's own candidate list, which does not exist
until nominations close before the 28 November 2026 election. Until then the
run prints `DS2 arm CS requested but vic2026 has no candidate list yet --
FALLING BACK to uniform swing` and behaves exactly as before this change.
Re-running after nominations close activates it with no code change.

**Measured on backtests before shipping** (fed2022, vic2022, sa2026, nsw2023;
see `docs/reviews/arm-c-conditional-slopes-2026-08-27.md` and the commits around
`afb7fef`/`203610e`): rescues nearly all of arm C's damage on fed2022 (log loss
1.0161 → 0.8780, vs unscreened 0.8727), and beats the unscreened baseline
outright on sa2026, vic2022 and nsw2023.

## Added 2026-09-06: two constants the inventory had missed

| constant | where | value | status |
|---|---|---|---|
| Candidate-conditional slope defaults (`same` / `new` per class) | the `same` / `new` defaults of `conditional_slopes()` and `screened_slopes()` in `R/dev_slope.R` (same values in both) | IND 0.907 / 0.326, OTH_RIGHT 0.891 / 0.325, others per the table in the roxygen | **ESTIMATED once, then frozen in code -- the fitting script now EXISTS.** `fit_conditional_slopes()` (`R/split_slope.R`), built 2026-09-09, refits all eight leave-one-election-out and checked each against its own definition: IND is fine (0.374 vs 0.326, 0.882 vs 0.907), but OTH_RIGHT is wrong in OPPOSITE directions (0.442 vs 0.325, +3.1 SE; 0.766 vs 0.891, -3.8 SE) and ONP "same" is off on 51 observations (-2.7 SE). The arm to REPLACE these frozen constants with the fit was pre-registered, run, and **REFUSED** (`docs/plans/prereg-fit-conditional-slopes-2026-09-09.md`: pooled log loss FAIL, panel FAIL) -- root cause was fed2013's OTH_RIGHT surge (Palmer United's debut), where the frozen `0.325` correctly shrinks hard toward the statewide level for a class with no local history, and the fit's `0.442` does not. So the CONSTANTS remain frozen, correctly, pending a slope that also conditions on surge status -- not for want of a fitting script anymore. The sitting-member tier (`AUSPOL_MP_SLOPE=1`, `output/mp-slope-by-*.csv`) overrides these for sitting members only. |
| Sitting-member slope tier (`output/mp-slope-by-class.csv`) | the `.MP_SLOPE` block in `scripts/fit_seats_full.R` (reads `output/mp-slope-by-class.csv`; `AUSPOL_MP_SLOPE=0` turns it off); backtests read `output/mp-slope-pooled.csv` by default (`AUSPOL_MP_SLOPE_POOL=1`, published since 2026-10-30; the `.MP_SLOPE` block in `scripts/backtest_candidate_fed.R`, on when `AUSPOL_MP_SLOPE=1`, which `published_flags.R` sets); `AUSPOL_MP_SLOPE_FILE`, default `output/mp-slope-by-target.csv`, applies only at `AUSPOL_MP_SLOPE_POOL=0`. `fit_seats_full.R` likewise reads the pooled table under the published default and `mp-slope-by-class.csv` only at `AUSPOL_MP_SLOPE_POOL=0` | Published (`mp-slope-pooled.csv`, vic2026 rows): every class takes the all-class member slope **0.960** (GRN is still dropped at use: `fit_seats_full.R` `.mpp$party != "GRN"`, harness default `AUSPOL_MP_SLOPE_GRN=0`), because the between-class variance tau^2 is 0 at vic2026 (class estimates IND 0.939 n=84, GRN 1.042 n=22, OTH_RIGHT 0.960 n=16, ONP 1.340 n=1; no n floor). Only at `AUSPOL_MP_SLOPE_POOL=0`, the by-class table: IND 0.939 (n=84), OTH_RIGHT 0.960 (n=16); GRN (1.042, n=22) excluded, ONP/OTH excluded by the n>=8 floor | **FITTED, and tracked in git** (both tables; a few other `output/` files are tracked too). Both written by `scripts/fit_mp_slope.R` from `output/candidacies.csv` (the pooled table by `R/mp_slope_pool.R`, partial pooling toward the all-class slope); all-data per class for vic2026, which is leak-free because vic2026 has not happened (a backtest uses the target-keyed rows). Committed copies: pooled 2026-10-30, by-class 2026-10-27. **Tracked because of a CI deadlock, not because a generated file belongs in git**: `fit_seats_full.R` hard-stops without it under the published default, but CI cannot build it (needs `candidacies.csv` -> `build_candidacies.R` -> `external/reference/` dirs CI never populates), and it cannot be switched off either, because `fit_seats_full.R` refuses to write published filenames under a non-published config. That took the nightly Forecast refresh down for six runs, 2026-09-10 to 09-14. **REFIT (`Rscript scripts/fit_mp_slope.R`) whenever `candidacies.csv` changes**, and drop the `.gitignore` exception once `build_candidacies.R` runs in CI. |
| `AUSPOL_SEAT_SD_MULT` | all five `scripts/backtest_candidate_*.R` | default 1 | **FIXED** — a diagnostic multiplier on whichever seat spread is in force (`level_sd` when on, else `seat_sd`), for the pre-registered calibration arm B. Not read by `fit_seats_full.R`. Inert in four harnesses from 2026-08-27 to 2026-09-06 while printing "applied"; the arm B sweeps in that window measured nothing. |
| `AUSPOL_SEAT_SPREAD_SRC` | all five `scripts/backtest_candidate_*.R` | `derived` | **FIXED** (2026-10-16) -- where the harnesses get `seat_sd`. `derived` = within-region SD of the seat-level ALP-v-Coalition swing AT the pair's previous election, from `external/elections/archive` (`R/prev_seat_swing.R`); `anchor` = the old anchor seat file for the target election or a LATER one, which leaked (nsw2011/15, sa2010/14/18, qld2012-20, every vic pair, fed2010-16 via a median). Not read by `fit_seats_full.R` (flat `SEAT_SD` 3.5). `scripts/compare_seat_spread_sources.R` prints old vs new per pair. |
| `departed_rate = c(IND = 0.38)` (`AUSPOL_HONOUR_DEPARTED`) | `R/dev_slope.R` `screened_slopes()` | 0.38 | **ESTIMATED**, from `docs/reviews/departed-leader-retention-2026-09-15.md`: n=305 departing-non-major cases retain 0.38 of their prior class base vs n=288 recontesting cases retaining 1.01. Fires only when the prior top candidate of the class does NOT return (`prior_leader_returns == FALSE`) AND the salience screen does not independently permit a new emergence — decoupled from `candidate_returns()`'s `same` column, which aggregates `any()` across every candidate in the class and can read `TRUE` even when the actual leader departed (Morwell/vic2022: `same=TRUE` from an unrelated minor candidate, `prior_leader_returns=FALSE` from Russell Northe's real retirement). Shipped 2026-09-18 after re-measurement on the fuller corpus superseded the 2026-09-06 two-seat refusal — see `docs/reviews/departed-leader-honour-fix-2026-09-18.md`. |
| `AUSPOL_NOM_ZERO` | `R/nomination_zero.R`, `scripts/published_flags.R` | `"2"` | **SHIPPED v61 2026-10-03.** 0 off, 1 freed share proportional, 2 freed share by preference flows. Chosen by backtest, `plans/prereg-nomination-zero-2026-10-03.md`. |
| `AUSPOL_NOM_ZERO_ORDER` | `R/nomination_zero.R` (`nom_zero_order()`), six `scripts/backtest_candidate_*.R`, `scripts/published_flags.R` | `"late"` | **SHIPPED 2026-10-04 (Pete overrode the R2 refusal), not a fitted number; was `"early"` while testing.** A position switch for the six harnesses only: `early` zeroes right after the xgb override (what v61 was measured on), `late` zeroes after the last step that can revive a zero (the published forecast already does). Cannot come from data; decided on the prereg's 22-pair result (every clause passed except R2, bias shifts of 0.0045 and 0.0020 points), `docs/reviews/zero-order-22pair-2026-10-04.md`. `plans/prereg-zero-order-2026-10-03.md`. |
| `min_ratio = 0.85` (`live_nominations()`) | `R/nomination_zero.R` | 0.85 | **CHOSEN, cannot come from data.** HARD check even with `AUSPOL_NOM_LIVE=1`: the live vic2026 candidate list must hold at least this share of vic2022's 731 candidacies, else it is treated as a load error and zeroing stays shut. There is no distribution of "final list size" to fit it to (one comparable prior election), and it must be fixed before nominations close, when it is needed. It is deliberately a count, not a per-seat rule: a major party can genuinely not stand in a seat (ABC's list of 2026-10-03 had no ALP in 8 seats and no LNP in 8). |
| `NOM_GATE_DATE = 2026-11-10` | `R/nomination_zero.R` | date | **WARNING-ONLY.** Nominations close noon 9 Nov 2026. `AUSPOL_NOM_LIVE=1` set before this date logs a loud warning that nominations may not have closed; it never blocks and `auto` no longer uses it. A calendar fact, not estimable. |
| `AUSPOL_NOM_LIVE` | `R/nomination_zero.R`, `scripts/published_flags.R` | `"auto"` | **FIXED, meaning changed 2026-10-03.** Gate for v61 in the PUBLISHED Victorian forecast. Opens ONLY when set to `1` by hand, meaning the VEC final list has been loaded into `output/candidacies.csv`. `auto` (default) and `0` stay shut; `auto` logs "provisional list". Any other value, or any failure to apply under `1` (missing csv, no vic2026 rows, no vic2022 baseline, count floor, error in the step), STOPS the run. With `1`, ALP/LNP absent in some seats, or a seat with no candidacy, are logged warnings naming the seats (those classes WILL be zeroed there), not blocks. |
| `NOM_CLASS_WARN_RATIO = 0.8` | `R/nomination_zero.R` | 0.8 | **DISPLAY THRESHOLD, not a model constant.** With `AUSPOL_NOM_LIVE=1`, a class standing in fewer than this share of its vic2022 seat count is named in a warning; nothing is blocked or changed by it. Cannot come from data (there is no distribution of final per-class seat counts); it only decides what gets flagged for a human to check. |

## Breakout mixture (`AUSPOL_BREAKOUT_MIX`, built 2026-10-06, OFF)

`R/breakout_mix.R`; design in `docs/reviews/breakout-risk-design-2026-10-05.md`. All inert at the published `"0"`.

| constant | value | status |
|---|---|---|
| `.BO_CLASSES` | IND, OTH, OTH_RIGHT, ONP | **CHOSEN** (GRN left out as a different phenomenon, per the design review). |
| `.BO_HARD` | 15 | **CHOSEN** in the design review: only rows predicted under 15 get the mixture (applying it to every row pulled expected winners down). Not fitted. |
| `.BO_Y` | 20 | **CHOSEN**: the breakout definition (actual primary >= 20). The review also measured 25. |
| `.BO_MIN_POS` | 5 | **FEASIBILITY FLOOR**, not a model constant: an xgboost classifier with fewer earlier breakouts than this is not fitted (fed2010, wa2013 and every earlier election get no p). |
| `.BO_CAL_K` | 10 | **CHOSEN prior strength**: Platt calibration shrunk toward identity by npos / (npos + 10). |
| `.BO_Q_K` | 10 | **CHOSEN prior strength**: the hard-row breakout quantiles shrunk toward all-row breakout quantiles by n / (n + 10). |
| `.BO_P_CAP` | 0.5 | **CHOSEN** cap, from the review's recommendation pending recalibration on the real simulator (the review's top bin was over-confident, 44% vs 24%). |
| xgboost settings | eta 0.05, depth 3, subsample 0.8, colsample 0.8, min_child_weight 2, lambda 5, up to 300 rounds, early stopping 25 | **COPIED** from the design review's classifier; rounds chosen by `xgb.cv` with folds grouped by election. |

## Added 2026-10-06: state-level defector rate (`AUSPOL_DEFECTOR_STATE`, OFF)

`R/defector_state.R`; design in `docs/reviews/state-defectors-2026-10-06.md`. Inert at the published `"0"`.

| constant | value | status |
|---|---|---|
| `.DEFSTATE_K` | 3 | **CHOSEN prior strength** (the review measured it: carry bias +0.16 -> +0.05): the target level's sitting-member median is shrunk toward the all-level median by n / (n + 3) pseudo-cases. Replaces the min_n = 5 cliff. Not fitted; K could be estimated once there are enough cases per level to size between-level variance. |
| cross-seat guards | sitting members only; same jurisdiction (federal: same state); full first name equal or one a prefix of the other; key unique among the previous election's major candidates and the target's candidates | **RULES**, not constants; every refusal is printed (`DFS2!`). |

### Jurisdiction pooling (`AUSPOL_POOL_BY_JURISDICTION`, published `"0"`)

`R/pool_hierarchical.R`, `pool_by_group()`; inventory in `docs/reviews/pooled-fits-inventory-2026-10-13.md`. Inert at the published `"0"`.

| constant | value | status |
|---|---|---|
| `AUSPOL_CONSERVE_SHRINK_K` (was `min_n` = 8) | K = 3 pseudo-cases | `fit_minor_defector_conserve()`: **CHOSEN prior strength** (same 3 as `.DEFSTATE_K`), shipped 2026-10-16. The median kept share is shrunk toward 0 by n / (n + 3); replaces a cliff that ignored 7 cases and believed 8. Not fitted. `"off"` restores the cliff. Screen: seat log loss unchanged (+0.0001, SE 0.0001). |
| `AUSPOL_DEPARTED_ORIGIN_SHRINK_K` (was `min_n` = 5) | K = 3 pseudo-cases | `fit_departed_origin_return()` (`R/candidate_returns.R`): **CHOSEN prior strength**, same 3 as above, added 2026-10-24. The share of a departed defector's vote that goes home to their origin party is shrunk toward 0 by n / (n + 3). The same change made the fit time-forward; it was leave-target-out. Reaches the model only under `AUSPOL_DEPARTED_ORIGIN` (off). `docs/plans/prereg-departed-origin-tf-2026-10-24.md`. |
| `AUSPOL_GRN_TREE_SHRINK_K` | K = 3 elections | `grn_tree_shrink_fit()` (`R/grn_tree_shrink.R`): **CHOSEN prior strength**, added 2026-10-24. The fitted pull of the trees' Greens share toward base (`lambda`, least squares on earlier elections' as-at rows in `output/forecasts.csv`) is shrunk toward 0 (no pull) by G / (G + 3), G = earlier elections. The form `w = 1/(1 + lambda*base)` has lambda as its only fitted number. Reaches the model only under `AUSPOL_GRN_TREE_SHRINK` (off). `docs/plans/prereg-grn-tree-shrink-2026-10-24.md`. |
| `prior_df` | 3 pseudo-degrees of freedom | **CHOSEN prior strength** (same 3 as `.DEFSTATE_K`): each jurisdiction's own spread is moderated toward the pooled within-jurisdiction spread, s_g^2 = (SS_g + 3 s^2) / (n_g - 1 + 3). Not fitted; with 1-9 cases per jurisdiction the variance of the variances cannot be estimated. `Inf` gives one common spread. |
| `1.2533` | sqrt(pi/2) | **MATHEMATICAL**: large-sample standard error of a median relative to a mean under normal noise. |
| between-jurisdiction variance tau^2 | fitted per call | **FITTED** (DerSimonian-Laird method of moments, floored at 0). |

## New-independent shrink (AUSPOL_NEW_IND_SHRINK, OFF, prereg pending)

| constant | value | status |
|---|---|---|
| `prior_max` in `new_ind_cells()` | 10 share points | **INHERITED from `docs/reviews/vic-ind-overcall-2026-10-06.md`** (its "departed class leader, class prior 10 or more" row is a different population with its own, refused, rule). A cell definition cut, not a fitted value; the data could set it (n of departed-leader cells is 12, too few to fit). |
| the factor | fitted per target | **FROM DATA**: ratio of sums of actual to base_pred over earlier new-independent cells, partially pooled by jurisdiction (DerSimonian-Laird tau^2), bounded [0, 1]. No constant. |
| design effect for a one-election jurisdiction | measured | **FROM DATA**: clustered SE / cell-level SE on the all-jurisdiction fit. |

## Hare-Clark party-seat path (Tasmania, ACT; `R/hare_clark.R`, added 2026-10-13)

A separate scored path (`scripts/backtest_hare_clark.R`), not in the published single-member forecast.
Every SD and rate below is fitted time-forward (election pairs dated before the target only); the numbers in
the table are the PRIORS each one is shrunk toward, which bind only when few earlier pairs exist.

| constant | value | status |
|---|---|---|
| `prior_sd`, `n0` in `hc_noise_sd()` | 3 points, 5 pseudo-deviations | **PRIOR**; the per-class electorate SD is fitted from earlier electorate deviations from uniform swing (25 to 70 deviations per class by 2016) and dominates once n > 5. |
| `prior_sd`, `n0` in `hc_state_sd()` | 5 points, 3 pseudo-changes | **PRIOR** for the statewide spread used only by the previous-result FALLBACK (no polls); fitted from earlier statewide changes, both regions pooled. |
| `prior_new`, `prior_sdlog`, `n0` in `hc_unit_priors()` | 1.5 points, 0.5, 5 | **PRIORS**: a new minor ticket's expected first-preference share and the log-share spread of a returning one; fitted from earlier elections (100+ new tickets by 2020). |
| `prior_n` in `hc_flows_from_ballots()` (`R/hare_clark.R:221`), `hc_leak_from_ballots()` (`:255`) and `hc_flows_from_counts()` (`R/hare_clark_candidates.R:33`) | 50 pseudo-ballots | **CHOSEN** shrinkage toward the pooled row; rows carry 25,000 to 100,000 ballots, so it binds only on an empty class. |
| `exh` in `hc_flows_prior()` | 0.3 | **SENSITIVITY ARM ONLY** (`--flows=prior`); never the default. |
| naive hit-rate prior | 0.6 with 20 pseudo-cells | **PRIOR** for the naive baseline's probability on "same seats as last time"; fitted from earlier pairs. |
| floor on simulated shares | 0.05 points | **COMPUTATIONAL** (keeps a contesting class alive before renormalising). |
| Tasmanian transfer rates | the latest ACT ballot file before polling day | **BORROWED**: Tasmania publishes no ballot files. The TEC 2024/2025 count exports (stored) would allow a Tasmanian estimate for 2025 onward; not built. |
| `lambda0`, `sdlog0`, `n0` in `hc_split_priors()` | 0.7, 0.4, 20 | **PRIORS** for the within-ticket split (shrink toward equal; log-share noise); both fitted time-forward over every ticket that stood twice. |
| synthetic ballot depth | two transfers, then exhausted | **CHOSEN** structure for Tasmania's synthetic ballots (no ballot files); the Tasmanian count exports could fit it. |
| ballot slot depth | 20 preferences | **CHOSEN** cut in `scripts/build_hare_clark_ballots.R`. |

## Fold correction in the fuller trend scripts (`R/fold.R`, `scripts/fit_federal.R`, added 2026-10-15)

These reach only `fit_federal.R` / `fit_nsw.R` / `fit_vic.R`, whose outputs the published forecast does not read (it uses `trend_as_at()`).

| Constant | Value | Status |
|---|---|---|
| `house_adjust` in `unfold_others()` | TRUE | **CHOSEN** structure: impute the firm's own fitted house effect (shrunk by the trend model's `sigma_house_pts` prior), not the all-firm trend. |
| One Nation unprompted `discount` | fitted each run (FFD1; `scripts/fit_federal.R:312-359`, consumed by `R/fold.R:153`) | **ESTIMATED**, inverse-variance pooled over every firm-cycle that both names and folds One Nation (2 firms, 2025 cycle, as of 2026-10-15). Fitted on the same within-firm gap FF1 checks, so FF1 cannot validate it until a second cycle has such firms. |
| `FD_ITER`, `FD_TOL` in `fit_federal.R` | 4 iterations, 0.002 | **COMPUTATIONAL**: the discount is re-estimated after a refit until the pooled increment is below 0.2% of the imputed share; failing to converge stops the script. |

## Coalition split (`AUSPOL_COALITION_SPLIT`, built 2026-10-16, SHIPPED 2026-10-17 with `_F=state`; `R/coalition_split.R`)

A Liberal and a National in one seat counted as two candidates. Prereg: `plans/prereg-lib-nat-two-candidates-2026-10-16.md`.

| Constant | Value | Status |
|---|---|---|
| `f`, Coalition-to-Coalition share of an excluded Coalition candidate's votes | fitted each election (0.70-0.76) | **ESTIMATED** time-forward: pooled over every earlier year's exclusion with another Coalition candidate surviving (transfer files). |
| junior fraction centre `r`, `mu`, `s` (there is no `tau` in the code) | fitted each election (`coalition_split_fit()`, `R/coalition_split.R:150-190`) | **ESTIMATED** time-forward. As built (prereg Amendment 1, which replaced the original `tau^2/(tau^2+s^2)` shrinkage this row used to describe): `r = min(fn_hat, 1 - fn_hat)`, where `fn_hat` is a ridge regression (`glmnet`, alpha 0, `lambda.min`, folds = min(10, n)) on logit of the Nationals' fraction of the Coalition vote, with nine features (the state's fraction at the previous election, each party's own previous vote and whether it stood, sitting-member flags, the seat's last split and its indicator). `s` is the sd of the out-of-fold residuals, ONE number per election, used as the Beta spread for every seat. `mu` is the training-set mean junior fraction, returned for reference. A seat with no previous split still gets a ridge prediction (indicator 0, state fraction filled by the training mean when missing); fewer than 5 earlier split seat-elections means no split (`:147`). |
| Beta sd cap | 0.95 x sqrt(r(1-r)) | **COMPUTATIONAL**: a Beta with mean r cannot have sd at or above sqrt(r(1-r)). |
| junior fraction clamp | [1e-9, 1 - 1e-9] | **COMPUTATIONAL**. |
| side-stream seed | `(seed * 7919 + 104729) mod 2^31-1` | **COMPUTATIONAL**: keeps the split's draws off the count's stream so unsplit seats are byte-identical. |

## Seat-composition spread (`AUSPOL_COMPOSITION_SD`, built 2026-10-17, SHIPPED 2026-10-17 with the error distribution on Pete's override; `plans/prereg-composition-spread-2026-10-17.md`; `R/size_sd.R`)

| Constant | Where | Value | Status |
|---|---|---|---|
| per-class coefficient `b_c`, weight `w_c` | `scripts/fit_spread_by_composition.R` -> `output/spread-by-composition.csv` | fitted per target, time-forward. In the 2026-10-21 `output/spread-by-composition.csv` (read 2026-10-25) vic2026 has IND b = 0.240 (se 0.056, w 0.945), i.e. IND sd x1.120 per 10 points of predicted IND share (the earlier text said x1.124); GRN b = -0.250 (w 0.81), ONP -0.220 (w 0.60), OTH -0.271 (w 0.27) and OTH_RIGHT 0.034 (w 0). Only OTH_RIGHT is shrunk to zero weight; the three negative classes keep weight but the factor is floored at 1 (`R/size_sd.R:53,79`), so they can only offset other classes' widening | **ESTIMATED** (Gamma GLM, SE clustered on election, `w = max(0, 1 - se^2/b^2)`) |
| classes | `composition_sd_classes()` | GRN, IND, ONP, OTH, OTH_RIGHT (majors the reference) | **CHOSEN**: every non-major class; the data pick which widen |
| `/ 10` share unit, `/ 2` sd from variance | `composition_sd_factor()` | scale only | **DEFINITIONAL** |
| floor at 1 | `composition_sd_factor()` | only widens | **CHOSEN** (prereg; Greens narrowing is a separate question) |
| minimum training | `fit_spread_by_composition.R` | 3 earlier elections and 500 cells, else factor 1 | **COMPUTATIONAL**: the clustered SE needs several elections |

## Empirical error distribution (`AUSPOL_ERROR_DIST`, built 2026-10-17, SHIPPED 2026-10-17 on Pete's override; `plans/prereg-error-distribution-2026-10-17.md`; `R/error_dist.R`)

| Constant | Where | Value | Status |
|---|---|---|---|
| per-class quantiles of standardised error | `scripts/fit_error_distribution.R` -> `output/error-quantiles.csv` | 201 (0.5% steps), earlier elections only | **ESTIMATED** |
| shrinkage toward pooled | same | `w = n / (n + 200)` | **CHOSEN** (k = 200: a class needs a few hundred cells before its own tails dominate) |
| width | same | each class rescaled to RMS 1 (exact for the interpolated draw) | **CHOSEN** (prereg: shape, not width) |
| training floor | same | cells predicted 2+ | **CHOSEN** (matches the spread fits) |
| minimum training | same | 3 earlier elections and 2,000 cells, else rnorm | **COMPUTATIONAL** |

## Added 2026-10-19: constants shipped or changed 2026-10-09 to 2026-10-19

Found by reading the diffs of `R/` and `scripts/` since 2026-10-09 against this file. Each row says whether the number is fitted from data and where.

### Statewide draws netted out of the seat spread (`AUSPOL_HARNESS_SW_DRAWS="net"`, `AUSPOL_SW_NET_LIVE="1"`, shipped 2026-10-19)

| Constant | Where | Value | Status |
|---|---|---|---|
| net-out floor | `R/forecast_statewide.R:506` (`floor2 <- (0.5 * cur)^2`) | a cell's seat sd never falls below 0.5 x its un-netted sd | **CHOSEN** (prereg amendment 1). A guard so a draw wider than the seat spread cannot drive the variance negative. Not fitted; the log line `SWN1`/`SWLN1` counts cells at the floor. |
| flat statewide reference, live | `scripts/fit_seats_full.R` (`1.5` passed as `party_sd` to `harness_sw_net_sd()` in the `AUSPOL_SW_NET_LIVE` block) | 1.5 points | **INHERITED**: the flat statewide piece removed from the seat residual when `level_sd` was fitted (section "`level_sd`" above). Not re-fitted. The live draws' own sd (`psd`) is deliberately NOT the reference, or nothing would be netted out (comment above the `AUSPOL_SW_NET_LIVE` block). |
| flat statewide reference, harnesses | `AUSPOL_PARTY_SD` default, e.g. `PARTY_SD` in `scripts/backtest_candidate_nsw.R` (the `psd` vector is built from it on the next line), passed as `party_sd = psd` to `simulate_seat_contests()` in the same script | 1.5 points | **INHERITED**, same number as above. |
| `AUSPOL_FP_EXTRA_SD` | `R/forecast_statewide.R:466`; `scripts/fit_seats_full.R:163` | 2.419 | **ESTIMATED 2026-08-19** (row in section 1). Became a switch 2026-10-19 so the width arms of the F4 prereg could vary it; the shipped value did not move. |

### Seat-poll blend, arm H (shipped 2026-10-18; `R/seat_poll_blend.R`)

The blend weight for a cell is `v / (v + 1/P + t2)`: `v` our model's error variance for the class, `P` the summed decayed poll precision, `t2` an election-wide poll miss. Everything below except the priors is fitted time-forward on earlier elections only.

| Constant | Where | Value | Status |
|---|---|---|---|
| `SEAT_POLL_OPTIN_FLOOR_PRIOR` | `:302` | 225 points^2 (sd 15) | **CHOSEN** prior for opt-in link polls (amendment 1). The `optin` group's floor is shrunk toward this instead of the pooled floor. |
| `SEAT_POLL_ELECTION_ERR_PRIOR` | `:521` | 4 points^2 (sd 2) | **CHOSEN** prior for the miss every seat poll in an election shares (amendment 8). The per-class value is **ESTIMATED** from earlier elections (`seat_poll_election_err()`, `:533`) and shrunk by `SEAT_POLL_FLOOR_K`. |
| squared-error floor in the size exponent | `:386` (`pmax(e2, 0.25)`) | 0.25 points^2 | **COMPUTATIONAL**: keeps `log(e2)` finite where a prediction was exact. |
| size exponent `g` | `:384-392` | fitted per target | **ESTIMATED** (amendment 2): slope of log squared error on log(predicted share + 1), class-demeaned, shrunk by `max(0, 1 - se^2/g^2)`. Prior 0. |
| salience exponent `b` | `:394-430`; jump offset 0.01 at `:421`; at least 3 earlier cells at `:420` | fitted per target | **ESTIMATED** (amendment 4), same shrinkage. The 0.01 only keeps `log(jump)` finite; 3 cells is a **FEASIBILITY FLOOR**. |
| model-variance pool | `:321`, `:359`, `:362-368` | prior 25 points^2, `K = SEAT_POLL_FLOOR_K` | **ESTIMATED** from every earlier seat-class cell (amendment 5), shrunk toward the prior. |
| heavy-tail mixture (arm, OFF) | `:405` (`pr_pi <- 0.02`), `:513` (`k >= 1.5`), `:507` (fallback pi 0.02, s1 1, k 9 below 20 cells) | 0.02, 1.5, 9 | **CHOSEN** priors for `AUSPOL_SEAT_POLL_HEAVY_TAIL`, inert at the published "0". |
| method groups | `poll_methods.csv`; `.seat_poll_method_table()` `:303-311` | mrp, direct_indep, direct_stake, optin | **RULES**: a poll is `direct_stake` when its sponsor type is party, union, advocacy group, industry lobby or candidate campaign. Hand-keyed definitions. |

Existing rows for `AUSPOL_SEAT_POLL_PRIOR` (0.75), `_PRIOR_SD` (0.25), the half-life prior (60 days), its log sd (0.7), the floor prior (16), `K` (10) and the sample fallback (600) now carry line numbers in section 1 and are all shipped, not arms.

### Live train/serve fixes (shipped 2026-10-18 and 2026-10-19)

| Constant | Where | Value | Status |
|---|---|---|---|
| major-defector discount | the `.defect` block in `scripts/fit_seats_full.R`, fitted by `fit_defector_discount()` in `R/candidate_returns.R` | 0.313 at the 2026-10-18 audit (DECISIONS); no number in code | **ESTIMATED** time-forward each run (`AUSPOL_LIVE_DEFECT_FIT="1"`). The frozen **0.282** (`.defect <- 0.282`) is now only the fallback when the fit fails or has too few cases (`CAL!` line). |
| `AUSPOL_LIVE_LEVEL_SPLIT` | `scripts/fit_seats_full.R` (`AUSPOL_LIVE_LEVEL_SPLIT` block) | "1" | Switch. The others bucket is split as in training by `bucket_split_ratio()`; the ratio is **ESTIMATED** from the candidate model, falling back to the prior election's ratio. |
| `AUSPOL_LIVE_SEATPREV_RAW` | `scripts/fit_seats_full.R` (`.mat22_xgb`) | "1" | Switch: the xgb layer reads the raw prior-election matrix it was trained on. |
| `AUSPOL_SURGE_H_TF` | `scripts/fit_xgb_primary_v6.R:580` | "1" | Switch: the xgb `surge_h` feature is built from earlier canon elections only. |
| `AUSPOL_SURGE_SOURCE` | `R/party_surge.R:95` | "none" | Switch (decided 2026-10-16): no class counts as surging in the salience screen. |

### Spread by seat size, composition and error shape (shipped 2026-10-14 and 2026-10-17)

| Constant | Where | Value | Status |
|---|---|---|---|
| training floor, size and composition fits | `scripts/fit_spread_by_size.R:24`, `fit_spread_by_composition.R:31` | cells predicted at 2 or more points | **CHOSEN** (matches the error-distribution fit). |
| minimum training, size and composition | `fit_spread_by_size.R:33`, `fit_spread_by_composition.R:67` | 3 earlier elections and 500 cells, else factor 1 | **COMPUTATIONAL**. |
| size bins | `fit_spread_by_size.R:36` | ten equal-count bins of log formal votes | **CHOSEN**. Slope shrunk by `w = max(0, 1 - se^2/b^2)`, then `factor = max(1, exp(w*b*(log f - log f_median)))`; `f_median` is **ESTIMATED** (median training seat size). |
| `COMPOSITION_OWN_MIN_SHARE` | `R/size_sd.R:30` | 2 points | **CHOSEN**; only the own-cell arm (`AUSPOL_COMPOSITION_SD="own"`, not shipped) reads it. |
| composition share unit | `R/size_sd.R:77` (`/ 10`) | per 10 points | **DEFINITIONAL**. |
| error quantile grid | `scripts/fit_error_distribution.R:68` | 201 quantiles, 0.5% steps | **CHOSEN**. |
| error shrink K | `scripts/fit_error_distribution.R:69` (`K_SHRINK <- 200`), weight at `:92` | 200 cells | **CHOSEN** (a class needs a few hundred cells before its own tails dominate); `w = n/(n+200)` toward the pooled quantiles. |
| error training floor and minimum | `fit_error_distribution.R:54`, `:89` | predicted 2+; 3 earlier elections and 2,000 cells, else rnorm | **CHOSEN** / **COMPUTATIONAL**. |
| `AUSPOL_ERROR_DIST_COMP` | `R/error_dist.R:12` | "0" | ARM (audit F9): standardise the error shape by the composition factor too. Not shipped. |

### Recent-poll level blend, training weights and other switches

| Constant | Where | Value | Status |
|---|---|---|---|
| `AUSPOL_LEVEL_RECENT_HALFLIFE` | `R/level_recent.R:191` | 20 days | **CHOSEN BY PETE 2026-10-11/12** (no hard caps; "fit" refused as too jumpy). The blend weight `k` is **ESTIMATED** on earlier elections (grid `exp(seq(log(0.25), log(400), length.out = 120))`, `:262`). |
| `AUSPOL_LEVEL_FED_R` | `R/level_recent.R:77` | 0.15 | **CHOSEN BY PETE 2026-10-12** (the level screen was about 1 SE worse at every r; shipped on preference). Not fitted. |
| `AUSPOL_LEVEL_FED_GAP_HL` | `R/level_recent.R:141` | 90 days | **CHOSEN**, fixed not fitted (180 reported as sensitivity). Gap shrunk to 0 by n/(n+1). |
| thin-cycle noise and walk | `R/thin_cycle.R:110` (`default_sigmas("points")`), header `:26`; the values are set in `default_sigmas()` at `R/trend.R:280` (`sigma_obs = 1.7, sigma_rw = 0.10`) | 1.7 points noise, 0.10 points a day walk | **INHERITED** from the trend model; `tau` (change between consecutive elections) is **ESTIMATED** time-forward and shrunk by precision. |
| `AUSPOL_TRAIN_DECAY_H` | `scripts/fit_xgb_primary_asat.R:104` (published "8") | 8 years | **CHOSEN** (P4, Pete override 2026-10-13); half-life of a training row's weight by age. |
| `AUSPOL_FLOW_RATE_HL` | `R/xgb_flow_override.R:295` (published "2") | 2 years | **CHOSEN** (tf2); must equal the half-life the tagged models trained at (`validate_flow_arm()`). |
| `AUSPOL_CONSERVE_SHRINK_K` | `R/candidate_returns.R` (`.conserve_shrink_k()`) | 3 | Already listed under jurisdiction pooling; line added. |
| `AUSPOL_DEFECT_BY_LEVEL` | `fit_defector_discount()` in `R/candidate_returns.R` | "2" | Switch, shipped 2026-10-05. |
| `IND_MIX_PRIOR_SD` | `R/ind_mixture.R:16` (arm `AUSPOL_IND_MIXTURE`, OFF) | 1.5 | **CHOSEN** prior sd of the surge-chance coefficients; inert at the published "0". |
| `FD_TOL` | `scripts/fit_federal.R:341` | 0.002 | Already listed (fold section); line added. |
| `k_prior` (`onp_newseat_cv()`) | `R/onp_newseat.R:208` (arm `AUSPOL_ONP_NEWSEAT_RULE`, OFF) | 0.5 | **CHOSEN** prior exponent of One Nation's SD-on-level curve (`scripts/estimate_onp_concentration.R` fits ~0.5 over all seats); the time-forward contested-seat fit pulls it to ~0.8 once 10+ earlier elections exist. Inert at the published "0". |
| `k_shrink` (`onp_newseat_cv()`) | `R/onp_newseat.R:208` | 3 | **CHOSEN** shrinkage constant, weight `df/(df+3)`, same form as `AUSPOL_CONSERVE_SHRINK_K`. Inert at "0". |
| `min_seats` (`onp_newseat_cv()`) | `R/onp_newseat.R:208` | 10 | **CHOSEN** fewest One-Nation-contested seats for an earlier election to enter the spread fit. Inert at "0". |
| no-history seats needed / key coverage (`onp_newseat_apply()`) | `R/onp_newseat.R:314`, `:335` | 3 seats; at most 10% without a key | **CHOSEN**, the same applicability rule as `onp_senate_rank_apply()` / `onp_senate_alloc()`. Inert at "0". |

## Partially pooled sitting-member slopes (`AUSPOL_MP_SLOPE_POOL`, built 2026-10-25, SHIPPED 2026-10-30; `plans/prereg-mp-slope-pool-2026-10-25.md`; `R/mp_slope_pool.R`)

| constant | where | value | status |
|---|---|---|---|
| `n_member >= 8` (live MP tier floor) | `scripts/fit_seats_full.R` (`.keep`, MP tier block) | 8 | **CHOSEN, a min_n cliff**; the harnesses never had it. Reached only at `AUSPOL_MP_SLOPE_POOL=0` since 2026-10-30; the shipped `1` keeps every class and shrinks it instead. |
| `tau^2`, `se_i` (pooling weight `w = tau^2/(tau^2+se_i^2)`) | `R/mp_slope_pool.R` | per target | **ESTIMATED**: `tau^2` by DerSimonian-Laird over the classes with member rows (floored at 0; 0 with fewer than two classes), `se_i` from one within-class residual variance pooled over classes. No new hand-set number. |
| pooled-toward slope `mu` | `scripts/fit_mp_slope.R` (`shr()`, `K = 10`, `PRIOR_MEMBER = 1.0`) | per target | **REUSED**, not new: the time-forward grid's own all-class member slope, shrunk toward 1.0 by `n/(n+10)`, so a target with no earlier member rows gets 1.0 as the grid does. |

## Election-night update (`R/night_update.R`, `R/booth_projection.R`; issues #153, #160, #161)

Replay-only until the 2026 feed arrives; none is read by the published forecast. Each was set on the vic2022 replay
(2018 booths as the reference), so none is held out.

| constant | value | where | can it come from data? |
|---|---|---|---|
| projection sd by counted share | 3.5 / 2.63 / 1.93 / 1.77 / 0.26 at 0-5% / 8.6% / 22.4% / 34.6% / 95% | `booth_projection_sd()` | fitted on the 2018->2022 replay (rehearsal 1); refit on another state's booth pair |
| report order | small ordinary booths first (log size + N(0, 0.5)), postals last, seed 2022 | `.night_order()` | the 2026 feed's real order replaces it |
| early-vote report position | "last" (default) or "interleaved" U(0.3, 1.0) of the way through the booths | `.night_order(early =)` | the 2026 feed; each early centre is its own booth |
| vote-type gap shrinkage `gap_k` | off by default; 5 chosen (k = 20 tried: 75% counted 0.0712 vs 0.0750) | `night_booth_update(gap_k =)` | more replays (other states) |
| VEC pair minimum | 0.20 of draws | `night_apply_tcp(pair_min =)` | set by judgement; check on a replay with VEC first-pair errors |
| flow SE below 3 counted booths | 0.25 | `night_tcp_obs()` | judgement (a flow share's plausible range) |
| flow SE floor | 0.02 | `night_tcp_obs()` | judgement |
| new-candidate sd multiplier | 1 (off): 1.5 and 2 were slightly worse on 2022 (few new candidates; One Nation 2026 untestable) | `night_booth_update(new_sd_mult =)` | a replay with a new party (SA 2026) |

## Election-night 2CP update (added 2026-10-31)

| Constant | Where | Value | Status |
|---|---|---|---|
| Flow sd floor | `night_run_update(tcp_flow_floor =)` -> `night_apply_tcp(flow_sd_floor =)`, `R/night_runner.R` | 0.01 (0.065 tried 31 Oct, taken off the same day) | **CHOSEN, not fitted.** The measured between-seat error of the night's booth-implied two-candidate flow is 0.065 (fed2022/fed2025, `docs/reviews/aec-preference-data-2026-10-30.md`), but using it as the floor never helped on the real-night replays and made vic2022 worse at 10pm (`docs/reviews/night-replay-real-feed-2026-10-31.md`, per-fix split). Open: why a measured error makes the update worse. |
