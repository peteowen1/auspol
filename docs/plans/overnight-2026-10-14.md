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
