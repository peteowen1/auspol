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

Last audited 2026-08-21; two rows added 2026-09-06 (below, "Added 2026-09-06") after a documentation review found them missing.

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
| `SEAT_POLL_TOTAL_TOL` | `seat_poll_blend.R` | 5 points: a poll whose primaries sum to 100 +/- 5 without a duplicated Nat figure, and above 105 with it, has the Nat figure dropped as a merged-cell copy (`AUSPOL_SEAT_POLL_COALITION_DEDUP`, shipped 2026-10-07). | **CHOSEN**: Wikipedia primaries are rounded to whole points, so complete polls sum to 97-103; the one case (fed2022 Nicholls) is 141 vs 100. Not estimable: there is one duplicate in 1,210 polls. |
| `SEAT_POLL_IND_MAP_MIN_OTH` | `seat_poll_blend.R` | 10 points: a poll's OTH figure at least this big, with IND blank and an IND candidate in the seat, is read as the independent (`AUSPOL_SEAT_POLL_IND_MAP`, off). | **CHOSEN** from the fed2022 YouGov table (genuine catch-all OTH 2-8; teals 17-24). Misses Bradfield (5) and Calare (11, excluded by the next constant). Could be estimated once more than one MRP house leaves IND blank. PREREG PENDING. |
| `SEAT_POLL_IND_MAP_KNOWN_FRAC` | `seat_poll_blend.R` | 0.5: skip the remap when one of our OTH/OTH_RIGHT/ONP as-at predictions is at least this fraction of the poll's OTH figure (Katter in Kennedy). | **CHOSEN** by hand so Kennedy and Bass skip while Goldstein and Mackellar remap; as-at predictions only. Not fitted. PREREG PENDING. |
| `PUBLIC_SEAT_POLLSTERS` | `seat_poll_blend.R` | Pollsters whose direct seat polls count as independent under `AUSPOL_SEAT_POLL_SOURCES="public"` | **CHOSEN BY PETE 2026-09-29** (allowlist over a sponsor-only filter); being tested, `plans/prereg-seat-poll-public-only-2026-09-29.md`. Not estimable: it is a definition. |
| `AUSPOL_SEAT_POLL_PRIOR` | `seat_poll_blend.R` (`.seat_poll_prior()`) | Prior mean for the seat-poll blend weight; "0" (shipped) shrinks the fitted weight toward 0, so an election with no earlier polled cells blends nothing (fed2016, fed2019). Arm value 0.75. | **CHOSEN BY PETE 2026-10-09**, knowingly hindsight-informed (fed2022's fitted weight was 0.751). Combined by precision with the time-forward slope, so it fades as polled elections accumulate (vic2026: 0.373 -> 0.394). ARM, screening. |
| `AUSPOL_SEAT_POLL_PRIOR_SD` | `seat_poll_blend.R` | 0.25: sd of that prior ("weak"). One earlier election at se 0.35 moves the weight about a third of the way to its own slope. | **CHOSEN** (2026-10-09) to make Pete's "weak prior" a number. ESTIMABLE in principle from the spread of per-election slopes once more polled elections exist (six now). |
| `SEAT_POLL_HALFLIFE_PRIOR` | `seat_poll_blend.R` | 60 days: prior half-life of a seat poll's recency weight under `AUSPOL_SEAT_POLL_DECAY` (replaces the 90-day hard window). | **CHOSEN BY PETE 2026-10-09** as a prior; the half-life itself is **ESTIMATED** time-forward (`seat_poll_decay_params()`, SPD line): fed2025 54 days, sa2026/vic2026 34. |
| `SEAT_POLL_HALFLIFE_LOGSD` | `seat_poll_blend.R` | 0.7: prior sd of log(half-life); 2-sd range 15-245 days. | **CHOSEN** (2026-10-09) to make the prior weak. |
| `SEAT_POLL_FLOOR_PRIOR` | `seat_poll_blend.R` | 16 points^2 (sd 4): non-sampling error variance of a seat poll before any data. | **CHOSEN**; the floors per group (mrp/direct/sponsored) are **ESTIMATED** time-forward and shrunk toward it (vic2026: 5.4 / 5.1 / 6.5 sd). |
| `SEAT_POLL_FLOOR_K` | `seat_poll_blend.R` | 10 pseudo seat-elections pulling each group's floor toward the pooled floor. | **CHOSEN** (2026-10-09). ESTIMABLE as a between-group variance once groups are larger. |
| `SEAT_POLL_N_FALLBACK` | `seat_poll_blend.R` | 600: seat sample size for a direct poll with none recorded, only when no earlier direct poll records one (otherwise the earlier median, ~750-800). | **CHOSEN**; overridden by data from fed2019 on. |
| `SEAT_POLL_MODEL_VAR_PRIOR` | `seat_poll_blend.R` | 25 points^2 (sd 5): our seat primary error before any polled election, for `AUSPOL_SEAT_POLL_PRECISION_BLEND`. | **CHOSEN** from the AEF-7 ledger's primary RMSE (5.13); per-class values are **ESTIMATED** time-forward and shrunk toward it (`seat_poll_model_var()`). |
| `k0 = 25` | `hyperpars.R` | Shrinkage of per-cycle sigmas toward pooled | **CANNOT BE TUNED ON FORECAST ERROR — it does not reach the forecast.** See §6c. |
| `FP_EXTRA_SD = 2.419` | `fit_seats_full.R` | Statewide first-preference error the trend posterior does not contain, added in quadrature | **ESTIMATED, ADOPTED 2026-08-19.** Coverage of the raw band is 69.8% at a nominal 95%; the structure (additive in points, not multiplicative) was chosen by testing alternatives against the residuals, and the value is the two-party projection error pre-registered in `prereg-fp-widening-choice.md`. See `reviews/fp-widening-choice-2026-08-19.md`. |
| `SEED = 42` | `fit_seats_full.R` | Simulation seed | **FIXED.** Overridable via `AUSPOL_SEED` only so a change can be checked for stability across seeds. |
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
| `95`–`105` | `load_polls.R:76` | Sanity bound on reported FP sums |
| `> 0.02` | `load_polls.R:81` | Share of malformed rows tolerated before erroring |
| `n > 100`, `< 60`, `< 380` | `load_polls.R:70,103`, `fundamentals.R:108` | Row-count floors that catch `fread` stopping early on a ragged row — the bug that once trained the fundamentals on 62% of the data |
| `min_year = 1990` | several | Start of the modern polling record |
| `min_polls`, `min_firm_polls` | several | Minimum data before fitting |
| `PARTY_INCLUSION_FLOOR = 8` (`scales.R`) | `fit_vic.R:184,196`, `fit_nsw.R:105,200,256,269`; `>= 25` federal | **Which parties exist in the forecast at all** — not an input-sanity guard, which is how it was filed until 2026-08-19 and why nobody looked at it. A party under the floor is not fitted, so its vote stays inside `OTH`. Lowering it is monotonically worse (tested 2026-08-19). **Tried at 15, reverted, both 2026-08-24** (`plans/prereg-inclusion-floor-15-adoption.md`): floor 15 beats 8 by 0.061 MAE, three times the adoption bar, but folds One Nation from NSW 2027 (21.0% on 8 polls) into `OTH`, where a party polling in the twenties cannot be told apart from the rest. Adopted first with that cost disclosed (Victoria 2026, the only published forecast, is unaffected — verified byte-identical), then reverted: a live-cycle party going invisible is not acceptable even in an unpublished cycle. `scripts/test_inclusion_floor.R`'s anchor check (`IF6`) is what surfaced this, unweakened, and stays wired in for any future attempt. Extracted into a single named constant regardless of the reverted value, replacing four independent hardcoded `8`s this file had already flagged as a sister-copy risk. `fit_vic.R:115` AND `fit_nsw.R:116` each carry a separate `parties_in(n = 8)` default (validation-cycle noise-factor estimation, not the live party set) — a distinct constant, currently at the same value by coincidence rather than by the same name. |
| `warn_days = 21`, `stale_days = 60` | `freshness.R:63` | When our copy of the poll data is old enough to warn, then stop |
| `SHARE_CLAMP = c(0.25, 99.75)` | `scales.R:19` | Keeps logit finite at the boundary |
| `EXHAUST_LIMIT = 0.02` | `fetch_preferences_wa.R` | Exhaustion rate above which an election's transfers may not be pooled with full-preferential ones. NSW runs ~12% and is excluded outright; the seven admitted WA elections run 0.15–0.88%. **FIXED, and deliberately not raised**: WA 2001 measured 2.27% and was named in `TRANSFERS_EXCLUDED` instead, because moving a threshold to admit the one election that failed it is choosing the number after seeing the answer. |
| `TRANSFERS_EXCLUDED = "wa2001"` | `fetch_preferences_wa.R` | The named consequence of the line above. Its first preferences and winners are still used — exhaustion cannot affect either. |
| `WA_PARTY` (39 codes) | `fetch_preferences_wa.R` | Party code → name, because the WAEC publishes a code and no name and a bare code classifies as OTH. **FIXED, and machine-checked**: WF1c requires every name to be one the WAEC itself publishes, WF5 requires our winners to reproduce its declared seat counts, and an unknown code aborts. |
| `EXTERNAL_FLOWS$*$dates` (9 dates) | `external_flows.R` | Polling days for the Queensland and Western Australian elections, deciding what a backtest may see. **FIXED and hand-entered** — neither commission publishes a machine-readable polling day with its results — so each is checked against the year in its own election key, which catches the mistyped year that hand-entered tables actually suffer. |
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

## 4b. The candidate-level seat path (added 2026-08-18)

These live in `scripts/fit_seats_full.R` and the three functions it calls. The
path does not feed the published page, but the rule applies the same: a
constant absent from this file is a bug in this file.

| constant | value | where | status |
|---|---:|---|---|
| `SMOOTH` | 0.15 | `distribute_preferences()` | **FIXED, and load-bearing** |
| `min_n` | 3 | `build_flow_matrix()` | **FIXED** — judgement |
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
| `SHRINK = 0.01` | `fit_seats_full.R` | Per-draw calibration shrink toward a coin toss in close seats. Added 2026-08-21 at 0.10; **lowered to 0.02 on 2026-09-06**. A scalar shrink caps every seat at `1 - shrink/2`, so 0.10 meant no seat could be called above 0.95 — measured max p was 0.9505 with 19 of 150 federal seats against that ceiling, costing ~0.006 of mean log loss on the cap alone. Swept on fed2025: 0.10→0.3042, 0.05→0.2933, **0.02→0.2891**, 0.00→0.2914. Three seeds at 0.02 mean 0.2886 against AE Forecasts' 0.3025. Validated election-wide before shipping: federal mean log 0.4154→0.4047 (better in 5 of 6 pairs, Brier in 6 of 6), Victoria 0.3020→0.2997, NSW 0.4062→0.3822, SA 0.3976→0.3857, WA accuracy 87.0%→87.3%. **Lowered again to 0.01 on 2026-09-06**: six federal pairs give mean log loss 0.10=0.4154, 0.02=0.4047, 0.01=0.4096, 0.00=0.4282, and 0.02's edge over 0.01 is one seed and not established as significant while 0.01 has the best mean Brier (0.0982). Stays NON-ZERO because 0.00 costs 0.0235 of mean log loss against 0.02, concentrated in fed2013 (+0.0975) and fed2022 (+0.0243) — a risk invisible on fed2025 alone. Expected to be superseded by the per-seat `AUSPOL_INSURGENCY_SHRINK`. | **ESTIMATED** — swept on held-out log loss, then checked election-wide as a do-no-harm guard. |
| `LAMBDA = 0.5` | `estimate_statewide_cov.R:215` | Shrinks the statewide party-correlation matrix toward independence. Written to `cor_shrunk`, which `R/statewide_cor.R:48` reads for `fit_seats_full.R` **by default**, so it shapes the published joint distribution over party votes. | **FIXED, pre-registered.** Half weight on a correlation estimated from few cycles; the alternative was to estimate the shrinkage from the same small sample that produced the correlation. |
| `1.96` | `trend.R:423,424`, `projection.R:526`, `fit_seats_full.R:545,552` | The Gaussian 95% quantile, used to build the published bands and to turn a band back into a simulation sd. | **FIXED, and worth flagging**: §6c records that the model deliberately does *not* assume the error distribution is normal, yet this constant assumes it at five sites. A correctness matter, sized before it is worth changing. |
| `SA_RESPONSE` (6 coefficients) | `fit_seats_full.R:630` | Where a party's statewide gain or loss comes from, fitted on South Australia 2026. `LNP −0.846, ALP −0.123, IND −0.086, OTH_RIGHT −0.074, GRN 0.063, OTH 0.065`. Reached only under `AUSPOL_FORCE_FP`, so **not on the default publish path**. | **ESTIMATED** from one election, which is its weakness. |
| `ANCHOR_K = 0` | `trend.R:82` | Weight on the previous election result as an anchor for the trend, defaulting `trend_anchor()` and `fit_trend()` — both on the published path. | **FIXED at 0.** Built and refused on a wrong theory; see `reviews/poll-lag-2026-08-19.md`. Same tested-and-kept shape as `sigma_house_pts` in §6b. |
| `1.5` party-sd fallback | `fit_seats_full.R:1401` | Used when a party has no estimated statewide sd. | **FIXED**, and it should be visible when it fires: a fallback nobody sees is a number nobody checks. |
| `0.489` flow fallback | `fit_seats_full.R:576,1490` | Preference rate used when the matrix has no cell for a pair. | **FIXED**, same caveat. |

Also absent and lower priority, none on the default publish path: `TARGET`,
`TOL`, `N_REP`, `FLOOR_R` in `calibrate_onp_ordering.R:18-21`; `VIC_MEAN = 20.2`
and the `tgt` vector in `compare_onp_seats_sa.R:68` and `:105`, which are frozen
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
| Candidate-conditional slope defaults (`same` / `new` per class) | `R/dev_slope.R:138-140` | IND 0.907 / 0.326, OTH_RIGHT 0.891 / 0.325, others per the table in the roxygen | **ESTIMATED once, then frozen in code -- the fitting script now EXISTS.** `fit_conditional_slopes()` (`R/split_slope.R`), built 2026-09-09, refits all eight leave-one-election-out and checked each against its own definition: IND is fine (0.374 vs 0.326, 0.882 vs 0.907), but OTH_RIGHT is wrong in OPPOSITE directions (0.442 vs 0.325, +3.1 SE; 0.766 vs 0.891, -3.8 SE) and ONP "same" is off on 51 observations (-2.7 SE). The arm to REPLACE these frozen constants with the fit was pre-registered, run, and **REFUSED** (`docs/plans/prereg-fit-conditional-slopes-2026-09-09.md`: pooled log loss FAIL, panel FAIL) -- root cause was fed2013's OTH_RIGHT surge (Palmer United's debut), where the frozen `0.325` correctly shrinks hard toward the statewide level for a class with no local history, and the fit's `0.442` does not. So the CONSTANTS remain frozen, correctly, pending a slope that also conditions on surge status -- not for want of a fitting script anymore. The sitting-member tier (`AUSPOL_MP_SLOPE=1`, `output/mp-slope-by-*.csv`) overrides these for sitting members only. |
| Sitting-member slope tier (`output/mp-slope-by-class.csv`) | `scripts/fit_seats_full.R:879`, via `AUSPOL_MP_SLOPE=1` | IND 0.943 (n=53), GRN 1.034 (n=21, excluded — indistinguishable from its also-ran slope), OTH_RIGHT 0.959 (n=14), ONP/OTH excluded by the n>=8 floor | **FITTED, and the only `output/` file tracked in git.** Produced by `scripts/fit_mp_slope.R` from `output/candidacies.csv`; all-data per class, which is leak-free here because vic2026 has not happened (a backtest must instead use the target-keyed `mp-slope-by-target.csv`). Committed copy fit 2026-09-13. **Tracked because of a CI deadlock, not because a generated file belongs in git**: `fit_seats_full.R` hard-stops without it under the published default, but CI cannot build it (needs `candidacies.csv` -> `build_candidacies.R` -> `external/reference/` dirs CI never populates), and it cannot be switched off either, because `fit_seats_full.R` refuses to write published filenames under a non-published config. That took the nightly Forecast refresh down for six runs, 2026-09-10 to 09-14. **REFIT (`Rscript scripts/fit_mp_slope.R`) whenever `candidacies.csv` changes**, and drop the `.gitignore` exception once `build_candidacies.R` runs in CI. |
| `AUSPOL_SEAT_SD_MULT` | all five `scripts/backtest_candidate_*.R` | default 1 | **FIXED** — a diagnostic multiplier on whichever seat spread is in force (`level_sd` when on, else `seat_sd`), for the pre-registered calibration arm B. Not read by `fit_seats_full.R`. Inert in four harnesses from 2026-08-27 to 2026-09-06 while printing "applied"; the arm B sweeps in that window measured nothing. |
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

## New-independent shrink (AUSPOL_NEW_IND_SHRINK, OFF, prereg pending)

| constant | value | status |
|---|---|---|
| `prior_max` in `new_ind_cells()` | 10 share points | **INHERITED from `docs/reviews/vic-ind-overcall-2026-10-06.md`** (its "departed class leader, class prior 10 or more" row is a different population with its own, refused, rule). A cell definition cut, not a fitted value; the data could set it (n of departed-leader cells is 12, too few to fit). |
| the factor | fitted per target | **FROM DATA**: ratio of sums of actual to base_pred over earlier new-independent cells, partially pooled by jurisdiction (DerSimonian-Laird tau^2), bounded [0, 1]. No constant. |
| design effect for a one-election jurisdiction | measured | **FROM DATA**: clustered SE / cell-level SE on the all-jurisdiction fit. |
