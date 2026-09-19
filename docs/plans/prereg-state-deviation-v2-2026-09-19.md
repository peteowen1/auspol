# Pre-registration: state-deviation v2 (prior state election as a second predictor, five states)

Written 2026-09-19 evening, arms NOT yet run (machine under 10 GB free). Replaces
the roadmap's "model item (1) independent emergence" as the first model item,
for the reason in the next section.

## Why this and not independent emergence

The roadmap said "independent emergence (fed2022 is the whole AEF loss)". The
ledger (v38, 660 seats) says otherwise. Log loss summed over seats, lower is
better, `gap` = ours minus AE Forecasts (negative = we are ahead):

| slice | seats | ours | AEF | gap |
|---|--:|--:|--:|--:|
| every independent winner, all 7 elections | 36 | 16.7 | 19.7 | **-3.0** |
| fed2022 independent winners | 7 | | | -0.33 |
| **fed2022 Labor winners** | 77 | **17.7** | **8.7** | **+9.0** |
| fed2022 Coalition winners | 58 | 8.3 | 9.7 | -1.4 |
| fed2022 total | 151 | 41.3 | 35.3 | +6.0 |

We are already ahead of AEF on independents overall and level on fed2022's.
The fed2022 loss is **Labor gains we did not see**, and the ledger's ten worst
fed2022 seats by gap are Higgins, Curtin, Hughes, North Sydney, Reid,
Robertson, Tangney, Boothby, Chisholm, Pearce -- eight Labor gains, two teals.
Our Labor primary in those seats (shipped v38, xgb on):

| seat | state | ours | actual | miss |
|---|---|--:|--:|--:|
| Tangney | WA | 27.6 | 38.1 | +10.5 |
| Pearce | WA | 33.9 | 42.8 | +8.9 |
| Hasluck | WA | 30.4 | 39.7 | +9.3 |
| Swan | WA | 34.2 | 39.1 | +4.9 |
| Chisholm | VIC | 30.9 | 40.1 | +9.2 |
| Reid | NSW | 33.5 | 41.6 | +8.1 |
| Higgins | VIC | 21.5 | 28.5 | +7.0 |
| Robertson | NSW | 33.5 | 37.7 | +4.2 |

