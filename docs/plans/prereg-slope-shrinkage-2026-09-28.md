# Pre-registration: shrink the base_pred slopes instead of a min_n cliff

Written 2026-09-28, before running. Pete's rule (CLAUDE.md "Fit constants
with SHRINKAGE, never a hard min_n cliff"), made urgent by v45: once the fits
became time-forward, early elections fall below `min_n` and snap to the
fallback (fed2007 departed slope 1.000 at n=6, then 0.56 at n=41).

## The change (`AUSPOL_SLOPE_SHRINK=1`)

In `R/split_slope.R`: the minor same/new conditional slopes, the major
same/new slopes, and `fit_major_departed_slope()` (departed and present).
Each slope through the origin is shrunk toward 1 by its precision:
`shift = d * d^2 / (d^2 + se^2)`, `d = b - 1`, `se` cluster-robust by
election (seats in one election share a swing). Fewer than 3 rows or 2
elections gives 1. No cliff.

The target is 1, NOT the hardcoded `SHIP_SAME` / `SHIP_NEW` fallbacks: those
were fitted on every election, so today an early election below `min_n`
gets a slope learned partly from later elections -- a remaining leak this
change also removes (noted, and measured as part of this arm).

Not in scope, stated: the two-slope split fit (`AUSPOL_SPLIT_SLOPE`, off in
the shipped configuration) and the defector discounts (a median of ratios, a
different estimator).

## Criterion

Rebuild against v46 (ledger 0.2822, all 16 elections 0.2987 over
forecasts-seats.csv, stage-9 pooled 0.3193): ships if the all-elections
figure falls beyond noise and the ledger does not rise beyond noise; primary
RMSE reported. The early elections (where the cliff bit) are the named
targets: report fed2007-fed2013, vic2014, wa2005-wa2013 per election.
Live vic2026 changes slightly (its slopes are also shrunk); its seat totals
are printed before and after.

## AMENDMENT BEFORE ANY MEASUREMENT (2026-09-28)

Inspecting the fitted slopes (not outcomes) showed fed2007's departed Labor
slope at 0.313 from 6 seats in 2 earlier elections: a 2-cluster standard
error is too unreliable to shrink with. Changed before any rebuild: at least
3 elections (else 1), and the variance is the LARGER of the cluster-robust
and ordinary estimates. Nothing had been scored when this was changed.

## RESULT (rebuild J vs v46, 2026-09-29; the text above is unedited)

Ledger seat log loss 0.2822 -> **0.2878** (+0.0056, SE by seat 0.0017,
t 3.23; by election 0.0035); all 16 elections 0.2987 -> 0.2991 seat-weighted
(per-election mean +0.0031, SE 0.0031, better in 6); weighted primary RMSE
4.947 -> 4.984. **FAILS; stays OFF.**

Named early targets mostly improved (fed2007 -0.005, fed2010 -0.007, fed2013
-0.002, vic2014 -0.009, fed2016 -0.020; wa2005 +0.009, wa2013 +0.033); the
recent pairs got worse (wa2025 +0.025, nsw2023 +0.010, fed2025 +0.006).
Likely reason, untested: in thin cells v46 falls back to the hardcoded
SHIP_SAME / SHIP_NEW slopes, fitted on EVERY election including later ones;
J replaced them with an honest estimate shrunk toward 1. So part of v46's
recent-pair score may rest on that remaining leak. Next: count how often the
ledger pairs use a SHIP_* fallback, and refit those constants time-forward.
