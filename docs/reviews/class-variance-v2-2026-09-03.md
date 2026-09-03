# Class-specific variance v2: REFUSED, and widening further makes it worse

2026-09-03. Scores `docs/plans/prereg-class-specific-variance-v2.md`, committed
before this grid ran. Stage 1 (`m_IND` in {1,2,3,4,5}, `m_OTH` fixed at 1),
`AUSPOL_N_SIMS=5000` per the run-settings addendum. Stage 2 does not run.

**No arm passes both bars. The change does not ship.**

## The link check passed

v2's `m_IND = 2` is required to reproduce v1's −0.1185 on the primary or the
two runs are not comparable. It does, to four decimal places: −0.1185, n 88.
The rest of this scoring is on solid ground.

## Result

| m_IND | primary t (eff) | co-IND t (eff) | all-seat guard | majors guard |
|--:|---|---|--:|--:|
| 2 | 2.98 pass (0.1185 fail) | 2.77 fail (0.1556 fail) | −0.017 | −0.011 |
| 3 | 2.98 pass (0.2076 fail) | 2.77 fail (0.2736 pass) | −0.033 | −0.023 |
| 4 | 2.60 fail (0.4247 pass) | 2.47 fail (0.5880 pass) | −0.047 | −0.025 |
| 5 | 2.65 fail (0.5068 pass) | 2.53 fail (0.7044 pass) | −0.052 | −0.025 |

Required: `t >= 2.80` AND `effect >= 0.25`, on both the primary and the co-IND
subset. Both guards pass at every setting throughout. **No cell in this table
is a pass**, and the pattern differs by subset:

- **Primary** (all non-majors, n=88): significance clears at `m_IND` 2-3 while
  materiality does not; materiality clears at 4-5 while significance no longer
  does. The two conditions never overlap.
- **Co-IND** (n=59, the smaller and noisier subset, and the one the original
  finding was actually about): **significance never clears anywhere in this
  grid.** It peaks at t = 2.77 (`m_IND` 2-3) and falls from there. Materiality
  clears from `m_IND = 3` onward, but the bar that was never in reach is the
  one that matters most for the question this change set out to answer.

## Why the grid-edge clause did not save it either

The best arm on the primary sits at `m_IND = 5`, the boundary — which the
document's own refusal clause treats as a direction rather than a value, to be
re-registered wider rather than shipped. That would normally be the next step.

**It is not, because of what happened between `m_IND = 3` and `m_IND = 4`.**
The t-statistic *peaks at 2.98 (m_IND 2-3) and then falls* to 2.60 and 2.65 as
the multiplier keeps rising, even though the raw effect keeps growing (0.12 →
0.51). Variance is growing faster than the mean: primary sd goes 0.373 → 0.654
→ 1.531 → 1.791 across the grid, roughly quadrupling while the effect only
quadruples too, but the *ratio* that matters for significance gets worse past
m_IND 3. Materiality clears exactly where significance stops holding, and
never both at once.

**That is a reason not to re-register wider.** A grid extending to `m_IND = 6,
7, 8` would very plausibly clear materiality by an even larger margin and fail
significance by more, not less — the mechanism visible in this grid points that
direction, not toward an undiscovered sweet spot just past the edge.

## What passed, again

Per-harness: negative in all five harnesses at every setting (fed −0.17 to
−0.79, nsw −0.06 to −0.30, sa/vic/wa smaller but consistently negative). The
majors guard holds throughout, −0.011 to −0.025 against a 0.070 tolerance --
the class filter still does not leak even as the effect on non-majors grows
5-fold. Other-non-majors stay flat and non-significant (p 0.24-0.25) at every
setting, as `m_OTH = 1.00` requires.

## Leave-one-election-out

Printed against v1's absolute co-IND bar (−1.649) as a scorer limitation --
v2's actual bars are t/materiality, not that number -- so read this as a
diagnostic rather than a verdict. Worst-case-drop-one values (−0.12 at m_IND 2
rising to −0.47 at m_IND 5) show no single election dominates the co-IND
result; the effect is broadly shared across the six federal elections and NSW,
SA, VIC, WA.

## Verdict

**Class-specific IND variance does not ship, on stage 1 or stage 2.** The
direction is now established beyond reasonable doubt -- negative in 20 of 20
harness x arm cells, growing monotonically, p < 0.02 throughout -- but it is
small relative to its own noise, and the mechanism (variance outpacing the
mean past `m_IND ~ 3`) argues against finding a passing setting by widening the
grid further.

The honest summary for `docs/NEXT-STEPS.md`: per-class variance is a real but
minor refinement, not a fix worth its own parameter next to the 29% log-loss
gain A1 already delivered. Section A of the plan is now fully closed, and this
line of work is closed with it rather than left open pending a wider grid.

## What the criteria still cannot see

- Everything v2 already listed: 87-88 non-major wins and 55-59 IND wins carry
  the whole result; One Nation is unscored at n=4; salience remains the
  unshipped fix for the emergence tail this touches least.
- **Whether the same variance-outpaces-mean mechanism applies to OTHER kinds of
  widening** (a different functional form, a per-seat rather than per-class
  multiplier) is untested. This result is specific to a slope multiplier on
  `level_sd`'s existing form, not a general statement about widening IND
  variance by any means.
