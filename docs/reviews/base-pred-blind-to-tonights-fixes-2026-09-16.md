# Both of tonight's fixes only reached the xgb layer; base_pred never moved

2026-09-16, very late, following Pete's Parramatta push-back ("well it clearly
didn't do its job as it predicted 48% when they got 35%"). Root-caused to a
real design gap that affects `seat_outperf` AND the minor-to-minor defector
discount identically, both shipped earlier tonight.

## The mechanism: base_pred assumes 100% premium carryover, unconditionally

`base_pred` (the pre-xgb baseline every harness produces) comes from
`dev_slope()` (`R/dev_slope.R`):

```r
dev_slope(x, level_prev, level_now, slope = 1)
  = level_now + slope * (x - level_prev)
```

`x` is the seat's own prior share for that party; `level_prev`/`level_now`
are that party's statewide average then and now. `slope` defaults to 1 --
the seat's deviation from the state average (its "premium," positive or
negative) carries forward UNCHANGED.

`screened_slopes()`/`conditional_slopes()` exist to make `slope` conditional
on whether the same candidate is returning -- but their `same`/`new` tables
(`R/dev_slope.R:207-210`) only cover `IND`, `OTH_RIGHT`, `GRN`, `ONP`.
**`ALP` and `LNP` are not in either table**, so `screened_slopes()` falls
straight through to `conditional_slopes()`'s `default = 1` for every major
seat in the corpus, regardless of whether the sitting member is retiring,
being challenged, or standing again. There is no same/new distinction for
majors at all, anywhere in the baseline.

## Verified against the real harness, not derived by hand

Instrumented `backtest_candidate_nsw.R` and ran it (published config) to
print the actual intermediate values for Parramatta nsw2023:

```
ALP: state_tgt=36.9653  state_prev=33.3080  seat's 2019 share=30.2413
     premium = 30.2413 - 33.3080 = -3.0667
     val = 36.9653 + 1.0*(-3.0667) = 33.8986  ->  renormalised to base_pred 35.66

LNP: state_tgt=35.3730  state_prev=41.5831  seat's 2019 share=54.0182 (Lee)
     premium = 54.0182 - 41.5831 = 12.4351
     val = 35.3730 + 1.0*(12.4351) = 47.8081  ->  renormalised to base_pred 50.29
```

Lee's entire +12.4 personal-vote premium goes into LNP's prediction
undiscounted, full stop, by design -- not a bug in the sense of a wrong
formula, but a formula that was only ever conditioned for minor parties.

## Why seat_outperf couldn't fix this: SHAP proof, not inference

`seat_outperf`'s own SHAP contribution on the LNP/Parramatta row: **+0.40**,
against `base_pred`'s **+22.2** (leave-one-pair-out model, the row's real
out-of-fold prediction, not a leaked full-data one). `is_incumbent_party_i`
contributes a further **+0.83 in the WRONG direction** -- it pushes LNP's
prediction UP, because the tree learned "being flagged incumbent correlates
with being a strong candidate" from the corpus in general, with no way to
know this specific incumbent is leaving.

`seat_outperf` was gated correctly (176 target rows, NA-filled per the
noise-floor finding), and the 349-case corpus sizing was real (r=0.176,
p=0.001). None of that is wrong. But it is a small xgb correction fighting
a baseline that injects the full, undiscounted premium first -- 0.4 points
of pull against a 12.4-point injection. The aggregate improvement measured
earlier tonight (targeted RMSE 9.2363 -> 8.8813) is real and was honestly
reported, but it was never going to look like "fixed" on an individual seat
this large, and calling it "did its job" overstated what a bolt-on
correction of this size could do.

## The minor-to-minor defector discount has the SAME gap, confirmed

