# AUSPOL_* names read in code but not in published_flags.R (2026-10-12)

`quick_arm.R` refuses any switch not in `PUBLISHED_FLAGS`. Set difference of `Sys.getenv("AUSPOL_...")` reads
in `R/` and `scripts/` against `scripts/published_flags.R`: **119 names** (284 read, 170 registered), not the
"about 50" the queue said. Classified by two Haiku (effort high) read-only passes, then spot-checked by hand where
marked. Agent labels are leads; every row marked "checked" was read in the code.

Classes: MODEL (changes a number a harness or `fit_seats_full.R` produces), RUN (which pair, paths, caches,
suffixes, publish plumbing), DIAG (diagnostic or analysis script), DEAD (only in scripts nothing in the pipeline
calls).

## Counts

Number of names per class, 120 rows (agent A added `AUSPOL_FB_FLOW_SD`, read in the qld harness), after moving
`FED_PAIRS` from MODEL to RUN:

| class | n |
|---|---|
| MODEL (agent label) | 33 |
| RUN | 24 |
| DIAG | 18 |
| DEAD | 45 |

## Findings worth acting on

1. **Live and backtest MP-slope tiers differ (checked).** `fit_seats_full.R:925` keeps a party's sitting-member
   slope only when `n_member >= 8`; the six harnesses (`backtest_candidate_vic.R:481` and siblings) keep any
   finite one. Both drop GRN (harness via `AUSPOL_MP_SLOPE_GRN` default "0", live hard-coded), so that part
   matches. A slope the backtest applies can be refused live, and the `>= 8` is a `min_n` cliff. **Dormant
   today (checked):** `output/mp-slope-by-class.csv` has IND n=53, OTH_RIGHT 14, GRN 21 (dropped anyway), and ONP
   n=1 with no member slope (NA, dropped by both paths); the per-target file has n >= 13 for every finite row. It
   bites only when a party's member count sits between 1 and 7 with a finite slope. Fix when touched: shrink
   toward the also-ran slope instead of the cliff, in both paths.
2. **Harness-only model switches, all off or at a constant, none in the registry**, so quick_arm cannot screen
   them and the parity table cannot see them: `AUSPOL_ELASTIC_OVER` / `_FALL`, `FLOW_PRIORS` (fed, default
   "1"), `FLOW_TREND`, `FLOW_SD_BY_SOURCE`, `FLOW_POOL_VOLATILE`, `IND_TREND`, `MINOR_POLL_ADJ`,
   `FLOW_ON_PRIMARY`, `MAJOR_SLOPES` (nsw), `NSW_EXHAUST`, `FALLBACK_FLOW_SD`, `FB_FLOW_SD` (qld), `FLOW_UNC`
   (vic), `PARTY_SD` (all six, 1.5), `REENTRY_SD_K`, `WA_TRANSFER`, `SALIENCE_SURGE`, `SALIENCE_EXPECTED`
   (not in either list; agent B flagged it). Each is either a dead experiment (delete) or a switch to register
   at its harness default. `AUSPOL_FLOW_PRIORS="1"` in the federal harness is the one most likely to be live
   behaviour; not checked against `fit_seats_full.R`.
3. **Training-time switches in `fit_xgb_primary_v6.R`** (`XGB_NOTIONAL` "1", `XGB_RAW_LEVEL`,
   `XGB_RETIRING_MP`): they change the trained models the rebuild uses. `check_like_ci` reports "no fitting
   script's default disagrees with what published_flags.R ships", which only covers registered names.
4. **`AUSPOL_SKIP_PAIRS`**: code default "", `rebuild_forecasts.sh:48` default "wa2021". wa2021 is not one of
   the 22 scored pairs, so no number moves; worth one comment where the default is set.

## Not acted on

Agent misclassifications seen: `FED_PAIRS` (labelled MODEL, is RUN: pair selection). The DIAG/DEAD split for
uncalled scripts is the agents' judgement. The v7 xgb (`V7_*`) and salience-fetch chains are DEAD and could be
deleted with their scripts. Agent B noted the external-flow switches (`SA_FLOWS`, `*_CUTOFF`, `*_DROP_*`) are
registered and out of scope.
