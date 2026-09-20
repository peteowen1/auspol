# auspol — work queue

Open state only. Narrative lives in `docs/backlog/journal-*.md` (the hub as
it stood before this rewrite: `backlog/journal-2026-09-19-hub-snapshot.md`).
Decisions: `docs/DECISIONS.md`. Every seat verdict: `docs/SEAT-REGISTRY.md`.
Pete's requests: `docs/PETE-ASKED-FOR.md`. Rewritten 2026-09-19 21:30.

## Where things stand (2026-09-20 12:10)

**Ledger v41** (660 AEF-7 seats, predictive throughout, 20,000 sims; lower
is better): seat log loss **0.2921 vs AEF 0.2851**, weighted primary RMSE
5.18 vs 5.42, TCP MAE 3.98 vs 3.63, accuracy 88.0% vs 86.8%. Public copy:
https://github.com/peteowen1/auspol/releases/download/shipped-models/aef7-ledger.html
History: v38 0.2657 (oracle statewide), v39 0.3012 (predictive), v40 0.2992
(mix at short horizons), v41 0.2921 (silent screen is not a permit); the
last two missed their own pre-registered bars and Pete kept them (DECISIONS,
2026-09-20). **The day-before statewide forecast is the biggest lever**: it
misses by 1.3-3.9 points per class per election and every seat inherits it.

**Live forecast**: `forecast-latest` release daily 06:00 Melbourne, mirrored
to R2 for inthegame.blog/politics/ (live). 20 Sep run pending on v41 models.

## NOW: the election-night booth model (Pete, 2026-09-19: option b)

Plan and both rehearsals: `docs/plans/election-night-booth-model.md`. Built:
2022 + 2018 booth data (`fetch_booths_vic2022.R`), matching + projection +
prior combination (`R/booth_projection.R`, tested), replay harness. Rehearsal
2: prior + projection beats both alone (major-share MAE 3.12 -> 1.25 at half
the night vote; leaders 68 -> 77 of 78). Seat-type swing pre-election is
PARKED (a new 2022 pattern no prior election teaches).
Next: re-simulate the preference count from posterior primaries (win
probabilities), chamber aggregation with the forecast's correlation, VEC
feed parser once the 2026 configuration is published (email drafted in the
plan, **Pete to send**; To Do reminder set).

## Dated, cannot move

- **9 November 2026, 12 noon: nominations close.** Same day: fetch the VEC
  candidate list; `build_candidacies.R` writes vic2026 rows so
  `candidate_returns(vic2022, vic2026)` and the flow model's `dest_same`
  features go live; rerun the three salience scripts named in
  `published_flags.R` (`victoria_salience_dryrun.R` proves the path on
  vic2022); revisit candidate-count weighting once counts are facts.
- **The day Liberal how-to-vote cards are published**: add
  `vic2026,ALL,<TRUE/FALSE>,<source>` to
  `external/reference/htv/liberal-alp-grn-order.csv` (~8 points of 2CP in
  inner-Melbourne ALP-v-GRN seats). Nothing announced as of 19 Sep.
- **28 November 2026**: election night.

## Model, open (triaged 2026-09-19; nothing here blocks Victoria)

- **(0) The statewide forecast as at the day before** now decides the ledger.
  Per-class error 1.3-3.9 points; WA 2017 (Labor 31.7 forecast, 42.2 actual)
  and nsw2023 (Labor 31.3 vs 37.0) are the worst. Every seat inherits it, so
  a point here is worth more than any seat mechanism. Start by walking the
  worst cycles' poll-trend fits with Pete (the "design with Pete" rule).

- **NSW variance / per-seat `seat_sd`** — design-with-Pete item: the 11 wrong
  nsw seats went to a different beneficiary every time, arguing for seat-level
  uncertainty over class widening; means a `src/seat_sim_core.cpp` change.
- **One Nation in Victoria**: polls ~25%, Nepean by-election 24.5%,
  concentration fitted on one election (sa2026). `AUSPOL_ONP_CONC_SD` fixes
  sa2026 but regresses vic2022 (IND coupling); MacKillop's boundary mismatch.
  Not shipped. The Victorian ONP level sits 0.03 inside the poll-tracking
  bound (WATCH; analogue WA 2017 says trends OVER-state such surges).
- **Demographic axis**: real (permutation control) but one coefficient is an
  order of magnitude too small; a level interaction needs its own prereg.
  Parked by Pete.
- **`base_margin` scoped arm** (away from ALP, or to sa2026/wa2021-shaped
  cases): the full form refused at seat level (+0.004) despite primary gains.
- **State-deviation**: v2 refused 2026-09-19 (one landslide behind the
  state-election term). Reopens with Tasmanian state results in the corpus
  (7 of the 12 worst state-years are TAS/ACT/NT).
- **Surge v4 vs salience**: hazard AUC 0.936 vs 0.751 but over-dispersed;
  deciding seat-count test not run (`prereg-xgb-surge-parameters-v2`).
- **Teal/independent under-call** (Curtin, Goldstein, Mackellar, Wakehurst):
  PARKED by Pete. Overall we lead AEF on independents (36 winners: 16.7 vs
  19.7 log loss). Wave term blocked (`reviews/wave-term-blocked-2026-09-07.md`).