`AUSPOL_MINOR_DEFECT` only wired `minor_discount` into
`fit_xgb_primary_v6.R`'s own call to `personal_prior_vote()` -- the one that
builds the xgb feature `own_prev_pcv`. Checked all six harnesses
(`backtest_candidate_{fed,nsw,qld,sa,vic,wa}.R`): **every one calls
`personal_prior_vote(..., major_discount = .defect)` and NONE pass
`minor_discount`.** So Stephen Andrew's full, undiscounted 31.66% ONP result
still flows straight into `base_pred` for OTH_RIGHT at Mirani via
`remove_transferred_votes()`/`.own_x()` -- the discount never touches the
number the simulator actually uses as its starting point.

## The general lesson (saved to memory, not just this doc)

**When building an xgb correction for a mechanism that's already
structurally present in the pre-xgb baseline, check whether the baseline
needs fixing directly, not just a bolt-on feature.** `base_pred` dominates
this ensemble's SHAP decomposition (+16 to +22 points typically, against
single-digit-or-smaller contributions from most engineered features) because
xgboost is *told* `base_pred` as a feature and mostly reproduces it. A
correction layered on top can nudge, not override, unless it's large enough
to cross a split boundary that changes the ensemble's whole shape for that
row -- which `seat_outperf`'s aggregate effect shows it occasionally does,
just not reliably per-seat.

## What needs fixing, in order of how contained the change is

1. **Wire `minor_discount` into all six harnesses' `personal_prior_vote()`
   calls**, mirroring exactly how `major_discount = .defect` already works
   (`fit_minor_defector_discount(TGT)` per-target, same as
   `fit_defector_discount(TGT)`). Small, safe, directly parallels working
   machinery. Not yet built.
2. **Fit same/new conditional slopes for ALP and LNP**, the same way
   `IND`/`OTH_RIGHT`/`GRN`/`ONP` already have them (`R/dev_slope.R:207-210`)
   -- measure retention for a returning major-party MP vs. a new major-party
   candidate, leave-one-out, sized on the whole corpus of major-party
   retirements, not just the 5 seats Pattern A was built from. This is the
   real fix for Parramatta's shape of miss; `seat_outperf` should likely be
   retired or demoted to a secondary correction once this exists, since it
   was always working around a gap in the baseline rather than closing it.
   Not yet sized, not yet built.

## Item 1 built and tested both ways -- MIXED, NOT SHIPPED

Wired `minor_discount` into all six harnesses' own `personal_prior_vote()`
calls (mirrors `major_discount`/`.defect` exactly). Ran the full non-circular
4-step procedure `pool_sharedetail.R` documents (all 21 pairs, explicit
`AUSPOL_XGB_PRIMARY=0`, `AUSPOL_N_SIMS=20000` -- `pred_share` is a
simulation mean, not deterministic; a `pool_sharedetail.R` guard correctly
refused a first attempt at lower sims), pooled, retrained v6 once.

**Mirani improved substantially**: `base_pred` for OTH_RIGHT dropped
33.24 -> 11.13 (the discount finally reaching the baseline), `xgb_pred`
34.37 -> 32.75 (error 6.51 -> 4.89 against actual 27.86). Pooled RMSE also
improved slightly (3.8178 -> 3.8091).

**But the full 28-row targeted aggregate got WORSE**: RMSE 8.8813 -> 11.4315,
mean abs error 7.251 -> 7.787 -- worse than the ALREADY-SHIPPED xgb-only
version, not just worse than doing nothing. Individual rows are genuinely
mixed (several much better, several much worse) -- feeding the discount into
`base_pred` doesn't just adjust the target row, it ripples through
`remove_transferred_votes()`'s class-level redistribution and affects OTHER
candidates in the same class at other seats, and that ripple cost more than
Mirani gained.

**Not shipped.** Reverted `output/xgb-primary-v6-oof-predictions.csv` to the
tested, shipped xgb-only state (confirmed reproducing 3.8178 exactly). Set
`AUSPOL_MINOR_DEFECT`'s default back to `"0"` in all six harnesses (opt-in
only) so a future clean-pool regeneration doesn't silently pick up the
untested combination. The wiring code stays -- tested, real, available for
whoever revisits this with a narrower application (e.g. gate the ripple to
only the target row's own class-and-seat cell, not the whole class
redistribution) -- but the current implementation is not an improvement over
xgb-only.

