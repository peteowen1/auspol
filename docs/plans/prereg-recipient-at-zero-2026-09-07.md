# Pre-registration: a named recipient at zero share still takes the surge (P4c)

Written and committed 2026-09-07 BEFORE any code. Follows P4b
(`prereg-surge-recipient-2026-09-06.md`, shipped). Baseline: the published
configuration at `d85c21d` (PR #28 on `main`), 20,000 draws.

## The defect, measured

`simulate_seat_contests()` drops a named recipient back to the default rule
whenever that class's simulated share in the draw is at or below zero:

```r
j0 <- surge_party_idx[i]
if (!is.na(j0) && v[j0] <= 0) { j0 <- NA_integer_; ... }
```

The diagnostic added by the review gate measured it on its first run:
**275,205 of 3,000,000 seat-draws on fed2022, and 57,510 of 940,000 on
sa2026.** A class that polled 1.3% last time (Goldstein's independents) is at
or below zero in most draws once `level_sd` noise is applied, so the surge
the hazard bought for the independent is handed to the Greens in exactly the
seats P4b was written to fix. Of 150 fed2022 seats, 76 give the independent
class p = 0 exactly.

The floor (`surge_floor = 2`) exists to stop a party polling near nothing
taking a double-digit gain by the DEFAULT rule, where the recipient is
whoever happens to be largest. It should not gate a recipient the hazard
named from that candidate's own salience: an emergence from nothing is the
case the mechanism exists for.

## The change

One switch, `AUSPOL_SURGE_FROM_ZERO` (published 0 until this decides). When
1, a named recipient takes the surge regardless of its share in the draw:
the `v[j0] <= 0` demotion is removed, and the surge is added to that class
from whatever base it holds (the existing `pool_v > add` guard still refuses
a surge larger than the rest of the seat). Both engines; a test asserting
they stay identical. Nothing else changes: not the hazard, not its scale,
not the default rule, not the floor for unnamed recipients.

## Targets (primary), fed2022 at the shipped baseline

Goldstein 0.017, Fowler 0.010, North Sydney 0.025, Curtin 0.034, Kooyong
0.044, Mackellar 0.054; Wakehurst and Kiama in NSW. A working change lifts
each roughly toward its hazard (0.025-0.045 per draw, so p(win) of that
order or higher), and the top-ranked above 0.10 without a scale.

Dry run on known cases: Clark 2022 and Melbourne 2013, where the hazard
names a Green who already holds a real share, must not move at all (their
recipient was never demoted). Cowper and Mallee 2022, where the independent
is the largest non-major anyway, must not move. If either moves, the
implementation reaches further than the demotion it removes.

## Guards, all 17 elections (Pete's objective)

- Pooled seat-weighted log loss must improve by more than one SE of the
  paired per-election differences; pooled seat-share RMSE must not rise by
  more than 0.1 point.
- The false-independent list (Kennedy 2013, Lyne 2013, New England 2013,
  Goldstein 2025) must not grow.
- Returning-incumbent independent and Greens-won seats: no fall beyond 0.02;
  the Greens' total log cost must not exceed the independents' gain.
- Per-election table: not carried by fed2022 alone.

## Refusal, decided in advance

Refused if any guard fails, or if the pooled gain does not clear one SE, or
if the targets rise only into the clamp (nothing above 0.05). **And refused
if the gain comes with a class that polled zero last time winning seats it
should not**: report the count of seats where a class with no prior vote
takes p > 0.10, baseline against arm, and refuse if it rises by more than
the number of genuine emergences gained.

## What this cannot see

Whether the hazard is on the right seats. It amplifies whatever the hazard
says in the seats where the recipient was being demoted, which is most of
them. If the arm wins, the calibration experiment (P4d) is the one that
decides how large these probabilities should be.

## Result, 2026-09-07 — REFUSED, and the reason is a rescue nobody designed

All 17 elections, 20,000 draws, against the shipped P4b baseline:

| election | P4b (ships) | P4c | move |
|---|--:|--:|--:|
| fed2010 | 0.3281 | 0.3246 | −0.0035 |
| **fed2013** | **0.3864** | **0.4199** | **+0.0335** |
| fed2016 | 0.3154 | 0.3135 | −0.0019 |
| fed2022 | 0.3862 | 0.3826 | −0.0036 |
| nsw2023 | 0.2970 | 0.2956 | −0.0014 |
| others | | | ≤0.0006 |
| **pooled, 1,549 seats** | **0.3422** | **0.3444** | **+0.0022** |

Better in 7 of 17 and worse overall, because **the whole loss is one seat**:
Fairfax 2013, where Clive Palmer's party won and the hazard had named a
different class. Under P4b the default rule (largest non-major) handed the
surge to Palmer by accident; under P4c the named recipient takes it always,
so the rescue disappears and the seat costs 5.30 log points on its own.

The demotion count went to zero as intended (275,205 → 0 on fed2022) and the
targets moved exactly as far as the mechanism allows: Goldstein 0.017 →
0.022, Fowler 0.010 → 0.015, the rest within 0.002. **That is the finding:
with the demotion gone, a seat's win probability equals its hazard.** The
hazard, not the wiring, is now the whole constraint.

**Refused per the pre-registration** (pooled gain negative). The switch
`AUSPOL_SURGE_FROM_ZERO` stays at 0, kept because a per-class surge (below)
would change the trade-off it lost on.

## And the calibration experiment is answered before running it

Out-of-fold predicted hazard against realised outcome, 1,920 seat-classes
and 20 winners over nine election pairs:

| predicted band | n | mean hazard | winners | actual rate |
|---|--:|--:|--:|--:|
| top 2% | 38 | 0.173 | 6 | 0.158 |
| 2–5% | 58 | 0.051 | 3 | 0.052 |
| 5–10% | 96 | 0.039 | 5 | 0.052 |
| 10–25% | 293 | 0.017 | 4 | 0.014 |
| 25–50% | 475 | 0.007 | 2 | 0.004 |
| bottom half | 960 | 0.002 | 0 | 0.000 |

**The hazard is calibrated in every band.** Rescaling it can only make it
worse, which is why x2, x4 and x8 all lost. Goldstein's 0.025 is not an
under-estimate: seats that look like Goldstein did in the data available
before the 2022 election won about 5% of the time.

So the gap to AE Forecasts' 0.28–0.51 on those seats is not calibration and
not wiring. It is **information the model does not have**. Two candidates,
both testable, in order of cheapness:

1. **A wave term.** In 2022 six teal-shaped candidates won at once. An
   election-level feature — how many high-salience non-major challengers this
   cycle carries, computable from the salience corpus before polling day and
   so leakage-free — would let the model raise them together instead of
   treating each as an independent 5% draw. This is the next pre-registration.
2. **Exogenous information**: seat polls or market odds, which is what AEF's
   0.3–0.5 most likely reflects. Pete's call, since it is a different kind of
   input to the model than anything used so far.
