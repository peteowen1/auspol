# Checklist: adding the vic2010 pair (target vic2010, previous vic2006) so it is scored exactly like vic2014 (2026-10-13)

Read-only investigation, nothing edited. "VERIFIED" = read in code or run read-only on this machine today;
"UNVERIFIED" = inferred, not run. Line numbers are against `dev` at a2ff74e.

## 0. Headline findings

1. **Existing pairs have ALREADY drifted today, before any vic2010 work.** `htv_observed_splits()`
   (`R/htv_flow.R:43`) globs every `*-transfers.csv` in `external/elections/`. The files that landed in wave 2a
   (`vec-2006-vic-transfers.csv`, `nswec-2011-nsw-transfers.csv`, `aec-fed-2001-transfers.csv`) are now in the
   how-to-vote card fit (`AUSPOL_HTV_FLOW=1` is published). VERIFIED by running `fit_htv_flow_rows()` with and
   without them: greens-above ALP share vic2018 34.14 -> 32.33, vic2022 37.67 -> 35.32, vic2026 37.15 -> 35.27;
   labor-above moves 0.1 to 0.3. Only vic2018, vic2022 (and live vic2026) have a card entry, so only they move.
   Any "existing pairs unchanged" test must take its baseline AFTER deciding what to do about this (see 7.1).
2. **Adding the pair to `all_election_pairs()` WILL change 17 scored later pairs** (and the live vic2026 and
   nsw2027 forecasts), because a dozen fitted constants and the xgb training sets pool over that list
   time-forward (section 4). Unchanged by construction: fed2007, fed2010, wa2001, wa2005, wa2008 (all dated on or
   before 2010-08-21, vic2010 is 2010-11-27).
3. **Hard blockers (loud):** no `vec-2006-vic-firstprefs.csv`; `vic2006` absent from `output/candidacies.csv`
   and from `election_dates()`; `level-pred.csv` has no vic2010 row (`fit_xgb_primary_v6.R:324` stops).
4. **Silent fallbacks (log line only, no failure):** listed in section 3; the worst are the level recent-poll
   blend switching off for vic2010 (3.2), the by-election prior failing inside a `tryCatch` (3.3), the v6 stage
   skipping the pair so the harness keeps base_pred (3.1), and the demographic correction skipping (3.5).

## 1. Hard-coded pair lists, date tables and per-pair constants

Every grep hit for `vic2014`, `vic2010`, `vic2006`, plus `2014` near "vic". "Add" = vic2010/vic2006 entry needed.

### Needed for the pair to run (in the rebuild chain)

