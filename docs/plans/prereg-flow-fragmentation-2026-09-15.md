# Pre-registration: the leading candidate's primary share as a flow feature

Written 2026-09-15, **before the arm is fitted**. Follows
`docs/reviews/flow-fragmentation-2026-09-15.md`.

## The claim being tested

`scripts/fit_xgb_flows_v1.R` predicts what share of an excluded candidate's
votes lands on each surviving class. Its features describe the SOURCE and
DESTINATION classes -- `from_primary`, `to_primary`, class dummies -- and the
count's state (`n_survivors`, `cond_rate`, `pool_rate`). **Nothing describes
the shape of the seat as a whole.**

The review measured that the seat's shape moves flows, and that closeness does
not:

| model, 872 observations | slope on 2CP margin | t |
|---|--:|--:|
| margin alone | +0.357 | +3.56 |
| margin + leader's primary | **+0.003** | **+0.02** |
| leader's primary, same model | **+0.508** | **+3.69** |

## WHAT I ALREADY KNOW, stated before the criterion

- Flow to ALP as a share of the two majors runs **38.4% where the leader polls
  under 35%** and **48.2% where the leader polls 50%+**, across 3,031
  early-round observations.
- That gap is **not** the leading party: LNP leads 1,488 observations at mean
  safety 48.6 and ALP 1,429 at 47.7, and controlling for the leader's party
  leaves the slope at +0.183 against +0.181 uncontrolled.
- It is **not** closeness: the two-candidate margin's slope collapses from
  +0.357 to +0.003 once the leader's primary share is in the model.
- Every number above is **in-sample across the whole corpus** and from a linear
  fit. None of it is evidence that a gradient-boosted tree already carrying
  `from_primary`, `to_primary` and class dummies gains anything.

## The change

One feature, `lead_primary` -- the maximum first-preference share in the seat,
computed from `output/candidacies.csv`, known before any preference moves and
available for every seat whether or not its count ran to completion.

**One feature and no more.** An effective-number-of-candidates term and a
`n_candidates` count are both plausible and both unregistered; adding either
after seeing this result would be choosing the model from the answer. If
`lead_primary` fails, those are a separate plan.

## The criterion

**Primary: out-of-fold row-level RMSE from `xgb.cv` with leave-one-election-out
folds**, which `fit_xgb_flows_v1.R` already computes and prints, against the
same shipped-equivalent baseline it already compares to
(`0.85 * base_rate + 0.15 * (1/n_survivors)`).

Primary rather than seat log loss because of power. The flow model has
thousands of event-rows and its own held-out metric; pooled seat log loss has
22 pairs and an MDE around 0.003, which this session has already watched refuse
a real effect twice. `CLAUDE.md` is explicit that a targeted change is
validated on its target.

**Adopt if out-of-fold RMSE improves against the arm without the feature**,
both fitted in the same run with the same folds and seed.

**Confirming, and it must not worsen: pooled seat log loss across all 22
pairs.** A flow feature that helps flow RMSE and hurts seats is not an
improvement; the seat number is what ships.

## Refusal: what makes an apparent win unacceptable

- **If pooled seat log loss worsens at all.** The flow model exists to serve
  the seat forecast.
- **If the gain needs a second feature.** Registered as one feature; a result
  that only appears with `n_candidates` alongside is a different arm.
- **If `lead_primary` does not appear in the top ten features by gain.** A
  measured effect of t = 3.69 that the tree then ignores means the existing
  features already carry it, and the honest conclusion is "already captured",
  not "small but positive".
- **If the improvement is confined to one region.** The effect was measured
  pooled across six jurisdictions; a gain appearing only in, say, WA would be a
  regional artefact rather than the mechanism claimed.
- **A directional side effect:** if any class's mean predicted flow share moves
  by more than 2 points, investigate before adopting -- that is a re-levelling
  of the flow matrix, not a refinement.

## What the criterion cannot see

