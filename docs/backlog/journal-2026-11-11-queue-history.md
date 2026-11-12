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
