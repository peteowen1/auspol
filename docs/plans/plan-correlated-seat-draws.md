# Correlated seat draws: design plan

**Status: DESIGN ONLY. Nothing here is pre-registered yet.** The
pre-registration skeleton in §5 becomes a `prereg-*.md` and is committed
before any arm runs. Written 2026-09-07 against the corpus as it stood that
day (`scripts/pool_backtests.R`: 22 pairs, 2,050 seat-elections, pooled log
loss 0.3386, floor-excluded 0.3056 over 2,045).

## The idea

Today `simulate_seat_contests()` draws each seat's per-party deviation
independently, conditional on the statewide draw:

```
v[i,k] = shares[i,k] + shift[k] + rnorm(0, sd_cell[i,k])
```

`shift` is shared by every seat (and, since `party_cor`, correlated across
parties within itself). Everything after that is per seat: the surge coin
toss, the flow noise on each exclusion, the `shrink` coin toss. **Nothing
in the simulator couples one seat to another.**

Pete's observation is that this is wrong on the face of it. nsw2019 is the
case: the Shooters, Fishers and Farmers won Barwon, Murray and Orange on one
night, three adjacent rural seats, and the model gave the winner

| seat | p(actual winner) | called | at |
|---|---:|---|---:|
| Barwon | **0.00000** | LNP | 0.9659 |
| Murray | 0.00345 | LNP | 0.9711 |
| Orange | 0.00025 | LNP | 0.9887 |
| Dubbo | 0.9598 (correct) | LNP | 0.9598 |

(`output/backtest-nsw2019-lv110_867-sh01-cor-a10f34c-g5a8542fx.csv`.)

---

## 0. Read this before anything else: correlation alone CANNOT move the primary metric

This is not a caveat. It is a proof, and it decides how the whole plan is
shaped.

**Claim.** Let the change be *variance-preserving*: split the existing
per-seat residual into a cluster factor plus an idiosyncratic part with the
total variance held at today's value,

```
v[i,k] = shares[i,k] + shift[k] + g[c(i),k] + rnorm(0, sd_idio[i,k])
        with  var(g[.,k]) + sd_idio[i,k]^2  =  sd_cell[i,k]^2
```

Then **every seat's win probability is unchanged, exactly, not approximately.**

**Why.** Read the core loop (`src/seat_sim_core.cpp` lines 78–160, and the
mirror at `R/seat_sim.R` 780–930). Seat `i`'s recorded winner is a function
of `v[i,]` and of randomness drawn only for seat `i` — its surge `runif`, its
per-exclusion flow `rnorm`, its `shrink` `runif`. No expression in the seat
body reads another seat's state. So

```
P(party k wins seat i) = E[ f_i(v[i,]) ]
```

depends **only on the marginal law of `v[i,]`**. Both terms above are
Gaussian, so under the variance-preserving split that marginal law is
identical to today's. The joint law over seats changes; every marginal does
not.

**Consequences, in order of how much they cost:**

1. **PB3f — the mandated primary metric — cannot move.** It is a mean of
   `-log(p)` over per-seat marginal probabilities. A variance-preserving
   correlation arm will differ from baseline only by Monte Carlo noise.
   Barwon does not come off the floor. Murray does not rise from 0.00345.
2. **The motivating evidence does not motivate this mechanism.** Barwon was
   given 0.0000 because the *marginal* distribution of OTH_RIGHT in Barwon
   never reaches a winning level, not because Barwon failed to hear about
   Murray. Correlating them changes which simulations they lose together in.
3. **The contrast with `party_cor` is instructive and easy to get wrong.**
   `party_cor` correlates the K components of `shift` **within** a seat, so
   it changes the joint law of `(v[i,1..K])` and therefore who wins seat `i`.
   That is why it moved anything. Between-*seat* correlation is a different
   object and does not have that property. Anyone arguing "but `party_cor`
   helped" is comparing two things that are not alike.
4. **`shift` is already a cluster factor whose cluster is the whole state.**
   Adding a second, smaller one changes nothing about marginals unless it
   adds variance.

**What correlation DOES change** is the joint distribution — the seat-count
histogram in `sim$totals`, the probability of a majority, the probability
that One Nation wins three or more. Conditional on the statewide draw the
current model treats 93 seats as 93 independent coin flips, so its published
seat *range* is too narrow. That is a real defect with a published
consequence. It is scored by a different metric on 22 observations, and it
should be pursued as its own small change (§4c), not sold as a log-loss fix.

**So the plan splits in two**, and the split has to be made honestly in the
pre-registration or the experiment is uninterpretable:

