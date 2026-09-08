# Pre-registration: the salience point estimate is an EXPECTED VOTE, not a win probability (P5)

Written and committed 2026-09-07 BEFORE any code. Pete's observation, and it
is a category error in the shipped mechanism rather than a tuning question.
Baseline: the published configuration at `f9f8c72`, 20,000 draws.

## The defect

`surge_blend_estimate()` sets a governed candidate's point estimate to

```
(1 - p_hat) * uniform_swing + p_hat * surge_mu
```

where `p_hat` is the fitted probability that the candidate **WINS** and
`surge_mu` (35.1) is the mean vote of past **winners**. Mixing a vote share
with a win probability as the weight is not a prediction of anything: for
Goldstein 2022 it returns `(1 - 0.025) * 2.3 + 0.025 * 35.1 = 3.1`, when the
question being answered is "what will this candidate poll".

The right weight is the expected vote given the salience, which the same
training population already answers. Every candidate in the governed
population, banded by salience percentile (leave-one-election-out, so the
band mean never sees the election it is applied to):

| salience band | n | won | LOO expected primary | sd | p10 | p90 |
|---|--:|--:|--:|--:|--:|--:|
| top 0.5% | 12 | 4 | **21.1** | 14.0 | 6.3 | 39.9 |
| 98–99.5% | 36 | 7 | **14.0** | 12.6 | 1.7 | 33.4 |
| 95–98% | 48 | 5 | **10.3** | 9.9 | 1.2 | 25.8 |
| 90–95% | 85 | 0 | 6.8 | — | | |
| below 90% | 1,739 | 4 | 6.1–6.4 | — | | |

**A high-salience candidate who loses still polls 9 to 13.** The mechanism
gives them 3. On the seven fed2022 teals the LOO band estimate is 11.5
against an actual 29.1, where the model publishes 2 to 6.

## The change

For a candidate in the governed population, the point estimate becomes the
LOO band expectation and the draw takes that band's spread:

- `surge_hazard_for()` also returns `seat_party_expected`, the LOO band mean
  and sd per (seat, class), fitted on the training pairs with the target
  election excluded exactly as the hazard already is.
- The point estimate for that (seat, class) is `max(uniform_swing, expected)`
  rather than the hazard blend. A returning incumbent is not in the governed
  population and is untouched.
- The DRAW keeps the existing generative surge, with `surge_mu`/`surge_sd`
  replaced per seat by that band's mean and sd, and the hazard unchanged.
  A candidate can still fall short and lose.
- One switch, `AUSPOL_SALIENCE_EXPECTED` (published 0 until this decides).

Bands are the pre-registered form because 20 winners cannot support a
continuous fit (measured: `pcv ~ jump_pctile` over the winners has R² 0.015
and loses to a constant out of fold, 13.09 against 10.33 RMSE). The band
edges (0.90, 0.95, 0.98, 0.995) are fixed here and are NOT tuned later.

## Targets (primary), fed2022

The seven teals' projected IND primary: Kooyong 12.2, Mackellar 14.3,
Wentworth 35.9, Goldstein 2.3, Fowler 0.8, Curtin 9.5, North Sydney 5.8
against actuals of 40.3, 38.1, 35.8, 34.5, 29.5, 29.5, 25.2. A working
change moves each toward its band expectation (9 to 21) without moving
Wentworth, which is already right from Phelps's inherited base.

Dry run on known cases: Clark 2022 (Wilkie returning, not governed) must not
move at all; Cowper 2022 (Heise, governed, high hazard, LOST with 26.3%)
must RISE, and that is correct — she polled 26.3 — even though the seat's
winner does not change. Mallee 2022 (Baldwin, governed, polled 12.2) must
not rise far.

## Guards, all 17 elections (Pete's objective)

- Pooled seat-weighted log loss must improve by more than one SE of the
  paired per-election differences.
- **Seat-share RMSE is the co-primary here, not a guard**: this change is a
  vote-share prediction, so it must improve pooled RMSE as well. If log loss
  improves and RMSE worsens, the change is refused.
- The false-independent list must not grow: raising every high-salience
  candidate's expected vote will raise losers too, which is priced in the
  RMSE and must be visible in the count of seats where a governed class
  takes p > 0.30 and loses.
