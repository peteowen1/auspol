# Checklist: adding the next five pairs (2026-10-13)

Pairs (target, previous): **nsw2015 (nsw2011), qld2015 (qld2012), qld2017 (qld2015), sa2014 (sa2010), sa2018 (sa2014)**.
Read-only investigation, nothing edited except this file. Template: `add-pair-vic2010-checklist-2026-10-13.md` and the
committed vic2010 wiring (`git show 59a953c`). VERIFIED = read in code or on disk, or run read-only today. UNVERIFIED =
inferred or from memory. Line numbers are against the working tree on `dev` (575f260). The vic2010 doc's sections 3, 4 and 6
(silent fallbacks, which existing pairs move when a pair joins `all_election_pairs()`, the baseline-freeze test order) apply
unchanged and are not repeated; read them with this file.

## 0. Headline

1. **Order (cheapest first): nsw2015, qld2015, sa2018, qld2017, sa2014.** Reasons in section 6.
2. **Three harnesses stop hard on a seat-count mismatch.** `backtest_candidate_qld.R:776-782` (`N_DISTRICTS <- 93L`),
   `backtest_candidate_sa.R:946` (`!= 47L`) and `backtest_candidate_nsw.R:432` (`stopifnot(nrow(win) == 93L)`) all assume the
   same seat set at both ends. Vic's harness instead scores the matching seats (vic2014: 73 of 88). Pairs with a redistribution
   (nsw2015, qld2017, sa2014, sa2018) therefore need EITHER a notional prior (needs polling-place results for the previous
   election, none on disk for any of the four) OR a relaxed, loudly-logged "score the matching seats" rule. qld2015 is the one
   pair that is fine as is for names (89 = 89, VERIFIED), but the 93 constant must become per-pair.
3. **No state flow distribution exists for 4 of the 5 pairs.** nsw2015 is the exception: its previous election's own published
   transfers are on disk. For the other four, `output/flows-estimated.csv` already holds blended estimates (qld2012, qld2015,
   qld2017, sa2010, sa2014, sa2018, nsw2011; VERIFIED rows), **but nothing in `R/` or the harnesses reads that file** (grep:
   only `scripts/estimate_flows_from_results.R` mentions it). The harnesses build the flow matrix from event-level rows
   (`build_flow_matrix(tx)`), and the estimate is party-level (`flow_alp`, `exhaust`), so it needs a new entry point (section 2.2).
4. **Leak rule for the flow source:** a pair's flows must come from its PREVIOUS election (qld2015's estimate for qld2017), never
   the target's own row in `flows-estimated.csv`. The estimate for a target uses that target's results.
5. The estimates are thin: `n_seats` 8-13 for Qld and 5-14 for SA (VERIFIED), against 40+ federal. The blend leans on the prior
   (`pool_weight` 0.65-0.79; `prior_source` fed2010/2013/2016/2007).

## 1. Hard-coded lists, dates and per-pair maps

"Add" = an entry for the pair. File:line from the vic2010 commit's footprint, plus the three harnesses' own selectors.

### 1A. Shared (same places the vic2010 commit touched)

