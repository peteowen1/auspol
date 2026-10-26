# Audit F8, F10, F12-F19: status against the code, 2026-10-25

Read-only re-check of the open findings in
[pipeline-overwrite-audit-2026-10-18.md](pipeline-overwrite-audit-2026-10-18.md) against HEAD `37ccddf`
(dev, clean). Every file:line below was read today. No R was run. Magnitudes come from the log of today's
live walk, `deciding-runs/20261025-minor-additive-walk/add.log` (published flags plus
`AUSPOL_MINOR_ADDITIVE=1`, which has since shipped), and from tables in `output/`. Anything marked
**UNVERIFIED** was not measured; the text says where I looked.

## Ranked summary

Columns: rank by expected effect on the published Victorian forecast (`scripts/fit_seats_full.R`), the
finding, today's verdict (LIVE = still in the code, FIXED, WRONG = the claim does not hold), whether it
reaches the published forecast or only the backtests, the size seen in today's live log, and how a fix
would be screened. Bigger effect ranks higher.

| Rank | ID | Verdict | Reaches published Vic? | Size seen today | Screen for the fix |
|---|---|---|---|---|---|
| 1 | F8 | LIVE | Yes, all 88 seats | port moves ALP/LNP by sd 1.55 points (range -5.98 to +4.41); demographic adj ALP mean 0.47, GRN 0.39; leader +2.72 in 3 seats; all fitted on residuals that ignore the steps before them | `quick_arm.R`, AEF-7 then `--pairs=all` (post-xgb, so the cached trees are valid) |
| 2 | F12 | LIVE | Yes, every cell's `level_pred` feature | live `level_pred` ALP -0.6, LNP -0.4, GRN +0.1 against the training recipe, about +0.9 pushed into ONP/OTH pro rata | live walk diff now; the real fix (train with the blend) needs a stage-3 rebuild, not `quick_arm` |
| 3 | F16 | LIVE | Yes, salience blend now hits 43 cells (31 seats) | each salience lift delivered roughly 85-90% after the whole-row rescale (arithmetic, not measured); seat-poll blend: 1 cell, mean change 0.00 | `quick_arm.R` on salience pairs |
| 4 | F18 | LIVE | Yes (training base differs from live base) | not measurable before nominations; persists after them as an ordering difference | needs a stage-1 rebuild, or a live walk once the VEC list is in |
| 5 | F17 | LIVE | Yes (staleness) | 0 today (one Vic seat poll, unchanged since Aug 2025); tables on disk stamped 21 Oct 17:34 | ops change, not a model arm |
| 6 | F13 | WRONG (main claim); overwrite is by design | Not now (no vic2026 card row) | 0 today | `quick_arm.R "AUSPOL_HTV_FLOW=0"` on the 9 pairs with a card row, if wanted |
| 7 | F10 | LIVE | Yes, Mildura (and any sitting IND/OTH_RIGHT member) | IND 0.939 live vs ~0.946 harness-style; about 0.2 points on Mildura's IND cell (estimate) | live walk diff only |
| 8 | F19 | LIVE | No (federal backtest only) | n/a for Vic | `quick_arm.R` on the 7 federal pairs |
| - | F14 | LIVE, design not defect | Yes | projection's -0.88 two-party mean shift erased (LL2) | none proposed |
| - | F15 | LIVE, design notes | Yes | one stale comment remains | none |

**AUSPOL_MINOR_ADDITIVE (shipped today) interacts with F8, F10 and F12, and with none of the others.** See
the last section.

---

## F8 (c) Post-xgb corrections fitted on raw xgb residuals and stacked: LIVE

**Evidence.**
- Order in the published script: trees `fit_seats_full.R:1410`, `ind_person` final `:1423`, seat-swing port
  `:1431`, seat-poll blend `:1439`, demographic `:1448-1449`, leader `:1459`, salience blend `:1479`.
