# Pre-registration: which rate for the minor-to-minor defector discount

Written 2026-09-17, **before any arm is fitted or run**. Follows the PR #44
review-gate finding (`docs/NEXT-STEPS.md`, "OPEN, 2026-09-16" item 1) that the
shipped discount and its own justification describe two different numbers.

## The claim being tested

`fit_minor_defector_discount()` (`R/candidate_returns.R:850`) ships with
`min_prior = 10`, `stats::median()` aggregation — leave-target-out per-pair
rates cluster **0.30-0.34**. The review that motivated shipping it
(`docs/reviews/minor-to-minor-defector-2026-09-16.md`) headlines a
**geometric-mean retention of 49%**, computed with a looser prior-vote floor
(`prev_pcv >= 5`, 33 cases) and a different aggregation statistic. Both
numbers are real measurements; they answer different questions on different
samples, and nothing has yet asked **which one predicts held-out cases
better**.

## WHAT I ALREADY KNOW, stated before the criterion

- **The two differences are confounded.** Going from the shipped setup to the
  review's headline changes BOTH the sample (`min_prior` 10 → 5, roughly 18
  → 33 cases) and the statistic (median → geometric mean) at once. Nobody has
  isolated which one, if either, actually helps.
- **Median and geometric mean diverge hardest exactly when the ratio
  distribution is skewed** — and the review's own unfloored table (n=66)
  shows mean 1.326 vs median 0.729, a sign of exactly that skew. A rate
  fitted by mean/geometric-mean is more sensitive to a handful of large-gain
  outliers (Fremantle 2008 IND→GRN, ratio 4.79) than a rate fitted by median.
- **`fit_minor_defector_discount()` already does leave-target-out** — the
  infrastructure for an honest per-case OOF prediction exists; it just isn't
  used to SCORE cases today, only to report a corpus-wide rate.
- **The pooled do-no-harm floor is already established**: any single-column
  change costs roughly 0.014 pooled primary RMSE regardless of information
  content (`docs/reviews/pattern-a-seat-outperf-2026-09-16.md`), and the
  currently-shipped rate already clears it at **+0.0017**
  (`docs/reviews/minor-to-minor-defector-2026-09-16.md`). Any replacement
  rate needs to clear the same floor, not just beat the current one on the
  primary metric.

## The change being tested

A 2×2 grid, deconfounding the two axes above. Each cell is a
`fit_minor_defector_discount(target_election, min_prior = <p>, agg = <a>)`
call (the function needs one new parameter, `agg = c("median", "geomean")`,
defaulting to `"median"` — no other behavior changes):

| arm | `min_prior` | aggregation |
|---|--:|---|
| **A (shipped)** | 10 | median |
| **B** | 5 | median |
| **C** | 10 | geometric mean |
| **D (review's headline)** | 5 | geometric mean |

**The evaluation set is FIXED across all four arms**: every minor-to-minor
defector case with `prev_pcv >= 5` (the review's inclusive 33-case set),
regardless of which arm fitted the rate that scores it. Varying the
evaluation population along with the fitting population would let an arm
pass by changing what it's tested on rather than how well it predicts —
the same trap the departed-member pre-registration's control condition
existed to catch.

For each of the 33 cases, using arm X's leave-target-out rate for that
case's own target election (fit on the other 20 pairs, `min_prior` and
`agg` per the arm), predict `target_pcv_hat = prior_pcv * rate`. Score
against the actual `target_pcv`.

## The criterion

**This is a targeted change** (33 named cases across 21 pairs), so per
`CLAUDE.md`'s scoping rule the primary is targeted, with an election-wide
guard.

**Primary: RMSE over the fixed 33-case evaluation set**, arms B/C/D each
compared against arm A (shipped). **Adopt a replacement only if it beats
arm A's RMSE by at least 5%** — roughly the size of the targeted gain the
already-shipped discount itself produced over no discount at all (9.2363 →
8.8813, ~4%), so a replacement needs to clear a bar of the same order as
the effect that got the current version shipped in the first place, not a
smaller one.

**Guard, must not worsen by more than 0.005: pooled OOF RMSE across all
13,739 rows**, wiring the winning arm's rate into `AUSPOL_MINOR_DEFECT` the
same way the shipped rate is wired, via the standard non-circular
`pool_sharedetail.R` procedure.

**Guard, must not worsen by more than 0.005 on election-wide seat log loss**,
pooled across all 23 pairs, once the winning arm is threaded through
`fit_xgb_primary_v6.R` and a full six-harness backtest is run — matching the
seat-level bar every other model change in this repo is held to
(`## THE OBJECTIVE`, `docs/NEXT-STEPS.md`).

## Refusal: what makes an apparent win unacceptable

- **If the gain is carried by fewer than 5 of the 33 cases.** A rate that
  only helps Fremantle-2008-shaped outliers is overfitting the tail the
  skew warning above already names, not a better estimator.
- **If either guard breaches.**
- **If the winning arm's per-pair rates are less stable than arm A's**
  (wider spread across the 21 leave-target-out folds) — a rate that predicts
  the fixed set better on average but swings more per pair is a worse thing
  to ship into six harnesses that each read it independently, even if this
  criterion's headline number passes.
- **If arm D wins but arm B and arm C both lose to arm A.** That would mean
  neither axis helps alone and the apparent win is an interaction only
  visible in a 33-case sample — plausible overfitting, not a real joint
  effect, and it should be named as such rather than shipped on the
  strength of one cell in a 2×2.

## What the criterion cannot see

- **Why some defections collapse and some gain.** Same open question the
  review already named; a better-fitted rate does not answer it.
- **Whether 33 cases (or 18, at `min_prior=10`) is enough to fit ANY of these
  four estimators reliably.** This grid picks the best of four candidates on
  the data available; it does not establish that the data available is
  enough to fit a rate this finely at all.

## Prediction, written before running

**Arm B (min_prior=5, median) is the most likely improvement**, if any wins:
loosening the prior-vote floor recovers cases the shipped arm currently
discards without also inheriting the mean/geomean sensitivity to the
Fremantle-shaped outliers that arm D's headline number is partly built on.
**Arm D is the most likely to fail the stability refusal condition** even if
its point-estimate RMSE looks good, because geometric mean pulls hardest
toward whichever pair happens to contain a large-gain case in that fold.
**Arm C is the least likely to move anything** — changing only the
aggregation while keeping the tighter case filter should shift the estimate
only mildly, since median is already close to robust at n≈18.

I expect **no arm to clear the 5% primary bar**, and the honest finding to be
"the shipped 0.30-0.34 stays, and the review's 49% was answering a different,
noisier question" — but this is written before running, and a clear winner
that also clears both guards should ship regardless of what I predicted here.
