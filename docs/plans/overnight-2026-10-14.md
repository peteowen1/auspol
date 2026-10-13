# Overnight queue, 2026-10-13/14 (Pete asleep; autonomous)

## MORNING SUMMARY (written 05:25)

**Needs Pete, in this order:**
1. **Publish.** Release still has the 18:20 (13 Oct) models. Two ready states:
   - final, with full inputs (salience/census/retirements for the new elections): snapshot
     `output/snapshots/20261014-0448-4e03af5-from1` = what is in output/ now. AEF-7 0.2657 vs AEF 0.2825.
   - without those inputs: snapshot `output/snapshots/20261014-0250-ecc1bb3-from4`, AEF-7 0.2644.
   Recommendation: the full-inputs state (qld2017 0.927 -> 0.602; 2010+ -0.0087 within noise; AEF-7 +0.0013 beyond
   1 SE; nsw2019 +0.026, sa2018 +0.025 unexplained). Command: `AUSPOL_PUBLISH=1 AUSPOL_REBUILD_FROM=9 bash
   scripts/rebuild_forecasts.sh`, then push dev (held back since f7f475a so the 07:00 run saw less new code).
2. **Kill-by-name incident ~01:50**: an agent ran `taskkill /IM Rscript.exe` (PIDs 42792, 56328, owners unknown).
   Check other sessions' overnight jobs. Memory saved so every brief now forbids it.
3. **Decisions** (each built OFF or pending):
   - `AUSPOL_THIN_CYCLE="1"` published by the NT agent: confirm.
   - Census LOOKAHEAD rows (214 rows take a later census for renamed seats): keep or drop.
   - `AUSPOL_HC_DEFECTOR` (Hare-Clark members who change ticket): pooled 0.525 -> 0.496, act2024 worse.
   - `AUSPOL_POLL_ARCHIVE` (Morgan + Newspoll archives): fed2007 AEF polls 185 -> 66; scored effect unmeasured.
   - `AUSPOL_PB_COALITION_COMBINED`: frees 4 WA polls; recommend leave off.
4. **Daily run 07:00**: ran dev's new code against the OLD release; check `gh run list --workflow forecast.yaml`.
5. Cleanup needing approval: ~10 agent worktrees under .claude/worktrees (all merged; several contain JUNCTIONS to
   main's external/ -- remove with `git worktree remove`/rmdir, never rm -rf); `output/` holds 10,112 backtest files.

**Shipped overnight (dev, local):** CI green (1938 tests, R CMD check clean); leak fixes; as-at fit checkpoints per
target (a 01:34 kill had lost 13 min); inputs for the 12 new elections; Tas polls (89, EMRS mostly; ACT 3) and the
Hare-Clark thin-cycle path (pooled 0.525 vs naive 0.974); pollster-archive, combined-Coalition and Hare-Clark defector
switches (all OFF); registries regenerated; NT 2012 empty tcp column fixed; SEAT-REGISTRY entries for wa2013
Churchlands (retired independent + Liberal re-entry), Hillarys, WA 2017 swing seats.

**Failed / not done:** first poll-coverage agent stuck 5 h on setup (replaced); Poll Bludger second pass found
little (posts hold no more); ACT has almost no polls anywhere; Newspoll 2005-07 gaps; wa2017/wa2013 regressions
traced to seats but not fixed.


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
- 02:10 Pollster-archive layer AUSPOL_POLL_ARCHIVE built OFF (625a7ff, branch a2069626): Roy Morgan's table (98 polls
  2004-07) + archived Newspoll PDFs (38) -> fed2007 polls on AEF's numbers 185 -> 66; 132 of 134 matched polls agree
  exactly; 2 disagree and the archive looks right (Morgan Mar 2005: AEF L-NP 44.5 likely double-counts Nationals;
  Newspoll Dec 2006 ALP 46/GRN 5 in two PDFs vs AEF 44/7). Off = byte-identical. Scored effect unmeasured. Agent's copy
  into main was denied by the permission check; the CSVs come via the branch merge instead. It also disclosed a
  `taskkill /IM python.exe` (only its own downloader was running). Empty dir left: external/reference/polls/archive.
- 02:52 HEAD rebuild done (snapshot 20261014-0250-ecc1bb3-from4): leak fixes vs pre-fix 35 run, sqrt-votes +0.0002
  everywhere, none worse > 0.02. AEF-7 0.2644 vs AEF 0.2825.
- 03:00 Merged into dev: Hare-Clark polls/thin-cycle/defector, combined-Coalition, pollster archive (1960 tests pass).
  Inputs data brought into output/ (backups deciding-runs/inputs-backup-20261014).
- 03:05 Final rebuild: memory gate never opened (5.0 GB free, 6 needed); ran on 1 slot. Claude Code's memory guard
  killed its wrapper shell at ~03:08 but the runner survived (orphan); watched the log. Done 04:48 (snapshot
  20261014-0448-4e03af5-from1): AEF-7 0.2657; qld2017 -0.324; nsw2019 +0.026, sa2018 +0.025.
- 05:00 Registries regenerated (poll registry: 2,965 polls, AEF's numbers on 712; final 30 days 286, AEF's on 20).
  Data dictionary failed on NT 2012's empty tcp column -> fixed at the source.
- 05:15 Worst seats in the regressed elections recorded in SEAT-REGISTRY (Churchlands measured).
