# v3: three mechanisms clearly beat one, still are not adopted, and the binding constraint is sample size

Run 2026-08-20 against
[../plans/prereg-independent-two-mechanism.md](../plans/prereg-independent-two-mechanism.md),
committed before anything was fitted.

**Verdict: KEEP ARM A. Not adopted — the Brier improvement is 1.46 SE against a
2 SE bar.**

**But H3 does NOT fire, and the script said it did.** See the correction below.

## The three rounds side by side

| | A (published) | v1 | v2 | **v3** | S (control) |
|---|---:|---:|---:|---:|---:|
| accuracy | 71/88 | 74/88 | 74/88 | **74/88** | 71/88 |
| Brier | 0.1471 | 0.1280 | 0.1282 | **0.1201** | 0.1409 |
| log score | 0.856 | 0.407 | 0.408 | **0.487** | 0.703 |
| **calibration slope** | 0.586 | 0.632 | 0.627 | **0.974** | 1.441 |
| B vs A | — | 1.03 SE | 1.01 SE | **1.46 SE** | — |
| B vs control (E1) | — | 0.66 SE | 0.65 SE | **1.06 SE** | — |

Splitting the independent vote into **recontest**, **incumbent** and
**emergence** did what two rounds of fiddling with one distribution could not:
the calibration slope moves from **0.586 to 0.974**, which is as close to
calibrated as this model has ever been, and both margins improve by roughly half
again.

## A correction to my own script

`scripts/score_independent_two_mechanism.R` printed:

> *v3 reaches 1.46 SE and 1.06 SE. Does NOT clear the bar — per H3 this line of
> work stops.*

**The second half of that is wrong**, and the code was wrong, not the plan. It
tested `abs(bA) > 2` — the **adoption** rule — and labelled the result H3.

H3 says something different: stop **if the margins are not clearly better than
v2's** 1.01 SE and 0.65 SE. They are clearly better — 1.46 and 1.06. So H3's
stop condition is **not met**. Splitting the mechanisms helped, which is exactly
what H3 was written to detect.

Two separate conclusions, and conflating them nearly ended a line of work that
the evidence supports:

- **Adoption: no.** 1.46 SE does not clear 2 SE, and the model stays as it is.
- **Continuation: yes.** H3 does not fire.

## Route 1 is the part that worked, and it was fitted, not assumed

Nine seats routed as sitting independents, 79 as emergence.

- **Recontest rate 8 of 9 = 0.889**, Jeffreys 95% interval **0.586 to 0.988**.
  Nine seats is very little and the interval says so.
- **`log1p(next) = 0.203 + 0.925 × log1p(previous)`**, slope **0.925 ± 0.281**,
  which is **0.27 SE from 1**.

That last number is the point of H1. "Next ≈ previous" was the hypothesis, not an
assumption, and the data supports it. Both earlier rounds forced a linear term to
do this job and it could not: v2 predicted Sydney at 20% against an actual 41%.

## G1 still fails, and by much less

| seat | previous IND | A | v2 | **v3** |
|---|---:|---:|---:|---:|
| Wagga Wagga | 46.1 | 1.000 | 0.524 | **0.831** |
| Sydney | 41.4 | 0.999 | 0.410 | **0.722** |
| Lake Macquarie | 53.5 | 1.000 | 0.597 | **0.655** |
| Wollondilly | 20.1 | 0.259 | — | 0.183 |

Three of four sit below the 0.80 bar, so **G1 fails**. But the failure has
shrunk from catastrophic to marginal, and the remaining gap is the recontest
term doing its job: an 11% chance the independent does not stand caps how
confident the model can be, and that rate is estimated from **one** non-recontest
in nine seats.

Wollondilly is a separate matter — arm A already gave it 0.259, so the model was
never confident there and v3 does not make it worse in any meaningful way.

## What is actually binding

**Not the idea. The sample.**

Every number above rests on 88 seats, 9 sitting independents, 1 non-recontest,
and one unusually independent-friendly election. A 1.46 SE effect on 88 seats is
exactly what a real effect looks like when there is not enough data to prove it,
and the pre-registered bar correctly refuses to adopt on that.

**Today the federal corpus arrived**: seven AEC elections, **1,052
division-elections**, six consecutive pairs, including 2022 — the teal wave, and
the richest set of emergent independents in Australian electoral history. That
is roughly twelve times the seats and vastly more than twelve times the
independent contests.

If the effect measured here is real, the same test on that corpus resolves it
decisively in either direction. If it is noise, that will show too.

**Recommendation: do not adopt, do not stop.** Re-run all three rounds on the
federal data before drawing any conclusion about the idea itself.

## Two cautions for that re-run

- **Voting systems do not mix.** Federal is full preferential — the 2022
  distribution has **zero** exhausted ballots. NSW is optional preferential and
  exhausts about 12%. Victoria is full preferential, so the federal matrices are
  system-compatible with it and the NSW ones are not. Pooling them would be a
  real error.
- **Redistributions.** Divisions run 150 → 151 → 150 across these elections with
  boundary changes, so consecutive pairs are not cleanly matched without notional
  previous results on new boundaries. Without those, a redistributed division
  will look like an enormous swing.
