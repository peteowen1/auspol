# Plan: a candidate who stood at the by-election keeps that result (2026-11-22)

Status: BUILT BEHIND AN OFF SWITCH for a live walk. Not shipped, not scored on a rebuild pair.

## Why

Found 22 Nov scoring the de-swing rebuild pair. Murray nsw2019: Helen Dalton took 18.2% as an independent in 2015,
31.5% as the Shooters candidate at the October 2017 by-election, and won with 38.8% (class 40.3%) in 2019. The model
predicted 4.0%. `own_prev_substitute()` replaces a class's seat cell with the lead candidate's own vote at the
PREVIOUS GENERAL ELECTION (here 18.2 x the non-sitting switcher rate 0.230 = 4.18), after the by-election half blend
has run, so whatever the blend put in that cell is lost (0, 15.7 and 31.5 going in all return 4.18).

## What was already seen (disclosed; not a test)

79 non-major candidates stood at a by-election and at the next general election (by-election table joined to
`output/candidacies.csv` on the person key); 69 have a result. Among those with 5% or more at the by-election in a
seat where both majors stood (n = 22), the published class prediction against the class result has RMSE 10.5 and
mean error -4.4; the person's raw by-election share against their own next vote has RMSE 8.8 and mean error -1.2.
The non-winners the model under-calls: Murray Dalton (published 3.9, got 38.8, by-election 31.5), Bundamba Bell
(6.6, 15.0, 27.7), Cootamundra Stadtmiller (6.2, 15.7, 23.3), Johnston Klose (4.8, 14.6, 22.1), Wagga Wagga McDonagh
(3.7, 8.7, 9.9), Upper Hunter McNamara (6.9, 9.7, 12.3). Their next vote sits between the published number and the
by-election share, which is what a half blend on the person gives.

By-election WINNERS are not touched: they already get the sitting non-major level
(`AUSPOL_BYELEC_LEVEL`, plans/prereg-byelection-level-2026-10-05.md, which considered and did not use the share).

## The change (one switch, `AUSPOL_BYELECTION_PERSON`, default "0")

Inside `personal_prior_vote()`, so all six harnesses and `fit_seats_full.R` get it. In a seat where the by-election
blend applies (both majors stood, `AUSPOL_BYELECTION_PRIOR` "1" or "blend", weight w = 1 or 0.5), when a non-major
class's lead candidate stood at that by-election and did not win it:

    own vote = w x their by-election share + (1 - w) x their own previous general-election vote (0 if none)

The same half blend the seat row gets, applied to the person.

## Three choices, fixed here before any arm ran

1. **Label change, no switcher discount.** The existing non-sitting switcher rate (0.23) is NOT applied to the
   blended value, whether the person changed label before the by-election (Dalton) or after it (Hopper, independent
   at the by-election, The West Party now). Reason: the by-election vote is recent, in this seat, and for this
   person. Thin evidence for the after case: McNamara (One Nation to independent) kept 0.79, n = 1 clean case.
   Reported beside it for Werribee: the value with the 0.23 rate applied.
