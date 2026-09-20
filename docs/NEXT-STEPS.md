# auspol — work queue

Open state only. Narrative lives in `docs/backlog/journal-*.md` (the hub as
it stood before this rewrite: `backlog/journal-2026-09-19-hub-snapshot.md`).
Decisions: `docs/DECISIONS.md`. Every seat verdict: `docs/SEAT-REGISTRY.md`.
Pete's requests: `docs/PETE-ASKED-FOR.md`. Rewritten 2026-09-19 21:30.

## Where things stand (2026-09-20 15:00)

**Ledger v42** (660 AEF-7 seats, predictive throughout, 20,000 sims; lower
is better): seat log loss **0.2943 vs AEF 0.2851**, weighted primary RMSE
5.15 vs 5.42, TCP MAE 3.99 vs 3.63, accuracy 87.7% vs 86.8%. Public copy:
https://github.com/peteowen1/auspol/releases/download/shipped-models/aef7-ledger.html
History: v38 0.2657 (oracle statewide), v39 0.3012 (predictive), v40 0.2992
(mix at short horizons), v41 0.2921 (silent screen is not a permit), v42
0.2943 (WA Nationals poll series folded into the Coalition; primary better,
seat log loss +0.002 within noise, **held for Pete** like v40/v41,
`plans/prereg-poll-series-class-fold-2026-09-20.md`). **The day-before
statewide forecast is the biggest lever**: audit of every pair in
`reviews/statewide-forecast-audit-2026-09-20.md`, three cycles to walk with
Pete (wa2017, nsw2023, fed2019).

**Live forecast**: `forecast-latest` release daily 06:00 Melbourne, mirrored
to R2 for inthegame.blog/politics/ (live). 20 Sep run pending on v42 models.

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
  Audited per pair 2026-09-20 (`reviews/statewide-forecast-audit-2026-09-20.md`,
  `scripts/audit_statewide_forecast.R`): worst wa2001, wa2017, fed2019,
  wa2005, nsw2023; three walk-through questions written for Pete.
  Per-class error 1.3-3.9 points; WA 2017 (Labor 31.7 forecast, 42.2 actual)
  and nsw2023 (Labor 31.3 vs 37.0) are the worst. Every seat inherits it, so
  a point here is worth more than any seat mechanism. Start by walking the
  worst cycles' poll-trend fits with Pete (the "design with Pete" rule).
  **15:35: the ledger log-loss gap is six 95%+ favourites that lost**
  (Tangney, Braddon, Parramatta, Maryborough, South Brisbane, Bateman:
  8.1 points against AEF, total gap 6.1; the other 654 seats are ahead by
  2.0). Calibration by band otherwise identical to AEF (roadmap item 5
  DONE, audit review last section). The lever is the simulation's tail,
  not the mean: why under 5% for the loser where AEF had 8-28%.
  **nsw2023 walked with Pete (16:10)**: the trend was right (54.2 vs
  54.3); Labor's 4.4-point fall is three steps: phantom vote for unpolled
  classes (-1.2), the first-preference-implied two-party sitting 1.0
  above the published-TPP trend (-1.1), the fundamentals' pull (-2.1).
  Arms run: drop `fed_aligned` REFUSED (fundamentals LOO MAE +0.54);
  phantom-vote fix REFUSED on rebuild v43 (ledger 0.2943 -> 0.3022,
  wa2025 +0.077) because it had been compensating the anchoring's
  Coalition push. **Next: the anchoring arm designed WITH the phantom fix
  as one change** (anchor to the draws' own implied two-party, not the
  published-TPP series; then remove the phantom vote); smoke nsw2023,
  wa2001, wa2025 before any rebuild. Plans: `prereg-fundamentals-drop-
  fed-aligned-2026-09-20.md`, `prereg-phantom-minor-vote-2026-09-20.md`.

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
  items 3 and 5, unstarted). Item 3 demoted 15:20: the whole TCP MAE gap
  to AEF is nsw2023 (+2.04 on 77 seats, 157 of 211 gap points), Labor too
  low across western Sydney, i.e. item (0) again (audit review, last table).
- WA Nationals fold: SHIPPED in v42 (held for Pete: WA primary RMSE 5.46 ->
  5.34, WA seat log loss +0.004, wa2001 Labor now over-forecast through the
  anchoring's asymmetry, which is the next thing to look at in the statewide
  walk). Smaller: intra-Coalition seats have no TCP class (2 of 660, AEF has the
  same limit; zero vic2026 seats affected today); Centre Alliance/SA-BEST
  read as OTH not IND (Pete's call); Orange/Wagga `own_prev_pcv` NA for
  by-election winners (needs a feature, fallback fill refused); the statewide
  covariance pools every era; WA has no surge-v2 hazard.

## Harness and pipeline hygiene

Closed 2026-09-19/20 (detail in DECISIONS and the plans): forecast mode in all
six harnesses; time-forward folds (as-at models already train on earlier
elections only); registry fully classified; zero-placeholder audit (the
52%-NA identity columns stay NA for xgboost); the fast loop (`smoke_pair.sh`,
stage 1 at 2,000 sims, as-at model cache, `tidy_output.R`); bare output paths
routed through `out_path()`.

Still open:
- Diagnosed, not built: widening simulated variance for the majors' floor
  seats (`sd_override` into the WA harness); WA personal-vote transfer helps
  Pilbara and hurts WA overall (one seed).

## Data and infra

Closed 2026-09-19/20: poll snapshot + zero-byte guard on every run; the data
dictionary fails on a 100%-empty column; vic2022 TCP truth from VEC official
totals (74 seats); Tasmanian statewide primaries hand table; district-to-
region table (`external/reference/vec/vic-district-regions.csv`) in the
forecast JSON and on the blog page; To Do reminders for 9 Nov, the HTV row
and the VEC email; Tasmania in the state-swing prior (the v2 arm with it is
still worse, off).

Still open:
- VEC feed: 2026 configuration not yet published; **Pete to send the email**
  drafted in the booth-model plan.
- Federal results as a correlated signal for state seat lean: needs
  seat-boundary matching (`external/reference/boundaries/` has CED 2016).
- GDELT parked (needs a GCP project); Census 2006/2001 have no bulk pack.
- ITG page: a seat map (regions are in the JSON now) and per-seat cards.

## Awaiting Pete

- **Ledger v42 (WA Nationals fold): keep or revert?** Primary better (5.18
  -> 5.15), seat log loss 0.2921 -> 0.2943, every per-pair move inside its
  SE. Recommendation: keep (a dropped poll series is a bug), and treat the
  wa2001 Labor over-forecast as the anchoring question for the statewide walk.
- **Repo public?** Two outward-facing things to be deliberate about:
  `docs/plans/product-features.md` names competitors; the scorecard names
  pollsters. Poll data is the anchor's and not republished; ask permission
  before going public.
- The four improvement-quiz questions (`ANCHOR-MODEL.md`, "Honest
  assessment"); two now have measured answers.
- Market odds or seat polls as an exogenous input for new independents: a
  different kind of input, Pete's call.
- Centre Alliance / SA-BEST class (OTH vs IND).
