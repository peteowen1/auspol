# Delta re-simulation: can an arm reuse the baseline's fitted objects? (2026-10-11)

Phase 1 item 3 of `docs/plans/fast-iteration-plan-2026-10-11.md`. Read-only investigation: no harness was run,
nothing was timed. Every runtime figure below is an estimate from numbers already in the repo (plan table,
CLAUDE.md profile of 2026-10-07, `secs_guess` in `scripts/quick_arm.R:216`), and is marked as such.

Labels: **[V]** verified by reading the code at the cited line. **[I]** inference, not checked by running.

## Answer in one table

Downstream-only means: the switch's effect can be applied to saved baseline objects by re-running only a
suffix of the pipeline. The suffix is NOT always just `simulate_seat_contests()`.

| arm type | example switch | downstream-only? | suffix that must re-run | est. runtime avoided |
|---|---|---|---|---|
| (c) spread | `AUSPOL_SEAT_SD_MULT` | **YES, sim only** | `simulate_seat_contests()` + scoring tail | ~80-90% at 1,000 sims [I] |
| (b) cells | `AUSPOL_IND_PERSON=final` (shipped) | **YES** | every shares-dependent step after the xgb override, then the sim | ~50-85% [I] (depends on saving the hazard fit) |
| (b) cells | `AUSPOL_IND_PERSON=base` | YES, but longer | from before `xgb_primary_override()`: delta re-predict, then the same tail | ~40-80% [I] |
| (b) cells | `AUSPOL_SEAT_POLL_*` (blend, decay, sources, IND_MAP...) | **YES** | `seat_poll_blend_apply()` and everything after it | ~50-85% [I] |
| (a) level | `AUSPOL_LEVEL_RECENT`, `_HALFLIFE` | **Partly**: downstream of the pre-blend statewide, but NOT sim-only | the whole projection block from `sb` onward (about 400 lines in vic), but none of the fits | ~40-65% [I], big error bar |
| (a) level | `AUSPOL_LEVEL_MODE` | **NO** | not a harness switch at all; it changes the xgb TRAINING data | 0% (needs `fit_xgb_primary_asat.R` retrain) |

## The shape of the pipeline (all verified, vic harness; fed differs only where noted)

```
forecast_statewide_or_oracle()        vic:412   -> sb (statewide level)           [arm (a) enters here]
  forecast_statewide_for(), 20,000 draws, level_recent_apply() LAST        R/forecast_statewide.R:324-353
reentry_apply_harness(.., sb, ..)     vic:421   (reads sb)
dev_slopes / candidate_returns / personal_prior_vote / fit_* (target-excluded fits)   vic:439-596   [arm-independent, expensive]
per-party dev_slope(x_p, sa, sb, slope) -> shares   vic:634-650   (reads sb)
re-entry post-swing, renorm, IND zeroing           vic:654-711
new_ind_shrink_apply                  vic:758
ind_person_apply(stage="base")        vic:762   [arm (b) AUSPOL_IND_PERSON=base]
xgb_primary_override()                vic:763   -> reads CACHED as-at predictions, then xgb_base_delta_apply()
ind_person_apply(stage="final")       vic:765   [arm (b) AUSPOL_IND_PERSON=final, shipped]
ind_mixture_apply, zero_unnominated_at("early"), seat_swing_port_apply   vic:766-777
seat_poll_blend_apply                 vic:782   [arm (b) AUSPOL_SEAT_POLL_*]
edu/demo/leader/departed_fed          vic:789-810  (off or shares-only)
seat_swing_spread(.., sb ALP - sa ALP) vic:836  (see note 3)
surge_hazard_for + blend_salience_shares   vic:861-926   (fits arm-independent; blend reads shares)
zero_unnominated_at("late"), SD_OVR (xgb_primary_sd_matrix), flow overrides, breakout_mix_args   vic:932-1022
simulate_seat_contests(.. level_sd = .level_sd ..)   vic:1025
```

Fed has a real phase split that the others lack. The projection loop ends by pushing everything the simulator
needs into `out_all` (`backtest_candidate_fed.R:1579-1594`: K, shares, fm, truth, keep, parties, sd_w,
**sw_draws**, fb, nz_cells, REENTRY_CELLS) and a second loop does salience, SD overrides and the sim
(`:1618-1878`). Vic, NSW, QLD, SA and WA are single linear passes (WA and vic loop over pairs; NSW, QLD, SA run
one `TGT`). [V for fed and vic; NSW/QLD/SA/WA by the `ind_person_apply` grep hits only, I]

