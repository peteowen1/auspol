# The One Nation ordering was worse than no ordering. Replaced with a direct measurement.

Run 2026-08-20 against
[../plans/prereg-onp-allocation-federal.md](../plans/prereg-onp-allocation-federal.md),
committed before anything was scored. `scripts/test_onp_ordering_federal.R`.

**ADOPTED: order districts by their transposed federal One Nation vote.**
**ADOPTED separately: the renormalisation compression fix.**

## The old ordering was subtracting value

On NSW 2023, the only election with enough contested districts to score
(n = 17):

| ordering | Spearman vs actual | MAE after scaling to the true total |
|---|---:|---:|
| **A** — Greens share, as shipped | +0.331 | **3.287** |
| **B** — federal One Nation vote | **+0.814** | **1.594** |
| **C** — uniform, no ordering at all | — | 2.595 |

**A is worse than C.** The shipped rule — order by the Greens vote, quantile-map
onto South Australia — predicted One Nation's district ordering *less* well than
ignoring geography entirely. The repo already recorded it beating uniform by
"only 0.122 MAE"; on this test it does not beat uniform at all.

B more than halves the error.

## The signal it relies on is stable

Necessary before using federal 2025 to order Victorian 2026 districts: does
One Nation's federal geography persist between elections?

| pair | divisions | Spearman |
|---|---:|---:|
| 2019 → 2022 | 58 | **+0.876** |
| 2022 → 2025 | 145 | **+0.772** |

Earlier pairs have too few contested divisions to say (3 to 13). Where the
party stands consistently, where it is strong barely moves.

## The two changes, separated as N3 required

| arm | ONP expected seats | change | P(at least one seat) |
|---|---:|---:|---:|
| baseline: Greens ordering, compression as shipped | 3.11 | — | 0.896 |
| **federal ordering only** | 3.28 | **+0.17** | **0.878** |
| **compression fix only** | 3.65 | **+0.54** | 0.934 |
| both — adopted | 4.19 | +1.08 | 0.943 |

This split is the point of N3, and it matters: **the ordering change is worth
+0.17 seats and LOWERS One Nation's chance of winning any seat.** No one-way
ratchet. The spread increase belongs to the compression fix, which is
arithmetic, and would have been credited to the new ordering had the two been
bundled.

N4 passes: +1.08 against a 2.0 stop.

## The compression fix

Setting One Nation and then dividing each row by its total shrank the spread by
**13.7%** — a district allocated a high share has a larger row total, so
renormalising cut it hardest. The quantile map produced a CV of 0.327, matching
South Australia's 0.334 as intended, and normalisation reduced it to 0.283.

Now the other parties are scaled to fill exactly what One Nation leaves, so the
row already sums to 100. Verified in the run log: **target CV 0.327, delivered
0.327.**

## Published effect

| | before | after |
|---|---|---|
| ALP seats | 40 (90%: 23–51) | **41** (90%: 23–51) |
| Greens seats | 5 (90%: 3–7) | **4** (90%: 2–6) |
| One Nation seats | 3 (90%: 0–8) | **4** (90%: 0–9) |
| Coalition seats | 38 (90%: 29–55) | 38 (unchanged) |

444 tests pass, `R CMD check` 0 errors and 0 warnings.

## What this does not do, and N2 held

- **N2 held.** Agreement with YouGov motivated the investigation and was
  explicitly not the criterion. The NSW test decided. For the record the gap
  narrows — One Nation 3 to 4 against their 17 — but that is a consequence, not
  evidence.
- **The statewide level is untouched.** Federal One Nation was 5.3% in Victoria
  against a state forecast near 20%. Only shape transferred, and a better
  distribution of a wrong total is still wrong.
- **N1 held.** No level and no spread were fitted. 33 observations across three
  elections, every one conditioned on the party choosing to stand, cannot
  support it.

## The limitation that stays, and it is real

**One election, 17 districts.** Today the independent-emergence model looked
like a 1.46 SE improvement on 88 NSW seats and turned into a 2.52 SE
degradation on 886 federal ones. This test is smaller than that one.

Three things argue it is not the same situation:

1. The effect is **large** — Spearman 0.331 to 0.814, MAE halved — not a
   marginal edge.
2. The mechanism is **transparent**: measuring where a party actually polled
   beats inferring it from a different party's vote.
3. **The incumbent option loses to doing nothing.** Even if B were noise, A is
   demonstrably worse than a uniform allocation, so keeping A was not the safe
   choice it looked like.

**N5 stands unaddressed.** Every observation is a district One Nation chose to
contest, and the Victorian model gives them a vote in all 88 seats. That is
plausible at 20% statewide polling and would be badly wrong in a cycle where
they stood in twelve seats. Nothing here tests it.
