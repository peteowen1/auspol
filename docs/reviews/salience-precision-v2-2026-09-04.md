# The salience gate's precision criterion: replaced, and it passes

2026-09-04. Scores `docs/plans/prereg-salience-precision-v2.md`, committed at
`6443e73` before this scorer existed. `scripts/test_salience_precision_v2.R`.

**Criterion 1 passes. This C2 replacement clears its bar.**

## Result

| | required | observed | verdict |
|---|---|---|---|
| **C1 (replacement)**: gated RMSE, fed2025, vs base | must not worsen by more than +0.37 | **−0.410** (improves) | **PASS** |
| C2 (informational): sign agreement on moved predictions | p < 0.05, agreement > 50% | 57.4% of 331, p = 0.008 | clears, not decisive |
| dry-run: Boele stays ungated | zero effect | base = pred = 22.86 | PASS |
| dry-run: Dai Le moves toward actual | gated, error shrinks | base error 27.66 → pred error 14.43 | PASS |
| refusal: coefficient near zero | must not be ~0 | t = +12.72 | not triggered |

331 gated fed2025 rows across 141 seats, all confirmed zero true emergences
(`sum(emerg) == 0`, asserted in the script rather than assumed).

## The honest wrinkle, reported because the aggregate alone would hide it

**By seat count, more seats got slightly worse (78) than got better (63).**
The aggregate RMSE improves because RMSE weights squared error, and the gain
is concentrated in the seats with the largest swings — exactly the emergence-
adjacent cases the gate exists to catch (Ben Smith/Flinders, Kate Hulett/
Fremantle, Peter George/Franklin, from the sizing pass that fed this
document). The 78 "worsened" seats are mostly small movements in ordinary
minor candidates where the gate nudged a prediction a fraction of a point the
wrong way — none of it large enough to move the aggregate, all of it real.

**This does not trigger the pre-registered refusal.** That clause named the
failure mode as gain concentrated in "one or two seats [driving everything]
while [most] are flat" — 63 improving seats is broadly shared, not a handful
of outliers. But 63-of-141 improving against 78-of-141 worsening is a real
trade-off worth stating plainly rather than only quoting the favourable
aggregate, which is what the old, threshold-based C2 never let anyone see in
the first place.

## What this settles and what it does not

**Settles**: the salience gate does not damage the bulk of ordinary gated
candidates on an election built to test exactly that (zero true emergences,
so nothing in the gated subset *should* move toward truth by construction —
any net improvement is either real signal on near-misses like the sizing
pass's flagged cases, or noise, and the RMSE test says it is not damaging
either way).

**Does not settle**: whether the gate ships. C1 of the *original* document
(`prereg-salience-emergence-gate.md`) already passed on 2026-08-27. C3, the
real positive test — mean absolute error on 8 held-out federal emergences
from 2010–2019 — has never run; the data needs its own fetch, chained in time
on candidates appearing across separate Trends windows since Google collapses
to monthly buckets past roughly five years, per that document's own note.
**That fetch is the next thing this thread needs, not another criterion.**

## What this cannot see

Same limits `prereg-salience-precision-v2.md` names in advance: scored
against `salience-v5.csv` (20 elections, non-majors only) rather than the
now-current `salience-v6.csv` (22 elections, majors included) deliberately,
so this result is not confounded with a corpus change; the by-seat clustering
assumes gated rows are exchangeable within a seat, unverified against an
alternative clustering; and Criterion 2's binomial test has no correction for
the cross-seat correlation Australian electorates actually carry, which is
exactly why it was pre-registered as informational rather than decisive.
