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

Both are scoped, not started. Item 1 is safe to build immediately (small,
mirrors existing code exactly). Item 2 needs its own sizing pass first --
same discipline as everything else measured tonight.

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
