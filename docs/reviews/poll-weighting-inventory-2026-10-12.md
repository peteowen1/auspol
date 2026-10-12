# Statewide poll weighting: inventory and a unified design (2026-10-12)

Pete, 2026-10-12, on the level blend: *"how do we balance fed polls with state polls say for VIC26 ... a fed
poll got announced yesterday does that affect the VIC election (it probably should at least slightly but obvs not
as much as a vic26 poll) ... theres a reason i dont like hard caps"*, and on the uncommitted poll-sample work: *"i
think we can still do a LOT better on poll weighting stuff and this ties in with our other work"*.

Source: one Sonnet read-only pass, plus my own check of the blend weights (marked **checked**). Everything else
is the agent's reading of the code. I have not re-verified it.

## What weights a statewide poll today

| Mechanism | Where | What it weights by | Hard cut-off? |
|---|---|---|---|
| Published trend, `trend_as_at()` | `R/projection.R:64`, core `R/trend.R` | Every poll the same: fixed 1.7-point noise (`R/trend.R:275-280`). Age only through the random walk, 0.10 per day. House effects per pollster, soft sum-to-zero. | `min_polls = 8` returns NULL. Firms with fewer than 3 polls are pooled as "(other firms)". |
| Trend options built but off | `R/projection.R:67,147-175` | Per-firm factors, pollster record (`firm_record_factors()`, `R/poll_record.R:73`), per-cycle or time-forward noise | None. All refused 2026-10-09. |
| Recent-poll level blend | `R/level_recent.R:181`, called from `R/forecast_statewide.R:353` and `fit_seats_full.R:627` | `w = n/(n+k)`. Decay mode (shipped) weights each poll `2^(-age/20 days)`. | Window mode: the 28 days before. Both modes: polls since the previous election only. ALP, LNP and GRN only. |
| Fitting the blend constant k | `R/level_recent.R:161` (window), `:96` (decay) | Time-forward grid search | The grids have floors: 0.25 (window) and 0.01 (decay). |

**Federal polls never reach a state forecast (checked: no state-path call to `load_polls("fed")`).**
`R/state_deviation.R` uses the state breakdowns of federal polls for federal seats only.

## The blend is not blending (checked)

k sits at its grid floor for every target, in both modes, so the blend weight is 0.89 to 1.00. The day-before
level is the recent-poll average, and the trend contributes almost nothing. The reason is monotone:

- Over 66 party-election cells, the trend alone misses the result by 2.60 points (RMSE).
- The 28-day poll mean misses by 2.11.

Blend weight by election. w is the share given to recent polls; 1.00 means the trend is ignored:

| election | polls in cycle | polls in last 28 days | w, window | w, 20-day decay |
|---|---|---|---|---|
| fed2022 | 303 | 17 | 0.99 | 1.00 |
| fed2025 | 448 | 27 | 0.99 | 1.00 |
| nsw2023 | 32 | 6 | 0.96 | 1.00 |
| qld2024 | 30 | 5 | 0.95 | 1.00 |
| sa2026 | 15 | 5 | 0.95 | 1.00 |
| vic2022 | 36 | 7 | 0.97 | 1.00 |
| wa2025 | 15 | 2 | 0.89 | 1.00 |

vic2026 live: 59 polls since 2022, 2 in the last 28 days (latest 26 Sep).

**What this means:** the trend is the weak part. A trend whose noise and drift are fitted would follow late
movement by itself, and the separate blend could go. The window-against-decay question is second order.

## Worktree `agent-ab43fc411bcb0c254` (uncommitted poll-sample fetch): KEEP

`scripts/fetch_statewide_poll_samples.R`:

- adds WA 2001 and 2005
- parses quarterly aggregates as ranges, not polls
- reads the pollster from the heading when a table has no firm column
- handles old layouts with a blank date header
- writes `fetch_log.csv` with each Wikipedia revision id and timestamp. This matters: the fetched pages are the
  current revision, not the one standing before the election.

`check_poll_coverage.R` reports coverage both ways.

Not re-run. Several old elections still show 0% with a sample size, so it will not lift coverage past the
refused prereg's 50% gate on its own. Run `scripts/check_poll_coverage.R`, review, then commit.

## Proposed: one weight per poll, no cut-offs

Each poll is one observation in the trend. Its variance is:

```
(non-sampling noise x pollster factor)^2 + p(1-p)/n, divided by relevance
```

- **Age:** the random walk only. Fit its drift time-forward so the trend can follow late movement, and retire
  the separate blend (keep it as a control arm).
- **Precision:** sample size where known. Where missing (about 84% of polls), impute the pollster-and-mode median,
  shrunk toward the overall median.
- **Pollster record:** `firm_record_factors()` already shrinks toward pooled with `POLL_RECORD_K`.
- **Relevance:**
  - a state poll counts 1;
  - a federal poll's state breakdown counts r, between 0 and 1, fitted time-forward;
  - a national-only federal poll counts less still, applied to the national number less the state's lagged
    deviation from it.
  - r gets a strong prior (0.1 to 0.2), because few cycles exist to fit it.

## Data for it

| source | rows | what it has |
|---|---|---|
| `external/reference/polls/state-federal/state-federal-polls.csv` | 1,095 (211 state-scope, 884 seat-scope) | Victoria: 48 state rows (fed2022 21 with no sample size; fed2025 27, 25 with one). Little before 2022. |
| `external/reference/polls/newspoll-quarterly/breakdowns.csv` | 169 (98 by state) | Newspoll quarterly state primaries with sample size, Nov 2019 to Sep 2026 |
| `demosau/crosstabs.csv` | 991 | Has a jurisdiction column. Not inspected. |
| `load_polls("fed")` | 4,007 | National numbers only |

## What would decide it

1. **Trend responsiveness (data exists).** Fit the drift and noise time-forward. If the trend alone reaches the
   28-day mean's 2.11 RMSE on the 66 cells, the blend goes. Earlier prereg warning: with 195 pairs, gains under
   0.02 MAE cannot be resolved.
2. **Imputed sample size (data exists for recent cycles).** Does the precision term improve the held-out poll
   likelihood, clustered on cycle?
3. **Federal relevance r (low power).** Fit pooled across states. Test on the state elections that follow a
   federal cycle: nsw2023, qld2024, sa2026, wa2025, vic2022.
