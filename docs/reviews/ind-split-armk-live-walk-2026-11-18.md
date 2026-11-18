# Independent split arm K on the live vic2026 forecast (18 Nov 2026)

Pete asked to see Essendon under arm K before deciding whether to override its refusal
(`plans/prereg-ind-split-points-2026-11-18.md`, arm K refused on guard 1, won seats +0.057, SE 0.014).

Detached worktree `C:\dev\auspol-wt-indk` at 17033711, its own copy of `output/` (archive folders excluded).
Two `fit_seats_full.R` runs at the published configuration, seed 42, 20,000 sims: `AUSPOL_OUT_SUFFIX=indbase`
(8:48-8:53pm) and `indk` with `AUSPOL_CLASS_SPLIT=1 AUSPOL_CLASS_SPLIT_MODE=pts_carry` (8:53-8:58pm). Arm K printed
`CLS2 ... frozen fit ind-split-fit-vic2026.csv (25 seats, mode pts_carry)` and `CLS1 ... 25 seat(s) [IND=25]`.
Baseline Essendon IND 0.8475 matches the published forecast (built 17 Nov).

Win probability, 0-1. Only seats whose independent chance moved more than 0.005 or whose favourite changed.

| Seat | IND base | IND arm K | Favourite base | Favourite arm K |
|---|---|---|---|---|
| Essendon | 0.848 | 0.647 | IND 0.848 | IND 0.647 |
| Kew | 0.194 | 0.137 | LNP 0.804 | LNP 0.861 |
| Footscray | 0.121 | 0.082 | GRN 0.700 | GRN 0.740 |
| Macedon | 0.047 | 0.028 | ONP 0.405 | ONP 0.423 |
| Albert Park | 0.020 | 0.010 | GRN 0.490 | GRN 0.493 |
| Mornington | 0.019 | 0.013 | LNP 0.978 | LNP 0.983 |
| Preston | 0.015 | 0.009 | ALP 0.739 | ALP 0.743 |
| Sydenham | 0.014 | 0.003 | ONP 0.757 | ONP 0.782 |

Expected independent seats statewide: 2.16 -> 1.80. No favourite changes. Essendon's freed 0.20 goes to
LNP 0.069 -> 0.150, ALP 0.048 -> 0.110, GRN 0.025 -> 0.067, ONP 0.010 -> 0.026. Primary-vote ranges are unchanged
(the split acts at the count, not on the class total).
