# Overnight 27 Nov 2026 (Pete asleep from ~12:05am; election Sat 28 Nov)

## Rules this run never breaks
1. Never change what ships: no edit to `scripts/published_flags.R`, no merge to `main`, no upload to R2 / releases / the live night key.
2. Never kill a process by name, and never run two R-heavy jobs at once (memory ~4-7 GB free, kernel leak).
3. Anything needing Pete goes at the top of the morning summary, not into a change.

## Queue, in order
1. Unit tests for `R/night_borrow.R` (leave-own-out, zero cells stay zero, off = identity); run the suite on dev.
2. 4:30am daily run check (first Victoria-only run): conclusion, no nsw2027 jobs, UHV/UHF3, SCC1, CSC9/CSC7, numbers vs 8:24pm.
3. Benchmark capture of record (Fri 27 Nov): `Rscript scripts/snapshot_benchmarks.R` + TAB/GES Chrome steps, seat odds page + R2 seat odds
   JSON is an UPLOAD -> rule 1: prepare, leave the upload for Pete's go unless standing permission covers it (it does not).
4. Housekeeping on dev: queue items flagged by check_queue.py that this session touched.

## Log
- 12:10am: tests for R/night_borrow.R written (18 checks, pass), pushed.
- 12:15am: request register: 4 shipped/refused rows closed (moved verbatim to backlog/pete-asked-for-closed-2026-11.md), 26 Nov asks added.
- 12:25am: dev CI was RED on 1b2cd22f (my push without check_like_ci: undocumented Rd arg); check_like_ci then also caught
  AUSPOL_NIGHT_BORROW and AUSPOL_EXTERNAL unlisted. Fixed, check_like_ci clean, pushed.
- 12:40am: queue: NSW blog seat-page paths corrected (`politics/vic2026/seat.qmd`, `nsw2027/index.qmd:46`); search-interest item reworded.
- FOR PETE (after 28 Nov, not urgent): 7 remote branches add nothing over dev and can be deleted: dev-2026-10-07-unreviewed,
  other-upper-houses, pipeline-guide, seat-corr-type, upper-house-combo, upper-house-count, upper-house-vote. Not deleted (needs his yes).
- Benchmark capture of record must run after 11am Sydney (folder is the UTC date; 27 Nov UTC starts 11am AEDT).
- 1:00am: wrote docs/NIGHT-RUNBOOK-vic2026.md (claims checked: auto index on laptop and backup, results --source). FOR PETE: night fetch rate decision.
- 5:04am: 4:30am run 45868309996 GREEN, every check passed (NEXT-STEPS). Move from 8:24pm = final Newspoll via Poll Bludger.
- 5:25am: FOR PETE: Agenda C 14 Nov poll double-counted (alias gap); fix prepared, not applied (it is an upload). NEXT-STEPS top.
