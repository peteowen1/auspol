# Pre-registration v2: per-class concentration, allocated by education

Written 2026-09-15 after v1
(`prereg-education-ranked-concentration-2026-09-15.md`) was found unusable by
its own scoping. v1 is NOT deleted and its result section stays empty; this
supersedes it and says why.

## Why v1 failed before it ran

v1 named `fed2013 OTH_RIGHT` as a primary target on the strength of its
ORDERING correlation (+0.591). Scoping then showed the mechanism is
ordering x concentration, and OTH_RIGHT has the WEAKEST concentration law in
the corpus:

| class | pairs | k | R2 |
|---|---|---|---|
| IND | 22 | 0.642 | **0.826** |
| OTH | 17 | 0.648 | 0.536 |
| GRN | 23 | 0.957 | 0.373 |
| ONP | 10 | 0.339 | 0.364 |
| OTH_RIGHT | 16 | 0.603 | **0.212** |
| ALP | 23 | 0.231 | 0.067 |
| LNP | 23 | 0.079 | 0.016 |

A null on that target would not say which half failed, so the criterion cannot
do its job. Swapping the target to a better-fitted class was REFUSED: it would
favour the answer I want, which CLAUDE.md calls a rationalisation rather than
an amendment.

## What I already know, stated so the criterion cannot pretend otherwise

I cannot write "targets chosen before seeing the data" because I have seen:

- the education-ordering correlations, 43 of 43 party-elections consistent in
  sign, Spearman 0.665-0.800 where the party is non-trivial;
- the per-class concentration fits in the table above.

What is still genuinely unknown is whether COMBINING them predicts the
per-seat vote better than what we currently produce. Component quality does not
imply the combination helps.

## So: no targets. Every class, every pair, pooled.

Choosing any subset now is cherry-picking, so the design chooses nothing.

- Fit `SD = a * statewide^k` PER CLASS, leave-one-pair-out, exactly as
  `estimate_onp_concentration.R` already does for ONP.
- For every non-major class in every pair, reallocate the per-seat prediction
  with `concentration_allocate(level, SD(level), education_order(pair, seats))`.
- Majors (ALP, LNP) excluded on the pre-stated ground that their concentration
  law is absent (R2 0.067 and 0.016) -- a fitted spread would be noise. Stated
  now, from the table above, not after seeing results.

**Primary criterion: pooled per-seat primary RMSE across all 23 pairs and every
non-major class, against the shipped arm.** Adopt if it improves. One number,
fixed now, covering everything -- there is no subset to select afterwards.

**Secondary, reported and not decisive:** the same by class and by pair.

## Refusal: what would make an apparent win unacceptable

- **If the pooled win comes from one class.** Report the per-class breakdown.
  A win carried entirely by IND (best curve) or ONP (the motivating case) is a
  finding about that class, not the general mechanism this claims to be.
- **If it beats the shipped arm but not `base_pred`.** base_pred already
  carries the ONP concentration curve, so the comparison must be against both.
- **Placebo: rank by `born_aus_pct` instead.** It correlates +0.581 with ONP
  on sa2026. If the placebo does as well, this is evidence for "rank by
  something correlated", not for education.
- **If it needs the 3 census-less fed2013 seats dropped to work.** Those seats
  are excluded from scoring for BOTH arms or the comparison is rigged.

## What this cannot see

- Whether education is causal or proxying income, industry or urbanity.
- Victoria 2026. No Victorian pair has a right-minor party above 6.5%, and the
  two orderings agree there at Spearman +0.764 anyway, so this is not expected
  to move the live forecast much. If it does, distrust the implementation.
- Whether the concentration law extrapolates above its fitted range. It called
  sa2026 at 9.18 against 7.67 actual, 20% too wide.

## Prediction, written before running

Pooled RMSE improves slightly, 0.02-0.10 points. The gain concentrates in ONP
and OTH where the current allocation is worst, is near zero for GRN, and IND is
the one I am least sure about -- best curve, least reliable ordering. If the
pooled number improves but the per-class table shows one class carrying it, the
refusal above applies and the answer is no.
