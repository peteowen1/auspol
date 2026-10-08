# Model registry

**Generated 2026-10-08 by `scripts/build_model_registry.R`. Do not hand-edit** --
rerun the script instead. Regenerate whenever a switch is added to
`published_flags.R` or a harness's wiring changes.

This exists because "now works in every harness" has been claimed and been
wrong twice (AUSPOL_SEED hardcoded in WA; AUSPOL_SEAT_SD_MULT never reaching
`fit_seats_full.R` at all), both found 2026-09-09 by checking every switch by
hand instead of trusting the prior claim. The table below is regenerated from
the actual scripts, not remembered.

`yes*` means the switch's NAME is present in the file (often only in a
disclosure comment explaining that it is NOT wired) but is not functional
wiring -- see the explained section below for which ones and why.

## What each entry point is

| entry point | what it is | jurisdiction |
|---|---|---|
| `fit_seats_full.R` | **the published forecast** -- the only script whose output is real | Victoria (live target) |
| `backtest_candidate_fed.R` | backtest harness | Federal |
| `backtest_candidate_nsw.R` | backtest harness | New South Wales |
| `backtest_candidate_qld.R` | backtest harness | Queensland |
| `backtest_candidate_sa.R` | backtest harness | South Australia |
| `backtest_candidate_vic.R` | backtest harness | Victoria |
| `backtest_candidate_wa.R` | backtest harness | Western Australia |

All seven share one `R/` package core (`simulate_seat_contests()`,
`reentry_prior.R`, `salience_surge.R`, etc.) -- differences between them are
in which switches each one WIRES and which data source each reads, not in
separate model code.

## Switch parity (156 switches from `published_flags.R`, 7 entry points)

