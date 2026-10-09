# Scope: weight statewide polls by sample size and track record

2026-10-09. Read-only investigation, no R was run. Pete's request is in
`docs/PETE-ASKED-FOR.md:38` ("Statewide polls: same per-poll weighting ... NOT DONE").
Everything below is from reading code and docs, and from Python reads of the poll CSVs.
Items I could not confirm are marked **UNVERIFIED**.

## Headline

1. **The statewide poll files carry no sample size at all.** Not "poorly covered": there is no column.
   Sample-size weighting is a data-acquisition job first and a modelling job second.
2. Two premises in the question are slightly off. (a) The published trend does not *estimate* `sigma_obs`;
   it uses a fixed default. (b) The "0.2% for 33x" measurement was per-cycle *volatility*, not firm
   factors. Firm factors were measured separately: **worse by 0.6%, at 1.8x runtime**.
3. `weights = "firm_factors"` is a pollster-scatter weight learned within one cycle. It is not a track
   record against results, and it is not sample size. The cross-cycle version was never tested.

## 1. Where the trend is fitted, and how noise and house effects enter

- Entry point: `trend_as_at()` `R/projection.R:57-220`. It calls `fit_cycle_trends()` (`R/trend.R:492-509`)
  once per party, which calls `fit_trend()` (`R/trend.R:369`). Published callers: `scripts/fit_seats_full.R:438`,
  `scripts/build_trend_page_data.R:34`, `scripts/build_page.R:95`.
- **`sigma_obs` is not estimated on the published path.** `fit_trend()` takes `defs <- default_sigmas(scale)`
  when `sigma_obs` is NULL (`R/trend.R:377-380`). The default is 1.7 points translated to the logit scale at a
  35% share (`R/trend.R:275-280`). `trend_as_at(sigmas = "default")` passes no override (`R/projection.R:106`,
  only filled at `:107-126` for `"per_cycle"`).
- So it is **one value per party per fit, identical for every poll and every firm**, and because the logit
  conversion is fixed at 35%, a minor party's value is the same log-odds number whatever its size.
- Estimation machinery exists but is off the published path:
  - `estimate_trend_sigmas()` `R/hyperpars.R:33-79`: maximises the exact log marginal likelihood
    (`trend_solve()` `R/trend.R:204-237`, the `logml` at `:226`) over (`sigma_obs`, `sigma_rw`), summed over past
    cycles, L-BFGS-B via `optim_boxed()` (`:302`).
  - `estimate_cycle_sigmas()` `R/hyperpars.R:128-179`: per-cycle, shrunk to the pooled value on the log scale
    with weight `n/(n+k0)`, `k0 = 25` (`:161-163`), with a binomial floor argument (`:114-121`).
  - Used by `scripts/fit_vic.R`, `fit_federal.R`, `fit_nsw.R` only.
- House effects: one per firm, plus a pooled `"(other firms)"` effect for firms with fewer than
  `min_firm_polls = 3` polls **in this cycle** (`R/trend.R:31-37`, default at `:373`). Prior sd
  `sigma_house_pts = 3` points, the same for every firm, translated to the model scale at the party's observed
  mean share (`R/trend.R:38-50`, `:127-148`, `:207`). A poll-count-weighted soft sum-to-zero (`szc_sd_pts = 1.5`)
  pins the level (`:150-151`). Both 3 and 1.5 were chosen by held-out error (`docs/reviews/firm-weights-2026-08-16.md:72-73`).
- Firm identity in the CSV is the `Firm` column with era suffixes (`Newspoll`, `Newspoll2`, `Newspoll3`,
  `F2F Morgan`, `SMS Morgan`, `Morgan Phone`, `Morgan multi-mode`); each label is its own house effect.
- The solve: observation matrix `H` has a 1 in the latent-day column and a 1 in the firm column
  (`trend_obs_matrix` `R/trend.R:164-172`). Observation precision is the diagonal `w` at `R/trend.R:213`:
  `w <- 1 / (sigma_obs * obs_noise_factors(prep, firm_factors))^2`, times an optional Student-t `obs_weight`
  (`:214`). Posterior is `A = P + H'WH`, `b = b0 + H'Wy` (`:216-217`).

## 2. `weights = "firm_factors"` and the measurements

- `trend_as_at(weights = "firm_factors")` `R/projection.R:144-159`: fit once with equal weights, take that cycle's
  residuals, call `estimate_firm_factors()`, refit with the factors as `firm_factors`.
