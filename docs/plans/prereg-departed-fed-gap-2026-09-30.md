# Pre-registration: departed-member federal-booth blend, at full size and with a gap-dependent weight

Written 2026-09-30 19:20, before any rebuild under either arm. Follows
`prereg-departed-fed-booths-2026-09-30.md` (DF, refused: departed seats'
error 4.553 -> 4.572), whose result section named the gap-dependent weight
as the next test and said it needed its own prereg.

## Why DF is re-run too

DF was measured while `departed_fed_apply()` added the move and then
rescaled the whole row, handing back about half of it (the leader-bonus
defect, fixed in v55 by `.shift_cell()`). So DF was a half-strength version
of its own fitted weight. Arm A measures it at full size; arm B adds the gap.

## The arms (both xgb layer only, state harnesses with a booth map, and live)

- **A, `AUSPOL_DEPARTED_FED=1`**: DF unchanged except applied at full size.
- **B, `AUSPOL_DEPARTED_FED=gap`**: the weight is `b0 + b1 * |gap| / 10`,
  clamped to [0, 1]. `b0`, `b1` by least squares through the origin of
  `actual - pred` on `(dx, dx * |gap| / 10)`, `dx = fed + k * gap - pred`,
  on departed seats of elections BEFORE the target only; sandwich SE
  clustered on election; each coefficient shrunk `b^3 / (b^2 + se^2)`.

Dry run of the fitted weights (no outcomes looked at, 2026-09-30 19:10):
vic2026 `b0 -0.005, b1 0.292` (raw b1 0.328, SE 0.116, n 77), so Bendigo
East (gap 18.5) gets 0.53 and a gap of 5 gets 0.14. qld2020 has only two
earlier elections (n 21) and fits `b1 2.04`, which clamps every seat with a
gap over 6.6 to a full move: the early-evidence case, left as fitted.

## Measurement

Each arm: rebuild from stage 6 on top of v55
(`output/snapshots/20260930-1807-3c1a1db-from6`, stages 1-5 from v54's
full rebuild). Scored with the DF scorer (paired, same seats).

1. **Primary (targeted)**: departed seats' incumbent-class primary, mean
   absolute error, paired against v55, all eight state elections with a
   booth map. Must improve by more than 1 SE.
2. **Guards**: published ledger seat log loss not worse by more than 0.001;
   seat log loss over all seats not worse by more than 1 SE clustered on
   pair.
3. **If both arms pass**, ship the one with the lower primary error. If
   only one passes, ship it.

Reported: per election; Parramatta, Wakehurst, Riverstone (nsw2023),
Mulgrave (qld2024); the live Victorian seats that move and by how much.

Unacceptable-win clause: if B passes on the primary only through qld2024
and sa2026 while qld2020 (the thin-evidence, clamped case) gets worse by
more than it did under DF (3.30 -> 4.39), say so plainly in the result, and
the clamp at thin evidence is the next thing to test, not a reason to tune
B now.