| switch | fit_seats (published) | fed | nsw | qld | sa | vic | wa |
|---|---|---|---|---|---|---|---|
| `AUSPOL_ANCHOR_EXHAUST` | yes | NO | NO | NO | NO | NO | NO |
| `AUSPOL_ANCHOR_IMPLIED` | yes | NO | NO | NO | NO | NO | NO |
| `AUSPOL_ASAT_MIN_PAIRS` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_BREAKOUT_MIX` | yes | yes | yes | yes | yes | yes | yes |
| `AUSPOL_BREAKOUT_MIX_MIN_P` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_BUCKET_SPLIT` | NO | yes | NO | NO | NO | NO | NO |
| `AUSPOL_BUCKET_TOTAL` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_BYELEC_DEPARTED` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_BYELEC_LEVEL` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_BYELECTION_FILL` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_BYELECTION_MP` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_BYELECTION_PRIOR` | yes | yes | yes | yes | yes | yes | yes |
| `AUSPOL_CLOSE_PROPORTIONAL` | yes | NO | NO | NO | NO | NO | NO |
| `AUSPOL_COUNCIL_EXTRA` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_COV_LOO` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_CROSS_SEAT_VOTE` | yes | yes | yes | yes | yes | yes | yes |
| `AUSPOL_DEFECT_BY_LEVEL` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_DEFECT_CONSERVE` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_DEFECT_DISCOUNT` | yes | yes | yes | yes | yes | yes | yes |
| `AUSPOL_DEFECT_POOLED` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_DEFECTOR_STATE` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_DEMO_RESID` | yes | yes | yes | yes | yes | yes | yes |
| `AUSPOL_DEMO_RESID_SHUFFLE` | NO | yes | yes | yes | yes | yes | yes |
| `AUSPOL_DEPARTED_FED` | yes | NO | yes | yes | yes | yes | NO |
| `AUSPOL_DEPARTED_HOLD` | yes | yes | yes | yes | yes | yes | NO |
| `AUSPOL_DEPARTED_HOLD_MIN_PRIOR` | yes | yes | yes | yes | yes | yes | NO |
| `AUSPOL_DEPARTED_ORIGIN` | yes | yes | yes | yes | yes | yes | yes |
| `AUSPOL_DEPARTED_SUCCESSOR` | yes | yes | yes | yes | yes | yes | NO |
| `AUSPOL_DEV_SLOPE` | yes | yes | yes | yes | yes | yes | yes |
| `AUSPOL_DEV_SLOPE_MODE` | yes | yes | yes | yes | yes | yes | yes |
| `AUSPOL_DISPERSION_SLOPE` | yes | yes | yes | yes | yes | yes | yes |
| `AUSPOL_EDU_RESID` | NO | yes | yes | yes | yes | yes | yes |
| `AUSPOL_EDU_RESID_FEATURE` | NO | yes | yes | yes | yes | yes | yes |
| `AUSPOL_EDU_RESID_SHUFFLE` | NO | yes | yes | yes | yes | yes | yes |
| `AUSPOL_FALLBACK_SMOOTH` | yes | yes | yes | yes | yes | yes | yes |
| `AUSPOL_FIT_SLOPES` | yes | yes | yes | yes | yes | yes | yes |
| `AUSPOL_FLOW_ASAT` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_FLOW_CELL_SD` | NO | yes | yes | yes | yes | yes | yes |
| `AUSPOL_FLOW_FRAG` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_FLOW_MODEL_TAG` | NO | yes | yes | yes | yes | yes | yes |
| `AUSPOL_FLOW_SD` | yes | yes | yes | yes | yes | yes | yes |
| `AUSPOL_FLOW_SHIFT` | yes | NO | NO | NO | NO | NO | NO |
| `AUSPOL_FLOW_SHRINK_K` | yes | yes | yes | yes | yes | yes | yes |
| `AUSPOL_FORCE_FP` | yes | NO | NO | NO | NO | NO | NO |
| `AUSPOL_FORCE_FP_RULE` | yes | NO | NO | NO | NO | NO | NO |
| `AUSPOL_FORECAST_MODE` | NO | yes | yes | yes | yes | yes | yes |
| `AUSPOL_FP_SD_MODE` | yes | NO | NO | NO | NO | NO | NO |
| `AUSPOL_FUND_TIME_FORWARD` | NO | yes | NO | NO | NO | NO | NO |
| `AUSPOL_HISTORIC_ELECTED_BACKFILL` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_HONOUR_DEPARTED` | yes | yes | yes | yes | yes | yes | NO |
| `AUSPOL_HTV_FLOW` | yes | yes | yes | yes | yes | yes | yes |
| `AUSPOL_IND_SALIENCE` | NO | yes | NO | NO | NO | NO | NO |
| `AUSPOL_INSURGENCY_SHRINK` | yes | yes | NO | NO | NO | NO | NO |
| `AUSPOL_LEADER_SEAT` | yes | yes | yes | yes | yes | yes | yes |
| `AUSPOL_LEVEL_MODE` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_LEVEL_MULT_IND` | yes | yes | yes | yes | yes | yes | yes |
| `AUSPOL_LEVEL_MULT_OTH` | yes | yes | yes | yes | yes | yes | yes |
| `AUSPOL_LEVEL_RECIPE` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_LEVEL_SD` | yes | yes | yes | yes | yes | yes | yes |
| `AUSPOL_LIVE_DRAW_BUCKET` | yes | NO | NO | NO | NO | NO | NO |
| `AUSPOL_LIVE_LEVEL_ANCHOR` | yes | NO | NO | NO | NO | NO | NO |
| `AUSPOL_MAJOR_DEPARTED` | yes | yes | yes | yes | yes | yes | yes |
| `AUSPOL_MAJOR_SLOPE` | yes | yes | yes | yes | yes | yes | yes |
| `AUSPOL_MINOR_DEFECT` | yes | yes | yes | yes | yes | yes | yes |
| `AUSPOL_MINOR_DEFECT_BASE_PRED` | yes | yes | yes | yes | yes | yes | yes |
| `AUSPOL_MINOR_DEFECT_CONSERVE` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_MP_SLOPE` | yes | yes | yes | yes | yes | yes | yes |
| `AUSPOL_N_SIMS` | yes | yes | yes | yes | yes | yes | yes |
| `AUSPOL_NB_TARGET` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_NEW_IND_SHRINK` | yes | yes | yes | yes | yes | yes | yes |
| `AUSPOL_NEW_IND_SHRINK_CAP` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_NOM_LIVE` | yes | NO | NO | NO | NO | NO | NO |
| `AUSPOL_NOM_ZERO` | NO | yes | yes | yes | yes | yes | yes |
| `AUSPOL_NOM_ZERO_ORDER` | NO | yes | yes | yes | yes | yes | yes |
| `AUSPOL_NOTIONAL` | NO | yes | NO | NO | NO | NO | NO |
| `AUSPOL_NSW_THIN_WALK` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_ONP_CONC_SD` | NO | NO | NO | yes | yes | NO | NO |
| `AUSPOL_ONP_CV` | yes | NO | NO | NO | NO | NO | NO |
| `AUSPOL_ONP_FIX` | yes | NO | NO | NO | NO | NO | NO |
| `AUSPOL_ONP_ORDER` | yes | NO | yes | yes | yes | NO | NO |
| `AUSPOL_OTHERS_SCALE` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_PARTY_COR` | yes | yes | yes | yes | yes | yes | NO |
| `AUSPOL_QLD_CUTOFF` | NO | yes | NO | yes | yes | yes | NO |
| `AUSPOL_QLD_FLOWS` | yes | yes | NO | yes | yes | yes | NO |
| `AUSPOL_REENTRY` | yes | yes | yes | yes | yes | yes | yes |
| `AUSPOL_REENTRY_GAP` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_REENTRY_LINK` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_REENTRY_SPLIT` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_REENTRY_WINSOR` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_SA_CUTOFF` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_SA_FLOWS` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_SALIENCE_BLEND` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_SALIENCE_EXP_SD` | NO | yes | yes | yes | yes | yes | NO |
| `AUSPOL_SALIENCE_EXPECTED` | yes | yes | yes | yes | yes | yes | NO |
| `AUSPOL_SALIENCE_PCTILE_NZ` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_SALIENCE_SMOOTH` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_SALIENCE_SURGE_V2` | yes | yes | yes | yes | yes | yes | yes* |
| `AUSPOL_SD_DEPARTED` | NO | yes | yes | yes | yes | yes | yes |
| `AUSPOL_SEAT_CONTEXT_FILL` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_SEAT_CONTEXT_MARGIN` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_SEAT_POLL_BLEND` | yes | yes | yes | yes | yes | yes | yes |
| `AUSPOL_SEAT_POLL_COALITION_DEDUP` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_SEAT_POLL_HANDKEYED` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_SEAT_POLL_IND_MAP` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_SEAT_POLL_IND_WEIGHT` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_SEAT_POLL_MATCH` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_SEAT_POLL_SOURCES` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_SEAT_POLL_TPP_SOURCE` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_SEAT_POLL_W_SINGLE_CLUSTER` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_SEAT_SD_MULT` | yes | yes | yes | yes | yes | yes | yes |
| `AUSPOL_SEAT_SWING_PORT` | yes | yes | yes | yes | yes | yes | yes |
| `AUSPOL_SEAT_SWING_PORT_NOCLIFF` | NO | NO | NO | NO | NO | NO | yes |
| `AUSPOL_SEAT_SWING_PORT_WA` | NO | NO | NO | NO | NO | NO | yes |
| `AUSPOL_SEED` | yes | yes | yes | yes | yes | yes | yes |
| `AUSPOL_SHIP_TIME_FORWARD` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_SHRINK` | yes | yes | yes | yes | yes | yes | yes |
| `AUSPOL_SIM_ENGINE` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_SITTING_MEMBER_ADJ` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_SLOPE_SHRINK` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_SPLIT_SLOPE` | NO | yes | yes | yes | yes | yes | yes |
| `AUSPOL_STATE_DEV` | NO | yes | NO | NO | NO | NO | NO |
| `AUSPOL_STATE_DEV_SHUFFLE` | NO | yes | NO | NO | NO | NO | NO |
| `AUSPOL_STATE_NOTIONAL` | NO | NO | yes | yes | yes | yes | yes |
| `AUSPOL_STATE_POLL_EXTRA` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_STATE_POLL_POOL` | NO | yes | NO | NO | NO | NO | NO |
| `AUSPOL_SURGE_FROM_ZERO` | yes | yes | yes | yes | yes | yes | NO |
| `AUSPOL_SURGE_H` | yes | yes | yes | yes | yes | yes | yes |
| `AUSPOL_SURGE_RECIPIENT` | yes | yes | yes | yes | yes | yes | yes |
| `AUSPOL_SURGE_SCALE` | yes | yes | yes | yes | yes | yes | yes |
| `AUSPOL_TIME_FORWARD_FITS` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_UPSET_FLOOR` | yes | NO | NO | NO | NO | NO | NO |
| `AUSPOL_WA_CUTOFF` | NO | yes | NO | yes | yes | yes | NO |
| `AUSPOL_WA_DROP_3C` | NO | yes | NO | yes | yes | yes | NO |
| `AUSPOL_WA_DROP_LNP` | NO | yes | NO | yes | yes | yes | NO |
| `AUSPOL_WA_FLOWS` | yes | yes | NO | yes | yes | yes | NO |
| `AUSPOL_XGB_BASE_DELTA` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_XGB_BASE_DELTA_TOL` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_XGB_BASE_MARGIN` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_XGB_BASE_RECORD` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_XGB_BOOTH` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_XGB_COUNCIL` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_XGB_DEPARTED_SIDE` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_XGB_ENDORSE` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_XGB_ENSEMBLE` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_XGB_FLOWS` | yes | yes | yes | yes | yes | yes | yes |
| `AUSPOL_XGB_PRIMARY` | yes | yes | yes | yes | yes | yes | yes |
| `AUSPOL_XGB_PRIMARY_LIVE` | yes | NO | NO | NO | NO | NO | NO |
| `AUSPOL_XGB_PRIMARY_OOF` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_XGB_PRIMARY_SD` | NO | yes | yes | yes | yes | yes | yes |
| `AUSPOL_XGB_PRIMARY_SD_CLASSES` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_XGB_PRIMARY_SD_SRC` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_XGB_SEATPREV_NAFILL` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_XGB_SEED` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_XGB_SENATE` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_XGB_SURGE` | NO | yes | yes | yes | yes | yes | yes |
| `AUSPOL_XGB_SURGE_SRC` | NO | NO | NO | NO | NO | NO | NO |

## Every non-universal switch, explained

- **`AUSPOL_ANCHOR_EXHAUST`** (intentional / dead experiment): ARM, not shipped (default 0; plans/prereg-anchor-exhaust-2026-09-27.md). Read in R/forecast_mode.R (statewide_draws_as_at(), which only the federal harness and fit_seats_full.R call) and in fit_seats_full.R. No effect where flows carry no exhaust (every non-NSW election, live Victoria). Not a parity gap while off; if adopted for NSW, note the nsw harness does not reach forecast_mode today (function-name grep).
- **`AUSPOL_ANCHOR_IMPLIED`** (intentional / dead experiment): ARM, not shipped (default 0; plans/prereg-anchor-implied-tpp-2026-09-20.md). Same wiring as AUSPOL_ANCHOR_EXHAUST: read in R/forecast_mode.R (federal harness + fit_seats_full.R) and fit_seats_full.R; scripts/audit_statewide_forecast.R only prints it. The other five harnesses never call forecast_mode, so 'no' there is the arm's scope, not drift.
- **`AUSPOL_ASAT_MIN_PAIRS`** (intentional / dead experiment): Training-time switch for scripts/fit_xgb_primary_asat.R only: the minimum number of earlier election pairs a target must have before it gets its own point-in-time model (default 4). Below it the target gets no model and no row in the predictions file, so the harness keeps base_pred for it and says so. Not a harness or forecast switch.
- **`AUSPOL_BREAKOUT_MIX_MIN_P`** (intentional / dead experiment): PREREG PENDING, default 0 (= every eligible cell, i.e. no gate). Read inside breakout_mix_args() in R/breakout_mix.R, which all six harnesses and fit_seats_full.R call, so the harness grep cannot see it; it reaches all of them when set.
- **`AUSPOL_BUCKET_SPLIT`** (**adopted, shared-function wiring**): SHIPPED 2026-09-28 (ledger v44, 'cand_naive'). Read inside candidate_bucket_ratio() in R/forecast_statewide.R, which every harness and fit_seats_full.R reach through forecast_statewide_for(); only the federal harness names it in a comment. published_flags.R notes the split is backtests-only until the 9 Nov nominations.
- **`AUSPOL_BUCKET_TOTAL`** (intentional / dead experiment): ARM, not shipped (default 'poll'; plans/prereg-bucket-total-candidates-2026-09-28.md). Read in R/forecast_statewide.R (candidate_bucket_total()) and R/forecast_mode.R, both below the harness grep; scripts/build_bucket_total_history.R reads the audit log it produces.
- **`AUSPOL_BYELEC_DEPARTED`** (**adopted, shared-function wiring**): SHIPPED 2026-10-05. Read inside R/candidate_returns.R (the 'member departed' flag after a by-election loss), which every harness and fit_seats_full.R reach through candidate_returns(); the harness grep cannot see it.
- **`AUSPOL_BYELEC_LEVEL`** (**adopted, shared-function wiring**): SHIPPED 2026-10-05 (Pete override of the 2-SE clause). Read in R/candidate_returns.R (a non-major by-election winner is credited the median next-election share); R/cross_seat_vote.R carries a comment that this switch owns those rows. Reaches every harness and fit_seats_full.R through candidate_returns().
- **`AUSPOL_BYELECTION_FILL`** (intentional / dead experiment): REFUSED 2026-09-30 (docs/plans/prereg-byelection-fill-2026-09-30.md): only Lyne improved, xgb error +0.01. Default 0, read only as an argument default in R/byelection_prior.R, so a refused experiment with no reason to be wired anywhere.
- **`AUSPOL_BYELECTION_MP`** (**adopted, shared-function wiring**): SHIPPED 2026-09-19 (plans/prereg-byelection-mp-2026-09-19.md). Read inside R/candidate_returns.R at the top of candidate_returns(): a by-election winner (external/reference/byelections/byelection-winners.csv) is the sitting member for every identity test. Reaches all six harnesses and fit_seats_full.R through that function.
- **`AUSPOL_CLOSE_PROPORTIONAL`** (intentional / dead experiment): ARM, not shipped (default 0; plans/prereg-close-proportional-2026-09-28.md). Read in R/forecast_mode.R (federal harness path) and fit_seats_full.R (the live LL1 step). Off, so the four state harnesses not reaching it changes nothing.
- **`AUSPOL_COUNCIL_EXTRA`** (**shipped, fitting-time switch (reaches harnesses via the artifact)**): FITTING-TIME, default 0, TESTING (plans/prereg-council-extra-2026-10-02.md). Read only by scripts/build_council_history.py, which builds the council-history input that the xgb council features (AUSPOL_XGB_COUNCIL) read; no R/ or harness call site.
- **`AUSPOL_COV_LOO`** (intentional / dead experiment): Read inside R/statewide_cor.R, not per-harness -- universal in practice, absent from every harness script by design.
- **`AUSPOL_DEFECT_BY_LEVEL`** (**adopted, shared-function wiring**): SHIPPED 2026-10-05 (mode 2: federal targets get their own shrunk sitting-member defector carry). Read inside R/candidate_returns.R (line ~1240), so every harness and fit_seats_full.R get it through that function; the grep cannot see it.
- **`AUSPOL_DEFECT_CONSERVE`** (**adopted, shared-function wiring**): SHIPPED (default 1) and read inside R/candidate_returns.R's personal_prior_vote(), not by any harness directly, so the registry's grep sees it nowhere: a major-party defector's unclaimed vote stays with the origin class instead of vanishing. Reaches every harness and fit_seats_full.R through that one function. scripts/prereg_major_defector_verify.R proves =0 is byte-identical to the pre-switch behaviour.
- **`AUSPOL_DEFECT_POOLED`** (**adopted, shared-function wiring**): ADOPTED 2026-09-09 at "2" (docs/plans/prereg-defector-two-rate- 2026-09-09.md), by Pete on mechanism -- the arm missed its own primary bar (t -2.04 vs 2.08) but every directional indicator was favourable and R4 confirmed the published Victorian forecast is byte-identical (Victoria fields no major-party defector standing as a minor this cycle, so the mechanism does not fire there). Reaches fit_seats_full.R correctly: personal_prior_vote() self-resolves both rates from Sys.getenv() when the caller passes NULL, exactly so this did not need a seventh call site wired by hand -- the mistake that made the first pooled-arm run VOID earlier the same day.
- **`AUSPOL_DEFECTOR_STATE`** (intentional / dead experiment): PREREG PENDING, OFF (built 2026-10-06; docs/reviews/state-defectors-2026-10-06.md). Gate is .defstate_on() in R/defector_state.R, called from R/candidate_returns.R, so it would reach every harness and fit_seats_full.R if turned on; not a gap.
- **`AUSPOL_DEMO_RESID_SHUFFLE`** (intentional / dead experiment): Control, not an arm. Permutes which seat gets which seat's demographics within each election, at fit and at apply both, so every marginal and the whole procedure survive and only the seat-to-demographics link dies. Absent from fit_seats_full.R for the same reason its arm is: a control has no business in the published forecast. Calibrated on sa2026 -- 8 draws give mean 0.3576 against a 0.3577 baseline, sd 0.0013, so the null manufactures nothing and the real effect sits 8.9 sds out.
- **`AUSPOL_DEPARTED_FED`** (intentional / dead experiment): REFUSED 2026-09-30 (both '1' and 'gap': qld2020 and sa2026 worse; plans/prereg-departed-fed-gap-2026-09-30.md). Wired into the nsw/qld/sa/vic harnesses and fit_seats_full.R. The fed and wa 'NO' cells are by design: commit 2ff6bf8 says fed and wa have no booth map (the booth-to-federal-district join only exists for state elections with transposed federal swing).
- **`AUSPOL_DEPARTED_HOLD`** (intentional / dead experiment): REFUSED 2026-10-05, switch kept OFF. Holds a departed leader's decayed class cell fixed through the final renormalisation (the 0.38 was measured on final shares but applied before renormalising, so the effective retention was 0.6-0.7). Wired in fed/nsw/qld/sa/vic and fit_seats_full.R; WA is not wired for the same reason as AUSPOL_HONOUR_DEPARTED (backtest_candidate_wa.R has no screened_slopes() call). docs/plans/prereg-departed-hold-fixed-2026-10-04.md, docs/reviews/departed-hold-sweep-2026-10-05.md.
- **`AUSPOL_DEPARTED_HOLD_MIN_PRIOR`** (intentional / dead experiment): Arm B of AUSPOL_DEPARTED_HOLD (post hoc, Amendment 1): hold only classes whose prior seat share is at least this many points (15 = the retention review's population). Also refused; default 0 = arm A. WA not wired, as for AUSPOL_DEPARTED_HOLD.
- **`AUSPOL_DEPARTED_SUCCESSOR`** (intentional / dead experiment): UNDER TEST 2026-10-07, OFF. The departed-independent rate per seat, split by a hand-coded pre-election successor flag (endorsed, local office, community group, former staffer) and fitted time-forward with shrinkage; those cells held through renormalisation. Read via departed_successor_rates() (R/), so the grep may show it UNEXPLAINED where it is wired. WA not wired (no screened_slopes() call). docs/plans/prereg-departed-successor-flag-2026-10-07.md.
- **`AUSPOL_EDU_RESID`** (intentional / dead experiment): REFUSED 2026-09-15 and left wired so the result stays reproducible. docs/plans/prereg-education-residual-correction-2026-09-15.md: the criterion passed (pooled seat log loss 0.2702 -> 0.2689 over the AEF-7) and the placebo condition fired, so the answer is no. Superseded by AUSPOL_DEMO_RESID. Default 0 and it should stay 0.
- **`AUSPOL_EDU_RESID_FEATURE`** (intentional / dead experiment): Which census column AUSPOL_EDU_RESID uses. born_aus_pct was pre-registered as the PLACEBO and was not one: r(yr12_pct, born_aus_pct) = -0.706 over 1,989 seats, so both columns read a single class-and-urbanity axis from opposite ends. It recovered 71% of the pooled gain and 100% of it on qld2024, which is what refused the mechanism. The lesson is in AUSPOL_DEMO_RESID_SHUFFLE: with correlated features the control must break the link, not swap the variable.
- **`AUSPOL_EDU_RESID_SHUFFLE`** (intentional / dead experiment): The permutation control retrofitted to the refused single-feature arm, and the instrument that showed its signal was REAL (8.9 sds) even though the arm was refused. Same mechanism as AUSPOL_DEMO_RESID_SHUFFLE; absent from fit_seats_full.R because a control does not belong in the published forecast.
- **`AUSPOL_FLOW_ASAT`** (**adopted, shared-function wiring**): SHIPPED 2026-09-18 and read inside R/xgb_flow_override.R (.flow_asat_model()), never by a harness directly: the per-election flow model is the as-at file output/xgb-flows-v1-asat-<election>.model when one exists, the all-data model for a future election (vic2026), and skipped only if a LATER election's as-at model exists. Reaches all six harnesses and fit_seats_full.R through that function.
- **`AUSPOL_FLOW_CELL_SD`** (intentional / dead experiment): Read inside R/xgb_flow_override.R, not per-harness -- universal in practice (added to published_flags.R 2026-10-08 at its code default).
- **`AUSPOL_FLOW_FRAG`** (**shipped, fitting-time switch (reaches harnesses via the artifact)**): SHIPPED 2026-09-15 and reads NO everywhere by construction: it is a FITTING-TIME switch, not a runtime one. Only scripts/fit_xgb_flows_v1.R reads it, where it decides whether lead_primary (the seat's leading first-preference share) enters feat_cols and so whether the column is baked into output/xgb-flows-v1-final-cols.json. Every harness and fit_seats_full.R then reads that JSON, never the environment, so the feature reaches them through the ARTIFACT. The parity question for this switch is therefore not 'does each harness honour it' but 'was the artifact refit with it', which the cols JSON answers: 40 features, lead_primary present. scripts/fit_xgb_flows_loo.R inherits the same list, so the 25 leave-one-election-out models must be refit in the same breath or a harness loads a 39-feature model against a 40-column matrix. Both were refit 2026-09-15. docs/plans/prereg-flow-fragmentation-2026-09-15.md
- **`AUSPOL_FLOW_MODEL_TAG`** (intentional / dead experiment): Read inside R/xgb_flow_override.R, not per-harness -- universal in practice (added to published_flags.R 2026-10-08 at its code default).
- **`AUSPOL_FLOW_SHIFT`** (intentional / dead experiment): Published-forecast-only (fit_seats_full.R shifts the statewide TPP fundamentals blend for the live Victorian projection); backtests inject real historical first preferences directly and have no fundamentals blend to shift. NOT federal-specific -- fit_seats_full.R is the Victorian forecast; corrected 2026-09-09, this comment previously said "federal" for every switch fit_seats_full.R alone reads, which is wrong for all six in this group.
- **`AUSPOL_FORCE_FP`** (intentional / dead experiment): Published-forecast-only (fit_seats_full.R -- forces a first-preference override for the live Victorian forecast); no analogue in a backtest scored against real historical results.
- **`AUSPOL_FORCE_FP_RULE`** (intentional / dead experiment): Published-forecast-only (fit_seats_full.R -- how the other parties give way under AUSPOL_FORCE_FP); a what-if switch with no analogue in a backtest.
- **`AUSPOL_FORECAST_MODE`** (**OPEN GAP**): OPEN GAP, and the most consequential one in this table. 1 = the statewide the seats swing toward is PREDICTED from polls rather than read off the election being scored. Implemented in backtest_candidate_fed.R and _sa.R ONLY; nsw/qld/vic/wa still use the actual result, so their numbers answer a different question from federal's and are not comparable to a forecast. Default 0 because flipping it today would mean two different things across the six harnesses, NOT because the oracle statewide is endorsed -- Pete's ruling 2026-09-11 is that a forecast must be predictive throughout. Cost where measured: federal +0.0047 pooled seat log loss.
- **`AUSPOL_FP_SD_MODE`** (intentional / dead experiment): Published-forecast-only (fit_seats_full.R -- first-preference spread mode for the live Victorian projection); backtests use realised historical first preferences, not a projected spread.
- **`AUSPOL_FUND_TIME_FORWARD`** (**adopted, shared-function wiring**): SHIPPED as a leak fix (ledger v51, 2026-09-29). Read in R/forecast_statewide.R (reached by every harness and fit_seats_full.R), scripts/backtest_candidate_fed.R and scripts/build_level_pred.R. 'No' in the other harness columns is the grep missing the R/ read.
- **`AUSPOL_HISTORIC_ELECTED_BACKFILL`** (**adopted, shared-function wiring**): SHIPPED 2026-09-15 on judgement (costs 0.0141 pooled RMSE in the backtest, but vic2026 is never a training pair so the 62 returning members can only move the live forecast, which the backtest cannot see). Read ONCE at build time by scripts/build_candidacies.R and baked into output/candidacies.csv, so no harness reads it at runtime; reversible by rebuilding candidacies with the flag off.
- **`AUSPOL_HONOUR_DEPARTED`** (**adopted, shared-function wiring**): SHIPPED 2026-09-18 (flipped 0->1). A departed non-major class leader's vote base decays toward a measured 0.38 retention rate, gated on prior_leader_returns==FALSE (not candidate_returns()'s `same`, which is any() across every candidate in the class and can read TRUE even when the actual leader departed -- Morwell/vic2022, an unrelated minor candidate persisting) AND the salience screen not independently permitting a new emergence. Wired into R/dev_slope.R's screened_slopes(), read by all five harnesses that call it (fed/nsw/qld/sa/vic; backtest_candidate_wa.R has no screened_slopes() wiring at all, a separate pre-existing gap) and by fit_seats_full.R. 2026-09-06's refusal was a federal two-seat wash (New England vs Wentworth) that conflated departure with 'no new emergence' as one mechanism; re-measured on the fuller 593-case corpus. Isolated in base_pred: pooled log loss 0.2810->0.2801 (5 harnesses, n=1751), Morwell 3.049->1.877. Reaches the published Victoria forecast immediately via fit_seats_full.R's xgb_primary_predict_live() (base_margin set fresh each run from the current shares matrix) with no retrain needed -- but the BACKTEST harnesses' AUSPOL_XGB_PRIMARY path (xgb_primary_override(), a static cached OOF file) needs the 4-step non-circular retrain to reflect it in a pooled backtest comparison. See docs/reviews/departed-leader-honour-fix-2026-09-18.md and docs/reviews/departed-leader-retention-2026-09-15.md.
- **`AUSPOL_IND_SALIENCE`** (intentional / dead experiment): Deprecated experimental arm (the v1 national IND multiplier), superseded by the newer salience mechanisms; fed-only because that is the only harness it was ever tested in. Not adopted.
- **`AUSPOL_INSURGENCY_SHRINK`** (intentional / dead experiment): Per-seat shrink experiment, REFUSED 2026-09-06 (worse than the scalar shrink on 5 of 6 federal pairs) -- see docs/NEXT-STEPS.md. Fed/fit_seats-only because that is as far as the experiment got before being set aside. Not adopted.
- **`AUSPOL_LEVEL_MODE`** (intentional / dead experiment): Read by scripts/fit_xgb_primary_v6.R when the model is FITTED, not by any harness or by fit_seats_full.R at run time -- the choice is baked into the oof file and the saved model, so it shows as absent everywhere while governing every row of both. 'pred' (default) trains on a poll-based statewide projection; 'now' trains on the target election's actual result and is LEAKAGE, kept only so the cost stays measurable. The live path has always used a prediction (R/xgb_primary_override.R fills level_now from state_mean), so this made training match serving.
- **`AUSPOL_LEVEL_RECIPE`** (**adopted, shared-function wiring**): SHIPPED 2026-09-30 as v56 ('live'). Read only in R/forecast_mode.R (statewide_draws_as_at()), which fit_seats_full.R and the federal harness call. The harness grep cannot see an R/ read. Whether the state harnesses honour 'live' through another path was not traced.
- **`AUSPOL_LIVE_DRAW_BUCKET`** (**adopted, shared-function wiring**): SHIPPED 2026-09-28 as a parity fix, LIVE-ONLY by design: read only in fit_seats_full.R, where the live statewide draws split the unpolled bucket by its 2022 ratio. The harnesses use candidate_bucket_ratio() (AUSPOL_BUCKET_SPLIT) instead.
- **`AUSPOL_LIVE_LEVEL_ANCHOR`** (intentional / dead experiment): OFF since 2026-09-30 (v56), LIVE-ONLY by design: read only in fit_seats_full.R. The un-anchored level scored better over all 22 elections, and published_flags.R says backtests and live now both use the un-anchored recipe (AUSPOL_LEVEL_RECIPE='live').
- **`AUSPOL_MINOR_DEFECT_CONSERVE`** (**adopted, shared-function wiring**): SHIPPED 2026-09-19 (plans/prereg-minor-defector-conserve-2026-09-19.md). Read inside personal_prior_vote() in R/candidate_returns.R: a minor-to-minor defector's origin class keeps a fitted share (~0.38) of the vote. Reaches every harness and fit_seats_full.R through that function, not by a direct harness read.
- **`AUSPOL_NB_TARGET`** (intentional / dead experiment): NOT A MODEL SWITCH: an argument to scripts/build_notional_baselines.R (which federal election year to build notional post-redistribution baselines for). Reads NO everywhere by construction; listed in published_flags.R only as documentation of how to rebuild the notional table.
- **`AUSPOL_NEW_IND_SHRINK_CAP`** (**adopted, shared-function wiring**): SHIPPED (default 1 = cap the new-independent factor at 1); the '0' arm is pending. Read inside R/new_ind_shrink.R, which all six harnesses and fit_seats_full.R call, so the harness grep cannot see it.
- **`AUSPOL_NOM_LIVE`** (**adopted, shared-function wiring**): SHIPPED v61, LIVE-ONLY by design: the published Victorian forecast zeroes non-standing parties only when set to '1' by hand once the VEC final list is loaded (R/nomination_zero.R, fit_seats_full.R). The six harnesses use AUSPOL_NOM_ZERO instead.
- **`AUSPOL_NOM_ZERO`** (**adopted, shared-function wiring**): SHIPPED v61 2026-10-03 (mode 2). All six harnesses read it. fit_seats_full.R does not name it, by design: the published run uses AUSPOL_NOM_LIVE for the same zeroing (R/nomination_zero.R) once the real nomination list exists.
- **`AUSPOL_NOM_ZERO_ORDER`** (**adopted, shared-function wiring**): SHIPPED 2026-10-04 ('late', Pete overriding the R2 refusal). Read in R/nomination_zero.R and named by all six harnesses; per published_flags.R, fit_seats_full.R already zeroes after the last step that can write a share back, so the switch does not apply to it.
- **`AUSPOL_NOTIONAL`** (**adopted, shared-function wiring**): SHIPPED (2) and FEDERAL-BACKTEST-ONLY by design: the redistribution-adjusted (notional) prior only exists where build_notional_baselines.R has a table (federal). State harnesses have no notional table to read, so 'no' there is a data fact, not a parity gap. docs/reviews/notional-prior-redistribution-2026-09-13.md
- **`AUSPOL_NSW_THIN_WALK`** (intentional / dead experiment): NOT A PUBLISHED-CONFIG SWITCH: read by scripts/fit_nsw.R (the NSW poll-trend validation stage), which does not source published_flags.R. The comment block in published_flags.R says why it is deliberately unregistered.
- **`AUSPOL_ONP_CONC_SD`** (**adopted, shared-function wiring**): SHIPPED 2026-09-14 ('auto') for the harnesses that model a One Nation seat concentration from federal booth-transposed votes: qld and sa (where One Nation contests every seat). fed/nsw/vic/wa have no ONP concentration mechanism, and fit_seats_full.R has its own live ONP path; a gap only if One Nation's Victorian seat spread is ever driven from this switch (the VIC2022 IND-coupling regression is the reason it is not: docs/reviews/sa2026-onp-base-pred-diagnosis-2026-09-14.md).
- **`AUSPOL_ONP_CV`** (intentional / dead experiment): Published-forecast-only (fit_seats_full.R). ADOPTED 2026-09-09 at 0.365, partially pooled (docs/reviews/onp-concentration-validated-2026-09-09.md) -- moves the live Victorian One Nation median seat count 9 -> 10. The highest-stakes switch this registry tracks; was previously mislabelled "federal" here, which is wrong -- fit_seats_full.R is the Victorian forecast, not a federal one.
- **`AUSPOL_ONP_FIX`** (intentional / dead experiment): Published-forecast-only (fit_seats_full.R -- One Nation allocation fix for the live Victorian projection).
- **`AUSPOL_ONP_ORDER`** (intentional / dead experiment): Published-forecast-only (fit_seats_full.R -- One Nation allocation ordering for the live Victorian projection).
- **`AUSPOL_OTHERS_SCALE`** (intentional / dead experiment): ARM, REFUSED 2026-09-28 (plans/prereg-others-bucket-size-2026-09-27.md). Backtest path only (R/forecast_mode.R, R/others_bucket.R); published_flags.R says the live script is deliberately not wired because it did not pass.
- **`AUSPOL_PARTY_COR`** (intentional / dead experiment): WA deliberately excluded from the statewide party-correlation matrix -- cor(ALP, IND) flips sign there (docs/reviews/statewide-cov-loo-2026-09-07.md). Intentional, not a gap.
- **`AUSPOL_QLD_CUTOFF`** (intentional / dead experiment): Read inside R/external_flows.R (pool_configured_flows), not per-harness -- universal in practice (added to published_flags.R 2026-10-08 at its code default).
- **`AUSPOL_QLD_FLOWS`** (intentional / dead experiment): Self-referential no-op in the QLD harness itself ("use Queensland's own flows" is trivially true there) -- disclosed via its own `.inert` list. Genuinely absent from WA (uses AUSPOL_WA_FLOWS instead).
- **`AUSPOL_REENTRY_GAP`** (intentional / dead experiment): Read inside R/reentry_prior.R, not per-harness -- universal in practice (added to published_flags.R 2026-10-08 at its code default).
- **`AUSPOL_REENTRY_LINK`** (intentional / dead experiment): Read inside R/reentry_prior.R, not per-harness -- universal in practice (added to published_flags.R 2026-10-08 at its code default).
- **`AUSPOL_REENTRY_SPLIT`** (intentional / dead experiment): Read inside R/reentry_prior.R, not per-harness -- universal in practice (added to published_flags.R 2026-10-08 at its code default).
- **`AUSPOL_REENTRY_WINSOR`** (intentional / dead experiment): Read inside R/reentry_prior.R, not per-harness -- universal in practice (added to published_flags.R 2026-10-08 at its code default).
- **`AUSPOL_SA_CUTOFF`** (intentional / dead experiment): Read inside R/external_flows.R (pool_configured_flows), not per-harness -- universal in practice (added to published_flags.R 2026-10-08 at its code default).
- **`AUSPOL_SA_FLOWS`** (intentional / dead experiment): Read inside R/external_flows.R (pool_configured_flows), not per-harness -- universal in practice (added to published_flags.R 2026-10-08 at its code default).
- **`AUSPOL_SALIENCE_BLEND`** (intentional / dead experiment): Read inside R/salience_surge.R's blend_salience_shares(), not per-harness -- universal in practice, and gated there deliberately so all five harnesses and the published forecast get the switch from one change. Exists to make a suspected DOUBLE COUNT measurable: the same hazard drives both a shift of the point estimate and an additive jump in the draw. Measured 2026-09-11 -- the double count is real (surge_h is the per-seat max of p_hat, correlation 0.984) and turning the blend OFF makes things WORSE, because the under-prediction of emergences is larger than the over-counting. Stays at 1 until the per-cell variance is fixed.
- **`AUSPOL_SALIENCE_EXP_SD`** (**OPEN GAP**): WA: same salience-corpus exclusion as AUSPOL_SALIENCE_EXPECTED, intentional. fit_seats_full.R: OPEN GAP, not fixed -- registered as published but sd_override is never wired into the forecast script at all (docs/reviews/pre-main-review-gate-2026-09-08.md). Currently harmless: this whole salience-variance arm is still pre-registered and undecided (docs/plans/prereg-salience-expected-and-variance-2026-09-07.md), so the switch is off everywhere. Wire it in the same commit that ships the arm, not before.
- **`AUSPOL_SALIENCE_EXPECTED`** (intentional / dead experiment): WA has no candidate-level salience corpus at all (the WA commission files carry surnames only, no salience-v6.csv rows) -- documented, intentional exclusion.
- **`AUSPOL_SALIENCE_PCTILE_NZ`** (**adopted, shared-function wiring**): SHIPPED 2026-09-12 (b7b5839): R/salience_surge.R ranks the salience percentile among NON-ZERO values only (docs/reviews/salience-percentile-fix-2026-09-12.md). Read in R/, reaches every caller of the surge model.
- **`AUSPOL_SALIENCE_SMOOTH`** (intentional / dead experiment): Read inside R/salience_surge.R, not per-harness -- universal in practice.
- **`AUSPOL_SALIENCE_SURGE_V2`** (**OPEN GAP**): WA: OPEN GAP, not fixed. Marked `yes*` above because the switch's name appears only in a disclosure comment explaining that it is NOT wired -- WA has no surge-v2 hazard at all where every other harness does (docs/NEXT-STEPS.md's own "Open" item 3, still unaddressed). A plain grep of the file would otherwise call this cell a clean "yes" and hide the gap.
- **`AUSPOL_SD_DEPARTED`** (intentional / dead experiment): UNDER TEST, default 0, not adopted: widens the per-cell sd for major-party cells whose previous winner is off the ballot. Read inside R/xgb_primary_sd_override.R, reached by the fed and nsw harnesses that call it; the other four never call the sd override at all (see AUSPOL_XGB_PRIMARY_SD). plans/prereg-departed-member-width-2026-09-16.md
- **`AUSPOL_SEAT_CONTEXT_FILL`** (**shipped, fitting-time switch (reaches harnesses via the artifact)**): FITTING-TIME. SHIPPED 2026-09-28 as v46: fills incumbent party / retiring member from output/seat-context.csv when the xgb training table is built (scripts/fit_xgb_primary_v6.R); baked into the trained model, no harness or live read.
- **`AUSPOL_SEAT_CONTEXT_MARGIN`** (intentional / dead experiment): ARM, not shipped (default 0; phase 2 of plans/prereg-seat-context-complete-2026-09-28.md). Read in scripts/fit_xgb_primary_v6.R (training) and R/xgb_primary_override.R (the 'all' mode, live). Off, so nothing differs by entry point.
- **`AUSPOL_SEAT_POLL_COALITION_DEDUP`** (**adopted, shared-function wiring**): SHIPPED 2026-10-07 (data fix). Read in .read_seat_polls_file() in R/seat_poll_blend.R, which all six harnesses and fit_seats_full.R reach through the seat-poll blend; the weight fit and the blend see the same polls.
- **`AUSPOL_SEAT_POLL_HANDKEYED`** (**adopted, shared-function wiring**): SHIPPED 2026-10-06 (Pete override). Read in .read_seat_polls_file() in R/seat_poll_blend.R; reaches every entry point through the blend.
- **`AUSPOL_SEAT_POLL_IND_MAP`** (**adopted, shared-function wiring**): SHIPPED 2026-10-06 (Pete override). Read in seat_poll_shares() in R/seat_poll_blend.R; reaches every entry point through the blend.
- **`AUSPOL_SEAT_POLL_IND_WEIGHT`** (**adopted, shared-function wiring**): SHIPPED 2026-10-06 (Pete override). Read in R/seat_poll_blend.R (.ind_weight_on(), seat_poll_blend_apply()); reaches every entry point through the blend. It errors if combined with AUSPOL_SEAT_POLL_MATCH=perpoll.
- **`AUSPOL_SEAT_POLL_MATCH`** (intentional / dead experiment): TESTING, default 'class' (plans/prereg-seat-poll-per-poll-match-2026-09-29.md). Read in R/seat_poll_blend.R; 'perpoll' is built for blend mode 1 only and backtests only until shipped, so no live wiring is expected.
- **`AUSPOL_SEAT_POLL_SOURCES`** (intentional / dead experiment): TESTING, default 'all' (plans/prereg-seat-poll-public-only-2026-09-29.md). Read in seat_poll_shares() in R/seat_poll_blend.R, which every entry point reaches; the harness grep cannot see it.
- **`AUSPOL_SEAT_POLL_TPP_SOURCE`** (intentional / dead experiment): TESTING, default 'all' (plans/prereg-seat-poll-tpp-direct-2026-09-30.md). Read in R/seat_poll_joint.R, which implements blend mode 3 (joint primary and two-party weights); it only matters under that mode.
- **`AUSPOL_SEAT_POLL_W_SINGLE_CLUSTER`** (**adopted, shared-function wiring**): SHIPPED 2026-10-07 (bug fix: a weight fitted on one cluster gets SE Inf, not ~0). 'legacy' restores the old factor for screening only. Read at R/seat_poll_blend.R line ~393 inside all three weight fits, so every entry point gets it.
- **`AUSPOL_SEAT_SWING_PORT_NOCLIFF`** (intentional / dead experiment): PREREG PENDING, default 0 (built 2026-10-05). Read inside R/seat_swing_port.R, which the nsw/qld/sa/vic/wa harnesses and fit_seats_full.R all call; only the wa harness also names it (an output-filename tag), and scripts/dry_run_seat_swing_port_wa.R sets it. So the matrix's wa-only 'yes' is a naming artefact, not wiring.
- **`AUSPOL_SEAT_SWING_PORT_WA`** (**adopted, shared-function wiring**): SHIPPED 2026-10-06 (Pete override; mode 2). WA-ONLY by design (Pete: 'why is WA special?'; wa2025 -0.0064 log loss, nothing else moves): read in R/seat_swing_port.R and the wa harness only. Mode 2 pools WA cycles for WA targets alone, so the other harnesses and the live Victoria run are intentionally untouched.
- **`AUSPOL_SHIP_TIME_FORWARD`** (**adopted, shared-function wiring**): SHIPPED as a leak fix (ledger v51, 2026-09-29). Read in R/split_slope.R, which the six harnesses use for the minor-slope tiers; fit_seats_full.R does not name split_slope (function-name grep), so the published path is not shown to read it. Not traced further.
- **`AUSPOL_SIM_ENGINE`** (intentional / dead experiment): Read inside R/seat_sim.R's simulate_seat_contests(), not per-harness -- universal in practice.
- **`AUSPOL_SITTING_MEMBER_ADJ`** (intentional / dead experiment): ARM, not shipped (default 0; plans/prereg-sitting-member-baseline-2026-09-28.md). Read in R/xgb_primary_override.R and scripts/fit_xgb_primary_v6.R, i.e. at xgb training and in the override, not in a harness.
- **`AUSPOL_SLOPE_SHRINK`** (intentional / dead experiment): ARM, not shipped (default 0; plans/prereg-slope-shrinkage-2026-09-28.md). Read through .slope_shrink_on() in R/split_slope.R, which the six harnesses call; if adopted it needs a published-forecast check since fit_seats_full.R does not name split_slope.
- **`AUSPOL_SPLIT_SLOPE`** (intentional / dead experiment): REFUSED 2026-09-09, and harmfully so (docs/plans/ prereg-partial-return-split-slope-2026-09-09.md): it discarded the existing conditional-slope system instead of refining it. Harness-only by design, same reasoning as AUSPOL_FIT_SLOPES.
- **`AUSPOL_STATE_DEV`** (**adopted, shared-function wiring**): ADOPTED 2026-09-15 and FEDERAL ONLY, which is a design fact rather than the all-harnesses rule outstanding: a state election has no deviation from a national swing to correct, so the other five harnesses have nothing to honour. Corrects a federal seat's primaries for how its STATE moves against the national swing -- WA 2022 swung to Labor far harder than the country (mean ALP per-seat primary error +6.43 over 15 seats, positive in 14). Federal pooled seat log loss 0.2584 -> 0.2539 over 1,052 seat-elections, 0 of 10 permutation-control draws beating it. fit_seats_full.R reads NO for the same reason the state harnesses do; the published Victorian forecast is unaffected. docs/plans/prereg-state-deviation-2026-09-15.md
- **`AUSPOL_STATE_DEV_SHUFFLE`** (intentional / dead experiment): Control for the above, not an arm: permutes which state each seat sits in, within its election, at fit and apply both. Absent from fit_seats_full.R because a control has no business in the published forecast. Calibrated -- the null lands on the baseline to within 0.0001 pooled.
- **`AUSPOL_STATE_NOTIONAL`** (**adopted, shared-function wiring**): SHIPPED v57 and STATE-BACKTEST-ONLY by design: the state notional prior replaces the prior only on state pairs preceded by a redistribution (STATE_REDISTRIBUTIONS, R/state_notional.R). The federal harness has its own (AUSPOL_NOTIONAL), and the published Victoria forecast needs none: 2026 is fought on the 2022 boundaries. plans/prereg-state-notional-2026-10-01.md
- **`AUSPOL_STATE_POLL_EXTRA`** (**shipped, fitting-time switch (reaches harnesses via the artifact)**): FITTING-TIME, TESTING (default 0; plans/prereg-state-polls-extra-2026-10-02.md). Read only in scripts/build_state_deviation_features.R, which builds the state-deviation features the xgb model trains on.
- **`AUSPOL_STATE_POLL_POOL`** (**adopted, shared-function wiring**): SHIPPED v60 2026-10-02 (Pete overrode the prereg clause). FEDERAL-HARNESS-ONLY by design: pools a state signal from seat polls before the seat-poll blend (R/state_poll_pool.R); published_flags.R states 'federal harness only'. Only backtest_candidate_fed.R calls it.
- **`AUSPOL_SURGE_FROM_ZERO`** (intentional / dead experiment): WA has no candidate-level salience corpus -- same exclusion as AUSPOL_SALIENCE_EXPECTED, intentional.
- **`AUSPOL_TIME_FORWARD_FITS`** (**adopted, shared-function wiring**): SHIPPED as a leak fix (2026-09-28): every constant fitted inside base_pred learns only from earlier elections. Read in R/time_forward.R and R/fundamentals_tf.R (also part of cache keys), below the harness grep; reaches every entry point.
- **`AUSPOL_UPSET_FLOOR`** (**OPEN GAP**): OPEN GAP: TESTING, default 0, live-script only. Read in fit_seats_full.R (stage 6b) and scripts/promote_rebuild.R; no harness reads it. Checked: published_flags.R comment ('time-forward upset insurance for minor contenders') and the two call sites; the reason no harness scores it was not established, and docs/plans/prereg-upset-floor-2026-10-02.md was not read for it. Decide before adopting.
- **`AUSPOL_WA_CUTOFF`** (intentional / dead experiment): Read inside R/external_flows.R (pool_configured_flows), not per-harness -- universal in practice (added to published_flags.R 2026-10-08 at its code default).
- **`AUSPOL_WA_DROP_3C`** (intentional / dead experiment): Read inside R/external_flows.R (pool_configured_flows), not per-harness -- universal in practice (added to published_flags.R 2026-10-08 at its code default).
- **`AUSPOL_WA_DROP_LNP`** (intentional / dead experiment): Read inside R/external_flows.R (pool_configured_flows), not per-harness -- universal in practice (added to published_flags.R 2026-10-08 at its code default).
- **`AUSPOL_WA_FLOWS`** (intentional / dead experiment): Self-referential no-op in the WA harness itself, same shape as AUSPOL_QLD_FLOWS above but not disclosed via an `.inert` list there. Genuinely absent from QLD (uses AUSPOL_QLD_FLOWS instead).
- **`AUSPOL_XGB_BASE_DELTA`** (**adopted, shared-function wiring**): SHIPPED 2026-10-06 with AUSPOL_REENTRY='majors'. HARNESS-ONLY by design: read inside xgb_primary_override() (R/xgb_primary_override.R, R/xgb_base_delta.R); the live forecast gets the same effect through base_margin (xgb_primary_predict_live()).
- **`AUSPOL_XGB_BASE_DELTA_TOL`** (**adopted, shared-function wiring**): SHIPPED companion of AUSPOL_XGB_BASE_DELTA (tolerance in percentage points); read only in R/xgb_base_delta.R, so inert unless that switch is '1'. Harness-only for the same reason.
- **`AUSPOL_XGB_BASE_MARGIN`** (intentional / dead experiment): Training-time switch for the XGBoost primary models (fit_xgb_primary_v6.R, _v6_final.R, _asat.R), not a harness or forecast switch -- which is why no harness row reads it. 2 (shipped 2026-09-17) = base_pred set as the training DMatrix's base_margin AND kept as a feature, so every tree boosts on the residual to the shipped model's own prediction; 1 = offset only; 0 = plain feature. xgb_primary_predict_live() must set the same base_margin at predict time, and does. Classified 2026-09-18; it had sat UNEXPLAINED in this table since it shipped.
- **`AUSPOL_XGB_BASE_RECORD`** (intentional / dead experiment): Measurement plumbing, not a model change (default 0): scripts/rebuild_forecasts.sh sets it for stage 1 so the disabled override writes the reference shares AUSPOL_XGB_BASE_DELTA compares against. Read in R/xgb_primary_override.R only.
- **`AUSPOL_XGB_BOOTH`** (**shipped, fitting-time switch (reaches harnesses via the artifact)**): FITTING-TIME, TESTING (default 0; plans/prereg-booth-features-2026-10-02.md). Booth spread / early-vote gap xgb features; read in scripts/fit_xgb_primary_v6.R and scripts/promote_rebuild.R, baked into the trained model.
- **`AUSPOL_XGB_COUNCIL`** (**shipped, fitting-time switch (reaches harnesses via the artifact)**): FITTING-TIME. SHIPPED v58 2026-10-02: council-history xgb features, read in scripts/fit_xgb_primary_v6.R and scripts/promote_rebuild.R; baked into the trained model artifact, so no harness reads it.
- **`AUSPOL_XGB_DEPARTED_SIDE`** (**shipped, fitting-time switch (reaches harnesses via the artifact)**): FITTING-TIME, ARM (default 0; plans/prereg-departed-member-sides-2026-09-28.md). Adds own_departed_i / opp_departed_i xgb features via add_departed_side() (R/departed_side.R), called from fit_xgb_primary_v6.R and _v6_final.R; baked into the trained model.
- **`AUSPOL_XGB_ENDORSE`** (**shipped, fitting-time switch (reaches harnesses via the artifact)**): FITTING-TIME. SHIPPED v59 2026-10-02: Climate 200 / Voices endorsement xgb features, read in scripts/fit_xgb_primary_v6.R and scripts/promote_rebuild.R; baked into the trained model.
- **`AUSPOL_XGB_ENSEMBLE`** (**shipped, fitting-time switch (reaches harnesses via the artifact)**): FITTING-TIME. SHIPPED v58 2026-10-02: K=3 seed-varied xgb fits averaged. Read in fit_xgb_primary_asat.R and fit_xgb_primary_v6_final.R (training only), so no harness or live read exists.
- **`AUSPOL_XGB_PRIMARY_LIVE`** (intentional / dead experiment): Published-forecast-only (fit_seats_full.R), the live counterpart of AUSPOL_XGB_PRIMARY above. Loads output/xgb-primary-v6-final.model, trained on all 22 historical pairs -- correct here and leakage in a backtest, which is exactly why the two switches exist separately.
- **`AUSPOL_XGB_PRIMARY_OOF`** (intentional / dead experiment): Harness-only escape hatch naming which out-of-fold file AUSPOL_XGB_PRIMARY reads; empty means the v6 default. Exists because the unversioned filename is v1's, and until 2026-09-11 the backtest arm measured v1 while the live forecast shipped v6 -- the two were never describing the same model. Not a modelling switch; no published-forecast analogue.
- **`AUSPOL_XGB_PRIMARY_SD`** (intentional / dead experiment): OFF (0). The xgb spread model's per-cell sd, read in R/xgb_primary_sd_override.R and wired into fed and nsw only. With the switch off nothing reaches any output, so the four unwired harnesses are not a live parity gap; if it is ever adopted the wiring must be ported to all six in the same commit (CLAUDE.md rule).
- **`AUSPOL_XGB_PRIMARY_SD_CLASSES`** (intentional / dead experiment): Companion of AUSPOL_XGB_PRIMARY_SD (which classes it widens); read only inside R/xgb_primary_sd_override.R, so inert wherever that switch is off. Same wiring status as its parent.
- **`AUSPOL_XGB_PRIMARY_SD_SRC`** (intentional / dead experiment): Companion of AUSPOL_XGB_PRIMARY_SD (the OOF file it reads); read only inside R/xgb_primary_sd_override.R. Same wiring status as its parent.
- **`AUSPOL_XGB_SEATPREV_NAFILL`** (**adopted, shared-function wiring**): SHIPPED 2026-09-13/18: seat_outperf and seat_prev_pcv NA cells are filled with 0 at feature-build time (scripts/fit_xgb_primary_v6.R), so the switch is baked into the trained model artifact; no harness reads it.
- **`AUSPOL_XGB_SEED`** (**shipped, fitting-time switch (reaches harnesses via the artifact)**): FITTING-TIME: the xgb training seed (fit_xgb_primary_*, fit_xgb_flows_asat.R). Varied only to measure how much an equally valid refit moves the metrics (plans/noise-floor-2026-10-02.md); no harness or live read.
- **`AUSPOL_XGB_SENATE`** (intentional / dead experiment): OFF, REFUSED 2026-10-01 (three arms: all parties, minor only, geography only) -- each cost Victorian Labor or lost the gains. Read only in fit_xgb_primary_v6.R and xgb_primary_override.R, so 'no' in the harness columns is by design. plans/prereg-xgb-senate-2026-10-01.md
- **`AUSPOL_XGB_SURGE`** (intentional / dead experiment): Harness-only and wired into backtest_candidate_sa.R ALONE, which is this file's own 'a fix to one harness is a fix to all of them' rule outstanding rather than satisfied. Built, measured, NOT shipped: the hazard is much better than the salience one it would replace (out-of-fold AUC 0.936 against 0.751) but it failed its pre-registered bar and a calibration check says it is now over-dispersed. Its live path is an unimplemented stub, so fit_seats_full.R cannot honour it even if asked. docs/plans/prereg-xgb-surge-parameters-2026-09-11.md
- **`AUSPOL_XGB_SURGE_SRC`** (intentional / dead experiment): Companion of AUSPOL_XGB_SURGE (which emergence model file to read: v5 candidate-level); read only inside R/xgb_surge_override.R, so it reaches exactly the harnesses that honour AUSPOL_XGB_SURGE.

## Gaps the switch-presence matrix cannot see

A grep for a switch's name proves the name is mentioned, not that the
VALUE it's set to is fully honoured. Hand-maintained because there is no
mechanical test for "is this harness doing the whole thing the switch
asks for":

- **`AUSPOL_DEV_SLOPE_MODE=screened` is only half-honoured in WA.** The
  switch functionally reads and WA does apply the conditional-slopes
  half; it has no `salience_permit_for()`/`screened_slopes()` wiring at
  all, so the salience-screen half of "screened" never fires there.
  Disclosed at runtime (`BW1c!`) since 2026-09-08. Open, not fixed --
  see `docs/NEXT-STEPS.md`.

## Fixed this session (2026-09-08/09), for history

- WA's `SEED` was a hardcoded literal (`20260825L`), ignoring
  `AUSPOL_SEED` entirely -- every WA run before 2026-09-09 used one fixed
  seed regardless of the env var. Fixed; WA's *default* seed (20260825)
  still differs from the other five harnesses' (42), unchanged on
  purpose so nothing already published moved silently.
- `AUSPOL_SEAT_SD_MULT`, `AUSPOL_FALLBACK_SMOOTH` and `AUSPOL_FLOW_SD`
  were registered in `published_flags.R` and honoured by all six
  backtest harnesses, but never wired into `fit_seats_full.R` at all.
  Fixed 2026-09-09; harmless while shipped at their no-op defaults.

## Switches a harness FORCES away from its published value

Honouring a switch and running at its published value are different questions, and this table asked only the first until 2026-09-14. A harness that reads a switch and then `Sys.setenv()`s it scores a clean "yes" above while measuring a configuration the forecast does not ship. Detected mechanically below, so it cannot go stale.

MR3  no harness forces a switch away from its published value.

## Coverage check

MR2  every non-universal switch (120 of 156) has a recorded classification.