- `estimate_firm_factors()` `R/hyperpars.R:425-444`: pools each firm's squared residuals from the fitted trend
  (standardised by that fit's `sigma_obs`, all parties and cycles together), normalises to mean 1, shrinks the
  variance ratio toward 1 with `k0 = 12` pseudo-polls, clips the sd multiplier to [0.6, 2.0]. Enters the model
  through `obs_noise_factors()` `R/trend.R:176-181` and the `w` line above.
- **What it measures is scatter around the fitted trend, not error against election results.** A herding firm
  that sits on the trend looks *precise*, and a firm whose house bias is large looks fine (the house effect
  absorbs it). It is not a track record.
- `scripts/fit_vic.R:105-124` builds factors from *past* validation cycles (`estimate_firm_factors(past_fits)` at
  `:120`) and feeds them into `estimate_trend_sigmas`. That cross-cycle version is the closest existing thing to
  a record, but it is on the non-published path (`docs/reviews/vestigial-vic-fit-2026-08-16.md`), and it still
  uses trend residuals, not results.
- **The measurements** (both `build_projection_data()` held-out MAE over 195 election-horizon pairs, equal-weight
  arm 2.0588 each time):
  - Per-cycle volatility (`sigmas = "per_cycle"`): 2.0547, gain 0.0041 = 0.2%, runtime 34 s -> 1122 s = **33x**.
    `docs/reviews/backtest-model-comparison-2026-08-16.md:13-24`. Per-horizon signs alternate (noise).
  - Within-cycle firm factors: 2.0719, **gain -0.0131 (worse, 0.6%), runtime 33 s -> 61 s = 1.8x**. Better only at
    30 days (+0.0178), worse at 90/180/365/730. `docs/reviews/firm-weights-2026-08-16.md:9-35`. Pre-registered
    in `docs/plans/prereg-firm-factors.md` (bar 0.02 MAE, incumbent wins ties).
  - `CLAUDE.md` and `PETE-ASKED-FOR.md:38` fold these into "0.2% held-out gain, 33x runtime" for firm factors.
    That is a conflation; the firm-factor number is the second line. Suggest correcting both docs.
- **Never tested:** cross-cycle factors done honestly, per-poll sample size, any record measured against results.
  `prereg-firm-factors.md:30-49` and `firm-weights-2026-08-16.md:47-52` say so.

## 3. Do the polls carry sample size, sponsor?

- `load_polls()` `R/load_polls.R:15-63` reads `external/aus-polling-analyser/analysis/Data/poll-data-<region>.csv`
  and keeps only `MidDate`, `Firm`, `@TPP`, the `* FP` columns and (if present) `GLApp`/`GLDis`. Header of all six:
  `MidDate, Firm, Brand, @TPP, <party> FP ..., GLApp, GLDis, Comments`. **No sample size, no sponsor/client column.**
  `R/scales.R:21-30` already states this ("the source poll files carry no sample-size column") and uses an assumed
  `BINOMIAL_REF_N = 2500` / `BINOMIAL_SENSITIVE_N = 1500` for floors instead.
- Coverage (Python, `-I`, all six files): sample size **0% of rows in every jurisdiction**. Nothing to put in a
  coverage table, and no ranges or mashed numbers to clean, because there is no field. The `Comments` column is
  free text, mostly `#Date estimated` style notes (non-empty on 73/4003 fed, 23/472 nsw, 50/609 vic, 26/399 qld,
  138/318 wa, 11/292 sa); my regex for n-like strings matched only date notes, so no hidden sample sizes there.
  `Brand` is filled on 30/4003 fed and 0-5 rows elsewhere (e.g. "Newspoll", "YouGov"); not a sponsor.
- Rows per jurisdiction and firms: fed 4003/33, vic 609/26, nsw 472/21, qld 399/19, wa 318/17, sa 292/18. The
  biggest firms carry most rows (vic: Newspoll 170, F2F Morgan 110, Essential 41).
- Our own files that do carry `sample_n`: `demosau/crosstabs.csv` (`docs/DATA-DICTIONARY.md:115`) - but only 10
  polls (6 federal, 4 VIC; all 10 have a number, values 1007-2694); `newspoll-quarterly/breakdowns.csv:116`
  (federal breakdowns); `state-federal/state-federal-polls.csv:119` is *federal* polls by state, not state-election
  polls; seat polls (`seat_poll_blend.R:98`, 899 of 1,188 per `PETE-ASKED-FOR.md:37`) are a different series.
  **None of these cover the statewide state-election polls.**
- Sponsor: seat polls record `client` (`R/seat_poll_blend.R:69-72, 99`); statewide polls record none.
- **Consequence: item 4(a) needs new data.** Candidate source: the Wikipedia "Opinion polling for the next X state
  election" tables, which usually list sample size per poll and sometimes a "commissioned by" note. **UNVERIFIED**
  that coverage is high for the older (pre-2015) polls the backtest needs, and that the sample/sponsor columns are
  consistently present. Per `CLAUDE.md` keep the raw page and every column (`keep-raw-scraped-data`); fixed
  pre-election archive revisions only (`fixed-pre-election-sources`). Expect ranges ("1,000-1,500"), "~800", and
  "n/a" there, so the parser needs a rule: range -> midpoint, unparseable -> NA, never the digits of both ends joined.
  Join key will be (region, date, firm, ALP/LNP FP) because the CSV has no ID; budget a hand-review of unmatched rows.

## 4. Design

Both pieces slot into one line: the diagonal precision `w` at `R/trend.R:213`. Nothing else in the sparse system
changes (`P`, `H`, the Cholesky, the evidence formula).

### (a) Per-poll variance: non-sampling term plus sampling term

`var_i = sigma_obs^2 * f_firm(i)^2 + s_i^2`, `w_i = 1 / var_i`, with
`s_i^2 = deff / (n_i * q_i * (1 - q_i))` on the logit scale (`binomial_sd_link()` `R/scales.R:187-194` squared;
on the points scale `q(1-q)/n * 100^2`). Same shape as the seat-poll weight at `R/seat_poll_blend.R:134-141`
(`sv + floor`), which is the in-repo precedent.

- `sigma_obs` changes meaning: it becomes the *non-sampling* sd (house methodology, design effect, timing), not
  total noise. Its default must drop accordingly; otherwise sampling is double counted. Arithmetic for a 35% party:
  sampling sd is 1.69 pts at n = 800, 1.23 at n = 1500, 0.87 at n = 3000, against a total default of 1.7. So most
  of today's 1.7 is sampling for a typical n = 1000-1500 poll, and the spread in n across polls is the thing being
  added. Estimating the non-sampling part is the same kind of fit as `SEAT_POLL_FLOOR_PRIOR` (`:126`).
- `q_i`: **do not use the poll's own reading**. On the logit scale variance is larger for a smaller share, so a
  poll reading low would get less weight and the trend would be biased up (and vice versa). Use a value that does
  not depend on that poll's noise: `prep$p_ref` (`R/trend.R:50`), or better the pass-1 fitted trend at the poll's
  date (needs a two-pass; cheap, `want_var = FALSE`). Start with `p_ref`; test the fitted-trend version as an arm.
- Missing `n`: fill with the firm's median `n` from *earlier* polls in the data (the cycle up to `as_at` plus
  earlier cycles), else the pooled median; flag filled rows and report the share (a column of 100% filled values
  is the failure mode of `CLAUDE.md` "assert coverage"). This mirrors `n_fill` at `seat_poll_blend.R:128, 205-208`.
