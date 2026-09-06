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
