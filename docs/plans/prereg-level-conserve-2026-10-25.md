# Pre-registration (DRAFT, nothing built or run): make the seat layer conserve the statewide level

Written 2026-10-25, before any code exists. Source: `docs/reviews/wa-nt-seat-layer-trace-2026-10-25.md`
(the trace that found the seat layer adds about one point to EACH major party's implied statewide share
above the level it was handed). Rules: `docs/PRE-REGISTRATION-RULES.md`, the shrinkage, leakage and
"a fix to one harness is a fix to all of them" rules in `CLAUDE.md`.

Status: DRAFT for Pete. Not to be built until he says go. No switch exists yet.

## The question

Every harness projects each class with `dev_slope()` around the statewide level, then renormalises each
seat's row to 100 (`backtest_candidate_*.R`, e.g. `_wa.R:614`, `_nt.R:647`), after zeroing independents
where none nominated (`_wa.R:603`) and, later, every class with no candidate (`zero_unnominated_at("late")`,
`_wa.R:677`). Share the level gave a class that cannot stand in a seat goes to whoever is left in that seat,
in proportion to their share there. The level of a class with no candidate anywhere is dropped from the
level vector before the seats see it (`R/forecast_statewide.R:382` thin cycle, `:403` published path), so
the row renormalisation hands it out the same way.

Measured (28 state elections, vote-weighted implied statewide share minus the level used): ALP +1.07 (SE
0.38), Coalition +1.09 (SE 0.36), 20 of 28 positive each. NT +5.7 / +4.4; WA +0.45 / +0.68.

Does forcing the seats' implied statewide share to equal the level (after nominations) predict seats better?

## The change (fixed now)

New switch `AUSPOL_LEVEL_CONSERVE` (default "0" = byte-identical), read by all six state harnesses, the
federal harness (national level) and `fit_seats_full.R`, added to `scripts/published_flags.R` in the same
commit, one shared function in `R/` (no per-harness copies).

- **Targets.** The level vector `sb` restricted to classes with at least one candidate, rescaled to sum to
  100 over them (a class with no candidate anywhere gives its level up pro rata to the others' LEVELS).
- **Weights.** Each seat's formal vote at the PREVIOUS election (knowable before polling day); a seat with
  no previous figure gets the median weight.
- **Rake.** Iterative proportional fitting on the seat x class matrix after nomination zeroing: columns to
  the targets (vote-weighted), rows to 100, cells at 0 stay 0, 50 iterations or max column gap < 0.01.
- **Strength.** Final shares `= (1 - lambda) * current + lambda * raked`. Primary spec `lambda = 1`.
  Sensitivity `lambda = 0.5`, and `lambda` fitted time-forward as the least-squares coefficient of
  (actual implied minus current implied) on (raked implied minus current implied) over earlier elections,
  shrunk toward 0.5 with `w = tau^2 / (tau^2 + se^2)`. Sensitivities are never decisive.

Arms (each must be measured; CLAUDE.md "test base_pred AND the xgb layer"):

| arm | where | reaches |
|---|---|---|
| `base` | on `base_pred`, just before `xgb_primary_override()`, with the target's nomination zeroing applied first so the targets are the standing classes | the xgb layer through `AUSPOL_XGB_BASE_DELTA` re-prediction |
| `final` | after `zero_unnominated_at("late")`, the last step before simulation | the published shares directly |
| `both` | both positions | |

## Dry runs (before any decision run, results written here first)

1. `AUSPOL_LEVEL_CONSERVE=0` scores exactly 0 on every pair.
2. Leaked check: with the oracle level (`AUSPOL_FORECAST_MODE=0`), `final` must make the implied statewide
   share exact (max gap < 0.05 points) and must IMPROVE pooled seat primary MSE. The 2026-10-25 screen found
   the exact level made WA and NT seats worse because the seat layer added its own point on top; if
   conservation does not reverse that, the mechanism is not what this prereg says and it stops here.
3. Print per pair: dropped level mass, implied minus level before and after, for ALP and Coalition.

## Decision (all on `quick_arm.R --pairs=all`, 20,000-sim deciding run before shipping)

SE clustered on election throughout.

- **Primary**: pooled seat log loss change (arm minus shipped) below 0 by more than 1 SE.
- **Secondary** (reported, must not be worse by more than 1 SE): ALP and Coalition seat primary MSE, pooled.
- **Targeted** (the cells the fix is for): ALP and Coalition signed seat error, mean by jurisdiction; NT and
  WA Coalition must move toward 0.
- **Guards**: leave-one-election-out worst case still below 0 (no one-election share refusal, per memory
  rule); no jurisdiction's log loss worse by more than 2 of its own SEs; AEF-7 ledger subset reported.

**Unacceptable even if the primary passes**: any election's implied ALP or Coalition error made worse by
more than 3 points; a raked cell above 0 where the class has no candidate; any change to a pair whose
targets were already met within 0.05 (should be byte-identical).

Choice between arms: the one with the lower pooled log loss, provided it passes; if `base` and `final` are
within 1 SE, prefer `base` (one mechanism, xgb sees it).

## What would make a win suspicious

- Gain concentrated in nt2024 (its dropped 14.8-point Territory Alliance level is a level-model problem, the
  thin cycle carrying a party that did not stand): report the arm with NT excluded; it must still pass.
- WA 2017 / 2021, where the level under-called Labor by 4.0 and 6.9 points: conservation will make Labor
  worse there. That is expected, not a reason to refuse, provided the guards hold.
