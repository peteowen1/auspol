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

## RESULT (2026-10-19, screen; appended, nothing above edited)

Switch built in 304b662. Proof: OFF byte-identical to the pre-change code on vic2022 and wa2025 (allprobs and
sharedetail, 1,000 sims); ON prints the applied spread (vic2022 sd(ALP-LNP) 3.68, wa2025 4.24, against 2.12 for the
flat 1.5 with parties independent; minor classes NARROWER than flat, sd 0.4-1.1). The broken-matrix fallback is a unit test.

Screen `quick_arm.R "AUSPOL_HARNESS_SW_DRAWS=1" --pairs=all`, 1,000 sims, log
`deciding-runs/quickarm-20261019-f4-sw-draws.log`. Seat-winner log loss, lower is better, SE clustered on election:

| scope | elections | seats | base | arm | change | SE |
|---|---|---|---|---|---|---|
| targeted (vic/nsw/qld/sa/wa) | 25 | 1,806 | | | +0.0017 | 0.0014 |
| all seats (guard) | 35 | 2,931 | 0.3085 | 0.3095 | +0.0011 | 0.0009 |
| AEF-7 subset (reported) | 7 | 681 | 0.2625 | 0.2628 | +0.0003 | 0.0019 |

Worse in 18 of 25 targeted elections (largest sa2014 +0.0115, nsw2019 +0.0102); better in 7 (wa2008 -0.0147, wa2001
-0.0124, qld2024 -0.0105). Federal controls exactly 0 (7 of 7). nt2016/nt2020/nt2024 printed `BNTW0!` (no draws: thin
cycle) and are unchanged, so they count for neither side (clause b).

Verdict: REFUSED at the screen (primary not better; guard WORSE by more than 1 SE; "WORSE stops"). No deciding run.
The switch stays at "0". Named blind spot applies: SHRINK, seat_sd and slopes were tuned under the narrow spread, so
this says "the shipped statewide spread, dropped unretuned into the state harnesses, scores worse", not that the
narrow spread is right. Open question for Pete: the live forecast DOES use the wide draws, so either the state
backtests are optimistic about what ships, or the live statewide spread (FP_EXTRA_SD 2.419) is too wide for states.

## AMENDMENT 1 (2026-10-19, after the screen above; Pete chose "sweep the width", then "add a net-out arm")

Why: the seat-level spread `1.10 + 8.67 sqrt(p(1-p))` is the total seat residual `1.68 + 7.85 sqrt(p(1-p))` with a
statewide piece of ~1.3-1.6 points removed in variance (`R/seat_sim.R:65-68`), i.e. the flat `party_sd` 1.5. The
draws carry ~2.5-2.9 for the majors, calibrated against real statewide misses (`reviews/statewide-spread-2026-10-06.md`,
RMS z 0.96 over 44 major party-elections). Draws on top of an unchanged seat spread count the statewide miss about
twice for the majors. The live forecast (`fit_seats_full.R:1781-1785`) does exactly that today.

Arms, each against the same flat-spread baseline, `quick_arm.R --pairs=all`, 1,000 sims:
- **B (primary hypothesis)** `AUSPOL_HARNESS_SW_DRAWS=net`: the draws as in the original arm, and each cell's seat sd
  (after the size and composition factors) re-derived so the total is unchanged:
  `sd_new = sqrt(max(sd^2 - (V_k - party_sd_k^2), (0.5 sd)^2))`, `V_k` the draws' variance for class k. Minor classes
  whose draws are narrower than 1.5 get a WIDER seat sd by the same identity. The 0.5 floor is a guard, not a fit; the
  count of floored cells is printed (`SWN1`), and a result carried by floored cells is reported as such.
- **A0, A1 (diagnostic)** `AUSPOL_HARNESS_SW_DRAWS=1` with `AUSPOL_FP_EXTRA_SD` 0 and 1.2 (2.419 is the screen above).
  A new switch, default "2.419", read by `statewide_draws_as_at()` and `fit_seats_full.R`; byte-identical at default.

Decision: the standard rule, B against baseline. If B passes the screen, the 20k deciding run follows
(`deciding_run.ps1 -Arm "AUSPOL_HARNESS_SW_DRAWS=net" -Label f4-net`), and if that passes, the same net-out goes into
`fit_seats_full.R` as its own switch and change, walked on the live Victorian forecast before shipping. If only an A arm
wins, it goes to Pete with the 6 Oct calibration table beside it: a narrower width would make the statewide level
over-confident against real misses, so it is not shipped on seat log loss alone. Clauses (a)-(c) above apply to every arm.

## AMENDMENT 2 (2026-10-19, before arm B ran)

The federal harness already passes statewide draws, so it carries the same double count; by the one-harness-is-all
rule arm B's net-out reaches `backtest_candidate_fed.R` too (`BFWN1`). Under arm B the federal pairs are therefore
TARGETED, not controls; they stay controls (must score 0) under the A arms only if those leave fed untouched, which
they do not (`AUSPOL_FP_EXTRA_SD` reaches fed as well). Primary for B: all 32 changed elections; fed and state
reported separately beside it.
