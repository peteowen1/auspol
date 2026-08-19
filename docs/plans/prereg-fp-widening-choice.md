# Pre-registration: WHICH widening factor, and does it get adopted?

Written 2026-08-19, **before the comparison is run**. Committed before running.

Addendum to [prereg-fp-interval-coverage.md](prereg-fp-interval-coverage.md),
whose decision rule has already fired: first-preference coverage is **69.8% at a
nominal 95%** over 139 party-cycles, well below the 90% floor, so that plan says
to test a widening and adopt only if it brings coverage to nominal.

This addendum exists because that plan named a specific factor and a second
candidate now exists. Choosing between them after seeing both is exactly the
move the refusal sections are here to stop, so the rule goes in first.

## The two candidates

| | value | where it comes from |
|---|---:|---|
| **A — pre-registered (R3)** | **2.419** | the two-party projection error already measured and used by `project_result()`, borrowed unchanged |
| **B — measured on FP residuals** | **2.127** | maximum likelihood for tau in `err ~ N(0, sd_post^2 + tau^2)`, over the 139 party-cycles, leave-one-cycle-out |

They are close, which is itself worth stating: the FP poll-to-result error and
the TPP projection error are different quantities and there is no principle
saying they must agree. That they land within 0.3 points is evidence about the
size of the missing variance, not proof either is the right object.

## The rule, fixed now

**A is the default and wins ties.** It is what was pre-registered, it is
measured on data other than the residuals it is being applied to, and it cannot
be accused of being fitted to the test.

Adopt **A** if, on held-out coverage:

1. all three levels (50%, 80%, 95%) are within **5 points** of nominal; and
2. no party class with **n >= 20** exceeds nominal by more than 5 points
   (R2, restricted to classes large enough to measure -- with n = 1 to 5,
   100% coverage is uninformative and the original R2 did not say so).

**Only if A fails one of those** does B get considered, on the same two tests.
Adopting B is a **deviation from R3** and must be recorded as one in the review,
with the reason A failed stated in numbers.

If **both** fail, adopt neither and report that the missing variance is not a
constant in points.

## Refusal section — what would disqualify an apparent win

- **F1 -- no adoption on pooled coverage alone.** If pooled coverage lands on
  nominal while ALP or OTH (the two classes with n = 33) stay below 90%, the
  correction is moving the average by over-covering small classes. Report the
  per-class table with the headline, always.
- **F2 -- a level-band skew disqualifies a constant.** The correction is
  constant in points, so if coverage after widening differs by more than 10
  points between the (0,10] band and the (30,100] band, a constant is the wrong
  shape and neither factor should be adopted on that basis.
- **F3 -- the seat model must not be the reason.** Wider primary bands flow into
  the candidate-level seat model and will widen One Nation's seat range toward
  AE Forecasts'. That consequence is **not evidence** and must not appear in the
  adoption argument. If the coverage case fails, the fact that adopting anyway
  would improve agreement with AE is not a reason to adopt.
- **F4 -- a directional side effect that would disqualify a winner.** Widening
  every party's band symmetrically must not systematically move any party's
  **central** estimate or its win probability in a consistent direction. The
  share-to-seat map is convex, so extra variance raises a low party's seat
  expectation. If One Nation's expected seats rise by more than 1.0 on a change
  that is supposed to be about uncertainty only, stop and report it rather than
  shipping it as a calibration fix. This is the side effect the last three
  experiments each found late.

## What these criteria cannot see

- **Whether the central estimates are right.** This is interval width. Our One
  Nation Victorian primary of 20.7 being wrong is untouched by a wider band
  around it.
- **The live horizon.** Coverage is measured at the cycle endpoint where polls
  are densest; the published Victorian band is 101 days out. Whatever is adopted
  is calibrated at the endpoint and that limit must be stated on the page, not
  implied away.
- **Whether the trend posterior itself is the problem.** Both candidates add
  variance on top of the posterior rather than fixing it. If the posterior is
  over-confident for a structural reason, this papers over it.
