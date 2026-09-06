# Pre-registration: does One Nation's gain come disproportionately from the Coalition?

Written 2026-08-25, **before** any arm is fitted or scored. Committed before
running.

Follows [../reviews/onp-seat-type-asymmetry-2026-08-25.md](../reviews/onp-seat-type-asymmetry-2026-08-25.md),
which found our model elects One Nation in **6 of 6** ALP-leaning Victorian
seats and **0 of 6** LNP-leaning ones, while SA 2026 was **0 of 5 and 5 of 5**.

## First: a correction to that review's "next steps"

The review said a test against "SA 2026 / WA 2017 / QLD 2020+2024 / NSW 2019"
would be *"a real corpus, unlike the two aborted experiments"*. **Scoped before
writing this plan, that claim is wrong for the test it proposed.**

| | count |
|---|---:|
| One Nation seats **won**, entire corpus | **4** |
| elections with at least one ONP win | **1** (SA 2026) |

A test whose outcome is *seat wins* has one cluster. It would abort exactly
like the other two, and proposing it without counting first was the same
mistake this session already made twice.

## So the outcome is changed, deliberately and before measuring

**Do not test seat wins. Test the mechanism.** The review's causal claim is
about *whose votes One Nation takes*, and that needs only ONP's vote to move —
which happens far more often than ONP winning:

| | districts | cycle-pairs |
|---|---:|---:|
| all consecutive district pairs | 754 | 12 |
| ONP moved >= 3 points | 276 | 10 |
| **ONP rose >= 5 points** | **157** | **7** |

**157 districts across 7 cycle-pairs** is the test set. It is stated here
before any criterion, so the criterion cannot be sized to fit it afterwards.

## The confound, named before it can be discovered conveniently

Raw district changes are contaminated by the overall swing. The scoping run
already shows it:

| cycle-pair | districts | mean ΔONP | mean ΔALP | mean ΔLNP |
|---|---:|---:|---:|---:|
| wa 1996→2001 | 50 | 11.9 | +0.3 | −13.1 |
| sa 2022→2026 | 46 | 20.2 | −2.7 | −17.0 |
| wa 2013→2017 | 28 | 9.3 | +8.5 | −18.1 |
| **wa 2021→2025** | 14 | 6.6 | **−22.0** | **+9.2** |
| nsw 2019→2023 | 9 | 10.1 | +3.8 | −11.2 |
| **qld 2020→2024** | 8 | 9.4 | **−8.2** | **+5.7** |
| vic 2018→2022 | 2 | 5.9 | −2.4 | +3.0 |

Two cycle-pairs run the *other* way — and both have an obvious non-ONP cause.
WA 2021→2025 Labor was reverting from a freak 2021 landslide; QLD 2020→2024
Labor lost government. **Raw changes measure who lost the election, not whose
votes One Nation took.**

**Fix, fixed now:** every quantity is a **within-cycle deviation** — a
district's change minus that cycle's statewide change for the same party. This
removes the election-wide swing by construction and leaves only the
cross-district variation, which is what the mechanism is about.

## The general form: a VOTE-SOURCING MATRIX, not a One Nation patch

Added 2026-08-25 before any arm was run, on Pete's point: *"if a party wins
primary, where is it likely to win them from? People aren't as likely to go
ALP → ONP as they are to go LIB → ONP."*

That is the right generalisation and it changes what should be built. This
repo already has a **preference-flow matrix** — where a party's preferences go
once it is excluded, keyed on the surviving set. It has **no equivalent for
primary vote movement**: when a party's primary rises, the model takes the
votes proportionally from everyone, which is the assumption under test.

So the object is a **source matrix** `S[gaining party, losing party]`:
the share of a party's primary gain that comes out of each other party,
estimated from district-level movement across the corpus.

**One Nation is the first application, not the whole plan** — it is where the
question was raised and where the corpus is thickest. But the same estimation
answers ALP→GRN, LNP→OTH_RIGHT and the rest, and a matrix estimated once
serves every party.

**Scope discipline:** this plan tests **one cell** — does ONP's gain come
disproportionately from LNP rather than ALP. It does **not** build the full
matrix. If the cell is confirmed, the matrix gets its own plan, because
estimating every cell needs a coverage floor per cell (the same `min_n`
problem the flow matrix already solved, and the same one that killed refusal
M2 on cell thinning).

