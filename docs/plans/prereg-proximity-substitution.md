# Pre-registration: are ideologically adjacent parties substitutes?

Written 2026-08-25, **before** anything is computed. Committed before running.

Follows [../reviews/swing-shape-2026-08-25.md](../reviews/swing-shape-2026-08-25.md).
Pete's question: does our swing model account for One Nation voters being
closer to the Coalition and Greens voters closer to Labor? It does not — both
uniform (shipped) and proportional (tested, worse) know only about **size**.

## The hypothesis, stated generally

**When a party's primary vote moves, the offsetting movement concentrates on
ideologically adjacent parties rather than being spread by size.**

Not a One Nation patch. If true it applies to GRN↔ALP, ONP↔LNP, and every
other pair, and it is the principle behind the vote-sourcing matrix.

## Proximity is MEASURED here already, not assumed

`load_preference_flows()` gives each party's share of preferences flowing to
Labor. That is revealed behaviour, not a prior:

| party | mean flow to ALP |
|---|---:|
| NAT | 5.0 |
| ONP | 39.6 (Victoria 2026: 25.5) |
| UAP / DLP / FF / SFF | 40–42 |
| OTH | 50.4 |
| GRN | 71.3 (Victoria: 81.9) |

**Position** for party `p` is its `flow_alp`, with ALP fixed at 100 and LNP at
0. **Proximity** between `p` and `q` is `-|pos_p - pos_q|`.

Using preference flows as the position scale is itself an assumption — it
measures where a party's voters go *after exclusion*, which need not be where
they come *from*. Recorded as a limitation, not defended as obviously right.

## WHICH TEST THIS IS: gradient, declared in advance

This session has already produced **opposite answers from a levels test and a
gradient test on the same corpus**, so the choice is made and stated before
running rather than after.

