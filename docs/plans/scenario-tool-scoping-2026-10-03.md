# Scoping: a "what if" scenario tool for the Victorian 2026 forecast (ITG page)

Written 2026-10-03/04. READ-ONLY scoping: nothing was run (memory is tight), no
code changed. Every claim about code carries `file:line` as of branch `dev` at
7c9ea34. Time claims are marked **[LOG]** (read from a log or the runtime log),
**[INFER]** (arithmetic on log timestamps) or **[GUESS]**.

Pete's ask: pick a party (ONP, ALP, LNP, GRN), set its STATEWIDE first-preference
share anywhere from 10 points below to 10 above today's projection, and see
expected seats per party, every seat's win probability, P(majority), P(hung)
and P(One Nation balance of power). He chose a live slider over a precomputed grid.

---

## 1. One-page summary

**What the slider has to move.** The statewide first-preference level (`state_mean`)
is a single named vector of five classes (ALP, LNP, GRN, ONP, OTH) at
`scripts/fit_seats_full.R:522`. It reaches the seats through ONE path: it is the
input to the seat-share chain (`:1060-1197`), which produces an 88 x 7 matrix of
projected primaries. The Monte Carlo (`:1464`) then only adds deviations around
that matrix. So a scenario = a different `state_mean` -> a different 88 x 7
share matrix -> a re-run of the 17-25 s simulation **[LOG]**.

**A switch for this already exists.** `AUSPOL_FORCE_FP="ONP=30"`
(`fit_seats_full.R:593-620`) overwrites `state_mean` and rebalances the other
parties, then the whole published pipeline runs. It was built in August for exactly
"seat count as a function of the primary vote" (`docs/backlog/journal-2026-08-19-to-23.md:444`).
It writes suffixed output files so it cannot overwrite the published forecast
(`fit_seats_full.R:384-390`). Cost of one run: about 142 s wall **[LOG]** (the
runtime log has two foreground runs at 144 s and 142 s, 2026-09-27).
Caveat: its rebalancing rule is ONP-specific and not suitable for the other
three parties as written (section 4a).

**Where the time goes.** About 120 s of the 142 s is NOT the simulation
**[INFER]**: loading, poll trend, fundamentals, candidate and salience features.
The simulation is 17-25 s at 20,000 draws **[LOG]**. The xgb primary model load
and everything after it takes roughly 25-30 s of which 17 s is the simulation
**[INFER from live-ship.log timestamps 13:02:36 and 13:02:43 and an end near 13:03]**.
Peak memory was NOT measurable from any log (unconfirmed).

**Options.**

| | what it is | live feel | faithful to the model | engine to build | daily compute |
|---|---|---|---|---|---|
| A. True live | scenario engine running per request | yes | depends | R server (not recommended) or JS port | none per request |
| **A' (recommended)** | seat-share matrices precomputed at knots (2.5 or 1 point steps) by the real R pipeline, plus an in-browser JS port of the simulator | yes, any slider position, can combine parties | high, except preference flows are held at today's values | JS port, about 250-300 lines | about 6-20 min extra **[GUESS]** |
| B. Fine grid | full R results precomputed at 0.5-point steps (41 x 4 = 164 runs), interpolated in the browser | feels live for one slider | highest (flows recomputed) | none | 41-82 min even with a shared prefix **[GUESS]**; 6.5 h naive **[LOG-derived]** |

**Recommended path: A' in two stages.**

1. **Stage 1 (about 8-10 h [GUESS], almost no model code):** run the existing
   `AUSPOL_FORCE_FP` once per knot (9 knots x ONP = 9 runs, about 21 min **[LOG-derived]**),
   publish the results as a coarse interpolated slider. This proves the numbers
   look sane (including whether the xgb layer behaves 10 points outside its
   training range) and the output files become the test oracle for stage 2.
2. **Stage 2 (about 30-40 h [GUESS]):** knots exporter plus JS simulator plus
   slider UI, validated against stage 1 outputs.

**Total about 40-50 h [GUESS]; stage 1 alone about 8-10 h.** Risk: medium.
Main risks: (a) the refactor of the published script to loop scenarios (mitigation:
do not refactor; call the script's env switches or build a separate script
and prove default output byte-identical); (b) the ONP seat allocation shape is the
model's weakest, unvalidated assumption and the slider will lean on it hard at
the top of the range; (c) preference flows held fixed in the engine.

