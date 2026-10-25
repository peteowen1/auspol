# Pre-registration: the others-bucket scale fitted per jurisdiction (`AUSPOL_OTHERS_SCALE_JUR`)

Written in the 25 Oct night session (calendar date 26 Oct), before any screen of this switch has run. Pete chose
(25 Oct): pre-register and screen all four built-but-off experiment branches. Branch
`worktree-agent-a9cb9eebe64bafa28`, one commit `8ad808b` (2026-10-06). Rules: `docs/PRE-REGISTRATION-RULES.md`
(standard decision rule of 2026-10-18), the shrinkage and leakage rules in `CLAUDE.md`. Nothing in `R/` or
`scripts/` is edited by this plan and the branch is not merged by it.

## The question

Polls overstate the classes they do not track (the "others" bucket: OTH plus every class folded into it). The pooled
correction `AUSPOL_OTHERS_SCALE` was REFUSED 2026-09-28 (`docs/plans/prereg-others-bucket-size-2026-09-27.md`: mean
|bucket error| 2.010 -> 1.783, t -0.96 against a -1 SE bar; sunk by fed2007, k = 1.323 fitted on two WA elections).
Pattern 2 of `docs/reviews/major-party-error-2026-10-06.md` says the bias is jurisdiction-specific (majors' summed
miss about +4.4 in Victoria and +4.6 in Queensland, about 0 federally, negative in NSW and SA), so a pooled fit
averages it away. Does fitting the scale per jurisdiction from its own earlier elections, partially pooled toward the
all-jurisdiction value, predict seats better?

## What the branch does (read from the diff)

- `others_bucket_scale_jur(before, region, hist)` in `R/others_bucket.R` (exported, `.Rd` written). On log ratios
  `r = log(actual / forecast)` of the bucket, earlier elections only: prior `mu0 = w0 * m0` (the pooled fit's own
  correction, so no jurisdiction history gives exactly the pooled `k`); within variance `sigma2` pooled over all
  earlier elections; `se_j^2 = sigma2 / n_j`; `tau2 = max(0, var(jurisdiction means) - mean(sigma2 / n_j))`;
  `w = tau2 / (tau2 + se_j^2)`; `log k = mu0 + w (m_j - mu0)`. No `min_n`.
- Applied in `statewide_draws_as_at()` (`R/forecast_mode.R`, the six harnesses, `OB3` log line), REPLACING the
  pooled scale when both are set, and in `scripts/fit_seats_full.R` before `LL1` (live Victoria).
- `scripts/published_flags.R`: `AUSPOL_OTHERS_SCALE_JUR = "0"`. Tests in `tests/testthat/test-others-bucket.R`
  (no-history fallback, one earlier election, time-forward, follows a jurisdiction whose bias differs, default off).
- It moves the statewide level, which feeds `base_pred` in every seat. In the harnesses that reaches the xgb layer
  through `AUSPOL_XGB_BASE_DELTA=1` (shipped: cells whose base moved are re-predicted by the frozen as-at trees with
  the new base as `base_margin`), and live through `xgb_primary_predict_live()`'s `base_margin`. So both layers are
  measured by one screen; the trees' `level_pred` feature (from `output/level-pred.csv`) does NOT see the scale in
  the screen.

## Merge state and cached files

- **Does NOT merge cleanly onto `origin/dev`.** `git merge-tree` reports conflicts in `scripts/published_flags.R`
  (adjacent lines: dev added `AUSPOL_MINOR_ADDITIVE*`; the branch re-spaced `AUSPOL_ANCHOR_EXHAUST`; keep both, take
  dev's spacing) and `scripts/fit_seats_full.R` (dev added the `AUSPOL_LEVEL_RECENT` blend and the
  `.state_mean_trend` capture exactly where the branch put its live block). The second is an ORDER question, not a
  text one: in the backtests the scale acts inside `statewide_draws_as_at()`, BEFORE the anchoring and BEFORE the
  recent-poll blend (`R/forecast_statewide.R:407` calls `level_recent_apply()` after `forecast_statewide_for()`).
  For parity the live block belongs BEFORE the `AUSPOL_LEVEL_RECENT` block, not after it. Recommendation for the
  merge, not decided here: put it before `.state_mean_trend <- state_mean`. This does not affect the screen
  (`quick_arm.R` runs only the six harnesses), but it must be reviewed before anything ships. The branch is 764
  commits behind `origin/dev`, so it must be screened merged.
