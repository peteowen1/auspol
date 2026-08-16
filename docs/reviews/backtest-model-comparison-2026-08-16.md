# The fuller trend model does not forecast better

2026-08-16. Result of the comparison registered in
[../plans/prereg-backtest-model.md](../plans/prereg-backtest-model.md), written
and committed before the run.

## The question

The published headline uses `fit_trend()`'s default volatility for every cycle.
`fit_vic.R` estimates volatility per cycle. The second had been called "the
fuller model" and assumed better; it had never been measured.

## Result

| Arm | held-out MAE | usable pairs | runtime |
|---|---:|---:|---:|
| **A — default volatility** (published today) | **2.0588** | 195 | **34 s** |
| B — per-cycle volatility | 2.0547 | 195 | 1122 s |

**Gain 0.0041, against a pre-registered materiality bar of 0.02. Verdict: keep
the default.**

For scale, 0.0041 is **0.2%** of a 2.06-point error, on 195 election-horizon
pairs. It is indistinguishable from nothing, and it costs **33× the runtime**.

## The coverage guard passed cleanly

Rule 2 existed because a model that silently drops difficult cycles looks more
accurate while being fitted on an easier subset. Both arms produced **exactly
195 pairs** and **zero** error-skips, so the comparison is like-for-like and
arm B did not win or lose by changing the sample. The fallback built into arm
B — a party whose sigma estimation fails keeps the defaults rather than
dropping the cycle — appears to have done its job, since coverage is identical
rather than merely close.

## The per-horizon split, and a prediction that was wrong

Registered in advance as the more interesting cut if the headline was close,
along with the expectation that per-cycle volatility would **help at short
horizons** (many polls to estimate from) and **hurt at long ones** (few).

| Horizon | n | A | B | gain to B |
|---:|---:|---:|---:|---:|
| 30 | 42 | 1.8432 | 1.8504 | −0.0073 |
| 90 | 42 | 1.8492 | 1.8828 | −0.0336 |
| 180 | 42 | 2.0656 | 1.9658 | **+0.0998** |
| 365 | 39 | 2.3228 | 2.4134 | −0.0906 |
| 730 | 30 | 2.3014 | 2.2397 | +0.0617 |

**The prediction was wrong, and the shape is the finding.** There is no
pattern: B is worse at 30 and 90, better at 180, worse at 365, better at 730.
The signs alternate. The per-horizon swings (±0.03 to ±0.10) are an order of
magnitude larger than the overall gain (0.004), which is what random
cancellation looks like — not a model that helps in one regime and hurts in
another.

Had the overall result been read without this cut, "+0.0998 at 180 days" would
have been available as evidence that per-cycle volatility works. It is noise,
and the alternating signs are how you can tell.

## What this settles

The simple model in the backtest is **not** a shortcut that the project never
got round to fixing. It is as accurate as the alternative and 33× cheaper, and
the published forecast is not losing anything by using it.

That also removes the tension recorded in
[two-model-paths-2026-08-16.md](two-model-paths-2026-08-16.md): the page's
chart and headline now come from one fit, and that fit is the one measurement
supports.

## What remains open

**Per-pollster noise factors were not tested.** They were held out of scope
because removing their leakage vector — factors learned from fits of elections
that had not yet happened — needs per-fold refitting. Given that per-cycle
volatility bought nothing, the prior on firm factors buying something should
be lower than it was, but it is a different mechanism and untested.

**The runtime asymmetry is worth keeping in mind.** Arm B is 33× slower
because it runs an L-BFGS-B optimisation per party per horizon, roughly a
thousand of them. Any future feature with that shape needs to clear a much
higher bar than 0.02 MAE, because it would make every subsequent tuning grid
an hour instead of three minutes — and constants that are expensive to
re-examine stop being re-examined.