2. **Lead candidate only.** Like every other own-vote substitution, the class cell becomes its lead candidate's
   value; a second by-election restander in the same class (Sue Munro behind Paul Hopper in Werribee's OTH) is not
   added. Reported, not fixed.
3. **The by-election class gives the vote up.** When the person stood at the by-election under a different class
   from today's, w x their by-election share comes out of that class's cell (plus (1 - w) x any existing transfer
   from the general-election row), through the existing `remove_transferred_votes()`.

## What this run is and is not

A live walk: `fit_seats_full.R` with the switch off and on (`AUSPOL_OUT_SUFFIX`), Werribee traced, every seat
diffed. It shows what the published Victorian forecast would become. It is NOT ship evidence on its own: a base
change is invisible to `quick_arm` (the harness OOF cache), so the measured test is a rebuild pair like the
de-swing's. Pete decides whether to ship before 28 Nov on the walk, wait for a pair, or leave it until after.

Checks before the walk is believed: switch off is byte-identical in `personal_prior_vote()` output for nsw2019 and
vic2026; switch on moves Murray nsw2019's Shooters value from 4.18 to 0.5 x 31.5 + 0.5 x 18.19 = 24.84; every
matched and near-missed name for vic2026 is printed and read.

## Choice 4 (added while building, before the arm ran)

The rule applies only when today's class is not polled statewide (not ALP, LNP, GRN, ONP). A polled class's
by-election share is already de-swung and blended at class level, and a person's raw by-election share is in
by-election-date terms; mixing the two would double count the swing the de-swing removes.

## Live walk (22 Nov, 8:10am to 8:23am; not ship evidence)

Checks passed: switch unset and "0" give identical `personal_prior_vote()` output for nsw2019, vic2026, qld2020,
vic2018; switch on moves Murray nsw2019's Shooters value 4.18 to 24.83 (6 rows change in nsw2019, 3 in vic2026).
vic2026 matches read by eye: Mulgrave Ian Cook, Werribee Paul Hopper, Werribee Matt Emerson. Not matched and
correct: Sue Munro and Xavier Menta (not their class's lead), the Greens (polled class), Tina Theodossopoulou at
the Mulgrave by-election is a different person from Fotini Theodossopoulou.

Two runs of `fit_seats_full.R` at the published configuration, 20,000 simulations, switch off and on. Files in
`deciding-runs/20261122-byp-walk/`. 5 of 453 seat-party win probabilities move by 0.005 or more:

| Seat | Party | Win probability off | on |
|---|---|---|---|
| Werribee | One Nation | 0.300 | 0.569 |
| Werribee | Labor | 0.422 | 0.226 |
| Werribee | Liberal | 0.274 | 0.199 |
| Mulgrave | Labor | 0.954 | 0.947 |
| Mulgrave | Ian Cook | 0.019 | 0.025 |

Werribee point forecast, primary votes, off then on: Labor 30.9 to 28.1, Liberal 24.0 to 22.0, One Nation 22.6 to
23.2, Greens 11.2 to 10.2, independents 4.0 to 3.2, other (Hopper's class) 4.7 to 10.1, other right 2.7 to 3.1.
Expected seats statewide: One Nation 14.90 to 15.17, Labor 25.44 to 25.24, Liberal-National 40.15 to 40.08.

Why Werribee swings so far: Hopper's class starts from 8.5 instead of 0.0 before the tree step, and when the row
is brought back to 100 the extra comes out of Labor, Liberal and the Greens in proportion. One Nation's share is
allocated separately and gives up nothing. Labor's primary lead over One Nation falls from 8.3 points to 4.9, and
One Nation then wins on preferences in most simulations. Whether a 2025 by-election protest vote for Hopper would
really come from Labor and Liberal rather than from One Nation (which did not stand at that by-election) is the
weak point of the walk, and no historical case tests it.

With choice 1 the other way (the 0.23 switcher rate applied), Hopper's value is 2.4 against today's 1.6: nearly
the published forecast.

## Rebuild pair: criteria (written 22 Nov 9am, before the pair is registered; Pete chose "score it tonight")

Two full rebuilds from stage 1 at one commit, each in its own worktree, switch "1" then "0", never publishing; the
de-swing pair's chain with the switch name changed (`deciding-runs/20261123-byp-rebuilds/chain.ps1`, Scheduled
Task `auspol-byp-rebuilds`, 23 Nov 1am, refuses after 4am). Scored from the main checkout with the same two
commands as that pair: `scripts/score_byelection_deswing.R <base output> <arm output>` (it scores every
primary-vote cell of the by-election seats where both majors stood, from each arm's published-path predictions;
tested 19 Nov: refuses an identical pair, scores a doctored arm exactly), then `scripts/compare_rebuild_scores.R`.

1. **Primary**: squared error on the primary-vote cells of those by-election seats, arm minus base, SE by
   jackknife over elections. PASS if lower by more than 1 SE.
2. **Leave-one-election-out**: still lower with any one election dropped. This is the clause that matters:
   Murray nsw2019 alone is expected to be worth several hundred (4 to about 25 against 40), so the primary can
   pass on that one seat. Without nsw2019 the rule has to earn it on the other restanders.
3. **Guard**: pooled seat log loss not worse by more than 1 SE (clustered on election).
4. **Unacceptable win**: the primary falls but the by-election seats' own seat log loss rises by more than 1 SE.

Reported with the result either way: how many seats the arm moved, a row per restander (by-election share, value
used off and on, result), and the Werribee walk above.

Decision rule: all pass, Pete decides whether it ships before 28 Nov, with the Werribee caveat in front of him
(the walk takes Hopper's vote from Labor and Liberal, none from One Nation; no historical case tests that).
Primary or leave-one-out fails: it stays "0" for the election and the refusal is reported to him. Clause 4
tripped: to Pete as a split.
