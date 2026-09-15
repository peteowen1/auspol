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