- Every correction except the port learns from `current_seat_predictions()` (`R/seat_predictions.R:16-21`),
  which returns the stage-4 as-at xgb prediction and nothing applied after it. Readers:
  `R/demographic_residual.R:129`, `R/leader_seat.R:90`, `R/seat_poll_blend.R:333, 534, 598, 736, 1051`,
  `R/state_poll_pool.R:99`, `R/state_deviation.R:323`.
- The port is fitted on the seat's actual two-party swing against its transposed federal swing
  (`R/seat_swing_port.R:30-60`, `yy` from `seat-tpp-estimates.csv`). That is the total effect, not what the
  trees leave behind. The trees already have `fed_swing` as a feature (`output/xgb-primary-v6-final-cols.json`;
  served live at `R/xgb_primary_override.R:390`; trained at `scripts/fit_xgb_primary_v6.R:397, 813`).
- So the demographic and leader fits regress `actual - xgb` on their features without first removing the
  port, which is applied before them. The port coefficient is fitted as though no tree had seen `fed_swing`.

**Cost.** From `add.log`: the port moves ALP/LNP in all 88 seats (`SP2 ... sd 1.553 range -5.98..+4.41`,
line 165, coef 0.424). DR1 (lines 3600-3602) adjusts ALP on seven census columns and GRN on education.
LS1 (line 3605) adds +2.72 in Niddrie (ALP), Melbourne (GRN) and Kew (LNP). The poll blend touches one cell
(Hawthorn LNP, `SPB ... mean |change| 0.00`, line 3599), so it barely counts for Vic. The port did measure
well ON TOP of the trees when it shipped (`docs/plans/prereg-seat-swing-port-v2-2026-09-29.md:66-77`: ledger
0.2840 -> 0.2756, vic2022 -0.0073), so the trees do not absorb all of it. Whether the coefficient is right,
or whether the demographic ALP term chases part of the same seat residual, is **UNVERIFIED** (no run). This
is the largest stack touching every Victorian seat, so it ranks first on potential, not on a measured size.

**Smallest fix, two switches, both default "0".**
1. `AUSPOL_POSTXGB_RESID_NET="1"`: in `current_seat_predictions()` (`R/seat_predictions.R:17-21`), after
   `xgb_pred_seat` is built, for each state election add `seat_swing_port_adj(election, seats)` to the ALP
   row and subtract it from LNP, exactly as `seat_swing_port_apply()` does (`R/seat_swing_port.R:229-234`),
   and renormalise per seat. Then the demographic, leader and poll-blend fits learn from residuals net of
   the port. Give the function a `net = FALSE` argument so item 2 can read the raw version without a loop.
   Each election's port adjustment is fitted on cycles before it (`R/seat_swing_port.R:37`), so this stays
   time-forward.
2. `AUSPOL_SEAT_SWING_PORT_RESID="1"`: in `seat_swing_port_coef()` (`R/seat_swing_port.R:39-52`), replace
   `yy` (two-party swing deviation) with the seat's xgb residual in two-party terms,
   `((actual_ALP - xgb_ALP) - (actual_LNP - xgb_LNP)) / 2`, demeaned within the cycle, from
   `current_seat_predictions(net = FALSE)`. That gives the share of the federal swing the trees leave.

Add both to `scripts/published_flags.R` and `docs/CONSTANTS.md` as arms. **Screen:** both act after the
trees, so `quick_arm.R` sees them on cached tree predictions:
`Rscript scripts/quick_arm.R "AUSPOL_SEAT_SWING_PORT_RESID=1"` (AEF-7 default; the port acts on the state
pairs, so federal pairs should score exactly 0, which doubles as the check that it ran), then
`"AUSPOL_POSTXGB_RESID_NET=1" --pairs=all`. Item 1 moves federal pairs too, because the demographic and
leader fits pool every earlier election. Confirm the scratch copy carries
`output/xgb-primary-asat-predictions.csv` (`scripts/quick_arm.R:88` points `src_output` at it; not
otherwise checked).

