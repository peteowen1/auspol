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

## RESULT, arm B (2026-10-19, screen; appended)

`quick_arm.R "AUSPOL_HARNESS_SW_DRAWS=net" --pairs=all --reuse`, 1,000 sims, log `deciding-runs/quickarm-20261019-f4-net.log`
(baselines reused only where a per-harness canary re-ran byte-identical; OFF also proven identical on vic2022, wa2025,
fed2025 directly). Seat-winner log loss change, lower is better, SE clustered on election:

| scope | elections | seats | change | SE | worse in |
|---|---|---|---|---|---|
| all changed (primary, amendment 2) | 32 | 2,857 | -0.0006 | 0.0008 | 17 |
| federal | 7 | 1,051 | -0.0016 | 0.0011 | 2 |
| state | 25 | 1,806 | -0.0000 | 0.0010 | 15 |
| all seats (guard) | 35 | 2,931 | -0.0006 | 0.0007 | |
| AEF-7 subset (reported) | 7 | 681 | -0.0019 | 0.0018 | |

Leave-one-election-out: -0.0008 to -0.0003. Worst sa2014 +0.0084, sa2010 +0.0077, wa2005 +0.0074; best qld2024 -0.0101,
wa2008 -0.0096, qld2017 -0.0067. Floor (clause a of the net-out): 0 cells in most elections, at most 90 of 1,057 (fed2019).
nt2016/2020/2024 unchanged (no draws).

Reading: within 1 SE on the primary, so the screen does not clear B and does not stop it. With the first screen this
says: draws on top of the full seat spread (what `fit_seats_full.R` publishes today) +0.0017 worse on the states; draws
with the statewide variance netted out of the seat spread back to baseline, and better on the federal pairs, which are
the one harness that already ran the published configuration. Next decision is Pete's (deciding run, and the live port).

## LIVE PORT AND WALK (2026-10-19; Pete: "port to live, then decide")

`AUSPOL_SW_NET_LIVE` (default "0") in `fit_seats_full.R`: the same net-out, reference the flat 1.5 (live `psd` is the
draws' own sd and would net out nothing). Walk on vic2026, both runs in the quick_arm scratch folder (never `output/`):
SWLN1 moved seat variance ALP -7.67, LNP -6.66, GRN -3.57, ONP -3.48 (IND/OTH_RIGHT +0.2); 6 of 616 cells at the floor;
mean seat sd 3.75 -> 3.32. Seat totals unchanged (ALP median 30, 90% 16-42; LNP 30, 19-46 vs 20-46; ONP 21, 11-32).
Favourite unchanged in 88 of 88 seats; favourite probability +1.3 points on average, at most +3.3 (Melton ONP
0.612 -> 0.645); seats at 90%+ 24 -> 25. Deciding run (harness arm, 20k) scheduled 22:00:
`deciding-runs/20261019-1414-f4-net`. Shipping is Pete's call with that result.

## RESULT, arm B deciding run (2026-10-19 14:49-16:19, 20,000 sims, all 35 elections; appended)

`deciding-runs/20261019-1414-f4-net` (DONE; code 4051ca9, no baseline reuse). Seat-winner log loss, lower is better,
SE clustered on election:

| scope | elections | seats | change | SE |
|---|---|---|---|---|
| all seats (quick_arm, floor 2.5e-5) | 35 | 2,931 | -0.0014 | 0.0006 |
| primary: changed elections | 31 | 2,810 | -0.0014 | 0.0006 |
| federal | 7 | 1,051 | -0.0011 | 0.0011 |
| state | 24 | 1,759 | -0.0017 | 0.0007 |
| AEF-7 subset | 7 | 681 | -0.0021 | 0.0011 |
| recomputed at floor 1e-6 / 1e-4 | 32 | | -0.0012 / -0.0009 | 0.0005 / 0.0005 |

1. Primary better by more than 1 SE: PASS (-0.0014, SE 0.0006).
2. Guard, all seats: PASS.
3. Leave-one-election-out: PASS (least favourable drop, fed2022, still -0.0012 at 2.1 SE).
4. No election worse by more than 2 SE of its own seats: FAILS on sa2014 (+0.0043, own SE 0.0012) and wa2021
   (+0.0024, SE 0.0008); at the 1e-4 floor nsw2019 also (+0.0023, SE 0.0008).
Clause (a), floor artefact: no (holds at 1e-4; 1 seat under 1e-4 in base and arm alike).

Both refusing elections lose broadly, not in one seat: correct calls made a little less certain (sa2014 Ashford ALP
0.741 -> 0.722, Mawson 0.822 -> 0.804; wa2021 Nedlands ALP 0.875 -> 0.855, Carine 0.693 -> 0.678), the expected cost
of a wider, calibrated statewide spread in elections whose statewide polls were close. Verdict under the rule:
REFUSED by clause 4; per `clause-refusals-go-to-pete`, the split goes to Pete for an override decision.
