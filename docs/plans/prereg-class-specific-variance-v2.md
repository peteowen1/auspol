# Pre-registration v2: class-specific variance, wider grid, bar sized on itself

2026-09-03, written after stage 1 was scored and refused
(`docs/reviews/class-variance-stage1-2026-09-03.md`).

**This is weaker evidence than a clean pre-registration and must be described
that way wherever it is cited.** The direction is already known: per-class
widening helps, monotonically, in all five harnesses, at p = 0.004. What is not
known is where the optimum sits and whether the effect is ever big enough to
matter. Those are the two questions v2 asks, and it cannot un-know the first.

## What v1 got wrong, and what it got right

**Wrong: the bar.** v1 set an absolute bar of 1.171, computed from the
paired-difference sd of the *level_sd* experiment (3.901). Paired-difference sd
is a property of **the change being tested**, not of the metric or the dataset.
level_sd swapped a flat 3.81 for a curve — large structural change, large
spread. This multiplies one class's slope, and its observed paired sd is
**0.373**. The bar was therefore about ten times too high, and it was set that
way before any arm ran, so v1 could only ever refuse.

**Right, and kept unchanged:** the guards, the class split, the mechanism check.
Seats a major won moved −0.0005 to −0.0113 against a 0.070 guard while only
`m_IND` varied, so the class filter provably does not leak.

**Right, and the reason v2 exists at all:** the grid-edge clause. `m_IND = 2.00`
was the boundary and the best arm, which the document said makes the result a
direction rather than a value. That clause is result-blind and fired on its own.

## The change

Unchanged from v1. `AUSPOL_LEVEL_MULT_IND` and `AUSPOL_LEVEL_MULT_OTH` multiply
`level_sd`'s slope for independents and for other non-majors; majors untouched.
Already implemented and proven byte-identical at `m = 1` (commit `8c75fef`).

## The grid

```
Stage 1:  m_OTH = 1.00 fixed;  m_IND in {1.00, 2.00, 3.00, 4.00, 5.00}
Stage 2:  m_IND at the stage-1 winner;  m_OTH in {1.25, 1.50}
```

`m_IND = 2.00` is carried over deliberately as the link to v1: it must reproduce
v1's −0.1185 on the primary, and if it does not, the two runs are not comparable
and nothing else here means anything.

**An interior optimum is required.** If the best arm is again at the edge
(`m_IND = 5.00`), the answer is once more a direction and not a value, and the
correct response is a third grid, not shipping the edge.

## Primary criterion — TWO bars, and both must hold

The failure of v1 was one bar doing two jobs. They are separated here.

### 1. Statistical: `t >= 2.80` on non-major wins

Mean paired change in log loss on seat-elections a non-major won, pooled across
five harnesses, divided by the standard error **computed from that arm's own
observed paired sd**. Not from a previous experiment's.

2.80 is the same 80%-power-at-alpha-0.05 threshold the repo has used throughout
(1.96 + 0.84), so this is the existing convention with the reference class fixed.

**A t-threshold cannot be mis-sized in advance, which is the whole point.** It
adapts to whatever noise the change actually produces, and it is computed the
same way whichever direction the answer goes.

### 2. Materiality: the effect must reach **0.25** in absolute log loss

A t-statistic accepts arbitrarily small effects given enough n, and this model
already carries many parameters. A new one has to buy something.

0.25 is roughly 15% of what A1 delivered on the same subset (−1.705 on federal
non-major wins). Stated as a fraction of a known, shipped, accepted change
rather than picked off a scale with no anchor.

### Co-primary: IND-won seats

**Both bars again, on the IND subset alone**: `t >= 2.80` and effect `>= 0.25`.
n = 59. All four conditions must hold.

## Guards, unchanged from v1

- **All-seat log loss must not worsen by more than 0.096.**
- **Log loss on seats a MAJOR won must not worsen by more than 0.070.** The
  mechanism check: the majors' curve is untouched by construction, so movement
  beyond noise means the class filter is leaking.

## Dry-run: run the criterion on stage 1, whose answer is already known

This is the check v1 should have had and did not.

Computed by running `scripts/score_class_variance.R` with `AUSPOL_CV_V2=1`
against the stage-1 arms, so these are the criterion's own output, not a
hand-worked example.

| stage-1 arm | primary effect | t (>= 2.80) | materiality (>= 0.25) | co-IND t | verdict |
|--:|--:|--:|---|--:|---|
| m_IND 1.25 | −0.0321 | 2.46 fail | fail | 2.25 | refuse |
| m_IND 1.50 | −0.0548 | 2.78 fail | fail | 2.55 | refuse |
| m_IND 1.75 | −0.0949 | **2.95 pass** | fail | 2.74 | refuse |
| m_IND 2.00 | −0.1185 | **2.98 pass** | fail | 2.77 | refuse |

**The criterion refuses every arm v1 refused, for a better-stated reason.** It is
not a rubber stamp built to let the known answer through: the two arms that
clear the statistical bar are stopped by materiality. If v2's wider grid finds
nothing bigger, v2 refuses too.

That is the test v1 failed. A criterion that would have accepted everything it
was shown is not a criterion.

## Refusal — what disqualifies a winner

- **If the best arm is at the grid edge** (`m_IND = 5.00`). Direction, not value.
  Re-register wider; do not ship the edge.
- **If `m_IND = 2.00` does not reproduce v1's −0.1185** within simulation noise.
  The runs are then not comparable and everything here is void.
- **If the majors move beyond the 0.070 guard**, or their calibration slope moves
  by more than 0.05 in either direction. The premise is that they were already
  right.
- **If a flat widening captures the same gain.** A control arm raising the slope
  for EVERY class, majors included, runs alongside the winner. If it matches the
  primary within its own SE, ship nothing: the class split was not the mechanism.
- **If any party's Victoria 2026 median seat count moves by more than 3.** Stop
  and hand the decision to Pete.
- **If the gain sits in one harness.** Report per-harness. At `m_IND = 2` in
  stage 1 it did not: fed −0.170, nsw −0.060, wa −0.054, sa −0.052, vic −0.046.
- **If materiality passes only because the grid ran to an extreme setting that
  visibly degrades the seat forecast.** A very wide IND band will eventually
  improve log loss on IND-won seats by making every independent plausible, at
  the cost of the seats they lose. Report log loss on seats where an independent
  RAN AND LOST as a named counterweight; if that worsens by more than the
  primary improves, refuse.

## What the criteria cannot see

- **88 non-major wins and 59 IND wins carry everything.** Unchanged from v1 and
  still the binding constraint.
- **One Nation cannot be scored.** Four seat-elections across five harnesses.
- **The direction is known before running.** No amount of criterion design fixes
  that; it is why this document is weaker evidence than v1 would have been had
  its bar been right.
- **`n_sims = 5000`**, carried over from v1's run settings, with the winner
  re-verified at 20000 before anything ships. Simulation noise measured at about
  1/180th of v1's effect; it is a larger fraction of these smaller effects and
  the re-verification is what covers that.

## Amendments

None. Any change must be a visible addition with the original clause left
unedited, and must state whether it favours the answer found later.
