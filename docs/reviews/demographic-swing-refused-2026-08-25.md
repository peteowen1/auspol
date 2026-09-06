# Demographics do not predict swing — except in the seats where they were supposed to

2026-08-25, against
[../plans/prereg-demographic-seat-model.md](../plans/prereg-demographic-seat-model.md).
`scripts/fit_demographic_swing.R`. **Nothing adopted, and no harness arms were
built** — the fit was run first precisely so that decision could be made before
the expensive part.

## The overall result: refused

Leave-one-election-out across VIC 2018→2022, NSW 2019→2023 and SA 2022→2026;
211 (seat, party) rows. The question is whether demographics predict a seat's
**swing deviation** — how far it moves beyond the statewide swing — which is
the only thing a demographic term could add on top of a baseline the model
already has.

| | MAE of the swing deviation |
|---|---:|
| **uniform swing** (predict zero) | **3.850** |
| demographic model | **4.087** |
| improvement | **−0.237** |

**Worse than predicting nothing, and better in only 2 of 12 (party, pair)
cells.**

In-sample it looks like there is something — adjusted R² of 0.024 (ALP), 0.032
(LNP), 0.023 (GRN) and **0.110 (OTH_RIGHT)**. Out of sample it does not
generalise. `OTH_RIGHT` has the strongest in-sample fit and is worse in **all
three** pairs (−0.311, −0.090, −0.781), which is textbook overfitting across
elections.

**This confirms the feasibility review's caveat.** Demographics associate
strongly with the *level* of the vote, our baseline already encodes the level
more precisely, and nothing was left over for the swing.

## The pre-registered subgroup goes the other way

The plan named one subgroup as *"the entire argument for demographics"* and
defined it before any result was seen: seats whose swing deviation exceeds
**15 points** — where the previous result is a poor guide.

| party | pair | seats | uniform MAE | demographic MAE | improvement |
|---|---|---:|---:|---:|---:|
| ALP | sa2026 | 3 | 19.92 | 19.67 | +0.24 |
| LNP | vic2022 | 3 | 16.74 | 16.16 | +0.58 |
| LNP | nsw2023 | 4 | 22.27 | 21.28 | +0.99 |
| OTH_RIGHT | nsw2023 | 3 | 35.99 | 34.03 | **+1.96** |

**Better in 4 of 4 cells, pooled +0.945.**

That is the pattern the MRP argument predicts: demographics are useless where
the baseline works and useful where it breaks.

## Why this is reported and NOT adopted

**The plan did not anticipate this case.** It said adoption is refused if the
demographic arm wins overall but loses on the subgroup. It is silent on the
reverse, which is what happened.

Adopting on a subgroup **after losing the overall test** is cherry-picking, and
it is the exact move `CLAUDE.md` records twice as having gone wrong here. The
absence of a rule covering this case is not permission.

Three further reasons it would be wrong to act on:

- **Thirteen seats.** Four cells of 3, 3, 4 and 3. Four-of-four is a sign test
  at p = 0.0625 one-sided — suggestive, not significant, and the plan already
  committed to claiming no significance at three clusters.
- **The improvement is 1–5% of a catastrophic error.** `OTH_RIGHT` in NSW goes
  from **35.99 to 34.03** points of MAE. Both are hopeless. Demographics make a
  disastrous prediction fractionally less disastrous; they do not rescue it.
- **It does not reach MacKillop.** A seat needing a 23-point correction is not
  helped by a term worth one or two.

## What this settles

**Seat-level demographics do not solve the problem that started this.** The
association is real, the out-of-sample swing signal is absent, and the one
encouraging subgroup is too small and too weak to build on.

That closes the cheap version of Path A. It does **not** rule out the expensive
version — booth-level regression has roughly twenty times the observations per
election and can see within-seat structure that a single seat-level row cannot.
But that needs the SA1 correspondence and Census at booth geography, and this
result is a reason to be sceptical rather than encouraged about it.

**Also untested and now unlikely to be worth testing:** arm C, demographics
with no baseline at all. If a demographic term cannot improve on a baseline, a
demographic model with no baseline is not a promising direction at this
resolution.

## Cost

The Census acquisition was still worth it: it is reusable, correctly joined,
and the question is now answered rather than assumed. **Nine hours of
hypothesis-testing today produced one shipped fix — `shrink` in the SA
harness — and a great deal of ruled-out ground.**
