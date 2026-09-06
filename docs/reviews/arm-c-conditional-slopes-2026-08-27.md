# Arm C refused: conditioning on WHO is right, conditioning only on that is wrong

2026-08-27. Stage 1 of `docs/plans/prereg-joint-slope-spread-retune.md`
(`5acaff1`), scored across all five harnesses, 17 election pairs.

**Arm C does not ship. Stage 2 does not run**, as that document requires.

## One stated criterion change, made before scoring

The pre-registration named calibration and Brier. It is scored here on **log
loss primary**, per the metric order adopted in `b5defb9` and recorded in
`CLAUDE.md`.

That change was made for a reason independent of any result: log loss is the
only one of the three that matches the failure mode, because Brier caps the cost
of a seat called 0.9997 and lost at the same value as one called 0.90 and lost.
Measured on a different change entirely, log loss moved −29% where Brier moved
−1.7% and the calibration slope not at all. The swap is recorded rather than
quiet, and **it does not rescue arm C** — arm C fails on log loss, on Brier, and
on the original criteria alike.

## Result

| metric | better in | mean | paired t | p |
|---|---|---|---|---|
| **log loss** | 7 of 17 | +0.0174 | +0.82 | 0.422 |
| Brier | 8 of 17 | +0.0014 | +0.58 | 0.567 |

Clustered on harness: mean +0.0356, SE 0.0290, t +1.23. Null, tilting worse.

| harness | Δ log loss | pairs |
|---|--:|--:|
| nsw | **−0.033** | 1 |
| wa | **−0.023** | 7 |
| fed | +0.034 | 6 |
| vic | +0.086 | 2 |
| sa | +0.114 | 1 |

## The pattern, which is worth more than the refusal

Ranked by effect, the elections arm C **hurts** are the emergence elections:

| pair | Δ log loss | what happened there |
|---|--:|---|
| vic2018 | **+0.191** | |
| fed2022 | **+0.143** | the teal wave — six emergences |
| sa2026 | **+0.114** | One Nation wins four seats from nothing |
| fed2019 | +0.094 | Steggall takes Warringah |
| wa2013 | **−0.203** | ordinary incumbent cycle |
| fed2013 | −0.060 | ordinary |
| nsw2023 | −0.033 | ordinary |

**The new-candidate slope of 0.326 is an average over candidates who are
overwhelmingly no-hopers**, so it shrinks the rare emergent toward the statewide
mean — the exact seats the model already fails on, made worse.

So the finding is not "candidate identity does not matter". It is that
identity splits into three groups, not two:

1. **A returning candidate** — highly predictable, slope 0.907, and arm C gets
   this right.
2. **A new candidate who will poll nothing** — the overwhelming majority, slope
   near 0.3, also right.
3. **A new candidate who will win** — rare, and pooled into group 2, where the
   slope is catastrophically wrong for them.

Groups 2 and 3 are indistinguishable from the corpus alone: neither has a prior
vote in the seat. **Separating them is exactly what salience was built for**, and
this is the first measurement that shows the seat model needs it rather than
merely benefiting from it.

## What ships from this

Nothing. Arm C is refused, arm P was already refused, and uniform swing survives
stage 1.

What survives is `candidate_returns()` and `conditional_slopes()`, which are
tested, wired into all five harnesses and off by default. They are the machinery
a three-way split will need.

## Also fixed while doing this

- **`CAL_TAG` did not include the arm parameters**, so two arms wrote one
  per-seat filename and the second silently overwrote the first. Twice —
  `AUSPOL_LEVEL_SD`, then `AUSPOL_DEV_SLOPE`. Every harness now appends a hash of
  all `AUSPOL_*` variables, so a new parameter cannot repeat it.
- **vic2018 → vic2022 matched ZERO of 508 seat-classes** because the corpus
  stores those elections' seats as `albertpark` and `Albert Park`. Zero is a
  plausible-looking number, so arm C would have been a silent no-op in the live
  target state. Visible only because the other six pairs printed a normal rate
  beside it.
