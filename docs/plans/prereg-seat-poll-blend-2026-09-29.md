# Pre-registration: blend seat polls into the seat primaries (`AUSPOL_SEAT_POLL_BLEND=1`)

Written 2026-09-29, before running.

## Why

On v49, the 75 upset seats cost +18.4 of summed log loss against AE Forecasts,
while the 585 favourite-won seats earn -20.9. The worst group is independent
breakthroughs, where we under-call the winner's primary by 16-27 points
(Wakehurst, Mackellar, Goldstein, Curtin, North Sydney) and AEF by 5-15. The
model has never seen a seat poll. 7,054 poll rows now exist
(`external/reference/polls/seat-polls/seat_polls.csv`: fed2019 20 poll-seats,
fed2022 197, fed2025 884 including YouGov and RedBridge MRP for every seat;
sa2026, vic2026 and wa2021 one seat each).

## The change (`R/seat_poll_blend.R`)

- **Poll per (seat, class):** the rows where `row_type == "poll"` and `fp` is present, with fieldwork ending
  within 90 days before election day. Map parties to model classes (ALP; LIB, NAT, LNP, L/NP,
  CLP -> LNP; GRN; ON, ONP -> ONP; IND and "Name(IND)" -> IND; UAP, KAP ->
  OTH_RIGHT; OTH and anything else -> OTH). Sum within class per poll, then
  take the mean over polls. Direct polls and MRP are pooled; how many of each
  gets reported.
- **Blend:** after the xgb override (and the seat-swing port), in all six harnesses and live
  `fit_seats_full.R`: `share += w * (poll - share)` for polled classes whose
  share is already above 0 (no phantom candidates), then renormalise to 100.
- **Weight w for target T:** fitted by least squares on earlier elections'
  polled cells (`elections_before`), using `xgb_pred_seat` from
  `output/forecasts.csv` as the prediction:
  `w = sum(dx*dy) / sum(dx^2)` with `dx = poll - pred` and `dy = actual - pred`.
  The SE is clustered on seat-election. Shrink `w * w^2/(w^2 + se^2)`, and clamp to [0, 1].
  With no earlier polled cells, w = 0.

The targets it can touch: fed2022 (w from fed2019), fed2025 (w from fed2019 and fed2022),
sa2026 (Mount Gambier), and live vic2026 (Hawthorn). fed2019 gets w = 0: fed2016's
seat polls carry no primaries. Every other election is a control and must be
byte-identical.

## Decision rule

- **Primary (targeted):** seat log loss on the polled seats of fed2022 and
  fed2025, paired by seat. **Ship if** it improves by more than 1 SE.
- **Guard:** ledger seat log loss must not worsen by more than one seat-level SE.
- **Unacceptable even if it passes:** any control election moving; or a w
  above 0.9, which would mean the polls replace the model rather than
  inform it, and needs its own look before shipping.
- **Reported:** w per target with its SE and n; the targeted and
  ledger primary RMSE; and the worst-seat table (Curtin, Goldstein,
  Mackellar, North Sydney, Wentworth, Kooyong, Braddon) before and after.

## RESULT (rebuild P vs N = v49, 2026-09-29; the text above is unedited)

Weights: fed2022 0.450 (raw 0.472, se 0.104, 29 cells from fed2019), fed2025
0.239 (se 0.052, 917 cells), sa2026 0.185; fed2019 and every unpolled
election 0. Applied: fed2022 888 cells / 151 seats (mean |change| 1.30
points), fed2025 856 / 150 (723 of them MRP-only; 0.70), sa2026 6 / 1 seat.

- **Targeted (fed2022 + fed2025, 301 seats): -0.0175, SE 0.0102 (t -1.72). Passes.**
- Ledger 0.2812 -> 0.2719 (-0.0094, SE 0.0048). Guard passes. Accuracy 88.6% ->
  88.9%, weighted primary RMSE 4.956 -> 4.887, **TCP MAE 3.68 -> 3.79 (worse)**.
- Controls byte-identical: nsw2023, qld2024, vic2022, wa2025 and every
  unpolled election moved 0 seats. w below 0.9 throughout.
- fed2022 0.3054 -> 0.2611 (-0.0443, SE 0.0189); **fed2025 0.2861 -> 0.2957
  (+0.0095, SE 0.0068)**; sa2026 0.2856 -> 0.2658 (one seat).
- Winner's probability: Goldstein 0.136 -> 0.365 (AEF 0.509), Curtin
  0.096 -> 0.246 (0.445), Hughes 0.137 -> 0.557 (0.642), Mackellar 0.097 ->
  0.208 (0.280), North Sydney 0.079 -> 0.144 (0.336), Mount Gambier 0.131 ->
  0.333 (0.496).

**Ships as ledger v50.** Not hidden: fed2025, whose polls are 85% MRP, got
worse on a weight partly learned from direct seat polls, and the TCP margin
worsened. Next test (registered separately): separate weights for MRP and
direct polls. The ledger's `our_fp_win` column reads the pre-blend xgb
prediction, so its per-seat primary "miss" does not show the blend.