## F10 (e) Sitting-member slope table differs, live vs harness: LIVE

**Evidence.** `scripts/fit_seats_full.R:916-931` still reads `output/mp-slope-by-class.csv` (pooled, no
shrinkage, `n_member >= 8L` cliff at `:928`, GRN dropped). Every harness reads
`AUSPOL_MP_SLOPE_FILE` = `output/mp-slope-by-target.csv` (vic `:485`, fed `:927`, nsw `:559`, qld `:518`,
sa `:569`, wa `:294`, nt `:329`), which is time-forward and shrunk (`scripts/fit_mp_slope.R:241-258`).
`published_flags.R:737` names that file as the shipped one. Live today: `CAL MP tier: IND=0.9391
OTH_RIGHT=0.9605` (`add.log:45`). The latest harness rows (vic2022): IND 0.946, OTH_RIGHT 1.000. There is
no vic2026 row: `fit_mp_slope.R:232` builds targets from completed elections only. The by-class file is
git-tracked and the by-target file is not, so the daily CI run could not read the latter anyway.

**Cost.** Small. Only seats with a sitting IND or OTH_RIGHT member re-contesting; Mildura (Ali Cupper)
is the clear one. With `AUSPOL_MINOR_ADDITIVE=1` the slope now scales Cupper's whole deviation from the
class level (about 28 points), so a 0.007 slope gap is roughly 0.2 points on her base (my arithmetic,
UNVERIFIED), and then passes through the trees as `base_margin`.

**Smallest fix.** `AUSPOL_LIVE_MP_SLOPE_TF="1"` (default "0"):
- `scripts/fit_mp_slope.R:232`: append the live targets (`"vic2026"`) to `g_targets` when the switch is on;
  `elections_before()` then trains on every completed election, with the same shrinkage.
- `scripts/fit_mp_slope.R:262-263`: the guard `sum(.train_mask(tg)) < nrow(panel)` would fail for a live
  target (every row is earlier). Apply it to completed targets only.
- `scripts/fit_seats_full.R:917-930`: under the switch read `output/mp-slope-by-target.csv`, take the rows
  where `target == .tgt_mp` (copy `TGT` to a differently named local first: data.table NSE), drop GRN as
  now, no `n_member` floor.
- Ship the by-target file to CI (commit it like the by-class file, or add it to the `forecast.yaml:166-169`
  download list).

**Screen.** Live-only by construction (the harnesses already use this table), so `quick_arm.R` cannot see
it. Run a live walk diff like `deciding-runs/20261025-minor-additive-walk/` and read Mildura's IND cell.

## F12 (e) `level_recent` reaches live `level_pred`, not training `level_pred`: LIVE

**Evidence.**
- Training: `scripts/build_level_pred.R:84-86` calls `forecast_statewide_for()` (`R/forecast_statewide.R:56`),
  which has no blend. The blend is only in `forecast_statewide_or_oracle()` (`R/forecast_statewide.R:407`),
  the federal harness (`backtest_candidate_fed.R:1365`) and live (`fit_seats_full.R:627`).
  `fit_xgb_primary_v6.R:334-344` reads `level-pred.csv` as `level_pred` (`AUSPOL_LEVEL_MODE=pred`).
  Stage 1 also runs with `AUSPOL_LEVEL_RECENT=0` (`scripts/rebuild_forecasts.sh:245`).
- Live: `state_mean` is overwritten by the blend at `fit_seats_full.R:631`, and `.level_split` is built
  from that blended `state_mean` (`:1380-1381`), which `xgb_primary_predict_live()` uses as `level_pred`
  (`R/xgb_primary_override.R:275-276`).
- The blend also moves the classes it does not fit: `level_recent_apply()` takes its net change out of every
  other class pro rata (`R/level_recent.R:307-309`).

