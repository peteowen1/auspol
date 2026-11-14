# Queue item text moved verbatim from NEXT-STEPS.md (11 Nov 2026, wrap-up)

- OPEN, unblocked 9 Nov (reuse fix on main): `AUSPOL_POLL_SERIES_CLASS=name` (SA-Best, Katter, UAP, FF classed by full name). 20k on 7 pairs a tie
  (-0.0028, SE 0.0038); sa2018 +0.037 of which Morphett +0.031. `plans/prereg-poll-series-class-2026-11-06.md`, last section.
  Pete 10 Nov 11:10pm: "Run all 35". Deciding run scheduled 11:20pm (code 049ebc10, 20k, all pairs):
  `deciding-runs/20261110-2310-poll-series-class-all35/` FAILED 12:20am: all 70 harness runs failed in 17-228 s and
  the cleanup deleted their logs (fixed, 636da0e2). A 200-sim snapshot run passed, so likely memory (two feed parses
  and the test suite ran beside it); UNCONFIRMED. RETRY scheduled 6:00am 11 Nov, after the night-pair job:
  `deciding-runs/20261111-0027-poll-series-class-all35-retry/`. Done when its DONE marker is read and the prereg's standard
  rule applied; ship (published_flags "name" + inline default) only on a pass.

- OPEN, NIGHT MODEL (before 28 Nov). DONE 31 Oct: surge fade ON, flow floor 0.01, median ON, surge mixture OFF;
  surge-off replays settle it (Wentworth 2022 called 7:45pm with no patch; median within 0.001 on all three nights).
  Still wrong: draws with a different final pair are never corrected (Monash 2025; traced 10 Nov, fix proposed, not
  built: `reviews/night-final-pair-2026-11-10.md`; Melbourne 2025 is the AEC's own pair being wrong). BUILT 11 Nov,
  off: `pair_r` (0e621c04, prereg `plans/prereg-night-pair-trust-2026-11-11.md`); detached replay job
  `deciding-runs/20261111-0020-night-pair/` (starts after the poll-series run; reads R/ from this checkout, so no
  R/ or scripts/ edits until its DONE). Review 11 Nov 12:15am (Sonnet): 0 Important. Nits to do after the job: spread
  donors evenly over `hit` rather than cycling; document that `pair_r < 0.5` moves nothing. Mirani qld2024: counted pair right (Kelly v Andrew) and used, still wrong:
  a flow problem, untraced. Statewide draws
  shrink by the national mean counted, not the seat's; projection sd floors at 0.26.
  Fix 2 (`--tcp-own-fp`, each draw's flow from its own primaries) built, OFF: mixed on three nights; needs flow
  uncertainty in the draws, and `plans/prereg-flow-sd-2026-10-31.md` REFUSED that 31 Oct.


## Moved from NEXT-STEPS 2026-11-12 (TCP vs AEF item, verbatim)

- OPEN 7-8 Nov, TCP error vs AEF (Pete): NSW exhaustion SHIPPED (`plans/prereg-nsw-exhaust-tcp-2026-11-07.md`); ledger
  TCP headline scores both sides on the SAME seats: 3.654 vs AEF 3.727 (n 667), goal met (PR #205). 8 Nov on dev
  (PR #206): C++ engine applies exhaust (NSW stage 6 ~65 -> 11 min); exhaust rates made time-forward (leak fix,
  `AUSPOL_NSW_EXHAUST_TF`). nsw2011/2015/2019 now get no exhaustion from the anchor (no earlier rates); measured rates
  from NSWEC's pages (`scripts/build_nsw_exhaust_measured.R`, all 2015/2019/2023 pages ARE cached) are the off arm
  `AUSPOL_NSW_EXHAUST_SRC=measured` (+ `_MEAS_MAJORS=0`), SHIPPED 8 Nov. fed2025: seat flow persistence SHIPPED 8 Nov
  (`plans/prereg-seat-flow-persistence-2026-11-08.md`; fed2022/25 TCP -0.12 each, older federal worse). Its inputs are
  FROZEN in git; states not built (need state TCP histories).
  Low priority, pre-existing: `fit_nsw.R`/`fit_federal.R`/`fit_vic.R` read same-year flow rows; they feed no backtest.
  OPEN, pre-existing (review 8 Nov): `AUSPOL_REBUILD_ONLY` reuse (`reuse_check()`, `rebuild_forecasts.sh`) checks file age, not
  flags, so after a switch flip a rebuild that skips the affected harness silently reuses its old-config results.
  FIXED, on main since PR #211 (9 Nov): the fingerprint drops run-control vars (eb0a628f); the first REBUILD_ONLY after
  it reuses nothing (old tags). PARKED, same area: `apply_upset_floor.R` fits only files newer than
  `AUSPOL_STAGE6_START`, so under REBUILD_ONLY the upset-floor fit drops every reused election. INERT (checked 10 Nov):
  `AUSPOL_UPSET_FLOOR="0"` (`published_flags.R:324`), so stage 6b never runs. Trigger: fix before that switch is ever
  turned on. The fix must keep reused files' raw copies (stage 6 `rm -rf output/upset-floor-raw`; reused files are
  already mixed in place) and refresh a rerun file's raw copy when it is older than `AUSPOL_STAGE6_START`.

## Closed 13 Nov 2026 (moved verbatim from NEXT-STEPS)

- OPEN, SHIPPING 13 Nov: council-history coverage fix. Rebuild DONE 6:24am (`output/snapshots/20261113-0622-d938ce20-from3`),
  both guards PASS, live clause breached (up to 5.3 points, all from the retrained trees); Pete: "Ship it" (DECISIONS 13 Nov,
  prereg amendment 1). Next: review + check_like_ci, PR dev -> main, merge, stage 9 publish; done when the daily run is green.
- OPEN, check after the NEXT STAGE-9 PUBLISH (not the daily run: it downloads the 9 Nov `seat-poll-blend-vic2026.csv` from
  the shipped-models release, which still has the old Pakenham row; checked 12 Nov): Pakenham seat poll corrected 12 Nov. Fieldwork 4-8 Nov (Poll Bludger), and its client was
  the typo "TKR", which filed a Herald Sun poll as stakeholder-sponsored (`direct_stake`); now `direct_indep` via a `poll_methods.csv`
  row. Before (R2 `seat-probs-vic-2026.csv`, 12 Nov 8:49am): ONP 0.829, LNP 0.161, ALP 0.005. Done when the first file after that publish is compared and the move reported. The hand-keyed rows are
  permanent: Wikipedia's vic2026 page lists only Hawthorn (checked 12 Nov). Roy Morgan's 21-26 Oct SMS poll of Bass/Hastings/
  Morwell/Pakenham (release 10371) gives no per-seat primaries, so it cannot be keyed. Since 12 Nov the rebuild's stage 9 runs `fetch_seat_polls.R
  --refresh-live` before promote, so a new Wikipedia vic2026 seat poll ships with the next publish (old page copies kept, dated).
- OPEN, LIVE GAP found 12 Nov: the published vic2026 forecast uses NO candidate salience (`XG5! no salience corpus yet` in
  every live log since 27 Oct; `output/salience-v6.csv` has 0 vic2026 rows; CI never had the file). Fix built, unmerged:
  branch `salience-vic2026-link` (0646dbc8, worktree `C:\dev\auspol-wt-salience`, rank-mapped per DECISIONS 2026-11-12).
  With/without DONE and walked 12 Nov; Pete: ship now (DECISIONS 2026-11-12; `reviews/salience-vic2026-live-walk-2026-11-12.md`).
  Review round 1 (Sonnet, 12 Nov): 1 Important, PRS1 warned and published anyway; FIXED d3649546 (stops; daily run now
  errors without the asset), tested on 4 broken inputs. Round 2 (Sonnet, 12 Nov 10:55pm): 0 Important, gate passed;
  nit: the mtime check misses a later append to `salience-v6.csv` (`fetch_salience_v6_remaining.sh`), a snapshot-date
  match would be sturdier. ORDER on 13 Nov: merge the branch into dev after the rebuild
  scores, `Rscript scripts/link_vic2026_salience.R` here (same 11 Nov jump file as the walk), main PR, then stage 9
  AT ONCE: until stage 9 uploads `salience-v6.csv`, the daily run on main fails by design. Done when merged,
  stage 9 prints `PRS1  ... 663 vic2026 rows`, and the next stage 9 prints `PRS1` with vic2026 rows. Worktree has
  junctions under `external/`: unlink them before removing it.
  THEN, before the final 25-27 Nov snapshot: fix the coarse anchor link (linked values in ~5 steps of 0.0607; review file
  above), rerun the with/without.

## Moved from NEXT-STEPS 14 Nov 2026 (closed items, verbatim)

- **Status 12 Nov, 9:50pm.** main at 0.4.160. dev is 14 commits ahead, unmerged on purpose: council coverage (CH3 names,
  per-council coverage, Qld 2008, stale overlap rebuild), night replay settings check (NRC3), seat-poll `--refresh-live` and
  hand-keyed dedup. They go to main in one PR after the 13 Nov rebuild scores (item below). Round-2 review of the seat-poll
  fixes (f4a3cbff..db6e0637, Sonnet, 12 Nov 9:10pm): 0 Important, so the gate is passed. Rebuild PENDING for 11:30pm
  (needs 8 GB free; at 9:36pm 1.7 GB, other verses' R jobs). Pete to send the VEC draft (Gmail, "RE: State Election 2026
  results data feed"): it asks whether the voting-centre pages fill in during the count.
- DONE 13 Nov: vic2026 salience is in the published forecast (PR #230; stage 9 `PRS1 ... 663 vic2026 rows`; daily run 9:25am
  green with `XG5 salience corpus found for vic2026: 526 of 616`). The coarse anchor scale is fixed: ladder link published 13 Nov
  (PR #231, stage 9 2:59pm, forecast run 3:34pm green, XG5 546 of 616; DECISIONS 13 Nov). Full item in `backlog/journal-2026-11-11-queue-history.md`.
- DONE 13 Nov (first `poll-feed-check` run: 23 of 26 AusPoll polls in the anchor, Pakenham hand-keyed): the Greens' ORU Vic
  poll (14-26 Oct) is not in the anchor but IS in the trend at full weight through the layered Wikipedia scrape (Pete, 13 Nov:
  keep it at full weight; sponsor correction was refused 4 Nov). Same check found Lighthouse's 19 Oct-1 Nov Vic poll counted
  TWICE ("Lighthouse/Growth Intelligence Centre" unpaired with "Lighthouse"): alias added; only vic changes (640 -> 639 rows).
- DONE 13 Nov: the SPF1 seat-poll guard has an override: `Rscript scripts/fetch_seat_polls.R --refresh-live --accept-fewer`
  (the stop message names it). Tested on a scratch copy with a planted extra poll: stops without the flag, accepts with it,
  the next plain refresh passes. DONE 14 Nov, same area: an NA pollster in a scraped row with primaries errored the
  hand-keyed dedup (`if (any(dup))` on NA); now no match (`na.rm`), with a test that failed before the fix.
- DONE 13 Nov: council-history fix (PR #229, stage 9 8:34am, daily run 9:10am green; Footscray now GRN 0.519) and the
  Pakenham seat-poll correction (published ONP 0.829 -> 0.888, LNP 0.161 -> 0.104, ALP 0.005 -> 0.004; poll fix plus new
  trees). Full items moved to `backlog/journal-2026-11-11-queue-history.md`.