## Arm type (c): simulation spread. YES, simulation-only.

**`AUSPOL_SEAT_SD_MULT`**

- Read once at the top of each harness (`backtest_candidate_vic.R:86`; fed `:166`; nsw `:119`; qld `:110`;
  sa `:189`; wa `:90`; and `fit_seats_full.R:117`). [V]
- Effect: `.level_sd <- .level_sd * SEAT_SD_MULT` (vic `:99`) when `level_sd` is on (published
  `AUSPOL_LEVEL_SD = "1.10,8.67"`); `seat_sd * SEAT_SD_MULT` is inert in that case (vic `:89-93` says so). [V]
- Consumers of `.level_sd`: `simulate_seat_contests(level_sd=...)` (vic `:975`, `:1025`; fed `:1871`) and
  `reentry_sd_matrix()` only when `AUSPOL_REENTRY_SD_K > 0` (vic `:944`). [V]
- Nothing under `R/` reads the switch (grep of `Sys.getenv("AUSPOL_SEAT_SD_MULT"` over `R/` returns no hit). [V]
- It touches the output FILENAME (`CAL_TAG` `-m<x>`, vic `:214`), so a snapshot replay must write the arm's
  name, not the baseline's. [V]

Path: switch (`:86`) -> `.level_sd` (`:99`) -> `simulate_seat_contests()` (`:1025`). Nothing between depends on it.

**What must be saved from the baseline:** the complete argument list of the `simulate_seat_contests()` call,
plus what the scoring tail reads after it. For vic that is: `shares`, `fm`, `psd`, `sp$sd_within`, `SD_OVR`
(possibly NULL), `.level_sd` BEFORE the multiplier, `.lm(shares)` inputs, `.bo`, `surge_arg/surge_party_arg/
surge_mu_arg/surge_sd_arg`, `.htv_ov`, `PARTY_COR`, `SHRINK`, `FB_SMOOTH`, `SHRINK_K`, `FLOW_SD`, `SEED`,
`N_SIMS`; for fed also `sw_draws` (n_sims x ~10 doubles) and `shrink_arg`. Scoring needs `truth`, `keep`,
`win`, `fb`/`nz_cells` and the pair label. [V that these are the arguments; I that this list is complete for
the scoring tail, which I read only to line ~1043 in vic and ~1900 in fed]

Size [I]: shares 88x10 doubles is under 10 KB. `fm` (flow matrix) and `fb` (candidate table for one election)
are the big ones, guess 0.1-1 MB. Fed `sw_draws` is 20,000 x ~10 x 8 B = about 1.6 MB per pair. Order of
20-60 MB for all 22 elections as `.rds`.

**Runtime avoided [I]:** the sim itself is cheap at the quick_arm default. From the 2026-10-07 profile in
CLAUDE.md (vic, 3 pairs: 500 sims 144 s, 2,000 sims 148 s, 20,000 sims 183 s) the simulator costs about
0.7 s per 1,000 sims per pair, so about 1% of a 1,000-sim run and about 20% of a 20,000-sim run. A replay pays
only R startup, package load, the snapshot read, the sim and the scoring tail: guess 5-10 s against 45-70 s,
so 80-90% avoided at 1,000 sims. At 20,000 sims the replay is the sim (13 s/pair) plus the same overhead,
which is still a 70-80% saving. The load-bearing unknown is the fixed overhead; item 1 of the plan measures it.

**Common random numbers:** hold. `simulate_seat_contests()` does `set.seed(seed)` itself (`R/seat_sim.R:458`) and
the harness passes `seed = SEED` (vic `:1028`), so same snapshot + same seed reproduces the baseline draws, and
an arm that changes only the sd scales the same standard-normal stream. [V for the seed handling; I that the
cpp core consumes the stream independently of the sd values, which `quick_arm.R`'s existing byte-identical
check on untouched pairs supports but does not prove for scaled sds]

## Arm type (b): a few primary-vote cells. YES, downstream of the xgb override, but a suffix, not just the sim.

Every cell-editing step after `xgb_primary_override()` is a function of the `shares` matrix plus disk state
(candidacies, seat-poll tables), with its own per-process memo. [V for `ind_person_apply`, `R/ind_person.R:154`;
`seat_poll_blend_apply` reads only `AUSPOL_SEAT_POLL_*` inside `R/seat_poll_blend.R` plus the shares, grep of
`Sys.getenv` there; I that it has no other hidden input]

