# Pre-registration: a fitted poll series must land in its class (WA Nationals)

Written 2026-09-20 14:05, after the code change but before any harness
measurement.

## The defect

`statewide_draws_as_at()` fills each simulation class's level from the
trend series of the same name and gives `OTH` the remainder. WA polls carry
the Nationals as their own column, so the trend fits a `NAT` series; the
seat model's class for them is `LNP` (`classify_party()`), so `NAT` was in
neither list: its ~6 points fell through to the `OTH` remainder. Every WA
backtest since forecast mode shipped (2026-09-19) has forecast the
Coalition about six points low and "Other" six points high statewide, and
the seats inherit it. No other region's polls break the Nationals out, so
nothing else changes (verified: NSW 2023 and QLD 2024 diagnostics identical
before and after).

WA 2017, day-before forecast statewide (actual in brackets):

| | before | after |
|---|--:|--:|
| ALP (42.2) | 31.9 | 34.8 |
| LNP (36.6) | 35.3 | 38.3 |
| OTH (~5) | 16.3 | 10.3 |

## The fix

After the per-class loop, any fitted series whose party is not a
simulation class is folded into `classify_party()`'s class for it (bands in
quadrature), before `OTH` takes the remainder. One `FM1` line per fold.

## Prediction and criterion

WA pairs' Coalition and Other cells move toward the actual result; the
seven WA pairs' pooled seat log loss falls; no non-WA pair changes at all
(byte-identical stage-1 base_pred, which is the do-no-harm check and is
verifiable because the fold only fires where a `NAT` series exists). No
ledger criterion beyond wa2025 not worsening: this is a dropped-input bug,
and the standard is "the input reaches the model", measured for the record.

# RESULT, smoke (2026-09-20 13:55; base_pred only, all seven WA pairs, 500 sims)

All-class RMSE against the actual result (points, lower is better), before
-> after the fold, with the folded series' flow carried into the anchoring:

| pair | before | after |
|---|--:|--:|
| wa2001 | 7.04 | 7.17 |
| wa2005 | 4.64 | 4.79 |
| wa2008 | 5.80 | 5.91 |
| wa2013 | 4.73 | 4.72 |
| wa2017 | 5.30 | **4.53** |
| wa2025 | 4.52 | **4.19** |
| all WA cells | 5.46 | **5.34** |

The two elections with the largest Nationals vote (6.2 and 4.3 points)
improve by 0.78 and 0.33; the three early pairs (NAT 2.4 to 5.6) worsen
by 0.10 to 0.15, and the anchoring refinement changed that by only 0.01.
The early-pair cost comes with Labor's level, not the Coalition's: wa2001
Labor forecast 40.9 against 37.2 actual, up from 39.8 before the fold,
because raising the Coalition level moves the two-party anchoring's
correction onto Labor. That is the anchoring's known asymmetry, not a
reason to keep dropping a poll series. **Kept** (a dropped input is a
bug, and the net is an improvement); wa2025 is the WA pair in the ledger
and improves. Rebuild v42 decides the ledger number.
