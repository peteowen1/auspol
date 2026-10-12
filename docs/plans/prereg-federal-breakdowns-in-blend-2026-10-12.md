# Pre-registration: federal polls' state breakdowns in the recent-poll blend

Written 2026-10-12, before anything is fitted. Pete chose this ("Go", option 1). His words: *"a fed poll got
announced yesterday does that affect the VIC election (it probably should at least slightly but obvs not as much
as a vic26 poll ... theres a reason i dont like hard caps)"*.

## What changes

The shipped day-before level for ALP, LNP and GRN is the trend blended toward a 20-day-decay mean of the
state's own polls since its last election (`R/level_recent.R`). The arm adds federal voting-intention polls'
state breakdowns to that mean:

```
avg = (sum_s w_s y_s  +  r * sum_f w_f (y_f + gap)) / (sum_s w_s + r * sum_f w_f)
```

- `w` = 2^(-age/20 days), the shipped decay, for state polls (s) and federal breakdowns (f) alike.
- `r` = how much a federal breakdown counts against a state poll of the same age.
- `gap` = state minus federal, per class: the decayed mean of state polls minus the decayed mean of federal
  breakdowns, both with a **90-day** half-life and both since the state's last election. Shrunk toward 0 by
  `n/(n+1)`, n = the smaller of the two decayed weights.
  - Why longer than 20 days: with the same 20 days, `y_f + gap` averages to exactly the state mean and the
    federal polls add nothing. With 90 days, the gap is the stable federal-state difference and the federal polls
    carry the recent movement.
- `n_eff` (and so the blend weight `w = n/(n+k)`) includes `r * sum_f w_f`. k refits time-forward as shipped.
- Source: `external/reference/polls/statewide-samples/statewide_polls_wiki.csv`, rows `region == "fed"`,
  section `Sub-national polling > <State>`, fieldwork end before the as-at date and after the state's previous
  election. ALP, LNP (or Liberal + National), GRN. 515 rows, five states.
- State targets only. Federal targets are untouched.

## Arms

| arm | r |
|---|---|
| F1 | 0.15, fixed: the prior, nothing fitted |
| F2 | fitted time-forward and shrunk: grid {0, 0.05, 0.1, 0.15, 0.25, 0.5, 1} by day-before level SSE over the earlier of the five elections below, then `(m * r_hat + 3 * 0.15) / (m + 3)`, m = elections used. With none, 0.15 |

## Scope and criterion, fixed now

Elections where the federal breakdowns get any weight (coverage check, 2026-10-12): **vic2022 (federal
weight 0.71 against 5.34 own), nsw2023 (1.21 / 5.06), qld2024 (1.79 / 3.94), wa2025 (1.97 / 2.01), sa2026
(2.13 / 4.52)**. Fifteen cells (three classes).

**Screen (primary, targeted):** day-before level RMSE against the actual share on those 15 cells, paired against
shipped. SE by delete-one-election jackknife (5 clusters, a weak SE; said here so it is not a surprise).
- Passes if the arm is **no worse than shipped by more than 1 SE** (non-inferiority, the same rule Pete chose for
  the trend: a federal poll should count a little, and the test cannot resolve a small r).
- **Do-no-harm:** every other election's level changes by exactly 0 (printed; any non-zero change is a bug).

**Ship (deciding):** all 22 at 20,000 sims (`scripts/deciding_run.ps1`); pooled seat log loss no worse than
+1 SE, clustered on election. Then the live vic2026 level with and without the arm, printed per class.

## Dry runs (known answers)

- **vic2022:** any arm moves each class by 0.6 points or less (federal weight 0.71 against 5.34).
- **Live vic2026 Coalition:** own polls 28.9, federal breakdowns 22.9. With the gap working, F1 leaves the
  Coalition within 1 point of 28.9. A bigger drop means the gap failed: stop and check it.
- **Elections with no federal weight** (qld2020, sa2022, all federal, all WA before 2025): byte-identical.

## What would make a win unacceptable

- A live vic2026 change above 1 point in any class while the backtest is a tie. That goes to Pete before shipping,
  with the rows that drive it.
- F2's r at the top of the grid (1): federal polls counting as much as state polls is not what was asked for.

## Known limits

- The Wikipedia pages are the 2026-10-09 revisions, not the ones standing before each election. A later
  correction to an old poll could leak. Federal poll numbers are rarely revised, so this is accepted and stated.
- The gap half-life (90 days) is chosen, not fitted, because five elections cannot fit it. A 180-day run is
  reported alongside, not decisive.

## Amendments

(any change is added below this line with the original text left as is)
