# Overnight 27-28 Nov 2026: election-night model fixes

## RULES THIS RUN NEVER BREAKS

1. **Never upload to the live night key** (`auspol/night/vic2026.json`) or run the night command with `--upload` before 6pm Sat.
2. **Every fix ships behind a switch, off unless its prereg passes; past 1pm Sat (Pete's cutoff) nothing changes** and the
   model rehearsed at the last green rehearsal runs.
3. **Never kill a process by name, never move HEAD in C:/dev/auspol from an agent, never write to `output/`.**
   Only the main session runs replays (detached, one heavy R job at a time; free memory is ~4-5 GB).

Pete's calls (27 Nov ~9:20pm): a fix that PASSES its prereg overnight gets switched on by Claude (merged to `main` and
`dev`, flag on in the night command, rehearsed); anything failing or borderline stays off for him. Cutoff 1pm Sat.

## Asked for (Pete, 27 Nov ~9:15pm)

1. Same-class candidates (two or three independents) as their own candidates with their own preference flows.
2. Booths still to come modelled as unlike the ones counted (not one seat-wide swing).
3. Early uncertainty beyond the first snapshot.
4. Margins and flows by vote type / booth type (postal, early, ordinary).
5. Learn on the night from counted flows: Bayesian update from the pre-night flow toward the counted one, by vote type.

## Lanes

- **A, projection** (`R/booth_projection.R` `project_seat_from_booths()`, `R/night_update.R` `night_booth_update()`):
  items 2, 3, 4 (first-preference side), unit sizes from the VEC's 2026 early/postal counts.
- **B, two-candidate step** (`R/night_update.R` `night_tcp_obs()` / `night_apply_tcp()`, `R/night_class_split.R`):
  items 1, 4 (flow side), 5.

## Status log

- 9:20pm: plan written; checks before lanes: web page content, vic2026 sizing, Mildura by candidate.
