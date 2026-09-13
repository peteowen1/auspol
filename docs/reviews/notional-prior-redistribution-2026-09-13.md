# Notional (redistribution-adjusted) prior: real gap found, three fix attempts, no clean win

2026-09-13. Working the Tangney/Pearce/Heathcote/Hartley cluster from the AEF
worst-seats table (all four: a sitting LNP incumbent recontested and lost by
2.3-3.7x the trend the model applied). Found and closed a real gap; the fixes
tried to exploit it did not clearly pay off.

## The gap: we have never adjusted for redistribution on a continuing seat

`scripts/build_notional_baselines.R` reconstructs a seat's prior result on
current boundaries via booth-level AEC respreading -- the same technique
Antony Green's own published notional margins use, and AE Forecasts leans on
his numbers directly rather than computing their own. But its ONLY consumer
(`backtest_candidate_fed.R`) applies it exclusively to seats **missing
entirely** from the prior election (a brand-new name, e.g. Bullwinkel at
fed2025). A seat that keeps its name after a boundary change -- Tangney,
Pearce, and every seat in every redistribution -- fell straight through
using the raw, un-adjusted previous result.

This matters beyond these two seats: **South Australia redistricts every
single election** (a unique feature of SA electoral law), so every SA seat,
every cycle, carries this same problem -- plausibly part of why SA has been
by far our worst-calibrated jurisdiction all session (log loss 0.43-0.54
against 0.20-0.30 elsewhere).

## A real bug found and fixed along the way

`build_notional_baselines.R` didn't exclude the booth-level download's
"Informal" pseudo-candidate row before computing shares, diluting every
party's notional percentage by the seat's informal rate (~2-3 points,
similarly sized nationwide -- the tell that something was wrong: an
apparent redistribution effect showing up with near-identical magnitude in
every state, including ones with no federal redistribution that cycle).
Fixed and committed (`8db4305`) independent of everything below -- it's the
same script that computes Bullwinkel's live notional baseline.

## The corrected, real effect on the two named seats

| seat | LNP raw -> notional | ALP raw -> notional | combined swing embedded | actual swing |
|---|---|---|--:|--:|
| Pearce | 45.1 -> 44.0 | 29.1 -> 32.5 | 4.4 pts | 15.2 |
| Tangney | 53.6 -> 52.4 | 26.0 -> 27.7 | 3.0 pts | 13.6 |

Real, mechanical, leakage-free (redistributions are public well before
polling day) -- and genuinely explains 20-29% of the miss on these two
seats. Not the whole story: Porter's retirement (a historical rape
allegation, denied, case later dropped; plus a "blind trust" defamation-suit
funding controversy) is a real, undata-able personal factor for Pearce
specifically.

## Three ways tried to get the model to use it, in order

**1. Harness-level replacement** (`AUSPOL_NOTIONAL=2` in
`backtest_candidate_fed.R`, new mode alongside the existing missing-seat-only
default). Replaced the prior-vote table (`fa`/`mat`) for every seat with a
notional entry. **Zero effect, confirmed to 4 decimal places on named
seats.** Cause: `AUSPOL_XGB_PRIMARY` overrides ~99% of primary-share cells
with the gradient-boosted model's own prediction, which is built from
`candidacies.csv` directly and never touches `fa`/`mat` at all. Same root
cause that made `honour_departed` inert earlier the same day. Kept as
infrastructure (harmless, off by default, correctly targets the
non-overridden ~1% of cells) but is not where the real lever is.

**2. Silent substitution into the xgb feature** (`AUSPOL_XGB_NOTIONAL=1`,
first version -- `x` replaced by the notional value inside
`fit_xgb_primary_v6.R`'s own feature build). Verified the substitution was
numerically correct (Pearce ALP `x`: 29.05 -> 32.45, exact match to the hand
calculation). **Barely moved the prediction, and slightly the wrong way**
(Pearce ALP prediction 30.53 -> 30.15; pooled RMSE 3.8477 -> 3.8625, worse).
xgboost only responds when a feature crosses a learned split threshold; a
few points of additive correction to `dev_prev` apparently doesn't cross one
for these cells.

**3. Explicit adjustment feature** (`AUSPOL_XGB_NOTIONAL=1`, second version --
`x` left untouched, `x_notional_adj = notional - raw` added as its own
column, same shape of fix that made `ret_exp` work when a flat retention
rate didn't). **Real movement this time, but mixed**: Pearce ALP 30.53 ->
35.08 (+4.55, closes over a third of the remaining gap), Tangney ALP 25.51
-> 26.18 (+0.67, modest), Hasluck ALP 29.70 -> 29.72 (flat). Pooled: overall
RMSE 3.8477 -> 3.8516 (very slightly worse), federal-only 3.4166 -> 3.4094
(very slightly better). Best of the three, still net-neutral in aggregate.

## Verdict: not shipped, all three left in the tree as off-by-default code

Per Pete's own call ("try this one more time then stop regardless"),
stopping after the third variant. `output/xgb-primary-v6-oof-predictions.csv`
restored to the pre-investigation baseline after each test; nothing here
changes the shipped forecast. `AUSPOL_NOTIONAL=2` and `AUSPOL_XGB_NOTIONAL=1`
both stay in the code, off by default, documented, for whoever revisits this
-- same convention as `screened_slopes(honour_departed=)`.

`output/notional-baselines.csv` itself is now genuinely improved regardless
of any of the above: extended from covering only the 2022->2025 pair to all
six federal pairs (2007 through 2025), and the informal-vote fix applies to
every one of them. That's a strict improvement to the EXISTING (already-
shipped) missing-seat mechanism, independent of the three refused attempts
above.

## What's still open

- **NSW/VIC/QLD**: have booth-name-to-district correspondence files
  (`external/reference/correspondences/booths-*.csv`, from the anchor's own
  author) but not yet confirmed to have the underlying booth-level RESULT
  counts needed to do the same respread. Unchecked.
- **SA**: only district-level totals cached (`external/elections/ecsa-2022-
  sa-firstprefs.csv`); no booth-level results at all. Given SA redistricts
  every election, this is the highest expected-value target, but needs a
  genuinely new fetch from the SA Electoral Commission before any of this
  machinery can reach it.
- **Why the feature barely moves predictions even when built correctly** is
  itself a live question -- xgboost's threshold-crossing behaviour means a
  real, correctly-computed signal can still be invisible to the shipped
  model. Worth keeping in mind for any future feature of this shape (a
  seat-level additive correction), not just this one.