**Pete's directional hypothesis is recorded here BEFORE the test**, so
confirming it counts and contradicting it also counts: **LIB → ONP should
exceed ALP → ONP.**

## The null is PROPORTIONAL, and it is specific

Our model adds each party's statewide swing and renormalises, which takes One
Nation's gain **in proportion to each party's size in that seat**. So the null
is not "ONP takes equally from both" — it is:

> a party loses in proportion to its own share, i.e.
> `Δparty ≈ −(party_share / (100 − ONP_share)) × ΔONP`

The test is whether the Coalition loses **more than its share implies**, and
Labor correspondingly less.

Operationally: define `excess_LNP` as the Coalition's within-cycle deviation
minus its proportional prediction, and regress it on the district's ONP
deviation. **A positive coefficient means the Coalition loses more than
proportional where One Nation gains more.**

## Criterion, fixed now

Coefficient on `ΔONP_dev` in the `excess_LNP` regression, **standard error
clustered on the cycle-pair**.

**Seven clusters, so ~6 degrees of freedom.** Writing the bar in SE without
saying that is the failure this session hit twice today, so it is computed
here: a two-sided 95% test at t(6) needs **2.45 SE**, not 1.96. The bar is
therefore **2.45 clustered SE**, not the repo's usual 2.

Reported alongside, not decided on: the same regression for `excess_ALP`, and
the raw (non-deviation) version, so the confound's size is visible.

## Decision rule, fixed now

Adopt a source-weighted allocation **only if all three hold**:

1. Coefficient on `ΔONP_dev` is **>= 2.45 clustered SE** from zero, positive.
2. **Sign consistency: at least 5 of the 7 cycle-pairs** show the same sign
   individually. With 7 clusters a pooled estimate can be driven by one large
   cycle (SA has 46 of 157 districts), and a mechanism claimed to be general
   should not rest on one election.
3. The effect is **material**: implied reallocation changes at least one seat's
   ONP probability by >= 0.10 in the Victorian forecast. A real but tiny effect
   is a correctness note, not a model change — `stats-discipline` sizing.

**Otherwise nothing changes** and the review stands as a recorded suspicion.

## Refusal: what would make an apparent WIN unacceptable

- **R1 — it must not be Labor-symmetric.** If `excess_ALP` moves by a similar
  magnitude in the same direction, the model is picking up "the bigger party
  loses more", which is what proportional already does. Refuse.
- **R2 — SA 2026 must not be load-bearing alone.** Re-run with SA excluded. If
  the coefficient loses significance entirely, report that prominently and do
  not adopt on the pooled figure — SA is the cycle that motivated this and is
  the one most at risk of confirming it.
- **R3 — no improvement to ONP at the majors' expense.** If a fitted
  reallocation improves ONP seat accuracy while degrading ALP or LNP seat
  accuracy on the same corpus, refuse. The forecast is the whole parliament.
- **R4 — Victoria's published total must not move on an untested lever.** If
  adoption changes the published ONP seat *total* by more than 2 seats, that is
  a large published change resting on 7 clusters and must be escalated, not
  shipped as a side effect.
- **R5 — three-cornered contests.** Victoria runs Liberal against National in
  rural seats and SA has no Nationals at all. If the effect is carried entirely
  by seats with a single Coalition candidate, it may not transfer to exactly
  the Victorian seats this is meant to fix (Lowan, Ovens Valley, Gippsland
  East). Report the split; do not assume it.

## What the criterion cannot see, stated in advance

- **It tests vote SOURCING, not seat outcomes.** Establishing that One Nation's
  gain comes from the Coalition does **not** establish that a source-weighted
  model predicts seats better. That second step needs the outcome corpus, which
  is n=4 and cannot support it. Any adoption is therefore on **mechanism plus
  plausibility**, not on demonstrated seat-level improvement, and must say so.
- **Nothing here validates the federal-ordering input.** The review found the
  asymmetry survives *given* our ordering; this plan does not re-examine
  whether the ordering itself is right.
