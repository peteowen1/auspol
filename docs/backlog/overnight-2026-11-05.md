# Overnight 2026-11-05 to 06 (Pete asleep from ~11:55pm)

Pete: "keep working through next steps on dev and making fixes and housekeeping ... if you need me for something,
save it for the morning and move onto something else". Rules: dev only, no merges to main, no deletes, light work
while the deciding runs hold the machine (bucket split from 10:30pm, departed-slope pool from 2:00am).

## Summary (3:30am)

- Both deciding runs finished cleanly: bucket split a tie (item 3), departed-slope pool better on its headline with one guard
  tripped on noise (item 2).
- Two real backtest bugs found and built as off-by-default switches, each screened and confirmed at 20,000 sims:
  parties dropped when absent from the newest poll (fix better, -0.0009, SE 0.0004; item 1), and poll columns classed by code
  (fix a tie that helps federal elections and hurts sa2018; item 6). Neither changes the published forecast until you ship it.
- PR #195 (0.4.136) open, unmerged: CI green on the last code commit. Nothing reached main overnight.
- Still to check: the next daily forecast run is the first with `AUSPOL_POLL_DATE_OURS=1` (merged 10:54pm; last run 9:51am 5 Nov, success).

## FOR PETE IN THE MORNING

**ANSWERED 6 Nov 7:05am:** items 1-4 yes (three switches shipped in 0.4.137, PR #195 merged). Item 5 DONE 7:30am (Pete yes): 4 worktrees removed, 47 merged local branches deleted (5 of the 52 already gone), 18 local branches left. Item 6 (poll-series class) still open.

**IN FLIGHT 6 Nov 7:20am:** full rebuild with the three switches (unpublished; 2 slots, kernel pool leak). When it lands: read `output/rebuild-forecasts-logs/` scoreboard and the promote gates, then `AUSPOL_REBUILD_FROM=9 AUSPOL_PUBLISH=1 bash scripts/rebuild_forecasts.sh` (stage 9 only), then the dev -> main PR (publish before merge: the live run downloads the retrained trees).

In order: three decisions, one merge, one cleanup yes/no, one lower-priority decision.

1. DECISION: ship `AUSPOL_STATEWIDE_ENDPOINT=party`? (`plans/prereg-statewide-endpoint-2026-11-06.md` RESULT.) It fixes a real bug: the backtests'
  statewide level dropped any party missing from the newest poll (11 of 32 targets; nsw2023 One Nation 4.6 -> 0), unlike live.
  Screen, 11 affected elections at 1,000 sims: seat log loss 0.3071 -> 0.3065, -0.0007 (SE 0.0004), BETTER by more than 1 SE;
  nsw2023 -0.0038, fed2016 -0.0018; wa2008 +0.0009, fed2019 +0.0003. CONFIRMED at 20,000 sims (3:26am): -0.0009 (SE 0.0004). Recommend: yes. Shipping = flip the flag, rebuild
  level-pred.csv and retrain the as-at trees (they trained on the buggy levels), then the 20,000-sim run. Live Victoria is unaffected
  by the flag itself (live already reads per party); it changes only through retrained trees.
2. DECISION (clause override): departed-member slope pool `AUSPOL_DEPARTED_POOL` (your 27 Oct "tau^2 toward the pooled slope").
  Deciding run DONE 2:59am, all 35 elections at 20,000 sims: all elections -0.0020 (SE 0.0015), better; the eight targeted
  elections -0.0081 (SE 0.0052), PASS; leave-one-out and the two-biggest-seats check PASS. The one guard that fails is "no
  election worse by 2 SE": nsw2015 +0.0011 (z 2.07) and qld2024 +0.00004 (z 2.11), noise-sized moves where the seat SE is
  near zero. By the letter: refused. My recommendation: ship and record the override. Shipping = `AUSPOL_DEPARTED_POOL="1"` in
  published_flags.R and the inline default, then the next rebuild. (`plans/prereg-departed-slope-pool-2026-11-05.md`, results.)
3. DECISION: bucket split, rebuilt file or frozen (`deciding-runs/20261105-0941-bucket-split-v2-rebuilt/results.txt`, DONE 12:14am,
  all 35 elections at 20,000 sims). Seat log loss (lower is better) 0.3168 -> 0.3159, -0.0009 (SE 0.0010): a tie. AEF-7 +0.0001
  (SE 0.0001): worse by ~1 SE, tiny. Share squared error on the 3,525 moved cells -3% (SE 1.4%): better. By election: better on
  qld2017 -0.026, sa2018 -0.022, wa2017 -0.010; worse on nsw2015 +0.0065, sa2014 +0.006, nsw2011 +0.0056; 11 of 35 byte-identical.
  My recommendation: ADOPT the rebuilt file (`AUSPOL_BUCKET_SPLIT_SRC=minor-class-shares-resid-v2.csv`): reproducible from committed
  code, a tie on log loss, 3% better on shares. Then add `fit_minor_candidates.R AUSPOL_MC_OWN_RULE=v2` to the rebuild.
  The run overlapped my check_like_ci 10:42-10:47pm and was not harmed (35 of 35 scored).
4. MERGE: PR #195 (dev -> main, 0.4.136) is open and NOT merged, per your CLAUDE.md rule for overnight work. Contents: two new switches, both off
  (statewide endpoint; poll-series class), the two new tests, docs. check_like_ci clean at 1:08am after the last code push (4,989 passed); review 0 Important, and the poll-series commit reviewed separately at 1:10am: 0 Important. Merge on CI green if you agree.
5. HOUSEKEEPING PROPOSAL (nothing deleted; your yes needed): auspol has 68 local branches. 52 have no commit missing from dev
  (checked by patch content, `git cherry dev <branch>`): all `worktree-agent-*` and `worktree-wf_*` branches with 0 unmerged, plus
  census-retire-old-builder-1025, ci-step-timeout-1026, conserve-shrink, cov-tf, fat-tail-cell-error-1026, forecast-on-time,
  ind-overcall-1025, mp-slope-shrink-1025, newind-seatpoll-1026, night-replay-json, night-runner, party-class-fix, seat-spread-tf,
  slim-decisions-1028, surge-live, upper-house-design, upper-house-results, work-5c, zero-order-late. Recommend: delete those locally.
  Keep (unmerged work): departed-rate-fit-1105, fed-breakdowns-trend-1105, prereg-offbranches-1025 (results), the research/ and
  prototype/ branches, fed-timing-resume-fixed and instrument-backtest-fed-timing (queue item, never reviewed), departed-rate-refit
  (superseded by departed-rate-fit-1105; delete after a look), and the 6 worktree-agent branches with 1 unmerged commit each.
  Worktrees removable (branches pushed): .claude/worktrees/deprate-1105, fedbd-1105, wf_068cdb55-fff-2, wf_240a01af-c97-1 (checked 12:10am: no junctions, nothing uncommitted in any of the four).
6. DECISION (lower priority): poll-series class fix, `AUSPOL_POLL_SERIES_CLASS=name`. SA-Best, Katter, UAP and Family First poll
  columns were classed by code and dropped from the backtests' statewide level (sa2018 SA-Best's ~21 points went to nobody). The
  first version tied leaning worse because a class with no series of its own (IND) is re-split from the others bucket by fixed
  ratios; Amendment 1 (post hoc, 1:15am) stops that. Rerun, 7 elections: pooled -0.0026 (SE 0.0040), a tie; AEF-7 subset -0.0074
  (SE 0.0016), better; federal elections -0.007 to -0.010 each; but sa2018 +0.040 (SA-Best got ~14% and won no seat) and
  qld2015 +0.012. At 20,000 sims (3:26am): -0.0028 (SE 0.0038), the same tie and pattern. Recommend: decide the sa2018 question
  (a correct IND level costs seats SA-Best did not win) before shipping; post hoc, so not on this evidence alone.
  Amendment 1 code reviewed 1:40am (0 Important). Design point from the review: with the fix, sa2018's statewide IND level is
  SA-Best's polls alone; other independents stay in the Others remainder. Worth deciding before the deciding run.