Two different causes. **WA is a state-level miss**: mean Labor primary error
over WA's 15 seats is +5.52 with the shipped `AUSPOL_STATE_DEV` correction
already on (it moved Tangney about +0.6: fitted slope 0.17 on a polled
deviation of +3.5). Chisholm, Reid, Higgins, Bennelong are a seat-type miss
(2022's swing among Chinese-Australian and high-education electorates), which
is roadmap item (4), not this plan. Teal emergence stays PARKED per Pete
(2026-09-18) and is now also not where the money is.

## What the system already has (asked before designing)

- `scripts/build_state_deviation_features.R` writes, per federal seat:
  `state_poll_dev` (state-level federal polls minus the national swing, from
  the anchor's `region-polls-fed.csv`, 2007-2022, five states only),
  `state_elec_dev` (the preceding STATE election's Labor swing, from our own
  corpus, r = +0.769 on n = 10 within 24 months), `state_elec_gap` (months),
  `state_poll_n`.
- `R/state_deviation.R`: the shipped correction regresses each class's
  residual on `state_poll_dev` ONLY, one row per state-year, leave-target-out,
  and applies `b * dev` to that state's seats. Adopted 2026-09-15 at pooled
  federal log loss 0.2584 -> 0.2539 (-0.0045), fed2019 worse by +0.011,
  fed2025 untouched (no state polls in the anchor for 2025, still true today:
  zero 2025 rows in both anchor files). `state_elec_dev` was explicitly left
  out ("no state_elec_dev added" was a refusal condition of that plan).

## The residual, measured on the shipped model

Mean (actual - predicted) Labor primary by state-year, shipped v38 xgb-on
sharedetail, 56 federal state-years. **sd across state-years 2.79 points.**
Worst twelve:

| pair | state | miss | seats |
|---|---|--:|--:|
| fed2010 | tas | +7.66 | 5 |
| fed2019 | qld | -5.83 | 30 |
| fed2022 | tas | -5.63 | 5 |
| fed2022 | wa | +5.52 | 15 |
| fed2025 | tas | +4.81 | 5 |
| fed2025 | nt | -4.66 | 2 |
| fed2007 | tas | -4.59 | 5 |
| fed2022 | act | +4.42 | 3 |
| fed2013 | tas | -4.10 | 5 |
| fed2019 | act | +3.92 | 3 |
| fed2007 | nsw | +3.80 | 49 |
| fed2025 | wa | -3.63 | 15 |

Seven of the twelve are Tasmania, ACT or NT, which NEITHER predictor can
reach: the anchor has no state polls for them, and our candidate corpus
holds no Tasmanian, ACT or NT elections (`output/state-swing-prior.csv`
has rows for NSW, VIC, QLD, SA, WA only). **Corrected 18:05, before any
run**: the first draft of this plan said Tasmania was coverable through
`state_elec_dev`. It is not. Those seven state-years stay out of reach until
Tasmanian state results are fetched, which is a data item, not this plan.

What IS reachable and untouched today: state-years where the prior state
election is fresh. From `state-swing-prior.csv`, `state_swing` (that state
election's Labor primary swing) against `fed_dev` (the federal state-level
Labor miss the shipped model then made):

| pair | state | state swing | months | federal miss |
|---|---|--:|--:|--:|
| fed2022 | wa | +17.7 | 14 | +7.8 |
| fed2025 | wa | -18.5 | 2 | -3.0 |
| fed2022 | sa | +7.2 | 2 | -0.2 |
| fed2022 | qld | +4.1 | 19 | +1.5 |
| fed2019 | vic | +4.8 | 6 | +2.7 |
| fed2019 | nsw | -0.8 | 2 | -1.0 |
| fed2013 | wa | -2.7 | 6 | +2.2 |
| fed2025 | qld | -7.0 | 6 | +1.6 |
| fed2016 | vic | +1.8 | 19 | -0.6 |
| fed2025 | nsw | +3.7 | 25 | -0.2 |

Ten state-years inside about two years, both WA landslides among them and
pointing the right way, two (fed2013 WA, fed2025 QLD) pointing the wrong
way. The eye says a slope near 0.2 with real scatter; the fit below will say
what it is. **fed2025 gets its first correction of any kind from this**:
the shipped form skips it entirely for want of 2025 state polls, and WA
2025 (-3.0 on 15 seats, state election two months earlier at -18.5) is the
cleanest case in the table.

## The arm

`AUSPOL_STATE_DEV=2`: same leave-target-out, one-row-per-state-year fit, but
on two predictors with shrinkage, over the five states that have either source:

    err_sy = b1 * state_poll_dev_sy + b2 * w(gap_sy) * state_elec_dev_sy

with `w(gap) = exp(-gap / 24)` (the builder's own 24-month noise finding as a
decay, not a cliff), ridge penalty chosen leave-one-election-out on the
state-year table, and a state-year with neither predictor left at zero.
Fitted per class (ALP, LNP), as now. Where a state has no polls, only the
second term acts; where it has no recent state election, only the first.
The Labor and Coalition corrections are applied to primaries exactly as
`state_deviation_apply()` does today; nothing outside `^fed` is touched.

**Predicted size, stated before running.** The state-election term has
ten usable state-years and an eyeballed slope near 0.2 on swings of 4 to 18
points, so it is worth 1 to 4 primary points where it fires and nothing
elsewhere. WA 2022: 0.2 x 17.7 x w(14 months) = +2.0 on a +5.5 state-level
miss (Tangney's own miss is +10.5). WA 2025: about -2.5 on a -3.0 miss. So:
**halve WA in both directions, close nothing else**, and expect the pooled
federal move to be **-0.001 to -0.004** -- smaller than the polls-only step,
because it touches two large state-years and a few small ones. Say now that
this cannot fix Tangney and is not aimed at Tasmania.

## Criterion (committed before any run)

Primary, targeted: **state-year mean Labor miss, sd over the 56 state-years,
must fall by more than one clustered SE** (SE by jackknife over the seven
elections). Report ALP and LNP separately; ALP decides.

Do-no-harm: pooled federal seat log loss (1,052 seats, seven pairs) within
1 SE of the shipped value, and no pair worse by more than 0.010 (the
previous plan's fed2019 damage was 0.011 and was accepted; a second
mechanism doing the same to the same pair would mean state polls in 2019
are being trusted twice).

Control: `AUSPOL_STATE_DEV_SHUFFLE=<seed>` on the pair with the largest gain,
six draws; the arm must beat the control mean by more than the control sd.

Unacceptable win: any improvement that comes from a pair where `state_elec_dev`
uses a state election held AFTER that federal polling day (leakage through
`election_dates()`; assert it in the builder and print the date used).

## Dry run of the criterion on known cases

- fed2022 WA (+7.8 miss, prior +17.7 at 14 months): must move Labor up in
  all 15 seats by 1.5 to 3 points. If it moves less than 1, the decay or the
  ridge penalty has crushed it; if more than 4, the fit is chasing this one
  cell and the leave-target-out step is broken.
- fed2025 WA (-3.0, prior -18.5 at 2 months): must move Labor DOWN. This is
  the pair that currently gets no correction at all; it is also the pair
  where our ledger lead over AEF is largest, so the do-no-harm bound on
  fed2025 matters most here.
- fed2025 QLD (+1.6, prior -7.0 at 6 months) and fed2013 WA (+2.2, prior
  -2.7): both move the WRONG way by about a point. They are the cost, and
  they are in the table before the run so they cannot be explained away
  after it.
- fed2022 TAS, fed2010 TAS, fed2025 NT: untouched by construction; report
  them unchanged as the proof that the mechanism did not leak into states it
  has no data for.

## Smoke test of the fit itself, before any harness run (18:40)

Built as `state_deviation_b2()` (ridge, penalty grid 1-300 chosen leave-one-
election-out; unit-tested on planted data). Fitting the builder revealed a
bug: `build_state_deviation_features.R` started from the anchor's results
table, which ends in 2022, so EVERY fed2025 state-year had been emitted as
0 / 999 / 0 -- the 2025 WA state election never reached the file. Fixed
(union of state-years); the shipped mode 1 is unaffected because fed2025
still has no state polls.

Coefficients and the Labor correction each arm would add, from the real
tables, leave-target-out:

| target | b_poll | b_elec | lambda | WA add | other adds |
|---|--:|--:|--:|--:|---|
| fed2022 | +0.088 | +0.079 | 300 | **+1.1** | sa +0.5, qld +0.3, vic -0.4 |
| fed2025 | +0.205 | +0.369 | 1 | **-6.3** | qld -2.0 |
| fed2019 | +0.266 | +0.164 | 100 | | |

Two things to say before running. (1) WA 2022 gets +1.1, under the +1.5
dry-run floor set above: when the target is out of the training table the
penalty search shrinks the state-election term hard, because WA 2022 was
most of its evidence. (2) When WA 2022 IS in training (target fed2025) the
term is trusted at 0.37 and WA 2025 gets -6.3 against a -3.0 miss: an
overshoot of the same size as the miss, so fed2025 may not improve and
could breach do-no-harm. **Both are the plan working as written**: the
state-election term rests on one landslide, and a leave-one-out fit says so
by flipping between distrust and over-trust. The expected outcome is now
REFUSE unless the harness run says otherwise; running it anyway is the
point of pre-registering.

## Not run yet

Machine at 8.9 GB free at 17:45 with two citiusverse R jobs resident; the fed
harness alone needs ~6. Runs: fed pairs, shipped flags, 20,000 sims, arm
`AUSPOL_STATE_DEV=2` vs the stage-6 baseline already on disk, then the six
shuffle draws on the best pair. Estimated 40 minutes of compute once memory
allows.

# RESULT, 2026-09-19 18:55: REFUSED

Federal harness, shipped flags plus `AUSPOL_STATE_DEV=2`, 20,000 sims, arm
`a8aa01d-g0e8c044` against the shipped v38 stage-6 run `a8e6433-gb7d70a9`.

**Primary (state-year sd of the mean Labor primary miss, lower is better):**
base 2.814 -> v2 2.777, delta -0.036, jackknife SE over 7 elections 0.050.
**NOT MET** (needs more than one SE).

**Do-no-harm (pooled federal seat log loss, 1,051 seats, lower is better):**
base 0.2529 -> v2 0.2545, +0.0016 (SE by pair 0.0019: inside one SE, so
not a breach on its own). Per pair: fed2019 -0.0061, fed2022 -0.0021,
fed2016 -0.0004, fed2013 +0.0018, fed2010 +0.0039, fed2007 +0.0052,
**fed2025 +0.0090** (bound +0.010; the pair the plan flagged).

**Dry-run cases, Labor predicted (base -> v2) vs actual:**

| seat | pair | actual | base | v2 |
|---|---|--:|--:|--:|
| Tangney | fed2022 | 38.1 | 27.6 | 27.9 |
| Pearce | fed2022 | 42.8 | 33.9 | 34.2 |
| Hasluck | fed2022 | 39.7 | 30.4 | 30.6 |
| Tangney | fed2025 | 42.5 | 42.2 | 38.0 |
| Pearce | fed2025 | 40.1 | 47.1 | 43.1 |
| Hasluck | fed2025 | 48.4 | 48.3 | 44.4 |

WA 2022 moved +0.3 (below the +1.5 floor: with WA 2022 out of training the
penalty search chose lambda 300 and the state-election term was 0.08). WA
2025 moved -4.4 on the state mean (the -3.6 miss became +0.8), which is the
over-trust case the smoke test predicted: seat by seat it fixed Pearce and
broke Tangney and Hasluck, and the pair's log loss rose 0.009. Tasmania, ACT
and NT unchanged in every pair (21 of 21 zero), as required.

Shuffle control not run: it exists to validate a win, and there is none.

**Verdict: REFUSE. `AUSPOL_STATE_DEV` stays "1".** The mechanism is built
and switchable; what it lacks is evidence. The state-election term has one
landslide behind it, and a leave-one-out fit says so by swinging between
0.08 and 0.37. It becomes testable again when the corpus gains Tasmanian
state elections (seven of the twelve worst state-years) or a second WA-sized
case. The fed2025 builder fix (state-years no longer dropped after 2022)
stays, because it is a data correctness fix that the shipped mode does not
read yet but will the day 2025 state polls appear in the anchor.

**Disclosed after the run (review gate, 19:00):** the feature builder still
zeroed `state_elec_dev` at 24 months, so the arm as run was a 24-month cliff
with decay inside it, not the smooth decay registered above. The cells that
differ are the stale ones (fed2025 NSW at 25 months, SA at 37; fed2022 NSW
38, VIC 42; fed2019 WA 26; fed2016 WA 40), each of which would have received
a term of under 0.4 x swing x 0.35. The refusal rests on WA 2022 (14 months)
and WA 2025 (2 months), both inside the window and unaffected, so the run
is not repeated. The builder now emits the raw swing at any gap.