- **Final-two flow for excluded-party cells; calibration by band** (roadmap
  items 3 and 5, unstarted).
- Smaller: WA breaks out NAT and nothing merges it into LNP's trend (OTH
  bias +1.71); intra-Coalition seats have no TCP class (2 of 660, AEF has the
  same limit; zero vic2026 seats affected today); Centre Alliance/SA-BEST
  read as OTH not IND (Pete's call); Orange/Wagga `own_prev_pcv` NA for
  by-election winners (needs a feature, fallback fill refused); the statewide
  covariance pools every era; WA has no surge-v2 hazard.

## Harness and pipeline hygiene

- **DONE 10:40, Pete's ask ("optimise the test-a-theory pipeline")**: the fast
  loop is `scripts/smoke_pair.sh` + `smoke_diff.R` (one harness, xgb off, 500
  sims, diff against the last rebuild's stage-1 file: ~4 min); the rebuild's
  stage 1 runs at 2,000 sims (base_pred is deterministic), ~10 min saved per
  rebuild; `PIPELINE.md` C0. First use: the screen-silence fix on sa2026,
  all-cell RMSE 4.93 -> 4.20 in four minutes. 11:50: the as-at primary
  models now skip when their inputs' hash is unchanged (18 of 22 reused on a
  no-change rerun; stage 4 ~4 min -> seconds); the forecast statewide level
  is pinned to 20,000 draws so base_pred no longer jitters with the harness
  sim count.

- **DONE 22:50**: `AUSPOL_FORECAST_MODE` wired into nsw/qld/vic/wa through one
  shared block (`forecast_statewide_or_oracle()`), proven on all four at 2,000
  sims (forecast statewide error 1.3-2.4 pts per class; wa2021 has no
  fittable trend and is skipped loudly), and the published default FLIPPED
  to 1 (Pete's ruling: predictive throughout). **Ledger v39 rebuild under
  it pending** -- expect worse, honest numbers. The old note that the two
  modes tie with xgb on was true of the static-OOF path only; the production
  base_margin path carries the statewide through.
- CLOSED: time-forward folds -- the as-at models (`fit_xgb_primary_asat.R`,
  `fit_xgb_flows_asat.R`) train only on elections dated before the target.
- DONE 12:15: audited every xgb feature for zero placeholders. Beyond the
  known binary flags nothing else is 0-filled; five candidate-identity
  columns (`soph_party_i`, `retirement_i`, `is_incumbent_party_i`,
  `soph_cand_i`, `prev_swing`) are 52% NA and rely on xgboost's native
  missing handling, which is correct and should stay NA. `permit` now
  carries NA where the screen is silent; same treatment. Any new column
  costs ~0.014 pooled RMSE (placebo floor).
- Package functions read bare relative paths (`surge_hazard_for()`); should
  resolve via `getOption("auspol.root")`.
- DONE 23:20: every switch in `MODEL-REGISTRY.md` is classified (was 12 unexplained).
- Fresh clone needs `scripts/fit_mp_slope.R` before `AUSPOL_MP_SLOPE=1`
  works (deliberate: no silent fallback).
- Diagnosed, not built: widening simulated variance for the majors' floor
  seats (`sd_override` into the WA harness); WA personal-vote transfer helps
  Pilbara and hurts WA overall (one seed).

## Data and infra

- VEC feed: email drafted in the booth-model plan, **Pete to send**
  (communication@vec.vic.gov.au); 2026 configuration not yet published.
- Tasmanian statewide primaries 2006-2024 are now a hand table
  (`external/reference/state-elections-statewide.csv`, Wikipedia, tracked).
  Still to do: read it in `build_state_deviation_features.R` so `state_elec_dev`
  exists for TAS (Hare-Clark, so no seat rows; only the statewide swing is
  usable), then re-run the state-deviation v2 plan. ACT/NT not yet tabled.
- Row-add routine for the two hand tables (HTV order, by-election winners)
  plus a calendar reminder.
- DONE 22:40: `build_data_dictionary.R` reads every processed file in full
  and FAILS on a 100%-empty column (none today).
- DONE 22:35: vic2022 TCP truth upgraded to the VEC's official 2CP totals for
  74 seats (`build_aef7_tcp_vic_from_vec.R`); 12 ABC-scrape rows disagreed
  (Shepparton by 4 points). The VEC page's pair is its indicative count, not
  the distribution's final two (Hawthorn, Kew, Mulgrave kept from the ABC).
- Federal results as a correlated signal for state seat lean: needs
  seat-boundary matching (`external/reference/boundaries/` has CED 2016).
- GDELT parked (needs a GCP project); Census 2006/2001 have no bulk pack.
- ITG page: seat map and per-seat candidate cards (the table is live).

## Awaiting Pete

- **Repo public?** Two outward-facing things to be deliberate about:
  `docs/plans/product-features.md` names competitors; the scorecard names
  pollsters. Poll data is the anchor's and not republished; ask permission
  before going public.
- The four improvement-quiz questions (`ANCHOR-MODEL.md`, "Honest
  assessment"); two now have measured answers.
- Market odds or seat polls as an exogenous input for new independents: a
  different kind of input, Pete's call.
- Centre Alliance / SA-BEST class (OTH vs IND).