| # | File:line | What is there | Action |
|---|---|---|---|
| 1.1 | `R/election_dates.R:30` | `vic2010` present, `vic2006` absent | Add `vic2006 = "2006-11-25"` (matches `scripts/extract_pollbludger.R:162`; coverage doc says 31 of 38 dates were checked against Wikipedia, whether vic2006 was one of them is UNVERIFIED). `tests/testthat/test-election_dates.R:1-6` fails without it once the pair exists (good guard). |
| 1.2 | `R/reentry_prior.R:876-878` | `all_election_pairs()`: vic2014, 2018, 2022 | Add `list(election = "vic2010", prev = "vic2006")`. This is the switch that changes later pairs (section 4); do it LAST (section 6). |
| 1.3 | `scripts/backtest_candidate_vic.R:259-262` | `PAIRS` has `from=2010,to=2014` first | Add `list(from = 2006, to = 2010)` first. Header comments at :1-12 and :253 say "two/three pairs": update. `AUSPOL_VIC_PAIR` (:271) derives its allowed values from `PAIRS`, so no change. |
| 1.4 | `scripts/backtest_candidate_vic.R:287` | `VIC_DATE` has 2014, 2018, 2022 | Add `"2010" = "2010-11-27"`. Missing key = `VIC_DATE[["2010"]]` throws at :345 (subscript out of bounds) AND :412; loud. |
| 1.5 | `scripts/backtest_candidate_vic.R:862-871` | surge-v2 training list (`v2_pairs`), vic2022 only | No change (membership is deliberate, filtered by date at :875). vic2010 as target trains on fed pairs before 2010-11-27 only (fed2010 prev fed2007: dated 2010-08-21, so it IS in). |
| 1.6 | `scripts/fit_xgb_primary_v6.R:66-68` | `PAIRS` with `vic2014/prev vic2010` | Add `list(election="vic2010", prev="vic2006", region="vic")`. If omitted: no features rows, no as-at model, no predictions (3.1). `SAL_PAIRS` (:101) derives from it. Other `fit_xgb_primary*.R` variants (`:28-29` in `fit_xgb_primary.R`, `_v2`, `_v3`, `_v4`, `_v5`, `_v7`) are not in the rebuild: leave. |
| 1.7 | `scripts/build_level_pred.R:42,53` | `DATES` / `PREV` maps | Add `vic2010 = "2010-11-27"` and `vic2010 = "vic2006"`. Needs `st_of("vic2006")` (candidacies, 1.10). Without it `fit_xgb_primary_v6.R:324` stops: "no predicted statewide for vic2010" (loud). |
| 1.8 | `scripts/build_retirement_derived.py:29` | `PREV` dict | Add `'vic2010':'vic2006'`. `fit_xgb_primary_v6.R:642` reads `output/retirement-derived.csv`; not in the rebuild script, so it must be rerun by hand. Falls back to highest primary where no `elected` flags (same as vic2014). |
| 1.9 | `scripts/build_census_features.R:131-134` | `VINTAGE` / `EXACT` maps | Add vic2010 (vic2014 uses vintage "2021", non-exact; 2010 is on the same pre-2013 boundaries so it needs the same reaggregation as vic2014 or a 2006/2011 census mapping, see coverage doc 11:50 entry). Without rows: demographic correction skips (3.5). |
| 1.10 | `scripts/build_candidacies.R:711-760, 863` | vic loop `for (y in c(2010,2014,2018))`, parser reads district result HTML; winners loop `c(2014L,2018L,2022L)` | Add vic2006. The 2006 raw is DISTRIBUTION pages (`external/reference/vec/raw/2006/*dop*`), not result pages, so the existing parser may not apply. Easier: a reader for `external/elections/vec-2006-vic-candidates.csv` (cols `seat,candidate,party_code,party_name,fp,class`; 88 seats, VERIFIED) like the vic2022 branch at :455-474. Names are "SURNAME, Given"; the sa2018/sa2022 name-format trap is documented in `build_retirement_derived.py:13-18`, so measure the match rate to vic2010 (expect 15-26% returners). Winners: `vec-2010-vic-winners.csv` EXISTS (88 rows) but is NOT loaded (:863), which is why vic2010 has zero `elected` flags; loading it would change vic2014 (section 3.6). |
| 1.11 | `scripts/fit_xgb_flows_v1.R:171` | identity-feature `PAIRS` | Optional: adding `(vic2010, vic2006)` gives vic2010 events `dest_same` features, but changes the training rows of every later flow model (4). Leave out for the first cut and say so. |
| 1.12 | `R/quick_arm.R:31` | `mk("vic","AUSPOL_VIC_PAIR", c(2014,2018,2022))` | Add 2010 so `--pairs=all` covers it. `scripts/quick_arm.R:225` AEF-7 set stays as is. |
| 1.13 | `scripts/check_poll_coverage.R:50-59` | `scored` table, `stopifnot(nrow(scored) == 22)` | Add vic2010/prev vic2006 and change 22 to 23 (outside the rebuild). |

### Needed for display, ledger, side tools (not in the rebuild; update or consciously skip)

`scripts/pool_results.R:52`, `scripts/_extract_flowrun.R:10-15` (per-pair seat counts), `scripts/compare_zero_order.R:39`,
`scripts/build_level_components.R:63,74` (only with `AUSPOL_XGB_RAW_LEVEL=1`, off),
`scripts/build_leader_ratings.R:38` (display only), `scripts/build_state_swing_prior.R:61` (already has vic2010),
`scripts/estimate_statewide_cov.R:121` (already has 2010), `scripts/fetch_salience.R:43`, `scripts/fetch_salience_v6.R:107,136`
(see 2.9), `scripts/fetch_leaders.R:23` and `scripts/fetch_retirements.R:55-56` (retirements already has vic2010: 8 rows),
`scripts/fetch_seat_polls.R:73`, `scripts/analyse_incumbent_transfer.R:25`. The generated registries
(`docs/DATA-REGISTRY.md`, `MODEL-REGISTRY.md`, `POLL-REGISTRY.md`) must be regenerated after the change. The AEF-7 ledger
(`scripts/build_aef_comparison.R:16`, `build_aef7_ledger_data.R:37`) lists its own seven pairs and is unaffected.

