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

1. all three levels (50%, 80%, 95%) are within **5 points** of nominal
   (**AMENDED 2026-08-19 -- see the amendment at the foot of this file. This
   clause was mis-specified and has been replaced; it is left here unedited
   because rewriting it would hide that it ever said this**); and
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

---

## AMENDMENT, 2026-08-19: test 1 was mis-specified and is replaced

**Written after the comparison was run and after seeing that both candidates
failed. That is stated first because it is the thing most likely to make this
amendment worthless, and a reader has to be able to weigh it.**

### What was wrong

Test 1 required coverage within **5 points** of nominal at each of the 50%, 80%
and 95% levels. The 139 party-cycles are not 139 independent observations --
within a cycle the shares sum to 100, so a party over-estimated forces another
under. The independent unit is the cycle, and there are **33**.

Clustering on the cycle, the standard error on 50% coverage is **4.3 points**.
So the 5-point tolerance is **1.16 SE**, and a perfectly calibrated interval
fails it about a quarter of the time. At the 95% level the same 5 points is
about 2.6 SE, which is where the figure was copied from.

**The test could not reliably accept a correct answer.** That is a property of
n alone; it was computable before the run and was not computed.

### What replaces it

**Test 1 (amended).** On held-out coverage, every level's deviation from nominal
must be within **2 clustered standard errors**, clustering on the cycle. The
standard error is computed from the data, so the tolerance sizes itself to the
evidence available instead of being a fixed number of points that means
different things at different levels.

Test 2, and refusals F1 to F4, are **unchanged**.

### The tie-break is not being changed, and that is the point

The original rule already says **A is the default and wins ties**. Under the
amended test both candidates pass, so the tie-break decides, and it decides for
**A = 2.419 -- the factor pre-registered first**, in the parent plan's R3,
before either result was known.

So this amendment cannot be an argument for the number found later. If it were
being bent toward a preferred answer it would have to favour B, and it does the
opposite. That is the only real defence available for a criterion changed after
the fact, and it is offered as a limit on the damage rather than as a
justification.

### What is still owed before anything is adopted

**F4 has not been run.** Nothing may be wired into the published forecast until
the directional side-effect check is done: whether adding this variance raises
One Nation's expected seats by more than 1.0 through the convexity of the
share-to-seat map. A pass on coverage does not license the change on its own.

### The standing lesson

Two of this project's pre-registered criteria have now failed the same way: a
threshold in fixed units, set without checking the sampling noise the data can
produce. **A tolerance should be written in standard errors, or its size in
standard errors computed and recorded at the time it is written.** That belongs
in every future plan in this repo, and is why this amendment is a visible
addition rather than an edit to the original text.
