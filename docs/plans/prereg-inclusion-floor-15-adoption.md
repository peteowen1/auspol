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
rather than the four independent hardcoded `8`s this repo's own
`docs/CONSTANTS.md` already flagged as a sister-copy risk
(`fit_vic.R:115,184`, `fit_nsw.R:84,164`).

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
