# Pre-registration: weight statewide polls by sample size (and pollster record)

Written 2026-10-09, before any statewide sample size has been joined and before
any arm has run. Plan and design: `docs/plans/statewide-poll-weighting-scope-2026-10-09.md`.

## The question

The published poll trend (`trend_as_at()`, `R/projection.R`) gives every poll the
same observation noise, a fixed 1.7 points (`default_sigmas()`, `R/trend.R:275-280`).
Does giving each poll a variance of `non-sampling^2 + sampling(n)` (arm `"sample_n"`),
a time-forward per-pollster multiplier (arm `"record"`), or both (arm `"both"`)
make the forecast better?

## Stated expectation, before running

Three earlier "weight polls more cleverly" changes moved held-out MAE by +0.2%,
-0.6% and 0.0% (`docs/reviews/firm-weights-2026-08-16.md`). The 195-pair test
cannot resolve gains under about 0.02 MAE. **I expect no detectable change in
point accuracy.** Sample size is the one input not yet tried and has a physical
basis, so the plausible gain is in the trend's band: narrower around big polls,
wider around small ones.

## Gate before any arm (step 1 of the plan)

Stop and report, without building the arms, if observed (not filled) sample
sizes cover under 50% of 2010+ anchor polls pooled across regions, **or** the
interquartile range of `n` is narrower than 1,000-1,500 (ratio of 75th to 25th
percentile under 1.5), since then sampling variance barely differs across polls.

## Criterion and rule, fixed now (Pete, 2026-10-09: "accuracy OR bands")

**Incumbent:** equal weights, today's published configuration. It wins ties.

An arm SHIPS if it passes the guards and **either**:

1. **Accuracy:** held-out MAE from `projection_loo()` (leave-one-election-out,
   all horizons pooled, the measure used for every earlier trend decision)
   improves by more than **0.02**; **or**
2. **Bands:** held-out MAE is no worse than the incumbent's **+0.02**, AND the
   trend band predicts held-out polls better: one-step-ahead, fitting each cycle's
   trend only on polls before each poll's date, the poll's predictive 95% interval
   (trend band combined with that poll's own noise under each arm's noise model)
   covers it at a rate **closer to 95%** than the incumbent's, AND the mean log
   predictive density of those held-out polls is higher by **more than 1 standard
   error, clustered on cycle**. Log predictive density is the primary of the two;
   coverage alone cannot ship.

**Guards (any failure refuses):**

- Coverage of `build_projection_data()` within 5% of the incumbent, and zero
  pairs skipped for reason `error`.
- `B2`/`B3` (`scripts/fit_projection.R`: published 95% interval coverage in
  [88%, 99%], 50% in [38%, 62%]) still pass.
- Every number reported per horizon and per region; alternating signs across
  horizons are read as noise, not a horizon to pick.
- The same metrics on the subset of polls with an OBSERVED sample size, so a
  gain that exists only where `n` was filled is visible.
- Runtime under 3x the incumbent's `build_projection_data()`; above it the
  accuracy bar doubles to 0.04.

## Leakage rules

- The pollster record uses only elections strictly before the cycle under test
  (`as_of = cyc$start[1]`), with an assertion that no record's election date is
  on or after `as_at`. A deliberately leaked record must fail that assertion in a
  test.
- The fill value for a missing `n`, the non-sampling variance and the shrinkage
  strength come from earlier cycles only.
- The one-step-ahead band check never lets a poll see itself or any later poll.
- The 2026 Victorian and 2027 NSW cycles are never scored.

## What is not a criterion

That sample size is "more correct". That the scrape took a day. That the bands
look nicer on the chart.

## Amendments

(none yet; any change is added below this line with the original text left as is)

## RESULT 2026-10-09: GATE FAILED, no arm built

