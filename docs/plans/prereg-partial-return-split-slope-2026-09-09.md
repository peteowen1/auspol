# Pre-registration: split the class's prior vote into RETURNING and DEPARTED portions, and fit a slope for each

Written 2026-09-09, **before any arm is fitted or scored**. Committed before
running. Decision rule and refusal conditions below are fixed at commit time.

## The defect

The seat model projects a party class's seat-level vote forward with ONE
slope, selected by a BINARY class-level flag: did "the" candidate return?
(`candidate_returns()$same`, consumed by `conditional_slopes()` /
`screened_slopes()`; the base value comes from `personal_prior_vote()`.)

That flag is decided by the class's **highest-polling candidate at the target
election**, and the resulting behaviour is internally inconsistent:

| case (real) | class before | who returned | actual after | what the model uses now |
|---|---|---|--:|--:|
| Rankin OTH_RIGHT fed2016→19 | 13.3 (3 cands) | Davies 4.1 | **6.6** | 13.3 (leader is new → NO match → full class base) |
| Blue Mountains OTH nsw2019→23 | 9.0 (3 cands) | Keightley 4.1, Marschall 3.0 | **9.7** | 4.1 (leader matched → ONLY his own share) |
| Melton IND vic2018→22 | 35.5 (6 cands) | Birchall 10.5, Bingham 6.8 | **15.2** | 10.5 (leader's share only) |
| Groom IND fed2022→25 | 15.4 (2 cands) | both | **20.7** | 8.3 (leader's share only) |

So when the leader has no history the model keeps the **whole class total**,
and when the leader does have history it keeps **only that one person's
share** — two opposite assumptions, chosen by an accident of who polls
highest. Neither uses the fact that the repo has already measured both rates:
a returning IND candidate holds **0.907** of their vote, a departed one's
share retains **0.326** (`candidate_returns()` docstring, 17 pairs).

A "sum the returners only" version of this was built and **reverted** on
2026-09-09 after measuring real harm (fed2019 pooled seat log loss 0.263 →
0.383, fed2025 0.324 → 0.373). It discarded the departed candidates' vote
entirely, which is the opposite error. That failure is why this plan exists.

## The arm

Decompose each (seat, class)'s prior vote into two portions and give each its
own fitted slope, replacing the binary flag:

```
x = s_ret * (prior vote of candidates who ARE standing again)
  + s_dep * (prior vote of candidates who are NOT)
```

Identity matching is unchanged (`match_key()`, surname + first initial,
across the seat regardless of party label, both spellings of a renamed seat).
Only the projection changes. At the extremes this **degrades to the current
model**: an all-returning class gets `s_ret` (≈ the current 0.907 path), an
all-departed class gets `s_dep` (≈ the current 0.326 path). Only the mixed
case — the one this plan targets — moves.

`s_ret` and `s_dep` are **fitted from data, leave-one-election-out** (the
target election never contributes to the slopes used to score it), the same
discipline `fit_defector_discount()` uses. They are NOT the hand-carried
0.907 / 0.326: those are quoted above only to show the mechanism already has
measured rates, and Pete's instruction 2026-09-09 was explicitly to fit
rather than hand-pick.

Shipped behind `AUSPOL_SPLIT_SLOPE` (default `0` = byte-identical to today),
added to `scripts/published_flags.R` in the same commit per the repo rule.

## The test set, named before any criterion

Every (seat, non-major class, pair) where the class had **≥2 prior
candidates, at least one returning and at least one not** — the partial-return
shape, which is what the arm changes:

| | count |
|---|---:|
| partial-return cells, all classes | 431 |
| **non-major partial-return cells (the test set)** | **329** |
| of those, scoreable against model output | **319** |
| pairs represented | 22 |

The 10 unscoreable cells are all `wa2008` / `wa2013` OTH, lost to WA's
redistribution (seat names do not survive between WA elections — already
documented in `CLAUDE.md`). Stated here rather than discovered later.

Distribution by class: OTH_RIGHT 154, LNP 100, OTH 91, IND 84, ALP 2 (majors
excluded from the test set; 329 is the non-major count).

## Primary metric

**Seat-share RMSE on those 319 cells**, PAIRED (same cells scored under both
arms), differenced per pair, **clustered on the 22 election pairs**.

Baseline, measured before the arm exists: **RMSE 5.377** overall; per-pair
mean 4.994, sd 3.039 across 22 clusters; mean |error| 3.159; the model is
biased LOW on these cells by −0.42 points (predicts 7.42, actual 7.84).

**MDE sizing, computed now.** Unpaired, sd 3.039 over 22 clusters gives an
MDE of **1.354 RMSE points at 2.09 SE** (t, 21 df) — 27% of baseline, a
demanding bar. But the design is **paired**: the same cells are scored under
both arms, so pair-level difficulty cancels and the relevant spread is the sd
of the per-pair *difference*, which cannot be known until the arm runs. The
paired sd and the realised MDE **will both be reported** alongside the result,
and the criterion below is stated on the paired quantity. If the paired sd
turns out to make the MDE larger than the observed effect, that is reported
as "this test could not see it", not as a pass.

## Decision rule, fixed now

Pete, 2026-09-09: *"I don't like do no harm — if it's better in 9/10 metrics
then ship it — let's use some common sense."* That is adopted, but written
precisely here so it is a pre-registered rule and not a judgement made after
seeing the numbers.

**Ship if BOTH:**

1. **Primary improves**: paired per-pair share RMSE on the 319 target cells
   improves, and the improvement is ≥ 2.08 clustered SE from zero (t, 21 df,
   two-sided 95%).
2. **Majority of the named panel improves.** The panel is these **10**
   metrics, fixed now, each scored as better / worse / unchanged (|Δ| <
   0.0005 counts as unchanged and as NOT an improvement):

   | # | metric |
   |---|---|
   | 1 | pooled seat log loss, all 22 pairs |
   | 2 | pooled Brier, all 22 pairs |
   | 3 | pooled seat-share RMSE, ALL cells (not just targets) |
   | 4 | federal seat log loss (7 pairs) |
   | 5 | NSW seat log loss (2 pairs) |
   | 6 | QLD seat log loss (2 pairs) |
   | 7 | SA seat log loss (1 pair) |
   | 8 | Victoria seat log loss (3 pairs) |
   | 9 | WA seat log loss (7 pairs) |
   | 10 | count of seats given ≤ 1e-4 that the actual winner won (floor seats) |

   **Bar: ≥ 6 of 10 better, and no more than 3 worse.**

**Catastrophic-break floor (overrides the majority rule):** refuse regardless
of the panel if ANY single jurisdiction's seat log loss degrades by more than
**0.02**, or if pooled log loss degrades by more than **0.01**. This is not a
do-no-harm veto — small regressions are explicitly tolerated by the majority
rule — it is a guard against a change that wins on count while breaking one
jurisdiction badly.

**Victoria is the live target (28 November 2026).** It is metric 8, one vote
in the panel like any other, but a Victoria regression beyond the 0.02 floor
refuses on its own, and any Victoria regression at all must be reported
prominently in the result rather than absorbed into a count.

## Refusal: what would make an apparent WIN unacceptable

- **R1 — the win must not come from the majors.** The arm touches only
  non-major classes. If pooled improvement is driven by ALP/LNP seat-share
  error moving, something is wired wrong, not working. Report the target-cell
  improvement split by class; refuse if the non-major cells do not carry it.
- **R2 — `s_dep` must not be ≈ `s_ret`.** If the two fitted slopes come out
  statistically indistinguishable, the split has no content and any gain is
  noise or a side effect of refitting. Report both with SEs; refuse if their
  difference is under 2 SE.
- **R3 — it must not just be re-fitting.** The current 0.907/0.326 are frozen
  constants; this arm refits. Run a control arm that refits the EXISTING
  binary-flag slopes leave-one-out with no split, and report it. If the
  control captures most of the gain, the split is not what worked, and the
  cheaper control ships instead.
- **R4 — no silent seat-count swing in the published forecast.** If the
  Victorian published forecast's expected seat total for any class moves by
  more than 2 seats, escalate rather than ship as a side effect.
- **R5 — coverage.** If the arm fires on materially fewer than the 319 named
  cells (e.g. a join silently drops some), the run is void and gets rerun, not
  scored. The count of cells actually affected is reported with the result.

## Dry-run of the criterion on cases whose answer is already known

Required by `CLAUDE.md` before committing a criterion. Using the four real
cases above and the currently-measured 0.907 / 0.326 as stand-ins for the
fitted values (the real fit will differ):

| case | current model | split-slope prediction | actual | should the criterion count this a win? |
|---|--:|--:|--:|---|
| Rankin OTH_RIGHT | 13.3 | 0.907×4.1 + 0.326×9.2 = **6.7** | **6.6** | YES — near-exact, current is 6.7 off |
| Blue Mountains OTH | 4.1 | 0.907×7.1 + 0.326×1.9 = **7.1** | **9.7** | YES — closes most of a 5.6-point gap |
| Melton IND | 10.5 | 0.907×17.2 + 0.326×18.2 = **21.5** | **15.2** | NO — overshoots by 6.3, worse than current's 4.7 |
| Groom IND | 8.3 | 0.907×15.4 + 0.326×0 = **14.0** | **20.7** | YES — closes 6 of a 12.4-point gap |

The criterion says 3 of 4 improve and 1 worsens, which is the behaviour a
share-RMSE primary would score as a clear net gain — and Melton failing is
recorded HERE, before the run, so a post-hoc "but Melton got worse" cannot be
used to reject a result that the rule already accounts for. If the real fit
cannot beat current on at least Rankin and Groom, the mechanism is not doing
what this plan claims and the result should be read sceptically regardless of
the aggregate.

## What the criterion cannot see, stated in advance

- **It cannot separate "the split is right" from "two slopes fit better than
  one".** Any two-parameter model beats a one-parameter model in-sample; the
  leave-one-election-out fit and refusal R3's control arm are the defences,
  and neither is perfect.
- **It says nothing about seats, only shares, on the primary.** Seat outcomes
  enter only through the panel. A share improvement that never changes a seat
  call is a correctness gain, not a forecast gain, and will be described as
  such.
- **The identity matching underneath is unchanged and imperfect** — surname
  plus first initial, which `candidate_returns()`'s own docs flag as a
  false-positive source on common surnames. This arm inherits that; it does
  not fix or worsen it.
- **329 cells over 22 pairs is thin for some jurisdictions**: sa2026 has 2
  cells, wa2017 has 2, wa2008 and wa2013 have 1 each after the WA
  redistribution losses. Per-jurisdiction target-cell claims are not
  supportable for those; only the pooled target metric is.

## Prediction, written before running

`s_ret` should land near 0.9 and `s_dep` well below it, around 0.3-0.5,
because those are what the existing frozen constants measured on a
neighbouring definition. The arm should improve the primary clearly — the
current model's inconsistency (whole class one time, one person's share the
next) is large and obviously wrong in both directions. The binding constraint
is expected to be **R3**: much of the gain may come from refitting frozen
constants rather than from the split itself, and if the control arm shows
that, the honest outcome is to ship the control and not the split.