- Shrinkage, not cliffs: the firm multiplier `f_firm` is shrunk to 1 by pseudo-polls (below), and `n` for a firm
  with few observed `n` is pulled to the pooled median by `n_obs/(n_obs + k)`, not switched on a `min_n`.
- Evidence / `sigma_obs` estimation: the exact `logml` at `R/trend.R:226-227` already contains `0.5 * sum(log(w))`
  and `sum(w * y^2)` for arbitrary per-observation `w`, so `estimate_trend_sigmas()` (`hyperpars.R:57-67`) and
  `estimate_cycle_sigmas()` (`:144-147`) work unchanged *if* `trend_solve()` builds `w` from `(sigma_obs, f, s_i)`.
  Required changes: (1) pass a per-observation `sampling_var` vector in `prep` (`prep_trend_obs` `R/trend.R:11-69`
  attaches it from `n` and `q`) and have `trend_solve()` use `w = 1/((sigma_obs*f)^2 + sampling_var)`; (2) the
  bounds in `default_sigma_bounds()` (`hyperpars.R:400-404`) must be re-checked, because the lower bound 0.01
  logit was set for total noise and the new parameter is smaller; (3) `at_bound` hits become likelier and must not
  be waved through. The Student-t path (`R/trend.R:391-407`) divides residuals by `scale_i = sigma_obs * factors`
  and must use the same per-observation sd.
