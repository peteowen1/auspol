# Pre-registration: no votes for candidates who are not standing (2026-10-17)

Committed BEFORE anything is built or run. Found 17 Oct while checking C2 (composition prereg amendment 1b).

## The finding

`simulate_seat_contests()` draws `v <- base_v + shift + noise` for EVERY class and clips at 0
(`R/seat_sim.R:1407`, `src/seat_sim_core.cpp:168`), so a class predicted at 0% (not standing: nomination
zeroing sets them to 0) gets |N(0, 1.10)| points in half its draws. Those votes are excluded first and then flow
on by the flow matrix, so they shift the count wherever a class's flows lean (a phantom One Nation share flows
mostly to the Coalition). Toy check, same seed and flows, four elections (scratchpad `phantom.R`; NOT the full
harness): no seat moves more than 0.05, but holding 0% cells at 0 lowered seat log loss in all four
(vic2022 -0.0011, fed2022 -0.0010, nsw2023 -0.0020, qld2024 -0.0036); fed2022 Labor -0.28 expected seats.

## Arm

| Arm | Switch | Rule |
|---|---|---|
| A (shipped) | `AUSPOL_ZERO_ABSENT=0` | as now. |
| Z | `AUSPOL_ZERO_ABSENT=1` | a cell whose predicted share is 0 (`shares[i, k] <= 0`) is set to 0 after its draw. |

The noise is still DRAWN for that cell (and discarded), so the random stream and every other cell's draw are
exactly the shipped ones: Z differs from A only through the zeroed cells. A surge onto a zero-share class
(`surge_from_zero`) is added later in the draw and is unaffected. Both engines, byte-identical (tested).
Inside `simulate_seat_contests()`, so six harnesses, NT and live.

## Criterion

1. **Primary, every seat, all 35 elections:** seat log loss, SE clustered on election. **Z ships if lower than
   A by more than 1 SE.** (Scope matches the change: it touches every seat with a non-standing class.)
2. **Reported:** per election, expected seats by class moved (live vic2026 too), AEF-7.

Screen at 1,000 sims (`deciding_run.ps1 -Sims 1000`, all 35), then 20,000 before any ship; Pete's call.

## What would make an apparent win unacceptable (decided now)

- **One election** supplies more than half the gain -> refused.
- **Identity:** with the switch off, byte-identical (the off path is untouched code).
- **Live:** any vic2026 seat whose favourite's probability moves more than 5 points is listed for Pete.

## What this cannot see

- A class at a tiny positive share (0 < s < 1) that is standing but negligible still draws noise; this arm
  only removes classes that are not there at all.

## Amendment 1 (2026-10-17, while building, before any run)

The Arm text says Z "differs from A only through the zeroed cells" and the random stream is unchanged. That holds
only up to the first count: a phantom candidate's exclusion used to consume flow-noise draws, so once one is
gone, later draws come from a different part of the stream. Z and A are therefore NOT common-random-number
twins after the first affected seat, and the screen compares them at ordinary Monte Carlo noise. No criterion
changes; the 20k deciding run was already required.

## RESULT (2026-10-18, 5k screen `deciding-runs/20261018-0036-zero-absent-screen-5k/`, code fa5b557) -- REFUSED

Applied (every election differs; largest win-probability change 0.027), but every seat 0.3152 -> 0.3152,
+0.0000 (SE 0.0003); AEF-7 -0.0002 (SE 0.0003). Not better by more than 1 SE: refused, switch stays "0". The toy
check's -0.001 to -0.004 did not survive the full model: the phantom shares are small and mostly excluded first.
