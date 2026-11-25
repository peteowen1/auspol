# Overnight 25-26 Nov 2026 (Pete asleep; "keep working through next steps on dev, fixes and housekeeping")

## Rules this run must never break
1. Nothing to main, no release uploads, no forecast dispatches, no switch flipped on in published_flags.R:
   anything that changes the live forecast waits for Pete in the morning.
2. Never start a heavy R job (check_like_ci, quick_arm, fit_seats_full) while a scheduled seat-type deciding
   run is RUNNING (1:00am A, 3:15am B), or with under 8 GB free. Never kill a process.
3. Commit by explicit path on dev; leave other sessions' files (the DESCRIPTION bump) alone.

## Queue (in order)
1. Full check_like_ci on dev (the Victorian Socialists change got only the registry test) - before 1am if memory allows.
2. Score seat-type runs A and B when DONE; fill the prereg RESULT on branch seat-corr-type. Ship decision -> Pete.
3. Check the 4:30am forecast run (MRP cells, IPC1 hits, CFC2, what-if page refreshed).
4. Housekeeping: hub-slimming on NEXT-STEPS.md (45k chars) and DECISIONS.md (40k); queue flags.
5. Small fixes: #283 review nits (miss diagnosis compares against same-target entries).

## Log
