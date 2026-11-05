# Overnight 2026-11-05 to 06 (Pete asleep from ~11:55pm)

Pete: "keep working through next steps on dev and making fixes and housekeeping ... if you need me for something,
save it for the morning and move onto something else". Rules: dev only, no merges to main, no deletes, light work
while the deciding runs hold the machine (bucket split from 10:30pm, departed-slope pool from 2:00am).

## FOR PETE IN THE MORNING

- HOUSEKEEPING PROPOSAL (nothing deleted; your yes needed): auspol has 68 local branches. 52 have no commit missing from dev
  (checked by patch content, `git cherry dev <branch>`): all `worktree-agent-*` and `worktree-wf_*` branches with 0 unmerged, plus
  census-retire-old-builder-1025, ci-step-timeout-1026, conserve-shrink, cov-tf, fat-tail-cell-error-1026, forecast-on-time,
  ind-overcall-1025, mp-slope-shrink-1025, newind-seatpoll-1026, night-replay-json, night-runner, party-class-fix, seat-spread-tf,
  slim-decisions-1028, surge-live, upper-house-design, upper-house-results, work-5c, zero-order-late. Recommend: delete those locally.
  Keep (unmerged work): departed-rate-fit-1105, fed-breakdowns-trend-1105, prereg-offbranches-1025 (results), the research/ and
  prototype/ branches, fed-timing-resume-fixed and instrument-backtest-fed-timing (queue item, never reviewed), departed-rate-refit
  (superseded by departed-rate-fit-1105; delete after a look), and the 6 worktree-agent branches with 1 unmerged commit each.
  Worktrees removable (branches pushed): .claude/worktrees/deprate-1105, fedbd-1105, wf_068cdb55-fff-2, wf_240a01af-c97-1 (checked 12:10am: no junctions, nothing uncommitted in any of the four).

## Shipped tonight

- `c94cc074`: NEXT-STEPS under 40k (43,758 -> 39,982 chars). Status block brought current; fixed/closed items moved to DECISIONS; the election-night entry's history moved verbatim to `backlog/journal-2026-11-05-election-night.md` (runbook and every open step kept in the hub).
- `8cf24ad2`: arm `AUSPOL_STATEWIDE_ENDPOINT` (off). CONFIRMED BUG: `statewide_draws_as_at()` read every party at the single latest series date, so a party missing from the newest poll was dropped to 0 and folded into Others. 11 of 32 backtest targets: nsw2023 One Nation 4.6 -> 0 (last poll 12 days out), nsw2019 One Nation 3.9 (6 days), fed2016 Xenophon 3.0 (1 day), qld2017 Katter 1.8 (4 days); also defunct parties (fed2019 Centre Alliance 221 days, sa2018 Family First 548 days). Live already reads per party (`fit_seats_full.R:566`), so backtests and the trees' training levels differ from what ships. On nsw2023 the fix gives One Nation 4.53 against an actual ~1.8, so it is not automatically better: screen pending.
- `44d2c10c` (dev): tests for #194's review nits, `test-poll-date-ours.R` (poll_layer end to end; on/off/default) and the BludgerTrack reader test. Both pass; full check_like_ci deferred until the deciding runs finish.

## Failed / not done, and why

## Decided on Pete's behalf

## Still queued

- LATENT (not live): `wiki_polls()` row self-check is NA when the AE file has no One Nation column (`.ps_implied()` gets NULL), so matched rows would keep AE's numbers and date silently. Every layered region has the column today; NT is never layered. Fix if a region without ONP is ever layered: give `.ps_implied()` a zero for a missing column.

## Log

- 12:05am. Fold bug confirmed and arm built; screen after the deciding runs.
- 11:55pm. 8.7 GB free. Bucket split deciding run RUNNING (70 harness runs, est ~62 min at 1 slot; started 10:30pm).
  Departed-slope pool a1 PENDING for 2:00am. The 12:41 departed run is SUPERSEDED (its task was removed).
