# Anchor model: AE Forecasts (aus-polling-analyser)

Analysed 2026-08-14. Local clone of the model repo: `external/aus-polling-analyser`
(disposable third-party clone). Methodology text extracted from the website repo
`d-j-hirst/election-forecast-website-au` (`frontend/src/components/Methods/*`).

## Architecture (his stack — what we're replacing with R)

Four stages, three languages:

1. **Historical calibration** (Python) — pollster house effects/volatility, trend-vs-result
   adjustments, seat behaviour statistics. Everything leave-one-out to avoid look-ahead.
2. **Poll trend** (Python + PyStan) — Bayesian hidden-state model of true voting intention.
3. **Projection** (C++) — trend + "fundamentals" → probability distribution of election-day
   vote shares.
4. **Simulation** (C++) — ≥100,000 Monte Carlo elections, seat by seat.

Runtimes he reports: 1–4 hours per election for the Stan poll trend; multi-day for full
historical regeneration. Calibration is the expensive part.

## Stage detail

### 1. Poll trend (the Jackman/Mark-the-Ballot model)

- Latent voting intention follows a **Gaussian random walk** per party; step size increases
  during campaigns (esp. final 2 weeks).
- Polls = latent value + house effect + noise. Modelled per party FP (parties >~3%, or >5%
  at a past election), plus an "Others" residual category. TPP is *derived from FP via
  preference flows*, not taken from published poll TPPs.
- **House effects vary over time**: separate "new" (<4 months) and "old" (>8 months) house
  effects with linear blend between.
- **Pollster calibration is relative, not absolute** (too few elections per pollster for
  direct scoring). Leave-one-pollster-out comparison trends measure per pollster:
  - *Trend tracking* (noise vs the consensus trend) → weight for short-term movement
  - *Typical bias* (house-effect + final trend vs actual result) → bias correction
  - *Bias consistency* (std dev of bias across elections) → weight for absolute level
  - Bayesian-style priors ("initial" pseudo-elections) shrink new pollsters toward
    erratic/neutral until they earn a track record.
- Undecideds removed and rescaled; missing minor-party FP imputed from trend.

### 2. Fundamentals

Expected result with zero polling. Per party *category* (TPP, ALP FP, LNP FP,
"constituency minors" e.g. Greens, "populist minors" e.g. ON/UAP, Others, Unnamed others):

- Inputs: previous vote (or 6-election average for majors; 50-50 for TPP), incumbency and
  years in government/opposition, and for state elections whether the same party holds
  federal government.
- **Elastic-net linear regression** on all elections since 1990, validated leave-one-out.
- Economic variables deliberately excluded (weak predictors in Australia — cites Armarium
  Interreta analysis).