- **The 2022-lean conditioning variable predates the surge** in every cycle,
  so "Coalition-leaning" is measured before One Nation existed at scale.

## Prediction, written before running

Expect the coefficient to be **positive and to clear 2.45 SE**, because the
levels are large (SA's Coalition fell 17.0 against Labor's 2.7). Expect sign
consistency to be the binding constraint, not significance — WA 2021→2025 and
QLD 2020→2024 may survive the deviation adjustment with the wrong sign, and if
two of seven do, criterion 2 fails and nothing is adopted.

Expect R5 to be genuinely at risk: the strongest cycles (SA, WA) are the ones
without three-cornered Coalition contests.

---

## Result, 2026-08-25: REFUSED, and the confound control flipped the sign

Run by `scripts/test_onp_vote_sourcing.R`. 157 districts, 7 cycle-pairs, as
scoped. **Nothing adopted.**

| test | value | bar | verdict |
|---|---:|---:|---|
| criterion 1 — excess_LNP, clustered | **+1.72 SE** | 2.45 | **FAIL** |
| criterion 2 — sign consistency | **3 of 6** usable | 5 of 7 | **FAIL** |
| R1 — not Labor-symmetric | \|ALP\| 0.169 > \|LNP\| 0.094 | — | **REFUSE** |
| R2 — survives dropping SA | sign holds, 1.37 SE | — | pass |

### The hypothesis is not merely unsupported. The sign is the other way.

Pete's directional hypothesis, recorded before the test, was **LIB → ONP
exceeds ALP → ONP**. The pre-registered quantity says the opposite:

| per point of ONP deviation | coefficient | clustered ratio |
|---|---:|---:|
| excess **Coalition** loss | **+0.094** | +1.72 |
| excess **Labor** loss | **−0.169** | **−4.09** |

Positive excess means losing *less* than proportional. So within a cycle,
where One Nation gains more, **Labor loses more than proportional and the
Coalition loses less** — and the Labor effect is the one that clears
significance comfortably, at 4.09 SE.

### The confound was real and it was decisive

This is why the deviation adjustment was pre-registered rather than added later:

| specification | excess_LNP coefficient |
|---|---:|
| raw changes | **−0.309** |
| within-cycle deviations | **+0.094** |

**The raw version supports the hypothesis and the corrected version reverses
it.** Had the confound not been named in advance, this run would have
"confirmed" the prior — and the thing it was actually measuring is that the
Coalition lost the elections in which One Nation surged, which is not the same
claim.

### What this does NOT refute

**The seat-type asymmetry in
[../reviews/onp-seat-type-asymmetry-2026-08-25.md](../reviews/onp-seat-type-asymmetry-2026-08-25.md)
still stands as an observation.** SA 2026's five One Nation wins were all
Coalition-leaning; our six Victorian ONP seats are all Labor-leaning. That fact
is unchanged. What is refuted is **one proposed explanation for it** — that ONP
takes Coalition votes disproportionately at the district level.

The two are reconcilable, and the reconciliation is the next hypothesis rather
than a conclusion: in SA the Coalition fell **roughly uniformly** (a
cycle-level collapse, which deviations remove by construction), while One
Nation's district-level variation ate into Labor. A uniform Coalition collapse
from a high rural base, plus One Nation concentrated in rural seats, elects One
Nation in Coalition seats **without** any district-level Coalition-sourcing
effect.

**That cycle-level story cannot be identified from this corpus**: separating
"One Nation took Coalition votes" from "the Coalition lost that election"
requires between-cycle variation, and there are 7 cycles. Deviations were the
right control for the question asked and they structurally cannot answer this
one. Anyone attempting it should say so before starting.

### For the vote-sourcing matrix generally

The one cell tested came out significant in the **unexpected direction**
(ALP → ONP at 4.09 SE, not LIB → ONP). That is a reason to build the matrix
**from data rather than from priors about which flows are plausible** — the
prior here was confidently held, is the intuitive one, and does not survive the
confound control.

It is not a reason to adopt "ONP takes Labor votes" into the model either: one
cell, 7 clusters, and the level-versus-gradient ambiguity above all argue for
leaving the proportional assumption in place until a design exists that can
separate the two.