- Decision still needed from Pete: do we also publish `sigma_obs` as estimated rather than default? Today it is
  hand-set (1.7 pts at 35%, `docs/CONSTANTS.md`); `no-hardcoded-assumptions` argues for estimating it from earlier
  cycles' evidence (time-forward). That is a separate step with its own test (it was the per-cycle arm, 0.2%).

### (b) Track record: per-firm noise multiplier, time-forward, partially pooled

Is the existing `firm_factors` already (b)? **No**, for three reasons: it is estimated within the cycle being
forecast (`projection.R:128-143`) so it is not a record; it measures residual scatter around the model's own trend,
which rewards herding and ignores bias against results; and the cross-cycle version in `fit_vic.R` is off the
published path. It *is* the right plumbing: `obs_noise_factors()` (`R/trend.R:176-181`) multiplies the sd, and
the shrinkage-to-1 form (`hyperpars.R:441`, with `k0 = 12`, clip [0.6, 2.0]) is the style we want.

What (b) should be built from, in order of preference:

1. **Error of the firm's final-fortnight poll against the election result** (first preference, per party, converted
   to the model scale), one unit per (firm, election, party). Mean of squared error minus the sampling variance
   from (a) gives a non-sampling variance per firm; ratio to the pool gives a multiplier; shrink with
   `w = k/(k + n_firm_elections)` toward 1 (same family as `SEAT_POLL_FLOOR_K` and `estimate_cycle_sigmas`).
   Results come from `load_eventual_results()` (`R/fundamentals.R:96`). Because a firm typically has 2-6 state
   elections of record, expect heavy shrinkage; that is correct, not a bug (`CLAUDE.md` shrinkage section: a weak
   signal is safe to include).
2. Keep the within-cycle scatter factor as an *additional* term only if (1) leaves it unexplained; it was already
   measured to hurt (-0.6%).
3. Alternative channel worth one arm: per-firm **house-effect prior sd** instead of noise (`R/trend.R:148` uses a
   single `sigma_house`). Unbiased firms get a tighter prior and fewer degrees of freedom. A firm's bias magnitude is
   a track record too, and it is the part (1) lumps into noise.
- Firm keys: factors are looked up by raw `Firm` (`trend.R:178`) while house effects use the pooled
  `firm_eff` (`:34`). Era-suffixed names (`Newspoll2/3`, `Morgan Phone`, `SMS Morgan`) are separate firms with
  separate records; decide up front whether a record carries across suffixes (suggest: map to a parent firm, with
  a method-change penalty, and test both). New firms get factor 1.
- Sponsor: no data (section 3). Treat as out of scope until a source exists; the seat-poll `sponsored` floor
  (`seat_poll_blend.R:103`) shows it can matter, but only 34 of 1,188 seat polls were sponsored.

## 5. How to measure it

- **Decider:** `build_projection_data()` `R/projection.R:246-` over `horizons = c(30,90,180,365,730)` and the
  regions, with held-out MAE from `projection_loo()` (`R/projection.R:429`), exactly as the firm-factor and
  volatility comparisons were done (`scripts/compare_firm_weights.R`; same pre-registration pattern as
  `docs/plans/prereg-firm-factors.md`: bar 0.02 MAE, incumbent wins ties, coverage within 5%, zero `error`
  skips, per-horizon split reported, alternating signs read as noise). Add the arm as a new value of `weights`
  (`"sample_n"`, `"record"`, `"both"`) so `build_projection_data()` and `trend_as_at()` thread it through.
- Add a *direct* check that is more sensitive than MAE of the trend endpoint: for each (firm, election) the
  squared error of the fitted trend at the final-poll date; and calibration of the 95% band (`B2/B3`), since
  adding per-poll sampling variance changes the band width. Report n of pairs with every number (195 is small;
  the earlier MDE was already near 0.02).
- **Size the effect first** (`stats-discipline`): the weights only matter if `n` varies enough and sampling
  dominates. I could not compute that from our data because `n` is absent. First step of the build is to get `n`
  for a sample and look at its spread; if the interquartile range of `n` is narrow (say 1000-1500), (a) cannot
  move the trend much and the build should stop there.