- **Arm P (variance-preserving)** — the idea as literally stated. Predicted
  effect on PB3f: **exactly zero**. Run it anyway, once, on one pair, as a
  correctness check: if PB3f moves materially, the implementation has changed
  the marginals and is buggy. This is the cheapest kill in §6.
- **Arm H (heterogeneous variance)** — the version that can move PB3f. Add a
  cluster component **on top of** the existing per-seat sd, so a seat sitting
  in a historically volatile cluster is drawn wider than one in a stable
  cluster. This changes marginals, in a data-driven and non-uniform way, which
  is exactly the shape of the change that earned `level_sd` its −29% on
  federal log loss. **It must be scored against a variance-matched flat
  control** (arm F: the same average total sd, allocated uniformly), or a win
  is indistinguishable from "wider is better", which this repo already knows.

The rest of this plan is written for arm H, with arm P as a correctness
check and arm F as the mandatory control.

---

## 1. Candidate similarity structures, ranked

Coverage is the axis that decides most of this. The corpus is **22 pairs /
2,050 seat-elections**, and `CLAUDE.md`'s "a fix to one harness is a fix to
all of them" makes a structure that covers a quarter of the corpus unusable
as a shipped default however good it looks where it applies.

### 1. Prior-vote-profile similarity — RECOMMENDED

Distance between seats on the **previous** election's first-preference vector
over the 7 `classify_party()` classes. Cluster with k-means or a fixed
distance threshold; `k` is a hyperparameter and goes on the grid.

- **Data needed:** none that is not already loaded. Every harness builds
  `shares` from exactly this vector (`scripts/backtest_candidate_nsw.R` 333–394
  and siblings).
- **Coverage: 22 of 22 pairs, all six jurisdictions, by construction.**
- **Leakage: closed by construction** — it is the prior election, which is
  the model's own input.
- **For:** it encodes the thing that actually matters here. Barwon, Murray,
  Orange and Dubbo in 2015 are a tight group on this metric. It survives
  redistribution better than geography does, because it is defined on
  whatever seats the pair actually has.
- **Against:** it is collinear with the baseline. The seat's own prior vote
  is already step 1 of the projection, and `level_sd` already makes the
  variance depend on the level. The cluster may add nothing beyond what those
  two encode — which is the same trap the demographic-swing refusal fell
  into, one level up.
- **Against, concretely:** it groups **Dubbo** with the three. See §5's dry
  run — this is a feature and a cost at the same time, and the criterion has
  to be written knowing it.

### 2. Geographic adjacency — second, and worth building only if #1 wins

Shared-border adjacency from the ABS state electoral division boundaries.

- **Data needed:** `external/reference/boundaries/SED_2021_AUST_GDA2020.shp`
  and `SED_2022...` are on disk. They cover NSW 95, QLD 95, VIC 90, WA 61,
  SA 49 — every state jurisdiction.
- **Coverage: state pairs only, at ONE boundary vintage.**
  - **Federal is absent.** There is no CED shapefile in
    `external/reference/`. Federal is **7 pairs and 1,036 of 2,050
    seat-elections — half the corpus.** It is a free ABS/AEC download, but it
    is work, and until it is done this structure cannot decide anything.
  - **Historic boundaries are absent.** Using 2021 borders for wa1996–wa2013,
    nsw2015, vic2010 or qld2017 is an anachronism. WA redistributes hard
    enough that seat names do not survive between elections at all
    (2005→2008 scores 67% of the chamber), so for seven WA pairs the
    adjacency graph would be joining seats that are not the seats being
    scored.
- **For:** the most face-valid structure for the motivating case. Barwon,
  Murray and Orange are literally adjacent.
- **Against:** so is Dubbo.
- **Implementation note:** do **not** add `sf` to `Imports`. Precompute the
  adjacency list offline into a CSV under `external/reference/`, exactly the
  way boundaries and the census are already kept outside the package. The
  package must keep passing `R CMD check` with the anchor clone absent.

### 3. Regional blocks from `seat_region` — cheapest, and the evidence is against it

`load_seats()$seat_region` is already parsed, and the retired two-party model
already had this exact structure: `seat_swing_spread()` returns `sd_between`
and `sd_within`, and `simulate_seats()` drew a regional block effect.

- **Data needed:** the anchor's `analysis/seats/*.txt`. Files exist for 13
  election-years: 2019/2022/2025/2028 fed, 2019/2023/2027 nsw, 2022/2026 sa,
  2022/2026 vic, 2024 qld, 2025 wa.
- **Coverage: 10 of 22 scored pairs** (fed2019, fed2022, fed2025, nsw2019,
  nsw2023, sa2026, vic2022, qld2024, wa2025 — and no more). Missing:
  fed2007/2010/2013/2016, vic2014, vic2018, qld2020, six of seven WA pairs.
