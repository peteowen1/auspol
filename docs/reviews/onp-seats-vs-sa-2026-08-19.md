# The seat model may be under-calling One Nation by about half, not over-calling it

Measured 2026-08-19. **Nothing changed.** This is the first external check on
the seat model's minor-party output, and it points the opposite way from the
three experiments that preceded it.

## The check

South Australia voted in March 2026. It is the only observation of One Nation
contesting at the level Victoria is forecasting, and it is complete — so the
relationship between a district's One Nation first-preference share and whether
it won the seat is *measurable*.

Derived from first preferences plus the full transfer record (a party never
excluded keeps everything transferred to it):

**One Nation won 7 of 47 SA districts on 22.9% of the statewide first
preference vote.** An independent won one.

Win rate by first-preference band:

| ONP first prefs | districts | won | rate |
|---|---:|---:|---:|
| under 20% | 18 | 0 | 0.00 |
| 20–25% | 9 | 0 | 0.00 |
| 25–27.5% | 6 | 2 | 0.33 |
| 27.5–30% | 5 | 1 | 0.20 |
| 30–32.5% | 1 | 0 | 0.00 |
| over 32.5% | 8 | 4 | 0.50 |

A logistic fit puts the 50% point at **33.5%** of first preferences.

## Applied to Victoria

Victoria's projected One Nation shares, rebuilt exactly as `fit_seats_full.R`
builds them (mean 20.2, sd 6.6, max 33.0), run through SA's own share-to-win
curve:

| | expected One Nation seats |
|---|---:|
| **SA's curve applied to Victoria's projected shares** | **6.2** |
| **What the Victorian seat model expects** | **2.96** |

The model expects **about half** what the only comparable election implies.

## Why this matters more than the number

Three experiments in a row — share-level uncertainty, ordering uncertainty, and
the independents fix before them — were all concerned with **preventing One
Nation's seat count from rising**. Two were refused specifically because the
change lifted its win probability in most seats.

The only external evidence available says the count should be roughly twice as
high to begin with. **I spent three experiments guarding against a movement in
the direction the evidence supports.**

That does not make those refusals wrong: each failed its own pre-registered
terms, and a change that happens to move a number toward where you later decide
it should be is not thereby validated. But the framing was wrong, and it was
wrong because there was no external anchor — exactly the omission this check
fills.

## What would make this comparison invalid

Stated plainly, because it is a cross-state comparison and those are easy to
oversell:

- **The logistic fit is in-sample.** It reproduces SA's 7 wins from SA's own 47
  districts, which is not validation — a two-parameter fit on 47 points should
  do that. "7.0 against 7 actual" is arithmetic, not evidence.
- **The band table is not monotonic.** One district sits in 30–32.5% and lost,
  giving that band a rate of 0.00 between bands of 0.20 and 0.50. With eight
  wins spread over 47 districts, the shape of the curve is poorly determined.
- **The party landscape differs.** SA's Labor won 35 of 47; Victoria's contest
  is far closer, and the Nationals hold the kind of regional seats where One
  Nation polls best in Victoria but which have no SA equivalent. A three-way
  regional contest converts differently from a two-way one.
- **Preference flows differ**, and One Nation wins these seats on preferences —
  the SA winners polled 27–38% primary and finished above 40%.
- **One election.** Everything here rests on a single state's single result.

## What this changes about the next step

The queued next step was a fourth attempt at bounding the upward lean from
adding uncertainty. **That is now the wrong question to ask first.**

Before tuning how uncertainty moves the count, establish whether the count is
right: 2.96 against an external estimate of 6.2 is a bigger discrepancy than
anything the three experiments were arguing about, and it has a plausible
mechanical cause — the model's projected maximum is 33.0%, which is exactly the
point where SA's curve reaches even odds. **No Victorian seat is projected past
the level at which One Nation was more likely than not to win in SA.** If the
projected spread is too narrow, every downstream question about uncertainty is
being asked about the wrong distribution.

That is the thing to pre-register next, and the criterion should be this
comparison rather than an internal symmetry rule.
