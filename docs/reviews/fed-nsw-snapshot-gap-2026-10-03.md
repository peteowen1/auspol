# Why fed and nsw2019 do not reproduce the v61 snapshot (read-only, 2026-10-03)

Question: a hand run of `scripts/backtest_candidate_fed.R` (7 pairs) and
`scripts/backtest_candidate_nsw.R` (`AUSPOL_NSW_PAIR=2019`) on dev at published defaults differs
from `output/snapshots/20261003-0143-48f0233-from6` (fed2010 293 of 1,050 cells, fed2022 933 of
1,057, nsw2019 455 of 651), while vic, sa2022, qld2020 and wa2013 match exactly.
Nothing here ran R, a harness or a rebuild. Sources: the harness and R/ files, the snapshot's
own `rebuild-forecasts-logs/s6_*.log`, file metadata, one small Python read of two CSVs.

## Answer in three lines
1. **Most likely cause (high confidence, not yet confirmed by a run): the snapshot ran fed and
   nsw with `AUSPOL_SALIENCE_EXPECTED=0` and `AUSPOL_SALIENCE_EXP_SD=0`; a hand run runs them at 1.**
   Both harnesses set those two switches to 1 at the top, but only `if` the caller has not
   set them. `rebuild_forecasts.sh` exports every published flag first, and the published value
   of both is "0", so the harness-scoped default never fires in a rebuild.
2. No input file changed after the snapshot except `output/candidacies.csv`, which is already
   ruled out. No clock dependence reaches these pairs.
3. Cheapest test (not run): re-run nsw2019 with the two switches forced to 0 and diff against
   the snapshot (command below). Expect 0 differing cells.

## The mechanism, with the lines
Federal harness, `scripts/backtest_candidate_fed.R:78-79`:

    if (!nzchar(Sys.getenv("AUSPOL_SALIENCE_EXPECTED", ""))) Sys.setenv(AUSPOL_SALIENCE_EXPECTED = "1")
    if (!nzchar(Sys.getenv("AUSPOL_SALIENCE_EXP_SD", ""))) Sys.setenv(AUSPOL_SALIENCE_EXP_SD = "1")

NSW harness, `scripts/backtest_candidate_nsw.R:41-42`, identical. The comment above them says
the default is ON "here and in backtest_candidate_fed.R only" and "NOT set in published_flags.R"
because the switch makes Queensland, SA and Victoria worse. vic, sa, qld and wa have no such
lines (grep of all six harnesses; `scripts/backtest_candidate_{vic,sa,qld,wa}.R` only read the
switch, default "0"). That is exactly the set that reproduces.

Published value, `scripts/published_flags.R:62,64`: both "0".

The rebuild exports published flags into the environment before any harness starts
(`scripts/rebuild_forecasts.sh`, the `PUBFLAGS=$(Rscript scripts/export_published_flags.R)` /
`eval "$PUBFLAGS"` lines; `scripts/export_published_flags.R:10`). The snapshot logs prove the
switches were set to 0 in the fed and nsw runs:

    s6_fed.log   HD0 published defaults applied to 0 unset switch(es)
    s6_fed.log   HD1 caller set 114 switch(es): ... AUSPOL_SALIENCE_EXP_SD=0 AUSPOL_SALIENCE_EXPECTED=0 ...
    s6_nsw_2019.log   same, both 0

A hand run exports nothing, so lines 78-79 / 41-42 set both to 1, and `harness_defaults.R:23`
(`.caller_set`) then reports them as caller-set.

What the switch changes (point estimate, so it reaches `sharedetail`):
- `scripts/backtest_candidate_fed.R:1750-1751` and `scripts/backtest_candidate_nsw.R:933-935`
  pass `expected = .exp_mode > 0L` to `blend_salience_shares()`.
- `R/salience_surge.R:424-429`: with `expected = TRUE` every (seat, party) in
  `hz$seat_party_expected` is floored at its salience band's mean
  (`pmax(shares, exp_pcv)`); with FALSE the hazard blend `surge_blend_estimate()` runs instead.
- `EXP_SD=1` additionally builds `salience_sd_matrix()` (fed:1757, nsw:943), sim spread only.

