# Pre-registration: federal polls' state breakdowns in the state poll trend

Written 2026-10-26, before any model code exists and before any arm has run. Pete chose this on 25 Oct: feed
FEDERAL polls' state-level breakdowns into the STATE voting-intention trend as extra, down-weighted polls. His
words when the idea started (2026-10-12): *"a fed poll got announced yesterday does that affect the VIC election
(it probably should at least slightly but obvs not as much as a vic26 poll) ... theres a reason i dont like hard
caps"*.

Data counts: `scripts/count_fed_state_breakdowns.py` (read-only; run 2026-10-26 against the main checkout's
`external/` and `output/`). No R was run for this plan: free memory was 3.2 GB, under the 8 GB bar.

## What already exists, and how this differs

- **SHIPPED 2026-10-12, the blend version** (`plans/prereg-federal-breakdowns-in-blend-2026-10-12.md`,
  `AUSPOL_LEVEL_FED_R = 0.15`). Breakdowns already reach the day-before Labor, Coalition and Greens level, through
  the recent-poll blend (`R/level_recent.R`). The offset there is a decayed-mean gap: state minus federal, 90-day
  half-life. The level screen came out about 1 SE worse at every r, and the deciding run was seat-neutral. It
  shipped on Pete's preference.
- **This arm puts the breakdowns inside `trend_as_at()`**, which is what publishes (CLAUDE.md, "Two trend-model
  paths"). It reaches four things the blend cannot:
  1. **One Nation and the other classes.** The blend touches ALP, LNP and GRN only (`.LR_CLS`). For One Nation,
     the published level is the trend's, rescaled. The breakdowns carry a One Nation figure on 129 of 136 vic2026
     polls (table below). The blend file drops it.
  2. **Every horizon**, plus the chart on the page. The blend acts on the level only, and it is strongest close to
     polling day.
  3. **A modelled offset.** It is estimated inside the fit, per pollster and per federal term. The blend uses a
     smoothed average instead.
  4. **Sample size.** The breakdowns' state subsamples are known for most recent polls: 134 of 136 for vic2026,
     12 of 27 for vic2022.
- **Not a refused arm under a new name.** The refused trend arms all re-weighted or re-smoothed the same state
  polls: responsive walk, time-forward noise, firm-equal centring (`prereg-responsive-trend-2026-10-12.md`),
  pollster record and estimated noise (`prereg-statewide-poll-sample-weights-2026-10-09.md`). None of them added
  a single poll. Route 1 of the 2026-09-28 request ran the other way: state readings fed into the FEDERAL state
  correction (`prereg-state-polls-extra-2026-10-02.md`, refused).

## The data

### Are these federal or state voting intention? Federal.

Every row comes from a federal polling table:
- the "Sub-national polling" sections of the federal Wikipedia opinion-polling pages;
- BludgerTrack's `federal` section;
- `state-federal-polls.csv`, `scope == "state"`, which is hand-verified (`verified = yes`, 211 rows);
- Newspoll's quarterly state breakdowns.

The question asked is how the respondent would vote at a FEDERAL election. **So the breakdowns measure federal
vote intention in the state, and the federal-to-state offset has to be modelled, not assumed to be zero.** The
offset table further down shows why.

DemosAU's crosstabs have no state split for federal polls (`jurisdiction == "federal"` has no `state` dimension).
They are not a source here.

### Counts per state cycle

Federal breakdown polls per state election cycle: fieldwork end after the previous state election, up to polling
day (live cycles: up to 26 Oct 2026). Source columns are rows from each source. UNION is distinct polls across all
of them: same state, same firm, fieldwork end within 3 days. Firms are compared on their first six letters, so the
union is approximate. `lastN` is union polls ending within N days of polling day. ONP is polls with a One Nation
figure; n is polls with a state sample size. Results rows (firm "Election") are dropped.

| cycle | shipped file | Wikipedia | state-federal | Newspoll qtrly | BludgerTrack | UNION | last 365 | last 180 | last 90 | last 28 | ONP | n | first | last |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| qld2020 | 4 | 4 | 0 | 1 | 0 | 5 | 4 | 2 | 1 | 0 | 5 | 4 | 2019-09-01 | 2020-08-08 |
| wa2021 | 3 | 3 | 0 | 0 | 0 | 3 | 3 | 1 | 0 | 0 | 3 | 3 | 2020-05-16 | 2020-11-28 |
| sa2022 | 6 | 6 | 0 | 0 | 0 | 6 | 3 | 0 | 0 | 0 | 6 | 6 | 2020-05-16 | 2021-09-18 |
| vic2022 | 26 | 26 | 7 | 1 | 4 | 27 | 10 | 4 | 3 | 1 | 26 | 12 | 2019-12-08 | 2022-10-30 |
| nsw2023 | 30 | 30 | 7 | 1 | 9 | 31 | 13 | 7 | 3 | 1 | 30 | 17 | 2019-12-08 | 2023-03-16 |
| qld2024 | 53 | 53 | 7 | 0 | 48 | 69 | 30 | 17 | 8 | 2 | 67 | 54 | 2020-11-28 | 2024-10-16 |
| wa2025 | 21 | 21 | 5 | 0 | 34 | 45 | 21 | 9 | 3 | 2 | 42 | 41 | 2021-03-27 | 2025-03-07 |
| sa2026 | 30 | 31 | 12 | 0 | 58 | 60 | 23 | 16 | 11 | 7 | 58 | 60 | 2022-12-03 | 2026-03-19 |
| vic2026 (live) | 92 | 97 | 26 | 1 | 131 | 136 | 54 | 24 | 12 | 3 | 129 | 134 | 2022-12-03 | 2026-10-11 |
| nsw2027 (live) | 86 | 91 | 25 | 0 | 125 | 129 | 54 | 24 | 12 | 3 | 123 | 128 | 2023-04-03 | 2026-10-11 |
| qld2028 (live, not published) | 63 | 68 | 25 | 3 | 86 | 92 | 56 | 25 | 13 | 3 | 88 | 90 | 2024-11-10 | 2026-10-11 |
| tas2021 / tas2024 / tas2025 | 0 / 1 / 2 | 0 / 1 / 2 | 1 / 0 / 0 | 0 | 0 / 1 / 2 | 1 / 1 / 2 | | | | | | | | |

Firms (union):
- vic2022: Resolve 19, Newspoll 8.
- nsw2023: Resolve 22, Newspoll 9.
- qld2024: Resolve 41, YouGov 13, Newspoll 12, RedBridge 3.
- wa2025: YouGov 14, Newspoll 13, Resolve 12, DemosAU 2, RedBridge 4.
- sa2026: YouGov 27, Newspoll 13, Resolve 8, Morgan 5, DemosAU 3, RedBridge 2, Freshwater 2.

The state's own polls in the same cycles (`docs/POLL-REGISTRY.md`, whole cycle): vic2022 33, nsw2023 32, qld2024
34, wa2025 10, sa2026 16; live vic2026 72, nsw2027 33.

Cross-check of the reader: my Wikipedia column matches the shipped file, which comes from the R parser
`fed_state_breakdowns_parse()`, exactly on qld2020, wa2021, sa2022, vic2022, nsw2023, qld2024 and wa2025. sa2026
is 31 against 30. Live cycles run 5 higher, because the R parser drops exact duplicates and my reader does not.

**Sample sizes are the STATE subsample**, not the national one. In Wikipedia's per-poll rows the state n is a
fraction of the national n: NSW 0.32, Victoria 0.25, Queensland 0.20, WA 0.26, SA 0.21. BludgerTrack gives NSW
0.32, Victoria 0.25, Queensland 0.20, WA 0.10, SA 0.08. Newspoll's quarterly aggregates report state n directly:
median NSW 1,820, Victoria 1,731, WA 779, SA 600.

### The offset is large, varies by party and state, and is not zero

Points. fed90 is the mean of federal breakdowns ending in the 90 days before polling day (union). st28 is the mean
of the state's own polls in the last 28 days (`output/level-recent.csv`). act is the state result. Smaller absolute
errors are better.

| cycle | party | breakdowns in last 90 days | fed90 | st28 | act | fed90 - act | st28 - act |
|---|---|---|---|---|---|---|---|
| vic2022 | ALP | 3 | 39.0 | 38.1 | 37.0 | +2.0 | +1.1 |
| vic2022 | LNP | 3 | 30.7 | 33.5 | 34.4 | -3.7 | -0.9 |
| vic2022 | GRN | 3 | 12.0 | 13.2 | 11.5 | +0.5 | +1.7 |
| nsw2023 | ALP | 3 | 40.0 | 36.4 | 37.0 | +3.0 | -0.5 |
| nsw2023 | LNP | 3 | 32.3 | 34.8 | 35.4 | -3.0 | -0.6 |
| nsw2023 | GRN | 3 | 10.3 | 10.7 | 9.7 | +0.6 | +1.0 |
| qld2024 | ALP | 8 | 27.6 | 31.9 | 32.6 | -4.9 | -0.6 |
| qld2024 | LNP | 8 | 41.6 | 41.1 | 41.5 | +0.1 | -0.5 |
| qld2024 | GRN | 8 | 12.4 | 11.6 | 9.9 | +2.5 | +1.7 |
| wa2025 | ALP | 3 | 34.3 | 43.5 | 41.4 | -7.1 | +2.1 |
| wa2025 | LNP | 3 | 36.3 | 34.5 | 33.2 | +3.2 | +1.3 |
| wa2025 | GRN | 3 | 11.3 | 10.5 | 11.1 | +0.3 | -0.6 |
| sa2026 | ALP | 11 | 32.7 | 36.7 | 37.6 | -4.9 | -1.0 |
| sa2026 | LNP | 11 | 16.9 | 17.4 | 19.5 | -2.6 | -2.1 |
| sa2026 | GRN | 11 | 13.9 | 11.2 | 10.0 | +3.9 | +1.2 |

Over these 15 cells the federal breakdowns miss the state result by **3.40 points RMS**. The state's own late
polls miss by **1.25**.
- The sign follows state politics: federal Labor runs 5 to 7 points below state Labor where a popular Labor
  premier governs (Queensland 2024, WA 2025, SA 2026), and above it in Victoria and NSW.
- The offset can also move within a cycle. Every reachable cycle spans a federal election: vic2022, nsw2023,
  qld2024 and wa2025 span May 2022; sa2026 spans May 2025.

So a breakdown carries information about MOVEMENT in the state, not about its level. The design below follows
from that.

### Which state elections the arm can and cannot reach

- **Reaches, with real weight (the five targets):** vic2022, nsw2023, qld2024, wa2025, sa2026.
- **Reaches, barely:** qld2020 (5 breakdowns, 1 in the last 90 days) and sa2022 (6, none after September 2021).
  Scored as targets, because the arm moves them a little, the same seven the blend changed.
- **Live:** vic2026 and nsw2027 (published), plus qld2028.
- **Cannot reach:**
  - Every state election before 2020: vic2010-2018, nsw2011-2019, qld2012-2017, sa2010-2018, wa2001-2017. No
    breakdown on disk ends before 2019-09-01. Newspoll quarterly rows from 2018 carry only a publication date.
  - wa2021: 3 breakdowns, but the cycle has no trend at all (8 polls, 6 of them two-party only). It takes the
    thin-cycle path, which never calls `trend_as_at()`.
  - Tasmania, the NT and the ACT: 0 to 2 breakdowns per cycle, and no candidate harness.
  - Every federal election: the arm is for state targets only.

So 7 of the 22 scored elections can move: 5 with real weight, 2 with a trace. **The test has 7 independent units,
which is the honest size of the evidence, and five of them carry it.**

## How a breakdown enters `trend_as_at()`

The new switches are listed here and added in the implementing commit, at their OFF values, to
`scripts/published_flags.R`, with any constant in `docs/CONSTANTS.md`:
- `AUSPOL_TREND_FED_R`, default `"0"` = off;
- `AUSPOL_TREND_FED_SRC`, `"shipped"` or `"full"`;
- `AUSPOL_TREND_FED_N`, `"0"` or `"1"`.

At `AUSPOL_TREND_FED_R = 0` the code path is today's, unchanged.

1. **Admission.** State targets only. A breakdown is admitted when it is for this state, its fieldwork started
   after the previous state election, and its fieldwork **ended before** the as-at date. The end date is used
   because a midpoint would admit a multi-month aggregate that is still in the field. This is asserted, and a
   test feeds a deliberately late breakdown that must trip the assertion.
2. **Classes.** A breakdown's figure for a class enters only when this cycle's trend already fits that class
   from the STATE polls alone, at `min_polls` state polls reporting it, as today. So breakdowns cannot create a
   class (One Nation in a state where it does not stand), cannot rescue a thin class, and do not count toward
   `min_polls`. A cycle that returns NULL today still returns NULL.
   - The Coalition: breakdowns report the combined Coalition figure. It enters only where the state trend fits
     a combined LNP. Where state polls are fitted as separate Liberal and National classes, the breakdown's
     Coalition figure is left out, and that is printed.
   - Classes used: ALP, LNP, GRN, ONP.
3. **The offset (the federal-to-state difference).** Each federal pollster gets its own effect, one per federal
   term, as a firm named `fed:<firm>:<term>`. A federal polling day inside the state cycle starts a new term.
   - This is the trend's existing house-effect machinery. The effect absorbs both the federal-to-state offset
     and that firm's own house effect.
   - Firms with fewer than 3 breakdowns in a term pool into `fed:(other firms):<term>`, as state firms do now.
   - **These effects get zero weight in the house-effect sum-to-zero.** The centre stays defined by the state
     polls alone, exactly as today.
   - Prior: normal, centred at 0, with sd **10 points** translated at the party's reference share. That is the
     width of the existing weak day-0 anchor. It is effectively uninformative, so the LEVEL comes from state
     polls and a breakdown contributes only the shape of movement within its term.
   - The offset is estimated inside each fit, from data before the as-at date only, so it is time-forward by
     construction. Every fitted offset is printed per (firm, term, party) with its posterior sd.
4. **Weight r.** The breakdown's observation precision is r times a state poll's: variance `sigma_obs^2 / r`.
   This is the same meaning of r as the blend.
5. **Sample size** (arms B2 and B3, `AUSPOL_TREND_FED_N = 1`). The variance becomes
   `sigma_obs^2 * (lambda + (1 - lambda) * n_ref / n_i) / r`.
   - `n_ref = 1,516` is the median observed state-poll sample (`reviews/statewide-poll-samples-2026-10-09.md`).
   - `lambda = 0.48` is the non-sampling share of the 1.7-point state-poll noise at a 35% party: 1 minus the
     sampling variance at `n_ref`, 1.50 points squared, over 2.89.
   - So a breakdown with n = 400 has sd 1.57 times a state poll's, before r, and an 1,800-sample Newspoll
     quarterly has 0.96. The multiplier is always positive, with no floor and no cut-off.
   - Missing `n_i` is imputed, in order:
     1. that firm's median state n in this state, over breakdowns that ended before the as-at date;
     2. that firm's national n times the state's median subsample ratio, both from before the as-at date;
     3. the state's median over all firms;
     4. `n_ref`, which gives a factor of 1.

     The share imputed is printed per cycle.
   - Both constants are computed over all years. They measure poll SIZE, not outcomes, so the leak is accepted and
     stated, as the blend accepted its revision caveat.
6. **Dating.** In every arm, a breakdown observes the mean of the latent share over its fieldwork days: its row
   in the observation matrix is spread `1/L` over the `L` days. This matters for Newspoll's quarterly aggregates
   (up to 129 days) and Morgan's period aggregates (up to 343 days). A 2-day poll comes out the same as using its
   midpoint, so no cut-off is needed. State polls keep their single day, so the incumbent's fit is unchanged.
7. **Source.**
   - B1 reads `output/fed-state-breakdowns.csv`: what the blend reads, Wikipedia only, ALP, LNP and GRN, no n.
   - B2 and B3 read a new `output/fed-state-breakdowns-full.csv`, built by extending
     `scripts/build_fed_state_breakdowns.R`. It is the union of the four sources above, with ONP and state n,
     every source column carried through.
   - Dedupe: same state, same firm, fieldwork end within 3 days counts as one poll. Values come from Wikipedia,
     then BludgerTrack, then state-federal. Missing fields are filled from the next source, and disagreements
     over 1 point are printed.
   - The blend keeps reading the shipped file in every arm, so the blend's own federal input does not change.
8. **Downstream rebuilds inside each arm.** The trend feeds two fitted tables, and both are rebuilt under the arm
   in the arm's scratch output, never read from the baseline's:
   - `output/level-recent.csv`: its `trend` column is what the blend's k is fitted on;
   - `output/projection-data.csv`: the fundamentals-and-trend mix.

   Reusing the baseline's copies would score the arm's trend with a k and a mix fitted to a different trend
   (memory: artifacts outside the pipeline go stale).
9. **Reach.**
   - One switch in `R/forecast_mode.R` (`statewide_draws_as_at()`) reaches all six harnesses and
     `scripts/fit_seats_full.R`, through `forecast_statewide_or_oracle()`.
   - `scripts/build_trend_page_data.R` and `scripts/build_page.R` call `trend_as_at()` directly. They must pass
     the same arguments, or the chart and the headline stop agreeing.
   - `_fed.R` and every federal pair are byte-identical by construction, because the arm is for state targets
     only. That is asserted, not assumed.

## Arms

| arm | source | sample size | r | what it tests |
|---|---|---|---|---|
| B0 | none | - | - | incumbent: shipped trend, shipped blend at r = 0.15 |
| B1 | shipped file (ALP/LNP/GRN) | no | 0.15 fixed, the prior | the blend's data, moved into the trend |
| B2 | full union (+ONP, +n) | yes | 0.15 fixed | all the data, and Pete's "as much info as we can" |
| B3 | as B2 | yes | fitted time-forward, shrunk | whether the data want a different r |

B3: grid r in {0, 0.05, 0.1, 0.15, 0.25, 0.5, 1}. For each target, r is picked by the primary metric's squared
error over the target elections whose polling day is before this target's as-at date, which is asserted. It is
then shrunk: `(m * r_hat + 3 * 0.15) / (m + 3)`, where m is the number of elections used. With none, r = 0.15.

Reported, never shippable:
- **B-eq**, the negative control: the offset prior centred at 0 with sd 0.5 points, and r = 1. That is "federal
  equals state". From the offset table it must lose. If it does not, the screen is not seeing the breakdowns.
- **B2-noblend**: B2 with `AUSPOL_LEVEL_FED_R = 0`, to show where the information goes when the blend's copy is
  removed.
- **B2-wide20**: B2 with the offset prior sd at 20 points. A gain that changes sign here came from level
  information leaking through the prior.

## Expectation, stated now

**A tie at polling day.**
- For ALP, LNP and GRN the published level is the blend: weight 0.89 to 1.00 on recent polls, which already
  include the breakdowns. The arm reaches it only through the trend's remaining 0 to 0.11 share. Even a 0.5-point
  trend move is at most 0.05 points published.
- One Nation is where it can show, because there the published level is the trend's.
- The arm's unblended trend should move 0.1 to 0.5 points per cell, and more at 90 to 180 days out, where state
  polls are sparse.

## Size check, before arms are ranked

Run B1 once and print the RMS of its changes in the published day-before level on the targeted cells.
`|RMSE(arm) - RMSE(B0)| <= RMS(arm - B0)`, so that number bounds any possible gain.

Then compute the primary's paired SE (below). **If the bound is under 1.84 SE, the primary cannot show a pass at
80% power.** Stop and report to Pete with the horizon table, before the deciding run.

The 1.84 is the effect needed to clear a 1 SE bar 80% of the time. Prior estimate of the SE: the blend's screen
had 0.036 on 15 cells with 5 clusters, at level moves of 0.3 points or less.

## Criterion and rule, fixed now

This is the standard decision rule (`docs/PRE-REGISTRATION-RULES.md`). Departures are named.

**Primary (targeted):** RMSE of the PUBLISHED day-before statewide level against the actual statewide share.
- "Published" means after the fundamentals mix and the shipped blend, with k and the mix refitted under the arm
  (step 8).
- Cells: ALP, LNP, GRN and ONP, wherever the state trend fits that class.
- Elections: the seven targets (qld2020, sa2022, vic2022, nsw2023, qld2024, wa2025, sa2026).
- Actual shares come from `output/candidacies.csv`, the same as `build_level_recent_table.R`, extended to ONP.
- The difference against B0 is paired. The SE is a delete-one-election jackknife over 7 clusters. That is weak,
  and said here so it is not a surprise.

Outcomes:
- **PASS:** better than B0 by more than 1 SE.
- **TIE:** within 1 SE either way. This is **not a ship**. It goes to Pete as a clause decision, with the blend
  precedent stated (that version shipped on a tie at his preference), the live moves and the horizon table.
  Departure from the standard rule: none, since a tie is not a pass there either. This only says where a tie
  goes.
- **FAIL:** worse than B0 by more than 1 SE. Refused.

**Mechanism checks (any failure stops the run as a bug, not a result):**
- On all 15 non-target elections, every level changes by exactly 0.
- On the targeted cells, the UNBLENDED trend changes by more than 0.05 points in at least one cell. A zero change
  means the breakdowns never reached the fit.
- Every admitted breakdown's fieldwork ended before the as-at date (assertion).

**Guards (standard rules 2 to 4):**
- Deciding run: all 22 elections at 20,000 sims, `scripts/deciding_run.ps1`, from stage 1. Pooled seat log loss
  (the log of the probability given to the actual winner; lower is better) not worse than B0 by more than 1 SE,
  clustered on election.
- Leave-one-election-out on the primary: a PASS must stay better by more than 1 SE with each target election
  dropped in turn. Each election's share of the gain is reported, never used to refuse.
- No election materially worse: no election's seat log loss worse by more than 2 SE of its own paired seat
  differences.
- Direction (standard rule 6): report how many targeted cells moved toward the result.

**Reported, not decisive:**
- **Horizons.** The unblended level error at 30, 90 and 180 days before polling day on the same cells, the trend
  refitted on polls and breakdowns that ended by then. Reported per horizon. Alternating signs are noise.
- **Live.** Published vic2026 and nsw2027 levels with and without the arm, per class, with the rows that drive any
  move over 0.5 points.
- The B-eq, B2-noblend and B2-wide20 diagnostics.

## Dry runs (known answers)

1. **The rule on the blend's own screen results** (`prereg-federal-breakdowns-in-blend-2026-10-12.md`, cleaned
   rerun). The level RMSE change is in points; positive is worse.

   | arm | change (SE) | ratio | verdict under this rule | known answer |
   |---|---|---|---|---|
   | F1, r = 0.15 | +0.034 (0.036) | 0.94 SE | TIE, so it goes to Pete | Pete decided it; it shipped on preference. Matches. |
   | r = 1 | +0.303 (0.248) | 1.22 SE worse | FAIL | "federal counts as much as state" was the clearly wrong end. Matches. |
   | r = 0.05 | +0.010 (0.012) | 0.83 SE | TIE | correctly not a pass, for a near-zero r |

   No row there would PASS, which is the right reading of a screen that leaned slightly against at every r.