### Counters that go from 22/23 to 23/24

`scripts/check_poll_coverage.R:59` (22), comments saying "22 pairs" in `scripts/build_aef_comparison.R:230`,
`docs/CONSTANTS.md` / CLAUDE.md prose ("all 22", "2,050 seat-elections", "681 AEF-7"). `scripts/pool_backtests.R:136`,
`pool_sharedetail.R:259`, `promote_rebuild.R:170`, `promote_arm.R:168` take `.known` from `all_election_pairs()` and
REFUSE (PB2c!) if a known pair has no backtest file, so once 1.2 is in, vic2010 must be scored in every run that publishes.
`AUSPOL_SKIP_PAIRS` default is `wa2021` (`scripts/rebuild_forecasts.sh`), no vic change.

## 2. Inputs the Vic harness loads for the pair (target vic2010, previous vic2006)

| # | Input | Where read | On disk for vic2010 / vic2006? | If missing |
|---|---|---|---|---|
| 2.1 | Previous first prefs `vec-2006-vic-firstprefs.csv` (`seat,party,votes`) | harness :310 `share_of()` | **MISSING** (`external/elections/` has `vec-2006-vic-{candidates,checks,transfers,transfers-detail}.csv` only). Source: build from `vec-2006-vic-candidates.csv` (`fp`, `class`), cross-check against `external/elections/archive/2006vic-firstprefs.csv` (same 88 seats as `vec-2010-vic-firstprefs.csv`, VERIFIED name-for-name; archive is AEF, last resort per the source rule). | `fread` error, loud. |
| 2.2 | Target first prefs `vec-2010-vic-firstprefs.csv` | :311 | present, 88 seats | n/a |
| 2.3 | Previous transfers `vec-2006-vic-transfers.csv` | :336-347 | present, 524 rows, 49 seats with rounds (`-checks.csv`: seats decided at a majority have none). Guard `stopifnot(nrow(tx) > 100L, election == vic2006)` passes. Flows for the other 39 seats fall to `build_flow_matrix` pooled/fallback rows, as in any pair. | n/a |
| 2.4 | Winners `vec-2010-vic-winners.csv` | :350 | present (88 rows) | falls to the 2026-seat-file branch (:358), which would be WRONG for 2010; file exists so not hit |
| 2.5 | Polling date | :287, :345-346, :412 | see 1.4 | loud |
| 2.6 | Statewide forecast (`AUSPOL_FORECAST_MODE=1`) | :412 `forecast_statewide_or_oracle(..., on_fail="skip")` | Polls: 37 vic polls in 2006-11-25..2010-11-27, all with ALP+LNP, 9 in the last 30 days; origins AE 34, Wikipedia 3 (VERIFIED, `load_polls("vic")`). `fundamentals_tf("vic",2010)` = 46.05 and `projection_mix_tf` run (VERIFIED). The full `forecast_statewide_for` fit was NOT run. Anchor-clone cycles file supplies the window, no `election_dates()` dependency (UNVERIFIED for vic2006 row). | **SILENT SKIP**: `:413` `next` after "pair SKIPPED in forecast mode, not scored". The pair then simply does not appear; pooling prints PB2c! |
| 2.7 | Anchor seat files (`load_seats`) | only `PORT=1` (:731, off) and v6 (`fit_xgb_primary_v6.R:376`) | anchor has only `2022vic.txt`, `2026vic.txt` (VERIFIED). vic2014/2018 already run without; vic2010 identical | v6 fills NA, prints a coverage line. Same as vic2014. |
| 2.8 | Seat context (`output/seat-context.csv`, `AUSPOL_SEAT_CONTEXT_FILL=1`) | v6 :396-410 | built by `scripts/build_seat_context.R` from candidacies; needs vic2006 candidacies and (1.1) dates | no rows for the pair: incumbent/retiring stay NA, silent |
| 2.9 | Salience (`output/salience-v6.csv`) | `salience_permit_for` (:600), surge-v2 hazard (:861-926) | vic2014 has 365 rows, vic2018 255, vic2022 418; **vic2010: none** (Google Trends fetch needed, `fetch_salience_v6.R` has no vic2010 entry; throttling risk noted in CLAUDE.md). | `permit` NULL -> "arm C plain"; surge hazard `tryCatch` -> "BV0v! surge-v2 failed". **vic2010 would NOT be scored like vic2014 here.** Decide: fetch it, or record the pair as "no salience". |
| 2.10 | Candidates / incumbency / returners (`candidate_returns(.ea,.eb)`, `personal_prior_vote`, `split_slope_context`) | :451, :551, :550 | need vic2006 rows in `candidacies.csv` | `tryCatch` -> "BV1c! conditional slopes unavailable" / "BV1p! personal_prior_vote() FAILED; class-level bases kept": SILENT fallback to plain slopes |
| 2.11 | Leaders (`leaders.csv`, `AUSPOL_LEADER_SEAT=1`) | `leader_seat_apply` | file has vic2014 (23 rows), vic2018, vic2022, vic2026; **no vic2010 or vic2006**. `deciding-runs/leaders-backfill-proposed-2026-10-13.csv` is a proposal. | bonus not applied to vic2010, silent. Adding vic2010 rows changes later pairs' leader bonus (`R/leader_seat.R` pooled fit), so land it separately. |
| 2.12 | Census (`output/census-features.csv`, `AUSPOL_DEMO_RESID=2`) | `demographic_residual_apply` | rows for vic2014/18/22/26 only | "DR1! no census rows for vic2010; correction SKIPPED" (R/demographic_residual.R:~235), silent in the score. Also the existing look-ahead problem noted in the coverage doc (2016/2021 vintage on old pairs) applies. |
| 2.13 | By-election tables | harness :322-335 (supplementary), `byelection_prior` :555 | `byelection-winners.csv` has Kororoit 2008-06-28 and Altona 2010-02-13; `byelection-results.csv` has NO Vic rows before 2015 (so both are unmatched, same as Niddrie/Melbourne/Lyndhurst for vic2014). `byelections_between` does `dates[[election_from]]` (`R/byelection_prior.R:51,187`): **throws for vic2006 until 1.1 is done**. | caught by `tryCatch` at :556: "BF0b! by-election prior FAILED, prior kept". SILENT. |
| 2.14 | Level recent-poll blend (`AUSPOL_LEVEL_RECENT=decay`) | inside `forecast_statewide_or_oracle` -> `level_recent_apply` | needs vic2006 date: `.lr_prev_date()` (`R/level_recent.R:332-337`) returns NA without it, so `ra` is all-NA and `w = 0`. | **SILENT: blend OFF for vic2010 only**, log prints "w 0.00". Fixed by 1.1. |
| 2.15 | `output/level-recent.csv` (k / half-life fit table) | `level_recent_decay_fit` (:183-199) | built by `scripts/build_level_recent_table.R` (rebuild stage 5b) from `all_election_pairs()`; vic2010 row needs vic2006 candidacies (`share(p$prev)`) and 1.1; vic rows today: 3 per election (ALP/GRN/LNP) x 3 elections | trend NA via `tryCatch`, row dropped, reported only in the LT1 line (stop only if fewer than 15 scoreable elections) |
| 2.16 | `output/level-pred.csv` | v6 :318-324 | no vic2010 rows | **stop**, loud |
| 2.17 | xgb as-at primary predictions | `xgb_primary_override` (`R/xgb_primary_override.R:88`) | `xgb-primary-asat-predictions.csv` has no vic2010 | "XG1! no xgb predictions for vic2010; shares unchanged" = silently scored on base_pred only |
| 2.18 | As-at flow models (`AUSPOL_FLOW_ASAT=1`, `FLOW_TF=1`, tag tf2) | `xgb_flow_conditional_override_for` (`R/xgb_flow_override.R:29-38, 290-330`) | `xgb-flows-v1-asat-vic2010.model` and the tf2 equivalent EXIST (ls) because vic2010 transfers are already in the flow feature table | n/a for the target. NB the model was trained when vic2006 was not in the table (4.3). |
| 2.19 | How-to-vote card | `htv_flow_override` | no vic2010 entry (vic2014 has none either) | "HTV0 no how-to-vote entry for vic2010 -- flow rows unchanged": identical to vic2014 |
| 2.20 | Notional prior | `state_notional_prior("vic",2006,2010)` | vic2010 not in `STATE_REDISTRIBUTIONS` (`R/state_notional.R:49-59`) | "SNP0 no redistribution before this election -- actual prior kept". Correct if 2006 and 2010 used the same districts: names identical 88 = 88 (VERIFIED), geography not checked. `scripts/build_state_notionals.py:40` needs no entry. |
| 2.21 | Seat-swing port (`SEAT_SWING_PORT=2`) | `seat_swing_port_*` | `fed-swing-transposed.csv` has vic 2018/2022/2026 only; `seat-tpp-estimates.csv` has vic2010 but no vic2006 | coefficient 0 / no adjustment, as vic2014. Adding a `seat-tpp-estimates` vic2006 later gives vic2010 a cycle in later pairs' port fit (`R/seat_swing_port.R:36-50`). |
| 2.22 | Council history, endorsements | v6 | `council-history.csv` already has vic2010 (502 rows); endorsements only vic2022/2026 | same as vic2014 |
| 2.23 | Seat polls / blend | `seat_poll_blend_apply` | none for vic2010 | no-op, as vic2014 (UNVERIFIED for vic2014) |
| 2.24 | Departed-successor rates (`AUSPOL_DEPARTED_SUCCESSOR=1`) | harness :449 `departed_successor_rates(.eb)` | `departed-successor-rates.csv` already has a `vic2010,(none)` row (fitted, no successor cells) | would throw ("no rows for target") if absent; present, so fine |

