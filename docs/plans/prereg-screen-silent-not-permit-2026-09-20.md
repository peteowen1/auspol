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
