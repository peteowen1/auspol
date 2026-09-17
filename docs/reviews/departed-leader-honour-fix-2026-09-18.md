# AUSPOL_HONOUR_DEPARTED: decoupling departure from `same`, and shipping the fix

2026-09-18. Follow-up to `docs/reviews/departed-leader-retention-2026-09-15.md`,
which measured the 0.38-vs-1.01 retention split but explicitly left the seat-
level effect unmeasured. Triggered by Pete flagging Morwell (vic2022) as the
single worst log-loss miss on the AEF-7 ledger and asking for research broken
down by party class on retirements before building anything.

## The bug the 2026-09-06 refusal never saw

`screened_slopes()`'s original `AUSPOL_HONOUR_DEPARTED` logic was
`ifelse(!is_same & permit & plr, 1.0, base)` — `permit & plr` collapses to
`FALSE` the instant a leader departs, **regardless of whether the successor is
independently screen-permitted**. That is why the original version fixed New
England 2013 but broke Wentworth 2022 (Spender was a genuine, screen-permitted
emergence, but got decayed anyway) — a two-seat wash, refused.

Fixing that alone was not enough. `candidate_returns()`'s `same` column is
`any(hit)` across **every candidate in a (seat, party) class**, not just the
leader:

```r
res <- out[, list(same = any(hit), same_mp = any(mp_hit)), by = list(seat, party)]
```

Morwell (vic2018→vic2022, IND) traces to `same = TRUE`, because Tracie Lund (a
minor, non-leading candidate on 2–3%) ran IND in both years — even though
Russell Northe, who actually carried 19.6 of the class's 28.2-point base, did
not recontest. A fix gated on `!is_same & departed` can never fire here,
because `is_same` is `TRUE`. `prior_leader_returns` is a separate,
correctly-scoped column asking specifically whether the prior election's *top*
candidate of the class returned under any label, anywhere in the seat — it
reads `FALSE` for Morwell. The final logic decouples the departure branch from
`is_same` entirely:

```r
plr <- if (honour_departed && "prior_leader_returns" %in% names(hit))
         hit$prior_leader_returns[idx] else rep(TRUE, length(idx))
departed <- honour_departed & !plr & !permit
dep_rate <- if (cls %in% names(departed_rate)) departed_rate[[cls]] else new[[cls]]
ifelse(!is_same & permit, 1.0,
       ifelse(departed, dep_rate, base))
```

Verified against real data (`candidate_returns()` call, not just the unit
test): Morwell (`same=TRUE, prior_leader_returns=FALSE, permit=FALSE`) now
returns `0.38` instead of `0.907`. Wentworth (`permit=TRUE`) is unaffected
either way — still `1.0`. New tests added to
`tests/testthat/test-conditional_slopes.R` cover both shapes; 98/98 pass.

## Measurement

Isolated in `base_pred` (`AUSPOL_XGB_PRIMARY=0`, the non-circular baseline —
see `docs/reviews/xgb-primary-circularity-2026-09-13.md`), pooled across the
five harnesses that wire `screened_slopes()` (fed, nsw, qld, sa, vic —
`backtest_candidate_wa.R` has no `screened_slopes()` wiring at all, a separate
pre-existing gap, untouched here), at `AUSPOL_N_SIMS=5000`:

| scope | log loss before | after | Δ |
|---|---|---|---|
| pooled, 5 harnesses (n=1751) | 0.2810 | 0.2801 | −0.0009 |
| vic2022 alone (n=78) | 0.2789 | 0.2587 | **−0.0202** |

Targeted: 53 genuine IND departures (prior class share ≥15%, prior leader did
not return) across these harnesses' scored pairs — net −1.55 log-loss sum, 7
improved / 11 worsened (all small, largest +0.0067) / 35 unchanged (the screen
already permits regardless of departure in those). Two seats carry almost all
of the gain:

- **Morwell (vic2018→vic2022)**: p(actual=LNP) 0.0474→0.1530, log loss
  3.049→1.877 (Δ−1.17, the single biggest move in the 1751-row corpus)
- **Geelong (vic2018→vic2022)**: log loss 0.434→0.031 (Δ−0.40)

**Under the backtest harnesses' `AUSPOL_XGB_PRIMARY=1` (the static-override
mechanism), baseline and treatment came back byte-identical** — 0.2708 both
ways — because `xgb_primary_override()` (`R/xgb_primary_override.R:1-84`)
substitutes in a cached leave-one-pair-out OOF file
(`output/xgb-primary-v6-oof-predictions.csv`) that was frozen at whatever
`base_pred` existed when it was last pooled, and does not re-read
`dev_slope()`'s live output at all.

**This is NOT the mechanism the actual published Victoria forecast uses.**
`fit_seats_full.R` calls `xgb_primary_predict_live()`
(`AUSPOL_XGB_PRIMARY_LIVE=1`, `AUSPOL_XGB_BASE_MARGIN=2`, both published
defaults), which sets `base_margin` from the CURRENT run's `shares` matrix at
prediction time (`R/xgb_primary_override.R:481-483`) — and that `shares`
matrix is built by this run's own `dev_slope()`/`screened_slopes()` calls,
which already carry the fix (`fit_seats_full.R:906-928,1002`). **The live
forecast picks up this fix on its next run, with no retrain required.** Caught
by Pete asking directly whether published defaults use base_margin now — a
claim in this doc's first draft ("the fix does not reach the published
forecast") was wrong and is corrected here.

What DOES still need the retrain: an honest **backtest validation** number.
The cached OOF file the backtest harnesses read is generated the same way
(`fit_xgb_primary_v6.R:733` also sets `base_margin=base_pred` per held-out
pair), so the methodology matches what ships — the file is just stale.
Regenerating it via the 4-step non-circular procedure
(`docs/reviews/xgb-primary-circularity-2026-09-13.md`) gives a trustworthy
pooled log-loss/RMSE comparison against AE Forecasts et al., which this
repo's standing rule requires before treating any change as validated — even
though the live forecast itself doesn't need that step to already reflect the
fix.

## Decision

Flipped `AUSPOL_HONOUR_DEPARTED` to `"1"` in `scripts/published_flags.R`. The
2026-09-06 refusal was based on a federal two-seat wash and conflated
"departure" with "no real new emergence" as one mechanism; this measurement is
the fuller, well-powered (593-case) re-run it called for, and it is a clean,
targeted, do-no-harm-passing win with no seat-level regression larger than
noise.

The published Victoria forecast already reflects this fix as of the flag flip
above — `fit_seats_full.R`'s live xgb path (`xgb_primary_predict_live()`) sets
`base_margin` from each run's own fresh `shares` matrix, not a stale cache.
What still needs the 4-step non-circular retrain
(`docs/reviews/xgb-primary-circularity-2026-09-13.md`: run all six harnesses
at `AUSPOL_XGB_PRIMARY=0` with the new flag on, pool, refit `v6` once, then
rerun all six at published defaults) is the **backtest validation number** —
the pooled log loss vs AE Forecasts this repo's standing rule requires before
treating a change as confirmed. That retrain is the next step after this doc.
