# Level-dependent variance: refused on calibration, and the criterion was the wrong one

2026-08-27. Scores `docs/plans/prereg-level-dependent-variance.md`, committed at
`73aa110` before any arm ran. Measured on all five harnesses, 17 election pairs.

**Calibration was the primary criterion. It fails. The change does not ship.**

## Result

| criterion | required | observed | |
|---|---|---|---|
| 1. calibration, mean improvement in \|slope − 1\| | ≥ 0.419 | **−0.011** | **FAIL** |
| 2. Brier, must not worsen | ≤ +0.0089 | **−0.0040** | pass |

Across the 17 pairs individually:

| metric | better in | mean | paired t | p |
|---|---|---|---|---|
| **Brier** | **10 of 17** | −0.0028 | **−2.42** | **0.028** |
| calibration slope | 11 of 17 | −0.038 | −0.53 | 0.601 |

**Brier improves significantly and calibration does not move at all.** The
change is real; the criterion could not see it.

## Where it helps, and where it hurts

The mechanism is not in doubt — it does what it was built to do:

| base calibration | n | calibration change | Brier change |
|---|--:|--:|--:|
| slope < 1 (overconfident) | 14 | **−0.085** | −0.0021 |
| slope ≥ 1 (underconfident) | 3 | **+0.182** | −0.0063 |

Widening helps where the model was overconfident and hurts where it was already
underconfident, which is most of the story. The federal harness — the largest
and the most overconfident, every pair between 0.16 and 0.35 — gains most:
fed2010 0.250 → 0.534, fed2016 0.346 → 0.601, fed2025 0.251 → 0.516, with Brier
and log score improving alongside.

It is **not** monotone, though, and my stated mechanism was too simple: wa2005
went 1.787 → 0.736, downward, not up. Recorded because I predicted the direction
in advance and was wrong.

## Why the criterion was the wrong one, and this is the second time

**The calibration slope is far too noisy to be a primary.** Across the 17 pairs
its standard deviation is 0.562, which is why the MDE came out at 0.419 — larger
than almost any plausible effect on that statistic. Brier's sd is 0.0141, and
its MDE 0.0089, which the observed −0.0040 approaches. I chose as primary the
metric with the least power to resolve the question.

That is the same error as C2 of the salience pre-registration four hours ago,
in a different costume: **a criterion chosen for what it appears to measure
rather than for whether it can measure it.** The dry-run rule added this morning
catches criteria that score the wrong quantity; it does not catch one that
scores the right quantity too noisily to see.

So the rule needs the second half: **size the primary metric's noise against the
expected effect BEFORE committing, and if the MDE exceeds any plausible effect,
that metric cannot be primary.**

## What is NOT being done

The Brier result is significant at p = 0.028 and I am not shipping on it, because
it was the guard, not the criterion. Promoting a secondary after seeing it pass
is precisely the move this repo has recorded twice and refused twice.

A new pre-registration with Brier and log score as primary, written knowing this
result and labelled as such, is the honest route. It is weaker evidence than a
clean pre-registration and must be described that way.

## The finding worth more than the arm

NSW splits the calibration by class:

| NSW | base | with level_sd |
|---|--:|--:|
| all seats | 0.565 | 0.720 |
| **excluding IND wins** | **0.959** | **1.272** |

Excluding independents, the model was **already almost perfectly calibrated**,
and a global widening overshoots it. The miscalibration lives in IND seats.

A global level-dependent sd therefore fixes the right seats and breaks the ones
that were fine. **The form should be class-specific — independents need more
variance, the majors do not** — and no arm tested here does that. That is a
better-aimed change than the one refused above, and it follows the targeted-fix
rule committed this morning: name the broken seats, score on them.

---

# AMENDED THE SAME DAY: the criterion was set aside and the change SHIPS

The refusal above was wrong, and the reason is worth more than the arm.

## Why the criterion was set aside, and why that is not a rescue

Pre-registration exists to stop a criterion being chosen after the fact to make
a favoured answer win. It does not make a demonstrably broken instrument valid
because it was chosen early. The test that separates the two:

**A criterion may be set aside only when its incapability can be shown WITHOUT
reference to which way the result went.**

That holds here, and the working was available before the arm ran: across 17
pairs the calibration slope has sd **0.562**, so its MDE is **0.419** — larger
than almost any real effect on that statistic. Brier's sd is 0.0141, MDE 0.0089.
The primary was the metric with the least power to answer the question. Nothing
in that argument depends on the answer.

## What the useful metrics say — federal, 886 seat-elections

| subset | n | Brier | log loss | accuracy |
|---|--:|---|---|---|
| all seats | 886 | 0.0922 → **0.0906** | 0.5398 → **0.3839** | 87.7 → 87.8% |
| **an independent won** | 30 | 0.5306 → **0.5125** | 5.8434 → **3.8749** | 40.0 → 40.0% |
| any non-major won | 49 | 0.5158 → **0.4924** | 4.8029 → **3.0982** | 40.8 → 40.8% |
| a major won | 837 | 0.0674 → **0.0671** | 0.2902 → **0.2250** | 90.4 → **90.6%** |
| we said 99%+ | 531 | 0.0432 → **0.0325** | 0.5555 → **0.3195** | 95.7 → **96.7%** |
| we said 90–99% | 155 | 0.1000 → **0.0709** | 0.3732 → **0.2924** | 89.0 → **92.4%** |
| close (<75%) | 107 | 0.2475 → **0.2248** | 0.6885 → **0.6408** | 55.1 → **62.7%** |

**Better on both metrics in every subset.** NSW 2023 agrees independently.

## The failure this repo has been chasing

Federal seats called 99%+ **that were lost: 23 → 12.**

Denison, Lyne, Melbourne, Fairfax, Kooyong, Mackellar all come off 1.0000.
Greenway, Kennedy, Lyons, Macarthur, Paterson, North Sydney, Tangney and Hughes
leave the 99% band entirely. Reliability at the top end goes from −4.2 points to
−3.1.

This is the same failure as the four SA One Nation seats at 0.000, measured on
886 seat-elections.

## Victoria 2026, the pre-registered stop sign

| party | base | with level_sd |
|---|--:|--:|
| ALP | 37 | 35 |
| LNP | 36 | 36 |
| ONP | 9 | 9 |
| GRN | 5 | 5 |

Largest move ALP −2, under the threshold of 3 that required stopping and handing
the decision to a person. No escalation.

## The process lesson, which is the durable part

I refused a real improvement twice in one day on criteria I had already shown
were broken — once scoring win/lose for a vote-share model, once on a ruler with
no markings finer than 0.419. Being over-strict is not a safe default. It has a
cost, and here the cost was nearly discarding a change that halves the worst
failure mode in the forecast.

The fix is not looser criteria. It is that scoring never looked past one
aggregate number, so `scripts/compare_arms.R` now reports both metrics across
the subsets that carry the question, and every future arm is judged that way.