Scraped every Wikipedia national and state poll table (`scripts/fetch_statewide_poll_samples.R`, raw pages in `external/reference/polls/statewide-samples/raw/`) and joined to the anchor polls (`scripts/join_statewide_poll_samples.R`, all 6,093 rows kept; date/primary/region scrambles match 0-13 of 1,178). `docs/reviews/statewide-poll-samples-2026-10-09.md`.

- Observed sample size on **432 of 2,781** 2010+ polls (**15.5%**, bar 50%). By region: fed 19%, vic 7%, nsw 4%, qld 8%, wa 7%, sa 9%. Wikipedia has no state poll page before Victoria 2022 and none for WA or SA; 10 elections have no poll rows at all.
- Spread: interquartile range **1,242 to 1,698** (ratio **1.37**, bar 1.5); median 1,516, p10 1,033, p90 2,260.

Both clauses refuse. Per the clause-refusal rule this goes to Pete; the arms are not built.

## Amendment 1 (2026-10-09, after the gate failed, before any arm ran): two arms that need no sample size

Pete chose to build the pollster track record and an estimated poll noise instead ("1"). Same criterion, guards and leakage rules as above, unchanged. Arms against the equal-weights, fixed-noise incumbent:

- `weights = "record"`: each pollster's noise factor from its deviations from RESULTS at elections held before the cycle began (`firm_record_factors()`, `R/poll_record.R`): per poll and party (ALP, LNP, GRN), poll minus result minus the recency-weighted mean miss of all polls of that election (the shared miss is not a firm's record), recency weight halving every 30 days before polling day (`POLL_RECORD_HALFLIFE`), shrunk to the pool by 12 pseudo-polls (`POLL_RECORD_K`, as `estimate_firm_factors()`), as an sd ratio. All six regions' past elections count.
- `sigmas = "pooled_tf"`: sigma_obs and sigma_rw by marginal likelihood over the region's cycles that ended on or before the cycle began (`poll_sigmas_time_forward()`); defaults kept when fewer than 2 earlier cycles or at a bound.
- `both`: the two together.

The bands half is scored on held-out polls: each horizon's fit scores the polls from its cutoff to the next shorter horizon's cutoff (`poll_predictive_scores()`), so no poll is scored twice per cycle. Log predictive density, SE clustered on (region, election).

Expectation on record: small or no effect; the within-cycle version of the record arm measured 0.6% worse.

## RESULT, Amendment 1 arms (2026-10-09): all three REFUSED

`scripts/compare_poll_record.R`, regions fed/nsw/vic/qld, 195 election-horizon pairs in every arm, 0 errors, 14,234 held-out polls scored per arm (878 region-election clusters). Held-out MAE lower is better; log density higher is better.

| arm | held-out MAE | MAE gain vs equal | log density per poll-party | gain vs equal (SE) | 95% cover of held-out polls | B2 / B3 | runtime |
|---|---|---|---|---|---|---|---|
| equal (incumbent) | 2.0659 | - | 0.0564 | - | 0.914 | 0.949 / 0.549 | 56 s |
| record | 2.0728 | -0.0070 | 0.0549 | -0.0016 (0.0014) | 0.911 | 0.949 / 0.544 | 57 s |
| noise (pooled_tf) | 2.0703 | -0.0044 | 0.0255 | -0.0309 (0.0176) | 0.968 | 0.949 / 0.544 | 1005 s first run (17.9x; ~1x from the disk cache) |
| both | 2.0714 | -0.0055 | 0.0301 | -0.0263 (0.0167) | 0.966 | 0.949 / 0.549 | 56 s (cached) |

- Accuracy: every arm is slightly worse, inside the 0.02 bar; none clears it.
- Bands: the estimated noise moves held-out coverage from 91.4% to 96.8% (closer to 95%) but makes the log predictive density WORSE, because the wider bands are too wide; the primary of the two band measures refuses.
- The record arm is worse on both; the pollster that was accurate at the last election is not reliably accurate at the next.

Equal weights and the fixed 1.7-point noise stay. Switches built, all off: `weights = "record"`, `sigmas = "pooled_tf"`.