| # | File:line | Today | Add |
|---|---|---|---|
| 1.1 | `R/election_dates.R:24-29` | has nsw2015, qld2017, sa2018 only | `nsw2011 = "2011-03-26"`, `qld2012 = "2012-03-24"`, `qld2015 = "2015-01-31"`, `sa2010 = "2010-03-20"`, `sa2014 = "2014-03-15"` (the dates already used in `scripts/extract_pollbludger.R:161-164` and `score_pb_llm_extraction.R:36-39`; whether each was checked against Wikipedia is UNVERIFIED). `tests/testthat/test-election_dates.R` guards it. |
| 1.2 | `R/reentry_prior.R:882-895` (`all_election_pairs()`) | nsw2019, qld2020, sa2022 are the earliest of their states | five new `list(election=, prev=)` entries. **Do this last**: it is the switch that changes later pairs' fits (vic2010 doc 4B). |
| 1.3 | `scripts/fit_xgb_primary_v6.R` `PAIRS` (~l.50-70, region field) | no nsw2015, qld2015/2017, sa2014/2018 | five entries with `region`. `SAL_PAIRS` derives from it. |
| 1.4 | `scripts/build_level_pred.R:36-53` (`DATES`, `PREV`) | earliest nsw2019, qld2020, sa2022 | five `DATES` and five `PREV` entries; needs `st_of(prev)` from candidacies (1.6). Without it `fit_xgb_primary_v6.R` stops "no predicted statewide for X" (loud, per vic2010 doc 1.7). |
| 1.5 | `scripts/build_retirement_derived.py:24-30` (`PREV`) | nsw2019.., qld2020.., sa2022.. | five entries. Note the sa2018 name-format trap documented at its l.13-18 (surname-first vs given-first). |
| 1.6 | `scripts/build_candidacies.R` | see section 2.1: nsw2015, qld2017, sa2018 are built; nsw2011, qld2012, qld2015, sa2010, sa2014 are NOT | per-election loaders (2.1) and winners loops (l.~890 onward, the `WINF` loop and vic loop at l.878) |
| 1.7 | `R/quick_arm.R:28-34` | `nsw c(2019,2023)`, `qld c(2020,2024)`, `sa c(2022,2026)` | `2015`; `2015, 2017`; `2014, 2018`. (Values must match the harness `*_PAIRS` keys.) |
| 1.8 | `scripts/rebuild_forecasts.sh:130-131` (`specs=`) | 9 specs; Vic rides inside `vic` | **run6 DOES need entries here**: `nsw:AUSPOL_NSW_PAIR=2015`, `qld:AUSPOL_QLD_PAIR=2015`, `qld:AUSPOL_QLD_PAIR=2017`, `sa:AUSPOL_SA_PAIR=2014`, `sa:AUSPOL_SA_PAIR=2018`. Also the text "of 9 backtest runs" (l.~143) and "all 23 pairs" (l.111). `reuse_check` (l.147+) takes `${h}${yr}` for nsw/qld file names and the pair column for SA, so no change there. |
| 1.9 | `scripts/check_poll_coverage.R:50-59` | 23 pairs (after vic2010) | five rows; `stopifnot(nrow(scored) == 23)` -> 28 |
| 1.10 | `scripts/fetch_salience_v6.R:125-150` | no entry for these (nsw2019, sa2022, qld2020 listed with prev "(missing)") | entries for the five targets; template `scripts/fetch_salience_v6_vic2010.R` (the vic2010 fetch copy). See 2.9. |
| 1.11 | `scripts/fetch_retirements.R:45-56` (PAGES) | has nsw2015, qld2017, sa2018, not qld2015, sa2014 | add the 2015 Queensland and 2014 South Australian state election pages; `external/reference/retirements/retirements.csv` rows today: nsw2015 19, qld2017 7, sa2018 12, none for qld2015/sa2014 (VERIFIED). |
| 1.12 | `scripts/fit_xgb_flows_v1.R:166-175` and file list ~l.38-44 | the pair list has nsw2019, qld2020 ... | optional and changes later flow models (vic2010 doc 1.11). Note `nswec-2011-nsw-transfers.csv` is NOT in this script's `files` list (it names `nswec-nsw-transfers.csv`); the HTV glob (`R/htv_flow.R:43`) DOES pick the 2011 file up already (vic2010 doc 0.1). |
| 1.13 | Counters: `scripts/pool_backtests.R`, `pool_sharedetail.R`, `promote_rebuild.R`, `promote_arm.R` | `.known` from `all_election_pairs()`, REFUSE (PB2c!) if a known pair has no backtest file | once 1.2 is in, every run that publishes must score all five. Prose "23 pairs" -> 28. |
| 1.14 | Side tools (display / optional): `scripts/build_state_swing_prior.R:55-60` (DATES list), `scripts/estimate_statewide_cov.R:121-130` (SPEC years; nsw has `c(2015,2019,2023)`, qld/sa shorter), `scripts/build_level_components.R:63-75` (only with `AUSPOL_XGB_RAW_LEVEL=1`, off), `scripts/build_leader_ratings.R:38-41` (already has nsw2011, qld2015, qld2017, sa2018), `scripts/fetch_seat_polls.R:77-83` (already lists nsw2015, qld2017, sa2018 URLs) | | update or consciously skip |

### 1B. Per-harness pair selector (how a pair is added to each)

