# How we weight elections and seats: in training, and in judging the model (2026-10-13)

Pete, 2026-10-13, after vic2010 as training data made later elections worse (pooled seat log loss 0.3195 without it,
0.3256 with it, +0.0061, 2.3 SE; every pre-2010 election byte-identical, so the test is clean):
*"down weight in training - and we need to decide what metrics/elections we score our model training off --- i.e.
are all seats weighted equally? should probably weight based on number of polls or number of people in the seat or
something? and more recent more heavily weighted (decay?) ... we dont really care about pre 2010 as well too much so
can either ignore on model fit scoring or downweight (aef7 still priority for now)"*.

Two different weightings, easy to confuse:

- **A. Training weights**: how much each historical row (pair x seat x party class) counts when a model is FITTED
  (the as-at vote-share models, the level-blend constant, flow models, slopes).
- **B. Scoring weights**: how much each seat and election counts when we JUDGE a change (the objective in
  `memory: objective-all-elections-logloss-rmse`; today: pooled seat log loss over all scored seats, each seat equal;
  AEF-7 to iterate, all 22 to ship).

## What happens today

- Training: every row of every earlier election counts equally (time-forward, so only earlier elections). A 2007
  federal seat counts as much as a 2022 one.
- Scoring: each SEAT counts once. Federal elections have 150 seats against SA's 47, so the seven federal pairs carry
  1,051 of 2,120 seats (50%); WA 2001-2008 (unusual, old, thin features) carry 162.

## A. Training-weight options

| option | what it does | for | against |
|---|---|---|---|
| A1 recency decay | weight = 0.5^(years before the target / h); h fitted time-forward with a prior (e.g. 8 years) | politics drifts (One Nation, teals, preferences); recent rows describe today better | fewer effective rows; h needs fitting without leakage |
| A2 feature completeness | down-weight rows whose features are thin (salience mostly zero, census approximate, no seat polls) | targets the likely vic2010 cause directly | a judgement on which features count as "complete" |
| A3 era floor | rows before 2010 get a fixed small weight (or 0) | simple; matches "pre-2010 doesn't matter much" | a cliff (CLAUDE.md prefers decays/shrinkage over cut-offs) |

Recommended: **A1 + A2 together**, decay half-life fitted time-forward with a weak prior, completeness as a multiplier;
no hard era cut (A1 already makes 2001 rows small). Measured by the full rebuild against the bundle without vic2010
(0.3195), on all pairs, AEF-7 first.

## B. Scoring-weight options (what "better" means)

| option | what it does | for | against |
|---|---|---|---|
| B1 each seat equal (today) | pooled over seats | simple; every seat is a real contest | federal dominates (50%); a chamber of 150 is not 3x more important than one of 47 |
| B2 each election equal | each election's mean seat loss, then averaged | every election counts once; small states not drowned | a 47-seat election's noise counts as much as a 150-seat one |
| B3 by voters (enrolment) | seats weighted by electors | "people affected" | within a jurisdiction seats are equal-population by law, so this is ~B1 within and makes federal dominate MORE across |
| B4 by polls | weight by how many polls the cycle had | data-rich elections count more | rewards data, not importance; old/thin elections are exactly where we want to learn |
| B5 recency | recent elections weigh more (decay) | the live forecast is about now | judging on few elections raises noise |

Pete also wants pre-2010 out of (or down-weighted in) the fit scoring, and AEF-7 to stay the priority.

Recommended: **primary = AEF-7, election-equal (B2)**; guard = all pairs from 2010 on, election-equal; pre-2010 pairs
reported, never decisive. Seats within an election stay equal (B3 adds nothing within a jurisdiction, B4 measures the
wrong thing). Recency (B5) enters through AEF-7 being the seven most recent elections rather than as a separate decay.

## Worked example (to walk before fitting)

vic2018 Hawthorn (Labor gained from the Liberals): bundle with vic2010 in training gave Labor 0.043; without it, see
`deciding-runs/bundle-20261013/` vs the skip run. Under A1 with h = 8 years, vic2010 rows would count 0.71 for a 2014
target and 0.50 for 2018; fed2007 rows ~0.18 for a 2022 target.

## Status

Decisions pending (Pete). Nothing published from the vic2010 bundle; dev holds the vic2010 plumbing unpushed (it
must publish with its rebuild).

## Decisions (Pete, 2026-10-13)

1. **Training: decay + completeness.** Rows lose weight with age (half-life fitted time-forward, weak ~8-year prior)
   and with thin features; no hard era cut.
2. **Scoring: each election counts once, seats equal within it** (Pete's question: a Victorian state seat covers about
   half the electors of a federal Victorian division, so seat-equal gives it ~2.3x the weight; elector-weighting would
   swing the other way, one federal election = ~4 Victorian = ~14 SA). Seats within an election share one statewide
   polling error, so the independent unit is the election; the clustered SE already treats it so. A voter-weighted
   view is reported, not decisive.
3. **The guard is replaced** (Pete: "a bug fix ... might improve 17 elections and harm 5 which is clearly good but
   technically 'does harm'"): decide on the election-equal mean change in SE (beyond 1 SE = real); report the count of
   elections better / worse; a single election harmed badly must be explained (cause traced, like Barwon 2019), then
   Pete decides, never an automatic refusal.
4. **Which elections:** AEF-7 primary while iterating; all 2010+ pairs the second view; pre-2010 reported only.

## Next

Build: (a) training row weights (decay + completeness) in the time-forward fits, starting with the as-at vote-share
models where vic2010's harm entered; (b) the new scorer in `scripts/compare_rebuild_scores.R` (election-equal mean,
AEF-7 and 2010+ views, better/worse counts, voter-weighted view). Then rebuild with vic2010 in training under the new
weights and compare to 0.3195 (bundle without vic2010) under the new scorer.
