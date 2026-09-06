# Pre-registration: `shrink` versus the surge mixture, on seventeen pairs

Written 2026-08-25, **before any arm was run on the five-harness set**.
Committed before running.

## Why this is worth re-running

The surge mixture was refused on 2026-08-25 (`docs/reviews/surge-refused-2026-08-25.md`).
That verdict was reached on the **federal corpus alone**, six pairs, where the
across-election sign test bottoms out at **p = 0.125** however cleanly the arms
separate. It was refused on a real gate — the eight named seats reached a mean
probability of 0.0054 against a 0.01 threshold — but its aggregate behaviour was
judged with almost no power.

`backtest_candidate_wa.R` adds **seven pairs**. The set is now:

| harness | pairs |
|---|---:|
| federal | 6 |
| WA | 7 |
| Victoria | 2 |
| NSW | 1 |
| SA | 1 |
| **total** | **17** |

**Seventeen clusters changes what is decidable.** A two-sided sign test over 17
elections reaches p = 0.0000153 if all agree and **p ≈ 0.049 at 13 of 17** — so
for the first time an across-election result can clear 0.05 on its own. Every
criterion written in this repo before today was arithmetically incapable of
that.

## The competing mechanisms

- **A — flat `shrink = 0.10`.** The incumbent. A per-draw coin toss between the
  final two, which caps every seat at `1 - s/2` = 0.9598 measured.
- **B — surge only** (`surge_h = 0.0508`, `N(+15.6, 6.1)`, floor 2%,
  `shrink = 0`). Generative: the strongest eligible non-major's share is raised
  and the count decides, so a surge that falls short loses and no ceiling is
  imposed.
- **C — surge plus a reduced `shrink = 0.05`.** The hypothesis that the two are
  complements: the surge supplies the fat tail the majors cannot produce, and a
  smaller coin toss covers the residual over-confidence the surge does not
  touch. **Named here in advance precisely because reaching for it after seeing
  A and B would be the rationalisation pattern.**
- **D — neither.** The floor, to keep the others honest.

## Criterion

All five harnesses, 5,000 sims, `fallback_smooth = 0.60`, `flow_sd = 3.65`,
`party_sd` at whatever the concurrent experiment settles on (stated in the
result, identical across arms).

**Primary — reliability, pooled across all 17 pairs.** Buckets outside their own
95% binomial CI. Arm A currently scores 0 of 6 on federal. **The winner must
score 0 outside, and among arms that do, the one with the highest top bucket
wins.** Resolution is the point: A caps at 0.9598 and puts nothing above 0.99.

**Secondary — paired per-seat log score, sign test across the 17 pairs.** An arm
beats another only if it wins **13 or more of 17** (p ≈ 0.049). Anything from
9-of-17 to 12-of-17 is **explicitly a tie**, not a narrow win, and will be
reported as one.

**Guard — accuracy.** Whole-seat and therefore weakly powered; it may only
REFUSE, never justify adoption. Pooled accuracy must not fall by more than 1.0
percentage point.

## Refusal — what disqualifies a winner

- **If the eight named federal misses stay below 0.01** — Denison, Lyne,
  Melbourne, Fairfax, Indi, Warringah, Curtin, Fowler — the mechanism is not
  doing the job it was built for, whatever the aggregate says. This is the gate
  the surge already failed once and it is not being relaxed.
- **If any seat exceeds 0.995.** The best observed bucket wins 97.2%; nothing in
  this corpus supports a higher claim.
- **If confidently-wrong seats (`pred_p > 0.95` and wrong) increase**, the arm is
  buying resolution with exactly the errors these mechanisms exist to prevent.
- **If arm C wins only because `shrink` was lowered** — i.e. C beats A but B is
  no better than D — then the finding is about the `shrink` value, not about the
  surge, and must be reported that way rather than as "the surge works".
- **If the WA pairs drive the result alone.** WA contributes 7 of 17 clusters and
  two of its pairs are compromised (`wa2001` has no transfers of its own,
  `wa2008` scores 67% of the chamber). Re-check the verdict excluding WA; if it
  reverses, report both and adopt neither.

## What the criterion cannot see

- **Seventeen pairs are not seventeen independent draws of the same process.**
  WA 1996 and federal 2025 are thirty years apart with different party systems.
  The sign test treats them as exchangeable and they are not.
- **Coverage varies by pair.** WA 2008 is scored on 38 of 57 seats. A mechanism
  that helps most in the seats that dropped out would be invisible.
- **Nothing here tests Victoria 2026**, which is the live target, and Victoria
  contributes 2 of 17 clusters.
- **The surge size is truncated by construction** — fitted on seats that gained
  at least 10 points — so it understates small surges and cannot reach the
  +26.3 median that the eight named seats actually required.
- **None of these mechanisms can see a candidate who did not stand last time.**
  That is the structural finding from the refusal and it is unchanged by more
  data.
