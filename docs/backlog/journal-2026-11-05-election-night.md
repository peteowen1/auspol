# Election-night live model: NEXT-STEPS entry as it stood 2026-11-06 (moved verbatim)

Moved out of `docs/NEXT-STEPS.md` on 2026-11-06 to keep the hub under 40,000 characters. The open steps and the runbook
stay in the hub's stub; this is the full history and evidence.

- **Election-night live model, map https://github.com/peteowen1/auspol/issues/148.** Plan and replays:
  `docs/plans/election-night-booth-model.md` (vic2022 seat log loss vs afternoon 0.2643: 0.1133 at 10% counted,
  0.0929 at 50%). Upper house designed, NOT built (`plans/upper-house-night-model.md`). DONE: VEC sign-up (#150),
  night runner (`R/night_runner.R`, `scripts/night_loop.R`), page PUBLISHED unlisted https://inthegame.blog/politics/live
  (ITG #1057, maps, TCP booth colours #1068, live booths #1069, 2026 booth builder #1070), per-booth results (#168),
  R2 upload tested to `auspol/night/test-vic2026.json` (`scripts/night_publish_r2.sh`), night state saved every forecast
  run and uploaded to `forecast-latest` (#169), break-glass Actions backup `.github/workflows/night-backup.yaml` (#170;
  inputs on release `night-inputs`). Night runbook: `gh release download forecast-latest -p night-state-vic-2026.rds -D
  output`, then `night_runner.R --state=output/night-state-vic-2026.rds --ref=output/booths-vic2026-ref.csv --council-lean=output/council-fp-2022.csv`.
  Booth lean for parties new to a seat (One Nation), added 30 Oct: `night_council_lean()` from the 2022 upper house by
  voting centre; on the vic2022 replay with each class made "new", projection RMSE 3.03 -> 2.41 pts (real history
  2.45); named parties only (pooled OTH_RIGHT got worse). Without the flag the runner warns NW15! and runs as before.
  Early voting centres (30 Oct): NOT a new-booth problem (my earlier claim was wrong): night_booth_table() merges
  every centre in a district into one "early" unit matched to 2022's block. The real gap: that unit counts as
  complete once ANY centre reports (largest centre held a median 54% of a district's early vote in 2022, range
  32-93%). Projecting the remainder (`night_early_frac()`, `project_seat_from_booths(early_frac =)`) made the
  approximated replay WORSE (RMSE 0.95 -> 1.15; `scripts/test_early_partial_replay.R`) because the early swing is
  measured on whichever centre reported first. OFF (opt-in `--early-partial=1`). OPEN, for the 25 Nov trial: with
  real 2026 centre names, compare each counted centre with its own 2022 upper-house lean, then re-test; and source
  the expected early total from the VEC's published early-voting attendance, not last election's early share.
  OPEN, in order:
  2. SharePoint live-feed fetch (VEC access details from 4 Nov); the backup's source live waits on it.
  3. 10 Nov: in ITG `politics/night-maps/`, `python -I build-booths-2026.py <State2026MediaFilePollingLocationsV2.xml>`
     (expect ~88 districts, few "new" centres; refuses under 85 districts or half matched), commit `booths-vic2026.json`.
     DRY RUN 4 Nov: all five refusals fire with nothing written (VEC test file, 9 districts; names mangled; truncated at
     65,536 bytes; Classification renamed; and the 2022 file passes, 87 districts). GAP FOUND: Narracan is not in
     `booths-vic2022.json` (87 of 88; its 2022 poll was the 28 Jan 2023 supplementary), so every Narracan booth is "new"
     on the night. DONE 5 Nov (PR #189): the runner's `--ref` is `output/booths-vic2026-ref.csv` (Narracan from 2018,
     `scripts/build_booths_vic2026_ref.R`); the page's pre-count map shows them with their 2018 result, labelled 2018
     (ITG #1142, `build-booths-ref2018.py`; the 10 Nov command is unchanged). OPEN, 10 Nov: check the popup in a browser
     at 390/1280 px, and check the 38 Narracan-only 2018 names against the 2026 polling places.
  4. Navbar link; the "called" rule (99% with 10% counted is a placeholder). Find my seat (#166): LIVE 5 Nov 5:28pm on
     inthegame.blog/politics/live (ITG #1144 dev, #1147 main); CSP fix #1149, no-bias #1151, suggestions as you type #1152 (live 6:55pm). Pete checked it on his phone 5 Nov 7:09pm; #166 CLOSED. Live page hero bar: majority line no longer over a label (ITG #1154, live 5 Nov 7:29pm).
  5. Trial 25 Nov (no 2CP); the upper-house model.
  Dated: the satellite basemap's Esri key (Pete's account, basemaps only, pay-as-you-go off) expires 27/10/2027.
