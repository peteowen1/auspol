# Why no salience design can ship yet: the scale is election-local

2026-08-26. Follows `salience-regression-refused-2026-08-26.md`. That review
refused one model form. This one records why the obvious repair — gate salience
to candidates with no prior vote to lean on — **was not run**, and what would
have to be true before any salience design is testable.

Written before fetching fed2010/2013/2016/2019, which was the plan, so that the
four fetches are not spent on a test that cannot resolve.

## The gate hypothesis, and why it is right

Salience is meant to detect **emergence**. Applied to a sitting member it is
noise, because their prior vote already answers the question. fed2025 makes the
point at full strength:

**fed2025 contains zero emergences.** All 13 non-major winners had a prior party
vote of 15% or more — lowest Gee 20.4 and Boele 20.9. So every point salience
moved there was noise, which is why it turned a winners RMSE of 2.99 into 8.55.

| election | non-major winners | emergences (prior < 15%) |
|---|--:|--:|
| fed2022 | 16 | **6** |
| fed2025 | 13 | **0** |
| fed2013 | 5 | 3 |
| fed2010 | 5 | 2 |
| fed2019 | 6 | 2 |
| fed2016 | 5 | 1 |

The gate must key on **prior vote, not party class**: the two worst
over-predictions were Katter (OTH_RIGHT, prior 41.7, predicted 55.2) and Bandt
(GRN, prior 49.6, predicted 66.2). "Sitting independent" misses both.

## Three findings that block it, in order of severity

### 1. The effect is smaller than the test can detect

Sized before designing the criterion, per `CLAUDE.md`:

| quantity | value |
|---|--:|
| base error on fed2022 emergences | mean **−22.9**, RMSE 23.4, sd 4.9 |
| in-sample gain from the gated model (an upper bound) | **4.8 pts** |
| MDE at 8 emergences clustered on 4 elections (2.80 × SE) | **6.9 pts** |

**The best possible outcome sits below the detection floor.** No result from
fetching those four elections could have been read either way.

### 2. The interaction has the wrong sign

The gate implies salience should matter *less* as prior vote rises — a negative
`jump × prev_party` interaction. Fitted on fed2022, the election holding all six
emergences:

```
x:prev_party  = +0.182  (SE 0.241,  t = 0.75)
```

Positive and insignificant. The functional form the hypothesis predicts is not
in the data even where the data is most favourable.

### 3. The scale is election-local, so NO threshold rule works

This is the deep one, and it is the same root cause as the coefficient failure
in the previous review. Among candidates eligible for the gate:

| election | n | median | p90 | p95 | max |
|---|--:|--:|--:|--:|--:|
| fed2022 | 129 | 0.0 | 2.8 | 5.8 | **57.6** |
| fed2025 | 103 | 0.0 | 0.1 | 0.1 | **1.6** |

An **absolute** threshold looked perfect — `jump >= 10` gave 100% precision and
100% recall on fed2022 and zero false positives on fed2025. That is a **guard
that cannot fail**: fed2025's eligible maximum is 1.6, so a threshold of 10 is
unreachable by a factor of six. The clean result was measuring nothing.

A **relative** threshold has the opposite fault — no off switch, because there
is always a top 3%:

| flagged | fed2022 (6 emergences) | fed2025 (0 emergences) |
|---|---|---|
| top 3% | 4 true, 0 false | **0 true, 4 false** |
| top 1% | 2 true, 0 false | **0 true, 2 false** |

So an absolute rule cannot transfer between elections and a relative rule fires
unconditionally. **We cannot currently distinguish "2025 had no surges" from
"2025's scale is compressed", and both fit every number above.**

The cause: each election's chain is rescaled onto its own first batch, so the
unit of `jump` is "relative to whoever happened to be loudest in that election".
fed2025's chain is anchored on Bandt; fed2022's tops out at Monique Ryan.

## What would unblock it

A **cross-election anchor** — a term present in every election's chain whose
real-world search volume is roughly stable over time, so that one unit of `jump`
means the same thing in 2013 and 2025. This is the same shape as the PM anchor
tried and withdrawn earlier for cross-*seat* comparability, but the cross-
*election* problem is the one an anchor genuinely solves.

Until that exists, every salience number is comparable within its own election
and with nothing else. The ranking results stand on exactly that footing and
remain real: **AUC 0.971 on fed2022 and 0.969 on fed2025**, both within-election.

## A caution about the gate itself, independent of all the above

The 15% eligibility cut **excludes Nicolette Boele** (prior 20.9%, won Bradfield
on 27.0%), who is the single genuine near-emergence in fed2025. A gate tuned to
switch salience off in 2025 would have switched it off for the one case it could
have helped. Any future threshold must be pre-registered against that.

## Status

- The gated model is **not tested and not refused** — it is untestable with the
  instrument as built. Recorded here so it is not proposed again unexamined.
- fed2010/2013/2016/2019 are **not fetched**, deliberately.
- What proceeds is the attribution fix (`prev_party` over `prev_seat`), which is
  independent of salience entirely.