**Decisions to put to Pete (section 5):** (i) hold the moved party exactly at X
(recommended) or keep the usual +-2.5 point statewide spread around X; (ii) how
the other parties give way: the model's own covariance (recommended) versus
the South Australia pattern versus proportional.

---

## 2. How the statewide vote reaches the seats (exact mechanism)

All line numbers `scripts/fit_seats_full.R` unless stated.

### 2a. Where the level is made

1. Poll trend per party: `trend_as_at()` at `:399`; last point per party at `:496`.
2. Two-party projection `pj` (mean 47.93, sd 2.465 in the 2026-09-28 log) from
   trend plus fundamentals at `:504`. This is the calibrated object.
3. `sw` = the five fitted classes (`:509`); `state_mean` (`:522`) and `state_sd` (`:523`).
   Statewide sds are 2.52-2.63 points **[LOG: "FP sd mode: additive; statewide sds
   2.52-2.63", live-ship.log]**, built as sqrt(trend sd^2 + extra^2) (`:513-514`).
4. Closing to 100. With the published flag `AUSPOL_LIVE_LEVEL_ANCHOR="0"`
   (`published_flags.R:622`, v56) the level is the trend endpoints rescaled to sum
   100 (`fit_seats_full.R:557-563`); the projection does not pull ALP/LNP. (The
   older anchored behaviour, `:548-578`, is still in the file and was what the
   2026-09-28 logs show.) So the slider's "today" values are `state_mean` after this
   rescale (for example OTH 12.65 in the log), not the raw trend endpoints, and
   not exactly the `fp_now` numbers in `vic-page-data.json` (which show OTH 11.0).
   This must be explained on the page or the slider's zero point will not match
   the headline numbers.
5. The forced-level hook is `:593-620` (section 4).

### 2b. From level to seat shares (the only place the level enters the seats)

Everything below consumes `state_mean`; each line is something a scenario
re-computes:

| step | what it does with `state_mean` | line |
|---|---|---|
| uniform swing with per-class slope | `shares[,p] = dev_slope(x, a22[p], state_mean[p], slope)` for ALP, LNP, GRN, OTH (all but ONP) | `:1063-1066`; `R/dev_slope.R` |
| the unpolled bucket (IND, OTH_RIGHT, OTH) scaled to the OTH total | `scale_to = state_mean[OTH] / base_share` | `:1075-1095` |
| ONP written over | `onp_target = state_mean[ONP] * onp_ratio[seat]`, capped at 80; ratio is the SA-2026 quantile shape ordered by federal ONP vote (CV 0.365) | `:1118`, ratio built `:650-665` |
| others scaled to fill what ONP leaves, rows renormalised | `fill = (100 - onp_target)/rest` | `:1119-1126` |
| xgb primary correction | `base_margin = base_pred` and a feature `level_pred = state_mean` | `:1139`; `R/xgb_primary_override.R:239,571` |
| post-xgb adjusters, each a function of `shares` | seat-swing port, seat-poll blend, demographic, leader seat, departed-member (off), salience point blend | `:1149-1197` |
| per-seat xgb preference flows | built FROM `shares` (to_primary / from_primary features) | `:1455`; `R/xgb_flow_override.R:193,294` |

### 2c. Statewide draws: only the deviations matter

- `sw_draws` (`:1283-1294`): Cholesky of the shrunk statewide correlation (`:1243-1260`,
  cor(ONP,LNP) target -0.38, realised -0.41 **[LOG]**) times the sds, plus `mu`
  (`:1262-1282`), clamped at 0.1, renormalised to 100.
- Anchored so the draws' two-party figure is N(pj$mean, pj$sd): `d = target - implied`
  added to ALP and subtracted from LNP (`:1327-1347`), checked at `:1355`.
- `simulate_seat_contests()` then subtracts the column means: `centre <- colMeans(statewide_draws)`
  (`R/seat_sim.R:980`), `shift_mat <- sweep(statewide_draws, 2, centre)` (`:1072`);
  the R-engine twin is `:1197`. **So the level in `mu` and the anchoring's mean shift never
  reach a seat; only each draw's departure from the centre does.** This is why
  `AUSPOL_FLOW_SHIFT` was found inert on the draws (`fit_seats_full.R:336-342`).
- Consequence for a scenario: the level goes in through the share matrix (2b); the
  draws supply the spread. Moving `state_mean` alone is enough; there is nothing to
  inject into `sw_draws` for the mean.

### 2d. What is held fixed in a forced run (not re-derived from X)

Polls and trend sds, the covariance matrix (`:1251`), the two-party projection and
its sd (`:1327`), preference-flow table `fl` (`:330`) and the flow matrix, surge
hazards (no `state_mean` use in `:665-1007` per grep; `.hz` is built from the
salience corpus), candidates, 2022 baselines, the ONP concentration shape
(`:658-665`), the calibration shrink 0.01 (`:1421`), `level_sd` a=1.10 b=8.67
(`:49`). Not verified by a run.

### 2e. What goes into the C++ core (`src/seat_sim_core.cpp`) and where it comes from

Signature `:25-39`. Inputs: the 88 x 7 `shares`; `shift_mat` (n x 7 centred
statewide departures, `R/seat_sim.R:1072`); per-cell seat sd matrix (`sd_cell_pre`,
`:989-992`: a + b*mult*sqrt(p(1-p))); surge vectors (hazard, recipient index,
mu, sd per seat); dense preference tables, 1024 rows x 7 each for `cell_mat`,
`ss_mat`, plus `pool_mat` and `pw_mat` (K=7, `n_slots = (K+1)*2^K`, `:760`;
built `:1048-1070`); per-seat override rows (88 x 484 keys, sparse, `:1086-1171`);
flow sd vector, smooth, fallback smooth, shrink 0.01. None of these except
`shares` is written to disk today (`:1558-1561` write shares, probs, totals only).

---

## 3. Cost split: heavy part vs cheap part

**[LOG]** `output/live-ship.log:93`: "simulated 88 seats x 20000 runs in 17s".
Other logs: 20, 21, 21, 21 s (`live-ll0/ll1/ll3off/ll3on.log`), 25 s
(`live-smoke-port2.log`). So the simulation is **17-25 s per 20,000 draws**.

**[LOG]** `~/.claude/runtime-log.csv`: the two foreground whole-script runs
(2026-09-27T14:39:52Z `-ll3off`, 14:43:06Z `-ll0`) took 144 s and 142 s.

**[INFER]** The ~120 s before the simulation is data loading and feature building
(package load, polls, trend fit, fundamentals, candidate and salience features,
flows). The live-ship log timestamps show the xgb primary model loading at
13:02:36 and the xgb flow model at 13:02:43; the log file's last write is 13:03.
So from the primary model load to the end is about 25-30 s, of which 17 s is the
simulation. Stage times inside the first 115 s are not logged.

**Not confirmable:** peak memory of `fit_seats_full.R`. The simulation itself holds
`fp_draws` (20,000 x 88 x 7 doubles, about 99 MB, `R/seat_sim.R:944`, only because
`keep_fp = TRUE` at `fit_seats_full.R:1471`) plus three 20,000 x 88 TCP matrices
(about 28 MB) **[arithmetic]**. A scenario run should pass `keep_fp = FALSE`.
CI job: `timeout-minutes: 45` (`forecast.yaml:42`); actual job duration is not in
any file I read (unconfirmed).

**Brute-force arithmetic [LOG-derived]:** 142 s x 164 runs (41 steps x 4 parties) =
6.5 h; x 84 (1-point steps) = 3.3 h; x 36 (2.5-point knots) = 85 min; x 9 (ONP only)
= 21 min. These run sequentially because memory is tight.

**What is cheap and can be factored out [GUESS]:** with the shared prefix (everything
before `:1060`) run once, one scenario costs the chain (`:1060-1197`, seconds),
optionally the flow override (about 7 s [INFER]) and the simulation (17-25 s at
20,000; about 4-6 s at 5,000 draws [GUESS, linear in draws]).

---

## 4. The modelling mechanics for a scenario

### 4a. What `AUSPOL_FORCE_FP` does today, and its limits (read, not run)

Block `:593-620`:

- Sets the chosen party to X, then moves the others by `fp_delta * resp`, where
  `resp` = the six South Australia 2026 coefficients (`SA_RESPONSE`, `:590-591`;
  LNP -0.846, ALP -0.123, IND -0.086, OTH_RIGHT -0.074, GRN +0.063, OTH +0.065)
  restricted to classes in `state_mean`, with the chosen party removed, divided
  by the sum of absolute values.
- IND and OTH_RIGHT are not in `state_mean` (they are in the unmodelled bucket,
  `:1074`), so their coefficients silently drop out; ONP is not in `SA_RESPONSE`
  at all.
- **The comment says the total stays 100; by my arithmetic it does not.** For
  ONP +10: normalised responses LNP -0.771, ALP -0.112, GRN +0.057, OTH +0.059, signed
  sum -0.767, so `state_mean` sums to about 102.3. Later steps renormalise each seat row
  (`:1126`), which absorbs it proportionally. Needs a run to confirm.
- **For any party other than ONP the rule is not meaningful.** Forcing LNP down 10
  gives ALP +4.9, GRN -2.5, OTH -2.6 (the SA numbers re-weighted), and forcing ALP
  or GRN leaves ONP unmoved. The SA coefficients describe "ONP rises", nothing
  else (`docs/CONSTANTS.md:201` also marks it ESTIMATED from one election; its
  line reference ":240" there is stale, the block is at `:590`).
- Moved before the xgb layer, so the xgb layer sees the new `level_pred` and
  `base_margin`. The flows are recomputed from the new shares (a faithful run).
- Keeps the usual statewide sd around X: `mu` is the forced `state_mean`
  (`:1263`) and `psd` is unchanged (`:1222`).
- Refuses to write the published filenames: needs `AUSPOL_OUT_SUFFIX`
  (`:384-390`); `AUSPOL_FORCE_FP` default is `""` (`published_flags.R:314`).
- Applied after the level anchor, by design ("a forced vote must stay forced",
  `docs/plans/prereg-live-level-anchor-2026-09-28.md:49`).
- Last documented use is August (journal: the old curve read 0 seats at 12%, 5 at
  20.2%, 16 at 26%, 26 at 30% for ONP). That is a DATED snapshot of an older model
  (before the live xgb layer), do not quote it. Whether FORCE_FP still runs
  end-to-end on today's `dev` is unconfirmed.

### 4b. Where to inject "assume ONP statewide = X"

Same place as `FORCE_FP`: directly after `:578`/`:563` (state_mean final), before
`:1060`. Everything downstream follows (section 2b). No change to the simulator or
draws is needed for the mean. Only the spread question (5a) touches the draws.

### 4c. Do seat baselines get re-derived or shifted?

Re-derived. The chain recomputes each party's seat share from its 2022 seat share
and the new statewide figure (uniform swing with class slopes), re-allocates ONP
from the fixed concentration shape, then the xgb layer adds a learned correction.
So the response is nonlinear (ONP is clipped, xgb is piecewise-constant in
`level_pred`, rows renormalise). Linear shifting of the baseline matrix would be
wrong; interpolating between exact knots is fine.

### 4d. Known extrapolation risk (flag on the page)

The xgb primary model was trained on past elections, with `level_pred` as a feature
(`R/xgb_primary_override.R:239`). ONP at 30% or LNP at 18% is outside anything it
saw; tree models go flat at the edge, so the xgb residual stops adapting while
`base_margin` (a linear-ish baseline) keeps extrapolating. Unverified; stage 1
will show it as kinks in the curve. Also the ONP seat shape (CV 0.365) is fitted on
one election (South Australia 2026) and its CV is bounded only between 0.11 and
0.48 depending on assumption (`fit_seats_full.R:691-704`). At the high end of the
ONP slider the page is showing that assumption, not data.

---

## 5. The two modelling decisions to state on the page

### 5a. Hold the level fixed at X, or keep the usual statewide spread around X?

**Recommendation: hold it fixed (zero spread for the moved party).**

Reason: the user has conditioned on the outcome ("if One Nation gets exactly 25%").
Keeping +-2.5 points around 25% answers a different question ("if the polls said
25%") and double counts, because the model's statewide sd (2.52-2.63 points, `[LOG]`)
is the uncertainty about where the level will land, which the slider has just
removed. It also blurs the steep part of the seat curve: one old reading put ONP
at about 1-2 seats per point around 20% (dated, journal above), so a +-2.5 point
smear is worth several seats of spread. `FORCE_FP` keeps the spread today; it is the
other option and the engine should offer both as a toggle (cheap, see below).

Everything else stays uncertain and is stated as such: the other parties' statewide
levels (conditional on X, see 5b), seat-level noise, surge, preference flows,
calibration shrink. The page should say "Assuming One Nation gets exactly X% of the
first-preference vote statewide. Everything else is as uncertain as in the main forecast."

Implementation (a few lines, on the centred shift matrix `S` of section 2c): set
column p to 0, and for every other column j subtract `beta_j * S[,p]` where
`beta_j = cov(S_j, S_p) / var(S_p)` estimated from the draws. That is the exact
Gaussian conditional distribution given p = X.

### 5b. How do the other parties give way?

Three candidates:

| rule | what it does | for | against |
|---|---|---|---|
| **1. The model's own covariance (recommended)** | others move by `beta_j * (X - mean_p)`, `beta` from the renormalised statewide draws | built from the same correlation matrix the forecast already uses (`:1243-1260`); works for all four parties; sums to exactly -1 across the others by construction (draws sum to 100); no new constants | the shrunk correlation is mild (ONP-LNP -0.38 [LOG]), so ONP is predicted to take less from the Coalition than the South Australia pattern; I have NOT computed the betas |
| 2. South Australia pattern (`FORCE_FP` today) | LNP -0.85, ALP -0.12 per ONP point | fitted on the only election where ONP moved this much; says ONP takes mainly from the Coalition, which is the mechanism behind its seat wins | one election; ONP-only; total not preserved (4a); meaningless for ALP, LNP, GRN |
| 3. Proportional | others scaled pro rata | simple to explain | contradicts every ONP finding in this repo (ONP takes Coalition votes, `:1228-1229`) |

Rule 1 for the mean and the conditional spread (5a) are the same regression, so
one number per pair of parties drives both; show it on the page ("a point of One
Nation costs the Coalition about 0.4 points in this model" once measured).
**Decision for Pete**: rule 1 (data, general) or rule 2 (the pattern already in
use, ONP only). Rule 1 changes only the scenario's input rule, not the forecast. I
recommend also running rule 2 at the stage-1 knots so the size of the difference is
measured once, not argued.

### 5c. Things to state on the page regardless

- Slider zero is today's `state_mean` after closing to 100, so OTH reads 12.6 not 11.0.
- The scenario holds fixed: candidates, preference flows (engine only), the ONP
  concentration shape, the calibration, the trend sds.
- Range: 10 points either side of today; clip so no class goes under 0.1 (the
  model's floor, `:1291`).

---

## 6. Options in detail

### A. True live

- **R server (plumber on a small host, or Cloud Run):** needs R, the compiled
  package, the xgb models and a bundle of inputs. The R simulator takes 17-25 s per
  20,000 draws [LOG], about 5 s at 5,000 [GUESS], and cannot honestly be "live" under
  load. Does not remove the need for the share matrix at X (which needs the xgb layer
  and chain). Not recommended.
- **Cloudflare Worker:** the existing `inthegame-api` worker has a 5 s CPU cap
  (`inthegame-blog/worker/wrangler.toml`, comment near "CPU cap") and can only run
  JS/WASM; it would run the same JS port as the browser, with no benefit except
  hiding the engine. The site CSP already allows the worker origin
  (`inthegame-blog/_headers`, `connect-src`). Not recommended.
- **In-browser JS engine (the live part of A'):** zero marginal cost, works offline
  once loaded, runs in a Web Worker so the page does not stutter. Speed estimate:
  88 seats x 5,000 draws x about 150 operations is roughly 66 million operations,
  about 0.2-0.5 s [GUESS].

### A'. Recommended: knots plus in-browser engine

Daily CI step (after `fit_seats_full.R`) writes `scenario-bundle.json` (or binary):

1. `shares` at knots: 4 parties x (9 knots at 2.5 points, or 21 at 1 point) + today's.
   88 x 7 values each, about 23K numbers at 2.5-point knots (small).
2. The simulator tables (section 2e). Dominated by the 88 x 484 x 7 override rows
   (about 300K numbers, about 2.5 MB as JSON, about 0.3 MB quantised and gzipped
   [GUESS]). Held at today's values in the engine.
3. A centred shift matrix of 4,000-10,000 statewide departures (7 columns, 112-280 KB
   as float32), used by EVERY scenario, which keeps the slider smooth (common random
   numbers).
4. Parameters: level_sd a,b and class multipliers, surge vectors, shrink,
   smooth, flow sds, the covariance and beta table for 5a/5b.

Browser engine = port of `seat_sim_core.cpp:98-240`. **Size: about 143 lines of
C++ logic** (noise 98-106, surge 107-129, eliminations 137-217, winner and shrink
218-239), so **about 250-300 lines of JS** including seeded RNG, table decode,
the conditioning in 5a and the aggregation to the output JSON. Not byte-identical to R
(different RNG); the test is statistical equivalence against the R result at the
same shares (win probabilities within Monte Carlo error: about 0.007 at 5,000
draws, about 0.0035 at 20,000 [arithmetic, worst case p = 0.5]).

To keep the slider smooth the JS should draw noise from a counter-based hash of
(draw, seat, party) rather than a sequential generator, so the same random
numbers are used at every slider position. (The R engine does not have this
property: eliminations consume a variable number of random numbers, so streams
diverge between scenarios.)

What A' can show: everything in section 7, any slider position, two sliders at once
(for example ONP 25 and GRN 15), the keep-spread or hold-fixed toggle, a draw-count
choice. What it cannot: preference flows that react to the scenario (held at
today's), and anything the xgb layer would do between knots (linear interpolation of
shares).

### B. Fine precomputed grid with interpolation

- 41 steps x 4 parties = 164 R runs. Naive: 6.5 h [LOG-derived]; with the shared
  prefix factored out and 5,000 draws about 15 s each = 41 min [GUESS]; with the
  full 20,000 draws about 82 min [GUESS]. The grid is relative to today's projection,
  so it has to be rebuilt every day or labelled "as at <date>". The daily CI job
  has a 45-minute limit (`forecast.yaml:42`) and is already doing the forecast.
  Realistic home: a second, weekly or manual workflow.
- Output size: 164 scenarios x (7 expected seats, 4 majority probabilities, 2 chamber
  numbers, plus per-seat win probabilities for parties above 0.5%) about 36,000
  numbers for the per-seat part, roughly 0.25 MB JSON, about 60 KB gzipped
  [arithmetic, assumed 2.5 parties per seat].
- Interpolation: linear between 0.5-point steps is visually exact for expected
  seats. Monte Carlo noise is independent at each step (different random streams),
  so at 5,000 draws the curve wobbles by about +-0.1 seat; smooth it (local
  regression) or use 20,000.
- Shows: one party at a time. Cannot show: combinations, the spread toggle (unless
  the grid doubles), anything not precomputed.
- Pro: most faithful (flows and xgb recomputed at every point), nothing new to
  validate in the browser. Con: staleness or heavy compute.

### Stage 1 (no model code): brute force through the existing switch

`AUSPOL_FORCE_FP="ONP=<x>" AUSPOL_OUT_SUFFIX="-scn-ONP-<x>" Rscript scripts/fit_seats_full.R`
then `scripts/build_forecast_json.R` with the same `AUSPOL_OUT_SUFFIX`
(`build_forecast_json.R:16,132`) gives the full output for that scenario. Nine ONP
knots at 2.5-point steps is about 21 min [LOG-derived]; all four parties is 85 min.
These outputs are (1) a usable coarse slider, (2) the test oracle for the engine,
(3) the evidence for 4d. Caveat: ALP, LNP, GRN runs use the ONP-shaped rebalancing
(4a) and should not be shown until decision 5b is made.

---

## 7. Output JSON (small) and what we already compute

Already computed by `scripts/build_forecast_json.R` from the simulation totals
and probabilities (so the engine only has to reproduce these formulas):

| field | where |
|---|---|
| expected seats, P(majority), P(most seats, outright and with ties), 5-95% quantiles per party | `build_forecast_json.R:101-105` |
| P(tie for most), P(hung) = max seats < 45 | `:106-108` |
| P(One Nation balance of power): no majority, and larger major + ONP seats >= 45 and ONP > 0 | `:109-112` |
| per-seat win probability and projected primary per party | `:76-91` |
| majority = 45 of 88 | `:30` |
| chamber doc block | `:130` |

Not needed for the scenario: per-seat primary quantiles and final-two (the
`RG1` block, `fit_seats_full.R:1562-1596`); the engine can omit them or compute
them from its own draws.

Proposed scenario file (one per party for B; for A' the same shape is produced
live in the browser):

```json
{
  "built_at": "2026-10-04T06:10:00+1000", "git_sha": "abc1234", "n_sims": 5000,
  "assumption": "level fixed at X; others respond by the model's own covariance",
  "today": {"ALP": 31.1, "LNP": 28.0, "GRN": 12.5, "ONP": 20.6, "OTH": 12.6},
  "response_per_point": {"ONP": {"LNP": -0.44, "ALP": -0.31, "GRN": -0.12, "OTH": -0.13}},
  "x": [10.6, 11.1, ..., 30.6],
  "chamber": {"expected": {"ALP": [..], "LNP": [..], "GRN": [..], "ONP": [..], "IND": [..]},
              "p_majority": {"ALP": [..], "LNP": [..]},
              "p_hung": [..], "p_onp_bop": [..]},
  "seats": {"Melbourne": {"ALP": [..], "GRN": [..]}, "...": {}}
}
```
(`response_per_point` numbers above are placeholders to show the shape, NOT
measured.) About 0.25 MB per file for B (section 6), engine output in memory.

---

## 8. Publishing and page consumption (what exists)

- The daily workflow `.github/workflows/forecast.yaml` runs `run_all.R`, then
  uploads `forecast-vic2026.json`, `forecast-history.csv`, `seat-probs-vic-2026.csv`,
  `seat-shares-vic-2026.csv`, `victoria-2026.html`, `polls-vic-snapshot.csv` to the
  `forecast-latest` release (`:365`) and to R2 bucket `inthegame-data` under `auspol/`
  with `wrangler r2 object put`, 5-minute cache (`:366-400`; file list `:396`).
  Skipped with a warning if the Cloudflare secrets are not set (`:385-388`;
  whether they are set now is unconfirmed).
- The ITG page fetches `auspol/forecast-vic2026.json`, `vic2026-districts.topojson`
  and `vic-page-data.json` from `window.DATA_BASE_URL` (`inthegame-blog/politics/index.qmd:153,170,181`).
  CSP `connect-src` allows `self`, the R2 public origin and the API worker
  (`inthegame-blog/_headers`); scripts from `self` are allowed and so are blob
  workers (`worker-src 'self' blob:`). A scenario bundle on R2 and an engine file
  served by the site need no CSP change.
- New files to add to the R2 loop at `forecast.yaml:396`: the bundle (A') or the
  scenario files (B).

---

## 9. What I could not confirm (listed so nothing reads as checked)

1. Peak memory of `fit_seats_full.R` and the daily CI job's real duration.
2. The split of the ~120 s before the simulation (no stage timers in the logs; the
   split above is inferred from two xgb timestamps).
3. That `AUSPOL_FORCE_FP` still runs end-to-end on current `dev` with the live xgb
   layer, flows and post-xgb adjusters (last documented use predates them).
4. The sum-to-100 arithmetic in 4a (read only), and the regression betas in 5b
   (not computed; the "-0.4" style numbers in this doc are not measurements).
5. Whether the xgb layer misbehaves 10 points outside its training range (4d).
6. All hour estimates, JS speed, 5,000-draw timing and per-scenario times in B are
   guesses.
7. Whether the surge hazards depend on `state_mean`: grep of `:665-1007` found no
   `state_mean`, but I did not read that block line by line.
8. Whether `docs/PETE-ASKED-FOR.md` already carries this request: the register
   must be updated by the session that owns it (repo rule), not by this scoping.
9. R2 secrets present, and the current size of `forecast-vic2026.json` (not on disk).

## Decisions 2026-10-04 (Pete, quiz)

- **5a: hold the moved party exactly at X** (no statewide spread around X). Page wording: "if ONP gets exactly X%".
  The engine may offer the usual spread as a toggle later; not in the first version.
- **5b: the other parties give way by regression on the model's own draws** (shares sum to 100, works for all
  four parties), not pro rata. The betas still have to be computed from the model's simulation draws (not done).
- Earlier (2026-10-03): a LIVE slider, not a precomputed grid; the scoping's recommended path A' (seat-share
  matrices at 2.5-point knots from the real R pipeline plus a JS port of the seat simulation in the browser)
  is the one that gives a live slider without a server. Still NOT started: about 40-50 hours (a guess).
