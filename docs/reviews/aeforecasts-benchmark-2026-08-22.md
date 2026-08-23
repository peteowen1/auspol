# The benchmark exists now, and the first thing it found was our own measurement gap

`docs/ANCHOR-MODEL.md` has said from the start that our accuracy has never been
tested against either reference. That is no longer true, and the reason it was
true for so long is worth recording: **I looked in their code repository, found
no forecast data, and concluded there was none.** The site's "Past Elections"
menu says otherwise. Pete pushed; the archive was public the whole time.

## Getting it

Served by a Django REST API, not stored as files:

```
https://www.aeforecasts.com/forecast-api/election-summary/<code>/regular?format=json
https://www.aeforecasts.com/forecast-api/election-results/<code>/?format=json
```

Two things hid it, both now in `scripts/fetch_aeforecasts.R`'s header: the apex
domain does not resolve from here while `www.` does, and without `?format=json`
the endpoint serves a browsable HTML page. Eight elections, final forecast plus
official result, 4.3MB into gitignored `external/reference/aef/`.

## The bar

**Seat winner probabilities**, 728 seat-elections across eight elections:

| metric | AE Forecasts |
|---|---:|
| accuracy | 87.9% |
| Brier | 0.0908 |
| log loss | **0.2802** |
| calibration slope | **1.14** |

A slope of 1.14 is very slightly under-confident — well calibrated.

**Seat-level two-candidate-preferred**, 722 seats:

| | value |
|---|---:|
| MAE | **3.69 pp** |
| RMSE | 4.71 pp |
| 90% band coverage | **83.2%** |

Worth noting they are **not** perfect: 83.2% against a nominal 90% means their
seat TCP bands are somewhat over-confident too, and 2025 federal (68.7%) and
2025 WA (74.6%) are markedly worse than 2022–2024. The bar is a real forecaster,
not an oracle.

## Where we stand, stated carefully

On the four overlapping elections our seat backtest scores **log loss 0.524
against their 0.276**, with accuracy within a point and a half. Our picks are
comparable; our probabilities cost nearly twice as much.

**We produce no seat-level TCP at all**, so on the high-N metric we cannot be
scored yet. The candidate model works in first preferences and win
probabilities and never emits a seat TCP.

## The correction, which is the real finding

I reported those calibration figures to Pete as though they described our
forecast. **They do not.**

| | passes `statewide_draws`? |
|---|---|
| published model, `fit_seats_full.R:573` | **yes** — correlated statewide uncertainty |
| all four backtest harnesses | **no** |

The backtests inject each election's **actual** statewide result as the centre
and add only per-seat noise. The published model draws the statewide vote from
the projection's own uncertainty with party correlation — and
`simulate_seat_contests()`'s own documentation records that dropping that
covariance "made the seat range roughly 40% too tight."

So the backtest measures a **tighter, more confident variant than the one we
ship**, and:

- our published seat probabilities are probably better calibrated than a 0.23
  slope suggests — but that is inference, not measurement;
- **nothing in this repo measures the calibration of the model we publish.**

This is the same trap `CLAUDE.md` records for the two seat models in a new
guise: the thing being measured is not the thing being shipped. It went
unnoticed because the backtest numbers looked like model numbers.

## What the reliability curve shows anyway

Even granting the caveat, the backtest configuration is badly over-confident in
a specific, structural way:

| claimed | AEF actual | ours actual |
|---|---:|---:|
| 60–70% | 62% | 54% |
| 70–80% | 71% | 65% |
| 80–90% | 85% | **72%** |
| 90–95% | 91% | 87% |

And we place **637 of 1,099 seats (58%) in the 99–100% bucket** against their
**30%**. Claiming near-certainty on twice as many seats is what a zero-error
statewide anchor would produce, which is consistent with the caveat above rather
than separate from it.

## Consequences

The fair comparison and the calibration fix are **the same job**. Running the
backtest in forecast mode — statewide vote from `trend_as_at()` rather than from
the answer — both removes our unfair advantage and restores the uncertainty the
published model already carries.

That was assessed and is **feasible, closer to plumbing than modelling**:
`trend_as_at()` exists, is unit-tested against leakage on exactly this mechanism
(`tests/testthat/test-projection.R:101-117`), and `simulate_seat_contests()`
already exposes the `statewide_draws` slot. Two decisions need pre-registering
first: what to do when a party misses the poll-inclusion floor (One Nation has
3–7 polls in the Victorian and NSW cycles, against a floor of 8), and which
error distribution the statewide draws are taken from.

## Two gotchas for anyone reusing their data

Both were found empirically and will silently corrupt a comparison:

- **`ONP` vs `ON`.** Their 2024 Queensland summary abbreviates One Nation as
  `ONP` while that same election's results file uses `ON`. Without normalising,
  Southern Downs — a real One Nation TCP contest — fails to match and is
  dropped.
- **Generic versus named candidates.** In teal-independent seats two scenarios
  abbreviate to the same pair: a generic placeholder at ~0.1–2% probability and
  the specific candidate often above 50%. Match on the higher-probability
  scenario. 26 seats across the eight elections are affected.

Also: `IND*` in their results marks an independent who reached the final two but
was never in their modelled scenarios — a genuine pair-level miss, correctly
excluded rather than force-matched. Six of 728 seats are unscoreable this way,
which makes the coverage figures very slightly optimistic.
