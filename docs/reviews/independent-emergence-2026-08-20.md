# Independent emergence: NOT ADOPTED. It fixes the defect it was built for and breaks something else.

Run 2026-08-20 against
[../plans/prereg-independent-emergence.md](../plans/prereg-independent-emergence.md),
committed before anything was fitted. `scripts/fit_independent_emergence.R`,
`scripts/score_independent_emergence.R`.

**Verdict: KEEP ARM A. Nothing changed in the published model.**

## What was built, and what was not borrowed

The idea — that an independent can appear where none stood, and that the chance
is predictable from seat characteristics — is taken from the model this repo is
anchored on. **No number is.** Not a rate, not a coefficient, not a seat-type
modifier, and not their 7.7% emergence threshold, which an early draft of the
plan did adopt and which was removed before anything ran.

There is no threshold at all: a binary "emerged" event needs a cutoff and every
cutoff is a hand-set parameter, borrowed or tuned. The independent vote share is
modelled directly as a continuous outcome instead.

Their seat-type taxonomy was rejected on its own merits as well as on
provenance: NSW carries 12 region labels and Victoria 14, they are not the same
taxonomy, and a coefficient fitted on one cannot be applied to the other —
which is the whole point, since Victoria is where this has to work.

**Our four features, fitted on NSW 2019 → 2023:**

| term | location | log-spread |
|---|---:|---:|
| previous non-major vote | +0.0686 | −0.0162 |
| independent vote last time | −0.0007 | +0.0202 |
| margin | +0.0114 | +0.0086 |
| **Coalition-held** | **+0.5391** | +0.2402 |

The predictive distribution is well calibrated on its own terms: PIT mean 0.493
against 0.500, sd 0.309 against 0.289, KS p = 0.285.

**And it disagrees with the model it was inspired by, which is the point of
fitting it ourselves.** That model draws the emergent vote fat-tailed, at
kurtosis 3.76. Our estimated degrees of freedom came out at **13,497 —
effectively normal.** Modelling the share on a `log1p` scale already absorbs the
skew, so no extra tail weight is warranted. Copying their number would have
carried a tail our data does not support.

## The result

| arm | accuracy | Brier | log score | slope |
|---|---:|---:|---:|---:|
| **A** — as published | 71/88 (80.7%) | 0.1471 | 0.856 | 0.586 |
| **B** — with emergence | **74/88 (84.1%)** | **0.1280** | **0.407** | 0.632 |
| **S** — dumb temperature (E1 control) | 71/88 | 0.1409 | 0.703 | **1.441** |

Against the pre-registered rule — Brier improvement over **2 SE** of the paired
per-seat difference, **and** clearing E1:

| comparison | Brier | log score |
|---|---:|---:|
| B vs A | −0.0190 (**1.03 SE**) | −0.449 (2.00 SE) |
| S vs A | −0.0062 (0.59 SE) | −0.154 (1.60 SE) |
| **B vs S** (E1) | −0.0129 (**0.66 SE**) | −0.295 (1.66 SE) |

**B fails the main criterion at 1.03 SE and fails E1 at 0.66 SE. Not adopted.**

The dumb temperature is not an alternative either: it reaches a slope of 1.441,
overshooting past calibrated into underconfident, which the plan says to report
and not adopt for. It buys its calibration by making everything mushy.

## It does fix the defect it was built for

The five seats arm A missed worst — all won by independents:

| seat | actual | A | **B** |
|---|---|---:|---:|
| Orange | IND | 0.000 | **0.983** |
| Murray | IND | 0.000 | **0.573** |
| Barwon | IND | 0.003 | **0.421** |
| Wakehurst | IND | 0.000 | 0.041 |
| Kiama | IND | 0.000 | 0.013 |

Seats where the eventual winner was given under 5% fall from **5 to 3**, winner
accuracy rises by three seats, and the log score more than halves. On the exact
failure the model was built to address, it works.

## And it breaks something the plan did not anticipate

| seat | actual | A | B |
|---|---|---:|---:|
| Sydney | IND | 0.999 | **0.410** |
| Wagga Wagga | IND | 1.000 | **0.524** |
| Lake Macquarie | IND | 1.000 | **0.597** |
| Tamworth | LNP | 0.997 | 0.605 |

These are seats an **incumbent independent already held and comfortably won**.
Arm B throws away that knowledge.

The cause is in the fitted coefficients, visible above: `ind_prev` has a location
coefficient of **−0.0007**, essentially zero. It is collinear with
`nonmajor_prev`, which already contains it, so the fit put all the weight on the
aggregate. The model therefore cannot distinguish **"20% non-major spread across
minor parties"** from **"20% to a sitting independent"** — and arm B *replaces*
each seat's projected independent share with a draw, so a sitting independent on
45% is overwritten by a draw centred near the seat's aggregate.

That is a defect in the **feature set**, not in the idea. Two collinear features
were pre-registered together and the fit resolved the collinearity by discarding
the one that mattered for incumbents.

## What follows

The obvious repair — apply the draw only where no independent already stands, or
model the *change* rather than the level — is **not made here.** E3 forbids
changing the structure after seeing the scores, and the structure was fixed in
advance precisely so this could not be tuned into a win. It needs its own
pre-registration, with the collinearity resolved before fitting rather than
after.

Two things are worth carrying forward regardless:

- **The tail is not fat**, on our data and on a `log1p` scale. Whatever the next
  version looks like, it should not assume otherwise.
- **The temperature control did its job.** Arm B beats it by only 0.66 SE on
  Brier, which is exactly why E1 was written. Without that arm, a 13% Brier
  improvement and a halved log score would have looked like a clear win, and most
  of it is just an overconfident model being made less confident.

## One bug, caught by absurdity rather than by a guard

The first scoring run gave independents probability 1.000 in every seat and 10%
accuracy. The features were built from the raw vote table rather than shares, so
`nonmajor_prev` went in at ~30,000 instead of ~15 and every seat pinned to the
80% cap.

It was obvious only because the result was ridiculous. **A unit error one tenth
the size would have produced a plausible wrong answer**, and nothing in the
pipeline would have objected. The scoring script now asserts the shares are on a
0–100 scale and prints the median, p90 and cap count of the first draw, so the
distribution has to be looked at before the score is read.
