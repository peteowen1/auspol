# auspol — work queue

Open state only. Narrative lives in `docs/backlog/journal-*.md` (the hub as
it stood before this rewrite: `backlog/journal-2026-09-19-hub-snapshot.md`).
Decisions: `docs/DECISIONS.md`. Every seat verdict: `docs/SEAT-REGISTRY.md`.
Pete's requests: `docs/PETE-ASKED-FOR.md`. Rewritten 2026-09-19 21:30.

## Where things stand

**Ledger v40, 2026-09-20 10:10** (projection mix fitted at 1/7/14 days): seat
log loss **0.2992 vs AEF 0.2851**, wRMSE 5.19 vs 5.42, TCP MAE 3.96 vs 3.63,
accuracy 88.0% vs 86.8%. nsw2023 -0.051, fed2025 +0.019: the mix change
missed its own bar and breached do-no-harm on fed2025, kept provisionally
on structural grounds, **Pete's call** (`plans/prereg-projection-mix-short-horizons-2026-09-20.md`).

**Ledger v39, 2026-09-20 00:36, the first that is predictive throughout**
(660 AEF-7 seats, production pipeline, 20,000 sims; lower is better): seat
log loss **0.3012 vs AEF 0.2851** (v38 read 0.2657 because four harnesses
swung toward the counted statewide, an oracle), weighted primary RMSE 5.22
vs 5.42 (still ours), TCP MAE 4.04 vs 3.63, accuracy 87.3% vs 86.8%. The
forecast statewide misses by 1.3 to 3.9 points per class per election and
the seats inherit it: **the statewide forecast is now the biggest lever**
(model item 0 below). wa2021 has no fittable trend and is not scored.
Models retrained on predictive base_pred are on `shipped-models` and feed
the daily forecast from 20 Sep. Disclosed: v39 ran before a review fix
(the wrapper now unions the target's classes into the forecast), so
vic2022's One Nation cells read 0.0 (actual mean 0.2; negligible); the next
rebuild picks it up. Public copy:
https://github.com/peteowen1/auspol/releases/download/shipped-models/aef7-ledger.html

**Live forecast** (`forecast-latest` release, rebuilt 06:00 Melbourne daily,
also on R2 `inthegame-data/auspol/` for **inthegame.blog/politics/, live with
data since 21:35** after Pete set the two secrets). First run
2026-09-19 15:50: LNP 36.1 expected seats, ALP 35.5, ONP 11.0, GRN 5.3;
P(hung) 0.72, P(One Nation balance of power) 0.70. 88 of 88 seats.

## NOW: the election-night booth model (Pete, 2026-09-19 21:15: option b)

Seat-type swing pre-election is PARKED (Chisholm/Reid/Bennelong 2022 was a
new pattern no prior election teaches; Banks shares the census profile and
did not move). Both that pattern and the WA-type state miss are observable
on the night from booth swings, so the effort goes there.

Plan written: `docs/plans/election-night-booth-model.md` (VEC publishes an XML
feed down to voting centre; 2022 per-booth files exist per district; dress
rehearsal = replay vic2022; the VEC email is drafted there for Pete to
send). Scope:
**Done 22:05**: 2022 and 2018 booth data fetched and parsed (`fetch_booths_vic2022.R`);
replay harness `booth_replay_vic2022.R` passes the identity check and, with no
prior, calls the first-preference leader right in 85-87 of 87 seats from 10%
counted, major shares within 1.5 points at half the night vote (table in the
plan). **Rehearsal 2 (22:15)**: prior (vic2022 backtest) + projection beats
both alone: major-share MAE 3.12 (prior) -> 1.72 at 10% counted -> 1.25 at
50%; leaders 68 -> 77 of 78. `R/booth_projection.R`. Next: re-simulate the
preference count from the posterior primaries (win probabilities), chamber
aggregation, then the VEC feed parser.

1. Data: 2022 booth-level first preferences and TCP per voting centre
   (VEC "votes by voting centre"; `external/reference/vec/2010, 2014, 2018`
   hold the older FPV-by-VC files, 2022's is in
   `external/elections/cache/vec-2022-vic/*-dist.html`, 163 files unparsed
   for booths).
2. Matching: reporting booths to their 2022 counterparts (name + district;
   new/merged booths fall back to district-level swing).
3. Update: tonight's forecast as the prior for every seat; each booth's
   swing updates the seat's expected result with a booth-size-weighted
   analytic posterior; uncounted booths projected from matched swing by
   booth type (pre-poll, postal, ordinary).
4. Feed: how VEC publishes results on the night (media feed registration or
   the results site's per-district pages); what cadence.
5. Dress rehearsal: replay vic2022 in time order and score against the
   final result, before November.

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
- Audit other 0-filled xgb features for the NA-fill fix; any new column to
  `fit_xgb_primary_v6.R` costs ~0.014 pooled RMSE (placebo floor).
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