## 3. Silent-fallback inventory for the new pair (what makes it NOT like vic2014)

3.1 Pair skipped by v6: `fit_xgb_primary_v6.R:154` ("XG6! no state level for vic2010 -> skip") when `candidacies.csv` lacks
    vic2006 or vic2010; `:292` when sharedetail lacks the pair. Then no as-at model and 2.17 applies.
3.2 `candidate_returns` / `personal_prior_vote` failure: `NULL` in v6 (`:272, :288`) and caught in the harness (2.10).
3.3 `byelection_prior` failure caught (2.13). Same for `fit_defector_discount`, `fit_minor_defector_discount`,
    `fit_departed_origin_return`, `fit_major_departed_slope` (all `tryCatch` in the harness at :498, :532, :568, :585).
3.4 Level blend off (2.14); `level-recent.csv` row dropped (2.15).
3.5 Demographic correction skipped (2.12); leader bonus absent (2.11); salience absent (2.9); seat context NA (2.8).
3.6 `elected` flags: vic2010 and vic2006 carry none (winners loader skips them, 1.10), so vic2010 has no
    returning-member logic, exactly as vic2014 has none today (`scripts/build_candidacies.R:1396-1407`). If the 2010
    winners file is later loaded, vic2014 itself changes. Keep out of this change.