Why the pattern fits (numbers from the snapshot logs):
| pair | what the snapshot logged | consistent with the gap? |
|---|---|---|
| fed2007 | no hazard line at all (no salience corpus before 2010) | yes: 0 differing cells |
| fed2010 | `BF0v ... blended toward surge_mu for 0 (seat,party) cells` | yes: with OFF nothing moved; ON floors every governed cell, so cells differ |
| fed2013 | blended for 0 cells | same |
| fed2016 / 2019 / 2022 / 2025 | blended for 633 / 388 / 422 / 261 cells | differing cells grow as the corpus grows |
| nsw2019 | `BT0b salience point estimate applied to 216 (seat,party) cells` | yes |
| vic, sa, qld, wa | harness has no override | yes: 0 differing |

## Candidate inputs read by fed or nsw and not by vic/sa/qld/wa
Columns: input, where it is read, file mtime, and whether it is newer than the snapshot
(2026-10-03 01:43:51; earlier snapshot 01:15:58). All times +1000. "Newer" is by mtime only;
see the caveat below.

| input | read at | mtime | newer than 01:43? |
|---|---|---|---|
| `external/elections/aec-fed-{firstprefs,transfers,winners}.csv` | fed:445-447 | 09-07 23:05 | no |
| `external/elections/nswec-*-nsw-*.csv`, `nswec-nsw-{transfers,winners}.csv` | nsw (PREF) | 09-07 13:25-13:34 | no |
| `external/elections/{ecq-qld,waec-wa,ecsa-2026-sa}-transfers.csv` (pooled flows, `AUSPOL_QLD_FLOWS`, `WA_FLOWS`) | R/external_flows.R:79-89 | 08-22 | no |
| `output/projection-mix.csv`, `output/projection-data.csv` (forecast mode) | fed:216, R/fundamentals_tf.R:136 | 09-20 01:16 | no |
| `output/notional-baselines.csv` | fed:684 | 09-13 17:59 | no |
| `output/state-deviation-features.csv` (fed only) | R/state_deviation.R:203,269; R/state_poll_pool.R:55 | 10-02 23:39 | no |
| `external/reference/polls/seat-polls/seat_polls.csv` | R/seat_poll_blend.R:28,189 | 09-30 12:41 | no |
| `external/aus-polling-analyser/analysis/Data/poll-data-{fed,nsw}.csv` (clone HEAD 1d60706, 09-25) | R/load_polls.R | 09-28 00:06 | no |
| `external/reference/byelections/byelection-{results,winners}.csv` | R/byelection_prior.R | 09-19 | no |
| `output/salience-v6.csv` (read only if `AUSPOL_IND_SALIENCE=1`; published 0), `salience-hazard.csv` (v1 only) | fed:1154, 280 | 09-10, 08-26 | no |
| `output/candidacies.csv` | R/candidate_returns.R, R/xgb_primary_override.R:48 | **10-03 17:14** | **yes** (see below) |
| `output/xgb-primary-asat-predictions.csv` (all six harnesses) | R/xgb_primary_override.R:30, R/seat_predictions.R:17 | 10-02 19:22 | no |
| `output/xgb-flows-v1-asat-*.model`, `xgb-flows-asat-manifest.csv` | R/xgb_flow_override.R:16 | 09-19 / 10-02 19:22 | no |
| `output/cache/fundamentals-tf/129fa18eb76cbed8/*.txt` (disk cache outside the build) | R/fundamentals_tf.R:68 | 10-02 12:16 | no |
| `output/mp-slope-by-target.csv` (all harnesses) | fed/nsw/others | 09-13 07:47 | no |

Git: `git log --since=2026-10-03T01:00 -- data inst R scripts DESCRIPTION NAMESPACE src` returns only
`90d0ba4` (01:26), `87d7f23` (01:16), `ca788a4` (01:08), all BEFORE the snapshot run
(rebuild marker 01:36:02, fed harness wrote 01:40:51). Nothing tracked in R/ or scripts/ changed
after; the only working-tree change is the uncommitted `scripts/build_candidacies.R`. `data/`,
`inst/` and `R/sysdata.rda` do not exist in this repo. Nothing in fed/nsw reads `tempdir`,
`~/.cache`, `rappdirs` or `piggyback` (grep of R/ and both scripts).

Files newer than 01:43:52 anywhere in the repo outside `.git`, `.claude/worktrees` and
`snapshots/`: `output/candidacies.csv`, two `output/snapshots-candidacies-*.csv` copies, scripts
`build_candidacies.R` and `fetch_abc_vic2026_candidates.R`, and `external/reference/abc-vic2026/*`.
No library under `win-library/4.5` that fed/nsw use changed after 10-02 12:00 (only owidR/owidapi).

