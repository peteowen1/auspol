# Pre-registration: should the federal and NSW backtests score salience-expected ON or OFF?

Written 2026-10-03 (evening), BEFORE any ON arm has been run on the current model. Pete chose
"measure ON vs OFF first, then follow the result" (quiz, 2026-10-03).

## Why this is being asked

`docs/reviews/salience-arm-federal-nsw-scoped-2026-09-09.md` scoped arm C (`AUSPOL_SALIENCE_EXPECTED=1`
and `AUSPOL_SALIENCE_EXP_SD=1`) to federal and NSW as a harness-local default
(`backtest_candidate_fed.R:78-79`, `backtest_candidate_nsw.R:41-42`, set only when unset). That review
says the scoping was a post-hoc scope decision made after seeing the jurisdiction table, and that it
"should be re-examined with a real pre-registration of its own". Separately, a rebuild exports every
published flag first (`published_flags.R:62,64`: both "0"), so the two lines never fired in the rebuild
or the AEF-7 ledger: the scoreboard has scored fed and nsw at OFF, while hand runs scored them at ON.
Found 2026-10-03 (`docs/reviews/fed-nsw-snapshot-gap-2026-10-03.md`; confirmed: with both switches at 0
all 7 fed pairs and nsw2019 reproduce the v61 snapshot exactly, 0 differing cells).
When the rebuild began exporting flags first is NOT known, so how many past scoreboard numbers it
affects is unconfirmed.

## The two arms (defined now)

- OFF = both switches 0 = what the rebuild and ledger score = the v61 snapshot
  `output/snapshots/20261003-0143-48f0233-from6` (proven reproducible, see above). nsw2023 is not yet
  proven reproducible: step 1 below checks it.
- ON = both switches 1 = a bare hand run of the harness on `dev` as it stands (the harness-local lines
  active). Same code, same inputs, same seed, same sims as OFF; only the two switches differ.
Everything else (vic, sa, qld, wa, `fit_seats_full.R`) is untouched by this question.

## Metrics (fixed before the run)

Seat log loss per seat-election = -log(max(p_actual, 1e-6)), where `prob` in `backtest-<h>-*.csv` is the
probability given to the actual winner. Mean per pair, then per jurisdiction over its pairs
(fed: 7 pairs fed2007..fed2025; nsw: 2 pairs). Delta = ON - OFF (negative = ON better).

- PRIMARY, scoped to the change: per jurisdiction, the mean over pairs of the per-pair delta, with n
  (pairs) stated. NSW has n = 2 pairs, so no SE is meaningful: it is reported as direction only.
  Fed has n = 7 pairs: report the mean, the sd of the 7 deltas and the SE (sd / sqrt 7).
- NAMED CASES (the stated purpose of arm C): the six fed2022 teal seats (Goldstein, Curtin, North
  Sydney, Kooyong, Mackellar, Fowler): the probability given to the actual winner under ON vs OFF,
  and the count of seats where it is lower under ON. The 2026-09-09 review reported all six rising
  (Kooyong 0.053 -> 0.361).
- GUARDS: (a) no jurisdiction's mean delta worse than +0.01 (the 2026-09-07 prereg's own bound, carried
  over); (b) no single pair worse than +0.011 (carried from the v61 prereg); (c) floor events: the
  number of seat-elections whose actual winner sits at the 1e-6 floor under ON but not under OFF must
  be 0; (d) per-class signed primary-share error (pred - actual) on the seats arm C changed: refuse if
  any class's absolute bias grows by more than 2 SE from OFF to ON (the One Nation direction rule).
- Counts: report the number of seat-elections, the number of cells whose predicted share differs
  between arms, and the number of seats whose predicted winner differs.

## Decision rule (fixed now)

Per jurisdiction independently: set the scoreboard to ON for that jurisdiction only if ALL hold:
primary mean delta <= 0; guards (a) to (d) pass; for fed, at least 5 of the 6 teal seats do not fall
under ON. Otherwise the scoreboard stays at OFF and the harness-local ON default is removed (DECISIONS
entry saying arm C is dropped for that jurisdiction and why). A result where fed's mean delta is
negative but its SE (7 pairs) is larger than |mean| is reported as "direction only" and ships on the
rule above, not as "improved". Clause refusals of a headline-positive result go to Pete with the split
table (`clause-refusals-go-to-pete`).

## What this CANNOT see, said now

- **Victoria.** The fed and nsw backtest outputs feed the stage-1 pool the xgb models are trained on
  (`pooled-sharedetail.csv`, the 4-step retrain). Moving the scoreboard to ON changes that pool, so it
  could move the Victorian forecast through the xgb layer even though Victoria's own switch stays 0.
  This measurement does NOT test that. Even if ON wins here, flipping it in the rebuild needs its own
  measurement of the Victorian 3-pair log loss and the live forecast after the retrain; nothing is
  flipped on this result alone.
- n is tiny (7 pairs, 2 pairs): the primary is nearly unfalsifiable at the 0.01 scale; the guards and
  named cases carry the decision.
- The September measurement was on an older model; this is the point of re-running.

## Run plan (commands; foreground, one launch each; nothing else running)

All from `C:\dev\auspol` on `dev`. Output files are moved out of `output/` afterwards (hand runs
contaminate the ledger inputs). No `AUSPOL_PUBLISH`.
1. nsw2023 OFF check: `AUSPOL_SALIENCE_EXPECTED=0 AUSPOL_SALIENCE_EXP_SD=0 AUSPOL_NSW_PAIR=2023
   Rscript scripts/backtest_candidate_nsw.R`; it must equal the snapshot nsw2023 (0 differing) or the
   OFF arm for nsw2023 is the fresh run and the gap is reported.
2. ON arms, bare (no env): fed (all 7 pairs, about 285 s), nsw `AUSPOL_NSW_PAIR=2019` and `=2023`
   (about 35 s each).
3. Compare with a script written and committed before reading the results.

## Result
(not run)