## Shipped tonight

- `2cc061fa`: arm `AUSPOL_POLL_SERIES_CLASS` (off) + prereg `plans/prereg-poll-series-class-2026-11-06.md`. FOUND from the Katter lead: the backtest statewide level classifies poll columns by CODE, so KAP, UAP, FF (and SAB) land in OTH and are dropped before the rescale to 100, while their candidates are OTH_RIGHT / IND by full name. sa2018: SA-Best's ~21 polled points went to nobody and Labor/Liberal were inflated 8-9 points each; the arm moves IND +21.25. Also qld2015 OTH_RIGHT +7.5, fed2019/2022/2025 +2.9/+3.0/+1.8, sa2010 +3.1, qld2024 +1.4. Live keeps poll names in `state_mean` (separate path; small for Victoria: UAP, DEM).
- `c94cc074`: NEXT-STEPS under 40k (43,758 -> 39,982 chars). Status block brought current; fixed/closed items moved to DECISIONS; the election-night entry's history moved verbatim to `backlog/journal-2026-11-05-election-night.md` (runbook and every open step kept in the hub).
- `8cf24ad2`: arm `AUSPOL_STATEWIDE_ENDPOINT` (off). CONFIRMED BUG: `statewide_draws_as_at()` read every party at the single latest series date, so a party missing from the newest poll was dropped to 0 and folded into Others. 11 of 32 backtest targets: nsw2023 One Nation 4.6 -> 0 (last poll 12 days out), nsw2019 One Nation 3.9 (6 days), fed2016 Xenophon 3.0 (1 day), qld2017 Katter 1.8 (4 days); also defunct parties (fed2019 Centre Alliance 221 days, sa2018 Family First 548 days). Live already reads per party (`fit_seats_full.R:566`), so backtests and the trees' training levels differ from what ships. On nsw2023 the fix gives One Nation 4.53 against an actual ~1.8, so it is not automatically better: screen pending.
- `44d2c10c` (dev): tests for #194's review nits, `test-poll-date-ours.R` (poll_layer end to end; on/off/default) and the BludgerTrack reader test. Both pass; full check_like_ci clean 12:41am and 1:08am.

