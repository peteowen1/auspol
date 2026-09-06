# We beat AEF on One Nation's primary in all four seats. One number loses it.

2026-08-25. Direct three-way comparison — our projection, AEF's forecast, and
the actual result — on the four SA seats One Nation won.

## We are the better One Nation model

Absolute error on One Nation's first-preference share:

| seat | our error | AEF error |
|---|---:|---:|
| MacKillop | **−6.9** | −9.8 |
| Narungga | **−11.9** | −19.1 |
| Ngadjuri | **−3.6** | −6.3 |
| Hammond | **−0.3** | −8.6 |
| **mean absolute** | **5.7** | **11.0** |

**Better in all four, and roughly twice as accurate overall.** Hammond is
projected to 0.3 points. The One Nation allocation — federal ordering plus the
concentration curve — is not the problem, and today's day-long hunt for a
defect in it was looking in the wrong place.

## One number loses MacKillop

| MacKillop | 2022 | ours | AEF | actual | our error | AEF error |
|---|---:|---:|---:|---:|---:|---:|
| **LNP** | 67.0 | **49.9** | **35.0** | 26.9 | **+23.1** | **+8.1** |
| ONP | 8.1 | 28.3 | 25.4 | 35.3 | −6.9 | −9.8 |
| ALP | 20.0 | 17.5 | 12.6 | 15.6 | +2.0 | −3.0 |

**AEF let a 67% stronghold fall 32 points. Our uniform swing allows 17.**
That single 15-point difference is the whole gap between their 0.520 and our
0.952, and it is why they call the seat a coin flip and we call it settled.

## The caveat about betting odds is RESOLVED, and the comparison is fair

AEF publish a per-seat swing decomposition (`seatSwingFactors`). For all four
seats:

```
Adjustment towards MRP polling;      0.000000
Adjustment towards seat polling;     0.000000
```

**No MRP adjustment, no seat-polling adjustment, and no betting-odds component
appears in the decomposition at all.** So their SA 2026 numbers on these seats
are model output, not market prices. The benchmark comparison stands without
the caveat raised earlier today.

## The concept we are missing, named by their own model

Their decomposition lists ten components. Ours has one — a uniform statewide
swing. Theirs includes:

| component | MacKillop |
|---|---:|
| Base region swing | 5.630 |
| **Elasticity adjustment** | **0.000** |
| Reversion from previous swing | 0.386 |
| Correlation with federal swing | −1.191 |
| Retirement effect | 1.054 |
| By-election adjustment | 0.000 |
| Exhaustion from aligned non-majors | 0.000 |

Two things follow.

**"Elasticity adjustment" is a named term in a working competitor's model.**
Elasticity is how much a seat amplifies the statewide swing — precisely the
stronghold-collapse behaviour MacKillop needed and our uniform swing cannot
express. **We have no equivalent.**

**"Reversion from previous swing" is also there** — and it is the same concept
as the mean-reversion coefficient measured today at **−0.343 (4.56 SE)** and
set aside as possibly an artefact of regressing a change on its own baseline.
A working forecaster carrying an explicit reversion term is evidence the effect
is real rather than an artefact, though it does not settle the statistics.

**Note the elasticity term is 0.000 for all four seats**, so it is not what
produced their 35.0. Something else in their primary-vote model did. That is
worth understanding before copying anything.

## What this changes about priorities

Today ended with a plan to build booth-level regression over months. **This
says the gap is much narrower and much more specific than that.**

- Our One Nation model is **already better than the benchmark's**.
- The loss is concentrated in **how far a major party's stronghold can fall**.
- The competitor names two mechanisms for it — **elasticity** and **reversion
  from previous swing** — neither of which requires demographics, booth data,
  MRP or betting odds.
- One of those two we have **already measured** in our own corpus at −0.343.

**That is days of work with a benchmark to hit, not months.** Booth-level
regression should wait behind it.

## What must still be pre-registered

The mean-reversion coefficient remains artefact-suspect until tested with a
multi-election baseline as an instrument. **AEF using a similar term is
evidence, not proof**, and adopting a coefficient because a competitor has one
is exactly the reasoning this project's discipline exists to prevent. The
instrument test is the next experiment.
