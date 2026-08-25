# Pre-registration: does a demographic term beat baseline-plus-swing?

Written 2026-08-25, **before anything is fitted**. Committed before running.

Follows [../reviews/census-feasibility-2026-08-25.md](../reviews/census-feasibility-2026-08-25.md),
which acquired ABS Census at SED and found strong associations with the **level**
of the vote — and noted that our model already knows the level, so association
is not evidence of value.

## The claim under test, stated narrowly

> **In seats where the previous result is a poor guide, does a demographic
> model beat baseline-plus-uniform-swing?**

Not "do demographics correlate with vote". They do, and it does not follow that
they help. Six of this session's ten refusals came from exactly that confusion.

## The corpus, counted before any criterion

Census is 2021 and covers VIC, NSW and SA. Using it to predict an election held
**after** its publication is not leakage — the Census is not derived from the
result.

| pair | seats |
|---|---:|
| Victoria 2018 → 2022 | ~78 |
| NSW 2019 → 2023 | ~88 |
| SA 2022 → 2026 | ~47 |
| **total** | **~213** |

**Three election-pairs. Three clusters.**

### The power problem, named rather than discovered later

Three clusters cannot support a cluster-robust significance test. Two
experiments today aborted at 6 and 7 clusters; this is worse. **So this plan
does not claim significance and no SE bar is set.** Pretending otherwise would
be the theatre those aborts were meant to prevent.

The criterion is instead **consistency plus effect size**, and its weakness is
stated up front: with three elections, "wins in all three" is a sign test with
p = 0.125 under the null. **That is not significance and will not be reported
as such.**

## Arms

| arm | seat first preferences |
|---|---|
| **A — current** | 2018/2019/2022 result + uniform statewide swing |
| **B — augmented** | arm A **plus** a fitted demographic term |
| **C — demographics only** | fitted from Census alone, ignoring the baseline |

Arm C is included deliberately. It is the MRP-shaped model, and if it is
catastrophically worse than A everywhere, that bounds how much a demographic
approach could ever contribute here.

Fitting is **leave-one-election-out**: coefficients for a pair are estimated on
the other two only. No pair informs its own prediction.

## Criterion, fixed now

Primary: **seat-winner log score**, computed through the full count
(`simulate_seat_contests()`), not on first preferences — because first
preferences are not what the model outputs and a first-preference improvement
that does not survive the count is not an improvement.

Adopt arm B only if:

1. It beats arm A on log score in **all three** election-pairs.
2. The pooled improvement is at least **0.05** log score — a size chosen to
   exceed the noise between reruns rather than by significance, since no
   significance test is available at three clusters.
3. It does not reduce seat accuracy in any pair.

Otherwise nothing changes.

## The subgroup that is the actual point

Reported separately and **decisive in its own right**: seats where the baseline
is a poor guide.

Defined **before seeing results**, to avoid choosing the cut that flatters:
a seat is **baseline-broken** if the winning party's first-preference share
moved by **more than 15 points** between the two elections. MacKillop
(Coalition 67.0 → 26.9) qualifies; a typical seat does not.

**If arm B beats arm A overall but NOT on baseline-broken seats, the mechanism
claimed here is absent and adoption is refused** — that subgroup is the entire
argument for demographics.

## Refusal: what would make an apparent WIN unacceptable

- **R1 — the nine redistributed seats must be handled explicitly.** They have
  no 2021 Census geography. Excluding them silently is forbidden: excluding
  seats correlated with the outcome under test is the trap
  `backtest_candidate_sa.R` documents for Ngadjuri. Report the count and score
  with and without.
- **R2 — it must not simply relearn the baseline.** If arm B's demographic
  coefficients are large where the baseline is strong and near zero where it is
  weak, it is duplicating information the model already has. Report the
  coefficients, not just the score.
- **R3 — arm C must not be quietly dropped.** If arm C is far worse, that is a
  finding about the ceiling of this approach and must be reported even though
  it is unflattering to the direction Pete chose.
- **R4 — no Victorian 2026 adoption on three elections.** Even a clean pass is
  three election-pairs, one of which is the SA election that motivated it.
  Adoption into the published forecast needs a separate decision and should not
  be presented as following automatically.
- **R5 — uniform swing keeps its standing.** It has survived proportional,
  proximity-weighted, magnitude-dependent, cross-party and concentration-based
  alternatives this session. A demographic term does not get a lower bar for
  being more sophisticated.

## What this cannot see

- **One Census vintage.** 2021 demographics are applied to 2022, 2023 and 2026
  elections alike. Composition drifts, and this cannot measure the drift.
- **No sub-seat structure**, so it cannot represent a swing concentrating in
  part of a seat — the thing booth-level regression exists for.
- **Three clusters.** Whatever it finds is suggestive, and the plan says so
  before the result rather than after.

## Prediction, written before running

Expect **arm B to beat arm A modestly overall and to fail criterion 1** by
losing in at least one pair — because the baseline already carries the
level, and the feasibility review found no evidence demographics predict swing.

Expect **arm C to be substantially worse than A**, which would bound how much
a pure demographic approach can offer at seat-level resolution.

Expect the **baseline-broken subgroup to be the only place arm B clearly
helps**, if it helps anywhere. If that subgroup shows nothing, this direction
is finished and the honest conclusion is that seat-level demographics do not
solve the problem that started it.
