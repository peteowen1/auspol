# Pre-registration: a departed member's party pulled toward the same booths' federal vote (`AUSPOL_DEPARTED_FED=1`)

Written 2026-09-30 15:25, before building finished. From Pete's Parramatta
walk: Geoff Lee's Liberal vote was 54.0 at the 2019 state election and 30.8 in
the same booths at the 2022 federal election; he retired, and the Liberal
primary fell to 35.5. v53 kept most of his premium (Liberal 48.9).

## Evidence (2026-09-29/30, v51 misses, six state elections, 67 departures)

- Departed seats with a gap of 5+ points keep a median 0.42 of the gap (ours
  0.46); seats where the member stays keep 0.80 (ours 0.74). On average the
  shipped departed-member discount is right; the failures are seats whose
  member out-polled their own voters' federal vote by a lot (Parramatta 0.20
  kept vs ours 0.82; Wakehurst, Richmond, Mulgrave Qld).
- Time-forward rule "federal booths + k x gap": mean abs error 5.98 against
  ours 5.17 alone; a 50/50 blend 4.95.

## The change

State elections with a booth map (vic2018, nsw2019, qld2020, sa2022,
vic2022, nsw2023, qld2024, sa2026; live vic2026). For each seat whose member
left (retirements record), their class's share moves toward
`fed + k * gap` by `beta`, the row rescaled. `k` = pooled share of the gap
kept on earlier elections' departed seats (least squares, clamped [0, 1]);
`beta` = weight on `rule - ours` fitted on the same earlier seats, SE
clustered on election, shrunk `b^3/(b^2+se^2)`, clamped [0, 1]. Both from
elections BEFORE the target only, against this run's as-at predictions.
xgb layer only, after the leader-seat bonus; state harnesses and live.

## Decision rule (against v53, rebuild from stage 6)

1. **Primary (targeted): departed-member seats' incumbent-class primary,
   mean absolute error**, paired, all state elections where it applies. Must
   improve by more than 1 SE.
2. Guard: seat log loss on those seats not worse by more than 1 SE; pooled
   seat log loss and primary RMSE (all rows) not worse by more than 1 SE.
3. Reported: k and beta per target; Parramatta, Wakehurst, Richmond, Mulgrave;
   ledger.
