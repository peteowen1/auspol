# Pre-registration: does `fed_swing` decay with time since the federal election?

Written 2026-08-20, **before South Australia is scored**. Committed before
running.

## The hypothesis, and where it came from

[../reviews/fed-swing-gain-decomposition-2026-08-20.md](../reviews/fed-swing-gain-decomposition-2026-08-20.md)
observed that on five elections, the two held within a year of a federal poll
gained from `fed_swing` and the three held later did not:

| election | months after federal | gain |
|---|---:|---:|
| vic2022 | 6 | +0.330 |
| nsw2023 | 10 | +0.377 |
| qld2020 | 17 | −0.285 |
| vic2018 | 24 | −0.202 |
| nsw2019 | 34 | −0.050 |

**That pattern was noticed after seeing those results, so those five elections
can never test it.** This plan exists to state a prediction about data that has
not been scored, before scoring it.

## The out-of-sample data

**South Australia**, which played no part in forming the hypothesis. SA votes in
March, so both its scorable cycles fall in the long-gap group:

- **sa2018** — 17 March 2018, following federal 2 July 2016 by **20 months**.
- **sa2022** — 19 March 2022, following federal 18 May 2019 by **34 months**.

Neither has a published `fed_swing`; both use the transposed measure, which
[the decomposition](../reviews/fed-swing-gain-decomposition-2026-08-20.md)
measured as costing 1.9 points of gain against the published one — small
relative to the 11.5-point effect under test.

## The prediction, fixed now

**Both sa2018 and sa2022 will have a gain at or below zero.**

Under the null that gap does not matter, each is roughly a coin flip, so
**P(both ≤ 0) = 0.25**. Two observations cannot establish anything on their own,
and this plan does not pretend otherwise.

## THE POWER CALCULATION, DONE FIRST

Adding SA takes the long-gap group from 3 to **5** and leaves the short-gap
group at **2**. Using the observed spread of per-election gains (sd 0.312):

```
SE = 0.312 * sqrt(1/2 + 1/5) = 0.261     ->   2 SE bar = 0.522
```

The difference between the groups currently reads **0.533**.

**So this test is expected to land almost exactly on the bar, and will probably
not be decisive either way.** That is stated now, in advance, because it is
precisely the thing four earlier criteria discovered afterwards. A result of
"1.9 SE" must not be read as a near-miss worth another look, nor "2.1 SE" as
proof.

**The short-gap group is stuck at 2** and cannot grow from historical data —
only two Australian state elections in the corpus fall within a year of a
federal one. That is the binding limit, and no amount of extra long-gap data
fixes it.

## Decision rule, fixed now

- **Confirmed** only if the group difference exceeds **2 SE** computed from this
  run's own seven per-election gains, **and** both SA elections have gain ≤ 0.
- **Refuted** if either SA election gains more than **+0.20** — the smaller of
  the two short-gap gains — since that would put a long-gap election among the
  short-gap ones.
- **Undecided** otherwise, which is the most likely outcome and is a legitimate
  result to report, not a failure to be resolved by trying something else.
- **No change to `SEAT_SWING_COEF` on this evidence either way.** Confirmation
  would justify designing a gap-aware coefficient and pre-registering *that*
  separately. It would not license editing a live constant off a seven-election
  observational pattern.

## Refusals — what would disqualify a CONFIRMATION

- **G1 — the federal election is confounded with the gap, and SA does not break
  it.** sa2018 follows federal 2016, exactly like vic2018 and nsw2019; sa2022
  follows federal 2019, exactly like qld2020. So SA adds new *states* at
  federal elections already in the long-gap group. If the pattern is really
  "federal 2016 and 2019 were uninformative about later state votes" rather
  than "distance erodes information", **this design cannot tell the
  difference**, and a confirmation must be written up naming that limit.
- **G2 — what would break it, and is not available.** A **short**-gap election
  drawing on federal 2016 or 2019, or a **long**-gap one drawing on federal
  2022. Neither exists in the corpus. The nearest future candidate is **sa2026**
  — 21 March 2026, following federal 2025 by 10 months, a SHORT gap sharing its
  federal election with Victoria 2026 at 18 months. Scoring it needs the March
  2026 ECSA result, which this repo does not hold. **If the hypothesis survives
  here, fetching that result is the next step, not further analysis of these
  seven.**
- **G3 — a confirmation resting on one SA election is refused.** If sa2018 and
  sa2022 disagree in sign, the pair is reported as split and nothing is
  concluded from the one that agreed.
- **G4 — dispersion must be checked, not assumed away.** qld2020 lost with a
  baseline dispersion of 1.676, far below every other election. If either SA
  election also has dispersion below 2.0, its gain is uninformative about gap
  for the same reason, and it must be excluded and reported as excluded.
- **G5 — no re-reading the original five.** Their gains are fixed and already
  published. If this run changes them at all, something upstream moved and the
  run is invalid until that is explained.

## What this criterion cannot see

- Whether the mechanism is time at all, rather than anything else that
  correlates with the electoral calendar — a change of federal government
  between the two polls, for instance, which is true of federal 2022 and not of
  federal 2016.
- Anything about **magnitude**. Even a clean confirmation says the adjustment
  stops helping, not by how much or from which month.
- Whether Victoria 2026 in particular is affected. It is one election, at 18
  months, and this plan makes no prediction about it.
