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
- 10:09pm: full check_like_ci on dev PASSED (5,551 tests, 0 failed; R CMD check skipped, package unchanged). Item 1 done.
- 10:05pm: hubs slimmed, DECISIONS 40.4k -> 27.7k, NEXT-STEPS 45.7k -> 41.4k (47d6dfdc). Item 4 done.
- 10:14pm: #283 review nit fixed (fe34a24b, 27 cache tests pass); CI R-CMD-check green on d38a3bf7. Item 5 done.
- 2:16am: seat-type run A (type) DONE. Seat-total log score 1.9259 -> 1.9188 (diff -0.0071, SE 0.0174, 35 elections, 191 cells): fails rule 1 (needs >= 1 SE) => NULL, refused under the prereg. Seat-winner log loss 0.3033 -> 0.3023 (-0.0009, SE 0.0007; guard passes, baseline reproduces 0.3033). Coverage 90%: 0.895 -> 0.901. Sign holds leaving any one election out in 32 of 35. CAVEAT: totals baseline 1.9259 / 191 cells vs parent 1.8792 / 195: trace why. Score file: deciding-runs/20261125-2142-seat-type-A/score-totals.txt.
- 2:40am: caveat RESOLVED. Parent baseline (cache 235244214575) vs tonight's (82a613cca0e0) score identical (diff 0.0000, every class): same inputs. The pooled cell count differs by PAIR (197 base-vs-base, 195 regional pair, 191 type pair): the scorer's scorable minor-class cells depend on both runs compared. Not a data change.
- 4:31am: run B (both) DONE: seat-total log score 1.9549 -> 1.9390 (-0.0159, SE 0.0172 = 0.92 SE; clause 1 fails), sign holds 35 of 35, 90% coverage 0.894 -> 0.904, guard -0.0005 (SE 0.0008). Both arms refused; RESULT on branch d3367c17; split to Pete (rec: OFF for 28 Nov). Item 2 done.