3.7 Pair-fit helpers return NULL for a pair with empty candidacies (`R/candidate_returns.R:1176` `return(NULL)`;
    similar in `R/split_slope.R`): adding 1.2 before vic2006 is in `candidacies.csv` makes the pair a silent no-op
    in every pooled fit instead of an error.

Required guard when building: print per-input coverage for vic2010 and compare to vic2014's line for line; any
input present for vic2014 and not vic2010 is listed in the PR, not left to the log.

## 4. Functions that read the FULL `election_dates()` list or `all_election_pairs()`

### 4A. Would adding `vic2006 = "2006-11-25"` to `election_dates()` change an EXISTING pair?

Mostly no, because `elections_before()` (`R/time_forward.R:30-47`) already dates an undated label by mid-year of its
4-digit suffix (2006-07-01). Only rows that exist matter, and `candidacies.csv` has NO vic2006 or vic2002 rows
(VERIFIED: vic2010 502, 2014 545, 2018 507, 2022 731, 2026 501). Per function:

| Function | Reads | Effect of the DATE alone | Effect once vic2006 candidacies exist |
|---|---|---|---|
| `R/ind_person.R:47-49` | previous election = latest dated earlier election in corpus | none (vic2010 is still latest for vic2014+) | vic2010 target gets vic2006 as prev (intended). `:76` `elections_before(c_election, .tg)` cross-seat history gains vic2006 rows for every later vic target (changes) |
| `R/new_ind_shrink.R:132-150` | `earlier` by `elections_before`; prev by date | none | `hist` (people with ANY earlier row) gains vic2006 candidates, so more vic2014+ independents count as "returning": CHANGES vic2014, 2018, 2022 even without the date |
| `R/level_recent.R:183-199, 332-337` | `.lr_prev_date` | vic2010 target gets a prev date (needed); vic2014+ unchanged (prev stays vic2010) | k fit gains the vic2010 row |
| `R/byelection_prior.R:51,187` | `dates[[from]]` | vic2010 pair stops throwing; others unchanged | none |
| `R/candidate_returns.R:1529-1545` (`departed_defectors`) | major-party history `.d < d_from` | none for vic2014+ (history before vic2010 = nothing today) | **vic2014 pair gains vic2006 major-party history** (`align_person_keys(H0, P0)`) |
| `R/reentry_prior.R:727-745` (`reentry_majors_fill`) | `els` with a date before target; undated elections are dropped (`!is.na(edate)`) | none | **vic2014+ (and live vic2026) gain vic2006 history for the majors re-entry carry** |
| `scripts/build_seat_context.R:31-62` | `edate`, "election before the previous one" `ppv` | none | **vic2014 `soph_party` changes**: today vic2006 is undated so `pp_class` is NA for vic2014; with both date and rows it becomes real. Feeds v6 only where the seat file is NA (always, for vic) |
| `R/seat_swing_port.R:34-50` | `prior` = same-region earlier dated elections | vic2010 gets prior vic2006, but `seat-tpp-estimates.csv` has no vic2006, so the merge is empty and the cycle is dropped; no change today | change if a vic2006 `seat-tpp-estimates` is added (every later vic and cross-state port fit gains the vic2010 cycle) |
| `R/breakout_mix.R:233,353,433,466` | frame dates | none (`AUSPOL_BREAKOUT_MIX=0` published) | none |
| `R/xgb_flow_override.R:29, 298, 328` | age weights, as-at model existence | none; hard error `"no election date for"` if a flow-table election is undated, which is what happens as soon as `fit_xgb_flows_v1.R` re-reads `vec-2006-vic-transfers.csv` without 1.1 | see 4C |
| `scripts/fit_xgb_flows_asat.R:29-31`, `fit_xgb_flows_tf.R:48-50` | every election in the flow feature table | **stop** "election_dates() has no date for: vic2006" if the feature table is regenerated first | see 4C |
| `scripts/fit_departed_rate_asat.R:89`, `fit_departed_successor_rates.R:149` | `names(election_dates())` as targets | adds a vic2006 target row to their outputs; other rows unchanged | later targets' fits gain vic2006 cells (departed-rate history) |
| `R/fundamentals_tf.R:66-67` | election_dates in a memo key | memo invalidated, numbers unchanged | none |
| `scripts/fetch_pollbludger.R:90`, `build_poll_registry.R:24`, `check_poll_coverage.R`, `screen_*`, `diag_*`, `audit_*` | iterate or look up dates | vic2006 becomes visible to them (fetch script would fetch vic2006 posts) | tools only |

