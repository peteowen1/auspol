# The seat model is badly over-confident, and the fix is a knob rather than a better model

Run against [../plans/prereg-calibration.md](../plans/prereg-calibration.md),
committed before anything was fitted.

**Verdict per the rule: SHIP C.** A one-parameter rescale of the output beats
both the status quo and the model change. The pre-registration anticipated this
and named the consequence in advance: *"If C beats B, ship C and say plainly
that the fix is output rescaling, not a better model."*

## The defect

Calibration slope below 1 in **9 of the 10** elections now measured — federal
0.183 to 0.441, NSW 0.541, South Australia 0.299, Victoria 2018 0.512 — with
Victoria 2018 to 2022 at 2.515 the sole exception.

**A seat the published model calls at 95% should be about 70%.**

This was invisible until today. The corpus went from 166 seats across 2
elections to **1,187 across 10**, and the six federal pairs that carry most of
the evidence had never been scored against this model at all.

## The result

Leave-one-election-out log score, clustered on the election, 9 degrees of
freedom:

| comparison | mean | SE | |
|---|---:|---:|---:|
| **C beats A** — temperature vs status quo | +0.2363 | 0.0829 | **+2.85 SE** |
| **B beats A** — wider seat spread vs status quo | +0.1899 | 0.0829 | **+2.29 SE** |
| **B beats C** | −0.0465 | 0.0174 | **−2.67 SE** |

Both fixes clear 2 SE against the status quo. **C beats B by 2.67 SE**, so B is
not adopted.

Pooled log score falls from **0.5631 to 0.3680**, a 35% improvement, on a
temperature stable at **0.30 to 0.35** across all ten folds.

## Why the knob wins, which is not what I expected

Arm B wins on exactly **two** elections and loses on the other eight:

| | B vs C |
|---|---:|
| sa2026 | **+0.0312** |
| vic2022 | **+0.0189** |
| the other eight | −0.0101 to −0.1306 |

Those two are the unusual ones. South Australia is the One Nation surge, where
the model genuinely lacks the spread to represent what happened. Victoria 2018
to 2022 is the one **under**-confident election, where widening is right for the
opposite reason to everywhere else.

On ordinary elections, widening the simulation blunts discrimination — it moves
seats the model was right about as well as seats it was wrong about. Temperature
cannot do that: it never changes which party is top, so accuracy is untouched by
construction, and it only flattens the confidence.

**Arm C is the better fix precisely because it is dumber.** The over-confidence
is not a missing source of uncertainty in the simulation; it is a systematic
mis-scaling of the output.

## Refusals

- **K1 — accuracy.** A 87.3%, B 86.9%. Within the 1-point bar; and C leaves
  accuracy exactly unchanged, since temperature preserves the argmax.
- **K2 — parameter stability.** The multiplier is 2.5 in all ten folds; the
  temperature spans 0.30 to 0.35, a factor of 1.17 against a bar of 2.
- **K3 — no single election carries it.** Dropping any one leaves C between
  +2.44 and +3.13 SE.
- **K4 — vic2022 is not the mechanism.** It is the one under-confident election,
  so it flatters widening. Dropping it makes C's win over B **stronger**, at
  −3.04 SE.
- **K6 — decided on log score, not slope.** The slope is the symptom and is
  reported only as such.

**K5 is NOT yet satisfied and blocks shipping.** See below.

## What stands between this and shipping

**Temperature rescales per-seat probabilities. It does not rescale the
seat-count histogram**, which is drawn from the simulation and published beside
the pendulum on the same page. Applying C as measured would leave the seat
probabilities saying one thing and the seat total another.

Three ways out, none yet tested:

1. Rescale the per-seat probabilities and **re-derive the histogram** from them,
   which needs an assumption about correlation between seats that the simulation
   currently supplies.
2. Apply the temperature **inside** the simulation, as a shrink on each seat's
   per-draw outcome, so both come from one place.
3. Publish only what is calibrated, and say the histogram is not.

**K5 also requires reporting the effect on the Victoria 2026 seat medians before
anything ships**, and that cannot be read off this test — it needs the change
implemented in `fit_seats_full.R`.

So the measurement is done and the fix is chosen; the implementation is separate
work with its own risk, and the model is unchanged until it is done.

## Two plumbing failures, both caught, both worth recording

This test produced a byte-identical comparison **twice**, each time reporting a
difference of exactly `0.0000` and reading as a clean null.

1. The harnesses wrote to a fixed filename, so a sweep **overwrote the baseline
   it was being compared against**. Six federal elections read +0.0000.
2. Fixing that changed where non-default runs wrote, and the copy commands still
   fetched the old name — so six of twelve grid files were **stale copies of the
   baseline**, with the runs themselves having succeeded.

The second is the more instructive: the fix for the first *caused* it, and every
run reported success. What caught it was comparing **md5 digests** of the grid
files rather than their log scores — two arms can coincide on a summary
statistic, but not byte for byte. That check is now in `test_calibration.R` and
aborts the run.
