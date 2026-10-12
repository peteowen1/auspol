# Pre-registration: a trend responsive enough to replace the recent-poll blend

Written 2026-10-12, before any arm is run. Pete chose this ("Go", 2026-10-12) over keeping the blend, after the
size check stopped `prereg-poll-level-centring-2026-10-12.md`: the shipped blend puts weight 1.00 on recent polls,
so the trend barely reaches the forecast, and re-centring it cannot move the shipped level.

## The question

Can the poll trend alone (blend off, `AUSPOL_LEVEL_RECENT=0`) give a day-before level as good as the shipped
blend (trend + 20-day decay)? If yes, the blend goes. The payoff is one poll model with no cut-offs, where sample
size, pollster record and federal polls' state breakdowns can later enter as weights. The blend can't take those,
because it only averages recent polls since the last election.

Why the trend lags now (`docs/reviews/poll-weighting-inventory-2026-10-12.md`):
- Too smooth. A fixed 1.7-point poll noise against a 0.10-point daily walk means the trend averages many weeks.
- Centred on the busiest pollster. The house effects sum to zero weighted by poll count.

## Arms (blend OFF in every arm), each scored against the shipped incumbent

| arm | change | built? |
|---|---|---|
| T0 | today's trend, blend off. Control: says what the arms fix | yes |
| T1 | `sigmas = "pooled_tf"`: noise and daily walk by marginal likelihood over the region's earlier cycles | yes (2026-10-09) |
| T2 | walk multiplier m in {1, 2, 4, 8, 16} on the default walk, noise at default. For each target, m picked by day-before level RMSE over elections whose polling day is before the target cycle began (all regions pooled). Fewer than 3 such elections: m = 1 | screen code only |
| T3 | the better of T1/T2 by the screen, plus firm-equal centring (each firm counts once in the sum-to-zero) | needs code |

T2 picks m on the very thing it is scored on, but only from earlier elections. That is time-forward tuning, not
leakage. Asserted in code: every election used to pick m has a polling day before the target's cycle start.

## Criterion and rule, fixed now

**Screen (primary): day-before level RMSE against the actual share**, ALP, LNP and GRN, all scored elections
(22, wa2021 has no trend; 66 cells). Paired against the incumbent (shipped blend level from
`output/level-recent.csv` via `level_recent_apply`, decay 20). SE by delete-one-election jackknife, 22 clusters.

Measured noise (size check, same cells): SE 0.15 against the old trend, 0.42 against the shipped blend. So:

1. **Fixes the lag:** the arm beats T0 by more than 1 SE. Without this, the arm did nothing and stops.
2. **Replaces the blend (non-inferiority):** the arm is no worse than the shipped level by more than 1 SE.

The second is deliberately a non-inferiority test, because the SE (0.42) is larger than any plausible
difference between two levels that both follow the late polls. Ties go to the trend arm: that is Pete's choice of
this option (one model, no cut-offs), recorded here before results. If the arm's point estimate is worse than the
shipped level by more than 0.20 (half the SE), this goes back to Pete as a clause refusal even if it passes.

**Ship (deciding):** the best passing arm runs all 22 at 20,000 sims (`scripts/deciding_run.ps1`) against
shipped, from stage 1 (the trend reaches base_pred and the state deviation features). Ships if pooled seat log loss
(probability given the winner; lower is better) is no worse than +1 SE, clustered on election.

## Guards (any failure refuses)

- Horizons: the arm must not be worse than T0 at 7, 28 and 90 days before by more than 1 SE. A trend that wins the
  last day by chasing noise all campaign fails here.
- No single election supplies more than half the gain against T0.
- `B2`/`B3` band coverage in `scripts/fit_projection.R` still passes (a more responsive walk widens bands).
- ON and the other classes: print the max change in their day-before level. Report only, not a gate.

## Dry runs (known answers, checked when the screen first runs)

- **vic2022 LNP:** T0 32.2, late polls 34.1, result 34.4. A responsive arm must move it above 33. If it doesn't,
  the arm is not doing what it claims.
- **sa2026 ALP:** T0 39.5, late polls 37.6, result 37.6. A responsive arm must move it down.
- **fed2019 LNP:** polls 38.3, result 42.0. No arm may get within 2 points: a big gain here means leakage.

## Expectation, stated now

T1 small (its fitted noise also rose, so the noise-to-walk ratio moved little). T2 picks m = 4 to 8 and closes
most of the gap to the raw poll mean. T3 adds a little.

## What would make a win unacceptable

- An m at the top of the grid (16) for most targets. That means "no smoothing at all", which is the raw average
  by another name, and the grid gets extended and re-registered, not shipped.
- A gain that comes from GRN alone.

## Amendments

(any change is added below this line with the original text left as is)
