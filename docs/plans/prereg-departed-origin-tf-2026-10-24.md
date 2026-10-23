# Pre-registration: a departed defector's vote goes home, time-forward (2026-10-24)

Pete, 2026-10-24: *"Retiring members' vote going home (Morwell, and the same mechanism elsewhere). When a
member who left a party retires, send the released vote back to their former party first, instead of spreading it
across every party in proportion. Test it in both base_pred and the xgb layer."*

The mechanism already exists: `AUSPOL_DEPARTED_ORIGIN` (`route_departed_origin()`, `R/candidate_returns.R`), off
since `prereg-departed-origin-return-2026-09-18.md` fell 0.06 SE short on 15 cases. The investigation of
2026-10-24 (`docs/reviews/departed-vote-home-investigation-2026-10-24.md`) found two defects in its fit, both fixed
in the commit that adds this file, before any run:

1. **Leakage.** `fit_departed_origin_return()` was leave-target-out: it learned the go-home share from LATER
   elections. Now `fit_pairs_for()`, like every other fitted constant since 2026-09-28.
2. **A cliff.** Below 5 cases it fitted nothing; at 5 it believed the median outright. Now shrunk toward 0 by
   n / (n + 3) (`AUSPOL_DEPARTED_ORIGIN_SHRINK_K`, the same prior strength as `AUSPOL_CONSERVE_SHRINK_K`).

The corpus now gives about 40 cases across all elections (the 2026-09-18 run had 15), so it is worth
re-deciding. Both fixes reach the model only when the switch is on, so the shipped forecast is unchanged by them.

## Arms (part 1: base_pred)

Every axis but the one under test is the shipped configuration (`scripts/published_flags.R`).

| arm | setting | differs from baseline on |
|---|---|---|
| baseline | `AUSPOL_DEPARTED_ORIGIN=0` (shipped) | - |
| A | `AUSPOL_DEPARTED_ORIGIN=1` (median go-home share, shrunk, time-forward) | that switch only |
| B | `AUSPOL_DEPARTED_ORIGIN=mean` | that switch only |

Limiting case, stated before running: an election with no case before it (the earliest of each run of pairs) gets
no fitted share and must score byte-identical to baseline; quick_arm reports those as 0. An election with cases but
no departed defector of its own must also score identically.

Screen: `scripts/quick_arm.R "AUSPOL_DEPARTED_ORIGIN=1" --pairs=all` and the same for `mean`, common random
numbers against a shared baseline. The deciding run is `scripts/deciding_run.ps1` at 20,000 sims, all 22+ pairs.

## Criterion (the standard decision rule, unchanged)

1. **Primary:** squared primary-share error on the changed cells (the origin party and the departed class in each
   case seat), arm better than baseline by more than 1 SE, clustered on election.
2. **Guard:** seat log loss over every seat of every scored election, not worse by more than 1 SE.
3. Leave-one-election-out: the primary stays better by more than 1 SE with each election dropped.
4. No single election worse on seat log loss by more than 2 SE of its own paired seat differences.
5. Gain keeps its sign with the two largest-gain seats removed (Morwell 2022 is expected to be one).
6. Report how many case seats move toward the actual result.

**What would make an apparent win unacceptable:** a primary gain that comes with the origin party over-called in
seats it already led (the 2026-09-18 harm cases Hughes, Lyons, Frankston, Hillarys, Nedlands, Vasse 2008),
shown as more case seats moving away from the result than toward it (clause 6). If A and B both pass, A ships
(the median is less sensitive to the cases clipped at 0 or 1).

## Part 2: the xgb layer

The live forecast's xgb model (`xgb_primary_predict_live()`) takes `base_pred` as its `base_margin`, so a base_pred
change reaches the published number on the next run without retraining. Part 1 therefore tests the effect through
the trees as they are. A separate xgb FEATURE (`origin_released_i`: points of a departed defector's vote
attributable to the origin party) needs the as-at tree models retrained (rebuild stage 4), which quick_arm cannot
screen. It is run only if part 1 passes or comes within 1 SE, as an isolated stage-4 rebuild with its own
addendum to this file.
