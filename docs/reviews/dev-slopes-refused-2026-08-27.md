# Deviation slopes refused: right about vote share, wrong about seats

2026-08-27. Measured on all five harnesses per the fix-everywhere rule.

**The slopes stay at 1.000. They do not ship.**

This is the strongest single piece of statistical evidence produced in the
session, and it fails on the thing that actually ships. Both halves are worth
keeping.

## The evidence FOR, which is not in doubt

Uniform swing asserts a seat's deviation from the statewide mean carries forward
intact — a slope of exactly 1. Estimated across 17 election pairs, **held out by
region** so no election contributes to the slope used to predict it, that is
rejected for every class in every region:

| class | slope range across held-out fits | t vs 1 |
|---|---|---|
| OTH | 0.148 – 0.281 | −22.0 to −30.3 |
| ONP | 0.515 – 0.601 | −8.9 to −18.2 |
| OTH_RIGHT | 0.482 – 0.708 | −13.6 to −22.5 |
| IND | 0.519 – 0.708 | −11.4 to −18.6 |
| LNP | 0.846 – 0.877 | −7.6 to −11.5 |
| ALP | 0.884 – 0.908 | −6.5 to −9.4 |
| GRN | 0.879 – 0.958 | −3.3 to −6.7 |

Nothing below disputes this. **Uniform swing is wrong about vote share.**

## The measurement, on what ships

| harness | clusters | Brier | accuracy | calibration slope |
|---|--:|---|---|---|
| VIC | 2 pairs, 166 | 0.0884 → **0.0830** | 87.3 → **89.2%** | vic2018 0.506→0.415 / vic2022 **2.515→1.065** |
| NSW | 1 pair, 88 | 0.1468 → **0.1396** | 80.7 → **81.8%** | **0.541 → 0.742** |
| SA | 1 pair, 47 | 0.1530 → 0.1606 | 80.9 → 80.9% | 0.297 → 0.266 |
| WA | 7 pairs, 361 | 0.1027 → 0.1041 | 87.3 → **85.0%** | 4 pairs better, 2 worse |
| fed2010 | 147 | 0.0938 → 0.0973 | 87.1 → 86.4% | **0.252 → 0.336** |
| fed2013 | 150 | 0.1088 → **0.1059** | 83.3 → **84.7%** | **0.289 → 0.345** |
| fed2016 | 147 | 0.1033 → 0.1069 | 85.7 → 85.7% | 0.377 → 0.277 |
| fed2022 | 150 | 0.1163 → 0.1375 | 86.7 → 84.0% | **0.181 → 0.237** |

**Brier: better in 3, worse in 5. Accuracy: better in 3, worse in 3, flat in 2.
Calibration: better in roughly two thirds.**

## The pattern, and why it is not a contradiction

The split is consistent and it has a name. **Shrinking a seat's deviation makes
every prediction less extreme.** That trades sharpness for calibration:

- **Calibration improves**, because the model was overconfident nearly
  everywhere — federal slopes of 0.18–0.38 mean probabilities pushed toward 0
  and 1 far harder than results justified. Less extreme predictions fix that.
- **Brier and accuracy degrade**, because both reward being confident *and*
  right, and the model gives up confidence it was partly entitled to.

Where the base was already *under*confident — wa2005 at 1.426, wa2017 at 1.400 —
the slopes push further the wrong way (to 2.795 and 1.937). The one prediction
made in advance here was that calibration would improve wherever the base slope
sat below 1; **fed2016 broke it** (0.377 → 0.277), so the mechanism is real but
not universal.

## Why the vote-share win does not transfer

Two reasons, and the second is the useful one.

1. **A per-class slope is monotone within its class.** It rescales every seat's
   deviation by the same factor, so it barely reorders which seats a class wins.
   Seat accuracy depends mostly on that ordering. The change moves *levels*, not
   *ranks*, so it cannot buy much discrimination.
2. **`party_sd`, `seat_sd` and `shrink` were all fitted with uniform swing's
   bias present.** They absorbed part of it. Moving the point estimate without
   retuning the spread breaks a compensation that was doing real work — which is
   why a demonstrably better point estimate produces a worse forecast.

That makes this a **joint** problem, not a dead end. The next experiment is to
retune the spread parameters *with* the slopes rather than testing the slopes
against a spread tuned for their absence. That has to be pre-registered, and its
criterion must name Brier and calibration separately, because this measurement
shows they move in opposite directions and a single headline number would hide
exactly that.

## What was nearly shipped, and why it wasn't

The pooled vote-share evidence was overwhelming and I recommended shipping on it
before any harness had run. Had the deviation slopes gone in on that basis, the
published Victorian forecast would have lost accuracy on 5 of 8 measured
election-pairs. **The fix-everywhere rule is the only reason this was caught**,
and SA — the smallest and least powerful harness — was the first to say no.

## Also corrected

`CLAUDE.md` states WA "carries seven pairs at ~58 seats, which is more election
clusters than the other four combined". The federal harness now runs 6 pairs
over ~880 seat-elections against WA's 361, so that guidance is stale and the
preference it expresses should be re-read.
