# Prereg: state statewide flows from the AEC's same-state federal figure (AUSPOL_STATE_FLOWS_AEC)

Written 2026-10-30, before any run of the arm.

## What changes

The statewide preference flows (`flows_for()` -> `estimate_flows_for()`, used for the statewide two-party
anchoring: `fit_seats_full.R:602` `ll_flow()`, and the harnesses' trend via `statewide_draws_as_at()`) come, for
state elections, from the anchor clone's hand-maintained `preference-estimates.csv`. Its state rows are copied
NATIONAL federal figures: Victoria 2018, 2022 and 2026 all read 81.94 for the Greens (the 2016 national flow), and
the 2026 value is a mean of those (83.46). The AEC publishes each class's flow BY STATE: Victorian Greens 87.83
(2022) and 89.70 (2025).

Arm: `AUSPOL_STATE_FLOWS_AEC=1`. For a compulsory-preferential state election (vic, sa, wa, qld from 2017), each
class with exhaust 0 takes its state's AEC flow at the latest federal election held strictly before `as_of`
(the cycle start in the harnesses, the run date in the published forecast). Table:
`inst/extdata/aec-state-class-flows.csv` (`scripts/build_aec_state_class_flows.R`). The seat flow matrix
(`build_flow_matrix()`) is NOT touched.

### Addition before any run (2026-10-30): arm B, named parties only

Printing the arm's values for Victoria 2026 (before any screen) showed OTH moving 48.87 -> 71.52: the federal OTH
in Victoria is mostly left-leaning minors (Legalise Cannabis, Animal Justice, Victorian Socialists) and a state
ballot's OTH is a different mix. Greens 83.46 -> 89.70 and One Nation 33.73 -> 25.00 are the same party on both
ballots. So two arms are screened, decided by the same rule:
- **A**: `AUSPOL_STATE_FLOWS_AEC=1` (every class with an AEC row).
- **B**: `AUSPOL_STATE_FLOWS_AEC=1 AUSPOL_STATE_FLOWS_AEC_CLASSES=GRN,ONP`.
If both pass, B ships unless A beats it by more than 1 SE (B is the version whose premise is checked).

## Prediction (written before running)

Where the AEC figure is higher than the copied one (Greens in most states), the anchoring needs less Labor primary
to reach a polled two-party figure, so Labor's statewide primary and seat count should fall slightly. Expected
size: Greens ~12% x a few points of flow = ~0.3-0.7 points of two-party; a handful of seats in the live Victorian
forecast. Harness effect smaller, because as_of is the cycle start (Victoria 2022 gets federal 2016, 83.34).

## Measurement and decision rule

1. Screen: `scripts/quick_arm.R "AUSPOL_STATE_FLOWS_AEC=1"` on AEF-7 (default pairs). Primary: pooled seat-winner
   log loss (lower is better), SE clustered on election; also share RMSE. Federal and NSW pairs must be
   byte-identical (the switch does not apply there) -- if they move, the switch leaks and the arm is void.
2. If not WORSE on AEF-7: all 22 (`--pairs=all`), outside the session.
3. Ship rule (standard): pooled log loss better or within 1 SE with share RMSE better, and no election worse by
   more than 2 SE. A refusal from one election carrying the effect goes to Pete (clause-refusals rule).
4. Regardless of the score, print the live Victorian forecast with and without it (Labor seats, P(majority),
   statewide two-party) so the size of the change on 28 Nov is visible.

What would make an apparent win unacceptable: any federal or NSW pair moving; a gain that comes only from wa or
sa pairs where the AEC state figure is from a federal election years before (stale in a different way).
