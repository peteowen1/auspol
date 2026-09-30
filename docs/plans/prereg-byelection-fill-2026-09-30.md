# Pre-registration: use a by-election a major skipped, filling the major back in

Written 2026-09-30, before any backtest run under the switch. Pete's call
(quiz answer "Fill in the missing party"), after the Lyne 2008 walk: Labor
did not stand, Oakeshott won, and because the rule in
`prereg-byelection-prior-2026-09-18.md` skips such a by-election, fed2010
started Lyne from 2007 and gave Oakeshott 8.5 against 47.8 actual.

## How much it touches

18 of the 54 by-elections in `byelection-results.csv` had one major absent.
In backtest windows (wa2021 is skipped by the rebuild):

| pair | seats |
|---|---|
| fed2010 | Lyne, Mayo |
| fed2019 | Batman, Fremantle (Liberals absent) |
| fed2025 | Cook |
| nsw2019 | Canterbury, Wollongong, Blacktown (Liberals absent) |
| nsw2023 | Willoughby |
| vic2018 | Polwarth, South-West Coast |
| wa2017 | Vasse |
| wa2025 | North West Central |

13 seats. Live vic2026: Narracan, Warrandyte, Prahran, Nepean (four seats
that today start from vic2022 alone).

## The rule

`byelection_prior(fill = TRUE)`, `AUSPOL_BYELECTION_FILL=1`:

1. Take the by-election's class shares as now.
2. The absent major gets its row's general-election share plus the
   statewide swing to the by-election date: the mean of the region's polls
   in the 90 days to the by-election, minus the party's statewide share at
   the previous general election (anchor `prior-results.csv`). Polls
   dated before the by-election, so nothing after it is used.
3. That share is taken proportionally from every class that is not a major
   (Greens, independents, minors: they picked its vote up, as Lupton did in
   Prahran), never more than they hold. The major that stood keeps its
   by-election share.
4. The row is then half-blended with the general election exactly as a
   normal by-election is (`AUSPOL_BYELECTION_PRIOR=blend`).

Prahran worked through: ALP 26.6 in 2022, statewide swing -10.7 by
February 2025, so 15.9, taken from GRN/IND/minors; LNP keeps 36.2.

## Measurement

One full rebuild (stage 1 on) with `AUSPOL_BYELECTION_FILL=1` against the
v54 full rebuild (`output/snapshots/20260930-1607-33a848a-from1`, same
seed and sims). Only the 13 seats above can change in stage 1.

## Criterion, in order

1. **Primary, targeted**: mean absolute primary error over every class cell
   of the 13 seats, in `base_pred` (`pooled-sharedetail.csv`) AND in the
   xgb layer (`xgb-primary-asat-predictions.csv`, seat-normalised). Must
   fall by more than one SE clustered on seat in the xgb layer (what
   ships); `base_pred` must not rise.
2. **Do-no-harm**: pooled seat log loss in the published ledger
   (`aef7-ledger-summary.json`) not worse by more than one SE (cluster =
   pair).
3. **Secondary**: seat log loss on the 13 seats; Lyne and Mayo fed2010.

Unacceptable-win clause: if the primary error falls but the 13 seats' log
loss rises, the fill rule is moving shares the right way and the wrong
seats' winners, and it does not ship. Also: if the gain comes only from
the absent major's own cell while the independent's cell gets worse in
Lyne (the case that prompted this), report that plainly rather than
calling it a fix for Lyne.
