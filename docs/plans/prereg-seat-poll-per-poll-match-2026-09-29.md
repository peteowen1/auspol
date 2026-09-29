# Pre-registration: compare seat polls only on the classes each poll names (`AUSPOL_SEAT_POLL_MATCH=perpoll`)

Written 2026-09-29 18:55, before the rebuild. A CORRECTNESS defect in the
shipped seat-poll blend (v50/v51), found tracing the public-only arms' fed2022
losses.

## The defect

MRP releases report a catch-all "Others", and the blend compared it with our
own `OTH` class:

| release | named | its "Others" holds |
|---|---|---|
| YouGov 2022 | ALP, Lib/Nat, GRN, ON, UAP | Katter (43 in Kennedy), teal independents (24 in Goldstein) |
| Accent/RedBridge 2024-25 (3) | ALP, Lib/Nat, GRN | One Nation and independents |
| YouGov 2025 (3) | ALP, Lib/Nat, GRN, ONP, IND | KAP and other minors |

So Kennedy 2022's Katter vote (our `OTH_RIGHT` 46.3, actual 46.1) was pulled
toward UAP's 6, and the same mismatched cells fitted the weight.

## The change (Pete's choice over a fixed four-class collapse)

`seat_poll_implied()`: each poll becomes a vector over OUR classes. Classes it
names (ALP, LNP, GRN; ONP and IND where reported) take its number, scaled so
the poll sums to 100; its UAP/KAP/Others go to a REST total, shared among our
other classes in proportion to our own shares. Vectors average over a seat's
polls. Used by both the time-forward weight fit (our shares = that election's
`xgb_pred_seat`) and the blend (our shares = the harness's shares). Blend
mode 1 (what ships); backtests only until shipped, as the live table does not
carry per-poll rows yet.

Dry run on fresh v51 inputs: Kennedy's Katter poll value 6 -> 44.2; weights
fed2022 0.532 -> 0.002 (fed2019's polls, compared properly, carry almost no
signal: raw 0.040, se 0.168), fed2025 0.255 -> 0.390.

## Baseline

**Fresh v51 = `output/rebuild-R2/`** (ledger 0.2753), not the published
rebuild R (0.2760): R's seat-poll weight was fitted on v50-era fed2019
predictions left in `output/forecasts.csv`. R2 reran stage 6 with R's
forecasts in place.

## Decision rule

- **Primary: AEF-7 ledger seat log loss improves** against R2.
- **and** the all-elections per-election mean (`compare_rebuilds.R` CR2) does
  not worsen by more than 1 SE.
- **Reported**: fed2022 and fed2025 separately (fed2022 is expected to lose
  most of v51's blend, fed2025 to gain); Kennedy, Goldstein, Curtin, McMahon,
  Bullwinkel; primary RMSE and TCP MAE; weights.
- **Unacceptable**: any unpolled election moving.
- Ships -> live wiring (per-poll rows in the shipped table) before publishing.
