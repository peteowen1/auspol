# Overnight 4-5 Nov 2026 (Pete asleep; working the queue on dev)

Times are Sydney. Updated as I go; the morning summary is the top section.

## Needs Pete (morning)

1. **Narracan booth history for election night.** Narracan has no 2022 booths (its poll was the 28 Jan 2023
   supplementary), so on the night every Narracan booth is "new" with no swing. The supplementary is not a like-for-like
   base: it had NO Labor and NO Nationals candidate (Liberal 16,741, Greens 4,132, IND Wolfe 4,110, DLP 2,641, Freedom
   2,254, One Nation 2,246; final two Liberal 62.9 v Wolfe). Choices: (a) 2018 Narracan booths as the reference (both
   majors stood, but before the 2021 redistribution), (b) the 2023 booths for the parties that stood only, (c) leave them
   "new". Raw pages saved: `external/reference/vec/2022/booths/narracan-supp2023-{fp,2cp}.html`. My pick: (a), matched by
   booth name, since the night swing is Labor minus Coalition.
2. **Your email address is in the User-Agent of eight fetch scripts, and the daily CI run sends it to Wikipedia.**
   I found this while flagging my own slip (the curl for the two VEC pages sent "auspol research (fptpost@gmail.com)"
   to vec.vic.gov.au). The committed ones: `fetch_statewide_poll_samples.R:41` (CI runs it daily, `forecast.yaml:291`),
   `fetch_seat_polls.R:60`, `fetch_poll_breakdowns.R:59`, `fetch_demosau_crosstabs.R:27`, `fetch_pollbludger_tracker_polls.R:41`,
   `fetch_retirements.R:30`, `fetch_abc_vic2026_candidates.R:54`, `fetch_wikipedia_preelection.py:34`. Wikipedia asks
   for a contact in the User-Agent, and a URL works. Choices: (a) swap the email for
   `https://github.com/peteowen1/auspol` in all eight (one small PR); (b) keep it. My pick: (a). Until you say, I am not
   running any of them (so the federal breakdowns refresh below waits).

3. **The others-bucket split every harness uses cannot be rebuilt from committed code, and is stale.**
   `AUSPOL_BUCKET_SPLIT=cand_naive` reads `output/minor-class-shares-v2.csv` (`published_flags.R`,
   `candidate_bucket_ratio()`). That file is byte-identical to the 28 Sep 15:42 run's `minor-class-shares-resid-v2.csv`;
   `scripts/rebuild_forecasts.sh` never runs `fit_minor_candidates.R`, and the one committed version of that script
   (29 Sep) already has the v3 defector rule, so the v2 file is not reproducible. It predates the 25 Oct LDP
   reclassification and the 1 Nov sa2026 absent-vote fix. Live vic2026 is unaffected today (no vic2026 rows, so the
   live run falls back to the 2022 mix, `FST1!`), but that means live and backtests split the bucket differently.
   Choices: (a) recover v2 as a named arm in the script (`AUSPOL_MC_OWN_RULE=v2`), regenerate it, add it to the rebuild
   and give it vic2026 rows after nominations (live = backtest); (b) switch the split to v3 (committed) with a screen.
   My pick: (a) first, so what ships is reproducible, then (b) as its own screen.
   (The 1 Nov audit of inputs built outside the rebuild likely saw this one and filed it as a false alarm, "a first
   commit after its first run": the commit came after the run, but it also changed the rule. Not confirmed which file
   that audit meant.)

## Done overnight
- **FIXED: the vic2026 search-interest anchor was the wrong Premier** (`0db2b2e7`). Both salience scripts anchored on
  Jacinta Allan; Ben Carroll has been Premier since 28 Jul 2026 (our own `leaders.csv`). Allan's series peaked at 100 that
  week and sat near 1 from September, so 0 of 101 batches could be linked on the 26 Oct and 4 Nov snapshots. Against
  Carroll: 100 of 100 batches link, 374 of 500 candidates on the common scale. The 4 Nov snapshot is saved as
  `output/vic2026-salience-jump-2026-11-04.csv`; `output/vic2026-salience-jump.csv` (the 27 Oct, unlinked one local
  runs read) is untouched. Every other leader record already had the change right (`leaders.csv`, `retirements.csv`).
  For you: the final 25-27 Nov snapshot will now link; whether local runs should take the 4 Nov file before then is
  your call (CI has no salience corpus either way, and the surge path is off).

- Doc-audit sentinel (#109, 3 Nov run): the four still-drifted citations now name functions (`83d08209`); the other five
  were already fixed; its CONSTANTS:646 "value differs" is a false alarm (3 earlier elections = 3 pairs).
- Flows queue item narrowed (`b56f2032`): the federal Greens->Labor estimate running 3-7 points above the AEC is the
  estimator's known bias (failed its bar 13 Oct) and reaches no published forecast; federal flows come from the AEC.

- Staleness audit of the published path (42 `output/` files `fit_seats_full.R` and `R/` read): 9 have a builder committed
  after the file was written. Checked each diff: only flagged-off changes (`AUSPOL_SITTING_MEMBER_ADJ`, `AUSPOL_STATE_POLL_EXTRA`,
  the departed width arm) or the 9 Oct check-code rename. The bucket split (item 3) is the only live case.
- Queue corrected where it contradicted recorded results: seat-margin arm (refused 28 Sep), zeroed-party revival
  (measured and refused 18 Oct), HTV recency (shipped 1 Nov), surge v4 (superseded: surge off), the post-xgb corrections'
  inputs (already this run's), LDP class (live since 1 Nov).
- Value-odds page republished with the 4 Nov prices: https://claude.ai/artifact/GdrpxSB7zkY1xEvJvU3TKx (its readiness
  checklist is still the hand-written 28 Oct text, and says so).
- WA 2017 seat-layer lift partly traced (queue item): level 36.4 -> base_pred 38.9 -> xgb 41.7 -> published 41.3 Labor,
  actual 41.9; no bias by previous-share band; the misses are five seats (Southern River, Geraldton, Bunbury, Wanneroo,
  Kimberley) under-called by 8-12 points of swing.
- Queue notes added: the "52 re-stand cases" have no recorded definition; the statewide draw-width check needs the
  harnesses to write their draw quantiles first.
- Data registry regenerated (`14f55eba`). Model and poll registries regenerated (`f453b62b`): four switches built
  1-2 Nov had no classification (MR2!), now recorded; the poll registry picks up 4 new vic2026 polls.
- VEC feed-access email (due 4 Nov): still not in Gmail (all folders incl. spam) or Hotmail as of ~5am 5 Nov.
- Federal state breakdowns stop at 6 Oct and CI cannot refresh them; fix written into the queue (NEXT-STEPS, "federal
  breakdown poll page"), not built because it needs the fetcher (item 2).

## Not done, and why

- Narracan booth history (item 1) and the bucket split (item 3): your decisions.
- MP-slope tau^2 review nit: touches old backtest targets only (qld2015, sa2014, vic2014; vic2026's tau^2 is 0) and
  needs its own screen; left.
- Stray worktree `.claude/worktrees/wf_240a01af-c97-2` (branch `ind-overcall-1025`, fully merged, no junctions inside):
  safe to remove with `git worktree remove`; left for your yes since it deletes a folder.

## In flight

- Waiting for the 4:30am daily forecast run on main (first one with the MP-slope tables PR #187 merged); result below.
