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

## RESULT (14 Nov 2026, 3:19pm): PASS; SHIPPED as the live night default (Pete: "Ship for 28 Nov")

Run `deciding-runs/20261114-1500-night-class-split/` (code a1f36a82; vic2022 split rerun on 91f7cf68 after it
stopped on NCS1!: the VEC feed's booth table carried no candidate names, now it does; vic2022 base unaffected, as
the name column is read only by the split and by `cand_ref`, off on the feed). 20,000 sims, same seeds.
Night-average seat-winner log loss (lower is better), split minus base, SE clustered on seat:

| Set | Seats | Base | Split | Change (SE) |
|---|---|---|---|---|
| fed2022 | 151 | 0.0724 | 0.0735 | +0.0011 (0.0012) |
| fed2025 | 150 | 0.1387 | 0.1184 | -0.0203 (0.0248) |
| vic2022 | 88 | 0.0643 | 0.0633 | -0.0010 (0.0010) |
| pooled | 389 | 0.0961 | 0.0885 | -0.0076 (0.0096) |
| targeted (2+ same-class candidates) | 327 | 0.1058 | 0.0969 | -0.0088 (0.0114) |
| pooled without Monash | 388 | | | +0.0018 (0.0012) |

Clauses: pooled not worse by more than 1 SE TRUE; targeted falls TRUE; no night worse by > 0.005 TRUE; Monash
Liberal above base at 8pm (0.654 vs 0.046), 9pm (0.340 vs 0.006) and the end (0.469 vs 0.005) TRUE; no seat
without 2+ same-class candidates moved TRUE (the one scorer flag, South-West Coast vic2022, is the hyphen: the booth
file says "South West Coast", four independents); no seat above 1 TRUE.

Read with: the gain is mostly Monash; without it +0.0018 (1.5 SE). The costs: Bradfield fed2025 +0.305 (Boele won
by 26 votes; base was 0.99 sure because it counted another independent's 4.1% (Yin) as hers; split ends 0.67), Forde
+0.256 (a minor-right split, Pop 5.1 / Hiscock 4.7, flips the late lean to the Liberal; Labor won; not traced),
Lyons fed2022 +0.144, Calare +0.123 (an 8pm wobble, 0.99+ by 10pm).

### ADDENDUM (14 Nov, 8pm, after the result): Forde traced; a replay bug, not the split

Added after the decision; the clauses and table above are unedited.

- Forde never had its two-candidate count used in either arm. The feed shows "HOLZBERGER, Rowan v Van MANEN, Bert"
  from 6:01pm; the booth file says "VAN MANEN, Bert"; `night_replay_feed.R` compared case-sensitively and read it as a
  wrong pair. 8 divisions a night were lost this way (fed2022: Dobell, Eden-Monaro, Flinders, Lindsay, Riverina,
  Shortland, Swan, Wright; fed2025: Dobell, Eden-Monaro, Fairfax, Forde, Lindsay, McEwen, Riverina, Wright). Fixed
  21578e34 (case-folded; NRF0 prints the matches). The live VEC path does not compare names.
- Without the count both arms run on preference flows from first preferences. At the final count Labor's simulated
  2CP share (actual 51.77%): base mean 50.54 (P Labor 0.588), split 49.79 (0.343). The split puts the exclusion order
  right (both minor-rights out first into One Nation, as in the AEC's distribution); base often ran the combined
  minor-right (9.9%) past One Nation (10.2%), and that last minor's flow to Labor is 40.0% in the model against One
  Nation's 27.4%. Actual One Nation last-exclusion flow to Labor in Forde: 32.6% (fed2025 median 29.8% over 23 seats,
  fed2022 37.8% over 24), so the model's 27.4% is ordinary seat-level error, not a general miss. Base's better number
  came from the wrong count order.
- With the fix (fed2025, both arms, same seeds): Forde Labor at 9pm base 0.829, split 0.870; at the end base 0.642,
  split 0.691. Rerun of all federal arms: `deciding-runs/20261114-1700-replay-namecase/`.
- RESTATED (rerun DONE 10:45pm, code 21578e34, same seeds; vic2022 copied, unaffected; fed2022 base changed in exactly
  the 8 fixed divisions and nowhere else). Split minus base, SE clustered on seat: fed2022 +0.0011 (0.0012), fed2025
  -0.0222 (0.0247), vic2022 -0.0010 (0.0010), pooled -0.0084 (0.0095), targeted -0.0097, without Monash +0.0011
  (0.0010; was +0.0018). Decision rule: PASS on every clause; guard 0 moved seats without a split on the federal nights.
  The live `.NIGHT_PAIR_CAL` refitted on the fixed base replays is identical (0.945244, 0.681490; 388 seats, 33 wrong):
  the fit reads each pair's first showing, before any booth 2CP count.
