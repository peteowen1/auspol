# Pre-registration: stop excluding losing defectors; pool the two rates instead

Written 2026-09-09, **before any arm is scored**. Committed before running.
First application of the `CLAUDE.md` rule "fit constants with SHRINKAGE,
never a hard cliff", which Pete set the same day.

## The defect, and a correction to a comment written today

`personal_prior_vote(major_discount = ...)` gives a personal-vote floor to a
**sitting member** who defects to a minor party, and gives a **losing**
major-party candidate who does the same thing **nothing at all** — they fall
back to the class-level base, usually near zero. The exclusion is enforced by
`PREVT$elected %in% TRUE` in the DEF branch.

A comment added to that branch earlier today justified the exclusion:

> "the non-member analogue of this discount has 5 corpus cases, mean
> retention 2.32 and sd 4.38 -- noise, not a usable rate"

**Both halves of that are wrong**, checked against the corpus 2026-09-09:

- It is **13 cases, not 5** (12 after restricting to a prior vote ≥ 10%).
- The mean 1.08 is destroyed by a single case: **Preece, Schubert sa2026,
  2.1% → 21.7%, ratio 10.14**. A retention *ratio* with a 2.1% denominator
  is meaningless — the same small-denominator trap that put qld2017 One
  Nation at 20.8% instead of 13.7% earlier the same day.
- The **median is 0.142**, which is both usable and intuitive: a losing
  candidate carries about half what a sitting member does (0.282).

So the model currently assigns **zero** personal vote to a class of candidate
the data says retains about 15%.

## The two rates are NOT distinguishable

| group | n (prior ≥ 10%) | median | mean | se |
|---|--:|--:|--:|--:|
| sitting member | 17 | 0.282 | 0.351 | 0.056 |
| losing candidate | 12 | 0.142 | 0.326 | 0.114 |

Wilcoxon rank-sum on the raw ratios: **W = 131, p = 0.408**. The gap looks
large and is within noise at this n.

Partial pooling of the two group rates (`w = tau^2/(tau^2 + se^2)`):

| group | own estimate | weight | **pooled** |
|---|--:|--:|--:|
| sitting member | 0.282 | 0.366 | **0.265** |
| losing candidate | 0.142 | 0.121 | **0.241** |

The losing-candidate weight is 0.12, so pooling pulls it almost entirely to
the grand mean. **The data supports one rate, not two** — which is exactly
what shrinkage is for, and is the opposite of both the current hard
exclusion and a naive two-rate split.

## The arm

**One pooled rate for every major-party defector, member or not.** The
`elected %in% TRUE` filter is removed from the DEF branch and
`fit_defector_discount()` fits over all defector cases with a prior vote
≥ 10%, returning the pooled median.

The `prior >= 10` floor is stated here and not chosen later: it exists to
stop a ratio being computed on a denominator too small to mean anything
(Preece at 2.1%), and it removes exactly one case from each group.

