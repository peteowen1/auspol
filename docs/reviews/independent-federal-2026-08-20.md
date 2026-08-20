# The federal corpus reverses the result: the independent model makes the forecast WORSE

Run 2026-08-20 against
[../plans/prereg-independent-federal.md](../plans/prereg-independent-federal.md),
committed before anything was refitted.

**Verdict: REFUSE. Arm B is 2.52 SE WORSE than the published model on 886
division-pairs.** The line of work stops.

## What happened

Three rounds on 88 NSW seats read as a near-miss that kept improving:

| | v1 | v2 | v3 |
|---|---:|---:|---:|
| Brier vs A | 1.03 SE better | 1.01 SE better | **1.46 SE better** |
| calibration slope | 0.632 | 0.627 | **0.974** |

On six federal pairs, with the identical model and every parameter fitted
leave-one-election-out:

| arm | n | accuracy | **Brier** | log score | slope |
|---|---:|---:|---:|---:|---:|
| **A — as published** | 886 | **0.8804** | **0.0932** | 0.5444 | 0.260 |
| B — three mechanisms | 886 | 0.8691 | 0.0986 | 0.4782 | 0.353 |
| S — temperature control | 886 | 0.8804 | 0.1059 | **0.3685** | 0.206 |

| comparison | Brier |
|---|---:|
| **B vs A** | **+0.0054, 2.52 SE — B is WORSE** |
| S vs A | +0.0127, 4.11 SE — S is worse |
| B vs S | −0.0072, 2.14 SE — B beats the control |

The effect **changed sign**. At 88 seats it looked like a 1.46 SE improvement;
at 886 it is a 2.52 SE degradation. Arm B is also worse on winner accuracy, by
ten divisions.

**This is what the 2 SE bar existed for.** Had v3 been adopted on its
"promising" margin, the published forecast would have got worse, and the NSW
backtest would have said it got better.

## A bug in my own verdict, and it said the opposite

`scripts/score_independent_federal.R` printed **"adoption: 2.52 SE -> ADOPT"**.

`pair_se("A", "B")` returns `B − A`, so a **positive** value means arm B has the
higher Brier and is worse. The verdict line tested `abs(bA) > 2` and dropped the
sign — announcing adoption for a change that degrades the forecast.

That is the second sign-or-label error in this line of work: v3's script called
the adoption test "H3". Both were caught by reading the underlying numbers
rather than the verdict line. Fixed, with the sign requirement stated in the
code.

## Brier and log score disagree completely, and the plan chose in advance

| | best | middle | worst |
|---|---|---|---|
| **Brier** (the pre-registered metric) | **A** | B | S |
| log score | S | B | **A** |
| accuracy | A and S | | B |

Log score punishes confident misses hardest, and every arm that spreads
probability improves it. Brier rewards confidence when the model is mostly
right, and at 88% accuracy that reward dominates.

**Brier was fixed as the decision metric in v1 and never changed**, so the
verdict follows it. But the divergence is the real finding: *"is the model
overconfident"* and *"does making it less confident help"* have opposite answers
here, and which one matters depends on what the forecast is for. A seat count
wants accuracy and Brier; a probability quoted for one seat wants the log score.

Worth stating plainly: **the temperature control has the best log score of the
three and the worst Brier**, so "just make it less confident" is not a free win
either.

## What the fits found, which stands regardless

The parameters are far better measured than at 88 seats, and they say two
different things.

**The recontest rate is solid.** 35 of 41 sitting independents stood again,
**0.854**, Jeffreys 95% **0.723–0.937**, and it barely moves across held-out
elections (0.838 to 0.889). NSW's 8-of-9 was luckily close to right.

**Route 1's slope is not.** Pooled it is **0.599 ± 0.222** — regression toward
the mean, not the identity NSW suggested at 0.925. But per election it swings
between **1.438** (2019→2022, the teal surge) and **0.483** (2022→2025, the
consolidation), and leave-one-election-out it ranges **0.279 to 1.007**. J1
required this be reported rather than a pooled number quoted as settled: an
independent's next vote relative to their last depends on the electoral
environment more than on the seat.

**J2 fires.** Dropping 2019→2022 moves the pooled slope from 0.599 to **0.279**.
One election drives half the estimate.

**One thing the small sample could not see.** Route 2's tail: NSW estimated
**13,497** degrees of freedom — effectively normal. Federal estimates **7.3**,
genuinely heavy-tailed. The fat tail the anchor assumes is real, and 88 seats
simply could not detect it. That is an argument about sample size, not about
their parameters, and we now have our own number.

## Why it fails, as far as this can tell

Independents won 2, 4, 2, 2, 3, 10 and 10 seats across these elections — **1.9%
to 6.6% of divisions**. The model adds independent probability mass to *every*
division routed through emergence, 845 of 886. Spreading a few points of
probability across hundreds of seats to catch a handful costs more in the seats
it is wrong about than it gains in the ones it is right about, on a metric that
rewards confidence.

The NSW sample had independents winning **10%** of seats — the highest rate in
the corpus — which is why the same model looked like it was working there.

## What stops and what does not

**Stops:** this model. Three structures, four pre-registrations, and the
decisive test says it makes things worse. Per H3 and the decision rule, it is
not adopted and is not iterated further.

**Does not stop:** the underlying defect is real and unaddressed. The published
model still cannot elect a new independent, still assigns 0.000 to seats they
win, and its calibration slope on federal data is **0.260**. What this rules out
is fixing it by spraying probability across every seat. What the anchor does
instead — a **named list of confirmed independents**, plus seat polls and
market odds — is exogenous information, and refusal E4 kept it out of this work
deliberately. On this evidence that exclusion is why the work failed, and the
next attempt should be the exogenous one.