**Cost.** `add.log:28`: `w 0.83: ALP 25.2->24.6, LNP 29.3->28.9, GRN 14.2->14.3`, so about +0.9 points go
to ONP and OTH (final levels at `statewide-level-vic-2026-walk-add.csv`: ONP 21.77, OTH 10.34). The trees
see a `level_pred` built by a recipe they were never trained on, in every cell. Because `TRAIN_DEMEAN=1`
(`published_flags.R:735`) stops the trees moving a class's level, the effect runs only through
interactions with `level_pred` and `growth_ratio`, so it is probably a few tenths at most per cell
(**UNVERIFIED**). The blend's effect on the base (`base_margin`) is intended and was scored; only the
feature mismatch is in question.

**Smallest fix.**
- Diagnostic, live only: `AUSPOL_LIVE_LEVEL_PRED_TREND="1"` (default "0"). Before `fit_seats_full.R:627`
  save `.state_mean_trend <- state_mean`. At `:1380-1382` build `.level_split` from `.state_mean_trend`
  under the switch, including the sum check. `base_margin` keeps the blended level.
- Real fix, training side: `AUSPOL_LEVEL_PRED_RECENT="1"` in `scripts/build_level_pred.R` after `:86`:
  `r$st_fc <- level_recent_apply(r$st_fc, pr, reg, DATES[[pr]])`. This matches what
  `forecast_statewide_or_oracle()` does. Retrain stages 3-5.

**Screen.** Neither shows in `quick_arm.R`, which reuses cached tree predictions (the same reason
`AUSPOL_TRAIN_DECAY_H=4` needed its own rebuild, NEXT-STEPS line 55). For the diagnostic, a live walk diff.
For the real fix, an isolated rebuild from stage 3, scheduled like `auspol-decay4-rebuild` once 8 GB is free.

## F13 (a) How-to-vote card overrides the xgb flow ALP:GRN split: WRONG on its main claim; the overwrite is by design

**Evidence.**
- Order is as described: `fit_seats_full.R:1795-1804`, xgb flow rows, then `htv_flow_override()`
  (`R/htv_flow.R:100-139`), which rewrites ALP and GRN on every `LNP|...` key to `tot * share`
  (`:123-129`) and copies the attributes, including `sd`, through (`:134`).
- The audit said the HTV gain "was measured ... before the xgb flow rows existed". **That is wrong.**
  `AUSPOL_XGB_FLOWS` shipped 2026-09-11 (`published_flags.R:113-118`). The HTV prereg was measured on
  2026-09-18 and explicitly overrides "statewide or per-seat xgb override" rows
  (`docs/plans/prereg-htv-flow-2026-09-18.md:23-25`). Result: ALP-v-GRN two-candidate error 6.19 -> 5.08,
  3.5 SE, 20 of 26 seats better (`:51-67`). What it did NOT have was the xgb primary layer
  (`AUSPOL_XGB_PRIMARY=0`, `:36`). The primaries do not feed the flow rows' ALP:GRN split, so that matters
  little.
- The xgb flow model has no card feature (`scripts/fit_xgb_flows_v1.R:204-208`), so the card is not counted
  twice.
- Every harness applies it in the same place, after the xgb flow rows (vic `:1035`, fed `:1895`, nsw
  `:1151`, qld `:1126`, sa `:1309`, wa `:786`, nt `:816`).

**Cost.** None today. `external/reference/htv/liberal-alp-grn-order.csv` has no vic2026 row
(`HTV0 no how-to-vote entry for vic2026`, `add.log:3626`). When a row is added it will move the ALP-v-GRN
seats (Melbourne, Richmond, Brunswick, Northcote, Footscray, Preston, Pascoe Vale and so on), which is what it
is for. The leftover nit: the flow `sd` attribute describes rows the card replaced.

