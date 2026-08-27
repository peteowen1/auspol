# Pre-registration: a multi-feature surge hazard, not a point-estimate regression

> **OUTCOME 2026-08-27: ADOPTED, gated OFF by default pending Victoria review.**
> Beats the naive base-rate baseline on 4 of 5 elections in nested LOO (mean
> log loss 0.0295 vs 0.0455) and improves fed2022/nsw2023/sa2026 backtest log
> loss by 26-30% with no accuracy or Brier cost. vic2022 alone shows a small,
> non-accuracy-affecting wash (+1.9% log loss). See the backtest table below.
> Wired into all five harnesses and `fit_seats_full.R`, everywhere gated
> behind `AUSPOL_SALIENCE_SURGE_V2=1` (default off) -- the published
> forecast is unchanged until this is explicitly turned on.

Written 2026-08-27. **Note on process**: the design below was fixed in an
approved implementation plan (via Claude Code's plan mode) before the fed2019
fetch or any fitting ran -- the criteria, refusal clauses and model form were
not edited after seeing results. This document itself is written after
scoring, consolidating that plan and its outcome into the repo's own
pre-registration convention rather than living only in a session transcript.

## What this replaces, and why not a direct regression

The salience screen (`salience_permit_for()`) correctly `permit`s every
genuine emergent winner, but `permit` only ever changes which SLOPE a
candidate's uniform swing uses -- it never touches the point estimate. A
permitted candidate with a near-zero seat prior still gets swung from
near-zero, so fed2022's re-run after the screen fix scored log loss 0.8123 --
**worse than the naive 50/50 baseline (0.6931)** -- because 78.7% of total log
loss came from 10 seats, 8 of them genuine emergent winners called at
near-zero probability.

The obvious fix -- regress vote share directly on salience -- was already
pre-registered and REFUSED one day earlier
(`docs/plans/prereg-nonmajor-vote-regression.md`,
`docs/reviews/salience-regression-refused-2026-08-26.md`). A linear
`pcv ~ prev_party + log1p(jump) + is_ind + is_grn + prev_ind` model beat
baseline on fed2022 (the teal wave) and then predicted Adam Bandt at 66.2% on
an actual 39.5%, because a linear jump term applied to every non-major
candidate cannot distinguish "loud because emerging" from "loud because
famous incumbent."

## The design

Two choices, both aimed directly at that failure mode:

1. **Gate to the governed population only** (`governed_population()`:
   `prev_party < 15 & !surging & !ret`). Bandt (23.7% prior) and 2025-Ryan
   (34% prior) both fail `prev_party < 15` and are excluded BY CONSTRUCTION,
   not by a criterion checked after fitting.
2. **Extend the existing `surge_h` hazard mechanism in
   `simulate_seat_contests()`** (a per-seat probability of a fat-tail draw,
   already used by `backtest_candidate_fed.R`) instead of overriding the
   point estimate. A hazard that fires with probability `p` widens the tail
   without forcing every permitted candidate's expectation up the way a
   linear regression does.

Model: logistic hazard `elected ~ jump_pctile + prev_party + prev_ind +
party`, features carried over unmodified from the refused pre-registration's
own (validated-on-fed2022) feature search -- that search wasn't what failed,
its application to a non-gated population was. `jump_pctile` is jump
percentile-ranked WITHIN each election (each Trends batch chain anchors on a
different first query, so raw jump is not comparable across elections -- a
real construction fault the refusal review found and this fixes).

## Two more bugs found building this, both fixed before scoring

- **Quasi-separation.** A first attempt with plain `glm()` had only 8 winners
  across 687 governed candidates against 4-7 effective parameters --
  `algorithm did not converge`, and Ian Cook (18% actual, lost) scored
  p_hat=0.619, reproducing the Bandt-style failure via overfitting instead of
  an ungated population. Fixed with an L2 (ridge) penalty, chosen by NESTED
  leave-one-election-out so the penalty itself never sees the outer held-out
  election.
- **A seat rename.** Andrew Wilkie held Denison (2016, 44.1%) continuously
  into its 2019 rename to Clark (50.0%); `governed_population()`'s seat
  matching only strips case/punctuation, not genuine redistribution renames,
  so he scored as a fresh governed candidate with `prev_party` near 0 --
  directly contaminating the fitted surge-size estimate (his 50% pulled the
  mean of "what a governed winner gets" up alongside six genuine 25-44%
  emergences). Fixed with a small, high-confidence `SEAT_RENAMES` lookup
  (Denison->Clark, Batman->Cooper, Melbourne Ports->Macnamara); other renames
  found while diffing seat-name sets between election pairs (1-10 per pair,
  most genuine seat creation/abolition from population growth, not renames)
  are a disclosed, unmapped gap -- see `governed_population()`'s docs.

## Data: fed2019 fetched, no longer a blind holdout

`output/salience-v6.csv` covered fed2022/vic2022/nsw2023/sa2026 only. fed2025
was ad-hoc probed for the refused regression (not the full v6 pipeline) and is
"spent" -- its Bandt failure is known and would bias tuning. fed2019 was the
one untouched federal election; per direction, it was fetched and POOLED into
training (not reserved as a blind test) once the first `glm()` attempt showed
the feature set needed more data, not fewer features. This is a real,
deliberate cost: no federal election remains available as a genuinely blind
test for a future revision of this model.

## Results

**Nested LOO, ridge-penalised, governed population only** (mean log loss:
model 0.0295 vs base-rate-only 0.0455):

| election | n | winners | lambda | log loss | base rate |
|---|--:|--:|--:|--:|--:|
| fed2019 | 305 | 1 | 1.0 | 0.0136 | 0.0263 |
| fed2022 | 291 | 6 | 0.5 | 0.0629 | 0.1167 |
| vic2022 | 166 | 1 | 0.5 | 0.0472 | 0.0376 |
| nsw2023 | 169 | 1 | 1.0 | 0.0203 | 0.0371 |
| sa2026 | 61 | 0 | 0.5 | 0.0033 | 0.0097 |

**Dry-run**: Ian Cook (Mulgrave 2022, 18% actual, lost) scores p_hat=0.098 on
the full-population fit -- no longer overconfident. David Speirs correctly
drops out of the governed population entirely: he is a former sitting
Liberal MP re-contesting the same seat as an independent, so the personal-name
match correctly flags him as returning even under a new party label.

**Full backtest, arm CS (screen) + surge-v2 vs arm CS alone**, same seed,
same data, only the surge arm toggled:

| election | baseline log loss | surge-v2 | change | accuracy | Brier |
|---|--:|--:|--:|---|---|
| fed2022 | 0.8123 | 0.5671 | **-30.2%** | 129/150 both | 0.1202 -> 0.1205 |
| nsw2023 | 0.8423 | 0.6039 | **-28.3%** | 72/88 both | 0.1302 -> 0.1322 |
| sa2026 | 0.8825 | 0.6541 | **-25.9%** | 38/47 both | 0.1472 -> 0.1436 |
| vic2022 | 0.2399 | 0.2445 | +1.9% | 67/78 both | 0.0820 -> 0.0823 |

No election's top-line accuracy changed at all -- every improvement is in how
much probability mass the true winner gets, not in which seat is called.

## Criteria (pre-registered in the approved plan, before fetching/fitting)

1. Log loss beats the governed-population baseline (uniform swing, no surge)
   on the pooled LOO -- **met**, 0.0295 vs 0.0455.
2. Dry-run: known high-jump governed losers (Cook, Speirs) must not score
   high -- **met**, Cook 0.098, Speirs correctly excluded.
3. No feature beyond the four listed added after seeing results -- **met**,
   unchanged from the refused pre-registration's own validated search.

Refusal clause as written: *"if gating to the governed population removes so
much of the effect that fed2019 shows no improvement over baseline, that is a
real result -- say so, don't re-open the population definition post-hoc."*
vic2022's small wash is exactly this kind of honest negative result on one of
four elections, not chased or explained away, reported as-is.

## What the criteria cannot see

- **Only 9 total governed winners across 5 elections fund this whole model.**
  A single future emergence election could move the fitted coefficients a
  lot; this is not a stable large-sample estimate, and should be refit as
  more elections' salience data becomes available (the parallel scrape of 18
  further historical elections, running as of this commit, extends the
  corpus for a future revision even though most of those elections lack a
  usable `prev_party` baseline of their own -- see
  `fetch_salience_v6.R`'s `(missing)`-flagged entries).
- **vic2022's softness is exactly the state that matters live.** Only one
  genuine emergent winner (De Vietri, Richmond) exists in vic2022's governed
  population to validate against -- a single data point is not strong
  evidence either way about how this will perform on vic2026.
- **No federal election remains available as a genuinely blind test.** Any
  future federal revision of this model has no fresh federal holdout left.