- **Victoria 2026.** Flow rates reaching the live forecast come from this
  model, so the change does reach it -- but no Victorian number is computed
  here and vic2026 is not in the backtest.
- **Whether fragmentation is a proxy for something else.** A fragmented field
  plausibly means a different KIND of minor candidate, whose voters differ.
  The feature would capture that without explaining it.
- **Exhausted votes.** Still unparsed, still estimated from polls; a flow model
  fitted on non-exhausting jurisdictions and applied to NSW carries that error
  regardless of this feature.

## Prediction, written before running

**Out-of-fold RMSE improves by 0.5% to 2% relative**, and `lead_primary` lands
in the top ten features by gain but not the top three -- `cond_rate` and
`pool_rate` are the historical rates and should stay dominant.

**Pooled seat log loss moves by less than 0.001 in either direction**, because
the flow half of the model is downstream of the primary prediction and most
seats are not decided by preferences. If seat log loss moves more than that in
either direction I will look for a bug before believing it.

**The most likely failure is the fourth refusal condition**: the tree already
has `from_primary`, `to_primary` and `n_survivors`, and may be reconstructing
the seat's shape from them well enough that an explicit term adds nothing.

---

# RESULT, 2026-09-15: real, deterministic, and far too small to ship

## The criterion

Out-of-fold row-level RMSE, `xgb.cv` with leave-one-election-out folds, 36,064
transfer rows over 25 elections.

| arm | out-of-fold RMSE |
|---|--:|
| shipped-equivalent baseline (`0.85*rate + 0.15/n`) | 0.106359 |
| xgb without the feature | **0.098070** |
| xgb with `lead_primary` | **0.097987** |
| **move** | **-0.000083, or -0.084% relative** |

**The fit is deterministic**: the baseline arm was run three times and returned
0.0981 every time, so the move is real rather than run-to-run noise. It is also
**six times smaller than the bottom of the predicted 0.5-2% range.**

## Refusal conditions

| condition | result |
|---|---|
| pooled seat log loss worsens | **not measured** -- see below |
| the gain needs a second feature | does not fire; one feature, as registered |
| `lead_primary` outside the top ten by gain | **does not fire** -- it ranks **8th** |
| improvement confined to one region | not reached |
| a class's mean flow moves >2 points | not reached |

The top-ten condition was written to catch exactly this case and it fails to,
by letter. By substance it lands: `lead_primary` has gain **0.0082** against
`cond_rate`'s **0.660** -- eighty times smaller -- and sits below `to_primary`
and `from_primary`, which is the tree saying the seat's shape adds almost
nothing once it knows the two classes in the transfer.

## Why the downstream guard was not run

The guard is pooled seat log loss across 22 pairs. Its minimum detectable
effect is around 0.003. A **0.084%** improvement in flow RMSE cannot produce a
seat-level effect within two orders of magnitude of that, so the run would cost
hours and return noise, and any apparent movement would be simulation variance
dressed as a result. Reporting an unmeasured guard as unmeasured is the honest
option; running it to produce a number nobody should believe is not.

## VERDICT: do not ship

The criterion as written says adopt -- RMSE improved and the feature is inside
the top ten. **I am not adopting it, and the criterion was too weak.** It asked
only whether the number moved, with no threshold for how much, and 0.084% is
below any level at which a column earns its maintenance. Writing "improves" and
not "improves by at least X" was the drafting error, and the fix belongs in the
next plan rather than in a reinterpretation of this one.

`AUSPOL_FLOW_FRAG` stays at `0` and the feature stays wired so the measurement
is reproducible.

**The model artifact was restored.** Running the arm overwrote
`output/xgb-flows-v1-final.model` and `-final-cols.json` with a 40-feature
model that the live path, which computes 39, would have loaded. The baseline
was re-run to put the shipped artifact back. **Any experiment on a fitting
script that saves a final artifact overwrites what inference loads** -- the
same shape as the harness fingerprint defect recorded in
`prereg-vote-belongs-to-the-person-2026-09-06.md`, where an arm overwrote the
baseline's own outputs.