- **Cached input that must be rebuilt first: `output/others-bucket-history.csv`.** The copy on disk is from 28 Sep
  (1,104 bytes, 22 elections, `wa2001` to `sa2026`), built from an audit run at the code of that day. The scoreboard
  now has 35 elections (`docs/reviews/level-jurisdiction-bias-2026-10-25.md`) and the statewide recipe has changed
  since (level recipe, thin-cycle estimate). Rebuild it from an audit with BOTH switches off, at the merged code, in
  the scratch worktree's own `output/` (never the main checkout's):
  `AUSPOL_OTHERS_SCALE=0 AUSPOL_OTHERS_SCALE_JUR=0 AUSPOL_AUDIT_TAG=-jur0 Rscript scripts/audit_statewide_forecast.R` then
  `AUSPOL_AUDIT_TAG=-jur0 Rscript scripts/build_others_bucket_history.R`. Not timed; the audit draws 20,000
  statewide simulations per election, so time one election before launching all of them. The scratch worktree's
  `output/` must first hold a copy of the main checkout's `output/` top-level files plus the six subdirectories
  `quick_arm.R` copies (`booths`, `cache`, `shipped`, `xgb-base-ref`, `xgb-primary-asat`,
  `xgb-primary-v6-models`); `quick_arm.R` then takes its inputs from that copy, because it prefers the checkout's
  own `output/` when it holds `xgb-primary-asat-predictions.csv` (`scripts/quick_arm.R:84-88`).
- **No xgb retrain is needed for the screen** (base-delta carries the base change to the frozen trees, as for every
  shipped post-xgb `base_pred` fix since 2026-10-06). If the arm ships, the next full rebuild trains the trees on
  the corrected base; that is the normal pipeline, not a precondition.

## Sizing before the screen (a re-implementation, not the package code)

