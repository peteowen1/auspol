# Night swing to uncounted seats: replayed, stays OFF for 28 Nov (2026-11-26)

Pete asked (26 Nov): when one seat comes in well above expectation, should similar and nearby seats move too? Today they
do not. `night_booth_update()` moves only seats with booths counted, and `night_shrink_draws()` (`R/night_update.R:551`)
narrows the statewide draws around the afternoon centre. The seat cluster factor is drawn fresh in the simulation and is
never set from counted seats. Pete chose: build it behind a switch, replay, and turn it on only if early-night calls
improve with no night worse.

**Built** (`R/night_borrow.R`, off; replay flag `scripts/night_replay_json.R --borrow=1|k,c0`). Each seat's prior is
shifted by the swing the OTHER counted seats show (leave-own-out), before its own booth update:
- statewide part: the counted seats' mean swing, shrunk by n/(n+k);
- region and seat-type part: the cluster mean residual, weighted m*rho/(m*rho + 1 - rho), where rho is the afternoon
  forecast's cluster share.

Not yet wired into the live runner (`night_run_update()`), deliberately, because it stays off.

**Replays.** Night states were saved at the published settings through `quick_arm.R` (`AUSPOL_NIGHT_DUMP`; byte-identical
to baseline on all 3 elections), with 1,000 simulations and the replay's simulated report order. Seat log loss is the mean
of -log(P(actual winner)), and lower is better. Seats right is the count where the favourite won.

| night | counted | today | borrow k=2, c0=0.05 | borrow k=10, c0=0.1 |
|---|---|---|---|---|
| vic2022 | 1.2% | 0.2019 | 0.2032 | 0.2030 |
| vic2022 | 3.8% | 0.1800 | 0.1820 | 0.1806 |
| vic2022 | 8.2% | 0.1304 | 0.1344 | 0.1335 |
| vic2022 | 13.5% | 0.1541 | 0.1560 | 0.1566 |
| fed2022 | 1.6% | 0.1317 | 0.1309 | 0.1302 |
| fed2022 | 4.4% | 0.1092 | 0.1081 | 0.1083 |
| fed2022 | 9.1% | 0.0908 | 0.0910 | 0.0907 |
| fed2022 | 18.6% | 0.0873 | 0.0891 | 0.0890 |
| fed2025 | 1.7% | 0.1548 | 0.1406 | 0.1452 |
| fed2025 | 4.4% | 0.1358 | 0.1258 | 0.1281 |
| fed2025 | 9.1% | 0.1239 | 0.1178 | 0.1186 |
| fed2025 | 18.6% | 0.1083 | 0.1022 | 0.1022 |

**Verdict: OFF.** vic2022 is worse at every fraction under both settings, and it is the night most like Saturday (same
commission, same counting order). fed2025 gains up to 9%, and fed2022 is level.

Why vic2022 loses: the swing measured early overstates the final one. Counted seats show Labor -1.4 to -1.9 points from 1%
to 50% of the replay, against -0.96 at the full count. Early-reporting booths are not representative, and borrowing spreads
that bias to every seat. The federal early swings had the right sign and size (fed2025: +1.5 at 2% against +2.3 final).

The differences on vic2022 are 0.001 to 0.004 on 88 seats at 1,000 simulations. That is probably inside replay noise, but
the rule was "no night worse".

**After 28 Nov.**
- Correct the early-booth bias before borrowing: compare like booth types and sizes, or weight booths by their 2022 size.
- Rescore on real-time feed replays (`night_replay_feed.R`) rather than the simulated report order.
- Add vic2026 once it exists.
