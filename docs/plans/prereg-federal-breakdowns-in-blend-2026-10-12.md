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

### Amendment 1 (2026-10-12, after the screen, before the deciding run): the "byte-identical" dry run was wrong

qld2020 and sa2022 are not untouched: they have 5 and 7 federal breakdown rows in their cycles, at decayed weight
0.06 and under 0.01 (the coverage table rounded them to look like zero). F1 moves them by at most 0.021 points.
Every federal election, and every WA election before 2025, is unchanged (max change exactly 0 outside these
seven). Not a bug; the dry-run sentence above was imprecise. The criterion is unchanged.

## RESULT, screen (2026-10-12): F1 and F2 pass non-inferiority; every r is slightly worse on its point estimate

`scripts/screen_fed_breakdowns.R` (7 s). Day-before level RMSE, 15 targeted cells, lower is better:

| arm | RMSE | vs shipped (SE, 5 clusters) |
|---|---|---|
| shipped (no federal polls) | 1.188 | - |
| F1 (r = 0.15) | 1.224 | +0.036 (0.048), PASS |
| F2 (r fitted, shrunk; picked 0.15, 0.11, 0.09, 0.08, 0.21) | 1.245 | +0.058 (0.059), PASS |
| r 0.05 / 0.1 / 0.25 / 0.5 / 1 | 1.198 / 1.210 / 1.254 / 1.338 / 1.504 | rises steadily with r |
| F1 with a 180-day gap | 1.252 | +0.064 (0.071) |

- vic2022 dry run: max change 0.05 (bar 0.6). Live vic2026 under F1: ALP 24.6 to 24.5, LNP 28.9 to 28.8, GRN 13.6
  to 13.7, so the gap correction works (bar: within 1 point).
- **Live nsw2027 moves more than 1 point** (ALP 30.3 to 29.1, LNP 24.2 to 23.2, GRN 11.8 to 12.6), because NSW has
  few recent state polls (own weight 0.47 against 0.31 federal). The unacceptable-win clause names vic2026 only;
  this is reported to Pete under its spirit.
- The data lean toward r = 0, within noise. Shipping F1 rests on Pete's preference that a federal poll should
  count a little; the deciding run checks it does no harm to seats.

### Amendment 2 (2026-10-12, AFTER seeing the screen above): three data fixes from the review gate

A Sonnet review of 1d6afc5 found three problems in the federal rows. Fixed in `R/level_recent.R`:
1. 62 rows were each federal election's actual result (`row_type == "result"`), entering as polls. Dropped.
2. 18 rows were exact duplicates of another row. Counted once.
3. Newspoll's state figures are multi-month aggregates (up to 129 days of fieldwork) dated at their END. Now dated
   at the fieldwork midpoint, and a poll is admitted only once its fieldwork has ENDED before the as-at date
   (asserted), so the midpoint cannot admit a poll still in the field.

439 polls remain (was 515 rows). These are corrections, not choices, but they were made after the first screen,
so both results stay visible. The decision rule is unchanged.

| arm | first screen (uncleaned) | rerun (cleaned) |
|---|---|---|
| F1 vs shipped | +0.036 (SE 0.048) PASS | +0.034 (SE 0.036) PASS, at 0.94 SE |
| F2 vs shipped | +0.058 (SE 0.059) PASS | +0.029 (SE 0.028) FAIL, at 1.04 SE |
| every r in the grid | worse, rising with r | worse by about 1 SE at every r (0.05: +0.010, SE 0.012; 1: +0.303, SE 0.248) |

Live, F1: vic2026 ALP 24.6 to 24.5, LNP 28.9 to 28.8, GRN 13.6 to 13.7; nsw2027 ALP 30.3 to 29.3, LNP 24.2 to
23.4, GRN 11.8 to 12.5. F1 passes, so per the rule it goes to the deciding run. With every r about 1 SE worse and
F1 passing at 0.94 SE, this is reported to Pete as a knife-edge pass, whatever the seat result.

## RESULT, deciding run (2026-10-12): F1 meets the ship rule; ship is Pete's call

`deciding-runs/20261012-1524-fedr15/` (DONE, code 692dd47, all 22 at 20,000 sims, 29 min). 15 of 22 elections
byte-identical; 7 changed (the five targets plus qld2020 and sa2022).

- Pooled seat log loss (lower is better), 2,120 seats: 0.3095 -> 0.3095, +0.0001 (SE 0.0001). Rule: no worse
  than +1 SE. **PASS.**
- AEF-7 ledger, 681 seats: 0.2736 -> 0.2739, +0.0003 (SE 0.0004).
- Per election, seat log loss change: wa2025 +0.0045, sa2026 +0.0009, vic2022 +0.0002, nsw2023 -0.0004,
  qld2024 -0.0005, qld2020 -0.0012, sa2022 0.
- Share squared error on the 493 changed cells: +1.3 (SE 43.6), flat.

Read: seat-neutral, as expected from level moves of 0.3 points or less. The level screen leaned against (every r
about 1 SE worse); the seat run is flat. Shipping rests on Pete's preference, and on the live nsw2027 move of about
1 point (the unacceptable-win clause's spirit), so it goes to Pete.

## SHIPPED 2026-10-12 at r = 0.15 (Pete chose "Ship at r = 0.15")

Asked with both the level lean (every r about 1 SE worse) and the live nsw2027 move (about 1 point) in the
question. The blend now reads `output/fed-state-breakdowns.csv` (built from the Wikipedia table by
`scripts/build_fed_state_breakdowns.R`, rebuild stage 5b, published, downloaded by the daily forecast); the
screen reproduces its numbers exactly from that file.
