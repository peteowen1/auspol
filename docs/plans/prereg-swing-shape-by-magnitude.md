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