### `AUSPOL_IND_PERSON` (shipped value `"final"`, `scripts/published_flags.R:686`)

- Mode read in `ind_person_mode()` (`R/ind_person.R:21`). `ind_person_apply()` is a no-op unless the mode equals
  `stage` (`:156`). Two sibling switches `_CARRY` (`:158`) and `_DIR` (`:171`) are read inside the same function.
- Call sites: base stage before the override (vic `:762`, fed `:1477`, nsw `:853`, qld `:818`, sa `:986`,
  wa `:599`); final stage after it (vic `:765`, fed `:1480`, nsw `:856`, qld `:821`, sa `:989`, wa `:602`). [V]
- **`final` path:** switch (`R/ind_person.R:21`) -> `ind_person_apply` (vic `:765`) -> `ind_mixture_apply` ->
  `zero_unnominated_at("early")` -> `seat_swing_port_apply` -> `seat_poll_blend_apply` -> optional edu/demo/
  leader/departed_fed -> `blend_salience_shares` -> `zero_unnominated_at("late")` -> `xgb_primary_sd_matrix` /
  flow overrides / `breakout_mix_args` (all read `shares`) -> `simulate_seat_contests` (vic `:1025`).
- **Save from the baseline:** the `shares` matrix at the point immediately BEFORE the `final` call (post-override),
  plus the sim context listed under (c) and the per-pair objects the tail reads (`fb`, `fm`, `truth`, `keep`,
  `REENTRY_CELLS` for fed and vic, `sw_draws` for fed). About 10 KB of shares per pair on top of the (c) list.
- **Pitfall [V]:** `ind_person_cells()` needs `output/candidacies.csv` and builds `.cs_prep` tables; these are
  memoised per process (`.cs_cached`), so a fresh replay process pays the corpus prep once. `.ip_cases()`
  builds ONE entry per election pair, for the carry fit (`R/ind_person.R:92-109`), which is the slow part of
  a cold call. Cache it keyed on the corpus fingerprint, as the house pattern does.
- **Runtime avoided [I]:** the suffix contains `surge_hazard_for()` (a ridge fit over earlier elections, vic
  `:878`, "computed fresh per pair"). It does not depend on shares (only the follow-up `blend_salience_shares`
  does), so it can be saved too. Without saving it, expect 50% avoided; with it, 70-85%.

### `AUSPOL_IND_PERSON=base`

Applied BEFORE `xgb_primary_override()` (vic `:762`), so it feeds the frozen-tree re-prediction
(`xgb_base_delta_apply`, `R/xgb_base_delta.R:142`). Still downstream-only: save the shares matrix at vic `:761`
(after `ind_typical_apply`), then re-run override and the same tail as above. The override costs a 3 MB fread of
`output/xgb-primary-v6-features.csv` and loading the saved `.ubj` model(s) from `output/xgb-primary-asat/`
(`.xgb_asat_repredict`, `R/xgb_base_delta.R:60-108`); small. [V for the code, I for the time]

### `AUSPOL_SEAT_POLL_*` (blend, decay, sources, ind-map, firm floor, prior...)

All read inside `R/seat_poll_blend.R` (lines 102, 111, 162-172, 224, 277-279, 403, 464-468, 557, 567, 725-790) and
`R/seat_poll_joint.R`. Applied at vic `:782`, fed `:1491` (preceded in fed by `state_poll_pool_apply`, `:1489`,
which is a separate switch). [V] Path: switch -> `seat_poll_blend_apply` -> the same tail -> sim.
Save: shares at the point before the call (post-override, post-port). `seat_poll_blend_apply` has a memo keyed
on target and seven of the switches (`R/seat_poll_blend.R:277-279`); that key does not include the others
(`_DECAY`, `_PRECISION_BLEND`, `_PRIOR`, `_PRIOR_SD`, `_MATCH`, `_W_*`, `_IND_WEIGHT`). I did not read what the
memo holds, so whether a replay in one process could return a stale entry for an arm that differs only in an
un-keyed switch is **unchecked**. A replay should run each arm in a fresh process, as `quick_arm.R` already does.

## Arm type (a): the statewide level. Downstream of `sb`, but the suffix is most of the projection block.

### `AUSPOL_LEVEL_RECENT` and `AUSPOL_LEVEL_RECENT_HALFLIFE`

