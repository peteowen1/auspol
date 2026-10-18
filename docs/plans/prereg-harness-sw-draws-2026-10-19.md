# Pre-registration: state harnesses simulate the statewide spread that ships (audit F4), 2026-10-19

Committed BEFORE the switch is built or run. Pete: "go" (19 Oct). Investigation and file:line evidence:
`plans/f4-harness-statewide-spread-plan-2026-10-19.md`. Decision rule: the standard rule at the top of
`PRE-REGISTRATION-RULES.md`, no departures.

## The defect

The live forecast and the federal harness pass the seat simulator a matrix of statewide draws (per-party sd =
sqrt(trend band^2 + 2.419^2), two-party anchored to the projection). The vic, nsw, qld, sa and wa harnesses build
the same matrix inside `forecast_statewide_or_oracle()` (`R/forecast_statewide.R:403-412`) and keep only its column
means, then simulate with a flat `PARTY_SD` 1.5 and Labor and the Coalition independent. So their backtest scores
describe a narrower statewide spread than ships.

## The arm (`AUSPOL_HARNESS_SW_DRAWS=1`, default "0")

`forecast_statewide_or_oracle()` keeps the draws as an attribute; each state harness reads it straight after the call
and passes `statewide_draws` (first `N_SIMS` rows; the rows are independent). Questions decided here, so they are not
decided after seeing results:
- Target recipe: the harness path's own `statewide_draws_as_at()` draws, the recipe the federal harness already scores
  (not a port of `fit_seats_full.R`'s inline build).
- A pair with no draws (thin cycle, oracle level, a party missing from the matrix) prints `SW0!` and keeps the flat
  spread. It is unchanged by construction, so it is listed and drops out of the primary.
- nt joins only if its harness already calls `forecast_statewide_or_oracle()`; otherwise it is listed as out of scope.
- `SHRINK`, `seat_sd` and the slopes are NOT refitted. This answers only "does using what ships score better or
  worse"; a refit would be its own prereg.
- Federal pairs are controls and must score exactly 0, or the run is void.

## Measurement

1. Proof the switch acts: OFF byte-identical on one pair; ON prints the applied per-party and two-party draw sd; a
   deliberately broken matrix (a column removed) prints `SW0!`.
2. Screen: `Rscript scripts/quick_arm.R "AUSPOL_HARNESS_SW_DRAWS=1" --pairs=all`. Its SE on the targeted pairs is the
   MDE estimate; it is reported before the deciding run, and if the MDE exceeds any plausible gain that is said, not
   left to a 1-SE bar that can only refuse. WORSE stops; within 1 SE is not clearance.
3. Deciding run, detached, 20,000 sims: `deciding_run.ps1 -Arm "AUSPOL_HARNESS_SW_DRAWS=1" -Label f4-sw-draws`.

## Decision (standard rule)

1. Primary: seat-winner log loss over the targeted pairs' seats better by more than 1 SE (SE clustered on election).
2. Guard: all seats of all elections not worse by more than 1 SE.
3. Leave-one-election-out: the primary holds with each election dropped.
4. No election worse by more than 2 SE of its own seats.
Reported, not voted: Brier, reliability by band, accuracy, seats moving each way, each election's share of the gain.

## Named in advance: what would make a win unacceptable

(a) The gain lives only in seats at the 1e-6 floor: report floor counts in base and arm, and the result at a 1e-4
floor; if the gain vanishes there it is a floor artefact. (b) A targeted pair that fell back (`SW0!`) counts for
neither side. (c) Winner accuracy falls in more than half the elections: not a refusal, but it goes to Pete with the
split. Known blind spots: `FP_EXTRA_SD` 2.419 is estimated over the scored elections themselves (mild leak, shared
with the live forecast); the constants were tuned under the narrow spread, so WORSE may mean "retune", which is the
separate step above.
