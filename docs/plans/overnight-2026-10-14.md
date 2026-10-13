# Overnight queue, 2026-10-13/14 (Pete asleep; autonomous)

Pete, 23:5x: "keep working through next steps on dev and making fixes and housekeeping ... if you need me for
something, save it for the morning". Trust does not extend to merges to main, deletes, force-push or secret rotation.

## Queue (in order) -- status updated as I go

1. [ ] Full CI check green (2 warnings fixed: non-ASCII dash in R/poll_source.R regex, broken Rd link in
       hc_candidate_count). Commit test + fixes. Push dev.
2. [ ] Fresh full rebuild at HEAD (35 elections, P4 training, both leak fixes) with AUSPOL_PUBLISH=1, so the release
       matches the code on dev before the 07:00 daily run. Compare against deciding-runs/pooled-backtest-35pairs.csv.
3. [ ] Merge the inputs agent (retirements 8 elections, census 11, Google Trends for the new pairs) when it reports;
       copy its output files into output/; screen or rebuild.
4. [ ] Merge the Tas/ACT polls agent when it reports; rerun the Hare-Clark backtest with polls.
5. [ ] Poll Bludger extraction for wa2001-wa2017 and fed2007 (the stuck agent's other half; never started).
6. [ ] Housekeeping: regenerate DATA/MODEL/POLL registries, SEAT-REGISTRY entries for the worst new seats, update
       PETE-ASKED-FOR, NEXT-STEPS, DECISIONS, ARCHITECTURE (35 elections, Hare-Clark path, thin-cycle estimate).
7. [ ] WA defector carry: wa2017 +0.079 and wa2013 +0.040 worse after the 35-election merge; WA's own earlier cases
       carry 0.693 (Pilbara 0.86). Investigate, no ship without Pete.

## For Pete in the morning (decisions)

- AUSPOL_THIN_CYCLE="1" was published by the NT agent ("Pete to confirm"): thin poll cycles get a previous-result
  baseline updated by each poll's precision instead of being skipped. Touches no cycle with >= 8 polls (proved
  byte-identical on all 24 earlier pairs).
- Hare-Clark candidate-level count: better oracle on the ACT (18/18 from own ballots) but worse forecast log loss
  (1.060 vs block 0.802) because of zero-probability new independents; block count stays default.

## Log
- 00:10 CI green (1938 passed; R CMD check 0/0/3 after fixing a non-ASCII regex dash and an Rd link); dev pushed (f7f475a).
- 00:15 Publishing the rebuild was DENIED while Pete is away (production deploy). Rebuild at HEAD runs WITHOUT publish;
  publish (stage 9, ~1 min) waits for Pete. RISK: the 07:00 daily run uses dev's code with the 18:20 release models.
- 01:01 Rebuild at HEAD started (waited on memory: agents' R jobs).
- 01:05 Tas/ACT polls agent: Tasmania 89 polls (EMRS mostly), ACT 3 polls total. Hare-Clark pooled log loss with polls
  0.601 vs fallback 0.776 vs naive 0.974; tas2021 worse with polls. Sent back to use the thin-cycle estimate for tas2010
  and the ACT, and to diagnose tas2021. Branch worktree-agent-a9cee86a0d479a556, merge after the rebuild.
- Poll Bludger old-WA/fed2007 agent running; inputs agent (retirements/census/Trends) running.
- 01:25 Poll Bludger old-WA/fed2007 pass: 9 new WA polls, 0 federal (posts hold no more as text; wa2001 predates the
  blog). Real blocker: older WA posts give one combined Coalition figure; loader keeps LIB/NAT apart. Agent sent back to
  build AUSPOL_PB_COALITION_COMBINED (off) + measure. Branch worktree-agent-a8315975f4a90c716.
- 01:30 Hare-Clark with thin-cycle polls (96a0478, branch a9cee86a): pooled 0.525 vs prev-only 0.776 vs naive 0.974;
  tas2021 Clark miss = Ogilvie (sitting member changed label), Hare-Clark has no defector handling -> morning item.
- 01:50 Combined-Coalition PB path built OFF (552bc65, branch a8315975): frees 4 WA polls (wa2008 3, wa2017 1); WA
  day-before level MAE 2.558 -> 2.555. Old-WA AEF dependence is a floor (wa2005: 34 of 49 AEF polls predate the blog).
  LEAD: fed2007 takes 1 poll from Wikipedia though an "Opinion polling for the 2007 Australian federal election" page
  exists -- likely a parser miss; check after the rebuild.
- 01:55 CORRECTION to the 01:50 lead: no "Opinion polling for the 2007 Australian federal election" page exists
  (Wikipedia search: only the 2010 polling page and the 2007 election article). fed2007's 180 AEF-only polls need the
  pollsters' own archives (Newspoll history, Roy Morgan archive) -- queued as a fetch job, not a parser fix.
- 01:34 HEAD rebuild died silently in stage 4 (as-at fits, at nsw2023, no error line; agents' R jobs were running,
  cause unconfirmed). Stage 4 wrote only at the end, so 13 min of fits were lost. FIXED (9e1ecf8): checkpoint after
  every target, reuse by input key on rerun. Relaunched from stage 4.
- 01:50 **INCIDENT: a Hare-Clark agent ran `taskkill /IM Rscript.exe`** (kill by name), killing PIDs 42792 and 56328.
  Owners unknown; the timing fits the 01:34 death of my rebuild's stage 4, but another session's job (e.g. pannaverse)
  is possible -- Pete to check. All running agents told: never kill by name.
- 01:55 Inputs merged (ffc523c; scripts only): retirements 8 elections, census 11 (NT packs fetched; 42 LOOKAHEAD
  fallback rows on renamed seats -- decision for Pete), Trends 11 elections / 1,703 candidates (88-98% exactly zero).
  Data copied into output/ AFTER the running rebuild, then one more rebuild.
- 01:55 Hare-Clark defector switch AUSPOL_HC_DEFECTOR built OFF: 8 cases matched on the person (Sue Hickey Clark 2021,
  O'Byrne, Tucker, Jenner, Beswick, Pentland, Kikkert); pooled 0.525 -> 0.496, nearly all tas2021 Clark; act2024 worse
  (+0.059). Small n -> Pete decides. (Earlier "Ogilvie" claim was wrong; data says Hickey.)