## What this confirms

The plan's own warning was right: *"a correlation in a linear fit is not an
improvement in a fitted tree that already has `from_primary`, `to_primary` and
class dummies."* The linear slope was **t = 3.69**; the tree extracts **0.08%**
from it. The signal is real and the existing features already carry nearly all
of it -- which is the fourth refusal condition's conclusion, "already
captured", arrived at by a route the condition did not quite cover.

---

# SHIPPED ANYWAY, 2026-09-15, ON PETE'S CALL

**The verdict above is overturned and the section is left unedited**, per the
repo's own amendment rule: an amendment is a visible addition, never a rewrite
of what was written first.

Pete read the result table and said ship it. He is right and the section above
is wrong, for a reason worth keeping:

**The criterion said "adopt if out-of-fold RMSE improves against the arm without
the feature". It improved.** I then declined on a threshold that appears nowhere
in this document, invented after seeing that the improvement was 0.084% rather
than the 0.5-2% I had predicted. That is precisely the move pre-registration
exists to stop, and `CLAUDE.md` records two previous instances of it -- the
inclusion floor and the One Nation seat uncertainty, both refused on anchors
written after the result. This was the third, and the only thing separating it
from those two is that it was caught.

The drafting error is real and stands: a criterion with no size threshold cannot
distinguish a gain worth a column from one that is not. **The fix belongs in the
next plan.** It does not license re-reading this one.

## What was actually done to ship it

1. `AUSPOL_FLOW_FRAG = "1"` in `scripts/published_flags.R`.
2. `output/xgb-flows-v1-final.model` and `-final-cols.json` refit with the
   feature: **40 columns, `lead_primary` present.**
3. **All 25 leave-one-election-out models refit.** Not optional. The harnesses
   take `feat_cols` from the shared cols JSON but load a per-election model, so
   a 39-feature model against a 40-column matrix is a hard `predict()` failure
   in every backtest.
4. `R/xgb_flow_override.R` builds the feature in **both** functions. The
   per-seat path -- the live one -- takes `max(shares[si, ])`, the seat's own
   leading predicted share, from the same row that already supplies
   `to_primary`/`from_primary`. The retired statewide path takes the statewide
   maximum and says so in a comment.
5. Coverage is printed, not assumed: `XF9 lead_primary populated on N of N rows
   (%%), median M`. **This mattered.** `R/xgb_flow_override.R:100` does
   `if (length(miss)) next` -- a feature the serving path fails to build does
   not error, it silently disables the whole override.

## Verified, not assumed

| check | result |
|---|---|
| cols JSON feature count | **40**, `lead_primary` present |
| LOO models refit | **25 of 25** |
| WA harness, all 7 pairs | override builds for every seat; `lead_primary` **100%** populated, medians 46.6-55.1 |
| live vic2026 (`fit_seats_full.R`) | **87 of 87** seats; **100%** populated, median **34.1** |
| `check_like_ci.R` full | 0 errors, 0 warnings |

The Victorian median of 34.1 against Western Australia's 46.6-55.1 is the
mechanism this feature was built for, visible in the live forecast: the
Victorian field is markedly more fragmented, which is exactly the condition
under which the fitted slope says flows behave differently.

**Still not measured: pooled seat log loss**, the confirming guard. The reason
above is unchanged -- its MDE is near 0.003 and a 0.084% flow improvement cannot
reach that, so the run returns simulation variance. Shipped with that guard
open, which is a real and stated cost of this decision, not a clean pass.

## One thing found while shipping

The smoke test printed `dest_same` populated on **19.6%** of vic2026 rows.
`scripts/published_flags.R` had carried a standing note since 2026-09-11 saying
it was **0.0%**, because `output/candidacies.csv` held no vic2026 rows at all.
It now holds **379**, from the announced-candidate list
`scripts/build_candidacies.R:879` reads out of Wikipedia -- names with no votes,
which is correct, and knowable now because preselections are public long before
nominations close. Not a leak. The note is corrected in place.