### candidacies.csv, checked directly
`output/snapshots-candidacies-20261003-pre-abc.csv` (25 columns, 18,172 rows) against the
current file (29 columns, 18,294 rows): every non-vic2026 row is identical (17,793 of 17,793
matched on election, seat, name, raw party; 0 differ on the 25 shared columns). The only
difference is vic2026, 379 -> 501 rows. UNCONFIRMED: that the pre-abc copy equals the file the
snapshot run read (no copy from 01:43 exists). It agrees with the earlier nsw test.

## Clock dependence: none reaches these pairs
`Sys.Date()`/`Sys.time()` in R/: `flow_model.R:93,122,182` (`as_of` defaults, compared with past
election end dates), `freshness.R:25,61`, `load_polls.R:70,190` (sanity bound `+14` days),
`paths.R:101`, `tune.R:68,84`. None is used in the harness bodies. All fed/nsw pairs are
historical, so `cycles$end <= as_of` is TRUE for every target on any date after 2025; the
snapshot (10-03 01:43 local) and a rerun later that day share the calendar date anyway.
Even if R used UTC the date would only straddle 10-02/10-03, with no event in between.
The harness RNG is `set.seed(SEED)` (fed:1785, nsw:885) and only feeds the simulation; the point
estimate in `sharedetail` is deterministic.

## Ruled out by data (so they should not be re-tried)
- **As-at xgb predictions file.** It differs between the 00:13 from3 snapshot and `output/`
  (md5 `164227...` vs `cf5e53...`), but in the fed2010 and fed2013 rows the two files are
  identical (1 of 1,050 and 0 of 1,050 rows differ), and fed2010 still differs 293 cells.
  The file's mtime (10-02 19:22) equals the 19:30 snapshot's copy.
- **Pair subset.** The user already ran 7 pairs.
- **Flow-model files, as-at manifest, cache.** All older than the snapshot; the cache values
  match the snapshot log (fed2007 47.66, nsw2019 51.56).

## Caveat: the mtime audit is blind to `restore_snapshot.sh`
`scripts/restore_snapshot.sh:20` copies with `cp -p`, which keeps the OLD mtime. Restores ran
at 10-03 00:17 and 00:38 (`output/.unrestored/20261003-001706-*`, `-003836-*`). A file put
back by a restore after 01:43 would look old. This does not change the answer above, which does
not depend on any file, but a "no input changed" statement is weaker than it sounds. The
file-independent fix is to compare content hashes against a snapshot (not available for inputs).

## Cheapest single test (a command; NOT run)
Force the two switches to the value the snapshot used and re-run the smaller harness
(about 80 s by the snapshot's own timings, 01:40:51 to 01:42:09 for nsw 2019):

    AUSPOL_SALIENCE_EXPECTED=0 AUSPOL_SALIENCE_EXP_SD=0 AUSPOL_NSW_PAIR=2019 \
      Rscript scripts/backtest_candidate_nsw.R > /tmp/nsw2019-sal0.log 2>&1

Pass: `grep '^BT0b' /tmp/nsw2019-sal0.log` reads `applied to 216 (seat,party) cells`, and the new
`backtest-nsw2019-sharedetail-*` file has 0 differing cells against
`output/snapshots/20261003-0143-48f0233-from6/backtest-nsw2019-sharedetail-*`. Fail (cells still
differ): this cause is wrong or incomplete.

Free, even faster, no run at all: in the hand-run log, `grep -m2 '^HD' <log>`. If it reads
`caller set 2 switch(es): AUSPOL_SALIENCE_EXPECTED=1 AUSPOL_SALIENCE_EXP_SD=1` (the snapshot
reads 114 and `...=0`), the mechanism is confirmed as the difference in configuration; and
`grep '^BF0v\|^BT0b'` will show cell counts that differ from the snapshot's (fed2010 0,
fed2016 633, fed2022 422, nsw2019 216).

## What is NOT confirmed
- That this switch alone accounts for all 293 / 933 / 455 differing cells. The mechanism
  predicts the direction and the pattern; the counts were not reproduced.
- Which configuration "ships" for fed and nsw backtests. As written, a rebuild scores them OFF
  and a hand run scores them ON, so the pooled scoreboard and AEF-7 ledger carry the OFF
  numbers while the harness comments describe ON. That is a decision for Pete, not made here.
- The location the hand runs were launched from. The zero-order prereg says they ran from a
  worktree with `output/` and `external/` symlinked to main; the symlinks make the inputs
  the same files, so this does not affect the result.
