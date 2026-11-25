# Queue history moved out of NEXT-STEPS.md on 25 Nov 2026 (verbatim, newest first)

## Moved 25 Nov 10:20pm: 25 Nov morning checks (done) and the superseded #1262 note

- OPEN, DATED 27 Nov (evening) and 28 Nov (morning): save the VEC early and postal vote spreadsheet again, raw, into
  `external/reference/vec-early-vote-2026/` (link on https://www.vec.vic.gov.au/voting/2026-state-election/voting-statistics;
  one copy saved 24 Nov; cumulative, 88 districts per day from 7 Nov, verified). The 28 Nov copy is the final pre-poll count. Early-vote screen:
  `scripts/screen_early_vote.R`.
  **DATED 25 Nov (first thing): the early-share Labor correction went live-pending 24 Nov 7:09pm** (PR #274 merged;
  `demo-resid-vic2026.csv` on the `shipped-models` release replaced by hand, DECISIONS). Check the 4:30am forecast run:
  (1) its conclusion is success; (2) its log has `DR1  demographic correction ON for vic2026 from demo-resid-vic2026.csv
  (176 of 176 rows matched)`; (3) against the 24 Nov run, Labor's win chance moves in the walked seats (Monbulk up,
  St Albans and Greenvale down, Ringwood near even) and the hung-parliament figure moves by under 1 point. Then tell
  Pete, and update thread 1's numbers in the Victoria Forecast Thread artifact if they changed. ROLL BACK with
  `gh release upload shipped-models docs/reviews/early-vote-scouts-2026-11-24/demo-resid-vic2026-BEFORE-23nov-release.csv#demo-resid-vic2026.csv --clobber`
  (check the `#name` form uploads under the right name before relying on it; else copy the file to that name first).
  SAME MORNING, after that run: (4) its log shows `WIS2 wrote output/whatif-sims-vic2026.json` and `OK whatif-sims-vic2026.json`
  (PR #275), and https://pub-ee4bf5b599a047f9ac2b9facc1587008.r2.dev/auspol/whatif-sims-vic2026.json returns the file with
  `majority` 45 and a `built_at`; then MESSAGE THE ITG SESSION that it is on R2 (ITG merges its page
  `/politics/vic2026/what-if-primaries.html`, on its dev at 134d5307, after that and after Pete's launch). (5) Refresh
  posts 1-4 and the three early-voting charts in the Victoria Forecast Thread artifact from the new VEC file (after
  8:30am), and thread 1's numbers and four charts if the forecast moved. (6) Upper house, for release Thu 26 Nov: simulated walk
  DONE 24 Nov and Pete said the region tables look good (`plans/upper-house-forecast-walk-2026-11-24/sim.R`, `sim-output.txt`,
  `council-forecast-vic2026.json`; ITG has the JSON shape). LEFT: move sim.R into `scripts/` and the daily run with an R2
  upload (review gate), test the count against a real ticket-free count (a Senate contest), tell ITG the R2 key.
  (7) Seat TCP per what-if scenario: MERGED 25 Nov 9:15am (PR #276, `final_two` per scenario in scenario-vic2026.json;
  ITG built its column against it). ON R2 since run 45500128541 (Pete OK'd; built_at 2026-11-24T22:55:01Z, 9:55am): CSC9
  72 of 72, CSC7 0 of 88 differ on all four parties; ITG told, checks its live page. Still open from the same ask: `flows_to_labor` in scenario-vic2026.json; `n` on each `polls` row of
  vic-page-data.json.
  4:30am run 25 Nov (45449335210) CHECKED: success; `DR1 ... (176 of 176 rows matched)`; WIS2 + `OK whatif` and the R2 file
  has majority 45 and built_at. (3) CHECKED: Labor win chance Monbulk 0.24 -> 0.29, St Albans 0.635 -> 0.513, Greenvale 0.463 -> 0.354, Ringwood 0.404 -> 0.412, as walked (polls 23 -> 24 Nov in the same step). Hung figure not checked (not in page data).
  NOT DONE: nsw2027's table has no shift; `output/` in this checkout is the 13 Nov rebuild, NOT the live model
  (live = `C:/dev/auspol-wt-rbm/output`), so never run stage 9 from here until a full rebuild has been checked.
  EARLIER, PARKED 24 Nov (DECISIONS): as an xgb feature LAST election's early share is not
  separable from a placebo. AFTER 28 Nov: add vic2026 to the panel and rescore; the untested route is a direct post-tree
  correction on Labor; the federal "pre-poll shifted later" lead can be computed for Victoria from
  `external/reference/antonygreen-vic2022-early/` and the saved VEC 2026 file. DATED 25 Nov (morning): refresh posts 1-4
  and the three early-voting charts in the Victoria Forecast Thread artifact from the new VEC file before Pete posts.
- SUPERSEDED 25 Nov: inthegame-blog #1262 CLOSED (Pete OK): the note reached main via #1280; ITG owns the menu link as #1310 (merge 27 Nov). Old text kept below.
- OPEN, DATED 27 Nov: seat-page independents note (inthegame-blog #1243 + #1246) is on its dev only. Reaches prod via
  my cherry-pick branch off its `main` (ITG's rule), with the navbar #1239. Done when: the note's code is on inthegame.blog
  (it shows only at 10%+ independent; since search interest went off on 19 Nov no seat qualifies, so no page shows it yet).
  BUILT 21 Nov: DRAFT inthegame-blog PR #1262 (`feat/politics-night-prod`, into `main`): c3e41729, 28f51c5c, d38e702f and
  the navbar 264d638f cherry-picked onto its `main` (21 added lines, 2 files; built with merge-tree + commit-tree, the
  shared checkout untouched). ITG agreed 21 Nov and lists it as the 27 Nov merge in place of #1239. ITG reviewed and
  design-checked it 21 Nov at head 84d9e8d5 (0 important; PASS at 400/760/desktop); its check of the live forecast: the
  note shows on 0 of 88 seats (highest unsplit independent total Macedon 5.6%, against the 10% bar). On 27 Nov: mark it
  ready, check its render run is green, merge, close #1239 (same nav commit). Any new commit to the branch: tell ITG.
