# A minor-to-major party switcher can erase a retiring major incumbent's
# entire seat base

2026-09-17, found tracing why `AUSPOL_XGB_BASE_MARGIN`'s biggest single-seat
regression (Pilbara, wa2013, `base_pred` predicting LNP at 81.94% against an
actual 61.73%) happened at all — traced to the harness's own `base_pred`
computation, not the base_margin experiment. **This is a live gap in the
shipped model, unrelated to that refused arm.**

## The mechanism, confirmed by direct instrumentation

`backtest_candidate_wa.R`'s `mat` row for Pilbara/wa2013, immediately before
renormalisation to 100%:

| ALP | GRN | IND | LNP | OTH_RIGHT | row sum |
|--:|--:|--:|--:|--:|--:|
| 6.93 | 0.00 | 1.49 | 50.40 | 2.68 | **61.50** |

The row sums to 61.50, not 100, because `dev_slope()` (or `split_dev_slope()`)
is applied independently per class with no joint constraint. Renormalising
(`shares <- 100 * mat / rowSums(mat)`) then inflates every class
proportionally: LNP 50.40 → **81.94** (matches `pooled-sharedetail.csv`
exactly), ALP 6.93 → **11.27** (also matches exactly).

**Why ALP's pre-renormalisation value collapsed to 6.93 when Pilbara's ALP
incumbent (Stephens) polled 44.38% in 2008**: `personal_prior_vote()`
identity-matched **Howlett**, who ran as **GRN** in 2008 (9.63%) and switched
to **ALP** in 2013 as the party's new candidate in Pilbara, after Stephens
retired. `.own_x()` substitutes Howlett's own prior vote (9.63%, from a
completely different, minor party) as the ENTIRE ALP class's pre-swing base,
discarding Stephens' real 44.38% outright. `dev_slope()` then projects
forward from 9.63, not 44.38, and the class-level result (6.93) reflects a
minor party's personal-vote history standing in for a retiring major
incumbent's seat.

**The renormalisation then spreads that damage to every OTHER class in the
seat** — LNP didn't do anything wrong; it got inflated because its
neighbour in the same row collapsed.

## Why this is the mirror image of a question already settled today

`docs/plans/prereg-major-defector-conserve-2026-09-17.md` measured and
refused non-conserving treatment for a MAJOR-party member defecting TO a
minor party. This is the reverse direction — a MINOR-party candidate
switching INTO a major party's seat — and it has never been measured or
even named as a distinct case. `personal_prior_vote()`'s own_prev_pcv
substitution applies uncritically regardless of direction: it treats
"identity match found, substitute this person's own prior vote" the same
whether the person is a returning major incumbent, a major-to-minor
defector, or (this case) a minor-to-major arrival replacing someone else
entirely.

## Scale, not yet measured

Not sized against the corpus. The shape (a minor-party candidate becomes a
major party's new candidate in a seat where that major party's own MP
retires or was not the same identity) is a real, recurring pattern —
Pilbara/wa2013 is not obviously a one-off. Worth sizing the same way the
conserve/non-conserve question was sized today (count of corpus cases,
distribution of how wrong the resulting projection was) before deciding
whether this needs a fix, and if so, what shape (exclude minor-to-major
switches from `own_prev_pcv` substitution entirely and fall back to the
class-level base, the same way major-to-minor already has a discount
rather than a full substitution).

## What this does NOT explain

This is `base_pred`'s own error, computed identically regardless of
`AUSPOL_XGB_BASE_MARGIN`. It explains why Pilbara/wa2013 was the single
worst swing in the base_margin backtest (a badly wrong `base_pred` is
exactly the shape `base_margin` mode cannot recover from, per the earlier
SHAP trace), but the underlying `base_pred` error already existed in the
shipped model before today's experiment and affects the plain-feature
baseline too — it was just partially correctable there (the baseline
model's own xgb layer predicted 65.4 for this cell, much closer to actual
than base_pred's 81.94, by using other features to discount base_pred
heavily for this row).