Behind `AUSPOL_DEFECT_POOLED` (default `0` = today's behaviour), added to
`scripts/published_flags.R` in the same commit.

**This changes shipped behaviour if adopted** — `AUSPOL_DEFECT_DISCOUNT=1`
is a published default — so it is measured, not assumed.

## The test set, named in advance

`output/defector-cases-all.csv`, frozen before this plan was committed:
**29 seat-class cells** (17 sitting-member, 12 losing), across the 22 pairs.
The 12 losing cells are the ones that move from a zero floor to a fitted
one; the 17 member cells move slightly (0.282 → ~0.25).

## Primary metric

**Targeted change**, so per `CLAUDE.md`'s targeted-vs-general table the named
cases are primary: **seat-share RMSE on those 29 cells**, paired, clustered
on the election pairs they fall in.

Election-wide pooled seat log loss is the secondary panel, NOT the primary —
29 cells in 2,050 seat-elections would need ~70x the effect to clear an
aggregate bar, which is the mistake the salience gate's pre-registration made
and `CLAUDE.md` records.

MDE will be computed from the paired sd and reported; if it exceeds the
observed effect the finding is "could not resolve", not a pass.

## Decision rule, fixed now

Pete's majority rule, as used for the two arms refused earlier today.

**Ship if BOTH:**

1. Share RMSE on the 29 named cells improves at ≥ 2.08 clustered SE.
2. Of the 10-metric panel (pooled log loss; pooled Brier; pooled share RMSE;
   per-jurisdiction log loss for fed/nsw/qld/sa/vic/wa; floor-seat count),
   **≥ 6 better and ≤ 3 worse**, |Δ| < 0.0005 counting as unchanged.

**Catastrophic-break floor:** refuse if any jurisdiction's log loss degrades
by more than 0.02, or pooled by more than 0.01.

## Refusal: what would make an apparent WIN unacceptable

- **R1 — it must not be carried by the member cells.** The point of the arm
  is the 12 losing cells that currently get zero. Report the two groups
  separately; if the member cells (which only move 0.282 → 0.25) carry the
  gain, this is a re-tuning of the existing rate wearing the disguise of a
  new mechanism, and should be tested as that instead.
- **R2 — Preece must not come back through a side door.** The `prior >= 10`
  floor excludes him. If the result depends on that floor's exact value,
  report the sensitivity at 5% and 15% rather than shipping on 10%.
- **R3 — no seat may be won on a floor alone.** If any seat's winner changes
  solely because a losing defector now carries 24% of a prior major vote,
  name it. A model that elects someone off a shrunk constant with no other
  supporting signal is doing something this repo has refused before.
- **R4 — Victoria's published seat totals must not move by more than 2 for
  any class**, or it escalates rather than shipping as a side effect.

## What the criterion cannot see

- **29 cells over 22 pairs is thin**, and the pooled rate itself rests on the
  same 29. This cannot distinguish "0.25 is the right rate" from "any rate
  in 0.15-0.35 would score about the same".
- It cannot tell whether a *losing* defector's vote behaves differently in
  kind rather than in degree — only whether one rate beats a zero.
- The identity matching underneath is unchanged, with its known
  surname-plus-initial weakness.

## Dry-run on cases whose answer is known

- **Ward (Kiama, member, 53.6 → 38.8, ratio 0.724)**: already gets a floor;
  the arm lowers it slightly (0.282 → ~0.25 of 53.6, i.e. 15.1 → 13.4). The
  arm should make Kiama very slightly WORSE, since Ward over-performs the
  rate. Recorded in advance so it cannot be cited afterwards as a failure.
- **Cupper (Mildura, losing, 15.2 → 21.3, ratio 1.40)**: currently zero,
  gains a 3.6-point floor. She massively over-performs the rate, so the arm
  helps but nowhere near enough — this is the shape that would need a
  separate mechanism, not a bigger constant.
- **Key (Dandenong, losing, 29.3 → 1.5, ratio 0.05)**: currently zero, which
  is nearly right. The arm gives him a 7-point floor he does not deserve and
  should make that seat WORSE. If the arm does not hurt Dandenong, the wiring
  is wrong.

The dry-run predicts a mixed result at cell level, which is why the criterion
is an aggregate over 29 cells rather than a count of wins.

## Prediction, written before running

Expect a **small improvement** on the named cells — 12 of 29 move off a
floor of zero onto something non-zero, and zero is clearly wrong for a group
whose median is 0.142. Expect the election-wide panel to be near-flat, since
29 cells cannot move 2,050 seat-elections much. Expect R1 to be the
binding risk if anything: the member cells outnumber the losing ones.

---

## Result, 2026-09-09: the mechanism is CONFIRMED, the implementation is REFUSED

**First run was VOID, and R1 is why the plan had it.** The rate was pooled in
`fit_defector_discount()` but `personal_prior_vote()` keeps its OWN
`elected %in% TRUE` filter deciding who RECEIVES the floor. Only the fitting
end moved, so the run measured "lower the member rate 0.282 → 0.270" and the
12 losing cells moved by 1.7e-07 — nothing. Both ends were then wired and the
arm rerun. Recorded because it is the third time in one day an arm changed one
end of a two-ended mechanism (the split-slope arm computed `sl` and discarded
it; the fitted-slopes arm was inert on 20 of 22 pairs).

### Scored, correctly wired

| test | value | bar | verdict |
|---|---:|---:|---|
| **R1 — losing cells carry it** | **RMSE 10.44 → 8.99, −1.45** | must not be the member cells | **PASS** |
| member cells (side effect) | 12.61 → 13.21, +0.60 | — | as predicted |
| criterion 1 — paired primary | mean **−0.55**, t = −1.04, better in 9 of 17 | ≤ −2.08 SE | **FAIL** |
| criterion 2 — panel | **3 better, 3 worse** | ≥ 6 better, ≤ 3 worse | **FAIL** |
| catastrophic floor — SA | **+0.0364** | 0.02 | **BREACHED** |
| Victoria | 0.2693 → **0.2655** | — | improved |

**Refused on the SA floor breach.** `AUSPOL_DEFECT_POOLED` stays `0`.

### What was learned, which is more than the refusal

**The hypothesis is right.** Giving a losing defector a floor instead of zero
improves exactly the cells it targets, by 1.45 RMSE points across 12 cells,
and R1 — written to catch a member-cell effect masquerading as this one —
passes cleanly. Victoria and WA both improved. The direction is not in doubt.

**The magnitude is wrong.** One pooled rate of 0.270 over-predicts the losers
who collapse. South Australia is the case: Harrison (Unley, 32.0 → 4.4,
ratio 0.137) now carries a floor of 8.6 where he polled 4.4, and Dandenong's
Key (29.3 → 1.5) gains 7.9 against an actual 1.5. Both were named in the
dry-run above as cases the arm should hurt; SA is where enough of them
coincide to breach the floor.

### The tension this exposes, and it matters for the shrinkage rule

The plan pooled the two rates because they are **not statistically
separable** — Wilcoxon p = 0.408, and partial pooling put weight 0.12 on the
losing-candidate estimate, dragging 0.142 up to 0.241.

The seat-level outcome disagrees: at 0.270 the losers are visibly
over-predicted, which is what a rate fitted mostly on *members* would do.

Both can be true. p = 0.408 at n=12 is **absence of evidence, not evidence of
absence** — the test has almost no power to separate 0.142 from 0.282. The
shrinkage weight inherited that low power and shrank toward the members
accordingly. So partial pooling did what it should given the inputs, and the
inputs were too thin to tell it the groups differ.

**This is a real limit of the rule as stated in `CLAUDE.md`, and it belongs
there**: shrinkage protects against over-fitting a thin cell, but when the
between-group variance is itself barely estimable it will under-separate
groups that genuinely differ. The corrective is an outcome check — does the
shrunk value predict better on the held-out cells? — not a bigger significance
test.

### Next, needing its own pre-registration

Use the losing group's own median (0.142) rather than the pooled 0.270, i.e.
**less** shrinkage, on the grounds that the seat-level outcome carries
information the rank test cannot see. That value must NOT be chosen because
0.270 breached — it is the pre-existing group median, computed and recorded
above before this run — but adopting it after seeing this result still
requires a fresh criterion, and the plan must say what would make it
unacceptable.
