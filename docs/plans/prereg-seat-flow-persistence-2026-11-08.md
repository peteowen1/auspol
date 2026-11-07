# Pre-registration: seat flow persistence (2026-11-08)

Pete, 8 Nov ("go", after the five-seat fed2025 walk). Committed BEFORE any arm run.

**What the change does, in plain words.** Some seats send more of their minor-party and independent votes to
Labor than the election average, and that tendency repeats: across 112 seats that were Labor v Coalition in
both 2022 and 2025, a seat's 2025 flow miss correlates 0.27 with its 2022 miss (research: 0.25-0.49 over six
federal elections, `reviews/tcp-mae-vs-aef-2026-11-07.md` section 4). The flow trees have no feature for a
seat's own past flows. This arm gives each seat a small shift toward its own history.

**Definitions (fixed now).**
- A seat's effective flow at election E, where the final two were Labor and the Coalition:
  `f = (TCP_ALP - FP_ALP) / (100 - FP_ALP - FP_LNP)`, from the AEC's own counts (`aec-fed-tcp.csv`, first
  preferences from the candidate corpus). Seats with under 3% "others" are skipped.
- Its tendency `d_E = f - mean f over that election's seats` (an election-wide swing cancels).
- Weight `w_T`: slope of `d_E` on `d_{E-1}` for the same seat name, over every federal election pair BEFORE the
  target T (time-forward). A slope below 1 is itself the shrinkage; no further tuning.
- In the target, for each seat with a `d_{T-1}`: every flow row in which both Labor and the Coalition are still
  in the count moves `w_T * d_{T-1}` of the votes going to the two of them from the Coalition to Labor (negative
  moves the other way), clamped so neither share goes below 0.

**Arm:** `AUSPOL_SEAT_FLOW_PERSIST=1` (built off), federal harness only in this round. States follow only if
federal passes (their TCP histories need building).

## Metrics

1. **Primary:** pooled seat log loss over the federal pairs the screen runs, lower is better; pass if lower by
   at least 1 SE (election-clustered, as `quick_arm.R` prints it).
2. **Second:** TCP MAE on Labor v Coalition seats whose final two our model matched, fed2022 and fed2025
   (`score_tcp_arm.R`), against the research proxy (fed2022 2.680 -> 2.609, fed2025 5.084 -> 4.978).

## Guards (refuse even if the primary passes)

1. Any federal election worse by more than 1 SE of its own seat-level change.
2. Any non-federal pair not byte-identical.
3. 0 primary cells moved (the arm acts on flows only).
4. The fitted `w_T` printed for every target and between 0 and 1; outside that, the arm is broken, not tuned.

## Predicted result, written before running

Small: seat log loss -0.001 to -0.003 pooled; TCP MAE fed2022 and fed2025 each about -0.05 to -0.10. It will
not fix fed2025's worst seats (Blaxland, Dickson): their 2022 misses had the opposite sign or were small.

## RESULT

(not yet run)