- The **levels** question ("statewide, when ONP rose 20 points, did the
  Coalition fall 15 and Labor 5?") has **12 cycle-pairs**. That is n=12 for the
  quantity of interest, it is confounded with which party lost the election,
  and today's two aborted experiments both died at 6–7 clusters. **It is
  underpowered and this plan does not rest on it.** It is computed and
  reported as description only, with no criterion attached.
- **This plan's criterion is a within-cycle substitution structure**, which has
  far more observations and tests the *shape* of the proximity relationship
  rather than one party's levels.

## The design

For every cycle-pair and every pair of parties `(p, q)` both contesting:

1. Compute each party's **district-level change** across the pair.
2. Compute `r_pq` = correlation of those changes across districts within that
   cycle.
3. Compute `prox_pq` = `-|pos_p - pos_q|` from the flow scale.

**Substitution predicts `r_pq` is more negative for closer pairs.** Two parties
competing for the same voters trade votes district by district; two parties
appealing to different voters do not.

Criterion: coefficient of `r_pq` on `prox_pq`, **clustered on the cycle-pair**.

## Power, computed BEFORE the criterion

Twelve cycle-pairs; with ~5–6 parties each that is roughly 10–15 party pairs
per cycle, so **on the order of 120–180 pair observations in ~12 clusters**.

Twelve clusters is ~11 degrees of freedom, so a two-sided 95% test needs
**2.20 SE**, not 1.96. That is the bar. (Stating this before running is the
correction to the two failures earlier today, where bars were set without
computing their size.)

**Abort condition, fixed now:** if fewer than **8 cycle-pairs** yield at least
3 usable party pairs each, stop and report that the corpus cannot support it,
rather than reporting a number from four clusters.

## Decision rule, fixed now

Conclude that proximity drives substitution **only if all three hold**:

1. Coefficient is **>= 2.20 clustered SE** and in the predicted direction
   (closer ⇒ more negative correlation).
2. **Sign consistency in at least 8 of 12** cycle-pairs computed individually.
3. It **survives dropping One Nation entirely**. ONP motivated this; if the
   structure only exists for ONP pairs it is a One Nation fact, not the general
   principle claimed, and must be reported as such.

Otherwise nothing is adopted and the uniform swing stands.

## Refusal: what would make an apparent WIN unacceptable

- **R1 — size confound.** Two large parties trade more votes in absolute terms
  simply for being large. ALP and LNP are also the two ends of the proximity
  scale, so "big" and "far apart" are entangled. **Control for the product of
  the two parties' mean shares** and report the coefficient with and without;
  if it does not survive the control, refuse.
- **R2 — the sum-to-zero artefact.** District shares sum to 100, so *any* two
  parties are mechanically negatively correlated to some degree. The test is
  whether proximity explains variation **beyond** that. If the estimated
  proximity effect is smaller than the mechanical baseline implied by the
  parties' sizes, refuse.
- **R3 — it must not rest on GRN↔ALP alone.** Greens–Labor is the most
  numerous and best-measured pair in the corpus. Re-run excluding it; report
  prominently if the effect vanishes.
- **R4 — adoption is not authorised by this plan.** Even a clean result
  establishes that adjacent parties trade votes, **not** that reweighting the
  seat-level swing by proximity forecasts better. Uniform currently beats
  proportional at **MAE 3.724 vs 3.970** on 2,878 observations, and any
  proximity-weighted swing must beat *uniform* on that same test before it goes
  anywhere near the model. That is a separate experiment.

## What this cannot see

- **Direction.** A correlation says two parties trade votes, not which way they
  flow or who initiates.
- **Whether the flow scale is the right position measure** — see above.
- **Anything about seats.** This is a first-preference structure test. The seat
  model's behaviour, and the ONP seat-type asymmetry that started this, are
  downstream of it and untouched.

## Prediction, written before running

Expect the coefficient to be **in the predicted direction and to clear the
bar**, because the flow scale separates the parties sharply (NAT 5.0 against
GRN 71.3) and district-level trading between adjacent parties is a strong prior.

Expect **R1 to be the real threat**: ALP and LNP are simultaneously the largest
pair and the most distant pair, which is exactly the configuration that can
manufacture the predicted sign from size alone. If the effect dies under the
size control, that is the finding.

---

## Result, 2026-08-25: REFUSED. The size control was decisive, as predicted.

`scripts/test_proximity_substitution.R`. 54 party-pair observations, 12
cycle-pairs, gate passed. **Nothing adopted.**

| specification | coefficient | clustered ratio |
|---|---:|---:|
| proximity alone | +0.00100 | +1.35 |
| **proximity, controlling size** | **−0.00220** | **−1.16** |
| proximity, no ONP pairs | −0.00290 | −1.85 |
| proximity, no GRN–ALP pair | −0.00515 | −2.51 |

| criterion | required | got | verdict |
|---|---|---|---|
| size-controlled coefficient | >= +2.20 SE | −1.16 | **FAIL** |
| sign consistency | 8 of 12 | **5** | **FAIL** |
| survives dropping ONP | positive | −1.85 | **FAIL** |

**Raw proximity is in the predicted direction and does not clear the bar
(+1.35 SE). Controlling for size flips the sign.** That is R1 firing exactly as
written in the prediction above: ALP and LNP being simultaneously the largest
and most distant pair manufactures the expected pattern out of size alone.

### The Greens and Labor are not reliably substitutes

The most striking single result, because it contradicts the strongest form of
the intuition. GRN–ALP district-level correlations across 12 cycle-pairs:

`+0.125, −0.335, +0.005, +0.197, +0.225, −0.003, −0.031, +0.342, −0.165,
−0.222, −0.353, −0.146`

**Five of twelve are positive.** Greens and Labor frequently rise and fall
*together* across districts rather than trading votes — consistent with shared
demographic tides moving both, which a substitution model has no way to
represent.

ONP–LNP is the one pair that behaves as the intuition predicts (−0.245 and
−0.171, both negative), but that is **two observations** and it does not
generalise to the structure being tested.

### The proximity gradient is flat

Mean correlation by distance band, description only:

| band | pairs | mean r |
|---|---:|---:|
| close | 20 | −0.057 |
| far | 8 | −0.043 |
| very far | 26 | −0.046 |

No gradient. If proximity drove substitution, close pairs would sit well below
distant ones.

### What this means for the thread

**Third refusal in a row on the same question.** In order: district-level vote
sourcing (refused, sign reversed by the confound control), proportional swing
(measurably worse than uniform, MAE 3.970 vs 3.724), and now proximity
substitution (refused, sign reversed by the size control).

The consistent finding across all three is that **the shipped uniform swing
survives every alternative tried**, and that each intuitive improvement fails
once its obvious confound is controlled. Two of the three reversed sign at
exactly the control the plan named in advance — which is the argument for
naming them in advance.

**This does not explain the ONP seat-type asymmetry**, which remains open. The
remaining candidates from
[../reviews/swing-shape-2026-08-25.md](../reviews/swing-shape-2026-08-25.md)
are the statewide Coalition level (a trend question, cheap), mean reversion
(needs the artefact test first), and the count itself. **None of them is
another version of "whose votes move where" — that line is now exhausted and
should not be re-run in a fourth form.**
