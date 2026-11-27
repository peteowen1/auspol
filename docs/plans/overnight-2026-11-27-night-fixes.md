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
- 9:12pm rehearsal (`--dry-2022 --max-cycles=1`, tonight's night state): rc 0, 87 of 88, 2CP 87, no 999s, ~90 s a cycle.
- Sizing (vic2026 forecast, 7:24pm run): 75 of 88 seats have 2+ candidates in one class (IND 25, OTH_RIGHT 29, OTH 55);
  One Nation in a likely final pair in 57; favourite under 0.70 in 47. Web pages carry every ordinary booth, every early
  centre, postal/absent/provisional by candidate, and two-candidate counts.
- 9:30pm lanes A and B launched (Opus, worktrees off dev 403f3f9d; replays only by the main session, `AUSPOL_CODE_DIR`).
- 9:31pm full-night base replays launched (scratchpad/overnight/).
- Mildura by candidate (feed, counted ordinary booths): 8pm raw Coalition 45.5 / IND 40.4 (finals 45.0 / 41.2) while the
  projection said 39.0 / 46.5; 7pm's 4 booths were the Coalition's strongest (67.3% in 2018 -> 60.9%).
- **Lane A found (~9:55pm): the vic2022 FEED replays never made placeholders for uncounted ordinary booths** (the 2022
  PollingLocations setup file has no Classification; `night_booth_table()` keeps only VotingCentre). So every vic2022
  replay result before tonight's fix projected the uncounted 97% from the early/postal units alone. Federal replays are
  unaffected. The LIVE website path is fine: partial-count fixture (543 of 1,729 centres, no early/postal) made 1,186
  placeholders, exactly the missing ones, 0 unlisted (scratchpad/web_partial.R). Fix: replay passes the final ordinary
  booth list as places (lane A, own commit); vic2022 base to be rerun.
- 10:10pm: place-list fix cherry-picked to dev (3f63ff25); faulty vic2022 base kept as `noplaces-*`; corrected vic2022 base
  started 10:44pm after the federal bases (fed2022 done 10:17pm, fed2025 10:44pm).
- ~10:45pm lane A interim (federal nights; projection error under 15% counted, 7,378 cells): A1 booth-level swing WORSE
  (RMSE 2.715 -> 2.782; fed2025 +0.56 SE 0.22, fails "no night worse"); A2 vote-type pooling no change on federal (only
  ordinary booths counted by 9pm); A3 representativeness sd better overall (-0.017 SE 0.006) but 10-15% bin worse by 2 SE
  and does not beat the count-only fitted curve: fails as written. vic2022 arms pending on the corrected places.
- 11:04pm corrected vic2022 base (3f63ff25): placeholders 1,542 at 7pm -> 8 at 2am; Labor 7pm dip -3.3 -> -2.0 seats; log
  loss 7pm 0.216 -> 0.199, 8pm 0.129 -> 0.104, but 9pm 0.041 -> 0.061 (Northcote: Labor 0.94 -> 0.21; a flow problem).
- Lane A final (8ea44f8e): A1, A1b, A2 refused; A3 (--rep-sd=0.0458,0) borderline -> seat-level replays (11:24pm).
  A3 vic2022: Mildura 7pm Cupper 0.98 -> 0.92; 7pm log loss 0.199 -> 0.183; 9pm 0.061 -> 0.063. Federal nights pending.
- Lane B (46d2bf43 + place fix 207d5573): B1 same-class own flows, B1c candidate-level 2CP read, B2 cross-seat flow pooling,
  B3 flow by vote type; one-seat traces only; replays queued after A3 (scratchpad/overnight/run_laneb.sh).
- Lane C (fffbf957, --proj-sd=units): 10-feature Student-t variance model; projection log score better on all held-out
  nights (vic +0.288 SE 0.104) but vic2022 90% coverage 0.94 -> 0.81 (3 units) and narrower than base at 1-2 units:
  refused by its prereg. Pete asked why (12:10am); seat-level vic2022 replay started 12:15am to settle it.
- Review of tonight's dev night code (834699bb~1..HEAD): 0 Important; default path unchanged; 0 NW11 booth-name
  mismatches in the corrected replay. Nits: checkpoint helper sourced from cwd; NRV6 guard only at a 19:00 stamp.
- night_vic2026.sh --loop=FLAG pass-through (6b5b9aaa), to turn a shipped default off mid-count.
- **A3 SHIPPED (PR #292 merged 1:06am, main c21be992; dev c136880c):** seat-level replay on all three nights passed
  (under 15% counted -0.0012 SE 0.0008; nights vic -0.0013, fed2022 -0.0002, fed2025 +0.0001 SE 0.0003; wrong 0.99
  calls 25 -> 23; seats right 381 both). ON by default in night_cycle (.night_rep_sd_cfg); off with --loop=--rep-sd=off.
  Mildura 7pm Cupper 0.98 -> 0.92 (fp sd 3.2 -> 5.2); unchanged from 8pm (projection still 44.9/39.6; flows 57.7%).
  Gates: two Sonnet reviews 0 Important; check_like_ci clean on the ship branch; GitHub CI green; rehearsal on the saved
  2022 pages with A3 on rc 0 (87 of 88, loop prints rep-sd 0.0458,0); partial-count fixture (543 of 1,729 centres)
  with A3 on: no NA in shares, sd or win probabilities.
- Lane C seat-level vic2022 replay (12:15am): worse at every hour from 10pm (0.057 -> 0.064, 11pm 0.016 -> 0.025);
  refusal confirmed. Stays off.
- Fast screen built (scratchpad/overnight/screen.sh + small-states/, 2,000 draws, to 9pm, three nights): 422 s per
  arm vs ~45 min full. Simulation is not the bottleneck; per-snapshot parsing and booth matching repeat for every arm
  (cache after 28 Nov; replay logs need per-stage timing).
- 1:15am lane D launched: D1 vote-type uncertainty until a type reports; D2 Student-t combine (from lane C) on the
  current sd. Lane B full replays running (vic2022 lbbase byte-identical to the corrected base).