`C:\Users\peteo\AppData\Local\Temp\claude\C--dev-auspol\4653355c-88c2-4b09-a6da-4c710aaceceb\scratchpad\ob_jur.py`
re-implements `others_bucket_scale()` (dev) and `others_bucket_scale_jur()` (the branch) in Python and runs them on
the 28 Sep history. Check on the instrument: it reproduces the refused pooled arm's published mean |bucket error|,
2.010 -> 1.782 (the prereg's result says 1.783).

Bucket size in points, forecast and counted; |error| is |forecast x k - actual|, lower is better. AEF-7 rows only:

| target | earlier elections of its jurisdiction | w (jurisdiction weight) | k pooled | k per jurisdiction | forecast | actual | |error| shipped | |error| arm |
|---|---|---|---|---|---|---|---|---|
| fed2022 | 5 | 0.00 | 0.909 | 0.909 | 14.44 | 14.50 | 0.06 | 1.38 |
| vic2022 | 2 | 0.00 | 0.915 | 0.915 | 19.74 | 17.09 | 2.65 | 0.97 |
| nsw2023 | 1 | 0.00 | 0.911 | 0.911 | 20.85 | 17.97 | 2.88 | 1.02 |
| qld2024 | 1 | 0.00 | 0.907 | 0.907 | 9.76 | 8.04 | 1.72 | 0.82 |
| wa2025 | 5 | 0.00 | 0.902 | 0.902 | 14.19 | 14.33 | 0.14 | 1.53 |
| fed2025 | 6 | 0.00 | 0.907 | 0.907 | 15.12 | 14.94 | 0.18 | 1.22 |
| sa2026 | 1 | 0.00 | 0.911 | 0.911 | 12.59 | 10.40 | 2.19 | 1.07 |

**Finding that changes what the screen measures: on this history the between-jurisdiction variance tau2 is 0 at
every target from fed2016 on, so the per-jurisdiction arm is IDENTICAL to the refused pooled arm at all seven AEF-7
targets.** The jurisdiction term only fires early (wa2008 w 0.98, fed2010 0.87, wa2013 0.97, fed2013 0.48), so the
code path is live, not dead; the jurisdiction means simply do not spread more than their noise once there are
enough elections. Over all 22 elections the per-jurisdiction arm is WORSE than the pooled one (mean |error| 1.851
against 1.782), from wa2008 and wa2013. So, unless the rebuilt history changes this, an AEF-7 screen of
`AUSPOL_OTHERS_SCALE_JUR=1` is a seat-log-loss screen of the pooled `AUSPOL_OTHERS_SCALE=1` (which has never been
scored on seat log loss: its refusal was on bucket error). That is still new information, and Pete chose to screen,
so the screen runs; the result is reported under both names.

## Arm

| arm | switch | rule |
|---|---|---|
| shipped | `AUSPOL_OTHERS_SCALE_JUR=0`, `AUSPOL_OTHERS_SCALE=0` | as published |
| JUR | `AUSPOL_OTHERS_SCALE_JUR=1` | the branch's rule, nothing tuned |

No grid. The shrinkage weight is estimated; nothing is chosen after the screen.

## Screen and criterion

Instrument: `scripts/quick_arm.R` from the scratch worktree (merged, history rebuilt), AEF-7 default pairs
(681 seats), `--sims=1000`, baseline the shipped configuration, common random numbers.

This is a GENERAL change within each election (the statewide level moves every seat), so the election-wide metric
is the right primary (`PRE-REGISTRATION-RULES.md`, "general" row of the table).

- **Primary**: Q3, pooled seat-winner log loss on AEF-7, arm minus shipped, SE clustered on election; better means
  below 0 by more than 1 SE.
- **Targeted**: the elections pattern 2 named, in AEF-7: vic2022 and qld2024 (both over-forecast buckets), seat log
  loss per election from Q1 and the statewide bucket |error| from the `OB3` lines. Reported with each election's own
  paired SE; nsw2023 and sa2026 (also over-forecast) beside them.
- **Guards**: G1 Q3 not worse by more than 1 SE; G2 no AEF-7 election worse by more than 1 SE of its own paired
  seat differences (stricter than standard clause 4, set by tonight's brief; a G2-only refusal of an arm that
  otherwise passes goes to Pete with the split, standard clause 9); G3 leave-one-election-out, the pooled change stays
  below 0 by more than 1 SE with each election dropped (for an arm that passes); Q2 squared share error on changed
  cells reported, never a vote.

**Decision rule.** Primary better by more than 1 SE and G1 to G3 hold and nothing below is unacceptable: passes the
screen and earns the deciding run (`scripts/deciding_run.ps1 -Arm "AUSPOL_OTHERS_SCALE_JUR=1" -Label obj`, all
elections, 20,000 simulations) under the standard rule. Worse by more than 1 SE: STOPPED. Otherwise: "not shown",
stays off, numbers to Pete.

### What would make an apparent win unacceptable (named now)

- **fed2007 again.** With no earlier federal election the arm gives fed2007 the pooled k = 1.323 from two WA
  elections, the exact failure that refused the pooled arm (bucket error 2.02 -> 4.85). AEF-7 cannot see it; the
  deciding run can. If fed2007 is worse by more than 2 SE of its own seats there, the arm is refused regardless of
  the pooled number: the branch's prior inherits the small-n weight the 28 Sep result said a v2 must replace.
- The gain coming from elections whose bucket was already right (fed2022, fed2025, wa2025: shipped |error| under
  0.2 points, the arm moves them by 1.2 to 1.5). If those three score BETTER on seat log loss while their bucket
  error gets five to twenty times worse, the improvement is not coming from the mechanism; reported to Pete, not
  shipped on.
- Any `OB3` k outside [0.75, 1.35] at an AEF-7 target (the history above has 0.90 to 0.92).
- A live vic2026 walk that moves any seat's favourite: to Pete before shipping.

### What the criterion cannot see

- Which classes the removed share should go to: `others_bucket_apply()` gives it to the polled classes in proportion,
  then the anchoring rebalances Labor and Coalition. The 25 Oct level finding (Victorian Greens over-called 4 of 4)
  says proportional is not neutral.
- Seats whose winner is under the 0.5/N floor at 1,000 simulations.
- Whether a better small-n weight would make the jurisdiction term work; that is a different arm and needs its own
  registration.

## Dry run on known cases (prose, before any screen)

- **Switch off**: byte-identical, Q3 change 0.
- **No earlier election of the jurisdiction** (e.g. vic2014 on the old history): `OB3` must print `n 0`, `w 0.00` and
  the pooled k; the branch's test covers the function, the log line covers the wiring.
- **vic2022 on the old history**: k 0.915, bucket 19.74 -> about 18.06 against 17.09 counted. The `OB3 vic2022` line
  must show the bucket falling by about 1.7 points; if it shows k = 1, the switch did not reach the harness and the
  screen is void ("an experiment that never ran").
- **After the history rebuild**, rerun the Python sizing on the new file before the screen and add the new AEF-7
  table below as an amendment; if tau2 is no longer 0 at some AEF-7 target, say which, before any result is read.

## Leakage

`before` is the target's polling day; every term (jurisdiction mean, within variance, between variance, pooled prior)
uses only elections dated strictly before it. The history must come from an audit with both switches OFF, or the
correction is fitted to its own output. `build_others_bucket_history.R` stops when the audit ran with
`AUSPOL_OTHERS_SCALE` on, but it reads only that column: an audit run with `AUSPOL_OTHERS_SCALE_JUR=1` would NOT be
caught (read from the script, 26 Oct). Run the audit with `AUSPOL_OTHERS_SCALE_JUR=0` set explicitly.

## Amendments

(none yet; any change is added below this line with the text above left as is)