- **For:** zero new code to define membership; a precedent already in the
  repo.
- **Against, and this is the strong one:** `R/seats.R` line 104 records the
  measurement already made — *"Region effects are barely persistent between
  elections (correlation 0.27 across Victoria's 13 regions)"*. That is an
  in-repo, already-paid-for estimate saying the block signal is weak.
- **Against:** the regions are third-party hand-authored, and `CLAUDE.md`
  records that the anchor's own party classifications disagree with ours in
  exactly the NSW rural seats this plan is about. `seat_region` is not a
  party field so that specific trap does not fire, but the provenance is the
  same and one source of truth per question applies.
- **Worth noting for free:** the harnesses already compute `sd_between` and
  throw it away — they pass `sd_within` as `seat_sd`
  (`backtest_candidate_nsw.R` 601–602, 673). The between-region variance is
  measured, printed at `BT3`, and has nowhere to go. That is the natural
  home for a cluster component. **But** on the published path `level_sd` is
  on, and `simulate_seat_contests()` **ignores `seat_sd` entirely whenever
  `level_sd` is given** (`R/seat_sim.R` 830–834; the nsw harness says so at
  its lines 111–124). So `sd_within` is currently dead on the shipped path,
  and anyone reasoning from `BT3` is reading a number the model does not use.

### 4. Party-specific latent factor — the right FORM, not an independent option

A one- or two-factor model per party class: `g[i,k] = L[i,f] * z[f,k]`.

- **Data needed:** none external.
- **Coverage:** 22 of 22, in principle.
- **For:** statistically the cleanest shape, and it is what a cluster
  assignment is a crude special case of (a one-hot loading).
- **Against, decisively:** per-seat loadings are not identifiable here. There
  are ~15 usable election pairs, seats do not persist across redistributions,
  and estimating a free loading per seat on 15 observations is the textbook
  version of the overfitting the demographic model showed. The only
  admissible version is **loadings as a function of observable covariates**
  — and the obvious covariate is the seat's prior vote profile, at which
  point this **is** option 1 with soft weights instead of hard clusters.
- **Verdict:** adopt as the functional form *after* a cluster definition
  wins; do not race it as a separate structure.

### 5. Demographic distance from the census — last, on coverage

- **Data needed:** `external/reference/census/census-sed-2021.csv`,
  235 rows, with age, income, rent, household structure.
- **Coverage: NSW 95, VIC 90, SA 49 — no Queensland, no Western Australia,
  no federal.** That is **6 of 22 pairs and 467 of 2,050 seat-elections
  (23%)**. It cannot decide a change that has to be measured on all 22.
  Federal alone is 1,036 seat-elections and is entirely uncovered.
- **One census vintage (2021) against elections from 2010 to 2026.** For
  vic2014 that is a covariate measured seven years after the fact. It is not
  leakage in the usual sense (demographics move slowly and are not caused by
  the result) but it should be named, not assumed harmless.

**On the 2026-08-25 demographic refusal, explicitly.**
`docs/reviews/demographic-swing-refused-2026-08-25.md` measured demographics
as a **per-seat point predictor of swing deviation** and refused it: MAE
4.087 against 3.850 for predicting zero, better in 2 of 12 cells, and
`OTH_RIGHT` — the strongest in-sample fit at adjusted R² 0.110 — worse in all
three pairs.

**That refusal does not settle the question this plan asks, and the
distinction is not a technicality.** A point predictor is a claim about the
**first moment**: given this seat's demographics, here is where its swing
will land. Correlation is a claim about the **second moment**: two seats that
look alike will *miss in the same direction as each other*, without any claim
about which direction. A covariate can carry no first-moment signal at all
and still carry real second-moment structure — that is precisely what a
random-effects model asserts, and it is why "region effects are barely
persistent" (r = 0.27) is compatible with "regions have real block variance".
The refusal is evidence about the mean and says nothing about the covariance.

So demographics are ranked last **on coverage**, which is a hard constraint,
and not on that refusal, which does not apply.

---

## 2. Where it goes in the simulator, and what the byte-identical contract costs

### The insertion point

One line, in both engines. Between the statewide `shift` and the
idiosyncratic draw:

```
# today (cpp 84-88, R 815-822)
e      = rnorm(0, sd_cell[i,k])
v[k]   = base[k] + shift[k] + e

# with a cluster component
v[k]   = base[k] + shift[k] + g[s, c(i), k] + rnorm(0, sd_idio[i,k])
```

`sd_idio` costs nothing at runtime: `sd_cell_pre` is already a precomputed
`nseat x K` matrix, hoisted out of the draw loop on 2026-09-06 for exactly
this reason. Arm P writes `sd_idio = sqrt(pmax(0, sd_cell^2 - tau^2))` into
it; arm H leaves `sd_cell` alone.

### The contract, and how to keep it

`src/seat_sim_core.cpp` states the contract in its header: **byte-identical
output**, same random numbers in the same order, `long double` accumulation,
R's evaluation order preserved. `tests/testthat/test-seat-sim.R:302` asserts
`identical()` between engines with every mechanism switched on.

Two ways to add the cluster draw, and only one of them is cheap.

**The wrong way — draw `g` inside the core.** `R::rnorm` per (sim, cluster,
party) inside the loop changes the RNG consumption order, so the R engine
must draw in exactly the same places, and the identity test has to be
re-proven for every combination. Worse, if the cluster structure is a full
`nseat*K` covariance needing a Cholesky product per draw, the core has to do
a matrix product — and the header records that a hand-written accumulation
matched reference BLAS on Windows and **not** the Linux CI runner's BLAS
(last-bit differences, 2026-09-07), which is why `chol_t %*% z` is delegated
back to R's own `%*%` through `Function matprod`. A 651×651 product delegated
to R 20,000 times is not free.

**The right way — precompute `g` in R and pass it in, exactly as
`shift_mode == 0` already does.** `statewide_draws` is already handled by
handing the core a precomputed `shift_mat` and drawing nothing. Do the same:
pass an `n_sims x (n_clusters * K)` matrix `g_mat` plus an integer
`cluster_of[nseat]`. Then:

- the core draws **no new random numbers** and does **no new matrix
  products** — one extra add in the innermost loop;
- cross-platform BLAS never enters the hot path, because the Cholesky and the
  product happen once, in R, at full precision;
- the null (`tau = 0`, or `g_mat` absent) is **byte-identical to today**, the
  same way `chol_t = NULL` is;
- memory is the only cost: 12 clusters × 7 parties × 20,000 sims = 1.7M
  doubles ≈ 13 MB. A full per-seat `g` would be 20,000 × 151 × 7 = 169 MB
  for federal, which is the second reason to prefer a low-rank cluster form
  over a dense seat-by-seat covariance.

**Generate `g_mat` from a separate RNG stream.** Save `.Random.seed`, seed
the cluster draw independently, restore. Then the numbers the core consumes
are unchanged between the baseline arm and any cluster arm, so the two runs
are paired at the draw level and the only difference is the added `g`. Without
this, every arm shifts the whole stream and small PB3f moves become
indistinguishable from a reseed.

**What must still be done, and must not be skipped:** the same change goes
into the R engine, and `test-seat-sim.R:302` gets a **non-zero tau** case.
An identity test that only ever runs the mechanism switched off is the
`CLAUDE.md` hazard verbatim: an experiment that never ran looks exactly like
an experiment with no effect.

### Everything else that has to move in the same commit

- `simulate_seat_contests()` gains `seat_cluster` (per-seat integer or seat
  name → cluster) and `cluster_sd` (named per party), both `NULL` by default,
  with the same by-name matching and the same
  name-that-is-not-a-party-is-an-error rule that `level_mult` and `shrink`
  already use.
- `devtools::document()` in the same commit — a changed signature with a
  stale `.Rd` is a CI failure and has been three times.
- **All six harnesses** — `_fed`, `_vic`, `_nsw`, `_sa`, `_wa`, `_qld` — plus
  `fit_seats_full.R`. `CLAUDE.md` records `shrink` reaching four harnesses and
  missing SA, and four days of SA calibration numbers describing a model that
  is not published. Grep the other five before writing the first one.
- `scripts/published_flags.R` gets `AUSPOL_SEAT_CLUSTER` in the **same
  commit**, at the value that ships (`"0"` until something is adopted).
- Check codes: `SK*` is free (surveyed 2026-09-07 across `scripts/` and
  `R/`); the harness line goes in the `BT` family as `BT5k`.

---

## 3. Estimating the correlation leakage-free

### The estimand

Per party class `k`: the intra-cluster correlation of the seat-level residual
once the statewide movement is removed. Equivalently a between-cluster
variance `tau_k^2` against a within-cluster `sigma_k^2`.

### The residual

For each pair (prev → target), for each seat `i` and class `k`:

```
r[i,k] = actual_share[i,k] - central_share[i,k] - statewide_change[k]
```

`central_share` is the harness's `shares` matrix — the projection after steps
1–4 of the ARCHITECTURE.md description, which is what the simulator actually
centres on. `statewide_change` must be subtracted or the "cluster
correlation" is just the statewide correlation measured again on a different
axis, and it will look enormous.

**Every input is on disk.** `external/elections/*firstprefs.csv` covers all
22 pairs (federal in one file with an `election` column; five state
jurisdictions in per-year files). Nothing needs fetching.

### The hygiene

Mirror `scripts/estimate_statewide_cov.R` and `R/statewide_cor.R` exactly —
that is the pattern the repo settled on nine days ago and it already handles
the three cases correctly.

- Write `output/seat-cluster-cov.rds` with `cor`/`cov`, `cor_shrunk`, and a
  **`by_target`** list holding one estimate per election with that election's
  own pair removed.
- Add `seat_cluster_cov(target)` returning the leave-one-out estimate when
  the target is in the fit, the all-pairs estimate when it is not, the
  all-pairs estimate for a live forecast (nothing to hold out), and a
  `"cov_source"` attribute the harnesses **print**. Refuse — do not fall back
  — if the saved object predates `by_target`, exactly as `statewide_cor()`
  does. A silent fallback here is the leak defending itself.
- **Cluster membership must come from pre-election covariates only.** If
  clusters are found by clustering the residuals, the target has been used
  and every number afterwards is fiction. Prior-vote profile is safe because
  it is the previous election. The 2021 census against a 2014 election is not
  leakage but is an anachronism and must be stated in the log.
- `tau^2` estimated by method of moments can come out negative. **Clamp to
  zero and print that it was clamped.** A silent clamp is a guard that cannot
  fail; `CLAUDE.md` has four instances of that species.
- Assert row sums and coverage on every join. A class present but 0%
  populated passes every schema check and is the exact failure the global
  notes record from citiusverse.

### Jurisdiction hygiene, learned from the statewide fit nine days ago

`estimate_statewide_cov.R` fits on 15 pairs with **Western Australia
deliberately excluded**, because `cor(ALP, IND)` was −0.16 with WA in and
+0.43 without: a correlation that changes sign on one jurisdiction is
describing that jurisdiction. WA seats are still *scored*; only WA pairs are
kept out of that one estimate.

The same risk lands harder here, because WA is where seat identity itself
breaks between elections. **Fit `tau^2` on non-WA pairs, score everywhere,
and print which pairs were in the fit.** Then run the same sign-flip refusal
check (§5, refusal 6) with each jurisdiction removed in turn.

### Report the persistence too

Compute whether a cluster's mean residual at election `t` predicts its mean
residual at `t+1`. `seat_swing_spread()`'s docstring already answers the
regional version: r = 0.27 across Victoria's 13 regions, which is why the
retired model drew the region effect **fresh each time** rather than as a
predictable offset. This design needs a *random* block, so weak persistence
is fine and does not block it. But if persistence turned out strong, that
would be a case for moving the **mean**, not the variance, and that is a
different and better change than this one. Print the number either way.

---

## 4. Measurement

### (a) Primary: floor-excluded pooled log loss, PB3f

`scripts/pool_backtests.R`, line `PB3f`. Currently **0.3056 over 2,045
seat-elections**.

**Why pooled log loss including the floor seats (PB3) is the wrong primary.**
`PB2f` prints it: **5 of 2,050 seat-elections give the actual winner
≤ 1e-4, and they carry 10.0% of the total log loss.** Every harness clamps at
`eps = 1e-6` before the log, so a seat at exactly zero contributes 13.8 by
itself. `pool_backtests.R`'s own comment records the consequence: on
2026-09-07 the entire 0.0019 difference between two versions of the model was
**one seat — Barwon in nsw2019 — going from 0.000050 to 0.000001**. No model
change. PB3 is therefore substantially a report of how many seats crossed a
constant, and a change of this size cannot be judged on it.

**Two things the criterion must get right, or PB3f is not comparable across
arms:**

1. **Freeze the excluded seat set on the BASELINE arm.** PB3f excludes
   whichever seats are at the floor *in that run*. If the change lifts Barwon
   off the floor, Barwon enters PB3f, the denominator changes, and the two
   numbers are computed on different populations. Pick the 5 seats at the
   floor under the current published config, hold that list fixed, and score
   **both arms on the same 2,045 seat-elections.** Report the frozen list in
   the output.
2. **PB3f excludes the motivating case.** Barwon is one of the 5 excluded
   seats. A change aimed at rescuing floor seats, scored on a metric that
   removes floor seats, can only be seen through its collateral effects.
   That is a genuine tension and it must be stated, not finessed.

**On `CLAUDE.md`'s targeted-versus-general rule.** Its table says a targeted
fix is validated on its named targets with the election-wide metric demoted
to a do-no-harm guard, and that at 6 of 151 seats an aggregate criterion will
almost always refuse a targeted fix that works. **An election-wide primary is
correct here only if the change is specified as a general one** — a variance
component applied to every seat in every jurisdiction, which is what arm H
is. If anyone respecifies it as a rescue for four NSW seats, PB3f stops being
the right primary and this plan needs rewriting. Say which it is, in the
pre-registration, and do not let it drift.

### (b) Secondary and guards

- **Brier and accuracy**, pooled and per pair.
- **Per-pair PB3f, all 22**, with the sign of the move. A change that helps
  federal and hurts WA is a finding.
- **Reliability at tail-focused bands** (0.9, 0.95, 0.99, 0.999) with counts,
  via `scripts/compare_arms.R`. Never equal-width bins.
- **The floor set itself**: how many seat-elections at `p <= 1e-4` before and
  after, named. Growing this set is a refusal (§5).
- **The named cases**: Barwon, Murray, Orange (up) and Dubbo (down), with the
  log-loss arithmetic done in advance.

### (c) The metric for the joint distribution — a separate experiment

If arm P is pursued for its own sake, the metric is not log loss. Score the
**chamber total**: for each pair and party, the log score (or CRPS) of the
realised seats-won count under `sim$totals`. 22 pairs × 7 classes. Power will
be poor and the plan should say so before it starts, not after.

### (d) MDE — compute it before committing the criterion

`CLAUDE.md`: a primary whose MDE exceeds any plausible effect is a criterion
that can only refuse. Two numbers, both measurable before any arm runs:

- **Noise.** Run the baseline **twice at different seeds** and take the sd of
  the 22 per-pair PB3f differences. MDE ≈ 2.86 × sd / sqrt(22) at 80% power,
  alpha 0.05 two-sided, clustered on the pair — 22 pairs is the independent
  unit, not 2,045 seats.
- **Expected effect.** The largest known variance change in this repo is
  `level_sd`, worth 0.156 on federal log loss (0.5398 → 0.3839) — and that
  was replacing a flat sd with a level-dependent one, a first-order change to
  every seat. A cluster component is a second-order refinement of the same
  variance. A plausible effect is 5–20% of that: **0.008 to 0.03 on PB3f.**

**If the measured MDE exceeds 0.008, the experiment cannot decide and must
not be run as specified.** Raise `n_sims`, or accept that only a large effect
is detectable and say so in the criterion.

---

## 5. Pre-registration skeleton

*(To be lifted into `docs/plans/prereg-seat-cluster-variance-YYYY-MM-DD.md`
and committed before any arm runs.)*

### Question

Does making the per-seat residual variance heterogeneous by cluster — seats
grouped by prior-vote profile, with a cluster-level component estimated
leave-one-election-out — improve floor-excluded pooled seat log loss across
all 22 pairs, **beyond a variance-matched flat widening**?

### Arms

| arm | what it does | purpose |
|---|---|---|
| **B** | published config, `AUSPOL_SEAT_CLUSTER=0` | baseline |
| **B'** | B at a second seed | noise floor, run FIRST |
| **P** | cluster component, total variance held at B's | correctness check; predicted PB3f effect **zero** |
| **F** | flat widening to arm H's mean total sd, no clusters | **mandatory control** |
| **H** | cluster component added on top | the candidate |

### Grid, fixed in advance

- `n_clusters` ∈ {4, 8, 12, 20} per jurisdiction (or a distance threshold
  giving comparable sizes).
- `tau` scale multiplier ∈ {0.5, 1.0} on the fitted value. **Not free** — the
  fitted value is the point; the multiplier exists only to show the metric
  responds monotonically, which is itself a check that the mechanism is wired
  in.
- Nothing else moves. Every other switch at `published_flags.R`.

### Criterion

**Primary.** Pooled PB3f over all 22 pairs, on the **frozen** 2,045-seat set
defined by arm B. Adoption requires:

1. `PB3f(H) < PB3f(B) - MDE`, with MDE computed from B vs B' as in §4d, and
2. `PB3f(H) < PB3f(F)` by at least half the MDE — the structure must beat the
   variance-matched control, not just the baseline, and
3. improvement in **at least 14 of 22 pairs** (sign test, p ≈ 0.067
   one-sided; 15 gives p ≈ 0.026 — pick one now and record which).

**Secondary, reported and not decisive.** Brier, accuracy, tail reliability
bands with counts, per-jurisdiction PB3f, the named cases.

### Refusal — what disqualifies an apparent win

1. **Arm F matches or beats arm H.** The structure earned nothing; what was
   measured is "wider is better", which is already known. Refuse H; consider
   a `level_sd` retune as a separate plan.
2. **Arm P moves PB3f by more than the B-vs-B' noise.** The implementation
   has changed the marginals and is wrong. Everything downstream is void
   until it is fixed. **This check runs before H is judged, not after.**
3. **Concentration.** If the top 3 seat-elections account for more than 50%
   of the pooled improvement, refuse. That is a floor-crossing artefact in a
   new costume, and PB3f was chosen precisely to exclude that species.
4. **Reversal.** PB3f worse in 2 or more of the 6 jurisdictions, or in 8 or
   more of the 22 pairs — refuse, whatever the pooled number says.
5. **The floor set grows.** If the count of seat-elections at `p <= 1e-4`
   goes up at all, refuse. A correlation structure that concentrates draws
   can make some seats *more* extreme, and manufacturing new zero-probability
   winners is the opposite of the intent.
6. **The estimate describes one jurisdiction.** Refit `tau^2` with each
   jurisdiction removed in turn. If `tau^2` for `OTH_RIGHT` or `IND` — the
   two classes this is about — changes by more than a factor of 2 on any
   single removal, refuse. Same rule that refused the statewide widening on
   `cor(ALP, IND)` flipping sign on WA.
7. **Edge of grid.** If the winner is the largest or smallest `n_clusters`,
   the grid was wrong. Re-registering a wider grid is a new experiment.
8. **Accuracy.** If pooled accuracy falls by more than 0.3 points (≈ 6
   seat-elections) — refuse regardless of log loss.

### What the criterion cannot see

- **The seat-count distribution**, which is what correlation actually
  changes. A null on PB3f is not evidence against §4c.
- **Barwon.** It is in the frozen exclusion set. Its movement is reported in
  the named-case table and carries no weight in the primary.
- **The very tail.** At 20,000 sims a probability of 0 and one of 1e-5 are
  the same observation. Any claim below ~5e-5 needs more sims, not more
  structure.
- **Whether the cluster is real or a proxy.** Prior-vote profile clusters are
  collinear with the seat's own prior vote, which the baseline already uses
  twice. A win could be a re-expression of `level_sd` rather than new
  information. Arm F is the partial defence; it is not a complete one.

### Dry run of the criterion, on cases whose answer is already known

**This is the part that has failed twice** (`CLAUDE.md` on
`prereg-salience-emergence-gate.md` C2), and both faults were visible without
running anything. So:

**Case 1 — Barwon, Murray, Orange, nsw2019 (the target).**
2015 first preferences, `OTH_RIGHT` share:

| seat | 2015 OTH_RIGHT | 2019 OTH_RIGHT | 2019 result |
|---|---:|---:|---|
| Barwon | 2.50% | 36.4% | SFF gain |
| Murray | 1.40% | 40.3% | SFF gain |
| Orange | 2.59% | 56.2% | SFF hold |
| **Dubbo** | **2.54%** | **15.1%** | **LNP hold** |

What the criterion **should** say: under arm P, nothing — their marginals are
unchanged and that is the prediction. Under arm H their `OTH_RIGHT` variance
rises, because they sit in a cluster whose minor-right vote moved a great
deal, so `p` should rise visibly in all three. **If arm H does not raise all
three, the mechanism is not doing what is claimed and the run is void**, win
or lose on the aggregate.

**Case 2 — Dubbo, nsw2019 (the negative control, and the trap).**
Dubbo's 2015 minor-right share is **2.54%**, against Barwon's 2.50% and
Orange's 2.59%. It is adjacent, same region, and effectively identical on
every similarity metric in §1 — and it did not elect a Shooter. **Every
structure in this plan will raise Dubbo's `OTH_RIGHT` and lower its LNP
probability from 0.9598.**

What the criterion should say, with the arithmetic done **now**: the three
target seats cost, at the clamp, `-log(1e-6) + -log(0.00345) + -log(0.00025)`
= 13.8 + 5.67 + 8.29 ≈ **27.8**. Dubbo currently costs `-log(0.9598)` =
**0.041**. Dropping Dubbo to 0.70 costs 0.357 — a net swing of about 0.3
against a possible ~20 gained. **The criterion must accept Dubbo getting
worse.** If any clause would refuse on Dubbo alone, that clause is wrong and
it is the salience-gate failure repeating: counting the intended behaviour as
an error.

**Case 3 — wa2021 (the do-no-harm control).**
Log loss 0.0794, accuracy 0.9828 — the cleanest pair in the corpus. Widening
variance can only hurt it. Write the acceptable damage down **now**: wa2021
PB3f must not worsen by more than 0.02. Without this a pooled win built on
wrecking the easy pairs is invisible.

**Case 4 — arm P on nsw2019 (the instrument check).**
The criterion must return "no change" — PB3f within the B-vs-B' noise. If it
returns a change, the metric or the implementation is broken and no other
result from the session can be trusted.

---

## 6. The cheapest experiment that would kill the idea

**Run these in order. Stop at the first one that fails. Do not run a
harness sweep before step 3.**

### Step 0 — free, no code: the invariance argument (§0)

Read the seat body of `seat_sim_core.cpp` and confirm no expression reads
another seat. If that holds, a variance-preserving correlation cannot move
PB3f, and the idea as stated does not address the log-loss numbers. **Cost:
ten minutes of reading. This is the highest-value step in the plan.**

### Step 1 — ~30 min to write, seconds to run: does the co-movement exist out of sample?

A pure data script, no simulator, no harness. From
`external/elections/*firstprefs.csv` (all 22 pairs, already on disk):

1. build `r[i,k]` as in §3;
2. assign clusters by prior-vote profile;
3. regress a seat's residual on the **leave-one-out mean residual of its
   cluster-mates**, holding out one election at a time;
4. report the coefficient and its SE per party class, and `tau^2` clamped
   with the clamp printed.

**Kill condition:** if the held-out coefficient is not distinguishable from
zero for `OTH_RIGHT` and `IND`, there is no co-movement to model and the plan
stops. **Cost: under a minute of compute.**

*Honest expectation:* this will probably **pass**. Rural minor-right seats
genuinely do move together, and co-movement is a much weaker claim than the
first-moment claim the demographic model failed. Passing step 1 is not
encouragement — step 0 still applies.

### Step 2 — ~10 min: the noise floor

Two baseline runs at different seeds on nsw2019 and fed2022 only, at
`AUSPOL_N_SIMS=5000`. Take the per-pair PB3f difference.

**Kill condition:** if the seed-to-seed PB3f spread is larger than ~0.008,
nothing in §4d's plausible effect range is detectable at 5,000 sims, and the
exploratory sweep will produce noise that reads as findings. Raise `n_sims`
or stop.

### Step 3 — ~15 min: arm P on one pair

nsw2019, `AUSPOL_N_SIMS=5000`, cluster ICC 0 vs 0.5 at matched total
variance.

**Kill condition (both directions):** PB3f must move by **less** than step
2's noise. If it moves materially, the implementation changed the marginals
— fix that before anything else. If it moves by nothing, §0 is confirmed
empirically and arm P is settled: it is a joint-distribution change only.

### Only then: the sweep

22 pairs is roughly 14 harness launches (federal one pair at a time, WA and
Victoria multi-pair) — about an hour per arm at `AUSPOL_N_SIMS=5000`, two to
three at 20,000. Arms B, B', F, H across a 4×2 grid is a large number of
hours and it should not start until steps 0–3 are done.

---

## 7. Recommendation

**Do not build this as stated.** Between-seat correlation, done in the
variance-preserving way the phrase implies, provably cannot move the metric
the repo decides on, and the Barwon/Murray/Orange evidence does not point at
it — those three were assigned near-zero because their *marginal*
distributions never reach a winning level, which is a first-moment and a
variance problem, not a covariance one.

**Build one of these instead, and say which:**

- **The version that can move log loss:** a cluster-level variance component
  that makes per-seat variance heterogeneous (arm H), clusters from
  prior-vote profile, scored against a variance-matched flat control. Modest
  expected effect (0.008–0.03 on PB3f), honest, and testable on all 22 pairs
  with no new data.
- **The version that is actually about correlation:** fix the seat-count
  distribution (§4c). Conditional on the statewide draw the model treats 93
  seats as independent, so the published seat range is too narrow. Real
  defect, real published consequence, different metric, weak power. Scope it
  small and do not sell it as a log-loss improvement.

**What would change my mind about the ranking:** if step 1 finds a held-out
cluster coefficient for `OTH_RIGHT` above ~0.3 with a clean SE, then a large
part of the residual is a block effect the model has nowhere to put, and arm
H becomes a good bet rather than a modest one. If it comes back near zero —
which is what `seat_swing_spread()`'s r = 0.27 and the demographic refusal
both weakly suggest — then neither version is worth an afternoon and this
plan should be closed with the measurement recorded.

**One note on the live target.** Victoria 2026 has zero independent-held
seats and a negligible minor-right presence, so the rural minor-right cluster
this plan was motivated by does not exist there. If anything in Victoria
benefits it is a Greens inner-city cluster or a teal cluster, and neither has
a nsw2019-sized failure behind it. This is a backtest-corpus improvement
first and a Victoria improvement only incidentally.
