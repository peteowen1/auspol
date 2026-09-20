# Pre-registration: a silent salience screen must not mean "permitted"

Written 2026-09-20 02:10, before the fix is applied. Found tracing Waite
sa2026 (our independent 33.5, actual 2.9) from the worst-by-delta-primary
list under the first honest ledger.

## The defect

`salience_screen()` returns all-`TRUE` when fewer than 10% of an
election's candidates register any campaign salience (`min_fire`), on the
stated grounds that this "reproduces the unscreened model exactly". That
was true when a permit only lifted a refusal. Since the 6 and 18 Sep
revisions of `screened_slopes()`, a permit does two more things:

- a NEW class leader with `permit == TRUE` takes slope **1.0** (full
  carry-forward of the class's prior base, the Goldstein path) instead of
  the fitted "new" constant (IND 0.33);
- `departed <- honour_departed & !plr & !permit`: the departed-leader decay
  (IND 0.38) is switched OFF whenever `permit` is TRUE.

So in every election below the coverage floor, every new independent
keeps the previous independent's whole vote and no departed leader ever
decays. The six call sites also set `pm[is.na(pm)] <- TRUE`, so a
seat-class with no row in the permit table is "permitted" too. Silence
read as permission, twice: the trap `CLAUDE.md` records as "absence of
evidence read as certainty".

Elections below the floor (stage-1 logs, v40): **fed2007 5%, fed2010 6%,
sa2026 8%, vic2014 9%**: 4 of the 23 scored pairs, sa2026 among the seven
in the ledger. WA has no screen wiring and is untouched. Everything at 11%
or above is unaffected by construction.

Waite sa2026: Duluk (19.7) and Holmes-Ross (14.6) both left; Gargett polled
2.9. `candidate_returns` correctly says the leader did not return; the
screen said "permit" because 8% < 10%; base_pred kept 38.4 for the IND
class and the xgb layer gave 33.5. The same all-permit is behind Kavel's
46 (the departed rule is not the story there, the One Nation surge is,
but the 1.0 slope compounds it).

## The fix

1. `salience_screen()` returns `NA` (unknown), not `TRUE`, below `min_fire`.
2. `screened_slopes()` treats a non-`TRUE` permit as "the screen is
   silent": the 1.0 path needs `permit %in% TRUE`; the departed decay fires
   on `!plr & !(permit %in% TRUE)`. With the screen silent this is exactly
   the conditional-slopes model plus the departed-leader rule, which is what
   the docstring always claimed.
3. The six `pm[is.na(pm)] <- TRUE` lines (five harnesses, `fit_seats_full.R`)
   leave `NA`.
4. The `SP1` line counts `permit %in% TRUE` and says "screen silent" when
   coverage is below the floor.

Nothing is fitted or tuned.

## Prediction

sa2026's independent cells fall sharply (Waite IND 33.5 -> under 15,
Kavel down), fed2007/fed2010/vic2014 change through their new-candidate
cells only. Pooled seat log loss over 2,054 seats improves; the AEF-7
ledger improves through sa2026 alone (expected -0.003 to -0.008 on the
660-seat log loss, with sa2026's own log loss from 0.323 toward 0.29).

## Criterion

Primary: sa2026 seat log loss falls by more than one clustered SE
(jackknife over its 47 seats) AND pooled log loss over all 23 pairs does
not rise. Do-no-harm: the 19 pairs at or above 11% coverage must be
**byte-identical** in base_pred (stage-1 sharedetail) to v40's; any
difference there is a bug in the fix, not a result. Unacceptable win: a
gain on sa2026 that comes with Kavel's or Waite's independent RISING.

## Order of operations

v40 (the projection-mix rebuild) is running as this is written; editing
`R/` mid-rebuild would put two vintages inside one run, so the fix is
applied only after v40 completes, then v41 is rebuilt and scored against
v40 on the criterion above.

# RESULT, 2026-09-20 11:20 (rebuild v41 vs v40; lower is better)

Smoke first (`smoke_pair.sh sa 2026`, 4 minutes, base_pred only): sa2026
all-cell RMSE 4.93 -> 4.20, IND 7.49 -> 4.98, Waite IND 38.4 -> 23.4, Kavel
46.0 -> 30.9, Mount Gambier IND 42.7 -> 26.3 (actual 37.6: over-corrected).

Deciding rebuild:

| | v40 | v41 | AEF |
|---|--:|--:|--:|
| AEF-7 seat log loss (660) | 0.2992 | **0.2921** | 0.2851 |
| weighted primary RMSE | 5.19 | 5.18 | 5.42 |
| TCP MAE | 3.96 | 3.98 | 3.63 |
| pooled log loss, 22 pairs | 0.3356 | 0.3359 | |
| **sa2026 seat log loss** | 0.2942 | **0.3044** (jackknife SE 0.071) | |

**Primary criterion NOT MET**: sa2026's log loss rose 0.010, inside one SE
but the wrong way, while its first preferences got much better (the smoke
above; Waite IND 18.4 after the xgb layer, Kavel 26.9). The seat winners
in sa2026 turn on One Nation's spread, which this fix does not touch, and
the xgb layer partly undoes the base_pred move.

**Do-no-harm premise was WRONG, disclosed**: the plan said 19 pairs would be
byte-identical in stage 1. They are not: fed2013 moved up to 18.7 points in
a cell, qld2024 15.1, fed2025 11.0, nsw2023 7.2. The third part of the fix
(`pm[is.na(pm)] <- TRUE` removed at six call sites) changes every
seat-class that has no permit row at all, in every election, and those are
common. That is the same defect in another guise (a missing row was a
permit, so a new leader there carried the whole prior base), but the plan
did not size it, so the identity check cannot be claimed. The tiny WA moves
(0.08-0.11) show base_pred also has a slight simulation dependence at
2,000 versus 20,000 sims, worth its own note.

Per pair (log loss, v40 -> v41): qld2024 0.3855 -> 0.3286, nsw2019 0.4006
-> 0.3440, fed2016 -0.012, wa2025 -0.014, wa2017 -0.019; fed2019 +0.029,
sa2022 +0.031, wa2013 +0.090, fed2013 +0.012, fed2010 +0.009.

**Verdict: REFUSED on the pre-registered criterion; kept on dev, NOT merged,
Pete's call**, for the same reason as the projection-mix change: the
semantics it replaces ("no evidence of a campaign is evidence of one") are
indefensible, and the ledger, the primary RMSE and the smoke all move the
right way, but the target election's seat log loss did not and the plan
mis-stated the blast radius. The v41 models are on `shipped-models`
(stage 9 publishes automatically) and are the better ledger; say the word
and v40's are restored by rerunning the rebuild from main.
