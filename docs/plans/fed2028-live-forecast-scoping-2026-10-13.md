# Federal 2028 live forecast on ITG: scoping (2026-10-13)

Read-only scoping. Pete's ask (2026-10-13): a federal election model on the site, piggybacking on the
DemosAU MRP and post how ours differs. Nothing built. "UNVERIFIED" marks things I did not confirm; each
item says where I looked.

## 1. How nsw2027 became a second live target (the template)

Commits (git log --grep nsw2027 and neighbours): `3141a40` fit_seats_full.R takes `AUSPOL_TARGET` ->
`f5223c4` nsw2027 runs end to end -> `d5f4ef8` provisional candidate list (BC12) -> `ae8ef31` anchor prior
corrected -> `2caabdd` census features -> `1aa5c8c` forecast JSON reads the Wikipedia candidate table ->
`dd2c343` publish path, off by default (`AUSPOL_PUBLISH_NSW2027` repo variable) -> `dd556d8` what-if scenarios +
district map -> `0eb7349` regions + poll-trend page data -> `5f47218` R2 failure rules -> `5632737`
fetch_leaders nsw2027. Plan: `docs/plans/nsw2027-itg-scope-2026-10-08.md` (1-2 day estimate for the refactor).

Every piece that made it work:

| Piece | Where | Note |
|---|---|---|
| Target table | `scripts/fit_seats_full.R` lines ~172-190, `.TARGETS` (tgt, prev, region, year, fp_file, tx_file, tx_recipe, n_seats, out_stem) | A fed2028 entry is one more row, but see section 2 |
| Per-target input tables, downloaded from `shipped-models` release | forecast.yaml: `seat-swing-port-`, `seat-poll-blend-`, `leader-seat-`, `demo-resid-`, `council-history-` `-nsw2027.csv`; `nswec-2023-nsw-firstprefs.csv`, `nswec-nsw-transfers.csv`; tagged flow models `xgb-flows-v1-<tag>-asat-nsw2027.model` | Produced by `promote_rebuild.R` with `AUSPOL_PUBLISH_NSW2027=1` |
| Candidates | `output/candidacies.csv`, 194 `nsw2027` rows, built by `scripts/build_candidacies.R` BC12: Wikipedia candidate table (`external/reference/wikipedia/nsw2027-candidates.csv`, from `parse_wikipedia_candidates.py`) + `source=presumed_sitting` rows for sitting members, minus `nsw2027-retiring.csv`. BC11 guard: rows of other elections must stay byte-identical | vic2026 and nsw2027 are the two "provisional" elections |
| Dates | `R/election_dates.R` (nsw2027 = 2027-03-13); duplicate literal in `build_forecast_json.R` | fed2028 has no date row |
| Seat/prior data | NSWEC 2023 results; anchor corrections (`ae8ef31`) | boundaries unchanged 2023->2027 so no notional work |
| Leaders | `scripts/fetch_leaders.R` (nsw2027 added), daily refresh of Wikipedia pages in forecast.yaml (line ~218, `fed2028_leaders` already in the list) | |
| Polls | `nsw2027_opinion` Wikipedia page + anchor `poll-data-nsw.csv` + BludgerTrack; trend `output/trend-nsw-2027.csv` | |
| Forecast JSON | `scripts/build_forecast_json.R` `ELECTIONS$nsw2027` (chamber 93, majority 47, file_tag, json_stem, history_stem, candidates_file, region_file); `AUSPOL_FORECAST_ELECTION` | |
| Regions | `external/reference/nsw/nsw-district-regions.csv`, hand-coded (Pete chose ~8 regions) | |
| Poll-trend page data | `scripts/build_trend_page_data.R` -> `output/nsw2027-page-data.json` | |
| Map | `web/nsw2027-districts.topojson` via `scripts/build_nsw_districts_topojson.sh`, checked by `check_nsw_districts_topojson.R`; committed static | |
| Prior results for the page | `web/nsw2023-results.json`, `web/nsw2023-booths.json` via `build_nsw2023_results_web.R`; committed | |
| Workflow | forecast.yaml: step "NSW 2027 forecast" (fit + JSON + trend + release upload), R2 publish step (wrangler to `inthegame-data/auspol/`), dated history step (`publish_forecast_history.sh`, `ELECTION=nsw2027`), scenario matrix `target: [vic2026, nsw2027]` (line ~716) + `combine_scenarios.py --target=nsw2027` | all gated on `vars.AUSPOL_PUBLISH_NSW2027 == '1'`; NSW runs after every Victorian publish step so it cannot block Victoria |
| Release assets | `forecast-latest`: `forecast-nsw2027.json`, `forecast-history-nsw2027.csv`, `seat-probs-nsw-2027.csv`, `seat-shares-nsw-2027.csv`, `polls-nsw-snapshot.csv`, `nsw2027-page-data.json`, `scenario-nsw2027.json` | |

