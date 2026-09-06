# Pre-registration: adopting the party-inclusion floor at 15

Written 2026-08-24, **before** the constant is changed in code. Re-opens
[prereg-party-inclusion-floor.md](prereg-party-inclusion-floor.md), whose
result [../reviews/inclusion-floor-2026-08-19.md](../reviews/inclusion-floor-2026-08-19.md)
named its own refusal a deviation: floor 15 cleared that plan's decision rule
by three times the adoption bar and was refused anyway, on an anchor written
into the same commit as the result rather than before it. That write-up's own
words: *"the two honest options are to accept the deviation on its merits, or
to adopt floor 15 as the rule required and re-open the question properly with
the anchor pre-registered. What must not happen is the refusal quietly
becoming precedent."*

## Pete's ruling, 2026-08-24

Adopt floor 15. Re-run with the anchor pre-registered this time, so the
exception is a documented, deliberate choice, not something that becomes
precedent quietly.

## What is NOT being re-litigated

The MAE comparison itself. The original grid, criterion and decision rule
already ran honestly, scored on the rows every floor fits (the row-count
confound the first pass missed is fixed in `scripts/test_inclusion_floor.R`).
**Re-run today, 2026-08-24, for a fresh record** — not assumed from the
2026-08-19 numbers:

| floor | MAE | vs floor 8 |
|---:|---:|---:|
| 5 | 1.8854 | +0.0692 |
| 6 | 1.8547 | +0.0385 |
| 7 | 1.8396 | +0.0234 |
| **8** | **1.8162** | — |
| 10 | 1.8106 | −0.0056 |
| 12 | 1.7910 | −0.0252 |
| **15** | **1.7556** | **−0.0606** |

Byte-identical in shape to 2026-08-19 (expected: the scored rows are all
completed historical cycles, whose poll histories cannot change). Floor 15
still clears the 0.02 adoption bar by three times over, monotonically, on
`OTH` too (2.4530 → 2.2004), not as an isolated spike.

## What IS being fixed: the anchor, examined and disclosed BEFORE adoption

`scripts/test_inclusion_floor.R`'s `IF6` check — "refuse a floor that drops
a party polling >= 5% in a live cycle" — stays exactly as it is and is **not**
being weakened. It still fires, mechanically and correctly:

```
IF6  ANCHOR FAILS: floor 15 would drop nsw ONP (21.0% on 8 polls)
IF5  verdict: REFUSE floor 15: it clears the MAE bar but drops a party
     polling in double digits. The criterion cannot see that.
```

What changes here is that this specific, single anchor failure is examined in
full and either accepted or refused **in advance of the code change**, rather
than the refusal being taken automatically or the anchor being loosened to
avoid it. Checked directly today against every live cycle the script tracks:

| cycle | party | polls | mean share | fitted at 8 | fitted at 15 |
|---|---|---:|---:|:--:|:--:|
| Victoria 2026 (LIVE, published) | ONP | 19 | 22.34% | yes | yes |
| federal 2028 | ONP | 145 | 21.82% | yes | yes |
| **NSW 2027** | **ONP** | **8** | **21.00%** | yes | **no** |

Floor 15 drops exactly one (region, year, party): One Nation from the NSW
2027 cycle. No other live-cycle party at or above the 5% anchor threshold is
affected.

## Why the failure is accepted here

1. **Victoria 2026 is this repo's only published forecast**, and it is
   unaffected. ONP clears floor 15 by 4 polls. Nothing on the live page
   changes as a result of this constant.
2. **NSW 2027 is not a currently-published forecast.** `fit_nsw.R` covers it
   as validation/backtest infrastructure, one cycle of which (2023) is
   already historical. Losing ONP there degrades a number nobody is reading
   as a forecast today, not the live one.
3. **The exclusion is not permanent or hand-picked.** `cnt >= 15` is
   evaluated fresh from each cycle's own poll count; if NSW's ONP series
   reaches 15 polls before 2027, it resumes being fitted automatically. This
   is a threshold every cycle clears or doesn't on its own terms, not a
   one-off carve-out for NSW.
4. **The MAE evidence for floor 15 is not an artefact of NSW 2027**
   specifically. The 2026-08-19 review already traced the mechanism: floor
   15 wins because it matches the coarser granularity of the eventual-results
   record, which mostly does not break out minor parties — a property of the
   whole 33-cycle corpus, not of the one cycle being sacrificed here.

## Decision

**ADOPT floor 15** for the state scripts (`fit_vic.R`, `fit_nsw.R`). Federal's
25 remains untouched and untested by this — restating the original plan's
scope, not silently expanding it.

Implementation: introduce a single named constant (`PARTY_INCLUSION_FLOOR`)
at the two sites per script that decide which parties are FITTED in a cycle
(`fit_vic.R:184,196`, `fit_nsw.R:164,177`) — the ones `docs/CONSTANTS.md`
already flagged as a sister-copy risk. `fit_vic.R:115` and `fit_nsw.R:84`
each carry a *separate* `parties_in(cp, n = 8)` default, used only to select
which parties enter the validation-cycle noise-factor estimation
(`estimate_firm_factors()`), not the live fitted set. Deliberately left at 8
in BOTH scripts, not just Victoria's — see the addendum below for why that is
currently safe rather than merely assumed to be.

