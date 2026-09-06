# auspol architecture

How the pieces fit and why they are shaped this way. For the work queue and
measured findings see [docs/NEXT-STEPS.md](docs/NEXT-STEPS.md); for the anchor
model this is built on, [docs/ANCHOR-MODEL.md](docs/ANCHOR-MODEL.md).

## The shape of the thing

```
  anchor clone (external/, gitignored, third-party, hand-maintained)
        │  polls · prior results · preference flows · incumbency
        │  eventual results · seat margins
        ▼
  ┌─────────────┐
  │ load_polls  │  freshness check runs FIRST, before anything is computed
  └──────┬──────┘
         ▼
  ┌─────────────┐   per party, per cycle:
  │  fit_trend  │   latent daily vote share + pollster house effects
  └──────┬──────┘   exact posterior, one sparse Cholesky, no MCMC
         │
         ├──► unfold_others()      One Nation hidden inside "Others" — detected
         │                         arithmetically, imputed, subtracted, iterated
         │
         ├──► derive_tpp()         first preferences → two-party, via flows
         │
         ▼
  ┌─────────────┐   trend says "now"; fundamentals say "usually"
  │ projection  │   weight fitted per horizon on past elections
  └──────┬──────┘   ▲
         │          └── fit_fundamentals()  history alone: previous result,
         │                                  incumbency, federal alignment
         ▼
  ┌─────────────┐   statewide draw + regional block + per-seat residual
  │   seats     │   → distribution of seat counts
  └──────┬──────┘   (two-party only: cannot produce a non-major winner)
         ▼
   build_page.R  →  a self-contained HTML forecast
```

**A second seat path exists and does not feed the page.** The two-party model
above applies a statewide swing to each seat's margin, so a Green, an
independent or One Nation wins with probability exactly zero — not because it
is unlikely but because a two-party margin is the only thing that model knows
about a seat. The candidate-level path runs the count instead:

```
  VEC 2022 per-district pages          ECSA 2026 JSON API
  fetch_preferences_vic.R              fetch_preferences_sa.R
        │  452 exclusions, 76 seats          │  294 exclusions, 47 seats
        │  Greens / independents /           │  the ONLY source of One Nation
        │  minor-right behaviour             │  behaviour — it contested 5 of
        │                                    │  88 Victorian seats in 2022
        └───────────────┬────────────────────┘
                        ▼
              build_flow_matrix()      transfer rates keyed on the excluded
                        │              party AND who is still standing
                        ▼
            simulate_seat_contests()   per seat: exclude lowest, distribute,
                        │              repeat to a final two
                        ▼
              fit_seats_full.R  →  per-seat win probability by party
```

Both fetchers write to `output/`, which is gitignored: neither commission
publishes a licence. So this path **runs locally and not in CI**, and
`fit_seats_full.R` exits with instructions when the data is absent. The three
functions take a plain transfers table and are fully tested without it.

`scripts/run_all.R` runs that whole chain in one command. The stages are *not*
independent: `fit_projection.R` writes the mix table both `fit_seats.R` and
`build_page.R` read, so out-of-order runs silently use last time's numbers.

### How one party's seat share actually gets projected

Four steps, run in this order, for one party in one seat:

**1. Pick the starting point (`x`).** Normally `x` is that party's own prior
vote in that seat last time. Exception: if the leading candidate is personally
the same person as last time (`personal_prior_vote()`), and they were not
previously registered for a major party (ALP/LNP/NAT), `x` is *their own*
prior vote instead — even under a different party label then. Philip Donato
held Orange at 49.1% as a Shooter in 2019 and 53.1% as an independent in 2023;
without this, the seat's IND-class prior vote in 2019 is 0%, since nobody was
registered IND there, and his entire personal incumbency would vanish. The
major-party exclusion is deliberate: the one example of a major-party
defector in this data (McBride, MacKillop, LNP 62.3% → IND 14.8%) shows a
defector can lose most of a major party's vote along with the party label,
where a minor-to-minor relabelling (Donato's case) does not behave that way.

**2. Swing it by the statewide trend** (`dev_slope()`):
```
base = level_now + slope × (x − level_prev)
```
`level_prev`/`level_now` are that party's statewide vote last time / this
time. `slope` controls how much of the seat's individual deviation from the
statewide figure is assumed to persist — near 1 keeps the seat's quirk intact,
near 0 shrinks it to the statewide average. `slope` is 0.907 when the same
candidate is personally returning, 0.326 for a fresh face, or 1.0 (uniform
swing, no penalty) when the salience screen (`salience_permit_for()`,
`screened_slopes()`) judges a fresh face as a plausible emergence rather than
a no-hoper.

**3. Pull toward a typical emergence, weighted by how likely one looks**
(`surge_blend_estimate()`):
```
final = (1 − p_hat) × base + p_hat × surge_mu
```
`p_hat` comes from a SEPARATE model (`surge_hazard_for()`) — a ridge-penalised
logistic regression on salience (search-interest jump, percentile-ranked
within its own election), prior vote and party class, fitted only on the
GOVERNED population (`governed_population()`: low prior vote, not a surging
class, not personally returning — which excludes a declining incumbent like
Adam Bandt by construction, not by tuning). `surge_mu` is the mean share of
past governed candidates who *did* emerge (~35%, from 9 known cases across 5
elections). At `p_hat` near 0 this step does nothing; the closer to 1, the
more the estimate is pulled toward that ~35%.

**4. Renormalise every party in the seat to sum to 100%.**

**This is a patchwork, not one framework, and it shows.** Step 2's slope is a
multiplier bolted onto a linear vote-share formula; step 1 is a hard override
of that formula's input in raw percentage points; step 3 is a linear blend
using the OUTPUT of a genuinely different model (a logistic regression, which
is properly additive on the logit scale) as a blend weight applied back in raw
percentage-point space. Three signals — personal incumbency, defection type,
salience — arrived as three separate bespoke mechanisms discovered one at a
time (2026-08-27/28), not as three terms in one coherent model. That is
mechanically why fixing the salience gap did not also fix the party-defection
gap: they live in structurally different code, and any new signal needs its
own bespoke wiring rather than one more coefficient in an existing sum.

**The actual fix is B2 (compositional/softmax shares)**, already named as the
next structural priority once B1 (full candidate-level rows) was sized and
found not to justify its cost
(`docs/reviews/b1-sizing-2026-08-27.md`). A proper multinomial/softmax model
would put every party's seat share on one additive-logit scale, the way
`surge_hazard_for()` already does for its own probability — at which point
personal incumbency, defection type and salience are each just a coefficient
in the same linear predictor, and a new signal is "add a term" rather than
"invent a new mechanism."

## Load-bearing decisions

**The posterior is exact, not sampled.** Every term in the trend model is
Gaussian, so the whole thing is one sparse linear solve. The anchor's Stan
implementation of the same model takes one to four hours per election; this
takes seconds. That is what makes it affordable to refit the trend at five
horizons for every past election, which is what the projection stage needs to
be honest.

**Fat tails did not require giving that up.** A Student-t likelihood is a scale
mixture of normals, so robustness is a reweighting of the same exact solve
(`fit_trend(nu =)`). It is implemented, tested, and off by default because it
measurably did not help.

**Hyperparameters are estimated, not chosen.** Observation noise and walk size
come from maximising the exact marginal likelihood — pooled across completed
cycles, then re-estimated per cycle and shrunk back. A party's volatility
belongs to the cycle, not to its whole history: One Nation federally needed a
walk 4.9× the pooled value.

**Model scale is per party, decided by evidence.** Vote shares are modelled in
logit or in raw points, whichever the comparable log evidence prefers. Comparing
across scales requires the transform's log Jacobian; without it the two numbers
are densities in different units.

**Everything downstream reads shares, not the model scale.** `fit_trend()`
back-transforms before returning, so `derive_tpp()`, `plot_trends()` and the
seat model never need to know which scale was used. That seam is why adding the
logit scale did not touch them.

## Where the guards are

The unusual thing about this codebase is not the model, it is the checking.
Nearly every real bug found while building it produced *plausible output* and
was caught only against a number someone already knew.

- **Pre-registered checks live in the fit scripts**, not the package, and halt
  the pipeline. **This list is the codes each script actually EMITS**, which
  is what `run_all.R`'s uniqueness guard can see — not the codes its header
  comment pre-registered, which in several scripts were later restated under
  different labels:

  | Script | Emits |
  |---|---|
  | `fit_vic.R` | `F1`, `L2`, `L3`, `L3a`, `L4a`–`L4c`, `V5` |
  | `fit_federal.R` | `A1`–`A4` (plus `A2b`, `A3b`), `FF1`, `FL1`–`FL3`, `FL3a`, `FL4a`–`FL4c`, `FO1` |
  | `fit_nsw.R` | `N1`–`N3`, `NF1`, `NL2`, `NL3`†, `NL3a`, `NL4a`–`NL4c` |
  | `fit_projection.R` | `P1`–`P4`, `B1` |
  | `fit_seats.R` | `S1`–`S4`, `R1`–`R3` |
  | `fit_seats_full.R` | `S5` |
  | `fit_scorecard.R` | `C1`–`C3` |

  † **`NL3` reports rather than halting at the check**, like `fit_vic.R`'s
  `L3`. Both write a marker (`output/NL3-BREACH.txt`,
  `output/L3-BREACH.txt` — deliberately separate files) and `run_all.R` exits
  non-zero on either; `fit_nsw.R` also exits non-zero itself, at the very end,
  after its output is written. NSW 2027's One Nation breaches at 5.15 on three
  polls, and two pre-registered experiments aborted on whether that is the fit
  or the check — see `docs/plans/prereg-poll-tracking-bound-scaling.md`.
  Neither `POLL_TRACKING_BOUND` nor `min_polls` may be moved to clear it.
  Every other check in both scripts still halts where it fires.

  The version of this table before 2026-08-18 listed `fit_vic.R` as `V1`–`V5`,
  `fit_federal.R` as including `H1`–`H4`, and `fit_projection.R` as `B1`–`B3`.
  **None of `V1`–`V4`, `H1`–`H4`, `B2` or `B3` is emitted by any script.** They
  are pre-registrations recorded in the script headers, and the header of
  `fit_vic.R` explains why `V1`/`V3` were restated. A registry listing codes
  that do not exist, while omitting `FF1`, `FO1` and `N1`–`N3` that do, cannot
  serve as the hand-check backstop it exists to be. Open question, not settled
  here: whether the `V`/`H`/`B` pre-registrations still run under other names
  or were dropped.

  The **G codes are the registry worth writing down**, because they are spread
  across scripts that are not all pipeline stages, and `run_all.R`'s clash
  detector only sees the stages:

  | Code | Where | In the pipeline? |
  |---|---|---|
  | G1 | `build_page.R` — the page's blocks all drew | yes |
  | G2 | `build_page.R` — ONP flow against an independent trend fit | yes |
  | G3 | `backtest_flows.R` — the adopted flow estimator still wins | yes |
  | G4 | `tune_szc.R` — sum-to-zero prior by held-out error | no, run on demand |
  | G5 | `tune_sigma_house.R` — house-effect prior | no, run on demand |
  | G6 | `compare_backtest_model.R` — default vs per-cycle volatility | no, run on demand |
  | G7 | `build_page.R` — the **published** fit is structurally valid | yes |

  One-off analysis scripts carry their own prefixes. They are **not** pipeline
  stages, so `run_all.R`'s clash detector never sees them and nothing but this
  list stops a future script reusing a prefix — which is exactly how `B1` came
  to mean two different things:

  | Prefix | Script | What it measures |
  |---|---|---|
  | `SC` | `test_seat_probability_calibration.R` | are per-seat win probabilities calibrated |
  | `EV` | `estimate_fp_extra_var.R` | the first-preference variance the posterior lacks |
  | `FW` | `compare_fp_widening.R` | which widening factor, against the pre-registered rule |
  | `PL` | `test_poll_lag.R` | does the trend's lag behind recent polls hurt |

  Codes must be unique and `run_all.R` stops if two stages claim the same one
  — but only for stages. Adding a code to a standalone script means checking
  this table by hand, and **grepping for it is not enough**: three separate
  greps for these codes have come back incomplete because the pattern assumed
  a quote adjacent to the code, and `cat(sprintf("\nG3 ...` does not have one.
  That is how `B1` came to mean two different things.
- **Structural guards live in the package**, where they can be unit-tested:
  `scale_breaches()`, `trend_tracking()`, `binomial_sd_link()`,
  `check_poll_freshness()`.
- **The published page is executed, not just generated.** `tools/check-page.js`
  runs the page's own JavaScript against a stub DOM and fails if any block did
  not draw. Nothing else covers it: `R CMD check` never looks at HTML, and in
  a browser a page missing three of four charts still renders a headline and
  enough furniture to look fine.
- **Skipped work is counted, not ignored.** `build_projection_data()` returns a
  `skipped` attribute distinguishing "too thin to fit" from "errored", because
  a bug that quietly dropped elections would refit the mix on a shrunken subset
  with no symptom.

Several checks have *failed and changed the design* rather than being explained
away — a global switch to logit was rejected by its own test, and the Victorian
validation checks were restated twice because the check was wrong, not the
model.

## Recurring hazards, all of which have bitten

- **data.table NSE shadowing.** A function argument sharing a name with a
  column, used bare inside `dt[...]`, filters nothing and returns every row.
  Twice here. Masks are now computed outside the brackets with `which()`.
- **`fread` stops early on a ragged row** without erroring. It read 263 of
  `eventual-results.csv`'s 421 lines and trained the fundamentals model on 62%
  of the data. All hand-maintained files now go through `read_anchor_csv()`.
- **Untranslated constants after a scale change.** A hard-coded `0.3` in points
  became a ~20× weaker constraint in log-odds; house effects stopped being
  centred and nothing errored.
- **Leakage in the backtest.** Preference flows were keyed to the election
  being backtested — the realised post-count distribution. Fixing it moved the
  fitted trend weight from 0.57 to 0.52.
- **Blanket `tryCatch`.** Wrapping `load_polls()` swallows its deliberate
  corruption stop and lets a whole region vanish while every check still passes.
- **A guard that reports success for the wrong reason.** The most expensive
  class here, because it is indistinguishable from working. Four instances:
  a page test that counted only `innerHTML` and so called three healthy SVG
  charts missing; the same test then passing a page whose pendulum had failed,
  because the block draws its axes before it touches the data; a conditional
  block exempted from the must-render rule outright, so a caveat that silently
  failed to render still read as OK; and `G1` able to print `NA of NA ... PASS`
  when a log line it parses gets reworded. The rule that catches all four:
  **prove the check fails on a deliberately broken input before trusting it to
  pass.** Every guard in `tools/check-page.js` has been run against a page
  corrupted in the specific way it claims to detect.
- **Hand-maintained identifiers with nothing enforcing uniqueness.** Check
  codes live across seven scripts; `B1` was independently claimed by
  `fit_projection.R` and the page check, so the summary carried two different
  `B1` lines. `run_all.R` now records which stage owns each code and stops on
  a clash. Worth generalising: any hand-maintained key set needs a collision
  check, and a grep for existing keys must match every format they are written
  in — the one run before choosing `B1` matched only some, and so came back
  clean when it was not.
- **A fetch loop dropped failures with `next` and no counter, then scored the
  survivors as the full sample.** 2026-08-23: a Google Trends batch-fetch loop
  hit `widget$status_code == 200 is not TRUE` (an assertion with no status
  code in it, indistinguishable from a real bug) on every NSW batch, `next`ed
  past it silently, and reported "AUC national 0.850 vs state-level 0.775"
  from 9 of 22 candidates — Allegra Spender (34.9% in Wentworth) simply absent
  from the table. Caught by Pete reading the output, not by any check: *"There's
  no way Allegra Spender would be absent from NSW Google Trends, she was
  everywhere."* Same species as the guard-reports-success-for-the-wrong-reason
  bullet above, but the failure mode is an absent guard rather than a wrong
  one. Fixed in `scripts/trends_fetch.R`: every batch outcome is logged, and
  `trends_require_complete()` **aborts** rather than let a caller compute a
  statistic over a subset — proven against a 9-of-22 input before being
  trusted. Re-run complete (22 of 22, both geographies): the real AUCs are
  0.854 national vs 0.846 state-level, materially different from the withdrawn
  numbers. **The general rule this keeps re-teaching: any loop that can skip
  an item needs a counter that a downstream consumer is forced to check —
  "most of it worked" must never look identical to "all of it worked."**

## Data boundary

Nothing from the anchor clone is ever committed: no CSVs, no `external/`, no
`output/`. The clone is disposable and re-cloneable; `anchor_data_path()` is
the single point where the package touches it, and `options(auspol.anchor_dir)`
redirects it for tests. Every test needing that data calls
`skip_if_no_anchor()`, which is why CI runs 217 assertions with the clone
absent.
