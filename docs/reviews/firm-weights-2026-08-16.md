# Down-weighting noisy pollsters makes the forecast worse

2026-08-16. Result of the comparison registered in
[../plans/prereg-firm-factors.md](../plans/prereg-firm-factors.md), written and
committed before implementation, including the prediction that it would fail.

## Result

| Arm | held-out MAE | pairs | runtime |
|---|---:|---:|---:|
| **A — equal weights** (published today) | **2.0588** | 195 | 33 s |
| B — per-firm noise factors | 2.0719 | 195 | 61 s |

**Gain −0.0131.** Not merely below the 0.02 bar: **negative**. Down-weighting
noisier pollsters costs about 0.6% of accuracy, at 1.8× the runtime.

Coverage identical — 195 pairs each, zero error-skips — so arm B neither won
nor lost by being fitted on a different subset.

## The per-horizon shape is the finding

| Horizon | n | A | B | gain to B |
|---:|---:|---:|---:|---:|
| 30 | 42 | 1.8432 | 1.8254 | **+0.0178** |
| 90 | 42 | 1.8492 | 1.8761 | −0.0270 |
| 180 | 42 | 2.0656 | 2.0886 | −0.0230 |
| 365 | 39 | 2.3228 | 2.3474 | −0.0246 |
| 730 | 30 | 2.3014 | 2.3094 | −0.0080 |

**Better at 30 days, worse at all four longer horizons.** That is a
*consistent* pattern, not the alternating signs that marked the per-cycle
volatility comparison as noise, and it has an obvious mechanism: close to an
election a cycle has many polls, so each firm's noise is estimated from enough
data to be worth acting on. Further out it is estimated from a handful, and a
badly estimated weight is worse than no weight at all.

This is precisely the mechanism predicted — and wrongly — for per-cycle
volatility. It did not appear there. It appears here.

## What this settles

**The published forecast is right not to use firm factors**, and by a wider
margin than "it does not matter". The page's statement that variability is
measured and not used to weight the forecast now has a measured justification
behind it rather than only a description.

It also lowers the value of the untested cross-cycle version. That version
learns a firm's noise from *past elections* rather than the current cycle, so
it would have more data per firm — but it would apply that weight at every
horizon, including the long ones where this test shows weighting actively
hurts. It could still win; the case for spending 33× runtime to find out is
weaker than it was this morning.

## What was tested, precisely

Two-pass, self-contained: fit the cycle with equal weights, estimate each
firm's noise from *those* residuals, refit with them. Nothing outside the
cycle or after the horizon cutoff reaches the estimate.

That tests **"is a firm's noise detectable within a cycle and worth acting
on"** — not "are some firms reliably noisier across elections". The stronger
claim needs per-fold refitting of every prior cycle, which costs what the
volatility arm cost. The distinction was stated in the pre-registration before
the number existed, because the two are easy to conflate afterwards.

## Scoreboard for "more sophisticated model" changes

Four now, all judged the same way:

| Change | Result |
|---|---|
| `szc_sd_pts` 0.3 → 1.5 | **adopted** (1.3% better) |
| `sigma_house_pts` | already optimal, kept |
| per-cycle volatility | irrelevant (0.2% for 33×) |
| per-firm weighting | **harmful** (−0.6%) |

One in four helped. A procedure that only produced adoptions would be evidence
it was finding what it went looking for.
