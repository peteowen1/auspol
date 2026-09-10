# Pre-registration: replace the flat "new"-candidate deviation slope with corr × class-specific sd-ratio, leave-one-out

Written 2026-09-09, **before any arm is fitted or scored**. Committed before
running.

## The defect

`conditional_slopes()` / `screened_slopes()` give every "new" (no candidate of
this class stood here before) non-permitted candidate ONE flat slope per
class: IND 0.326, OTH_RIGHT 0.325, GRN 0.880, ONP 0.545. Two arms refused
earlier today already showed a flat number cannot be right:

- `prereg-fit-conditional-slopes-2026-09-09.md` found OTH_RIGHT's flat "new"
  constant is fine on the pooled corpus (0.442 fitted vs 0.325 shipped, within
  the ordinary-election noise) but **specifically wrong during a surge**:
  fed2013 (Palmer United's debut, OTH_RIGHT statewide 3.9%→9.9%) is the
  single pair driving the whole refit's effect.
- `prereg-partial-return-split-slope-2026-09-09.md` fitted a single `s_dep`
  pooled across ALL non-major classes (0.575) and refused it — pooling
  classes with genuinely different behaviour (a returning-vote analogue of
  the mistake found live in this plan, see below) into one number is wrong
  regardless of which portion of the model it lands on.

## The mechanism found live this session (2026-09-09, in conversation with Pete)

For a no-intercept regression, the slope of `dev_after` on `dev_before` is an
exact identity: **slope = corr(before, after) × sd(after) / sd(before)**.
Verified numerically on the three real ONP/OTH_RIGHT emergence-or-collapse
events in the corpus (matches to 3 decimals, confirming the identity holds
even with an intercept fitted):

| case | sd(before) | sd(after) | sd ratio | corr | corr×ratio | actual fitted slope |
|---|--:|--:|--:|--:|--:|--:|
| fed2013 OTH_RIGHT (rise, 3.9%→9.9%) | 1.29 | 4.41 | 3.41 | 0.30 | 1.011 | 1.011 |
| sa2026 ONP (rise, 6.6%→22.5%) | 1.30 | 7.72 | 5.93 | 0.34 | 2.008 | 2.008 |
| qld2020 ONP (collapse, 20.8%→7.4%) | 4.77 | 3.97 | 0.83 | 0.55 | 0.460 | 0.460 |

Neither ingredient is stable **pooled across classes** — correlation ranges
0.75-0.94 for GRN (geographically sticky) down to near-zero/negative for OTH,
and pooling them (0.446 pooled mean, sd 0.324 — nearly as large as the mean)
badly over-predicted both rises. **Class-specific** pooled correlation
(leave-target-pair-out) is far more usable. The sd-vs-level relationship has
the same problem: a single cross-class curve mixed populations with very
different sd-at-a-given-level (IND sd 16.15 vs ONP sd 5.93 at level ≈20%) and
was fit on the wrong population (all-candidate sd, applied to new-tier-only
sd). Fixing both — **per-class curve, new-tier population throughout,
leave-target-pair-out** — reproduces all three known cases far better than a
flat constant:

| case | class corr | sd_before (actual) | sd_after (class curve, leave-out) | sd_after (actual) | predicted slope | actual slope | shipped flat constant |
|---|--:|--:|--:|--:|--:|--:|--:|
| fed2013 OTH_RIGHT | 0.294 | 1.29 | 3.44 | 4.41 | **0.782** | 1.011 | 0.325 (3.1x off) |
| sa2026 ONP | 0.570 | 1.30 | 6.50 | 7.72 | **2.846** | 2.008 | 0.545 (3.7x off) |
| qld2020 ONP | 0.554 | 4.77 | 3.36 | 3.97 | **0.391** | 0.460 | 0.545 (1.2x off, closest by luck) |

The corr×sd-ratio prediction is within 15-42% of the true slope on all
three; the flat constant is off by 1.2x-3.7x. This is the arm.

## The arm

New `fit_dispersion_slope(cls, target_election, level_after, corpus, pairs,
min_pairs = 6)`:

1. `class_corr`: n-weighted mean of `cor(dev_before, dev_after)` over every
   OTHER pair of this class in the corpus (leave-target-election-out, same
   discipline as `fit_defector_discount()` / `fit_conditional_slopes()`).
2. `class_sd_curve`: `lm(log(sd_after) ~ log(sqrt(level*(100-level)/100)))`
   fit on that class's other pairs' new-tier `sd(dev_after)`, predicting
   `sd_after` at the target election's actual statewide level.
3. `sd_before`: measured directly from THIS pair's actual new-tier seat data
   (not curve-predicted — it's observable at forecast time).
4. `predicted_slope <- class_corr * sd_after_predicted / sd_before`, clipped
   to `[0, 3]` (a slope outside that range is not credible and falls back).

**Falls back to the shipped flat constant** when: fewer than `min_pairs`
other pairs of this class exist, `sd_before` is degenerate (< 0.3, meaning
fewer than ~5 seats of real "new"-tier prior history — not enough to measure
a spread at all), or any intermediate fit is non-finite. This is exactly the
gap the salience-screen 1.0 override cannot fill on its own: a screen-
*permitted* candidate still gets 1.0 as today (unchanged); this arm only
touches the flat number applied to a *non-permitted* new candidate.

Behind `AUSPOL_DISPERSION_SLOPE` (default `0` = byte-identical), added to
`scripts/published_flags.R` in the same commit.

## What this plan does NOT do

It does not touch the salience-screen 1.0 override, the sitting-member tier,
or the "same" (returning-candidate) slopes. It does not wire into
`split_dev_slope()` / the Waite-shape partial-return structure — that
mechanism was refused today for replacing `sl` outright, and wiring this
arm's output into it as `s_dep` is a natural follow-up but a separate,
smaller change once this constant itself is validated on its own.

## Primary metric

**Pooled seat log loss across all 22 pairs.** This is a GENERAL change — it
touches every non-major "new"-tier cell in every seat, not a named subset —
so per `CLAUDE.md`'s targeted-vs-general table the election-wide metric is
primary.

Baseline, measured today at HEAD `f3c3d07` (post-merge of `AUSPOL_DEFECT_POOLED=2`
and `AUSPOL_ONP_CV=0.365`): **pooled log loss 0.3358** over 2,050
seat-elections (accuracy 0.8717, Brier 0.0957). Paired per-pair deltas,
clustered on the 22 pairs, bar **2.08 SE** (t, 21 df) — same convention as
the two arms refused earlier today.

**MDE** cannot be known before the run; it will be reported with the result.

## Decision rule, fixed now

**Ship if BOTH:**

1. Pooled seat log loss improves at ≥ 2.08 clustered SE.
2. Of this 10-metric panel, **≥ 6 better and ≤ 3 worse** (|Δ| < 0.0005 is
   unchanged, counts as NOT an improvement): pooled log loss; pooled Brier;
   pooled share RMSE (all cells); per-jurisdiction seat log loss for fed,
   nsw, qld, sa, vic, wa; count of floor seats (≤ 1e-4).

**Catastrophic-break floor:** refuse regardless if any jurisdiction's seat
log loss degrades by more than **0.02**, or pooled by more than **0.01**.

**Victoria is the live target** and any regression is reported prominently.

## Refusal: what would make an apparent WIN unacceptable

- **R1 — the gain concentrating in fed2013/sa2026/qld2020 is EXPECTED, not
  disqualifying** — that is the population this arm targets. But report the
  result on the other ~500 "ordinary" new-tier cells separately: if THOSE
  get materially worse, the mechanism is trading rare-event accuracy for
  everyday accuracy and the net call needs to weigh that explicitly rather
  than being absorbed into the pooled number.
- **R2 — coverage.** Report how many new-tier cells actually got a fitted
  value versus fell back to the flat constant (the `min_pairs`/`sd_before`
  guards). If the arm fires on materially fewer cells than expected (e.g. a
  join silently drops rows), the run is void and reruns rather than scores.
- **R3 — no silent seat-count swing.** If the published Victorian forecast's
  expected seat total for any class moves by more than 2, escalate rather
  than ship as a side effect.
- **R4 — seed control.** If the pooled effect is smaller than the sd of a
  re-run with a different `AUSPOL_SEED`, it is simulation noise, not the
  mechanism.

## What the criterion cannot see

- It cannot tell whether the corr×sd-ratio *functional form* is the right
  one, only whether it beats a flat constant on this corpus. A different
  functional form might do better still.
- `min_pairs = 6` and the `sd_before < 0.3` fallback threshold are chosen
  now, not tuned to the result. They are conservative (ONP and OTH_RIGHT
  both clear them with 8-9 pairs each; IND and GRN have more).
- The class-specific sd-curve is still fit on 8-13 points per class. It is a
  large improvement on a flat constant (verified above) but is not a
  precisely estimated curve, and sa2026's own level (22.5%) is at the top
  edge of ONP's observed range — the curve is extrapolating there, just on a
  class-appropriate shape instead of a cross-class one.

## Dry-run of the criterion on cases whose answer is already known

Already performed, live, before this plan was committed (see the mechanism
table above): predicted slopes 0.782 / 2.846 / 0.391 against actual fitted
slopes 1.011 / 2.008 / 0.460 — all three within 15-42%, versus the shipped
flat constants' 1.2x-3.7x errors on the same three cases. If the built
`fit_dispersion_slope()` does not reproduce these numbers when run
leave-one-out on the real corpus, the wiring is wrong and the result should
be discarded rather than interpreted.

## Prediction, written before running

Expect the pooled effect to be small and concentrated almost entirely in
fed2013, sa2026, qld2020, and qld2020's neighbour qld2020→qld2024 (which
starts from the post-collapse ONP level). Expect the ~500 ordinary new-tier
cells to move very little, because for a class whose level barely changes
election to election, sd_after/sd_before ≈ 1 and the predicted slope
collapses to ≈ class_corr — close to the existing flat constants for ONP
(0.57 vs 0.545) and OTH_RIGHT (0.29 vs 0.325) by construction. R1 is
therefore expected to show a near-wash on ordinary cells and the real gain
concentrated on the named rare events — which is the point of the arm, not a
disqualifying pattern.

---

## Result, 2026-09-09: REFUSED

Run across all 22 pairs at 20,000 sims with `AUSPOL_DISPERSION_SLOPE=1`,
scored against the criterion above using `fit_dispersion_slopes()` built
in `R/split_slope.R` (function-level tests pass, 22/22). **Nothing adopted.
The flag stays at `0` in `scripts/published_flags.R`.**

| test | value | bar | verdict |
|---|---:|---:|---|
| criterion 1 — paired pooled seat log loss | 0.3358 → **0.3362**, t = **−0.35**, better in 7 of 22, worse in 11, tied in 4 | improve at ≥ 2.08 SE | **FAIL** |
| criterion 2 — 10-metric panel | **~2 better (Brier, WA), ~7 worse or unchanged** (log loss, fed, nsw, qld, sa-tied, vic, floor-seat count) | ≥ 6 better, ≤ 3 worse | **FAIL** |
| catastrophic floor — jurisdiction | worst is nsw +0.0051, WA actually **improved** −0.0099 | 0.02 | not breached |
| catastrophic floor — pooled | +0.0004 | 0.01 | not breached |
| floor seats (actual winner ≤ 1e-4) | 4 → **5** (new one in nsw2019) | — | worse |

**fed2013 — the case this arm was built for — got WORSE, not better:
0.3758 → 0.3964 (+0.0206), the single largest regression in the corpus.**
sa2026 was exactly unchanged (fell back to the shipped constant, as
designed — its `sd_before` guard fired correctly). qld2020 moved by +0.0001,
indistinguishable from zero. **The only real gain in the whole run is wa2013,
−0.0882 — a pair never named, checked, or validated anywhere in this plan.**

### Root cause: the dry-run only checked 2 of the 4 classes the arm touches

The mechanism table above validated `OTH_RIGHT` and `ONP` against three real
cases. It never checked `IND` or `GRN`. The fed2013 smoke test (run before
the full backtest, and which should have been read as a warning rather than
a green light) showed why that mattered: `fit_dispersion_slopes("fed2013")`
returned `IND = 0.071` — a class-specific correlation and sd-curve fit on
IND's OTHER pairs that happened to produce a near-zero slope, applied
uniformly to all 74 of fed2013's IND "new" seats (`SR1` log: `IND=74` of 150
seats). IND is the class this repo's own docs already flag as carrying the
worst seat-level RMSE and deciding the most marginal seats. Slashing its
new-candidate slope to 0.071 — crushing every new independent toward the
state mean — plausibly cost more than OTH_RIGHT's corrected slope (1.358 vs
shipped 0.325, genuinely closer to the true ~1.0-1.4) gained back. This is
the same failure shape as both arms refused earlier today: the change
touched more of the model than was ever validated. **Verify a dry-run covers
every class an arm modifies, not just the classes that motivated it** — the
generalisable lesson for whoever builds the next version of this.