**Fix.** None needed. If Pete wants it re-confirmed on top of the xgb primary layer:
`quick_arm.R "AUSPOL_HTV_FLOW=0" --pairs=vic2018,vic2022,qld2020,qld2024,fed2019,fed2022,fed2025,nsw2019,nsw2023`.

## F14 (d/f) Statewide mean in the draws is cancelled; only the spread survives: LIVE, design not defect

**Evidence.** `R/seat_sim.R:1029` `centre <- colMeans(statewide_draws)`, applied as deviations at `:1232` and
`:1409`. `fit_seats_full.R:1645` prints the anchoring mean shift, then `:1647-1649` applies it to the draws,
where the simulator removes it.

**Cost.** `add.log:3610`: `LL2 draws' anchoring mean shift -0.879 (LL1 off)`. The projection's two-party
(48.13, `add.log:20`) is about 0.9 below what the trend level implies (49.00, `add.log:34`). That gap never
reaches a seat mean. This was decided: `AUSPOL_LIVE_LEVEL_ANCHOR="0"` with `LEVEL_RECIPE="live"`
(`published_flags.R:662, 765`; un-anchored scored better over 22 elections). The note stands: an arm that
only moves the draws' mean, such as `AUSPOL_ANCHOR_IMPLIED` or `AUSPOL_FLOW_SHIFT`, is inert by
construction. No fix proposed.

## F15 (a) Deliberate overwrites: LIVE, design notes

- ONP column overwritten: `fit_seats_full.R:1317-1333`. Re-entry fills for ONP are noted as moot (`:1285`,
  `:1293`).
- `ind_person` final can only lower an IND cell, from `carry x record` (`R/ind_person.R:5-23`;
  `add.log:163`, Broadmeadows 5.2 -> 4.0).
- `TRAIN_DEMEAN=1` (`published_flags.R:735`).
- Still stale: `published_flags.R:56` says `AUSPOL_NOTIONAL` is "a no-op under AUSPOL_XGB_PRIMARY=1". The
  line after it (`:58`) says it never reaches Victoria at all, which is the accurate statement. This is a
  comment fix, not a model change.

## F16 (b) Whole-row rescale dilutes single-cell pulls: LIVE

**Evidence.** Seat-poll blend: pulled cells set, then `shares <- 100 * shares / rowSums(shares)`
(`R/seat_poll_blend.R:1028-1029`). Salience blend: the cell moved toward `surge_mu`, then the whole row
rescaled (`R/salience_surge.R:436-439`).

**Cost.** This matters more now than on 18 Oct. Vic2026 has a salience corpus: `XG5 salience corpus found
for vic2026: 43 of 616 seat-classes` and `DS3b salience point estimate applied to 43 (seat,party) cells`
(`add.log:156, 3606`). The surge hazard covers 31 seats (26 ONP, 5 IND), mean 0.052, mu 34.3
(`add.log:124-125`). For a 15-point ONP cell at p = 0.05 the lift is about 0.97 points, and after the
rescale about 0.82 is left (my arithmetic, about 85%). The other classes in that row lose share pro rata.
The poll blend touches one Vic cell with no change worth counting (`add.log:3599`). This finding does not
cover whether the salience lift itself is correct; that is F5, refused.

Note: `docs/NEXT-STEPS.md:72` says the vic2026 salience snapshots are "Not yet wired into the live forecast".
The walk log shows they reach it through XG5 and DS3b. Which salience file feeds `.hz` here was **not
confirmed**.

**Smallest fix.** `AUSPOL_ROW_SHIFT_EXACT="1"` (default "0"), the `.shift_cell` idea from
`R/leader_seat.R:157`: keep the moved cell at its new value and scale only the other cells to fill
`100 - new`.
- `R/salience_surge.R:439`: per row, scale the cells whose weight `w <= 0.001` to fill what the blended
  cells leave.
- `R/seat_poll_blend.R:1029`: scale only the cells not pulled.

