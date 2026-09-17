# Pre-registration: does a departed major-party member's unclaimed vote stay
# with the old party, or evaporate?

Written 2026-09-17, **before any arm is run**. Follows the PR #44 review
gate's item 2 (`docs/NEXT-STEPS.md`, "OPEN, 2026-09-16").

## The claim being tested

`personal_prior_vote()`'s major-party defector path (`R/candidate_returns.R:579-604`)
sets `transfer := def_pcv * rate` — only the DISCOUNTED portion of the
departing member's vote is removed from their old party's seat base via
`remove_transferred_votes()`. The undiscounted remainder, `def_pcv * (1-rate)`,
stays in the old party's base and feeds `dev_slope()`'s seat-level prior for
whoever the party runs next in that seat — a **conserving** assumption: the
party's own machine/brand inherits what the departing member didn't
personally take with them.

The minor-to-minor path (same file, `:533-536` plus the generic fallback at
`:616`) does the opposite: `transfer` carries the FULL undiscounted vote, so
a one-member minor loses its entire base when its only candidate leaves —
**non-conserving**. That choice was measured (`docs/reviews/minor-to-minor-defector-2026-09-16.md`)
and shipped. The major-party choice has never been tested against the
alternative; it was written this way from the start on the same
"party has infrastructure" intuition, never checked against real cases.

## WHAT I ALREADY KNOW, stated before the criterion

**The target population, sized before writing any bar**: 33 major-party
defector cases across 18 pairs (20 sitting-member, 13 losing-candidate,
matching the counts already fitted separately by `fit_defector_discount()`).
**All 33** have the old major party fielding a different candidate at the
target election — every case is scorable, none is vacuous.