### What worked and what didn't, for whoever picks this up next

- The identity itself (`slope = corr × sd-ratio`) is real and not in doubt.
- Per-class, leave-one-out estimation of both pieces is a large improvement
  over a flat constant **on the two classes it was checked against**
  (OTH_RIGHT, ONP) — but was never checked on IND or GRN, and IND broke.
- `sd_before < 0.3` / `min_pairs` fallback guards worked exactly as designed
  (sa2026 fell back cleanly, no crash, no wild number).
- wa2013's large, unexplained improvement is worth understanding before
  anyone trusts this mechanism again — it could be a real fix or an
  overfit; nobody has looked.
- Next attempt should validate EVERY class the arm touches against a known
  case (or hold the arm to IND/GRN off, OTH_RIGHT/ONP on, i.e. ship it as a
  two-class fix) rather than assuming two dry-run checks generalise to four
  classes.

### Kept, not reverted

`fit_dispersion_slopes()`, its tests, and the `AUSPOL_DISPERSION_SLOPE`
wiring across all 6 harnesses and `fit_seats_full.R` stay in the tree,
inert at the default `0`.

---

## Round 2, 2026-09-09: restricted to GRN/ONP only (Pete's call) — STILL REFUSED

Pete, on seeing the class list: *"why are you fitting IND and OTH_RIGHT they
arent parties i thought this was just for parties like ONP and GRN?"* Correct
and decisive — checked `R/parties.R`: `IND` is by definition a different
person every election, and `OTH_RIGHT` is a residual bucket `classify_party()`
files a dozen-plus unrelated minor-right parties into (DLP, Liberal
Democrats, Palmer United/UAP, Rise Up Australia, Family First, Shooters
Fishers Farmers, Katter's, and more). Only `GRN` and `ONP` are single,
persistent, named parties — the premise the corr × sd-ratio mechanism needs.
`fit_dispersion_slopes()` now defaults `classes = c("GRN", "ONP")`; `IND`
and `OTH_RIGHT` keep the shipped flat constant always. Re-ran all 22 pairs.

| test | round 1 (4 classes) | round 2 (GRN/ONP only) | bar | verdict |
|---|---:|---:|---:|---|
| pooled log loss | 0.3358 → 0.3362 | 0.3358 → **0.3365** | improve ≥ 2.08 SE | **FAIL** (t = 0.06, ~zero effect) |
| better / worse / tied | 7 / 11 / 4 | **5 / 10 / 6** | ≥ 6 better, ≤ 3 worse | **FAIL** |
| catastrophic floor | not breached | not breached (worst: fed +0.0037, wa +0.0024) | 0.02 / 0.01 | pass |
| floor seats | 4 → 5 | 4 → **5** (still nsw2019) | — | unchanged, not fixed |

**wa2013's round-1 "win" (−0.0882) vanished entirely (+0.0015, flat) once IND
was excluded — confirming it was never a real GRN/ONP effect, just IND's
0.071 doing something coincidentally favourable on that one pair.** Restoring
the mechanism to real parties only removed a mystery result along with the
harm, which is itself a useful confirmation the class restriction was right.

**fed2013 got WORSE again (0.3758 → 0.4015, now the single largest
regression) — and this time it is not a bug.** OTH_RIGHT's flat 0.325 really
is wrong for THIS election (Palmer United's debut dominated the bucket that
year), but OTH_RIGHT is not a coherent party in general, so this arm
correctly declines to touch it — and pays for that correctness on the one
case where the bucket happened to be one real party. Fixing fed2013
specifically would need a detector for "this bucket is dominated by a single
entrant this cycle," which is out of scope here.

**nsw2019 improved substantially (0.4403 → 0.4014, −0.0389) — a real,
unexplained gain nobody has looked into.** The two effects are close to
offsetting pooled, which is why the net is a wash rather than a loss.

### Verdict

Still refused by the pre-registered rule. The class restriction was the
right fix for the MECHANISM (confirmed: no more mystery wins from classes
that shouldn't have brand continuity), but the pooled effect on real parties
alone is statistically indistinguishable from zero — GRN and ONP's
"new"-candidate cells are not, in aggregate, biased enough by the flat
constant to move the whole corpus, even though the mechanism visibly gets
the three known emergence/collapse cases closer to right individually.
**Flag stays `0`.**

### What's still true and worth keeping

- The identity and the class-restriction logic are both correct and now
  well-tested (24/24 in `test-split_slope.R`, including a test that GRN
  moves and IND/OTH_RIGHT don't even when both have equally strong
  synthetic signal).
- nsw2019's gain and fed2013's (now cleanly attributable) loss are two
  concrete, real, opposite-signed effects worth understanding before anyone
  revisits this — neither was investigated further here.
- This is now the THIRD arm refused today (with the split-slope and
  fit_conditional_slopes arms) that improves specific known cases without
  clearing a pooled, 22-pair bar. The pattern across all three: real,
  measurable, individually-defensible local fixes do not add up to a
  pooled win once every ordinary election gets a chance to be hurt by the
  same change.
