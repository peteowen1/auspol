# Ordering uncertainty is far less one-sided, and still not neutral. Refused.

Run 2026-08-19 against
[../plans/prereg-onp-ordering-uncertainty.md](../plans/prereg-onp-ordering-uncertainty.md),
committed before anything was built and the first plan written under the
`CLAUDE.md` rule requiring a refusal section.

**Refused on R1, and the design was not adjusted to make R1 stop firing.**

## The design did what it claimed

One Nation's seat shares are assigned by ranking seats on Greens share and
quantile-mapping onto an observed spread. The previous attempt put noise on the
*shares*; this one puts it on the *ordering* and re-runs the same mapping, so
every draw carries an identical multiset of shares and only the assignment
varies.

Verified, not assumed:

- **The multiset is identical in 200 of 200 draws.**
- **The statewide mean ratio is identical to six decimal places** (0.999861 in
  the central allocation and in every draw's minimum and maximum).
- Calibrated by bisection to `ONP_ORDER_SD = 0.3575`, reproducing a mean rank
  correlation of **0.781** against the pre-registered target of 0.779 — the
  predicted-versus-actual correlation measured on South Australia.

## Scores

| | criterion | control | perturbed | |
|---|---|---:|---:|:--:|
| C1 | ONP median ≤1, mean ≤0.5 | 3 / 3.349 | 3 / 3.457 | pass |
| C2 | ALP, LNP medians ≤2 | 40, 38 | 40, 38 | pass |
| C3 | ONP 90% interval must widen | 0–7 | **0–8** | pass |
| C4 | primaries sum to 100 | — | holds | pass |

Every acceptance criterion passed, including the one the last attempt failed.

## R1 refuses it

| | previous attempt (share noise) | this attempt (ordering noise) |
|---|---:|---:|
| seats where ONP's probability rose | 71 | **57** |
| seats where it fell | 1 | **13** |
| ratio | 71× | **4.4×** |

R1 refuses anything above 3×. **57 against 13 is 4.4×.**

The diagnosis was right and the improvement is large — a 71:1 split became
57:13, so ordering noise really is far more two-sided than share noise, exactly
as the plan argued. It is still not two-sided enough.

R3 also fired as a *report-prominently* condition rather than a refusal: One
Nation's mean seat count rose by **+0.108** despite an exactly preserved
statewide vote. Small, within C1's bound, and in the same direction as before.

## Why preserving the total is not enough

This is the part worth keeping.

Holding the statewide total fixed does **not** make the effect neutral, because
a seat outcome is a threshold event and the map from share to win probability is
convex over the range that matters. Moving a high share **into** a seat where
One Nation is close enough to win gains more probability than moving it **out**
of a seat where One Nation was already winning comfortably loses. The gains
concentrate where the curve is steep; the losses fall where it is flat.

So the ratchet is not caused by adding vote — no vote is added — it is caused by
redistributing it across a nonlinearity. Any scheme that reassigns shares
without correcting for that convexity will lean the same way, just less.

## Refused rather than tuned

The plan said: *"Any R fires → refuse, and do not adjust the design to make it
stop firing. A second attempt needs a new pre-registration."*

The tempting move is obvious — R1's 3× was a number I chose, 4.4× is close to
it, and the design is clearly better than what it replaced. That is exactly the
reasoning the refusal section exists to stop, and it is the third experiment in
a row where the honest answer was no.

## What a neutral version would need

Correcting for the convexity, not just preserving the total:

- **Recentre the outcome.** Scale or shift the per-draw allocation so One
  Nation's *expected seat count* matches the unperturbed one, rather than only
  its expected vote. More invasive, and it would need a rule for where the
  correction is applied.
- **Perturb pairwise.** Swap shares between seats of similar competitiveness, so
  every gain has a matched loss in a seat at a comparable point on the curve.
- **Accept the lean and bound it.** Argue that some upward drift is the honest
  consequence of genuine uncertainty about a surging party, and set a defensible
  bound instead of requiring symmetry. This is the option most likely to be
  right and the hardest to argue without it sounding like a rationalisation of
  three failed attempts — it needs its own pre-registration written before the
  next run, not after.

## What was kept

`simulate_seat_contests()` keeps `party_draws`, which lets a caller supply
per-draw seat shares for one party — the machinery any of the above would need.
It is inert unless passed, and the model is unchanged.
`scripts/calibrate_onp_ordering.R` is kept: the 0.3575 figure and the
multiset-preservation check are reusable whatever the next design is.
