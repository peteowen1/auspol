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
