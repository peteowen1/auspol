# Pre-registration: the state-level swing inside a federal election

Written 2026-09-15. Pete's diagnosis, in his words: *"tangey and hasluck would
be fixed by state level polling within fed elections? as WA was polling higher
than other states for ALP?"*

He is right about the cause. This plan tests whether the fix is worth shipping.

## The problem, measured

A federal forecast anchors to a NATIONAL swing. States move differently, and
the model has no way to say so. Mean ALP per-seat primary error by state:

| election | worst state | mean error | seats agreeing |
|---|---|--:|--:|
| fed2022 | **WA** | **+6.43** | **14 of 15** |
| fed2025 | **TAS** | **+8.06** | -- |
| fed2010 | NT | -6.14 | -- |

Hasluck +10.4, Tangney +10.3, Pearce +9.7, Swan +6.0 -- one state, one
election, one direction. Across all seven federal elections the spread of state
means runs **sd 2.6 to 4.2**, widest gap 7.7 to 13.1 points. This is not noise
around a national number; it is a level the model does not model.

The ten seats in group A carry **8.9% of the AEF-7's entire seat log loss**.

## WHAT I ALREADY KNOW, stated before the criterion

`output/state-deviation-features.csv` already holds `state_poll_dev` (what
state-level federal polling implied minus the national swing), `state_elec_dev`
(the preceding state election's own ALP swing), `state_elec_gap` and
`state_poll_n`. Over the **30 state-years that have any polling**:

- `r(state_poll_dev, actual state-level ALP miss) = **+0.525**`, t = +3.27
- `r(state_elec_dev, same) = +0.429`
- OLS slope of the miss on `state_poll_dev` = **+0.416**
- that slope removes **28%** of the across-state variance; the state-level ALP
  miss sd falls 2.69 -> 2.29

So the polls carried real information and the model used none of it -- but they
knew only about a quarter of it. WA 2022's `state_poll_dev` was +3.53 against
an actual +6.43. **Applying the fitted slope moves Tangney about +1.5 points on
a 10.3-point miss.** This is a partial fix by construction and the numbers
above say so before anything is run.

**Two hard coverage limits, also known in advance:**

- **Only 5 of 8 states ever have state-level federal polling** -- NSW, VIC,
  QLD, SA, WA. Never ACT, NT or **Tasmania**.
- **fed2025 has NO state-deviation data at all** (every state reads
  `poll_dev 0, gap 999, n_polls 0`).

Together those mean this mechanism **cannot touch Braddon or Bass**, the two
worst seats it was motivated by. It is aimed squarely at the fed2022 WA
cluster.

## Why this is NOT the block that already failed

`CLAUDE.md` records four state-deviation features being added to the primary
model and making things worse: pooled RMSE 3.8740 -> 3.9297, with 96% of
non-federal predictions moving by up to 5.87 points. The cause is recorded
there too: the features exist only for federal pairs, and the other 6,100 cells
were given `state_poll_dev = 0` and `state_elec_gap = 999` as fillers, which a
tree splits on as a jurisdiction label.

This is a **post-hoc correction applied to federal seats only**, so no
non-federal cell is touched, no filler value exists, and there is nothing for a
tree to key on. It is the "fit that part separately" branch of `CLAUDE.md`'s own
prescription rather than the "add a filler" branch that failed.

It is also confirmed absent from the shipped model: `state_poll_dev` is not a
column of `output/xgb-primary-v6-features.csv`, so there is no double-count.

## The mechanism

For federal pair P, state S, class C in {ALP, LNP}:

```
correction = b_C * state_poll_dev(P, S)      applied only where state_poll_n > 0
```

`b_C` is fitted by OLS through the origin on the state-level mean residual of
every federal pair EXCEPT P. Shares are renormalised to each seat's original
total, so a correction moves vote between classes within a seat and never
changes the seat's total.

ALP and LNP get their own coefficient rather than `b_LNP = -b_ALP`: the
deviation is defined on the ALP swing, and how much of it comes out of the
Coalition rather than minor parties is an empirical question, not an identity.

## The criterion

**Primary: pooled seat log loss over the seven FEDERAL pairs**, 1,052
seat-elections. Lower is better.

Primary rather than corpus-wide because `CLAUDE.md` is explicit that a targeted
fix is validated on its targets and an election-wide metric will refuse a real
fix through dilution -- a change touching 5 of 8 states in 7 of 22 pairs would
need roughly three times the effect to clear a corpus-wide bar.

**Guard, and it must not worsen: pooled seat log loss over all 22 pairs.** The
mechanism touches no non-federal seat, so this should be arithmetically
unchanged outside federal; if it moves, something is wired wrong and that is
the finding.

**Adopt if federal pooled seat log loss improves AND the permutation control
does not.** The control permutes which state each seat belongs to, within the
election, at fit and apply both -- the same instrument calibrated for the
demographic work, where the null landed on the baseline every time. **K = 10
draws**, fixed now.

**Report and do not decide on:** per-seat primary RMSE, Brier, the ten group-A
seats individually, and per-state breakdowns.

## Refusal: what makes an apparent win unacceptable

- **Any control draw beating the arm.** 1 of 10 is enough.
- **If the all-22 guard worsens at all.** Non-federal seats are untouched by
  construction; movement there means a bug, not a result.
- **If fed2022 worsens.** It is the election with the largest, best-evidenced
  state effect and the one this exists for. A win carried by other pairs while
  the motivating case regresses is not the fix.
- **If the gain needs `state_elec_dev` as well as `state_poll_dev`.** The
  mechanism above is polls-only and fixed now. The state-election term
  correlates +0.429 and adding it after seeing the polls-only result would be
  choosing the model from the answer.
- **A directional side effect:** if any class's win probability moves the same
  way in more than 90% of federal seats.

## What the criterion cannot see

- **Tasmania, the ACT and the NT**, which never have state-level federal
  polling -- so Braddon and Bass, two of the three seats that motivated this,
  are outside its reach.
- **fed2025 entirely**, for want of data rather than method.
- **Victoria 2026**, which is a STATE election: this mechanism is federal-only
  and does nothing for the live target. It buys backtest accuracy and
  jurisdictional honesty, not a better Victorian forecast.
- **Whether state polling is available at forecast time** in the quantity the
  backtest assumes. The file was built retrospectively.

## Prediction, written before running

Federal pooled seat log loss improves by **0.002 to 0.006**, carried almost
entirely by fed2022, with fed2016 (SA -5.99) and fed2010 (QLD -4.34) also
contributing. fed2025 is unchanged because it has no data. The control lands on
the baseline as it did for the demographic arm.

**The ten group-A seats improve by much less than their 7.8-point mean miss
suggests** -- around +1.5 points each where the state has polling, and nothing
at all for Braddon, Bass, Banks and Petrie. I expect roughly half the group to
be untouched.

If it passes, the honest description is not "we fixed the state swing" but "we
recovered the quarter of it the polls already knew about".

---

# RESULT, 2026-09-15: criterion MET, control passes, one deviation disclosed

## Primary criterion: pooled seat log loss, seven federal pairs

| pair | baseline | state-dev | move |
|---|--:|--:|--:|
| fed2010 | 0.2429 | 0.2191 | **-0.0238** |
| fed2007 | 0.3076 | 0.2928 | -0.0148 |
| fed2013 | 0.2579 | 0.2541 | -0.0038 |
| **fed2022** | 0.2629 | 0.2594 | **-0.0035** |
| fed2025 | 0.2600 | 0.2600 | 0.0000 (no data) |
| fed2016 | 0.3057 | 0.3090 | +0.0033 |
| **fed2019** | 0.1725 | 0.1835 | **+0.0110** |
| **POOLED** | **0.2584** | **0.2539** | **-0.0045** |

**-0.0045 over 1,052 seat-elections**, inside the 0.002-0.006 predicted band and
2.5x the best demographic result of the day. Four of seven improve, fed2025 is
untouched for want of data, two worsen. Per-pair t is -1.03 over the six that
ran, which is NOT significant -- the result rests on the seat-weighted pooled
figure and on the control, not on a t-test across six clusters.

## Refusal conditions

- **fed2022 must not worsen.** It improved, -0.0035. Does not fire.
- **All-22 guard.** Non-federal seats are untouched *by construction*:
  `state_deviation_apply()` returns early on any pair not matching `^fed` and
  says so. Verified directly -- sa2026's share matrix comes back identical.
- **Control.** See below; passes where tested.
- **No class dropped, no `state_elec_dev` added.** The mechanism is exactly the
  polls-only form registered in advance.

## The control

Permuting which state each seat sits in, within its election, on fed2010 --
the pair carrying most of the gain. Six draws:

| | value |
|---|--:|
| baseline | 0.2429 |
| **control mean of 6** | **0.2429** | 
| control sd | 0.0035 |
| control range | 0.2364 to 0.2471 |
| real arm | **0.2191** |

The null lands **exactly on the baseline** and the real arm is 6.7 control-sds
below it, with 0 of 6 draws beating it. The fitted coefficient collapses the
same way: ALP b = +0.334 real against -0.091, +0.004, +0.013 shuffled.

**The pooled control was subsequently run in full, as registered.** An earlier
version of this section recorded 6 draws on one pair and said the mechanism
should not be switched on until the full control was run. It now has been --
60 harness runs, 10 draws on each of the six pairs that change:

| | pooled seat log loss |
|---|--:|
| baseline | 0.2584 |
| **state-dev arm** | **0.2539** (-0.0045) |
| control mean of 10 | 0.2586 (+0.0001) |
| control sd | 0.0008 |
| control range | 0.2573 to 0.2603 |

**0 of 10 control draws beat the arm**, which sits 5.6 control-sds below the
null mean, and the null lands on the baseline to within 0.0001. Per pair the
four that improve are 0/10 and the three that do not are 10/10 -- the control
separates them exactly as it should.

The exact permutation p is 1/11 = 0.091, which is the floor at K = 10 rather
than a measured borderline. The criterion registered here is "improves AND no
control draw beats it", both met; it did not set a p threshold.

## Why fed2019 regresses, and what it says about the mechanism

The correction is only as good as the state polls, and they are right **19 of
30 state-years (63%)**:

| election | polls pointed the right way |
|---|--:|
| fed2010, fed2022 | 4 of 5 |
| fed2007, fed2013, fed2016 | 3 of 5 |
| **fed2019** | **2 of 5** |

fed2019 is the "miracle election". Queensland's polls implied **+5.3** for
Labor and the actual state-level miss was **-3.8** -- a nine-point sign error.
When state polls fail the same way national polls do, correcting toward them
moves away from the truth, and the mechanism amplifies rather than repairs.
That is an inherent property, not a tuning problem: this buys accuracy in
normal elections and costs it in exactly the elections where polling breaks.

## What it actually did for the seats it was built for

| seat | ours before | ours after | actual |
|---|--:|--:|--:|
| Tangney | 27.8 | 28.8 | 38.1 |
| Hasluck | 29.3 | 30.4 | 39.7 |
| Pearce | 33.1 | 34.1 | 42.8 |
| Swan | 33.1 | 34.1 | 39.1 |

About a point each on misses of six to ten. As predicted, and as the ceiling
analysis said in advance: **this recovers the quarter of the state swing the
polls already knew about, and nothing more.** Braddon, Bass, Banks and Petrie
are untouched -- Tasmania has no state-level federal polling and fed2025 has no
data at all.

## Honest summary

The mechanism works, is leakage-free, passes its control where tested, and is
worth roughly -0.0045 federal seat log loss. It does **nothing for Victoria
2026**, which is a state election. Its remaining gap is data, not method:
fed2025 has no state-deviation rows, and three jurisdictions never will.

`AUSPOL_STATE_DEV` stays at `0` until the pooled control is run.


## Refusal conditions, all five evaluated

| condition | result |
|---|---|
| any control draw beats the arm | **does not fire** -- 0 of 10 |
| the all-22 guard worsens | **does not fire** -- non-federal seats untouched by construction; `state_deviation_apply()` returns early on any pair not matching `^fed`, verified on sa2026 |
| fed2022 worsens | **does not fire** -- improved -0.0035 |
| the gain needs `state_elec_dev` | **does not fire** -- polls-only, as registered |
| a class moves one way in >90% of seats | **does not fire** -- most one-sided is IND at 66%, against a 90% bar. ALP 60% up, LNP 61% down, GRN 59% down, ONP 53%, OTH_RIGHT 50% |

## VERDICT: ADOPTED

`AUSPOL_STATE_DEV = "1"` in `scripts/published_flags.R`.

**It does not change the published Victorian forecast.** `fit_seats_full.R` has
no call site and the mechanism is federal by construction, so what changes is
what the federal backtest measures. Victoria 2026 is a state election and has
no deviation-from-national to correct.

**fed2019 still regresses by +0.0110 and that is accepted, not overlooked.**
The control confirms it is a real wrong-direction correction rather than noise:
fed2019's control mean is 0.1730, essentially the baseline, while the arm is
0.1835. State polls pointed the right way in only 2 of 5 states that year --
Queensland implied +5.3 for Labor against an actual -3.8. This mechanism buys
accuracy in normal elections and costs it in the elections where polling breaks,
which is a property of correcting toward polls and not a defect in the fit.
