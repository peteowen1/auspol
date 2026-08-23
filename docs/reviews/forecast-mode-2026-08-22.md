# Forecast mode refused — and it rules out the explanation everyone would have reached for

> **OVERTURNED 2026-08-23. The refusal below was caused by a bug in the harness,
> not by the model.** `scripts/backtest_candidate_fed.R` folded parties into
> `OTH` in the `shares` matrix and then rebuilt every column of `shares` from
> `mat`, which had only been column-subsetted — so a folded party's per-seat
> votes were **deleted rather than merged**, and renormalising spread the
> missing mass across every remaining party. Found by code review.
>
> With the fold fixed, the pooled calibration slope goes **0.204 → 0.340**,
> against the current harness's 0.286. Distance from 1.0: **0.660 versus
> 0.714**, so the pre-registered rule now says **ADOPT**, not refuse.
>
> **What survives**: the projection is honestly sized at one day out (claimed sd
> 2.42, realised RMSE 2.42) — that measurement never touched the fold.
>
> **What does not**: the conclusion that "statewide uncertainty is not what makes
> us over-confident, so the fault is in the seat model". Adding honest statewide
> uncertainty *does* improve calibration. That inference was drawn from corrupted
> numbers and is withdrawn.



Against `docs/plans/prereg-forecast-mode.md`. **Refused on the pre-registered
rule**, and the investigation the rule demanded produced a sharper answer than
the experiment itself.

## The result

Six federal elections, pooled:

| arm | calibration slope | log score | accuracy |
|---|---:|---:|---:|
| current harness (knows the statewide answer) | **0.286** | 0.494 | 87.6% |
| forecast mode (polls only) | **0.204** | 0.846 | 84.3% |
| *AE Forecasts, for scale* | *1.140* | *0.280* | *88.5%* |

The rule: **adopt if the slope is closer to 1.0.** It is further — 0.796 from
1.0 against 0.714. **Refuse and investigate.**

The log score falling from 0.494 to 0.846 is expected and was pre-registered as
not-a-refusal: forecast mode uses strictly less information. The slope is the
quantity the change existed to fix, and it moved the wrong way.

## The investigation, which is the actual finding

The plan said what a refusal would mean: *"statewide uncertainty is not what
makes us over-confident, which is a finding about the seat model rather than
about the harness."*

The obvious suspect was that the projection understates its own error at a
one-day horizon — the finest horizon this repo had ever scored was 30 days.
**Measured, it does not:**

| election | projected ALP two-party | actual | error |
|---|---:|---:|---:|
| 2010 | 53.38 | 50.12 | +3.26 |
| 2013 | 48.88 | 46.51 | +2.37 |
| 2016 | 49.43 | 49.64 | −0.21 |
| 2019 | 51.85 | 48.47 | +3.38 |
| 2022 | 52.11 | 52.13 | −0.02 |
| 2025 | 52.48 | 55.22 | −2.74 |

**Claimed sd 2.42. Realised RMSE 2.42. Ratio 1.00.**

The statewide projection is honestly sized — it says what it does not know, and
it is right about how much that is. That is a good result in its own right and
the first measurement at the horizon the backtests actually need.

## So the over-confidence is in the seat model

The chain is now closed:

- the statewide input is correctly centred on average and correctly sized;
- feeding that honest uncertainty into the seat model makes calibration **worse**,
  not better;
- therefore the seat model converts statewide uncertainty into seat outcomes
  too sharply. A 3-point statewide miss becomes confidently wrong seat calls
  rather than appropriately hedged ones.

**This rules out the explanation anyone would have reached for first.** "We are
over-confident because the backtest gives us the answer for free" is intuitive,
was the motivation for this whole experiment, and is wrong. The candidates that
remain are inside `simulate_seat_contests()`: the per-seat spread `seat_sd`, the
calibration `shrink`, and the flow matrix's sharpness.

## What forecast mode is nonetheless kept for

It is **not adopted as the reported configuration** — the rule refused it — but
it stays wired behind `AUSPOL_FORECAST_MODE=1`, because it is the only way to
measure the model on equal terms with an outside forecaster, and because the
construction now matches the published path exactly. That took three passes:

1. omitted the first-preference widening (`sqrt(trend_sd² + 2.419²)`),
   understating statewide spread ~2.6×;
2. omitted the two-party anchor to the projection;
3. correct — the draws realise the projection mean to two decimals in all six
   elections.

**Each omission produced a plausible-looking refusal.** The first was reported
here as "not a finding" precisely because it was mine; had the third pass not
been done, this document would have concluded that statewide uncertainty makes
calibration worse, which is true only of an implementation missing two pieces of
the thing it claimed to replicate.

## Refusals, as they landed

- **F1 — leakage guard.** Proven to fail on a cutoff on or after the election
  and on an unparseable date, before any arm was trusted. Writing it exposed a
  guard that could not fire: `as.Date()` throws rather than returning `NA`, so
  the `is.finite()` check beside it was dead code.
- **F2 — default path byte-identical.** Passes.
- **F4 — folded parties reported.** Across the six pairs the trend cannot fit
  `IND`, `ONP` or `OTH_RIGHT` in most cycles, exactly as D1 predicted.
- **F5 — the live forecast unchanged.** Byte-identical.
- **F3 — no tuning inside this experiment.** Honoured, and it is now the thing
  standing between this result and the obvious next move.

## Next, and it needs its own plan

The seat model's own uncertainty is the remaining suspect, and re-tuning it
against AE Forecasts' 1.14 slope is exactly what F3 forbade doing here. It is
the next experiment: `seat_sd`, `shrink`, and how sharply the flow matrix turns
statewide shares into seat outcomes — measured in forecast mode, because that is
the configuration a rival can be compared on.