So the date by itself is inert for existing scores; **the vic2006 CANDIDACY rows are what move vic2014/2018/2022**
(`new_ind_shrink`, `departed_defectors`, `reentry_majors_fill`, `build_seat_context`, `ind_person`, cross-seat vote,
council history). That is a data change to existing Victorian pairs independent of the pair list, and needs its own
before/after (section 6, step 3).

### 4B. Fits that pool over `all_election_pairs()` time-forward (adding vic2010 to the list changes later targets)

`R/candidate_returns.R:1172` `fit_defector_discount`, `:1317` `fit_sitting_minor_level`, `:1412` `fit_minor_defector_discount`,
`:1573` `fit_departed_origin_return`, `:1653` `fit_minor_defector_conserve`; `R/split_slope.R:180, 349, 465, 611, 729`
(`fit_split_slopes`, `fit_conditional_slopes`, `fit_major_conditional_slopes`, `fit_dispersion_slopes`,
`fit_major_departed_slope`: the major slopes are published, `AUSPOL_MAJOR_DEPARTED=1`, `AUSPOL_MAJOR_SLOPE=1`);
`R/cross_seat_vote.R:63, 170` (`AUSPOL_CROSS_SEAT_VOTE=1`); `R/ind_person.R:95`; `R/level_recent.R:185`
(`AUSPOL_LEVEL_RECENT=decay`); re-entry GLM in all six harnesses (`backtest_candidate_vic.R:423`, `_fed.R:712`,
`_nsw.R:407`, `_qld.R:396`, `_sa.R:454`, `_wa.R:124`) and `scripts/fit_seats_full.R:1134, 1206` (live forecast);
`scripts/build_seat_context.R:48`, `build_retiring_mp_cases.R:41`, `build_level_recent_table.R:19`.
All keep only pairs dated strictly before the target (`fit_pairs_for`), so the **17 scored pairs dated after
2010-11-27** gain vic2010's cases: wa2013, fed2013, vic2014, fed2016, wa2017, vic2018, nsw2019, fed2019, qld2020,
sa2022, fed2022, vic2022, nsw2023, qld2024, wa2025, fed2025, sa2026 (plus unscored wa2021, and live vic2026, nsw2027).
Number of cases gained per fit is UNVERIFIED (depends on the 2006-2010 defector and re-entry counts); print it.

