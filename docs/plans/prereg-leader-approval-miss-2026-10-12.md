# Pre-registration: does the government leader's approval trend predict the final polling miss?

Written 2026-10-12, before anything is fitted. Pete asked for leader ratings in the forecast (*"we probably
should I know it helps in uk and us elections"*) and chose this framing ("go", option 1).

## The question

On polling day, is the government party's result further above its final polls when its leader's approval has
been rising, and below them when it has been falling, beyond what the voting-intention polls already show?

Three examples walked with Pete before writing this (AE approve minus disapprove, 6-3 months out -> final 90
days; government primary, last-28-day polls -> result):
- vic2022 Andrews +13 -> +3 (falling); 37.6 -> 37.0 (under)
- qld2024 Miles -13 -> -4 (rising); 31.9 -> 32.6 (over)
- sa2026 Malinauskas +34 steady; 37.6 -> 37.6 (exact)
One to six polls per window. A story, not evidence.

## Definitions

- **Target** `y_e` = government class's actual statewide share minus the SHIPPED day-before level (trend +
  20-day decay blend + federal breakdowns at 0.15, via `level_recent_apply`). Government class = ALP or LNP,
  from `GOVT` in `scripts/build_leader_ratings.R`.
- **Predictor** `x_e` = mean (approve - disapprove) of the government leader in the 90 days before polling day,
  minus the same mean 180 to 90 days before. AE's series (`output/leader-ratings.csv`, `source == "ae"`), polls
  dated before polling day only. Either window empty: `x_e = 0` (no information), counted and printed.
- **Correction** `beta_e * x_e` added to the government class; every other class absorbs it pro rata (as
  `level_recent_apply` does).
- **beta_e**, time-forward and shrunk: ridge on the elections whose polling day is before the target's,
  `beta = sum(x y) / (sum(x^2) + lambda)`, `lambda = s2 / tau^2`, s2 = mean of y^2 over those elections,
  **tau = 0.05** (prior: a 20-point approval swing moves the vote about 1 point, and an effect that size is about
  one prior sd). Fewer than 3 earlier elections: beta = 0.

## Arms

| arm | predictor |
|---|---|
| A1 (primary) | change in approval, as above |
| A2 | level of approval: mean (approve - disapprove) over the final 90 days |

Judged separately. A2 exists because the obvious alternative reading is "a popular leader beats the polls";
sa2026 (+34, exact) is the dry run against it.

## Criterion and rule, fixed now

- **Scope:** all 22 scored elections, one government-class cell each (primary), and all 66 ALP/LNP/GRN cells (guard).
- **Primary:** day-before government-class RMSE against the result, arm vs shipped, SE by delete-one-election
  jackknife (22 clusters).
- **Size check first:** print the SE. If it is above 0.10, say so before reading the result (the expected effect
  is about 0.1-0.3 points on a few elections).
- **Pass the screen:** the arm improves the government-class RMSE (point estimate below shipped) AND the
  66-cell RMSE is no worse than +1 SE. Shrinkage bounds the harm, so a small real gain is worth including;
  but a gain smaller than 1 SE is reported to Pete as "suggestive", with the per-election list, before any
  deciding run.
- **Ship:** deciding run all 22 at 20k, seat log loss no worse than +1 SE.

## Dry runs (must hold, or the code is wrong)

- vic2022: x negative (about -10), correction moves ALP down from shipped (actual 37.0 below polls).
- qld2024: x positive (about +9), correction moves ALP up.
- sa2026: |x| small; correction under 0.2 points.
- Any election with fewer than 3 earlier elections: no correction at all.

## Leakage

- Approval polls dated before polling day only (asserted).
- beta from elections whose polling day is strictly before the target's (asserted). Results of those elections
  are known by then.
- vic2026 and nsw2027 are never scored; their correction is printed for information only.

## What would make a win unacceptable

- A gain carried by one election (more than half the improvement): clause refusal, to Pete.
- beta changing sign across the time-forward fits after 10 elections: the effect is not stable.
- A2 winning while A1 does not: report, do not ship A2 without Pete (it is the reading the dry run argues against).

## Amendments

(any change is added below this line with the original text left as is)

### Amendment 1 (2026-10-12, AFTER the first screen): pooled predictor

The first screen used AE's approval series alone, which for most state elections is 1-2 polls per window (SA
2026 had none in the earlier window, so its x1 was forced to 0). A negative is only reportable from the strongest
version, so `--pool` adds the Wikipedia tables' government-leader net satisfaction (614 readings, 2011 on), one
reading per poll. Same rule, same prior. Post hoc and labelled as such.

## RESULT 2026-10-12: both arms REFUSED, in both versions

`scripts/screen_leader_approval.R` (`--pool` for the amendment). 22 elections. Day-before RMSE change against
shipped (government-class 2.269 over 22 cells; ALP/LNP/GRN 2.319 over 66); lower is better; SE jackknife over
elections:

| arm | government class | all 66 cells | verdict |
|---|---|---|---|
| A1 change, AE only | +0.010 (SE 0.009) | +0.005 (SE 0.004) | refused: worse |
| A2 level, AE only | +0.024 (SE 0.045) | +0.011 (SE 0.017) | refused: worse |
| A1 change, pooled | +0.008 (SE 0.009) | +0.004 (SE 0.004) | refused: worse |
| A2 level, pooled | +0.024 (SE 0.047) | +0.011 (SE 0.018) | refused: worse |

- The size-check SE (0.009 for A1) is small because the shrunk correction is small; the point estimate, not the
  noise, refuses.
- **The federal cases contradict the idea.** fed2013: Rudd's return lifted approval 16.6 points over the
  final months and Labor still fell 1.6 below its final polls. fed2016: Turnbull's approval fell 19.5 points and
  the Coalition still beat its polls by 0.4.
- The time-forward beta changed sign after the 10th election (-0.003 to +0.013): the instability clause fires as well.
- Dry runs: vic2022 x1 -11.5 (falling, as expected) but the fitted beta at the time was near 0, so the
  correction was -0.03 (direction right only in the pooled version); qld2024 +0.05 (right direction);
  sa2026 +0.04 (under 0.2). The A2 level arm moves sa2026 by +0.75 the wrong way (popular premier, Labor
  under its polls), which is the reading the dry run argued against.
- Live, for information: vic2026 x1 +23 (Carroll's rise), which A1 would have turned into +0.3 for Labor.

The leader-rating table stays (`output/leader-ratings.csv`) for the site and for the open question this test did
not cover: drift from months out to polling day (option 2), which needs horizon scoring first.
