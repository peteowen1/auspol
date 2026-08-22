# Pre-registration: Western Australia without its three-cornered seats

Written 2026-08-22, **before anything is measured**. Committed before running.

**This is the THIRD attempt at the same question**, and that fact changes the
bar rather than being a footnote. See "Multiplicity" below.

## Where this comes from

`reviews/wa-flows-2026-08-21.md` refused Western Australia's transfers at
−1.57 SE and diagnosed why: WA runs Liberal **against** National, so the pair
surviving the late rounds is often two Coalition candidates and nearly every
transfer resolves to LNP by construction. The pre-registered fallback dropped
WA's Coalition-origin exclusions and did worse (−2.23 SE), because the artefact
is not confined to the LNP row — `ALP → LNP` is 68.0% in WA against Victoria's
23.8%, in a row that fallback leaves untouched.

The remedy the diagnosis actually points at is to drop the **seats**, not the
rows. That idea was conceived *after* seeing the result, which is exactly why it
gets its own plan instead of being folded into the last one.

## What changes

A Western Australian seat is **three-cornered** when both a Liberal (`LIB`) and
a National (`NAT`, `NATS`, `NP`) candidate contested it. Every exclusion event
in such a seat is dropped; the rest are pooled as before.

| | value |
|---|---:|
| three-cornered seats | **109 of 466 (23%)**, rising from 12% in 1996 to 34% in 2025 |
| exclusion events surviving | **1,141 of 1,658 (69%)** |
| One Nation exclusions surviving | **102 of 161** |

**The cost puts the point of the exercise at risk**: One Nation exclusions, the
scarcest input the model has and the whole reason Western Australia was fetched,
fall by 37%.

## The rows, measured now, before any arm runs

| row | Victoria | current pool | WA all | WA non-3C | pooled + non-3C |
|---|---:|---:|---:|---:|---:|
| LNP → LNP | 38.8 | 16.3 | 55.8 | **0.0** | 13.4 |
| ALP → LNP | 23.8 | 30.8 | 68.0 | 14.2 | 27.3 |
| ALP → GRN | 25.3 | 16.0 | 2.0 | **0.0** | 12.6 |

Two of these argue **against** the remedy and are recorded here so they cannot
be discovered later and presented as insight:

- **Victoria's own `LNP → LNP` is 38.8%, higher than the pool's 16.3%.**
  Victoria *has* three-cornered contests. Dropping Western Australia's takes the
  pooled rate **down** to 13.4%, further from the jurisdiction being forecast,
  not closer. The remedy fixes an artefact by deleting a phenomenon the target
  genuinely exhibits.
- **`ALP → GRN` in non-three-cornered WA seats is 0.0%**, against Victoria's
  25.3%. Dropping the three-cornered seats does nothing about this, and the
  pooled rate moves from 16.0 to 12.6 — again away from Victoria. So a second,
  unaddressed way in which WA is unlike Victoria survives the fix.

## The competing explanation, which this experiment does not test

The flow matrix is keyed on party class **and survivor set**. If that
conditioning were fine-grained enough, a contest whose survivors are two LNP
candidates would occupy its own cell and could not contaminate any other. That
it evidently does contaminate them suggests **the survivor-set conditioning is
too coarse**, and that the fault is in the matrix rather than in Western
Australia.

If so, filtering seats is treating a symptom, and a third negative result would
be evidence for that reading rather than another fact about WA. **Stated now**,
so that outcome counts as information instead of a disappointment.

## What is measured

Unchanged from `prereg-wa-flows.md`: **per-seat log score, leave-one-election-
out, clustered on the election**, nine elections, 8 df. New South Wales stays
out. Reported alongside: accuracy, and the One Nation seat range for Victoria
2026.

## Multiplicity, and the bar it sets

Two arms of this question have already been scored (WA whole, −1.57 SE; WA minus
Coalition-origin rows, −2.23 SE). This is a third look at the same data for the
same decision, and three looks find a favourable one more often than one look
does.

So the bar is **stricter than the 2 SE used before, not equal to it**:

- **Adopt only if the clustered difference exceeds 2.5 SE**, and only if it is
  positive in at least 6 of the 9 elections. The previous arms managed 3 and 1.
- **The under-2-SE "adopt anyway" clause from `prereg-wa-flows.md` does NOT
  carry over.** There it was justified by a data-coverage argument — more One
  Nation evidence is better than less. That argument is unavailable here,
  because this arm *reduces* One Nation exclusions from 161 to 102. Removing the
  clause is a tightening, which is the safe direction.
- **If it lands between 0 and 2.5 SE, refuse and close the question.** A third
  filter producing a third inconclusive number is not a reason for a fourth
  filter.
- **If negative, close it.** Western Australia's transfers do not pool, and the
  next work belongs on the survivor-set conditioning above, which is a different
  question needing a different plan.

## Refusals

- **T1 — the control.** `AUSPOL_WA_CUTOFF=1990-01-01` with the flag on must
  reproduce the baseline byte-for-byte, as W1 did. Same reasoning: WA's earliest
  election predates every backtest election, so there is no naturally-empty
  admission to serve as a control.
- **T2 — the seat flag must be measured, not assumed.** The three-cornered
  marker is derived from the raw candidate codes in the WAEC payload, and the
  fetcher must **emit it and print the per-election counts** so the run shows
  what it applied. A flag that silently marked nothing would make this arm
  identical to the already-refused WA-whole arm, and the two would be
  indistinguishable by their scores alone. The scorer aborts on byte-identical
  arms; that is the check, not the log line.
- **T3 — `ALP → GRN` must not move further from Victoria.** It is 16.0 pooled
  today against Victoria's 25.3, and this arm is projected to take it to 12.6.
  **If the adopted arm leaves that row further from Victoria than the baseline,
  stop and report even on a winning score.** This is the directional side effect
  `CLAUDE.md` requires be named in advance, and it is named knowing it is
  already expected to fire.
- **T4 — the live forecast.** If any party's Victoria 2026 median moves by more
  than 2 seats, stop and report rather than ship.
- **T5 — no re-cutting the definition.** Three-cornered means both a Liberal and
  a National contested, decided now. Widening or narrowing it after seeing the
  result — to seats where both survived to the final two, say — is a fourth arm
  and needs a fourth plan.

## What this cannot see

- **Whether the survivor-set conditioning is the real fault.** See above; this
  experiment cannot distinguish "WA is unlike Victoria" from "the matrix
  conditions too coarsely", and a negative result is consistent with both.
- **Whether 23% of WA seats is enough to matter either way.** The filter removes
  31% of the exclusion events, so a null result may mean the remedy is right and
  the remaining data too thin, rather than the remedy being wrong.
- **Anything about the One Nation allocation**, still fitted on one election.