## 2. What fed2028 needs, item by item

| # | Item | Exists? | Gap / source |
|---|---|---|---|
| 1 | **Target slot in `fit_seats_full.R`** | Partly. `.TARGETS` has vic2026 and nsw2027 only. `tx_recipe` is `pooled` or `own_prev`; `n_seats` etc. are in the table | Add `fed2028` (prev fed2025, region fed, 150 seats, fp_file `aec-fed-firstprefs.csv`, tx_file `aec-fed-transfers.csv`). The script has 63+ Victorian assumptions already generalised for NSW (G1-G5 of the NSW plan), but federal-specific logic lives only in `backtest_candidate_fed.R` (1,966 lines) and has NOT been ported: notional prior (`AUSPOL_NOTIONAL`, harness line ~650), federal swing coefficient / state breakdowns, Senate-free fed2025 fundamentals. CLAUDE.md says "a fix to one harness is a fix to all" and "published = harness shipped flags"; the live script must reproduce what the fed harness scores. This is the main work. Also check hard-coded `ONP_B1` and `federal-transposed-to-state.csv` use (federal target should not need the transposition). |
| 2 | **150 divisions; redistribution since 2025** | 150 seats in fed2025 (DATA-REGISTRY line 147). `external/reference/boundaries/AEC_2025/` and `AEC-2025-esri.zip` are the boundaries used for the May 2025 election | **UNVERIFIED whether any redistribution applies to 2028.** Looked: docs/DATA-REGISTRY.md, ARCHITECTURE/NEXT-STEPS grep for "redistribut" (only state items and the existing federal notional machinery). My recollection (not checked, search needed): the 2024-25 redistributions (NSW, Vic, WA) were in force for May 2025; the next federal determination/redistribution cycle is a Pete/web-search question, with a possible state entitlement change only after the next census-based determination. Action: web-check the AEC redistribution schedule before committing. If seats change, `build_notional_baselines.R` (federal notional table builder, `AUSPOL_NB_TARGET`) already handles this from booth results. |
| 3 | **2025 results as prior; sitting members** | Yes. `external/elections/aec-fed-firstprefs.csv`, `aec-fed-tcp.csv`, `aec-fed-transfers.csv`, `aec-fed-winners.csv`, `external/reference/aec/fed2025-*.csv` (first prefs, dop, tcp), `fed-booth-map.csv`. Candidacies: fed2025 rows from the AEC corpus (including `elected`) | Sitting members are in fed2025 winners. By-elections since May 2025: UNVERIFIED (`external/reference/byelections/` not checked for federal). |
| 4 | **2028 candidates (none nominated)** | NSW precedent works: Wikipedia candidate table + `presumed_sitting` rows + retirements file. A `fed2028` Wikipedia candidates page: UNVERIFIED exists (Wikipedia usually has "Candidates of the next Australian federal election" only late) | Expect to use sitting members + the 2025 field by party class, as Victoria did before nominations (DS2/DS3 fallbacks). Add BC13 in `build_candidacies.R`, add fed2028 to the `.prov` set (line ~1529) so BC11 doesn't trip. Needs `fed2028-retiring.csv`. Federal 2028 date unknown (due by roughly mid-2028; no fixed term): put an assumed date in `election_dates.R` flagged as assumed; the model's as-at date machinery depends on it. |
| 5 | **Polls** | Yes, partly. `output/trend` equivalents: `external/reference/polls/pollbludger/trend-fed-2028.csv`; `bludgertrack_polls.csv` carries fed2028 (`--fetch=fed2028`, `AUSPOL_POLL_BT=1`); the anchor `poll-data-fed.csv` has ResolvePM/Newspoll 2026-10-07; forecast.yaml already fetches `fed2028_leaders`; `fed2028_opinion` Wikipedia page: NOT in the daily fetch list (list is vic2026_opinion, nsw2027_opinion, fed2028_leaders) | Add `fed2028_opinion` to `fetch_statewide_poll_samples.R` / `merge_live_poll_pages.R` lists, check the statewide-trend path (`trend_as_at`) accepts a federal national series (it is built for state series; a national TPP+primary series is the federal harness's case, so likely fine). One quirk: federal polls come with ONP and a large Others, same as NSW. |
| 6 | **Seat polls and MRPs** | `R/seat_poll_blend.R` + `external/reference/polls/seat-polls/seat_polls.csv` (5,333 fed2025 rows) work for fed backtests. DemosAU MRP: `external/reference/polls/demosau/` (crosstabs only); `mrp-seats.csv` being fetched by another agent | The blend reads `seat_polls.csv` by election label: needs fed2028 rows (DemosAU MRP quarterly; YouGov MRPs). Remember MRP-name/type rule: a release covering >= 20 seats counts as MRP. `seat-poll-blend-fed2028.csv` would be a new per-target table. |
| 7 | **Validated model: federal harness** | Yes. `backtest_candidate_fed.R` scores 7 pairs (fed2007-2025); fed is the largest harness (1,036 seat-elections) | The live path is `fit_seats_full.R`, which is a different script. The validity of the live fed2028 forecast rests on the live script matching the harness at shipped flags. A parity check (run the live path with `AUSPOL_TARGET=fed2025` as-at, compare against the harness fed2025 row) is the right acceptance test; the existing NSW work did not have one beyond "runs end to end" (UNVERIFIED, not in the commit list). |
| 8 | **xgb as-at models for a fed target** | Primary: `fit_xgb_primary_asat.R` is leave-one-election-out and includes fed pairs; the production model `fit_xgb_primary_v6_final.R` trains on all elections, so a fed2028 live prediction uses the same final model via `xgb_primary_predict_live()`. Flows: `xgb-flows-v1-asat-*.model` exist for state elections only (nsw, qld, sa, vic, wa). None for fed | Per the NSW row in forecast.yaml, a tagged live flow model `xgb-flows-v1-<tag>-asat-fed2028.model` plus manifest entry is needed IF the tf2 flow model is used; otherwise federal uses official AEC flows (`aec-fed-transfers.csv`, `tx_recipe` `own_prev`). Federal preferences are compulsory-full, so AEC official flows by candidate pair are available and the flow model matters less than in OPV states. Decision for Pete (below). |
| 9 | **Flows** | AEC official: `aec-fed-transfers.csv`, `parse_transfers_fed.R`, `fetch_preferences_fed.R` | Fine. `tx_recipe = "own_prev"`-style (the previous election's own transfers). |
| 10 | **Per-target auxiliary tables** | seat-swing-port, leader-seat (via `fetch_leaders.R`, fed2028 in the daily list), demo-resid (census features for 2025 boundaries: census CED 2021 files present, check mapping to AEC_2025 boundaries; UNVERIFIED), council-history (not applicable federally), booth-features / senate-vic2026 / onp-senate (Victorian; absent for fed; the live xgb model expects Senate and booth features, so absence is a measured cost, XS1!!/XB1!! warn) | Booth features exist federally in some form via `fed-booth-map.csv`; Senate features by division via `build_senate_by_district.R` (exists, scope UNVERIFIED for fed). The model trained with these features gets NA otherwise: need either fed2028 booth/Senate tables or an explicit absence measurement. |
| 11 | **Map** | Boundaries exist (AEC_2025). A topojson builder exists per state (`build_nsw_districts_topojson.sh`, `build_vic_districts_topojson.sh`) | New `web/fed2028-divisions.topojson` (150 polygons; heavy geometry, simplify; check size). Plus `check_` script and a hand-coded region file (state/capital-vs-regional grouping; states are the natural regions). |
| 12 | **Results JSON for the page** | NSW has `nsw2023-results.json` + booths | `fed2025-results.json` (+ booths, optional) via a new `build_fed2025_results_web.R`; `build_fed2025_browse_table.R` already exists and may be the base. |
| 13 | **Forecast JSON + page data** | `build_forecast_json.R` `ELECTIONS` table | Add fed2028 (chamber 150, majority 76, file_tag `fed-2028`, regions file, candidates file). Note federal has a speaker/crossbench convention: majority 76 of 150 is the right threshold. Trend page data: `build_trend_page_data.R` default is nsw2027, add fed2028. |
| 14 | **Workflow** | forecast.yaml step pattern | Copy the NSW block three times (fit/JSON/release, R2, history) gated by a new variable `AUSPOL_PUBLISH_FED2028`; add `fed2028` to the scenario matrix. Runtime: the federal fit has 150 seats vs 93 (NSW) and 88 (Vic); expect longer than the NSW step (UNVERIFIED, profile one run first per the long-runs rule). The R2 key set is `inthegame-data/auspol/`. |
| 15 | **Blog (inthegame-blog, not touched)** | | A fed page analogous to NSW: reads `forecast-fed2028.json`, `fed2028-page-data.json`, `fed2028-divisions.topojson`, `fed2025-results.json`, `forecast-history-fed2028.csv`, `scenario-fed2028.json` from R2 (CSP allows R2 only); a nav entry; a build-blog-data hook if the blog caches R2; copy for the "ours vs DemosAU MRP" post. Blog names the files; auspol owns the contents. |

## 3. Blockers vs reuse, effort, build order

Reuse as-is: AEC results/transfers, fed2025 corpus, federal poll trend and BludgerTrack, fetch_leaders, seat-poll
machinery, the R2/history/scenario workflow pattern, JSON/page-data builders, the as-at xgb pipeline.

Real blockers:
1. The live script is not the federal harness. Porting federal-only pieces and proving parity is the bulk of the work.
2. The redistribution question (item 2) could invalidate the prior; must be settled first. It is cheap to check and decisive.
3. Missing booth/Senate tables for the xgb model on a federal target (item 10).
4. Unknown 2028 election date (assumed date needed).

| Step | What | Effort |
|---|---|---|
| 0 | Settle redistribution/by-election/boundary status (web check, notional table if needed) | 0.5 day |
| 1 | `.TARGETS$fed2028`, election date, candidacies BC13 (sitting members + 2025 field), retiring file; run end to end | 1-2 days |
| 2 | Parity proof: run the live path as fed2025 (as-at) and compare against the harness's fed2025 numbers; fix gaps (notional, state breakdowns, ONP) | 2-3 days (the riskiest step) |
| 3 | Polls: add `fed2028_opinion`; DemosAU MRP rows into seat polls; fed2028 seat-poll-blend table | 1 day (after the MRP fetch lands) |
| 4 | Auxiliary tables: leader-seat, demo-resid, seat-swing-port, booth/Senate features or measured absence; flow model decision | 1-2 days |
| 5 | `build_forecast_json.R` entry, regions file, trend page data | 0.5 day |
| 6 | Map topojson + results JSON | 1 day |
| 7 | Workflow steps, release assets, R2, history, scenarios; promote/publish shipped tables for fed2028; keep off behind `AUSPOL_PUBLISH_FED2028` | 1 day |
| 8 | Blog page (other repo/session) | 2-3 days, in parallel from step 5 |

Total auspol side about 8-11 working days, blog separate. A first honest number (step 1 output) in 2-3 days.

## 4. Decisions for Pete

1. Boundaries for 2028: use the 2025 boundaries unless the redistribution check says otherwise (recommend: check first, assume unchanged).
2. Assumed election date for fed2028 (the model needs one; recommend a mid-2028 placeholder flagged "assumed", replaced on the real announcement).
3. Flows: AEC official only (recommend, compulsory preferential makes this simpler) or train tagged fed flow models like the states.
4. Model parity bar before publishing: the live fed path must reproduce the harness fed2025 within noise (recommend yes, as a hard gate, because "two lists drift").
5. Booth and Senate features: build federal versions, or publish with a measured-absence note (recommend measure absence in step 4 first).
6. Launch scope: forecast + map first, what-if scenarios later (recommend), publish off by default behind a repo variable like NSW.

## Decisions (Pete, 2026-10-13)

1. **Publish, validate in parallel** (not a hard gate): a fed2028 page may go up labelled PROVISIONAL before the live
   path is proven to reproduce `backtest_candidate_fed.R` on fed2025; the seat-by-seat match runs alongside and the
   label comes off only when it passes.
2. **Train federal flow models** (as-at, like the states), not AEC 2025 carried forward.
3. **Placeholder polling day: May 2028** (typical timing), updated when the election is called.
4. **DemosAU MRP enters as seat polls** through the existing seat-poll blend (`external/reference/polls/demosau/
   mrp-seats.csv`), weighted by MRPs' past seat accuracy, as the YouGov MRP was for fed2022.