### 4C. Rebuild stages that train on vic2010 for later elections

- **Stage 4 as-at primary models** (`scripts/fit_xgb_primary_asat.R`, `output/xgb-primary-asat-manifest.csv`): vic2010 rows
  enter the training set of the same 17 targets. Training rows today (manifest): wa2013 3,111; vic2014 4,456; vic2018 6,329;
  nsw2019 6,857; vic2022 10,462; sa2026 13,755. vic2010 adds about 528 rows (vic2014 and vic2018 each have 528 sharedetail
  rows, vic2022 616; ESTIMATE for vic2010): +17% for wa2013, +12% for vic2014, +8% for vic2018, +3.8% for sa2026. vic2010's
  own model trains on fed2007, fed2010, wa2001, wa2005, wa2008 (5 pairs, 3,111 rows, identical set to wa2013's) so it clears
  `AUSPOL_ASAT_MIN_PAIRS=4`. Targets with fewer than 4 prior pairs (wa2001, wa2005, fed2007, wa2008) get no model, unchanged.
  Skip-if-current keys on training rows (`fit_xgb_primary_asat.R:~108`), so exactly these 17 refit.
- **Stage 3 `fit_xgb_primary_v6.R`**: new features rows, plus the v6 final production model (stage 5) trains on them too (live vic2026).
- **Stage 4b/4c flow models** (`fit_xgb_flows_asat.R`, `fit_xgb_flows_tf.R`): the training table is
  `output/xgb-flows-v1-features.csv`, written by `fit_xgb_flows_v1.R`, which is NOT a rebuild stage and which globs
  `vec-????-vic-transfers.csv` (`:43`). vic2010 is already in that table. **vic2006 is not, and enters the next time it is
  rerun** (the file is on disk now): every flow model dated after 2006-11-25 with at least 4 prior elections gains vic2006
  events (524 transfer rows, 49 seats). Event count not computed. Both stage scripts stop if vic2006 is undated (1.1).
- **Stage 5b level-recent table**: 3 rows (ALP, GRN, LNP) join the k / half-life fit of the 17 later targets.
- **Surge pairs**: `v2_pairs` (harness :862) unchanged, so no change from vic2010. HTV and QLD/WA-flow pools: see 0.1 and 2.19 (QLD flows
  default on but there are no ECQ rounds before 2017, so nothing pools into 2010; UNVERIFIED by running).

## 5. Rebuild plumbing (no code change expected)

`scripts/rebuild_forecasts.sh` `run6()` runs `vic` once for all its pairs (spec `vic`, no `AUSPOL_VIC_PAIR`), so the new pair
rides along with no edit; harness wall time grows by about one third (3 pairs to 4; ESTIMATE, profile one unit before a 20-minute
run). Stage 1 uses `AUSPOL_N_SIMS=2000`; pooling floors follow. `pool_backtests.R` takes the newest file per pair and its `.known`
list from `all_election_pairs()`. Pair count text and `AUSPOL_SKIP_PAIRS` need no edit.

## 6. Minimal safe order, and the test that proves existing pairs are unaffected

1. **Freeze a baseline.** Snapshot `output/` and record per-pair seat log loss for all 22 scored pairs from the last full
   stage-6 run (`scripts/restore_snapshot.sh` copies exist). Decide what to do about 0.1 first: either accept the HTV shift
   as part of the baseline (rerun stage 6 once with the new transfer files, THEN freeze), or exclude the new files from the glob
   (`R/htv_flow.R:43`) until a deliberate decision. Without this the later diff mixes two causes.
2. **Inert plumbing, no pair yet:** add `vic2006` to `election_dates()` (1.1); add the VIC_DATE entry (1.4); add the lists in 1.6,
   1.7, 1.8, 1.12, 1.13 that cannot run without the pair; build `vec-2006-vic-firstprefs.csv` (2.1) and register it
   in `MANIFEST.csv`. Run `devtools::test()` and `scripts/check_like_ci.R`. Expected: every pair byte-identical
   (4A: the date alone is inert). Prove it by rerunning stage 6 for `vic,fed,...` at AUSPOL_N_SIMS=5000 against the same-sims
   baseline and diffing `backtest-*-allprobs*.csv`; also diff once with a deliberately broken date (set vic2006 to 2030) to
   show the diff test can fail.
3. **vic2006 candidacies** (1.10) into `candidacies.csv` and the files built from it (`seat-context.csv`, `council-history.csv`,
   `retirement-derived.csv`, `level-recent.csv` row for vic2010 is built in step 4). This DOES change vic2014/2018/2022 (4A).
   Run the vic harness only (`AUSPOL_VIC_PAIR=2014,2018,2022`) via `scripts/quick_arm.R` with a before/after, print the
   `new_ind_shrink`, `departed_defectors`, `reentry_majors_fill` and seat-context counts, and record the shift as its own
   result. Pairs outside Victoria must be byte-identical (nothing there reads vic rows): assert on fed/nsw/qld/sa/wa.
4. **Score vic2010 in isolation:** add the harness PAIR (1.3) but NOT yet 1.2. Run `AUSPOL_VIC_PAIR=2010`, stage 1 to 6 for that
   pair only; check each input line in section 2 against vic2014's log and list every difference (salience, leaders, census, bye-election,
   level blend). Expect vic2010 scored 88 seats (`BV1` line) and the `< 70` floor (:829) not tripped.
