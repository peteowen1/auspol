# The knobs stay — and the model was better calibrated than we knew

Against `docs/plans/prereg-seat-calibration.md`. **Refused on the decision
rule**, and the refusal comes with a correction that matters more than the
experiment.

## The result

24 grid points, six federal elections, forecast mode, `n_sims = 2000`.

| m | shrink | smooth | log | slope | accuracy |
|---:|---:|---:|---:|---:|---:|
| 1.25 | 0.10 | 0.30 | **0.8346** | 0.976 | 84.5% |
| 1.50 | 0.10 | 0.30 | 0.8380 | 1.008 | 84.3% |
| 1.00 | 0.10 | 0.30 | 0.8406 | 0.982 | 84.5% |
| **1.00** | **0.10** | **0.15** | **0.8469** | **0.980** | 84.3% |
| 1.00 | 0.20 | 0.15 | 0.8642 | 1.344 | 84.1% |
| 1.00 | 0.30 | 0.15 | 0.9022 | 1.642 | 84.4% |

The incumbent is the bolded row. The best point beats it by **0.0123 log, which
is 0.09 SE** against a bar of 1 SE. **Refused. The knobs stay where they are.**

The held-out set (Victoria 2018, Victoria 2022, South Australia 2026) was
**not spent.** Adoption already fails on the training set, so testing could only
consume a resource the next experiment will need.

## What the grid actually shows

**The published shrink of 0.10 is close to optimal, and higher values
overshoot.** Every `shrink = 0.10` row lands at slope 0.95–1.01. At 0.20 the
slope rises to 1.23–1.34 and at 0.30 to 1.52–1.65 — *under*-confident — with the
log score worsening monotonically. Whoever chose 0.10 chose well, and this is
the first time it has been checked in the configuration that ships.

`seat_sd` barely matters across 1.0–2.0. `smooth` prefers 0.30 over 0.15 by a
hair, and since the winner sits on that grid edge, **refusal C6 applies: the
optimum for `smooth` may be outside the grid and this is a lower bound.** Moot
given the refusal, recorded so nobody reads 0.30 as a measured optimum.

## The correction: our calibration figures were never of our model

**Incumbent slope in forecast mode: 0.980.** Essentially calibrated.

Every over-confidence figure this repo has ever quoted — slope 0.23–0.52, "58%
of seats in the 99–100% band", the reliability gaps of 10–14 points — came from
a backtest harness that passed **neither** `shrink` **nor** `statewide_draws`,
while `fit_seats_full.R` passes both. Three divergences found in one day, all
the same shape:

| | published model | harness before today |
|---|---|---|
| `statewide_draws` | yes | no |
| `shrink` | 0.10 | **0** |
| statewide vote | forecast, with error | the actual result |

Wired up, the reliability table is unrecognisable:

| claimed | actual |
|---|---|
| 50–60% | 57% |
| 70–80% | 75% |
| 80–90% | 83% |
| 90–95% | 91% |

and **no seat sits in the 99–100% band at all**, against 58% before.

**So the answer I gave Pete earlier today — "our seat probabilities are wildly
off" — was wrong.** It described a configuration we do not ship. The published
model is close to calibrated.

> **CORRECTED 2026-08-22 by `discrimination-gap-2026-08-22.md`.** The section
> below concludes we are "calibrated but blunt". That is wrong, and wrong in a
> way I introduced: it is measured in forecast mode, where `IND` falls under the
> poll-inclusion floor and is folded into `OTH`, so independents cannot win any
> seat at all. Measured where `IND` exists as a class, **we are level with AE
> Forecasts on 266 of 286 seats (log 0.255 against 0.247)** and 97% of the gap
> sits in twenty independent-won seats. The refusal and the calibration findings
> above are unaffected; only this section's diagnosis is.

## The real gap is sharpness, not honesty

That is not a clean win, because the log score says something else. On the two
elections both models cover, **with both forecasting from polls**:

| | AE Forecasts | ours |
|---|---:|---:|
| 2022 federal | log 0.234, slope 1.14, acc 90.7% | log 1.232, slope 0.85, acc 84.7% |
| 2025 federal | log 0.303, slope 1.17, acc 86.0% | log 1.255, slope 0.67, acc 83.2% |
| pooled | **0.268**, slope 1.15 | **1.244**, slope 0.76 |

We are calibrated but **blunt**: honest about our uncertainty, and far more
uncertain than they are. They are slightly under-confident and much sharper,
which is the better place to be.

**Their information advantage does not explain it.** Four of their eight final
reports are explicitly seat-betting updates — 2022vic, 2023nsw, 2022sa, 2026sa —
which is seat-level market information we neither have nor use. But the two
elections compared above are **not** among them: their 2022 federal final is
"Newspoll 53-47" and their 2025 federal final is "Ipsos 51-49 + final pollster
recalibration". Both poll-based, like ours. The gap is model quality.

## Where this leaves the work

Calibration is not the problem. **Discrimination is.** The next question is what
lets them separate seats we cannot — candidate-level incumbency and sophomore
effects, seat-specific history, or something in how they resolve a contest —
and that is a different investigation from any knob in this grid.

Two things are now known that were not this morning: our published model is
roughly honest about its uncertainty, and it is roughly four times less
informative per seat than the reference. Only the second is worth working on.
