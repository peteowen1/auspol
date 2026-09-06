# Class-specific variance, stage 1: REFUSED, and the bar was mine to get wrong

2026-09-03. Scores `docs/plans/prereg-class-specific-variance.md`, committed at
`8ffbe60` before any arm ran, with `scripts/score_class_variance.R` committed at
`b9c1264` before any arm output was opened.

**No arm passes. Stage 2 does not run.**

## Result

1,548 seat-elections per arm, five harnesses, 88 non-major wins, 59 IND wins.
Paired change in log loss against `m_IND = 1`; negative is better.

| m_IND | primary (bar −1.171) | co-IND (bar −1.649) | all-seat guard | majors guard | p |
|--:|--:|--:|--:|--:|--:|
| 1.25 | −0.0321 | −0.0429 | −0.0023 | −0.0005 | 0.016 |
| 1.50 | −0.0548 | −0.0720 | −0.0042 | −0.0012 | 0.007 |
| 1.75 | −0.0949 | −0.1254 | −0.0152 | −0.0104 | 0.004 |
| 2.00 | −0.1185 | −0.1556 | −0.0174 | −0.0113 | 0.004 |

Both guards pass at every setting. Both primaries fail at every setting.

## The effect is real and it is small

Monotone in `m_IND`, negative in **all five harnesses at every setting**, and
significant (p = 0.004 at `m_IND = 2`). Per-harness at `m_IND = 2`: fed −0.170,
nsw −0.060, wa −0.054, sa −0.052, vic −0.046. Nothing here is one harness
carrying the rest.

It is roughly **10x smaller than the bar it had to clear**.

## Why the bar was wrong, stated plainly

I sized it from the paired-difference sd of the **level_sd** experiment, 3.901,
and applied it to this one. **Paired-difference sd scales with the magnitude of
the change being tested.** level_sd replaced a flat 3.81 with a curve — a large
structural change, large effect, large residual spread. This multiplies one
class's slope, and its observed paired sd is **0.373**.

So the bar was set about ten times too high, and a bar computed from this
change's own noise would be `2.80 * 0.373 / sqrt(88) = 0.111`, which
`m_IND = 2.00` clears at −0.1185.

**That is not a reason to set the criterion aside, and it is not being set
aside.** The standing rule is that a criterion may be set aside only when its
incapability can be shown WITHOUT reference to which way the result went, and
the 10x gap was only visible after running. The one-way ratchet did exactly what
it was written to do: an observed sd BELOW the assumption leaves the bar alone,
because a surprise that makes the test easier is not allowed to.

## The refusal that needs no argument

**The best arm sits at the grid edge.** `m_IND = 2.00` is the boundary of the
pre-registered grid, and the document's own clause says that makes the result a
DIRECTION rather than a value, to be re-registered wider rather than shipped.
This clause is result-blind and fires on its own, independent of the bar.

## What passed, and it is worth keeping

**The class filter does not leak.** Seats a major won moved −0.0005 to −0.0113
against a 0.070 guard, while only `m_IND` varied. That is dry-run case 2 holding
on real data: this is not A1 again with a bigger number.

The other-non-major class barely moves and is not significant at any setting
(−0.0103 to −0.0431, p = 0.20–0.24), which is what `m_OTH = 1.00` throughout
stage 1 requires. Dry-run case 4 holds too.

## The durable lesson

**An MDE computed from one change's residuals does not transfer to another
change.** This repo already has the rule "size the primary metric's noise
against the expected effect before committing". The gap it did not cover is that
the noise itself is a property of the change, not of the metric or the dataset —
so borrowing a sd from a previous experiment imports the wrong reference class,
and does so invisibly, because the number looks like a measured quantity.

A pre-registration that borrows a sd should say which experiment it came from
and how similar in magnitude that change was, so the assumption is visible
rather than buried in a table cell.
