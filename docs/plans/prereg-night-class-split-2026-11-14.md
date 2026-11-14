# Pre-registration: two candidates of one class counted separately ON THE NIGHT (14 Nov 2026)

Pete, 14 Nov ("Build and test it"). The night model, like the pre-election one, runs every candidate of a class as
one runner: Monash fed2025 (Leonard 17.1 + Broadbent 10.2 = one IND on 27.3%) ends the replay with the Liberal, the
winner, at ~0.005, because the combined IND passes Labor (20.3) in 99.6% of draws. The pre-election split
(`AUSPOL_CLASS_SPLIT`, `plans/prereg-class-split-2026-11-06.md`) was refused twice on 6 Nov; its junior fraction came
from per-candidate PREDICTIONS (the weak part). On the night each candidate's own figure is COUNTED, so the junior
fraction is measured, not predicted. 25 vic2026 seats have 2+ independents. Walk: `reviews/two-candidates-one-class-2026-11-06.md`.

Pete's 6 Nov rule ("no further arm on this mechanism without a new design from Pete") is met: this is the new
design he chose today, night-only.

## Method (fixed before any run)

`night_class_split()` (`R/night_class_split.R`), behind `class_split` in `night_run_update()` (NULL = byte-identical):

1. For each seat with counted units and, among them, 2+ candidates of one minor class (IND, OTH, OTH_RIGHT) with votes:
   `r` = the second-largest candidate's counted votes over the class's counted votes (capped at 0.5, as the
   pre-election split). One class per seat: the one whose junior has the most counted votes.
2. `sd` = `sd0 * sqrt(1 - counted share)`, `sd0` = `class_split_fit(target)$sd`: the historical error of a
   pre-election junior fraction, fitted on EARLIER elections (the uncertainty before anything is counted, shrinking
   as the seat counts). `f` (same-class flow) = `class_split_fit(target)$f` for the class: earlier elections only.
3. These go to the simulator as the existing class-split elements (`cls`, `cls_r`, `cls_sd`, `cls_f` of
   `coalition_split`); a seat already split for the Coalition keeps that. No count: no split (unchanged).

## Known answers, stated before the runs

- Monash fed2025: the Liberal's probability must be higher in the arm than base at 8pm, 9pm and the last time.
- A seat with one candidate per minor class is byte-identical (same seed): checked by `max |win prob change|` over
  seats with no split, which must be exactly 0.

## Runs

Fixed replay, 20,000 sims, same seeds, the three real nights of the pair-cal prereg (fed2022, fed2025 via
`scripts/night_replay_feed.R`; vic2022 via `scripts/night_replay_vec.R`), both arms with the live night default
`pair_cal` at its time-forward fits (fed2022 `2.944439,1`; vic2022 `0.980156,0.583960`; fed2025 `1.068189,0.638272`).
Arms: base, split (`--class-split=1`).

## Decision rule

- Primary: night-average seat-winner log loss, pooled over the three nights, seats weighted equally (lower is
  better), SE clustered on seat (`scripts/score_night_pair_replays.R`).
- Targeted (reported with the primary): the same on the seats where the split is active at some time.
- Ship (make it the `night_runner.R` default for 28 Nov) if the pooled primary does not rise by more than 1 SE, the
  targeted set falls, no night is worse by more than 0.005, and the Monash known answer holds. Anything else goes
  to Pete with the split.
- Unacceptable even if those pass: a seat with no split that moves at all; any seat summing above 1.
