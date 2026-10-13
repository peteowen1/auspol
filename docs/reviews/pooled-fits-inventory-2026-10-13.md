# Pooled fits that mix jurisdictions — inventory, 2026-10-13

**Why this exists.** On 2026-10-13 the backtest grew from 23 to 35 elections
(NT, older NSW, Qld and SA). Every fit that pools individual cases across
jurisdictions and then forecasts another election now lets the jurisdiction with
the most cases set the number for the others. This lists every such fit found,
what it counts, whether it is time-forward, and whether the new switch
`AUSPOL_POOL_BY_JURISDICTION` (default and published `"0"`) reaches it.

The switch uses `pool_by_group()` (`R/pool_hierarchical.R`): each jurisdiction's
median, partially pooled toward the precision-weighted mean of the jurisdiction
medians, with the between-jurisdiction variance estimated net of noise
(DerSimonian–Laird) and each jurisdiction's own spread moderated toward the
pooled spread with 3 pseudo-degrees of freedom.

How each row was checked: rows marked **(read)** were read in the code for this
review; rows marked **(survey)** come from a read-only survey pass and were not
re-read line by line.

| # | Fit | Estimates | Statistic, unit counted | Time-forward? | Where it runs | Switch wired? |
|---|-----|-----------|-------------------------|---------------|---------------|---------------|
| 1 | `fit_defector_discount()`, R/candidate_returns.R **(read)** | Share of a major-party candidate's vote they carry after leaving the party: sitting members (`discount_mp`), losing candidates (`discount_loser`), all (`discount`) | Median of ratios; unit = person (case) | Yes (`fit_pairs_for`) | Per target, in every harness and in `personal_prior_vote()` (mode `AUSPOL_DEFECT_POOLED=2`) | **Yes**, all three rates. Supersedes the federal/state split of `AUSPOL_DEFECT_BY_LEVEL` when on; not applied under `AUSPOL_DEFECTOR_STATE=1` (which has its own pooling) |
| 2 | `fit_minor_defector_discount()`, R/candidate_returns.R **(read)** | Share a candidate carries when switching between two non-major labels (sitting / not) | Median of ratios (or geometric mean if `agg="geomean"`); unit = person | Yes (`fit_pairs_for`) | Per target, every harness and `fit_seats_full.R` | **Yes** (median mode only; the geomean mode is unchanged) |
| 3 | `fit_sitting_minor_level()`, R/candidate_returns.R **(read)** | Vote share a sitting non-major member typically holds at the next election (by-election winners' credit) | Median of next-election shares; unit = person | Yes (`fit_pairs_for`) | Per target, inside `personal_prior_vote()` | **Yes** |
| 4 | `fit_minor_defector_conserve()`, R/candidate_returns.R **(read)** | Share of a minor-to-minor switcher's vote their ORIGIN class keeps (shipped, `AUSPOL_MINOR_DEFECT_CONSERVE=1`) | Median of clipped fractions; unit = person; `min_n = 8` | **NO — leave-target-out only** (`if (identical(pr$election, target_election)) return(NULL)`, no `fit_pairs_for`), although a comment inside says "time-forward" | Per target, inside `personal_prior_vote()` | No. **The leak is the bigger problem** and is a separate fix (one line, `fit_pairs_for`), which changes shipped output, so it is not made here |
| 5 | `fit_departed_origin_return()`, R/candidate_returns.R **(read)** | Share of a departed leader's vote that returns to the major party they came from | Median of clipped fractions; unit = person | **NO — leave-target-out only** | Per target, harnesses + `fit_seats_full.R`, only under `AUSPOL_DEPARTED_ORIGIN` (published `"0"`) | No: switch off in production; fix the leak first if it is ever revived |
| 6 | `fit_major_departed_slope()` and the other slopes in R/split_slope.R (`fit_split_slopes`, `fit_conditional_slopes`, `fit_major_conditional_slopes`, `fit_dispersion_slopes`) **(survey)** | Persistence slopes of a seat's deviation from the statewide level | Through-origin regression; unit = seat-class row (thousands of rows; every jurisdiction contributes in proportion to its seat count) | Yes (`fit_pairs_for`) | Per target | No. A regression slope, not a centre: pooling it by jurisdiction needs a per-jurisdiction slope and its SE (a different helper). The unit is the seat, so the problem is "big parliaments dominate" (federal 150 seats, NT 25), not "a few cases swamp" |
| 7 | `scripts/fit_mp_slope.R` → `output/mp-slope-by-target.csv` / `-by-class.csv` **(read)** | Persistence slope of non-major deviations for sitting members vs also-rans | Through-origin regression; unit = seat-class row | **NO — leave-one-election-out** (`panel[target != t]`): each fold trains on LATER elections | Offline script; harnesses read `mp-slope-by-target.csv`, `fit_seats_full.R` reads `-by-class.csv` | No: offline regression (as 6), and it should be made time-forward before anything else |
| 8 | `scripts/fit_departed_successor_rates.R` → `output/departed-successor-*.csv` **(read)** | Independent vote retained after a departed independent, by successor flag | Ratio of SUMS of votes; unit = vote (so a federal seat of ~110,000 voters outweighs an NT seat of ~5,000 by ~20 to 1); already partially pooled strong/weak toward the pooled rate | Yes (`election_date < tday`) | Offline; read at run time by `departed_successor_rates()` | No: offline script with its own shrinkage; the unit is votes, so NT is close to weightless here, the opposite problem |
| 9 | Salience surge v2 (`R/salience_surge.R`, pair list `SURGE_V2_PAIRS` in each harness) **(survey)** | Probability a governed candidate surges, from salience jump and class | Ridge-penalised logistic regression; unit = candidate row | Harness use is time-forward (`backtest_candidate_fed.R:1728`, `elections_before`); the validation script `fit_salience_surge_v2.R` uses nested leave-one-out | Per target | No: a logistic model, not a centre. A jurisdiction random intercept would be the analogue; not clean to add |
| 10 | `thin_cycle_statewide()` tau, R/thin_cycle.R **(read)** | Typical statewide swing per party class, the prior spread for cycles with too few polls | Mean of squared swings per class, shrunk across classes; unit = election pair x class | Yes (own date filter) | Per target, only where the polled path fails (NT, wa2021) | No: a variance, not a centre, and each jurisdiction contributes one row per election, so the case-count problem is mild (NT adds one row per NT election, as every jurisdiction does) |
| 11 | `.defstate_rate()`, R/defector_state.R **(read)** | Sitting-member defector carry under `AUSPOL_DEFECTOR_STATE` | Median, level (federal/state) shrunk with K = 3 pseudo-cases; unit = person | Yes (inputs from #1) | Per target, only when that switch is on (published `"0"`) | No: has its own pooling; `AUSPOL_POOL_BY_JURISDICTION` deliberately leaves it alone |
| 12 | `departed_rate = c(IND = 0.38)` default in `screened_slopes()`, R/dev_slope.R **(survey)** | Departed independent leader's retention | Constant, measured offline (n = 305) | Superseded by #8 when `AUSPOL_DEPARTED_SUCCESSOR=1` (published) | Per target | No |

## Not covered

The survey did not classify every one of the ~170 `median(`/`mean(`/`lm(` hits
across 51 files, nor the `build_*`, `score_*`, `prereg_*` and `screen_*` scripts
that loop over `all_election_pairs()`. Those are diagnostics or one-off builders as
far as the file names go; that is **unconfirmed**.

## Two leaks found along the way (not fixed here)

- **#4 `fit_minor_defector_conserve()` is SHIPPED and not time-forward.** Every
  backtest target's origin-keeps fraction is fitted on later elections too. One
  line (`pairs <- fit_pairs_for(target_election, pairs)`), but it moves published
  backtest numbers, so it needs its own measured change.
- **#7 `fit_mp_slope.R` is leave-one-election-out**, which CLAUDE.md already names
  as not time-forward.
