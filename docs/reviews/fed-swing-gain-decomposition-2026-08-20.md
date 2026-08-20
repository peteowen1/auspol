# It was never the measure. Three elections gain nothing from `fed_swing`, and the live forecast looks like them.

Run 2026-08-20. No model change. This **corrects the mechanism** given in
[fed-swing-coefficient-2026-08-20.md](fed-swing-coefficient-2026-08-20.md) and
raises a risk on a constant that is live right now.

## The correction

That review concluded the transposed measure "works where it validates and is
unreliable where it could not be", and explained vic2018 and nsw2019's negative
gains as boundary-vintage noise. Its closing line was *more data is not
automatically better data — ask what the new observations are measured with.*

**Measured, the measure is barely the issue.** Scoring both on the same 180
seats:

| | gain over uniform swing |
|---|---:|
| published measure, 180 seats | **14.7%** |
| transposed measure, same 180 seats | **12.8%** |
| transposed measure, 441 seats | **1.2%** |

- **The measure costs 1.9 points** of gain.
- **The sample costs 11.5 points.**

Six times more of the collapse comes from *which elections were added* than from
*how they were measured*. The advice to ask what new observations are measured
with was right in general and wrong about this case.

## What actually separates the elections

| election | federal poll before it | months between | dispersion | gain |
|---|---|---:|---:|---:|
| vic2022 | 2022 | **6** | 3.351 | **+0.330** |
| nsw2023 | 2022 | **10** | 4.508 | **+0.377** |
| qld2020 | 2019 | 17 | 1.676 | −0.285 |
| vic2018 | 2016 | 24 | 3.153 | −0.202 |
| nsw2019 | 2016 | 34 | 3.399 | −0.050 |

The two elections held within a year of a federal poll both gain. The three held
more than a year after all lose. Mean gain **+0.354** against **−0.179**.

Dispersion does not explain it — nsw2019 (3.399) and vic2022 (3.351) have almost
identical dispersion and opposite gains. Neither does measurement: nsw2019's
shipped correspondence needed only **4** name-fallback matches, essentially
clean, and it still gains nothing.

**A federal swing appears to be informative about a state seat for about a year,
and then not.** Which is unsurprising once stated: it is a snapshot of local
sentiment, and local sentiment moves.

## How much this is worth believing: not much, and here is the arithmetic

**The pattern was noticed after seeing the results.** It therefore cannot be
tested on the five elections that suggested it, and this file does not test it.

Even taken at face value, a 2-versus-3 perfect split has a **1 in 10** chance of
arising from noise before any post-hoc penalty, because there are only
`C(5,2) = 10` ways to choose which two elections come top. The rank correlation
between gap and gain is only **−0.50**, because the ordering inside the losing
group is not monotonic.

So: a flag, not a finding. It is written down because of what it touches, not
because it is established.

## What it touches

`SEAT_SWING_COEF = c(fed = 0.7452)` is live. It was fitted on **vic2022 and
nsw2023 — gaps of 6 and 10 months, the two shortest in the set** — because those
are the only two elections with a published `fed_swing`.

**Victoria 2026 follows federal 2025 by 18 months.** Longer than either election
the coefficient was fitted on, and in the group where the adjustment did not
help.

That is not an argument for changing the constant. It is an argument that the
constant was fitted on a sample that may not represent the case it is applied
to, and that nothing currently measures this.

## Why it cannot be settled here

Testing it needs elections with a `fed_swing` and a known outcome, at varied
gaps. There are five. Adding more state elections does not help much: the gap is
a property of the electoral calendar, and Australian state elections cluster at
particular offsets from federal ones.

The honest options:

1. **Leave it and record the risk.** Costs nothing, and the forecast is already
   published with this constant.
2. **Pre-register a gap-decay test for the next cycle**, so the hypothesis is
   committed before the data that could confirm it exists. Victoria 2026 itself
   becomes one observation at 18 months.

Option 2 is the only one that converts this into evidence, and it costs nothing
now. Recorded for Pete rather than actioned.

## The methodological point

Today this measurement moved three times, and each time the reflex explanation
was reasonable:

1. sample size — the four-election fit gave a lower coefficient, read as the
   two-election fit being overconfident. **Wrong**: attenuation.
2. measurement quality — the added elections were noisier, read as bad data.
   **Mostly wrong**: worth 1.9 points of 13.5.
3. election character — something about the elections themselves. **Consistent
   with the evidence, and untested.**

Each explanation was adopted because it fit the numbers in front of it, and each
was displaced by computing one more thing. The general lesson is not about
`fed_swing`: **when a result moves, the first sufficient explanation is the one
most likely to be wrong, because it was reached by the least work.**