## What would still refuse this, stated now so it can't be invented later

- If Victoria 2026's own ONP count is re-checked at ship time and has fallen
  below 15 (today it is 19 and rising) — the live forecast being unaffected
  is the entire basis for accepting the NSW loss, so this is load-bearing.
- If a SECOND live-cycle party beyond NSW ONP is found lost by floor 15 —
  checked above against `IF6`'s own output and none found, but re-checked at
  ship time rather than assumed stale.
- This is a **one-time, fully disclosed override of one named anchor
  failure**, not a change to the anchor rule itself. `IF6` stays wired into
  `scripts/test_inclusion_floor.R` and will refuse any FUTURE floor change —
  including pushing past 15 — that drops a live-cycle party, with no special
  exemption carried forward from this decision.

## Result

Implemented 2026-08-24. `PARTY_INCLUSION_FLOOR <- 15L` added to `R/scales.R`
beside `BINOMIAL_REF_N`; all four `fit_vic.R`/`fit_nsw.R` call sites now read
it instead of a hardcoded `8`. `docs/CONSTANTS.md` updated to record the
adoption and point here instead of at the 2026-08-19 refusal.

## Addendum, post-commit review (2026-08-24)

Reviewed against the actual running scripts, not just the diff — original
clause above left unedited; this adds to it rather than replacing it.

**"Victoria 2026 is unaffected" is true for the LIVE forecast and verified the
strongest way available**: `fit_vic.R` run at floor 8 and floor 15 produces a
byte-identical `output/trend-vic-2026.csv`. But **the 2022 VALIDATION cycle
does move**: UAP (8 polls in that cycle) is fitted separately at floor 8 and
folds into `OTH` at floor 15, which shifts `OTH`'s 2022 cycle level
(14.7→14.3) and, because `derive_tpp()` no longer needs UAP's own trend
(which stopped 13 days early), extends the derived 2022 TPP series to the
full campaign. The reported V3 anchor check moves 56.57→56.39, comfortably
inside its `[52, 58]` bound — nothing breaks — but this plan's live-cycle-only
table structurally could not see it, because it only examines vic 2026, nsw
2027 and fed 2028. Recorded so "unaffected" isn't read more broadly than the
live number it actually means.

**The `parties_in(n = 8)` twin exists in BOTH scripts, not just Victoria's**,
and NSW's copy (`fit_nsw.R:84`) is called directly on the live 2027 cycle —
which looks, on the surface, exactly like the Q3 risk this plan worried about
(a party excluded from the live fit but still feeding the pooled noise-factor
estimate off a different threshold). Traced and confirmed currently inert:
`parties_in()` only subsets `est_parties`, itself gated by `counts >= 20`
total polls across BOTH cycles combined — and NSW's ONP never reaches that
(7 + 8 = 15), so it is never in `est_parties` in either script regardless of
which inclusion floor applies to it. Safe today, but the safety rests on
`est_parties`'s current composition, not on anything enforced — worth knowing
if a minor party's total poll count ever climbs past 20.

## REVERTED, 2026-08-24, same day

Pete's re-examination, on seeing the actual mechanism in plain terms: a
party polling in the twenties folding into `OTH`, where it cannot be told
apart from the rest, is not acceptable — even confined to an unpublished
cycle, even as a disclosed, bounded, self-resolving cost. **Floor reverts to
8.** The adoption above is left unedited, not deleted: it was a real,
considered decision, correctly disclosed, and still overturned once its
concrete consequence was put plainly rather than summarised as "NSW 2027 is
unaffected [as a live forecast]."

What survives from this round: `PARTY_INCLUSION_FLOOR` as a single named
constant (`R/scales.R`) replacing four independent hardcoded `8`s, which
`docs/CONSTANTS.md` had already flagged as a sister-copy risk — kept at its
reverted value, 8. `scripts/test_inclusion_floor.R`'s `IF6` anchor stays
wired in and unweakened, exactly as it was before this round started: it is
what surfaced this cost in the first place (2026-08-19) and would surface it
again for any future attempt at this floor.

**The lesson, stated plainly rather than left implicit**: an anchor that
"only" costs an unpublished validation cycle is still a real cost, and
disclosing it in advance makes the decision honest, not automatically right.
Pre-registration answers "was this decided fairly," not "was this the
correct call" — those are different questions, and this plan confused having
answered the first for having answered the second.

**One side effect of the revert, not caused by it**: `fit_nsw.R` now halts
again on NSW 2027's pre-existing `NL3` breach (`ONP fitted 19.52 against
24.67`) — already documented in `docs/NEXT-STEPS.md` as "NSW 2027 keeps CI
red," caused by a different, untouched constant (`fit_nsw.R:132`'s per-cycle
walk threshold, `cnt >= 15`, unrelated to `PARTY_INCLUSION_FLOOR`). Floor 15
incidentally silenced this by not fitting ONP in that cycle at all; floor 8
restores the original, already-known-red behaviour. Not a new problem and
not fixed here — it already had its own line in `NEXT-STEPS.md`: "needs a
threshold decision made before, not after, seeing NSW breach."
