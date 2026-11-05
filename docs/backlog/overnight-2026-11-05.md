# Overnight 2026-11-05 to 06 (Pete asleep from ~11:55pm)

Pete: "keep working through next steps on dev and making fixes and housekeeping ... if you need me for something,
save it for the morning and move onto something else". Rules: dev only, no merges to main, no deletes, light work
while the deciding runs hold the machine (bucket split from 10:30pm, departed-slope pool from 2:00am).

## FOR PETE IN THE MORNING

(filled in as the night goes)

## Shipped tonight

- `44d2c10c` (dev): tests for #194's review nits, `test-poll-date-ours.R` (poll_layer end to end; on/off/default) and the BludgerTrack reader test. Both pass; full check_like_ci deferred until the deciding runs finish.

## Failed / not done, and why

## Decided on Pete's behalf

## Still queued

- LATENT (not live): `wiki_polls()` row self-check is NA when the AE file has no One Nation column (`.ps_implied()` gets NULL), so matched rows would keep AE's numbers and date silently. Every layered region has the column today; NT is never layered. Fix if a region without ONP is ever layered: give `.ps_implied()` a zero for a missing column.

## Log

- 11:55pm. 8.7 GB free. Bucket split deciding run RUNNING (70 harness runs, est ~62 min at 1 slot; started 10:30pm).
  Departed-slope pool a1 PENDING for 2:00am. The 12:41 departed run is SUPERSEDED (its task was removed).