| Harness | Selector | Shape of an entry | Other hard-codes that depend on the pair |
|---|---|---|---|
| `scripts/backtest_candidate_qld.R` | `AUSPOL_QLD_PAIR` (l.296), `QLD_PAIRS` (l.285-295): `to, from, fa, fb, flow_file, flow_from, asof` | add `"2015"` (from 2012: `ecq-2012-qld-firstprefs.csv`, `ecq-2015-...`, asof `2015-01-31`) and `"2017"` (from 2015, asof `2017-11-25`); flow fields per 2.2 | `N_DISTRICTS <- 93L` (l.776) and error text "2024 winners"; winners file `ecq-qld-winners.csv` only (l.321, 339; 2017 winners are in a separate `ecq-2017-qld-winners.csv`, qld2015 winners are nowhere on disk, VERIFIED); `need`/stop message (l.321-326); `state_notional_prior("qld", FROM, TO)` (l.334); seat-file fallback to 2024qld.txt already exists (l.875-885, VERIFIED); `BQ1` log text says "2020"/"2024" (l.674-677, cosmetic); the surge training list (l.944-957) is the Qld-specific copy: nothing to add (membership is date-filtered), but diff it against `fit_salience_surge_v2.R` before touching. |
| `scripts/backtest_candidate_sa.R` | `AUSPOL_SA_PAIR` (l.108), `SA_PAIRS` (l.99-107): `to, from, fp_from, fp_to, flow_from, flow_before` | add `"2014"` (fp_from sa2010 file, fp_to sa2014 file, flow_from `fed2013`, flow_before `2014-03-15`) and `"2018"` (fp_from sa2014 file, fp_to `wikipedia-2018-sa-firstprefs.csv`, flow_from `fed2016`, flow_before `2018-03-17`) | `flow_before` doubles as the `asof` date for `forecast_statewide_or_oracle` (l.440); winners file `ecsa-sa-winners.csv` only (l.376, 411): no sa2014 or sa2018 rows (the sa2018 winners are in `wikipedia-2018-sa-winners.csv`, 47 seats, VERIFIED, not read); `!= 47L` stop (l.946); `RENAMES` is Frome->Ngadjuri for sa2026 only (l.933); `load_seats(TO,"sa")` at l.964 (PORT only) and **l.1037 unguarded** (see 2.7); fp files with candidate-level rows are collapsed to (seat, party) at l.~395 (good: sa2018's Wikipedia file already relies on it). |
| `scripts/backtest_candidate_nsw.R` | `AUSPOL_NSW_PAIR` (l.323), `NSW_PAIRS` (l.320-322): `to, from, next_seats` | add `"2015" = list(to = 2015L, from = 2011L, next_seats = 2019L)` | fp files named `nswec-<year>-nsw-firstprefs.csv` (l.337-338): **`nswec-2011-nsw-firstprefs.csv` does not exist** (derive from `nswec-2011-nsw-candidates.csv`); transfers hard-coded `nswec-nsw-transfers.csv` and the leak guard asserts BOTH `PRV` and `TGT` are in it (l.365-372) -- the 2011 rows live in a different file; statewide asof date map `c("2019"=...,"2023"=...)` at l.397 (a missing key = error, loud); `stopifnot(nrow(win) == 93L)` (l.432; nsw2015 has 93 winners rows, VERIFIED); `load_seats(TO,"nsw")` at l.387 **unguarded** and l.823 (PORT only); `load_seats(next_seats)` l.445 (2019nsw.txt exists, fine). |

## 2. Inputs per pair and what is on disk

### 2.1 First preferences, winners, candidacies (all VERIFIED on disk unless noted)

| Pair | Prev FP | Target FP | Target winners | Candidacies (`output/candidacies.csv`) |
|---|---|---|---|---|
| **nsw2015** | **MISSING `nswec-2011-nsw-firstprefs.csv`**. `nswec-2011-nsw-candidates.csv` has `seat,candidate,party,party_code,party_full,class,first_pref` for **92 districts** (2011 had 93: one district absent, which one UNVERIFIED), classes already assigned: group by (seat, class) gives the file | `nswec-2015-nsw-firstprefs.csv` 93 seats | `nswec-nsw-winners.csv` has nsw2015 x93 | nsw2015 540 rows (present); **nsw2011 absent**: write a loader from the candidates file (names are "SURNAME Given"; nsw2015 uses the inverted form, see `build_candidacies.R` ~l.961, measure the returner match rate) |
| **qld2015** | `ecq-2012-qld-firstprefs.csv` (89 seats) | `ecq-2015-qld-firstprefs.csv` (89 seats). Party-level only (`seat,party,votes`) | **none for qld2015** (`ecq-qld-winners.csv` holds qld2020/2024 only). Derive from the ECQ State2015 results zip (live 200, per the coverage inventory, UNVERIFIED re-fetch) or `ecq-2012/2015` TCP. A TCP file exists for 2012 only (`ecq-2012-qld-tcp.csv`) | **both qld2012 and qld2015 absent**; FP files carry no candidate names, so names need the ECQ XML (same schema as `qld2017.xml`, parser at `build_candidacies.R:660-712`) |
| **qld2017** | `ecq-2015-qld-firstprefs.csv` (89 seats) | `ecq-2017-qld-firstprefs.csv` (93 seats) | `ecq-2017-qld-winners.csv` (separate file, 93 rows) -> must be read or merged into `ecq-qld-winners.csv` | qld2017 453 rows present; **qld2015 absent** (as above) |
| **sa2018** | `ecsa-2014-sa-firstprefs-tcp.csv` is **long format** (`year,district,table,candidate,party,votes`; party is a code such as LIB; names "SANDERSON Rachel" without a comma) and **incomplete: 43 districts**. 2014 had 47; the four missing are inferably davenport, fisher, frome, giles (names in the 2010 file but not the 2014 file; UNVERIFIED which). Needs conversion to (seat, party, class) and a re-scrape of the four | `wikipedia-2018-sa-firstprefs.csv` 47 seats, 264 rows | `wikipedia-2018-sa-winners.csv` (47 rows) exists; `ecsa-sa-winners.csv` has no sa2018 (add rows or read both) | sa2018 264 rows present; **sa2014 absent** |
| **sa2014** | `ecsa-2010-sa-firstprefs-tcp.csv`: **45 districts** (2010 had 47; port-adelaide is in the page inventory but not in the data, and one more, probably norwood, UNVERIFIED). Names "SEBBEN, Ruben" with a comma, a different format from 2014 | sa2014 as above (43 of 47) | none; derive from the file's own `tcp` table (86 rows = 43 districts x 2) once complete, or Wikipedia | **both sa2010 and sa2014 absent** |

Notes. `external/elections/ecsa-2010-2014-sa-page-inventory.csv` lists the pages that were fetched; 2010 pages show `n_tables < 2` for 45 of 46 and `looks_like_distribution FALSE` throughout, so the ECSA pages carry first preferences and final two-party counts but **no preference rounds** (consistent with the coverage inventory). `scripts/fetch_preferences_sa2018.R` is the Wikipedia fetcher and the model for any further SA parser.

### 2.2 Transfers and flows (what each harness does when the file is missing, and where the blend plugs in)

| Pair | Published distribution of the previous election? | What the harness does today | What this pair needs |
|---|---|---|---|
| nsw2015 | **Yes**: `nswec-2011-nsw-transfers.csv`, 525 rows, 42 of 92 seats (the rest decided at a majority/partial), election label `nsw2011` (VERIFIED). Thin against nsw2015's 1,214 rows | `fread(nswec-nsw-transfers.csv)`, `stopifnot(c(PRV,TGT) %in% tx$election)` (l.365-366): **stops** because nsw2011 is not in that file | read both files (rbind in the harness) or append the 2011 rows to the shared file. Appending also changes the `fit_xgb_flows_v1.R` flow table and so the as-at flow models of later NSW pairs; a harness-side rbind does not. Prefer the harness-side rbind. The harness fallbacks (`fallback_smooth`, `flow_sd`, l.162-182) cover the thin cells. NSW is optional preferential: do not pool Qld/WA (the file's own comment, l.~370). |
| qld2015 | No (Qld optional preferential until 2016; no distribution for 2012). `output/flows-estimated.csv` has qld2012 (4 classes, `n_seats` 8, prior fed2010, exhaust 28-52%) | `need` includes `PAIR$flow_file`; with `aec-fed-transfers.csv` + `flow_from "fed2013"` it runs exactly like the qld2020 pair (precedent: fed2019 flows). `stopifnot(nrow(tx) > 100, all(election == FLOW_FROM))` | **Pete's decision already taken (flows-estimation plan, 2026-10-13): blend the estimate with nearest earlier published flows.** There is no earlier published Qld distribution at all, so the blend's prior is federal 2013 (matches `prior_source` in the file). Federal flows are compulsory-preferential, so exhaust is the missing piece; **the Qld harness has no exhaust path** (only NSW has `AUSPOL_NSW_EXHAUST`, R engine only). |
| qld2017 | No (the 2017 results package has no distribution; `ecq-qld-transfers.csv` holds qld2020/2024 only, which would LEAK). Estimate qld2015 exists (`n_seats` 11, fed2013 prior); qld2017 row has exhaust 0 (compulsory from 2016) | as qld2015 | flows from qld2015 (blend) for the pair; NOT the qld2017 row (target's own results). |
| sa2014 | No. Estimate sa2010 exists (`n_seats` 5, prior fed2007: the weakest row) | SA harness always reads `aec-fed-transfers.csv` filtered to one federal election (`flow_from`, l.413-418), then `pool_configured_flows(tx, flow_before)`. Works unchanged with `fed2013` (federal 2013 is in the file: 2,708 rows, VERIFIED) | blend plugs in at the same place |
| sa2018 | No. Estimate sa2014 (`n_seats` 10, prior fed2013) | as sa2014 with `fed2016` (1,886 rows) | as above |

**Where the blended flows would plug in (nothing built):** (a) `build_flow_matrix()` (`R/flow_matrix.R:42`) consumes event rows
`(election, seat, round, from, to, votes)` keyed on the survivor set, so a party-level estimate cannot enter it directly; options
are synthetic event rows weighted by `n_seats`, or a new function that blends the party-level pooled rates into `fm$pooled` and
leaves `conditional` to the federal rows. (b) The statewide two-party conversion goes through `flows_for(load_preference_flows())`
(`R/forecast_mode.R:112`, `R/load_polls.R:188`), AE's hand file; that file HAS rows for every one of these elections
(qld 2012/2015/2017, sa 2010/2014/2018, nsw 2011/2015: VERIFIED by `awk`), so the statewide path runs today with the AE
dependency and no failure; swapping to `flows-estimated.csv` is the "move off AE" step. (c) The time-forward blend weight from
earlier published elections (the plan's last paragraph) is not implemented anywhere (UNVERIFIED beyond the grep above).

### 2.3 Redistribution notionals

`STATE_REDISTRIBUTIONS` (`R/state_notional.R:49-59`) lists vic2014, vic2022, nsw2023, sa2022, sa2026, wa*; **no entry** for nsw2015, qld2017, sa2014, sa2018. `scripts/build_state_notionals.py` `PAIRS` (l.38-45) starts at nsw 2015->2019, qld 2017->2020, sa 2018->2022; `SAME_BOUNDARIES` (l.46); `DISTRICT_FILE` (l.70). It reads `output/booths/<election>-booth-fp.csv`; on disk: nsw2015, qld2017, sa2018 (+ later); **missing: nsw2011, qld2015, sa2010, sa2014** (VERIFIED `ls output/booths`). So every notional here needs a new booth parse first (`scripts/parse_booths_*.py`, `parse_booths_nsw_qld.py`; sources per coverage inventory: NSWEC `pastvtr` SGE2011 polling-place pages, ECQ State2015 zip with booth-level rows [live, 433 candidates, 89 districts], ECSA 2010/2014 per-polling-place HTML). `state_notional_prior` returns NULL ("SNP0 no redistribution ...") for a pair not in the vector, so skipping it is silent in the notional itself and then loud or silent downstream depending on the seat-count rule (section 0.2).

| Pair | District change (VERIFIED by comparing the name sets on disk) | Notional status |
|---|---|---|
| nsw2015 | 2011 (92 in file) vs 2015 (93): 7 only in 2011 (Burrinjuck, Marrickville, Menai, Murray-Darling, Murrumbidgee, Smithfield, Toongabbie), 8 only in 2015 (Cootamundra, Holsworthy, Murray, Newtown, Penrith, Prospect, Seven Hills, Summer Hill). A same-name seat can still have moved (UNVERIFIED) | needs nsw2011 booths; entry `nsw2015 = "2014 NSW redistribution"` (name UNVERIFIED) |
| qld2015 | 89 = 89 names, no difference | none expected (UNVERIFIED that boundaries are identical; the 2008 redistribution preceded 2009) |
| qld2017 | 89 -> 93: 12 only in 2015 (Albert, Ashgrove, Beaudesert, Brisbane Central, Cleveland, Dalrymple, Indooroopilly, Kallangur, Mount Coot-tha, Mount Isa, Sunnybank, Yeerongpilly), 16 only in 2017 | needs qld2015 booths (ECQ XML) |
| sa2014 | 2010 vs 2014 (data incomplete both ends): 2010-only davenport/fisher/frome/giles (absent from the 2014 file; probably an artefact of the incomplete scrape, not a redistribution), ramsey->ramsay, plus dunstan and port-adelaide on the 2014 side; the 2012 SA redistribution is the cause (memory, per the coverage inventory; UNVERIFIED) | needs sa2010 booths |
| sa2018 | 2014 (43 of 47 in file) -> 2018 47: 2018-only Badcoe, Black, Davenport, Elizabeth, Frome, Gibson, Giles, Hurtle Vale, King, Narungga; 2014-only ashford, bright, goyder, little-para, mitchell, napier. 2016 redistribution | needs sa2014 booths (and the complete 2014 file) |

### 2.4 Census (`output/census-features.csv`, vintage file `output/census-features-vintage.csv`)

VERIFIED: the vintage file has **no rows for any of the five pairs** (state pairs present: nsw2019/2023/2027, qld2020/2024, sa2022/2026, vic2010-2026, wa*). `scripts/build_census_features_vintage.R:222` builds `PAIRS` from `all_election_pairs()` (+ vic2010 + pairs in the old file), so adding the pairs to the list and rebuilding picks them up **if the target election has seats in `candidacies.csv`** (l.223-227); and `read_2011()` / `read_2006()` (l.108-125) read the 2011 and 2006 state-district tables for NSW/Qld/SA, so no new fetch is expected (the code path exists; I did not run it, UNVERIFIED). Expected vintage: nsw2015, qld2015, sa2014 -> 2011 census; qld2017, sa2018 -> 2016 census (taken Aug 2016, before both polling days). These will be name-matched, not exact, wherever the district list changed (qld2017 16 new seats, sa2018 10, nsw2015 8), with the fallback rows flagged LOOKAHEAD as for wa2001. The old `build_census_features.R` `VINTAGE`/`EXACT` maps (l.129-146) are the pre-vintage file and need no edit if `AUSPOL_DEMO_RESID` reads the vintage file (UNVERIFIED which file `demographic_residual_apply` reads under the published setting; check before assuming).

### 2.5 Leaders

`external/reference/leaders/leaders-supplement.csv` (loaded by `read_leaders()`, commit 59a953c) already has **all five targets**: nsw2015, qld2015, qld2017, sa2014, sa2018 (also nsw2011, qld2012, sa2010 and earlier). VERIFIED by election label; row quality not audited. `leaders.csv` has none of them, so the supplement is used. Leader bonus is applied to the target only. Already in the rebuild baseline, so adding these pairs does not move the pooled leader fit again.

### 2.6 Retirements, departed-successor rates, seat context, council history

- `retirements.csv`: nsw2015 19, qld2017 7, sa2018 12 present; **qld2015, sa2014 absent** (1.11).
- `output/retirement-derived.csv` (built by `build_retirement_derived.py`, not in the rebuild script; rerun by hand): no rows for these five (pairs start at nsw2019/qld2020/sa2022).
- `output/departed-successor-rates.csv`: rows for nsw2015, qld2017, sa2018 exist (1 each); **qld2015, sa2014 missing**, and the harness throws "no rows for target" if the flag is on and the row is absent (vic2010 doc 2.24). `fit_departed_successor_rates.R:149` enumerates `names(election_dates())`, so adding the dates (1.1) and rerunning creates the rows.
- `output/seat-context.csv`: no rows for the five (starts nsw2019 etc.); `build_seat_context.R` needs the candidacies and the dates.
- `output/council-history.csv`: rows for nsw2015 540, qld2017 453, sa2018 264 (keyed by candidacy election); qld2015, sa2014 absent. `R/council_features.R:19` already documents that **sa2018 has `council_coverage` FALSE** (no council election in its window), so council features are NA for it by design.
- `output/seat-tpp-estimates.csv`: nsw2015 93, qld2017 93, sa2018 47 present (matters only for the seat-swing port, off).
- `output/level-recent.csv` / `level-pred.csv`: built from `all_election_pairs()` / `build_level_pred.R` (1.4); today only the 2019+ pairs.
- By-election tables (`external/reference/byelections`): NSW 2013-2018 present (14 winners rows, 45 candidate rows in 2010-18 for nsw/qld/sa); Queensland has only Toowoomba South 2016-07-16; **SA has none in 2010-2018**. From memory (UNVERIFIED) the file is missing Qld Redcliffe 2013 and Stafford 2014 and SA Port Adelaide 2012 and Frome 2014. `byelections_between` throws for an undated election (1.1 fixes) and the prior is inside a `tryCatch`, so gaps are silent (vic2010 doc 2.13).

### 2.7 Seat files (`load_seats`)

The anchor clone's `analysis/seats/` has only 2019nsw, 2023nsw, 2027nsw, 2022sa, 2026sa, 2024qld (VERIFIED `ls`). Per harness: **Qld has a fallback to 2024qld.txt** (`backtest_candidate_qld.R:875-885`), so qld2015/qld2017 run (cosmetic loss: seat-swing spread comes from 2024). **SA `l.1037` and NSW `l.387` have no fallback** and will error ("seat file missing") for sa2014, sa2018 and nsw2015. This is the "seat-file fix" the coverage inventory lists; copy the Qld `tryCatch` shape and print which file was used. NSW also reads `2019nsw.txt` for `next_seats` (present).

### 2.8 Salience (`output/salience-v6.csv`)

No rows for any of the five (VERIFIED: elections present are fed2007-2025, nsw2019/2023, qld2020/2024, sa2022/2026, vic2010-2026, wa2005-2025). A Google Trends fetch is needed for each target (one per pair; the prev side is not fetched), using the `fetch_salience_v6_vic2010.R` pattern; 2010-2018 are inside Trends' data era (starts ~2004). Throttling risk per CLAUDE.md. Without it the pair falls to "arm C plain" and a `BV0v!`-style surge failure line (vic2010 doc 2.9), i.e. NOT scored like nsw2019/qld2020/sa2022. Decide fetch vs record "no salience" before scoring.

### 2.9 Polls

`docs/POLL-REGISTRY.md` is generated from `all_election_pairs()` (via `build_poll_registry.R:24`), so these pairs are absent from it today. I ran `load_polls()` read-only for each window under default settings (not necessarily the published `layered` setting, UNVERIFIED equivalence), counting polls strictly after the previous polling day up to polling day:

Polls with Labor and Coalition primaries, by origin (n = polls in the whole cycle; f30 = final 30 days). "ae_only" = AE's numbers only. Lower ae_only is better.

| Pair | n | f30 | ae_only | ours (any form) | Note |
|---|---|---|---|---|---|
| nsw2015 | 68 | 13 | **68** | 0 | all AE; `pb_llm_polls.csv` has 52 rows for cycle nsw2015 (and 39 for nsw2011) that are not yet layered in |
| qld2015 | 74 | 12 | 36 | 38 | `pb_llm_polls.csv` cycle qld2015 49 rows |
| qld2017 | 65 | 6 | 33 | 31 (+1 AE dispute) | pb_llm 42 rows; a Poll Bludger tracker page exists for qld2017 and sa2018 (`fetch_pollbludger_tracker_polls.R:8-11`, not fetched, "not scored") |
| sa2014 | 21 | 2 | 17 | 4 | pb_llm 21 rows |
| sa2018 | 41 | 3 | 32 | 9 | pb_llm 12 rows |

The load emitted the "More than 2% of modern polls have FP sums far from 100" warning for two regions (not attributed to a region; UNVERIFIED which). The coverage program wants non-AE sources first; scoring these before the Poll Bludger/Wikipedia layering lands bakes in the AE dependence (vic2010 doc 7.5).

## 3. Blockers vs silent fallbacks, per pair

"Blocker" = the run stops or cannot start. "Silent" = log line only (see vic2010 doc section 3 for the shared list: v6 skip, `candidate_returns` NULL, by-election prior `tryCatch`, census skip, salience absent).

| Pair | Blockers (loud) | Silent fallbacks / decisions |
|---|---|---|
| **nsw2015** | no `nswec-2011-nsw-firstprefs.csv`; no election date nsw2011; no nsw2011 candidacies; harness transfers read (nsw2011 not in the shared file); no `2015nsw.txt` and no seat-file fallback (l.387); statewide date map key (l.397); 92-vs-93 / 7-vs-8 district change with no notional (stop or relaxed rule) | notional skipped silently if `STATE_REDISTRIBUTIONS` lacks it; nsw2011 transfers are thin (42 seats); level blend off until nsw2011 is dated; 68 of 68 polls are AE's |
| **qld2015** | no qld2015 winners; no qld2012/qld2015 candidacies (names need ECQ XML); `N_DISTRICTS` 93 constant (89 seats) | flows: federal-2013 borrowed or a blend that does not exist yet; no exhaust path though the election is optional preferential (the Qld harness has none; borrowing fed flows overstates transfers, the coverage inventory cites a 0.194 log-score penalty for the NSW analogue); AE-only polls 36 of 74 |
| **qld2017** | needs qld2015 candidacies and FP (FP is on disk); 89 -> 93 seats with no qld2015 booth data, so no notional: `N_DISTRICTS` stop; winners live in `ecq-2017-qld-winners.csv`, not the file the harness reads | flows as qld2015 (blend from qld2015, estimate `n_seats` 11); seat file falls back to 2024 |
| **sa2018** | sa2014 FP is long-format, party codes unclassified, and 43 of 47 districts; no sa2014 candidacies; no sa2018 winners row in `ecsa-sa-winners.csv`; `!= 47L` stop (2016 redistribution, no notional); no seat-file fallback (l.1037) | flows fed2016 vs blend; `council_coverage` FALSE so council features NA by design; AE-only polls 32 of 41 |
| **sa2014** | sa2010 FP 45 of 47 and sa2014 FP 43 of 47 (two scrapes to complete, inferably 6 districts); no winners (derive from `tcp` table once complete); no sa2010/sa2014 candidacies (two different name formats, comma vs no comma); 2012 redistribution renames, no notional; no seat-file fallback | weakest flow estimate (sa2010 `n_seats` 5); 17 of 21 polls AE-only; no SA by-elections in the table |

## 4. Effects on existing pairs when these join `all_election_pairs()`

Same mechanism as vic2010 doc section 4: every fit that pools `all_election_pairs()` time-forward gains each new pair's cases for every
LATER target, and candidacies for the previous elections change history-based features (new_ind_shrink, departed_defectors,
reentry_majors_fill, ind_person, build_seat_context) for later pairs of the SAME state. Unaffected by construction: pairs dated on or
before the earliest new pair. Earliest new pair by date: sa2014 (2014-03-15); then qld2015 (2015-01-31), nsw2015 (2015-03-28), qld2017
(2017-11-25), sa2018 (2018-03-17). So fed2007, fed2010, fed2013, the wa pairs up to wa2013, and vic2010 are unchanged by all five; every
other scored pair moves (count and size UNVERIFIED; the vic2010 baseline must be frozen first, step 6.1). State-local effects: adding
**nsw2011 candidacies** moves nsw2019/2023 (new_ind_shrink `hist`, departed history); **qld2012/2015** move qld2017 (if added first),
qld2020, qld2024; **sa2010/2014** move sa2018, sa2022, sa2026. Add candidacies as their own landing with its own before/after
(vic2010 doc 6, step 3), then the pair list.

Rebuild plumbing: `run6()` needs the five specs (1.8); wall time grows by five harness runs (each of nsw/qld/sa is a separate process, ~1 unit each; profile one before a 20-minute launch, ESTIMATE). Memory slot logic needs no change.

## 5. What must be BUILT (does not exist today)

1. Per-pair seat-count handling in the Qld (`N_DISTRICTS`), SA (`47L`) and NSW (`93L`) harnesses, or notionals, plus a loud coverage line (matching seats of seats) like Vic's.
2. Seat-file fallback in the SA (l.1037) and NSW (l.387) harnesses, copying Qld's.
3. Candidacies loaders: nsw2011 (from `nswec-2011-nsw-candidates.csv`), qld2012 and qld2015 (ECQ XML), sa2010 and sa2014 (ECSA long-format file, after completion).
4. Complete the SA scrapes (sa2010 +2 districts, sa2014 +4) and convert to the harness shape; derive sa2014 winners from the `tcp` table; add sa2018 winners rows (file exists) and qld2015 winners; merge or read `ecq-2017-qld-winners.csv`.
5. `nswec-2011-nsw-firstprefs.csv` (derive) and a harness-side rbind of the 2011 transfers.
6. Booth parses for notionals: nsw2011, qld2015, sa2010, sa2014 (then `STATE_REDISTRIBUTIONS`, `build_state_notionals.py` `PAIRS`).
7. The blended-flow reader (section 2.2): a function from `flows-estimated.csv` plus time-forward blend weight to something `build_flow_matrix`'s consumers accept, with an exhaust path for Qld 2015 at least (the file carries exhaust 28-52% for qld2012/2015). Not built; the learned weight is not implemented.
8. Salience fetches (five targets), retirements pages (qld2015, sa2014), the 2011/2016 census rows (rebuild of the vintage file), `departed-successor-rates` rows (rerun), `retirement-derived.csv` (rerun by hand).
9. Regenerate `DATA-REGISTRY.md`, `MODEL-REGISTRY.md`, `POLL-REGISTRY.md`; counters 23 -> 28.

## 6. Recommended order

1. **nsw2015.** Only pair whose previous-election flows are real published data and whose candidate names, winners and target FP are on disk. Remaining work: derive one FP file, add the date and candidacies, harness plumbing (transfers rbind, date key, seat-file fallback), and the 7-vs-8 district handling. If the notional is deferred, score the 85 matching seats and say so.
2. **qld2015.** Same 89 seats both ends (no notional), seat-file fallback exists, FP on disk; needs winners, names (ECQ XML), the per-pair seat constant, and the flow-source decision. Doing it first also builds the qld2015 candidacies and FP that qld2017 needs.
3. **sa2018.** Target data is the best of the SA set (Wikipedia FP + winners, candidacies); the cost is the incomplete, long-format sa2014 prior and a 2016 redistribution. Pete's decision on flows (fed2016 as qld2020 did, or blend).
4. **qld2017.** Everything on the target side exists; the cost is the 89 -> 93 redistribution (needs qld2015 booths from the ECQ XML) and the winners file wiring. Do after qld2015 so its candidacies exist.
5. **sa2014.** Most work: two incomplete scrapes, no winners, two name formats, a redistribution, the weakest flow estimate (n_seats 5), and only 4 of 21 polls not AE's.

Landing sequence per vic2010 doc 6: dates and inert plumbing first, then candidacies (own before/after), then score each pair in isolation, then add to `all_election_pairs()` last, with the seven pairs dated before 2014-03-15 as the byte-identical guard and a deliberately broken date as the proof the diff can fail.

## 7. Decisions needed from Pete

7.1 Seat-count rule for redistribution pairs: build notionals first (four booth parses) or score matching seats only and log the coverage.
7.2 Flow source for qld2015, qld2017, sa2014, sa2018: federal-before-election (the qld2020/sa2022 precedent, already runs) or the blended estimate (needs the reader in section 5.7); and whether the Qld harness gets an exhaust path for the optional-preferential years.
7.3 Salience fetches: five Google Trends runs, or score these pairs "no salience" and flag it.
7.4 Whether to land `nswec-2011-nsw-transfers.csv` into the shared NSW transfers file (moves later NSW flow models) or rbind inside the harness only.
