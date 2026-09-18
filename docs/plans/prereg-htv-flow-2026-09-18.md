# Pre-registration: the Liberal how-to-vote card selects the ALP:GRN flow row

Written 2026-09-18, late evening, before any run under the switch. Pete's
call ("do all three then one combined rerun") on the data items from the
worst-seat pass.

## The measurement that motivates it

Our own flow tables run on the ACTUAL primaries still gave ALP 6-8 points
too much 2CP in Footscray, Richmond, Brunswick and Pascoe Vale (vic2022)
and 6 too little in South Brisbane (qld2024). One cell: Liberal/LNP
preferences with ALP and GRN both alive. Observed from the transfer files,
share to ALP: vic2018 58%, vic2022 35%, qld2020 36%, qld2024 73%, federal
59-73%. The card order is public before polling day.

## The rule

`external/reference/htv/liberal-alp-grn-order.csv` records, per election
(and per seat where a card differs), whether the Liberal card put the
Greens above Labor. `fit_htv_flow_rows(target)` fits the two ALP shares
leave-target-out from every other election's observed split, labelled by
that split (under 50% = greens-above), seat-weighted.
`htv_flow_override()` replaces the ALP:GRN split in every "LNP excluded,
ALP and GRN alive" conditional row (statewide or per-seat xgb override)
with the fitted share for the recorded order; other survivors untouched.
No entry for the election: nothing changes. `AUSPOL_HTV_FLOW`.

Entries for the backtest targets: vic2018 F, vic2022 T, qld2020 T,
qld2024 F, fed2019/2022/2025 F, nsw2019/2023 F. wa and sa: no entry
(unknown), so unchanged. vic2026: no entry until the cards are published.

## Criterion, in order

1. **Primary, targeted**: mean absolute 2CP error on the REAL pairing for
   seats whose real final two was ALP v GRN, in the elections with an
   entry, base_pred-only harness runs (`AUSPOL_XGB_PRIMARY=0`, 20,000
   sims), before vs after. Must fall by more than one clustered SE
   (cluster = seat).
2. **Do-no-harm**: pooled seat log loss over all 23 pairs not worse by
   more than one SE (cluster = pair). Note the rows touched exist only in
   seats where the Liberals are excluded with both ALP and GRN alive, so
   most seats are unchanged.
3. **Secondary**: the five named seats; and ALP-v-GRN seats in elections
   WITHOUT an entry must be byte-identical.

Unacceptable-win clause: the fitted shares must sit near the observed
extremes (greens-above 30-45%, labor-above 55-70%); anything outside means
the labelling is picking up noise from thin elections and `min_seats` is
too low.

## Result, 2026-09-18 23:25 (base_pred only, 20,000 sims, all six harnesses)

Fitted shares, leave-target-out: greens-above 36-37%, labor-above 60-62%
(inside the pre-registered windows).

| metric | before | after | delta | SE |
|---|---|---|---|---|
| ALP v GRN real-pairing 2CP error, elections with an entry (n=26) | 6.19 | 5.08 | **-1.12** | 0.32 |
| all other real pairings (n=629) | 3.96 | 3.96 | +0.002 | |
| pooled seat log loss, 2,112 seat-elections | 0.2945 | 0.2938 | -0.0007/pair | 0.0007 |

Footscray 66.1 -> 62.2 (real 54.2), Preston 64.6 -> 60.2 (52.1), Pascoe
Vale 60.3 -> 57.5 (52.0), Melbourne vic2022 53.4 -> 57.2 (60.2), South
Brisbane 46.9 -> 49.3 (56.0); Northcote the one clear loser (48.4 -> 45.9,
real 50.2). 20 of 26 better.

**Verdict: criterion met at 3.5 SE, do-no-harm met, SHIPPED.** The
residual (Footscray still 8 over) is the flow row's other survivors and
the primaries, not the card. vic2026 has no entry until the Liberal cards
are published; add the row to `external/reference/htv/liberal-alp-grn-order.csv`
the day they are.
