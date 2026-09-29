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