- Federal TPP fundamentals = plain 50-50 (regression didn't beat it).

### 3. Projection (trend × fundamentals mix)

For each party category × time-to-election:

1. Subtract historical *bias* of both trend and fundamentals at that time horizon
   (e.g. "Others"/populists systematically poll too high 1–2 years out).
2. Optimal **mix factor** (trend weight vs fundamentals weight) fitted on past elections;
   fundamentals dominate far out, trend dominates near election day.
3. Residual bias correction, then error distribution: std dev + kurtosis measured
   **separately for positive and negative errors** (asymmetry).
4. Parameters heavily smoothed across time horizons.

Validation (his numbers): at 1 year out, mean abs TPP error 2.87 pts for the projection vs
3.68 fundamentals-only, 3.77 trend-only, 4.29 naive baseline.

Election samples: draw minor FPs, then either FP-first (normalise, derive TPP via
preference flows) or TPP-first (back-calculate major FPs) — chosen randomly per simulation.
Preference flows themselves get random variation. "Emerging party" (à la ON 1998, PUP 2013)
appears stochastically, probability declining as election nears.

### 4. Seat simulation

- **Regional swings**: swing *deviations* from the national swing, aggregated Bayesian-style
  from regional poll breakdowns, sum-to-zero (population-weighted). Regional polls are
  calibrated for bias / sensitivity (polls exaggerate regional differences) / error spread.
  Unpolled regions (Tas/ACT/NT federally) use historical deviation patterns.
- **Seat TPP**: regional swing applied to redistribution-adjusted margin (Antony Green's
  estimates), scaled by **seat elasticity** (validated leave-one-out), plus candidate
  effects: retirement (loss of personal vote), sophomore surge (candidate and party
  variants), disendorsement/recovery.
- **Federal-state correlation**: state seats absorb ~55% of the co-located federal swing at
  concurrent elections, decaying to ~33% at ±6 months; effect size randomised via gamma
  distribution.
- Per-seat random variability floored at ~half the average (small-sample protection).
- Linear rescale so seat TPPs aggregate back to regional and national sample values.
- **Seat FP**: minor/IND FPs first from historical category behaviour; independents get
  recontest probabilities, "prominent challenger" handling (seat polls + betting odds,
  wide error bars per Bonham's seat-poll scepticism), and a beta-distributed shared bias
  so IND totals vary realistically. Populist minors contest a random subset of seats,
  placed by ideology. Greens (and other minors/INDs) nudged by seat betting odds via
  preliminary-simulation inversion. Nationals-vs-Liberal split modelled by regression on
  past two elections. Major FPs back-derived from seat TPP + preference flows; 5 rounds
  of iterative reconciliation to match the national sample (converges <0.1%).

## Data sources he uses

| Source | What | How |
|---|---|---|
| Pollster releases / news media / Poll Bludger / Wikipedia; pre-2007 from Kevin Bonham | National + state voting-intention polls, leader approvals | **Hand-maintained CSVs** (`analysis/Data/poll-data-*.csv` — fed file has ~4,000 polls back to 1943). Verified vs originals/Wayback. |
| Wikipedia electoral-results category pages | Historical seat-level FP/TCP results, all states + federal | Scraped + cached by `election_data.py`, with hand corrections |
| AEC (`results.aec.gov.au`, media feed XML) | Official federal results incl. booths, preference distributions, live feed | `downloads/` XMLs, C++ ResultsDownloader, `federal_state.py` |
| State electoral commissions (NSW pastvtr, QLD results site, VEC) | Official state results | Selenium fetchers `fetch_election_data_{nsw,qld,vic}.py` |
| Antony Green | Redistribution-adjusted margins (incl. drafts) | Manual |
| Seat betting odds | Prominent INDs, Greens, minor-party seat chances | His separate `betting-odds-collector` repo (Python) |
| Seat polls | Prominent candidates, heavily discounted | Hand-entered (`Seat polling.xlsx`, `Regional/*-polls`) |
| Hand-maintained reference CSVs | Incumbency, leaders, by-elections, preference estimates, seat types (urban/provincial/rural), region mappings, discontinuities | `analysis/Data/*.csv` |

## Sources he does NOT use (our opportunities)

1. **ABS Census at electorate level** — ABS publishes Census data on **CED/SED
   geographies** (Commonwealth/State Electoral Divisions), plus SA1→CED correspondence
   files for custom aggregation after redistributions. His seat model uses only a coarse
   urban/provincial/rural label and each seat's own history. Demographic covariates
   (age, income, education, ancestry, mortgage stress, industry of employment) enable
   538-style demographic swing modelling — e.g. education gradient in teal seats 2022,
   or CALD-community swings 2025. Also useful: post-redistribution margin estimation
   from booth+SA1 building blocks instead of relying solely on Antony Green.
2. **AEC booth-level results + GIS** — he uses seat-level Wikipedia data for history;
   booth-level (AEC Tally Room downloads, state commission equivalents) supports
   sub-seat swing structure, demographic regression, and better new-seat estimates.
3. **AEC/commission enrolment statistics** — enrolment growth by division (fast-growing
   outer-suburban seats behave differently; roll composition shifts between elections).
4. **Australian Election Study (AES)** — post-election academic survey since 1987;
   validates demographic vote models, preference-flow behaviour by demographic.
5. **MRP polls now published in Australia** (YouGov/DemosAU seat-level MRP 2022→2025) —
   as *inputs* to seat priors, and MRP as a *technique* we could eventually run ourselves
   off raw crosstabs + Census frames.
6. Minor: candidate databases (gender, local-government background), Google Trends
   (probably noise), economic data (he tested — weak, agree to deprioritise).

## Honest assessment of the anchor

Strengths: rigorous leave-one-out discipline everywhere; relative pollster calibration
(right call for Australia's thin pollster history); asymmetric fat-tailed error
distributions; federal-state swing correlation (novel); iterative FP/TPP reconciliation.

Weak spots / improvement candidates (closed 2026-10-25, outcome per bullet):
- Seat demographics essentially unused (one 3-level seat-type factor).
  - **Outcome: built for the seat vote, in part.** A census-based demographic correction
    on Labor and Greens shipped 2026-09-29 (`AUSPOL_DEMO_RESID = "2"` in
    `scripts/published_flags.R`; `docs/plans/prereg-demographic-labor-greens-2026-09-29.md`).
    The full-strength version (F7) goes to a 20,000-simulation deciding run on 26 Oct
    (`docs/DECISIONS.md`, 2026-10-25). Still open: tracking how demographics vote over
    time (`docs/PETE-ASKED-FOR.md`). The preference-flow models do not use census data
    (searched `R/flow_model.R`, `R/flow_estimate.R`, `R/xgb_flow_override.R`: no hits).
- No MRP / no raw crosstab usage — polls enter as topline numbers only.
  - **Outcome: not done.** MRP needs respondent-level data and we have toplines
    (`docs/plans/plan-mrp-scoping.md`, 2026-08-25). Poll crosstabs were tested and not
    shipped (PR #87; still open in `docs/PETE-ASKED-FOR.md`). DemosAU's published MRP seat
    estimates do enter as seat polls (`docs/DECISIONS.md`, 2026-10-09 and 2026-10-13).
- Preference flows modelled at national level with noise, not by seat demographics.
  - **Outcome: flows are now fitted per election and applied per seat, but not from seat
    demographics.** An xgb flow override, then the how-to-vote card order into a per-seat
    `conditional_override` (`ARCHITECTURE.md`, simulator row 10;
    `docs/plans/prereg-xgb-flows-v1-2026-09-10.md`, `docs/plans/prereg-htv-flow-2026-09-18.md`).
    The count draws each flow's noise per seat (`docs/NEXT-STEPS.md`). Flows by seat
    demographics: **UNVERIFIED**, no such model found.
- Betting odds enter in an ad-hoc "nudge" way.
  - **Outcome: odds are not a model input here; they are an outside benchmark.** Our seat
    probabilities were scored against bookmaker odds for four past elections
    (`docs/reviews/backtest-vs-bookmakers-2026-10-24.md`), and the `oddsdata` package
    holds the odds (`docs/PETE-ASKED-FOR.md`, 24 Oct). Using odds or seat polls as an input
    for new independents is an open question for Pete (`docs/NEXT-STEPS.md`).
- Upper houses not modelled at all.
  - **Outcome: still not modelled, deferred on purpose** ("Deliberately deferred" in
    `docs/plans/product-features.md`, 2026-08-14). Senate results are used only as a
    feature for ranking One Nation's chances in seats with no history (`docs/DECISIONS.md`,
    2026-10-25). I found no later decision to build an upper-house forecast, so whether it
    was formally ruled out is **UNVERIFIED**.
- Poll CSVs hand-maintained — labour-intensive, no pipeline from Wikipedia poll tables.
  - **Outcome: partly fixed.** Our own poll source (Wikipedia, then Poll Bludger) shipped as
    step 1 on 2026-10-11 and was layered over AE Forecasts' file on 2026-10-13
    (`docs/DECISIONS.md`). Wikipedia alone cannot replace that file: fed2007, wa2001 and
    nsw2019 have no usable tables (`docs/reviews/own-poll-source-step1-2026-10-11.md`).
    Moving off AE Forecasts' file entirely is still open (`docs/NEXT-STEPS.md`).
- C++/Python/Stan split makes the whole thing hard to reproduce (multi-day regeneration).
  - **Outcome: avoided by design.** One language (R) and an exact Gaussian trend with no
    MCMC (see "Decisions made since" below). `scripts/run_all.R` runs the chain in one
    command (`ARCHITECTURE.md`) and `.github/workflows/forecast.yaml` refreshes it daily.
    Caveat: the commission preference-distribution fetchers write to gitignored `output/`,
    so that path runs locally and not in CI (`ARCHITECTURE.md`).

## Decisions made since (were "pending Pete" as of 2026-08-14)

- **R architecture: not Stan.** The trend is an exact Gaussian posterior via one
  sparse Cholesky solve (`fit_trend()`) — no MCMC, seconds per cycle rather than
  the anchor's 1-4 hours. See `ARCHITECTURE.md`, "Load-bearing decisions."
- **Simulation stays in R**, vectorised; profiled 2026-09-03 and optimised
  (string-keyed environment replaced with an integer-indexed list) rather than
  moved to Rcpp — see `docs/NEXT-STEPS.md`, "the seat simulator's hot loop."
- **Target: Victoria, 28 November 2026** (not the 2028 federal pilot floated
  here) — see `README.md`.
- **Website/journalism layer**: `build_page.R` produces a self-contained HTML
  forecast page (checked end-to-end by `tools/check-page.js`); a fuller
  journalism/interactive layer beyond that page is still a later phase.