## Failed / not done, and why

- DONE 3:40am: the "party" branch is now a tested helper `.statewide_endpoints()` (behaviour-identical: nsw2023 ONP 0 / 4.53 before and after), and the registry note no longer cites a line number. check_like_ci clean, review 0 Important.
- Slips, recorded: pushed R code to dev with PR #195 open before rerunning check_like_ci (12:49am; check ran after, clean).
- GitHub returned a 500 on one push at 3:01am; the retry succeeded.

## Decided on Pete's behalf

- Nothing shipped or merged. Decided only: to build the two bug fixes as off switches, to screen them, and to run the 20k confirmations while the machine was free.

## Still queued

- Review nits from #195: a unit test for the "party" branch of `statewide_draws_as_at()`; the registry note cites "fit_seats_full.R line 566" (will go stale); pre-existing, the fp_parties loop has no finite check on `r$mean[1]`.
- RESOLVED (12:50am-1:00am): the Katter lead became the poll-series class finding (item 5 above): `classify_party("KAP")` by code is OTH, by name OTH_RIGHT.
- LATENT (not live): `wiki_polls()` row self-check is NA when the AE file has no One Nation column (`.ps_implied()` gets NULL), so matched rows would keep AE's numbers and date silently. Every layered region has the column today; NT is never layered. Fix if a region without ONP is ever layered: give `.ps_implied()` a zero for a missing column.

## Log

- 1:08am. check_like_ci clean after the poll-series push (4,989 passed); everything pushed. PR #195 CI starting.
- 3:26am. 20k confirmations done: statewide endpoint -0.0009 (SE 0.0004), confirmed; poll-series -0.0028 (SE 0.0038), tie.
- 3:03am. Machine free: 20,000-sim confirmation runs of both new arms on their affected elections, detached and sequential (statewide endpoint, 11 pairs; poll-series class, 7 pairs).
- 2:59am. Departed-slope deciding run DONE: headline better, one guard fails on noise-sized moves. To Pete (clause override).
- 2:00am. Departed-slope deciding run started on schedule.
- 1:35am. check_like_ci clean after Amendment 1 (4,989 passed); pushed. Amendment 1 code reviewed 1:40am, 0 Important.
- 1:23am. Poll-series rerun with the bucket fix (Amendment 1, post hoc): pooled tie, AEF-7 better, sa2018 worse. To Pete.
- 12:58am. Poll-series class screen: tie leaning worse; sa2018 traced (seat layer does not carry the IND level). Not recommended alone.
- 12:49am. Poll-series class arm built and pre-registered; screen launched (7 pairs). Slip: pushed the R change to dev with PR #195 open before rerunning check_like_ci (CLAUDE.md rule); default path unchanged; check runs after the screen.
- 12:41am. check_like_ci on dev (tests + switch + forecast_mode): 4,989 passed, R CMD check clean. Pre-PR review launched (Sonnet).
- 12:29am. Statewide-endpoint screen done: passes the primary (-0.0007, SE 0.0004). To Pete.
- 12:14am. Bucket split DONE (tie; to Pete). Statewide-endpoint screen launched detached (11 pairs, 1,000 sims, 2 slots); another session's 7.5 GB R job started 12:13am, so 4.1 GB free: messaged it, watching memory.
- 12:05am. Fold bug confirmed and arm built; screen after the deciding runs.
- 11:55pm. 8.7 GB free. Bucket split deciding run RUNNING (70 harness runs, est ~62 min at 1 slot; started 10:30pm).
  Departed-slope pool a1 PENDING for 2:00am. The 12:41 departed run is SUPERSEDED (its task was removed).
