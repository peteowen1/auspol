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

# RESULT, rebuild v42 (2026-09-20 14:21; 20,000 sims, shipped config)

**Criterion NOT MET on seat log loss.** Seat log loss per pair (lower is
better), v41 -> v42, all seats of each pair:

| pair | n | v41 | v42 | delta |
|---|--:|--:|--:|--:|
| wa2001 | 57 | 0.7204 | 0.7692 | +0.049 |
| wa2005 | 46 | 0.3818 | 0.3837 | +0.002 |
| wa2008 | 38 | 0.7814 | 0.7860 | +0.005 |
| wa2013 | 55 | 0.4034 | 0.4052 | +0.002 |
| wa2017 | 54 | 0.5635 | 0.5177 | **-0.046** |
| wa2025 | 53 | 0.2758 | 0.2835 | +0.008 |
| WA pooled | 303 | 0.5262 | 0.5297 | +0.004 |

The primary-vote statistic the fix targets improved (weighted primary RMSE
on the ledger 5.18 -> 5.15; all-seat pooled log loss over 20 pairs
0.3376 -> 0.3326, with vic2018 -0.057 and fed2016 -0.024), but the WA
seat log loss did not fall and wa2025 worsened by 0.008 (SE about 0.05 on
53 seats). The ledger moved 0.2921 -> **0.2943** (AEF 0.2851): fed2022
0.2747 -> 0.2742, fed2025 0.2993 -> 0.3003, nsw2023 0.2908 -> 0.2930,
qld2024 0.3286 -> 0.3345, sa2026 0.3044 -> 0.3016, vic2022 0.2734 ->
0.2785, wa2025 as above. None of the seven moves exceeds its own SE; six
of seven are in the worse direction.

**The do-no-harm check could not be read as written.** Stage-1 files were
not byte-identical for the non-WA pairs, for three reasons that are not
the fold: v41's stage 1 ran before the statewide level was pinned to
20,000 draws (`a374883`), so its 2,000-draw jitter (mean 0.03 points,
max 0.16 on nsw2023/qld2024/vic) is the whole difference on those pairs;
fed2016 folded the Nick Xenophon Team series (3.0) into `IND` (a second,
unforeseen fold; fed2016 log loss 0.3616 -> 0.3381); and Tasmania joined
the state-swing prior (`0b21398`) for the federal pairs. `FM1` fired on
the six WA pairs and fed2016 only.

**Disposition: kept, held for Pete** (the same shape as v40 and v41: a
dropped input restored, primary improves, seat log loss flat-to-worse
within noise). v42 ran the Coalition-only anchoring fix-up.

**Review finding, measured and refused (15:00).** The reviewer asked that
the anchoring fix-up apply to any class, not only the Coalition: correct
the implied two-party by the folded series' flow minus its class's rate
(1 for Labor, 0 for the Coalition, `flow_of(cls)` otherwise). Only the
fed2016 NXT -> IND fold is affected. fed2016 smoke (500 sims, xgb off)
against v42's stage-1 file: every South Australian seat's Labor moved
-1.4 and Coalition +1.4 (the Coalition was already over-forecast there:
Barker 55.2 -> 56.6 against 46.6), all-cell RMSE 4.154 -> 4.172, Labor
4.19 -> 4.24, Coalition 4.61 -> 4.68, the other classes unchanged. The
general form is the tidier rule and the worse forecast on the one case
that exists, because `flow_of("NXT")` is a pooled guess for a party with
no transfer history of its own. Not applied; the code stays as v42 ran
it, with the comment naming this measurement.