**This is exactly the result the new standing rule exists to produce.**
Testing base_pred alone would have shipped a worse aggregate on the strength
of one dramatically-better seat. Testing xgb alone (what happened earlier
tonight) shipped a real but narrow win. Testing both surfaced the actual
tradeoff and let the already-good xgb-only version stay shipped rather than
being replaced by something that looked more dramatic on the flagship case
and was worse everywhere else.

## Item 2: major same/new conditional slopes -- SIZED, BUILT, TESTED (base_pred layer) -- NOT SHIPPED

Sized `fit_major_conditional_slopes()` (`R/split_slope.R`, leave-target-out
`lm(yy ~ 0 + dev)`, same method as the existing minor-party fitter, mirrored
not duplicated) across the full corpus, stable over 4 different leave-out
targets: **ALP same≈0.92 new≈0.90-0.92** (barely differs -- ALP's brand vote
persists almost regardless of the candidate), **LNP same≈0.91-0.92
new≈0.826-0.831** (a real, consistent ~9% relative reduction). NAT never
appears as its own class in this corpus (folded into LNP), n=0, stays at the
unconditioned fallback of 1.0.

Wired into `backtest_candidate_nsw.R` behind `AUSPOL_MAJOR_SLOPES` (default
`"0"`, opt-in): after the existing `screened_slopes()`/`conditional_slopes()`
call, override `sl` for ALP/LNP using `.returns$same` (the same same/new
join `screened_slopes()` itself already uses, `match(seats, hit$seat)`) to
pick `.major_sl$same[[p]]` or `.major_sl$new[[p]]`. Contained: the existing
minor-party-tested `screened_slopes()`/`conditional_slopes()` functions are
untouched.

**Tested base_pred layer only** (`AUSPOL_XGB_PRIMARY=0`, so the xgb-override
that would otherwise paper over a `base_pred` change is off), NSW harness
only, `AUSPOL_N_SIMS=20000`:

Parramatta -- real, modest improvement, exactly as the sizing predicted:
LNP error 14.76 -> 13.51 (-1.25), ALP error 11.37 -> 10.31 (-1.06). Nowhere
near closing the ~13-point miss -- a nudge, not a fix, as flagged before
testing.

**Pooled ALP+LNP across NSW (176 seat-party rows) got marginally WORSE**:
MAE 4.6944 -> 4.7606 (+0.066), RMSE 6.2152 -> 6.2198 (+0.005, ~flat). Not a
clean win even on this one harness -- individual seats are genuinely mixed
(Newtown LNP 4.40 -> 0.37, Cabramatta LNP 14.66 -> 10.77 improve a lot;
Wallsend LNP 0.13 -> 3.42, Auburn LNP 7.35 -> 8.36, Albury LNP 4.18 -> 5.23
get worse), the same shape as the minor-defector base_pred experiment above.

**Not shipped.** `AUSPOL_MAJOR_SLOPES` stays default-off. Did not proceed to
porting the wiring into the other five harnesses or the full 21-pair
non-circular retrain (xgb layer test) -- NSW alone already failed the
do-no-harm bar the earlier minor-defector experiment used, and porting to
five more harnesses for an already-flat-to-negative single-harness result
isn't a good use of the remaining autonomous-session budget. The fitter and
wiring code stay (tested, real, available for whoever revisits this) but
this is explicitly an UNRESOLVED finding, not a shelved-because-it-worked
one: Parramatta's shape of miss (a major MP's undiscounted departure
premium) is still real and still unfixed. A next attempt should look at why
the pooled effect is mixed rather than uniformly positive -- possibly the
same "ripples through class redistribution" mechanism suspected for the
minor-defector case, since `dev_slope()` feeds `remove_transferred_votes()`
the same way.

## Item 3: found and fixed a real bug in `transfer` -- not the narrowing item 3 set out to do