5. **Add the pair to `all_election_pairs()`** (1.2) and run the full rebuild (stages 1-8, 20,000 sims, detached). Expected: fed2007, fed2010,
   wa2001, wa2005, wa2008 byte-identical (test this explicitly: `identical()` on their allprobs files); the 17 later pairs
   change, and the change is reported per pair with its SE, not as one pooled number. Seeds fixed, so a pair that changes with no
   listed cause is a bug.
6. Regenerate `DATA-REGISTRY.md`, `MODEL-REGISTRY.md`, `POLL-REGISTRY.md`; update `docs/NEXT-STEPS.md`, `PETE-ASKED-FOR.md`, counts in prose (22 to 23).

Done means: vic2010 scored on 88 seats with a log line for each section 2 input; the five early pairs identical; every later-pair change
attributed to a section 4B/4C item; check_like_ci passes.

## 7. Open items needing a decision from Pete

7.1 HTV glob (0.1): baseline the new transfer files or restrict the glob.
7.2 Salience for vic2010 (2.9): fetch from Google Trends, or accept that vic2010 differs from vic2014 on the salience arms.
7.3 Leaders backfill (2.11) and census vintage (2.12/1.9): each changes later pairs if landed; sequence them after this one.
7.4 Whether to load `vec-2010-vic-winners.csv` into candidacies (changes vic2014; 3.6).
7.5 Polls: 34 of 37 vic2010-cycle polls are AE's numbers; the coverage program wants Wikipedia/Poll Bludger first. Scoring vic2010 before
    that lands bakes in the AE dependence (the vic2010 level will move again when the polls change).