2. **The offset must hold the level.** wa2025 ALP: federal breakdowns 34.3 over the last 90 days, state polls
   43.5, result 41.4. B1 and B2 must move the unblended ALP trend by less than 1 point. A fall toward 34 means the
   offset failed: stop.
   - The same check on live vic2026 Coalition: own polls 28.9, federal breakdowns 22.9, from the blend's
     2026-10-12 measurement.
3. **The negative control.** The breakdowns miss the result by 3.40 points RMS against the state polls' 1.25, so
   B-eq must FAIL the primary. If it ties, the instrument cannot see this input. Stop and report.
4. **Byte-identity:** vic2014, vic2018, nsw2019, qld2017 and every federal pair must be exactly unchanged.

## Leakage rules

- Breakdowns: only those whose fieldwork ended before the as-at date (asserted, and tested with a deliberately
  late row).
- Offsets: fitted inside each as-at fit, from admitted data only.
- B3's r: only from elections whose polling day is before the target's as-at date (asserted).
- The rebuilt level-recent and mix tables keep their existing earlier-elections-only fits.
- **Known limit:** the Wikipedia and BludgerTrack tables are 2026 revisions, not the ones standing before each
  election. Federal breakdown numbers are rarely revised. This is accepted and stated, as in the blend prereg.