- Mode read in `level_recent_mode()` (`R/level_recent.R:19`), half-life at `:90` and `:221`. The blend is
  applied LAST inside `forecast_statewide_or_oracle()` (`R/forecast_statewide.R:353`), so the unblended trend
  forecast (`fc$st_fc`, 20,000 draws, `:324-348`) is independent of the arm and can be saved. Fed builds its
  own `st_fc` and calls `level_recent_apply` at `backtest_candidate_fed.R:1340`. [V]
- The blended level becomes `sb` (vic `:412`; fed `st_fc`). `sb` is then read by:
  1. `reentry_apply_harness(mat, fa, fb, sb, ...)` (vic `:421`); [V]
  2. the per-party `dev_slope(x_p, sa, sb, slope)` (vic `:634-650`), which is `base_pred`, the dominant term;
  3. `seat_swing_spread(.., sb[ALP] - sa[ALP])` (vic `:836`), but the swing is subtracted as a constant so
     `sd_within` does not depend on it (stated for fed at `backtest_candidate_fed.R:1597-1600`; vic uses the
     same function; I did not read `seat_swing_spread` itself). [V comment, I for vic]
- **The statewide DRAWS do not change [V for fed]:** `simulate_seat_contests` subtracts `colMeans(statewide_draws)`
  (`R/seat_sim.R:997`, `:1243`), and `level_recent_apply` edits `st_fc` after the draws were made
  (fed `:1018-1019` vs `:1340`). So `sw_draws` can be reused unchanged.
- The statewide level reaches the xgb layer ONLY through `base_pred` in the harness: `xgb_primary_override`
  reads cached as-at predictions and, with `AUSPOL_XGB_BASE_DELTA=1`, re-predicts cells whose base moved by
  more than 0.05 using the frozen trees, replacing only `base_pred` (as base_margin AND feature) and taking
  every other feature, including `level_pred`, from `output/xgb-primary-v6-features.csv`
  (`R/xgb_base_delta.R:91-93`, `:136-148`). [V]

So (a) is downstream of `sb` but **the downstream part is the whole shares-building block**, not the
simulator. Path for vic: `AUSPOL_LEVEL_RECENT` (`R/level_recent.R:19`) -> `level_recent_apply`
(`R/forecast_statewide.R:353`) -> `sb` (vic `:412`) -> `reentry_apply_harness` (`:421`) -> `dev_slope` loop
(`:634-650`) -> post-swing/renorm/IND (`:654-711`) -> `new_ind_shrink_apply` (`:758`) -> override with delta
(`:763`) -> tail as in (b) -> `simulate_seat_contests` (`:1025`).

**What must be saved from the baseline:** (i) the PRE-blend statewide level per pair (`fc$st_fc`, a named vector
of about 10 numbers) and, for fed, `sw_draws`; (ii) everything the shares loop reads that is arm-independent:
`mat`, `sa`, `fa`, `fb`, `DEV_SLOPE`/`.vic_slope` results (or `.returns`, `.own_prev`, `.MP_SLOPE`, `.MAJDEP`,
`.MAJPRES`, `.fitsl`, `.defect`, `.minor_disc`, `.split`, `.permit`), `REENTRY_CELLS` inputs; (iii) the (b)
tail objects. Item (ii) is where this stops being a snapshot of data and becomes a refactor: those are closures
and many locals in a 400-line linear block. The practical route is to turn the block into one function
`project_shares(sb, ctx)` called by all six harnesses, which the plan's own "fix to one harness is a fix to
all of them" rule makes a six-harness change.

**Runtime avoided [I]:** the statewide trend forecast, flow-matrix build, candidacy loads and the target-excluded
fits (`fit_major_departed_slope`, `fit_defector_discount`, `fit_departed_origin_return`, `candidate_returns`,
`personal_prior_vote`) are skipped; the shares loop, re-entry, delta re-predict and tail are repeated.
Guess 40-65%, with a wide error bar until item 1 supplies stage timings.

**Harness-vs-live mismatch worth knowing (affects how to read ANY level arm in the harness) [V]:** the live
forecast passes the blended `state_mean` (`scripts/fit_seats_full.R:627-631`) into
`xgb_primary_predict_live`, where it becomes the xgb feature `level_pred` (`R/xgb_primary_override.R:271`). The
harness keeps `level_pred` frozen from the features file. So a level arm in a harness moves `base_pred` and
`base_margin` only; live moves both the base AND the level feature. This is not a delta-resim problem (the
snapshot route inherits the harness behaviour exactly), but a delta-resim of a level arm will reproduce the
harness number, not what ships. Whether the two differ in practice is **unmeasured**.