- **Coverage guard:** the share of polls with an observed (not filled) `n`, per region and per cycle; backtest
  cycles before ~2005 may have almost none, which would make the arm look better on the recent cycles only.
  Report the held-out MAE on the subset with observed `n` as well.
- **Leakage traps:**
  1. Track record must use only elections strictly *before* the cycle under test, and only polls that were
     published and resolvable by then. `trend_as_at()` is called at `as_at` before polling day, so a firm's record
     from an election whose result is known at `cycle$start` is fine; the *current* cycle's result is not.
     In `build_projection_data()` use `as_of = cyc$start[1]` (the same pin used for preference flows at
     `projection.R:300-311`), and add an assertion that no record's election date is >= `as_at`.
  2. The `n_fill` median and the pooled `sigma_obs`/`k` must also come from earlier data only (same rule as
     `seat_poll_decay_params`, `seat_poll_blend.R:171-175, 195-196`: `elections_before(els, target)`).
  3. Leave-one-out is not time-forward: do not estimate firm records from all other elections including later
     ones (`CLAUDE.md` leakage item). `projection_loo` is leave-one-out for the *mix weight*; the record estimator
     must be walk-forward inside each fold.
  4. A firm's final poll error includes the true result; do not let the within-cycle residual factor and the
     record factor both see the current cycle's polls twice.
  5. Never score on the 2026 Victorian cycle itself; it has no result.
- Remember the runtime rule: the earlier decision keyed on cost (33x). The record arm is a table lookup at fit
  time (the heavy part is building the past-election error table once, then caching it, per `profile-before-long-runs`),
  so expect about 1x the equal-weight runtime, not 33x.

## Recommended build and rough hours

Order matters; stop at the gate after step 1.

| # | Task | Hours |
|---|---|---:|
| 1 | Acquire statewide `sample_n` (+ client where present) for state-election polls, raw page kept, parse rules for ranges/approximate values, join to the poll CSV, coverage table per region and cycle, regenerate `docs/DATA-REGISTRY.md`/`DATA-DICTIONARY.md`. **Gate:** if observed `n` covers under ~50% of 2010+ polls or has little spread, stop and report. | 8-12 |
| 2 | Plumbing: carry `n`, `n_filled` through `load_polls()`/`cycle_polls()`/`prep_trend_obs()`; per-observation `sampling_var`; change `w` in `trend_solve()` (and the Student-t scale) to `1/((sigma_obs*f)^2 + s_i^2)`; revisit `default_sigma_bounds()` and default `sigma_obs` meaning; update docs/CONSTANTS.md; `devtools::document()` in the same commit. | 4-6 |
| 3 | Pre-register (grid, bar 0.02, coverage, nominal criteria above) then run arm `"sample_n"` in `build_projection_data()` + `projection_loo()`. | 3-4 |
| 4 | Track record table: past-election final-poll errors by (firm, election, party), time-forward shrunk multiplier, cached; wire as `firm_factors`; arm `"record"` and `"both"`; leakage assertions and tests (synthetic data where a known-bad firm is penalised; a deliberately leaked record must fail the assertion). | 6-8 |
| 5 | Optional: per-firm house-effect prior sd arm; estimate published `sigma_obs` from earlier cycles. | 3-4 each |
| 6 | Tests (including `scripts/check_like_ci.R` as per `CLAUDE.md`, with no anchor data), NEXT-STEPS/DECISIONS/register updates, correct the "0.2% / 33x" wording in `CLAUDE.md` and `PETE-ASKED-FOR.md:38`. | 3-4 |

Total about 24-34 hours for steps 1-4 and 6; most of the uncertainty is step 1.

## Expectation, on the record

Prior evidence is unfavourable: the three previous "weight polls more cleverly" changes gained 0.2%, -0.6% and
0.0% on this metric (`firm-weights-2026-08-16.md:66-76`; `nu = 4` also did not help, `R/trend.R:343-348`). Sample
size is the one input not yet tried and is on firmer physical ground than a fitted noise factor, but the 195-pair
test cannot resolve gains below about 0.02 MAE (1%), so the realistic outcomes are "no detectable change in point
accuracy" and "narrower, better calibrated bands". Decide the success criterion with Pete before running, including
whether band calibration alone justifies shipping.
