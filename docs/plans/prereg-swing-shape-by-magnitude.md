# Pre-registration: does the right swing shape depend on the SIZE of the swing?

Written 2026-08-25, **before** anything is fitted. Committed before running.

Follows [prereg-onp-concentration-transport.md](prereg-onp-concentration-transport.md),
whose anchor failed for a reason that named this question.

## Why this is not a re-run of a settled question

[../reviews/swing-shape-2026-08-25.md](../reviews/swing-shape-2026-08-25.md)
already tested uniform against proportional on 2,878 (district, party)
observations and **uniform won: MAE 3.724 against 3.970.** That is not being
re-litigated.

What that test did **not** ask is whether the answer is the same for a 2-point
statewide move and a 17-point one. It pooled them. And the concentration run
showed a case where the pooled answer is badly wrong:

| MacKillop, Coalition share | |
|---|---:|
| 2022 actual | 67.0 |
| **uniform swing** (statewide −17.1) | **49.9** |
| proportional swing | 35.3 |
| **2026 actual** | **26.9** |

Uniform is out by **23 points**; proportional by 8. One Nation cannot win that
seat with 35% against a Coalition left at 49.9, which is exactly why the
concentration fix failed.

**The hypothesis: uniform is right for small statewide moves and proportional
becomes right as the move grows.** That is a different claim from either, and
it is not another version of "whose votes move where" — that line is exhausted
and is not revisited here.

## Corpus, stated before the criterion

The same one, already built: **2,878 (district, party) observations, 12
cycle-pairs, 5 regions**, restricted to parties contesting both elections
(`p_a >= 3`, statewide `>= 2`) so an entering party is not scored as a swing.

Twelve clusters, ~11 df, so the bar is **2.20 SE**, not 1.96.

## The estimand

For each observation compute the two prediction errors:

- `err_uniform = |d_seat − d_state|`
- `err_prop = |d_seat − p_a * d_state / sw_a|`
- **`advantage = err_uniform − err_prop`** (positive ⇒ proportional is better)

**Criterion: the coefficient of `advantage` on `|d_state|`, clustered on
cycle-pair.** A positive coefficient means proportional gains as the swing
grows, which is the hypothesis.

Reported alongside: the **crossover point** — the `|d_state|` at which mean
advantage turns positive. That is the practically useful number and the one a
blended rule would need.

## Decision rule, fixed now

Conclude that swing shape depends on magnitude **only if all three hold**:

1. Coefficient on `|d_state|` is **>= 2.20 clustered SE** and positive.
2. **Sign consistency in at least 8 of 12** cycle-pairs computed individually.
3. The **crossover lies inside the observed range** of `|d_state|`. A crossover
   beyond the data is an extrapolation, not a finding.

Otherwise nothing changes and uniform stands unconditionally.

## Refusal: what would make an apparent WIN unacceptable

- **R1 — it must not be South Australia alone.** SA 2022→2026 carries the
  largest swings in the corpus and motivated this. Re-run with SA excluded; if
  the coefficient loses its sign or falls below 1 SE, report that prominently
  and do not claim a general result.
- **R2 — it must not be a base-size artefact.** Large statewide swings may
  coincide with large parties, and proportional mechanically does better on
  large bases. **Control for `p_a`** and report with and without. If the effect
  does not survive, refuse.
- **R3 — small swings must be unharmed.** The premise is that uniform wins
  there. If proportional is also better at the smallest decile of `|d_state|`,
  the story is not "depends on magnitude", it is "the earlier test was wrong" —
  which would need its own investigation, not adoption here.
- **R4 — adoption is NOT authorised by this plan.** Establishing that the
  advantage grows with swing size does not establish that any particular
  blended rule beats uniform out of sample on the full corpus. That is a
  separate experiment with its own held-out design.
- **R5 — no seat-model change on this alone.** Even a clean result plus a
  validated blend would then need to be shown to fix the SA anchor (four seats
  at 0.000). Two steps, not one.

## What this cannot see

- **It is still first preferences.** Whether the count then elects the right
  party is downstream and untested.
- **`|d_state|` is measured per party-cycle**, so a cycle where one party
  collapses and another is flat contributes both, which is intended but means
  the clusters are not independent within a cycle.
- **It cannot say why.** A magnitude dependence could be a genuine behavioural
  fact or a ceiling/floor effect — a party on 67% has more room to fall in
  points than one on 20%. **That ambiguity is not resolvable here** and must be
  stated in any write-up.

## Prediction, written before running

Expect a **positive coefficient clearing the bar**, and a **crossover somewhere
around 8–12 points** of statewide swing — above typical Australian swings,
which is why uniform wins the pooled test, and below the −17 that broke
MacKillop.

Expect **R2 to be the live threat**, as it was for the proximity test: the
floor/ceiling mechanism in "what cannot see" is a real alternative explanation
and the size control is where it would show up.

---

## Result, 2026-08-25: REFUSED, with the sign REVERSED

`scripts/test_swing_shape_by_magnitude.R`. 2,878 observations, 12 cycle-pairs.

| criterion | required | got | verdict |
|---|---|---|---|
| coefficient, base-controlled | >= +2.20 SE | **−1.18** | **FAIL** |
| sign consistency | 8 of 12 | 6 | **FAIL** |
| crossover in range | yes | yes | pass |
| R1 — survives dropping SA | >= 1 SE | **+0.32** | **REFUSE** |

**The coefficient is negative.** Proportional does not gain as swings grow — it
gets **worse**, and worst of all exactly where the hypothesis said it should
win:

| decile | \|d_state\| | uniform MAE | proportional MAE | advantage |
|---:|---|---:|---:|---:|
| 1 | 0.1–0.4 | 2.706 | 2.735 | −0.029 |
| 5 | 2.5–3.7 | 4.427 | 4.322 | +0.105 |
| 9 | 7.9–11.0 | 4.465 | 4.348 | +0.117 |
| **10** | **11.3–20.3** | **4.776** | **6.591** | **−1.815** |

The top decile — the large swings this plan was built around — is where
proportional is beaten most heavily.

### I generalised from one seat, and one seat was not representative

The case that motivated this was MacKillop: Coalition 67.0 → 26.9, where
uniform is out by 23 points and proportional by 8. That is real. But South
Australia's own coefficient is **−0.503**, the most negative of all twelve
cycle-pairs, and dropping SA removes the effect entirely (+0.32).

**So proportional is worse on large swings even within the election containing
the seat that suggested otherwise.** MacKillop is an outlier inside its own
cycle, and reasoning from one worked example is what produced this hypothesis —
the failure mode `CLAUDE.md` records for exactly this reason.

### Where this leaves the SA anchor, and it is a better place

**No global swing rule captures MacKillop.** Uniform misses by 23, proportional
by 8, and even proportional is 8 points short of a 40-point collapse. The seat
is genuinely idiosyncratic.

That reframes the failure. Our model gives the Coalition **1.000** there. A
seat-specific collapse the central prediction cannot see is precisely what
**per-seat uncertainty** exists to cover — and SA's calibration slope is
**0.299**, badly over-confident. The model is not just wrong about MacKillop's
central value; it is far too sure of it.

**The next candidate is `seat_sd`, not the swing shape.** That is a different
part of the model from everything tried today, and it is consistent with the
one measurement that has been staring at this all along: a slope of 0.299 says
the seat-level distribution is much too tight, whatever the centre is doing.

**Do not test another swing rule.** Uniform has now survived proportional,
proximity-weighted, and magnitude-dependent variants. The central prediction is
not where the remaining error lives.
