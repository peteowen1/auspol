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

## RESULT, 2026-09-30 20:10: BOTH ARMS REFUSED (primary fails), flag stays "0"

Arm A `output/snapshots/20260930-1916-ece9a1f-from6`, arm B
`20260930-1959-ece9a1f-from6`, each against v55 (`20260930-1807-3c1a1db-from6`).

Departed seats' incumbent-class primary, mean abs error (points, n 77, lower
is better):

| election | n | v55 | A: one weight, full size | B: weight by gap |
|---|---|---|---|---|
| nsw2023 | 14 | 4.45 | 3.94 | 4.04 |
| qld2020 | 6 | 3.19 | 6.06 | 10.54 |
| qld2024 | 9 | 5.21 | 4.77 | 4.32 |
| sa2026 | 9 | 1.72 | 2.79 | 3.38 |
| vic2022 | 15 | 3.61 | 3.49 | 3.47 |
| all (nsw2019, sa2022, vic2018 unmoved: no earlier evidence) | 77 | 4.613 | 4.794 (+0.18, SE 0.19) | 5.174 (+0.56, SE 0.29) |

Pooled seat log loss, 22 pairs, 2,054 seat-elections (`pooled-backtest.csv`):
v55 0.3314; A 0.3322 (+0.0008, SE 0.0024); B 0.3360 (+0.0046, SE 0.0052).
Ledger 0.2761 -> A 0.2725, B 0.2749.

Both help nsw2023, qld2024 and vic2022 (Mulgrave qld2024 35.4 -> 32.9 in B,
actual 24.2; Parramatta 49.1 -> 47.4, actual 35.5) and hurt qld2020 and sa2026.
The unacceptable-win clause fired as written: B's qld2020 went 3.19 -> 10.54,
far worse than DF's 4.39, because two earlier elections fit b1 2.04 and k 0
and clamp every big-gap seat to a full move to the federal vote. sa2026 got
worse in both arms with 68 earlier cells behind the weight, so thin evidence
is not the whole story.

Scoring defect found while doing this (fixed in the same commit):
`output/forecasts-seats.csv` had held only federal, Victorian and WA seats,
because the NSW, Queensland and SA harnesses write allprobs without a `pair`
column and `build_forecasts_table.R` dropped them silently. My "all 1,593
seats" figures today came from that table and could not see the three states
where DF acts; the first DF result's "pooled log loss unchanged" may have too
(not checked: its scorer is not saved); the
22-pair numbers above come from `pooled-backtest.csv`, which was always
complete. `scripts/compare_rebuilds.R` reads the incomplete table too.
