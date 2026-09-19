# Pre-registration: state-deviation v2 (prior state election as a second predictor, all eight states)

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

Seven of the twelve are Tasmania, ACT or NT: **the states the shipped
mechanism cannot touch**, because it needs state polls and the anchor has
none for them. Tasmania has a state election inside 24 months of most
federal polls (2010, 2014, 2018, 2021, 2024), so `state_elec_dev` exists
there. That is the gap this plan targets.

## The arm

`AUSPOL_STATE_DEV=2`: same leave-target-out, one-row-per-state-year fit, but
on two predictors with shrinkage, applied to all eight states:

    err_sy = b1 * state_poll_dev_sy + b2 * w(gap_sy) * state_elec_dev_sy

with `w(gap) = exp(-gap / 24)` (the builder's own 24-month noise finding as a
decay, not a cliff), ridge penalty chosen leave-one-election-out on the
state-year table, and a state-year with neither predictor left at zero.
Fitted per class (ALP, LNP), as now. Where a state has no polls, only the
second term acts; where it has no recent state election, only the first.
The Labor and Coalition corrections are applied to primaries exactly as
`state_deviation_apply()` does today; nothing outside `^fed` is touched.

**Predicted size, stated before running.** The shipped form removes ~28% of
state-year variance where polls exist. Adding the state-election term at
r = 0.77 on the thin n = 10 where it is fresh, and giving TAS/ACT/NT a
correction for the first time, should take the state-year miss sd from 2.79
toward ~2.3. Translating through the previous plan's realised ratio
(0.0045 log loss per ~0.4 points of state-year sd), the expected pooled
federal move is **-0.002 to -0.005**. fed2022 WA specifically: `state_elec_dev`
for WA 2022 is +5.2 (the 2021 state landslide, 14 months old, w = 0.56) so
the added term is worth roughly +1.5 to +2.5 on Tangney -- **still not the
+10.5 miss**. Say that now: this plan cannot close WA 2022. It is aimed at
the seven Tasmania/ACT/NT state-years and at halving, not removing, WA.

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

- fed2022 TAS (miss -5.63, 5 seats): the 2021 Tasmanian election was a
  Liberal win with Labor down; `state_elec_dev` negative, 14 months old.
  Should move the right way. If it does not, the decay or the sign convention
  in the builder is wrong, not the idea.
- fed2019 QLD (-5.83, 30 seats): state polls said Labor 49-55, actual 41.6;
  the 2017 Queensland election (Labor +1) is 18 months old and mildly
  positive. Both predictors point the wrong way. **This pair must get worse
  under the arm**; the do-no-harm bound is what stops it from being fatal.
- fed2010 TAS (+7.66): the March 2010 state election was 5 months before,
  Labor -12 there while federal Labor held; a negative state term would push
  Bass/Braddon the WRONG way. This is the case that argues the state-election
  term should be shrunk hard. If the arm passes only because of this cell
  going right by accident, the shuffle control will not show it -- so also
  report the arm with TAS excluded.

## Not run yet

Machine at 8.9 GB free at 17:45 with two citiusverse R jobs resident; the fed
harness alone needs ~6. Runs: fed pairs, shipped flags, 20,000 sims, arm
`AUSPOL_STATE_DEV=2` vs the stage-6 baseline already on disk, then the six
shuffle draws on the best pair. Estimated 40 minutes of compute once memory
allows.
