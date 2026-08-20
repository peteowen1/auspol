# Pre-registration: can the seat model stop claiming certainty where an independent might emerge?

Written 2026-08-20, **before anything is fitted or measured**. Committed before running.

## The defect being addressed

The first backtest of the published candidate model
([candidate-backtest-nsw2023](../reviews/candidate-backtest-nsw2023-2026-08-20.md))
found it calibrated on major-party contests (slope 0.962) and badly
overconfident overall (slope 0.541). The entire difference is **new
independents**: five NSW seats where the model gave the eventual winner
0.000–0.002 while being 0.64–1.00 confident in somebody else.

It is structural. Each party's projected seat share is its own share at the
previous election plus the statewide swing, so a candidate with no previous vote
cannot acquire one.

## What is borrowed, and what is emphatically not

**Borrowed: the idea.** That an independent can appear where none stood, that
the chance of it is predictable from seat characteristics, and that the vote when
it happens is heavy-tailed. That much is observable in our own data and is not
anyone's property.

**Not borrowed: anything numeric.** No coefficient, rate, threshold, kurtosis or
seat-type modifier from `statistics_emerging_IND.csv` or any other model enters
this work — not as a starting value, not as a prior, not as a default. Every
number is fitted on our own data with our own features.

The anchor's figures may be quoted **once, in the write-up, after ours are
final**, purely as an independent read on magnitude. If ours disagree with
theirs, ours stand.

## Features, chosen now, and why these

Region and seat-type taxonomies are **rejected as features**. NSW has 12 region
labels and Victoria 14, they are not the same taxonomy, and a coefficient fitted
on one cannot be applied to the other — which is the whole point, since Victoria
2026 is where this has to work. Importing someone else's rural/provincial
classification would solve that by adopting their judgement, which is exactly
what is being avoided.

Four features, all state-agnostic and already in our data for both states:

1. **The seat's previous non-major vote** — IND + OTH + OTH_RIGHT at the last
   election. The natural measure of how willing this electorate already is to
   vote outside the majors, and it needs no taxonomy.
2. **Whether an independent already polled meaningfully there** — a different
   thing from (1), separating "a minor-party seat" from "an independent seat".
3. **The seat's margin** — safe seats plausibly attract a different kind of
   challenge than marginal ones.
4. **The incumbent's party** — independents have disproportionately challenged
   Coalition-held seats, and this tests whether that holds in our data.

If a feature turns out not to help, it is reported as not helping. **No feature
is dropped for failing significance after the fact** — the same rule the
seat-swing work followed when it kept `soph_party` at t = 1.2.

## The structure

**No emergence threshold.** Defining a binary "emerged" event needs a cutoff, and
any cutoff is a hand-set parameter — either borrowed or tuned, and both are
refused. Instead the independent vote share is modelled **directly as a
continuous outcome** whose conditional distribution depends on the features
above:

- a model for the **location** of the next-election independent share, and
- a model for its **spread**, allowed to grow with the same features, with a
  heavy-tailed shape so that a large independent vote is rare rather than
  impossible.

The tail weight is **estimated**, not assumed. If the data says a normal tail is
adequate, that is the finding.

## Fitting and scoring, and the honest limit

Fitted **leave-one-seat-out** on NSW 2019 → 2023: each seat's distribution comes
from a model fitted on the other 90.

**This does not validate across elections, and a win here is NOT evidence the
rate transfers to Victoria 2026.** Every seat shares one environment, and NSW
2023 was an unusually strong independent election. That limit is written here in
advance so it cannot quietly vanish from the write-up.

## What is measured

On the 88 scored NSW seats, arm A (as published) against arm B (with emergence):

- **Brier** on the party that actually won
- **log score**, which punishes confident misses hardest — the specific failure
- **calibration slope** on the log-odds
- **winner accuracy**, reported but not decisive

## Decision rule, fixed now

In **standard errors of the paired per-seat difference**. Four of my criteria
have now failed by being written in fixed units, most recently yesterday, so
this one is in SE and its size in SE was checked before it was written.

- **Adopt B** if the Brier improvement exceeds **2 SE** of the paired per-seat
  difference, **and** the calibration slope moves toward 1, **and** it clears E1.
- **Keep A** if the improvement is within 2 SE.
- A slope overshooting past 1 into underconfidence is reported, not adopted for.

## Refusal section — what would disqualify an apparent win

- **E1 — the shrinkage control, and this is the one that matters.** Any change
  making probabilities less extreme will improve Brier and slope on a model that
  is overconfident. So arm B is scored against a third arm **S**, which simply
  shrinks every probability toward uniform by one temperature, fitted the same
  leave-one-seat-out way. **If S matches B, the emergence model's structure is
  doing nothing and must be refused** in favour of the simpler fix. B must beat a
  dumb temperature to earn its place.
- **E2 — the one-way ratchet.** This adds probability mass to a party behind
  almost everywhere, the asymmetry that got the One Nation seat-sd change refused
  (win probability up in 71 of 87 seats, down in 1). Report the effect on the
  LIVE Victorian forecast: if independents' expected seats rise by more than
  **2.0**, stop and report rather than ship. Zero is certainly wrong; eight would
  be replacing one error with another.
- **E3 — no tuning against the scoring metric.** Features and structure are
  fixed above. Parameters are fitted by likelihood on the vote shares, not
  selected by whichever setting improves Brier — that would be fitting the model
  to its own test.
- **E4 — no per-seat overrides.** No seat gets special handling, however obvious
  its independent looks in hindsight. The model this repo is anchored on
  hard-codes an override for Kiama; this must not. A hand-maintained list of
  confirmed independents is a **separate, later** piece of work, done closer to
  nominations, and must not be smuggled in here.
- **E5 — accuracy must not collapse.** Spreading uncertainty could improve Brier
  while calling fewer seats correctly. If winner accuracy drops by more than 2
  seats, report and refuse: an honest model that is worse at the actual question
  is not an improvement.

## What the criteria cannot see

- **Whether the emergence rate transfers.** One election, one state, and an
  unusually independent-friendly one.
- **Which seats.** By construction this spreads probability by seat
  characteristics; it will be wrong about individual seats and is not intended to
  be right about them.
- **Victoria's actual 2026 field.** Nominations are not closed. Any seat where a
  serious independent is standing who did not stand in 2022 is outside anything
  this can know.
