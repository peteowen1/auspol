# Prereg: put preference-flow uncertainty into the seat simulation (AUSPOL_FLOW_SD)

Written 2026-10-31, before any run.

## Why

`AUSPOL_FLOW_SD = "0"` is published: every simulation uses the same preference flows, so once the primaries are
known the winner is treated as certain. Two fed2025 seats show the cost, both decided by preferences in a contest
that was not Labor v Coalition, both called wrongly at ~0.99 on the real night from primaries alone (the AEC
withdrew its wrong-pair two-candidate count in each, so the night had no 2CP evidence):

- Melbourne: primaries GRN 39.5, ALP 31.3, LIB 19.8; Labor won on Liberal preferences. Afternoon ALP 0.006, night 0.005.
- Monash: LIB 31.8, IND 27.3, ALP 20.3, ONP 8.0; the Liberal won on right preferences. Afternoon IND 0.76, night 0.99.

The August test of this (`reviews/flow-uncertainty-v2-2026-08-20.md`) ran on three Victorian elections on the
retired path and said itself that the test, not the idea, was the reason it found nothing. It has never been
measured on the candidate model over the full corpus.

## Arms (both before any run)

- **A**: `AUSPOL_FLOW_SD=3.65`, the one-step-ahead error of a party's mean flow (sd over 19 observations; the
  value already in `R/seat_sim.R`'s documentation).
- **B**: `AUSPOL_FLOW_SD=6.5`, the measured between-seat error of the booth-implied two-candidate flow, fed2022 and
  fed2025 (`reviews/aec-preference-data-2026-10-30.md`, 0.065).

Each draw perturbs each transfer proportion by N(0, sd) points (the existing mechanism; no new code).

## Prediction (before running)

Seats decided on preferences in a non-classic contest gain (fewer winners at the floor); safe classic seats
barely move. B helps the tails more and costs more in calibration of close classic seats. Size: small pooled.

## Measurement and decision rule

1. Screen both on AEF-7 at 1,000 sims (`scripts/quick_arm.R`). Stop an arm only if WORSE by more than 2 SE pooled.
   This acts in the tails, so a screen pass clears nothing.
2. Deciding run, all 35 elections at 20,000 sims, for the arm that screens better (both if within 1 SE of each other,
   one run at a time).
3. Ship if pooled seat-winner log loss (lower is better; SE clustered on election) is better, or within 1 SE with
   fewer winners below 0.01; and no election worse by more than 2 SE (a refusal by that clause alone goes to Pete).
4. Report regardless: log loss on seats whose actual final pair was not ALP v LNP, separately; Melbourne and Monash
   fed2025 win probabilities; and the live Victorian forecast's Labor-v-Greens seats (Richmond, Northcote,
   Brunswick, Melbourne, Albert Park) with and without.

What would make an apparent win unacceptable: a gain that comes only from widening every close classic seat
toward 50% (check: classic-pair seats' log loss must not get worse by more than 1 SE).

## Screen (2026-10-31 7:29pm, AEF-7, 1,000 sims, surge-off code 010e5741)

- A (3.65): +0.0022 (SE 0.0022), worse by 1 SE; not stopped (the stop is 2 SE).
- B (6.5): -0.0001 (SE 0.0025), within 1 SE; vic2022 0.2430 -> 0.2402, fed2025 0.3451 -> 0.3381, sa2026 0.2383 -> 0.2538.
- Flow noise changes the random stream, so arm and baseline do not share draws here: the screen is noisier than
  usual. Per step 2 both go to the deciding run, one at a time: B `deciding-runs/20261031-1929-flowsd-6p5` (started
  7:29pm), A `deciding-runs/20261031-1929-flowsd-3p65` (scheduled 10:30pm).