**The old party's actual retention is wildly heterogeneous, not clustered
near either extreme**: ratio of `old_now_pcv` (old party's actual vote after
the defection) to `prior_pcv` (the departed member's own prior vote) ranges
from **0.20 (Kiama, LNP after Gareth Ward)** to **0.97 (Corio, ALP after a
2007 defection)**. Some seats show almost total brand collapse; others show
almost none. This is the same heterogeneity shape the minor-to-minor review
already found on the OTHER side of an identical question ("some defections
collapse, some gain") — there is no reason to expect a single conserving-or-not
assumption to be right everywhere, only to be the better AVERAGE assumption.

**This is not symmetric with the minor-to-minor question in blast radius.**
33 cases is coincidentally the same count, but every major party runs in
every seat in the corpus, so a change here touches the OLD PARTY's predicted
primary in all 33 of these specific seats directly, and (via `dev_slope()`'s
statewide-level term) has a small second-order effect on every OTHER seat
that party contests, in every one of the six harnesses. The minor-to-minor
change only ever touches the minor party's own seat-level prediction.

**The standing rule applies**: `personal_prior_vote()` is called from both
the six harnesses' own `base_pred`-building code AND `fit_xgb_primary_v6.R`'s
xgb-feature-building call (`CLAUDE.md`, "test any primary-vote fix in both
layers, always" — the exact failure mode that bit `seat_outperf` and the
minor-to-minor discount on 2026-09-16). This must be measured in both.

## The change

A new switch, **`AUSPOL_DEFECT_CONSERVE`**, applied at the single line that
sets `transfer` in the major-party branch (`R/candidate_returns.R:602`):

- `1` (default, reproduces current behaviour exactly): `transfer := def_pcv * .rate`.
- `0`: `transfer := def_pcv` — the full amount, matching the minor-to-minor
  path's own treatment. `own_prev_pcv` (what the NEW class receives) is
  UNCHANGED either way; only how much comes OUT of the OLD class moves.

No change to the discount rate itself (`major_discount`/`loser_discount`),
`x_notional_adj`, or anything else already shipped.

## The criterion

**Primary: RMSE of the OLD major party's predicted primary vote against
actual `old_now_pcv`, over the fixed 33-case set**, measured twice —
once through `base_pred` (each of the six harnesses' own prediction for
that seat/party, non-circular procedure, `AUSPOL_XGB_PRIMARY=0`) and once
through the xgb layer (`fit_xgb_primary_v6.R`'s `xgb_pred` for the same
33 rows). **Both must be reported; a result in one layer only is not
reportable as a finding**, per the standing rule above.

**Adopt `AUSPOL_DEFECT_CONSERVE=0` (non-conserving) only if it beats the
current conserving default by at least 5% RMSE in BOTH layers.** Keep
conserving if either layer fails to clear the bar, or if the layers
disagree in direction (one better, one worse) — a fix that only works in
one layer isn't reaching the published forecast reliably, the same lesson
`seat_outperf` and the minor-discount transfer bug both taught the hard way.

**Guard, must not worsen by more than 0.005: pooled primary RMSE across
all rows** (both layers), via the standard non-circular `pool_sharedetail.R`
/ `fit_xgb_primary_v6.R` procedure.

**Guard, must not worsen by more than 0.005: pooled seat log loss across
all 23 pairs**, full six-harness backtest, `AUSPOL_N_SIMS=5000` exploratory
— only run if the primary bar clears in both layers first (no point backtesting
a change the targeted metric already refused).

## Refusal: what makes an apparent win unacceptable

- **If either layer misses the 5% bar**, per above.
- **If the gain is carried by fewer than 5 of the 33 cases.** Same shape as
  the minor-to-minor grid's own refusal condition, and there is already a
  concrete reason to expect it here: Kiama (ratio 0.20) and Corio (ratio
  0.97) are 5x apart, so a small number of near-total-collapse seats could
  easily dominate an aggregate RMSE the same way Fremantle 2008 did for the
  minor-to-minor grid.
- **If sitting-member and losing-candidate cases move in OPPOSITE
  directions.** `fit_defector_discount()` already fits these as two separate
  rates because their retention scales differ (0.282 vs 0.142); a conservation
  rule that helps one subgroup and hurts the other by more is not a general
  fix, it is re-fighting the two-rate question with a different lever.
- **If either election-wide guard breaches.**
- **If the win requires reducing `major_discount`/`loser_discount` at the
  same time.** That would be trading one lever for another rather than
  answering the question this pre-registration asks.

## What the criterion cannot see

- **Why some seats collapse to 0.20 and others barely move.** Same
  unanswered question the minor-to-minor review already named on its side;
  a single conserving-or-not constant does not explain the heterogeneity,
  it only picks the better average given it exists.
- **Whether a genuinely PER-SEAT conservation rate (rather than a binary
  switch) would beat both endpoints.** This pre-registration tests the two
  endpoints of a spectrum, not the spectrum itself — a real finding either
  way should prompt asking whether a partial/fitted rate (analogous to
  `major_discount` itself) beats both, as its own follow-up, not smuggled in
  here.
- **Whether 33 cases (18 pairs) is enough corpus to trust a fitted
  in-between rate even if the endpoints disagree** — same caveat the
  minor-to-minor pre-registration named for itself.

## Prediction, written before running

**I expect the primary bar to fail, or to clear in only one layer.** The
heterogeneity in the case table (ratios from 0.20 to 0.97) means neither
endpoint should fit the corpus well on average, and the current conserving
default already sits closer to the corpus median (most cases lose 15-25% of
the departed member's OWN vote, not the near-total collapse the extreme
cases show) than a full-removal assumption would. **If anything clears the
bar, I expect it to be driven by the small number of near-total-collapse
seats (Kiama, MacKillop, Black)** — which the concentration refusal
condition should then catch, the same shape as arms C and D in the
minor-to-minor grid. **My best guess is this closes the same way**: a
real, named heterogeneity that no single constant resolves, current default
kept, logged as a candidate for a future per-seat or per-subgroup rate
rather than a binary switch.

---

# RESULT, 2026-09-17: decisive. Keep conserving. My prediction was wrong,
# in the interesting direction.

**Structural finding, verified before trusting the "both layers" bar**:
`fit_xgb_primary_v6.R:271` never passes `major_discount` to
`personal_prior_vote()` at all — only `minor_discount`. The entire
major-party defector mechanism this switch lives inside, not just the
conserve/non-conserve question, **cannot reach the xgb layer**, in either
setting. Confirmed empirically (`scripts/prereg_major_defector_verify.R`):
identical `NA` `own_prev_pcv` for a known case (Calare) regardless of the
switch. The pre-registration's "must clear both layers" bar is
inapplicable — there is only one layer where this mechanism exists at all
(`base_pred`, via the six harnesses, which do pass `major_discount`).

**Result, `base_pred` layer, all 33 cases, genuine non-circular
(`AUSPOL_XGB_PRIMARY=0`, verified via `sharedetail`'s own `xgb_primary_on`
column — a first pass forgot this flag, was silently contaminated by the
xgb override, caught before trusting it, redone):**

- RMSE: conserving (shipped) = **8.5878**, non-conserving = **26.5369** —
  **209% worse**, not a near-miss.
- Subgroups agree in direction: sitting-member -192.6%, losing-candidate
  -259.8%.
- Concentration: only 1 of 33 cases (Kiama) individually improved under
  non-conserving; every other case got worse.
- Pooled primary RMSE guard: non-conserving worsens every jurisdiction
  except NSW (fed +0.21, qld2020 +0.26, sa2026 +0.89, sa2022 +0.52,
  vic +0.37, wa +0.28) — all far past the 0.005 guard.

**Primary bar fails decisively. No guard backtest run** — the
pre-registration's own instructions say not to once the primary metric
already refuses this clearly.

**My prediction was wrong, in the interesting direction.** I expected
heterogeneity too wide for either endpoint to win, with any apparent win
concentrated in a few collapse seats. Instead conserving wins outright and
by a huge margin: most major-party defector seats retain the bulk of their
vote (ratios 0.7–0.97), so removing the full amount massively under-predicts
almost every case. The asymmetry with the minor-to-minor path is real and
now measured, not just a plausible story: a major party keeping its
machine when a member walks is not a weaker version of the same effect a
one-member minor shows — it is close to the opposite end of the scale.

**Verdict: keep `AUSPOL_DEFECT_CONSERVE=1` (current behaviour). Closes item
2 of the PR #44 review.**

## A second, unrelated, LIVE finding surfaced while tracing this

Investigating why the switch can't reach the xgb layer led to checking
whether `fit_seats_full.R` (the actual published forecast) applies
`minor_discount` at all. **It does not, anywhere** — its one `personal_prior_vote()`
call (used for both the `mat22` base AND, via the same object, the
`xgb_primary_predict_live()` feature) passes `major_discount` only.
Training's xgb feature IS minor-discounted (`fit_xgb_primary_v6.R:271`);
live-serving's is not — a train/serve mismatch in `own_prev_pcv`, the same
shape as `seat_prev_pcv`'s fix earlier this session, for a different
column. **Not dormant**: vic2026's current partial candidate list already
has 5 minor-to-minor defector cases (Frankston, Broadmeadows, Lara,
Werribee, Sydenham). Tracked as its own fix, not folded into this
pre-registration's result — see the commit that follows.