- Returning-incumbent independent and Greens-won seats: no fall beyond 0.02.

## Refusal, decided in advance

Refused if pooled log loss or pooled RMSE fails, or if the gain is carried by
fed2022 alone (it is the wave election and the one this was noticed in), or
if the count of governed classes given p > 0.30 that then lose rises by more
than the number of genuine emergences gained. **A change noticed on one
election must be shown on the other sixteen.**

## What this cannot see

Whether 2022's magnitudes were a wave. The band expectation is an average
over nine elections, so it will under-predict a wave year and over-predict a
quiet one; it cannot know which is which. That is the wave-term experiment,
and it stays separate.

## Amendment 1, written after the first fed2022 run and BEFORE scoring it

The change as pre-registered replaces the point estimate AND the draw's size
with the band expectation. On fed2022 the point estimate improved as intended
(seat-share RMSE 4.558 -> 4.274, Goldstein's projected primary 2.3 -> 10.4),
but the win probabilities FELL -- Mackellar 0.054 -> 0.022, North Sydney
0.025 -> 0.008 -- because a surge adding the band's 14 points does not win a
seat where one adding 35 did. The band mean is over winners and losers
together: the right number for "what will they poll", the wrong number for
"how big is a surge when one happens".

So the arm splits, and BOTH are run and reported:

- **Variant A**, exactly as pre-registered above (`AUSPOL_SALIENCE_EXPECTED=2`):
  point estimate and draw size both from the band.
- **Variant B** (`=1`): the point estimate takes the band expectation, the
  draw keeps the winners-only size. This is the amendment.

The original text is unedited above. Variant B is favourable to the result
found later, so it is named as an amendment and held to the SAME criteria:
pooled log loss and pooled seat-share RMSE over all 17 elections, both
improving, and not carried by fed2022.

## Result, 2026-09-07 — REFUSED on log loss; the vote-share gain is real and recorded

All 17 elections (the 11 state ones are unchanged by construction: the
point-estimate blend exists only in the federal harness, a cross-harness gap
named below). Variant B, against the shipped baseline:

| election | log loss | | seat-share RMSE | |
|---|--:|--:|--:|--:|
| | base | B | base | B |
| fed2010 | 0.3281 | **0.3152** | 3.844 | 3.927 |
| fed2013 | 0.3864 | 0.4136 | 4.718 | 4.904 |
| fed2016 | 0.3154 | 0.3182 | 4.844 | **4.594** |
| fed2019 | 0.2624 | 0.2648 | 4.726 | **4.713** |
| fed2022 | 0.3862 | **0.3706** | 4.558 | **4.274** |
| fed2025 | 0.3049 | 0.3096 | 4.297 | **4.040** |
| **pooled, 1,549 seats** | **0.3422** | **0.3430** | **4.697** | **4.645** |
| | | +0.2 SE | | −1.1 SE |

**Log loss does not improve, so the pre-registration refuses it**, whatever
the vote-share gain. Variant A is worse still on fed2022 (0.3946).

**What is nonetheless established, and matters:** the point estimate is
better. Pooled RMSE falls 0.051 and improves in 4 of 6 federal elections;
Goldstein's projected primary goes 2.3 → 10.4 and the seven teals' mean 13.4
→ about 19 against an actual 33.9. The category error is real and the fix
does fix it. What it does not do is change who wins a seat, because a
candidate lifted from 2 to 10 still loses to a major on 45, and the seat
probability only moves when the DRAW is large — which is variant A, and
variant A is worse.

So the honest statement is: **the salience signal now predicts the vote well
and the seat badly, and those are different problems.** fed2013 is the clear
cost (+0.027 log, +0.186 RMSE): raising the expected vote of governed
candidates in New England and Lyne, where they polled far below their
salience, hurts twice.

`AUSPOL_SALIENCE_EXPECTED` stays at 0. Kept, because the wave term would
change the size of the band expectation and this is the mechanism it would
act through.

**Cross-harness gap found here and not fixed:** the point-estimate blend
(`surge_blend_estimate`) is called only by `backtest_candidate_fed.R`. The
Victorian, NSW and SA harnesses use the hazard for the draw only, and
`fit_seats_full.R` — the published forecast — does not blend at all. So the
salience point estimate has never reached the published Victoria forecast.
That is its own item, ahead of any further salience modelling.