**Screen.** `quick_arm.R "AUSPOL_ROW_SHIFT_EXACT=1"` on the pairs with a salience corpus or seat polls
(AEF-7 first). One caveat: the salience blend is also in stage-1 `base_pred` in the harnesses (F5), so the
deciding run needs a rebuild from stage 1, not stage 6.

## F17 (e) Daily CI uses correction tables frozen at the last promote: LIVE

**Evidence.** `.github/workflows/forecast.yaml:188-217` downloads `seat-swing-port`, `seat-poll-blend`,
`leader-seat`, `demo-resid`, `level-recent`, `spread-by-*` and `error-quantiles`. The table readers use the
file whenever `.has_seat_predictions()` is false (`R/seat_predictions.R:32-34`): `R/seat_poll_blend.R:803`
then the cache branch at `:841`, `R/leader_seat.R:128`, `R/demographic_residual.R:222`. CI also has no
`external/reference/polls/seat-polls/seat_polls.csv`: it is not git-tracked (only `hand_keyed_primaries`,
`mrp_candidates`, `poll_methods` and `seat_poll_corrections` are), and the workflow never downloads it. The
tables on disk are stamped 21 Oct 17:34.

**Cost.** Zero today: there is one vic2026 seat poll (Hawthorn, Freshwater for the Liberal Party, 14-16 Aug
2025, `seat_polls.csv:7233`), and it is already in the frozen table. A new Vic seat poll reaches the
published forecast only after a rebuild and promote. Victoria's pull weight is `w` 0.50 (`add.log:3599`),
so a delay could leave a polled cell several points off for days.

**Smallest fix (ops, not a model arm).** `AUSPOL_SEAT_POLL_CELLS_LIVE="1"` (default "0"): in the cache branch
of `seat_poll_blend_table()` (`R/seat_poll_blend.R:841`), when `seat_polls.csv` exists, rebuild `tb` from
`seat_poll_shares(target_election, by_type = TRUE)` and keep the frozen weights from the cache. Add a CI
step that runs `scripts/fetch_seat_polls.R` before the forecast. Check with a live walk, a byte-identical run
today (same single poll), and a test row to prove the path fires.

## F18 (e) Stage-1 base includes nomination zeroing; the live base does not: LIVE

**Evidence.** Stage 1 does not turn nomination zeroing off (`scripts/rebuild_forecasts.sh:245` forces
REENTRY, NEW_IND_SHRINK, DEPARTED_SUCCESSOR, IND_PERSON, GRN_TREE_SHRINK and LEVEL_RECENT to 0, but not
NOM_ZERO). `post_xgb_switches()` does not list it (`R/new_ind_shrink.R:40-46`). With
`AUSPOL_NOM_ZERO_ORDER=late` (`published_flags.R:569`) the harness call is not gated by `XGB_PRIMARY`
(vic `:947`, nsw `:1049`, qld `:1077`, sa `:1256`, wa `:677`, nt `:707`; fed `:1567` and `:1846`), so
stage-1 `base_pred` carries exact zeros and the freed share reallocated by flows (mode 2). Live: no
zeroing yet (`NZL ... NOT applied (provisional list)`, `add.log:3607`). After nominations it runs AFTER the
trees (`fit_seats_full.R:1497`).

**Cost.** Before the VEC list: every class that will not stand is carried in `base_margin`, so the
standing classes' base is lower than training's equivalent. After the list: the zeroing and reallocation
happen after the trees rather than before, an ordering mismatch that does not go away on 9 Nov. Size
**UNVERIFIED**. The arithmetic is similar either way, so it is probably small, but the trees'
`base_pred` feature differs.

**Smallest fix.** `AUSPOL_NOM_ZERO_PRE_XGB="1"` (default "0"), live only, meaningful once
`AUSPOL_NOM_LIVE=1`: also call `zero_unnominated_live()` just before `xgb_primary_predict_live()`
(`fit_seats_full.R:1410`), keeping the late call at `:1497` as the final guard. That matches training's
base. The alternative, adding `AUSPOL_NOM_ZERO=0` to stage 1 at `rebuild_forecasts.sh:245`, changes every
training row and needs a full rebuild. **Screen:** a live walk diff once the final list loads. The
stage-1 variant needs an isolated rebuild.