- vic2026, nsw2027 and qld2028 are never scored.

## What would make an apparent win unacceptable

- B3's r at the top of the grid (1) for most targets. That is federal polls counting as much as state polls, which
  is not what was asked for.
- A PASS that changes sign under B2-wide20. Then the gain came through the offset prior, which means through
  assuming equality, not through movement.
- A PASS where every fitted offset is near 0 (all |offset| under 0.5 points) while the offset table shows 3 to 7
  points. That means the offset is not being estimated.
- A live vic2026 or nsw2027 move over 1 point in any class while the backtest is a TIE. That goes to Pete with the
  driving rows.
- A day-before PASS while the 90-day and the 180-day horizons are each worse by more than 1 SE: winning the last
  day by chasing noise. That goes to Pete.

## What the criterion cannot see

- Elections before 2020: no data.
- The live forecast months out, where breakdowns matter most (nsw2027 has 33 state polls against 129 breakdowns).
  The horizon table is the only window on it, and it is not decisive.
- Correlated sampling error. Some firms field state and federal questions in the same survey, so a breakdown and a
  same-firm state poll with overlapping fieldwork share respondents. The breakdown then carries less than its
  weight says. The count of such pairs is printed. r absorbs the rest.

## Not verified here (marked; no R was run)

- Which WA cycles' state trends fit Liberal and National separately. That decides whether the Coalition
  breakdowns can enter WA at all, and needs `load_polls("wa")`.
- Which targeted cycles fit One Nation from state polls (needs R). The ONP cell set is printed at the first run.
- The union's dedupe is approximate (firm prefix match). The implementing builder replaces it with an explicit
  alias table (`external/reference/polls/statewide-samples/firm_alias.csv` exists).
- `state-federal-polls.csv` sample sizes are taken to be state subsamples, like the other sources. Not checked
  row by row.

## Amendments

(any change is added below this line with the original text left as is)