Went looking for the "ripples through class redistribution" mechanism behind
item 1's minor-defector base_pred result, to try Pete's suggested narrower
fix (gate the discount to just the target row). Found something more
specific: `personal_prior_vote()`'s `transfer` column -- the amount
[remove_transferred_votes()] subtracts from the OLD class's seat base, so a
departed candidate's vote is not double-counted -- falls back to
`own_prev_pcv` at `R/candidate_returns.R:572` (before this fix), and
`minor_discount` is applied to `own_prev_pcv` *earlier* in the same
function, at line ~499. So a discounted candidate had LESS removed from
their old class's statewide baseline than they actually took with them --
inflating that class's average at every OTHER seat it contests, via
`dev_slope()`'s `level_prev` term. This is exactly the mechanism a "ripple
through class redistribution... affects OTHER candidates in the same class
at OTHER seats" finding predicts, and it is a genuine bug (an inconsistency
between how much left the old class and how much arrived in the new one),
independent of whether the discount itself should ship.

**Fixed**: `own_prev_pcv` is snapshotted to `.own_prev_pcv_full` before the
discount is applied, and `transfer`'s fallback now uses the undiscounted
snapshot -- the old class always loses the full vote it actually lost;
only the new class's row-level base is discounted. `minor_discount = NULL`
(current default, nothing ships this) is byte-identical, confirmed by the
existing `test-candidate_returns.R` suite passing unchanged (69 tests, no
new failures). Since `AUSPOL_MINOR_DEFECT` defaults to `"0"`, **this fix has
zero effect on the currently published model** -- it only matters to
whoever next tries the discount with `minor_discount` set.

**Re-tested Mirani with the fix, base_pred layer only** (QLD harness,
`AUSPOL_XGB_PRIMARY=0`, `n=20000`) -- and found something that changes the
picture for anyone revisiting this: the fixed-transfer discount is *closer*
to the buggy version's error than to a fix. Actual Mirani OTH_RIGHT 27.86.
No discount at all: base_pred 33.24 (error 5.38). Buggy-transfer discount
(documented above): base_pred 11.13 (error 16.73). Fixed-transfer discount:
base_pred 14.22 (error 13.64) -- better than the bug, still nearly 3x
*worse* than doing nothing at this layer. **Discounting Mirani specifically
pushes base_pred further from actual than leaving it undiscounted does.**
The corpus-wide 49% geometric retention is real (`docs/reviews/minor-to-
minor-defector-2026-09-16.md`), but Mirani itself may just be a
higher-than-typical-retention case -- exactly the shrinkage argument in
`CLAUDE.md` ("Fit constants with SHRINKAGE"): a corpus average correctly
sized does not mean every individual cell sits near it.

So the honest state to hand off: item 1's mixed pooled result (Mirani gain,
aggregate loss) may not have been *purely* the class-redistribution ripple
this fix targets -- part of it could be that discounting Mirani was already
the wrong call for that specific seat, discount-leakage bug or not. Did NOT
re-run the full non-circular 21-pair retrain to re-check the pooled
aggregate with the leak fixed (`AUSPOL_MINOR_DEFECT=1` still opt-in only,
default off) -- that retrain, plus checking whether Mirani individually
needs a milder discount than the corpus rate, is the real next step here,
not attempted tonight given the time already spent on items 1 and 2.

## Standing rule from this session (Pete, 2026-09-16): test both layers, always

**Whenever a fix is proposed for something in this model, test it edited into
`base_pred` (the pre-xgb swing/baseline layer) AND as an xgb feature, not
just one.** Tonight built two real, well-sized, correctly-measured xgb
features (`seat_outperf`, the minor-defector discount) and neither one
touched `base_pred` at all -- both looked like real, positive, shippable
fixes by every test run against them, and both left the actual published
number for their flagship case (Parramatta, Mirani) still catastrophically
wrong, because `base_pred` dominates the ensemble and nothing corrected it.
A pooled RMSE improvement or a placebo-controlled positive delta is not
evidence the FIX REACHES THE NUMBER PETE IS LOOKING AT -- checking the
specific seat's actual predicted value against actual, end to end, is.
Added to `CLAUDE.md` as a standing instruction, not just recorded here.
