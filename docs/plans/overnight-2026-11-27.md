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
