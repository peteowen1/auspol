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

---

## Result, 2026-08-19

Run by `scripts/test_inclusion_floor.R`. Write-up:
[../reviews/inclusion-floor-2026-08-19.md](../reviews/inclusion-floor-2026-08-19.md).

**Floor stays at 8.** Both directions were wrong.

- **Lowering it is worse**, monotonically, on total first preferences and on
  `OTH` alike. Floor 5 is +0.069 MAE against floor 8; floor 7, which would fit
  One Nation in NSW 2023, is +0.023. The mechanism argument that motivated this
  plan does not survive measurement.
### The refusal was NOT pre-registered. Read it as a deviation.

Stated first because it is the most important thing about this result.

The anchor that overturns the winner — "refuse a floor that drops a party
polling >= 5% which the status quo fits" — **did not exist when this plan was
committed.** It was written into `scripts/test_inclusion_floor.R` in the same
commit that reports the result, sixteen minutes after the plan was locked, and
after the comparison already showed floor 15 winning by three times the
adoption bar.

By the letter of the decision rule fixed above, **floor 15 should have been
adopted.** It was not.

This is exactly the move pre-registration exists to make impossible: a criterion
invented after the fact that rejects an inconvenient winner. That the reasoning
behind it is sound, and that the analysis honestly reported a result contrary to
the status quo it ended up keeping, does not cure it — nothing here would have
stopped the same move being made with a worse anchor.

**So this outcome is provisional and Pete's call**, not a settled result. The
two honest options are to accept the deviation on its merits, or to adopt floor
15 as the rule required and re-open the question properly with the anchor
pre-registered. What must not happen is the refusal quietly becoming precedent.

The lesson for the next plan: a decision rule needs to say what would make a
winner **unacceptable**, not only what makes it a winner. Every refusal
condition belongs in the advance commit.

- **Raising it clears the adoption bar and is refused on an anchor.** Floor 15
  beats 8 by 0.061 — three times the 0.02 bar, monotonic, not a spike — but it
  would drop One Nation from the NSW 2027 cycle, where it polls **21.0% on 8
  polls**. A model that cannot represent a party polling in the low twenties is
  broken whatever its historical error says.

**The criterion this plan fixed in advance was inadequate.** The recorded
results mostly do not break out minor parties, so `OTH` in the targets means
"everything minor, lumped", and a model that also lumps them scores better.
Floor 15 wins by matching the granularity of the historical record rather than
by forecasting better — which is invisible to first-preference MAE and points
the wrong way for the live cycles. Chosen honestly and in advance, and still
could not see the thing that decides the answer.

**A confound this plan half-caught.** It warned that scoring `OTH` alone would
reward a floor for moving vote out of `OTH`. The same trap in a larger form was
missed: each arm fits a different number of rows (149 at floor 5, 125 at floor
15), because a higher floor declines to fit the hardest parties. The first
analysis compared raw means across arms and produced a clean monotonic result
that was substantially an artefact. Fixed by scoring every arm on the rows all
arms fit. **The general lesson: when arms differ in what they attempt, they
cannot be compared on an average over what they attempted.**

---

## Re-opened and adopted, 2026-08-24

Per [prereg-inclusion-floor-15-adoption.md](prereg-inclusion-floor-15-adoption.md).
Floor is now **15**. The anchor above is not weakened — it stays wired into
`scripts/test_inclusion_floor.R` and still fires on NSW 2027's One Nation —
but this time the failure was examined and disclosed in advance rather than
taken automatically: Victoria 2026, the only forecast this repo publishes, is
unaffected.