### `AUSPOL_LEVEL_MODE`: NO

It is read only by the model-fitting scripts (`scripts/fit_xgb_primary_v6.R:312`, `:685`), not by any harness
or `fit_seats_full.R` (grep over `R/` and `scripts/`; the registry says the same,
`scripts/build_model_registry.R:304-311`). It chooses what the xgb `level_pred` feature is TRAINED on
(`pred`, `now`, `none`), and the choice is baked into the as-at models and the cached predictions. Level feeds
`base_pred` AND the xgb features here, so a change is upstream of the trees: needs `fit_xgb_primary_asat.R`
(plus the v6 features file), the stage-1 to stage-6 rebuild, not a resimulation. Delta-resim cannot help.

## Why a naive "reuse the baseline run" is subtly wrong, and what already exists

- **The base_delta reference is stage 1, not the baseline run.** `xgb_base_delta_apply` compares this run's shares
  with `output/xgb-base-ref/<pair>.csv` (recorded at stage 1 with all post-xgb switches OFF,
  `R/xgb_primary_override.R:38-45`), not with the baseline run's shares. A snapshot of the baseline's shares is
  therefore NOT a stand-in for that file; the arm path must still pass through `xgb_base_delta_apply` against
  the same reference for any arm whose change is before the override (arm type a, IND_PERSON base). [V]
- **quick_arm already has the two ingredients in a coarser form:** per-election subprocess caching of whole
  runs with a code-hash key, and common random numbers by fixed seed (`scripts/quick_arm.R` header lines
  9-28, `:123`, `:214-228`). A snapshot would be a second cache level inside a run, keyed on the same inputs plus
  "which switches the saved prefix read". Because the prefix key must contain every switch the prefix reads, the
  safest key is the full set of `AUSPOL_*` variables minus a named allow-list of suffix-only switches.
  That allow-list is the dangerous part (see below).

## Recommendation

1. **Build (c) and the post-override part of (b) first.** They are downstream-only, need one snapshot point
   (just before the IND_PERSON final call, vic `:765`; fed's `out_all` is nearly the same point) and give the
   largest reliable saving for the least refactoring. Together they cover `SEAT_SD_MULT`, `IND_PERSON=final`,
   every `SEAT_POLL_*`, `NEW_IND_SHRINK`-style post-xgb tweaks, `STATE_POLL_POOL`, `REENTRY` post-xgb steps
   that are shares-only.
2. **Treat (a) as a separate, larger job.** It needs the projection block turned into a function in all six
   harnesses. Cheaper alternative for the screen the plan wants: the item-4 share-level screen, which already
   works from `output/level-recent.csv` and `output/published-predictions.csv`.
3. **Gate the allow-list with a proof, per harness.** For every switch declared "suffix-only", require two
   checks before trusting it, as CLAUDE.md demands of any check: (i) replay with NO switch changed is
   byte-identical to the original run's `sharedetail` and `allprobs`; (ii) replay of a deliberately chosen arm
   is byte-identical to a full from-scratch run of the same arm, on at least one pair per harness. A switch
   read anywhere in the prefix that was mislabelled suffix-only would otherwise produce an arm that
   "ran" but silently reused baseline numbers: the "experiment that never ran" failure.
4. **Do not add `AUSPOL_LEVEL_MODE` or any fit-time switch to the allow-list.** The registry
   (`docs/MODEL-REGISTRY.md`) lists switches read only by `fit_*` scripts as "absent"; a mechanical allow-list
   built from "not read by a harness" would wrongly include them.

## Unchecked (so nobody reasons from them as facts)

- Actual stage timings, including R startup and package load, and the cost of `surge_hazard_for` and
  `.ip_cases`. Item 1 of the plan owns this; all "runtime avoided" figures above depend on it.
- Whether the six harnesses are byte-for-byte equivalent in the pre-sim structure. I read vic and fed in detail
  and only grepped nsw, qld, sa and wa.
- What the `seat_poll_blend_apply` memo stores and whether its key covers every switch (see above).
- That cpp-engine RNG consumption is independent of the scaled sds (CRN under `SEAT_SD_MULT`).
- `seat_swing_spread` independence from the level in the vic harness (read only for fed).
- The scoring tail after the sim in every harness (read only the start of it).