## F19 (c) Two state-signal corrections stacked, federal only: LIVE

**Evidence.** `backtest_candidate_fed.R:1513-1514` `state_poll_pool_apply()`, then `:1553-1558`
`state_deviation_apply()`, both after the trees. Both fit on `actual - xgb_pred` from
`current_seat_predictions()` (`R/state_poll_pool.R:99`, `R/state_deviation.R:66, 112, 323`) without removing
the other. Neither appears in `fit_seats_full.R` (grep) or any state harness.

**Cost.** Nothing on Victoria. It may misstate the federal backtest scores (7 pairs).

**Smallest fix.** `AUSPOL_STATE_DEV_NET_POOL="1"` (default "0"): in `state_deviation`'s residual build
(`R/state_deviation.R:66` and `:112`), subtract the time-forward `state_poll_pool` adjustment for each
earlier pair before averaging by state. **Screen:** first the two ablations,
`quick_arm.R "AUSPOL_STATE_DEV=0" --pairs=fed2010,fed2013,fed2016,fed2019,fed2022,fed2025` and the same with
`AUSPOL_STATE_POLL_POOL=0`. If each still helps without the other, test the netted arm.

---

## Does AUSPOL_MINOR_ADDITIVE interact with any of these?

The switch is read at `fit_seats_full.R:1269` and changes `:1273-1274`: IND, OTH_RIGHT and OTH move by
points from the 2022 level to the scaled one, not by a multiple. It acts before the trees and changes only
`base_margin` and the `base_pred` feature.

- **F8: yes, and it helps.** The post-xgb tables fit on as-at predictions whose state-harness bases were
  already additive (`backtest_candidate_vic.R:643-648` runs `dev_slope()` per class). Live was
  multiplicative until today, so the switch narrows the gap between the base the tables learned from and
  the one they are applied to. The federal harness keeps multiplying (commit `37ccddf`; `backtest_candidate_fed.R:1052`),
  so federal rows in those tables still come from a multiplicative base. That is a parity gap for the
  federal backtest, not for Victoria.
- **F10: yes, it raises the stakes slightly.** The MP slope from `.vic_slope()` now scales a sitting
  independent's whole deviation from the class level (`:1273`), not a scaled share. So the live-vs-harness
  slope gap acts on Cupper's ~28-point deviation in Mildura. Still about 0.2 points (estimate).
- **F12: yes, marginally.** The blend's +0.9 to the non-fitted classes (`R/level_recent.R:309`) raises
  `state_mean[["OTH"]]`, which sets `scale_to` (`:1254`). Under the additive path that increase lands as
  equal points in every seat rather than in proportion. It is about 0.3 points spread over three classes.
- **F13, F14, F15, F16, F17, F18, F19: no.** They act on flows, draws, after-tree steps or the federal
  harness, none of which read the minor-field base differently under the switch.

## What I could not confirm

- No magnitude above is a measured counterfactual. The F8, F12 and F18 effects on seat probabilities are all
  UNVERIFIED. The F10 and F16 figures are my arithmetic on numbers from the log.
- Which salience file feeds the vic2026 `.hz` that the walk log shows active (F16), and so whether
  `docs/NEXT-STEPS.md:72` ("Not yet wired into the live forecast") is stale.
- Whether `quick_arm.R`'s scratch copy includes `output/xgb-primary-asat-predictions.csv`. Line 88 points
  `src_output` at its directory; I did not read the copy filter.
- Which Victorian seats besides Mildura have a sitting IND or OTH_RIGHT member re-contesting (F10). I did not
  list them from the candidacies corpus.
