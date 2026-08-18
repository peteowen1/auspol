# Pre-registration: the floor that decides which parties exist

Written 2026-08-19, **before** anything is fitted or measured. Committed before
running.

## What this is about

`fit_vic.R`, `fit_nsw.R` and `fit_federal.R` each fit only the parties with at
least `n` polls in the cycle — 8 in the states, 25 federally. The number has
never been justified anywhere, and `docs/CONSTANTS.md` filed it under
"minimum data before fitting", alongside row-count guards that catch a
truncated download.

**That filing is wrong, and the mis-filing is why nobody looked.** A row-count
guard asks "is this input intact". This decides **which parties exist in the
forecast**. A party under the floor is not fitted at all: its support stays
inside `OTH`, and `unfold_others()` cannot run on it, because unfolding needs a
fitted trend to impute from.

## What made it visible

The new `L3` poll-tracking check reports a party that is polled but not fitted.
Its first run flagged one: **One Nation has 7 polls in the NSW 2023 cycle
against a floor of 8** and is excluded by a single poll.

What that does, measured 2026-08-19:

- Morgan reports One Nation separately in all 7 of those polls; every other firm
  folds it into `OTH`. So the `OTH` column means "everything else **including**
  One Nation" for 25 polls and "**excluding** it" for 7.
- The model cannot see that. Its fitted house effect for Morgan on `OTH` is
  **−0.28 points**, which is a house effect, not the ~5-point definitional gap
  actually present.
- Fitted `OTH` endpoint **15.30** against an actual of **17.96**.

The vote is not lost — NSW 2023's recorded result has no separate One Nation
line either, so `OTH` is the right target. What is wrong is that `OTH` is fitted
across two different definitions of itself.

## The question

Does lowering the floor improve first-preference accuracy, or does fitting a
party on very few polls make things worse?

Both are plausible and that is the point. A party with 7 polls has a badly
determined trend, and a bad ONP trend feeds `unfold_others()`, which would then
impute a bad ONP out of every folded `OTH` row — potentially making `OTH` worse
than leaving the mixture alone.

## The grid, fixed now

Floors: **5, 6, 7, 8, 10, 12, 15**. Applied to the state scripts only; federal's
25 is left alone in this experiment because federal polling is an order of
magnitude denser and the floor there is not close to binding.

## Criterion, fixed now

**Mean absolute error of fitted endpoint first preferences against the eventual
result**, over every completed cycle with complete actuals (the same
100 ± 5 filter used throughout, and the same 33-cycle set
`scripts/calibrate_poll_tracking.R` uses), across all fitted parties.

Reported alongside, not decided on:

- the same MAE restricted to `OTH`, since that is the party the mechanism acts
  through;
- how many (cycle, party) fits each floor adds or removes;
- how many additional `unfold_others()` corrections each floor enables.

## Decision rule, fixed now

- **Adopt the best floor only if it beats 8 by more than 0.02 MAE**, the same
  bar every other constant in this repo has been held to (`szc` was adopted at
  1.3%, per-cycle volatility rejected at 0.2%).
- **Ties inside 0.02 go to the higher floor**, i.e. to fitting fewer parties on
  thin data. The status quo wins a tie.
- **If the curve is not monotonic and the winner is an isolated spike**, do not
  adopt: with 33 cycles that is noise, and picking the argmin of a noisy curve
  is how a constant gets fitted to its own test set.
- **If a lower floor wins on overall MAE but loses on `OTH` MAE**, report both
  and adopt nothing. The mechanism argument says it should win *through* `OTH`;
  winning while `OTH` gets worse means something else is moving.

## Threats, stated before the run

- **33 cycles is not many**, and the floors differ from one another on only a
  handful of (cycle, party) fits. Small differences will not be meaningful.
- **Changing the floor changes which parties are in `OTH`**, so the target for
  `OTH` shifts between arms. The comparison must therefore be on TOTAL
  first-preference MAE across parties, not on `OTH` alone — otherwise a floor
  that moves vote out of `OTH` looks better simply for having less left to get
  wrong. This is the trap most likely to produce a wrong answer here.
- **The eventual results do not break out most minor parties.** A cycle whose
  actuals list only ALP/LNP/GRN/OTH cannot score a fitted One Nation at all, so
  a lower floor may add fits that the criterion is blind to. Count them.
- The federal `25` is untested by this and stays untested. Say so rather than
  implying the whole family was checked.
