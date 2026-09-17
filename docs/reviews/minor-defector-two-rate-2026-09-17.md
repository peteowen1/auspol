# minor_discount split into sitting-member / non-sitting rates, 2026-09-17

## What prompted this

Checking the refreshed AEF-7 Seat Ledger, Murray/Orange/Barwon (nsw2023,
all won by independents) sat at the top of the worst-primary-miss list.
Traced to source: all three are the SAME sitting members as the prior
election, just relabelled -- `party_raw` confirms they formally quit
"Shooters, Fishers and Farmers Party (NSW) Incorporated" and recontested
as "Independent" (matching the real 2021 NSW SFF split: Donato/Orange,
Dalton/Murray, Butler/Barwon). All three grew their vote (108-136%
retention), consistent with a popular incumbent continuing under a new
label, not a real defection collapse.

`personal_prior_vote()`'s identity match already found their real prior
vote correctly (`own_prev_pcv` = 49.1/38.8/33.0 before any discount).
`candidate_returns()` already flagged `same=TRUE, same_mp=TRUE`. The
inputs were right. The problem was `minor_discount`: one pooled rate
applied to every minor-to-minor identity switch, sitting member or not.

## The evidence

Every minor-to-minor identity switch in the 23-pair corpus (`prior_pcv >=
10`, `prior_party != party`, both non-major):

| | n | median retention |
|---|---|---|
| was the sitting member at the switch | 5 | **1.08** |
| was not sitting | 13 | **0.28** |

The 5 sitting cases: Barwon (1.36), Murray (1.30), Orange (1.08), Mirani/
Stephen Andrew ONP->KAP (0.79), Kennedy (0.63). A 4x gap between the two
groups -- the same shape `major_discount` (sitting, ~0.28-0.29) vs
`loser_discount` (non-sitting, ~0.142) already exists to handle for
major-party defectors. The minor-to-minor mechanism just never got the
same split when it shipped 2026-09-16.

## The fix

`fit_minor_defector_discount()` now returns `discount_mp` (sitting-member
median) and `discount_loser` (non-sitting median) alongside the existing
pooled `discount`. `personal_prior_vote()` gains `minor_discount_loser`:
when given alongside `minor_discount`, a confirmed sitting-member
switcher gets `minor_discount`, a confirmed non-sitting switcher gets
`minor_discount_loser`, and unknown sitting-status (no `elected` column
in that corpus vintage) falls back to `minor_discount` -- "unknown" is
never read as "definitely not the sitting member".

Wired into all 8 call sites: the six backtest harnesses' base_pred
blocks, `fit_xgb_primary_v6.R` (the xgb-feature layer), and
`fit_seats_full.R` (the live published forecast -- not hypothetical,
vic2026's candidate list already has minor-to-minor switch cases served
by this mechanism).

## Verification

- 7 new regression tests: sitting-member gets the higher rate,
  non-sitting gets the lower rate, unknown status falls back correctly,
  single-rate mode is unchanged when `minor_discount_loser` is omitted,
  and `fit_minor_defector_discount()` itself correctly splits a synthetic
  corpus into `discount_mp`/`discount_loser`. All pass; 917 passed / 0
  failed on the full suite (`check_like_ci.R --tests-only`).
- Direct trace against the real nsw2023 leave-target-out fit
  (`discount_mp = 0.7094` on n=2 out-of-sample sitting cases, excluding
  Murray/Orange/Barwon themselves -- correctly not circular):
  `own_prev_pcv` for Orange/Murray/Barwon moves from ~14-18 (old single
  pooled rate, 0.294) to 34.9/27.5/23.4. Still short of their real
  retention (49.1/38.8/33.0) since `dev_slope()` applies its own
  returning-candidate slope on top of `own_prev_pcv`, but a large,
  correctly-directed improvement -- roughly halving the miss rather than
  fixing it outright.
- Pooled do-no-harm: xgb_v6 leave-one-pair-out primary RMSE across all 23
  pairs, 13,739 rows, unaffected within noise (3.7921 before -> 3.7931
  after, via a controlled `git stash`/rerun comparison). Expected --
  this fix touches 18 of 13,739 rows corpus-wide.
- **n=2 leave-target-out for nsw2023's own sitting-member rate is thin.**
  The pooled 5-case sitting-member rate (1.08) is itself already a small
  sample; excluding the target election's own 3 cases (leave-target-out,
  correct practice) leaves only Mirani and Kennedy to estimate nsw2023's
  rate from, giving 0.7094 -- lower than the full-pool 1.08, still far
  above the single old pooled rate (0.294). No formal shrinkage was
  applied between this and the non-sitting rate; per the identical
  precedent for `major_discount`/`loser_discount` (also not separable by
  a significance test at p=0.408, but published as two raw rates anyway
  because an outcome check showed pooling was worse), this uses the two
  raw group rates directly rather than a blended one. Revisit if a future
  target's own leave-out sitting-member sample is even thinner than n=2.

## Separately investigated, not fixed: {IND,minor} -> MAJOR

Pete's original design question also asked about a candidate moving from
IND/minor TO a major party. Checked the mechanism: `personal_prior_vote()`
explicitly zeroes `own_prev_pcv` for major-party rows (by design, so a
minor-to-major switcher can't inherit the wrong class's history --
`de660f5`, today's earlier fix), and `conditional_slopes()`'s `same`/`new`/
`same_mp` tables only have entries for IND/OTH_RIGHT/GRN/ONP, never ALP/
LNP/NAT -- a major-party row always gets `default = 1` (uniform swing)
regardless of the candidate's real history.

This gap is real in the code but checked for real-world evidence before
proposing a fix: the entire 23-pair corpus has exactly ONE identity match
in this direction (fed2019 Wright, ONP -> LNP, non-sitting, ratio 0.11 --
a retention this low for a genuine same-person switch would be unusual,
and more likely reflects two different people sharing a match_key than a
real defection). vic2026's current candidate list has zero such cases.
Not fixed, because there is no usable evidence to fit a rate from --
recorded here rather than silently dropped, per this repo's own rule that
"a request leaves the register when it ships, or when told plainly it is
not happening and why."

## Update, 2026-09-18: `AUSPOL_MINOR_DEFECT_BASE_PRED` retested and shipped, revised

The fix above (`0a834e0`) only reached `AUSPOL_MINOR_DEFECT`'s xgb
FEATURE. It does not touch `base_pred` -- that requires the separate
`AUSPOL_MINOR_DEFECT_BASE_PRED` flag, off by default because the OLD
single-rate version of this discount was refused there on 2026-09-16
(helped Mirani, made a targeted RMSE aggregate worse, 8.8813 -> 11.4315).
Pete asked to retest it now that the discount has a two-rate split.

**First retest (fitted sitting-member rate) showed 0.000000 delta on
Murray/Orange/Barwon** despite the discount being correctly computed and
logged. Root cause: the published default `AUSPOL_XGB_PRIMARY=1` runs an
XGB override AFTER `dev_slope()` that replaces `shares` entirely, so any
base_pred-flag test under default settings measures nothing -- the fix
was firing correctly, just being overwritten downstream before the number
ever reaches `pooled-sharedetail.csv`. Retesting with `AUSPOL_XGB_PRIMARY=0`
(this repo's own established method for isolating base_pred, per the
2026-09-16 "4-step non-circular retrain" note) confirmed the wiring works.

**But the fitted sitting-member rate made things worse, not better.**
Orange moved from an undiscounted 52.44 (already close to actual 53.08) to
a discounted 44.96 -- away from truth. The leave-target-out fit for
nsw2023 draws on only 2 other sitting cases (Mirani 0.79, Kennedy 0.63),
underestimating what Murray/Orange/Barwon (108-136% retention) needed.

**Revised: a confirmed sitting-member switcher now gets NO discount at
all**, not a fitted rate. Leave-one-out cross-validated against all 5
sitting-member corpus cases (Barwon 1.36, Murray 1.30, Orange 1.08, Mirani
0.79, Kennedy 0.63): predicting flat 1.0 gives HALF the squared error
(0.405) of predicting each case from the other four's median (0.782) --
n=5 is too thin to fit a rate below 1 usefully, and the median/mean (1.08
/ 1.03) both sit almost exactly on "keep it all" anyway. The 13-case
non-sitting rate (median 0.276) is unaffected -- well-powered, no such
problem. `personal_prior_vote()`'s `minor_discount` parameter now means
"the rate for a switcher whose sitting status is unknown" when
`minor_discount_loser` is also given, not "the sitting-member rate" --
updated in its own roxygen doc, all 8 call sites, and the regression
tests.

**Shipped**: `AUSPOL_MINOR_DEFECT_BASE_PRED = "1"` added to
`published_flags.R`. Measured across the 14 pairs with a real
minor-to-minor case (nsw2023, qld2024, fed2013/2016/2019/2022/2025,
wa2001/2005/2008/2013/2017/2021/2025), `AUSPOL_XGB_PRIMARY=0` both sides:
pooled RMSE 4.0554 -> 4.0568 (n=8,910, +0.0014, negligible -- a much
better do-no-harm result than the original refusal's real cost).
Murray/Orange/Barwon move from their old ~14-18 base_pred to
52.44/39.78/37.25 (actual 53.08/53.31/45.83) -- large, correctly directed,
still short of full retention because `dev_slope()` applies its own
returning-candidate slope on top.

**Honest trade-off, not hidden**: Mirani and Kennedy (the other 2 of 5
sitting cases, both of whom actually lost vote after switching) also
revert to no discount, undoing 2026-09-16's Mirani-specific improvement --
back to over-predicting Mirani at 33.24 against actual 27.86. Accepted
because the aggregate evidence (half the cross-validated error) favours
one rule applied uniformly over a rate fitted well enough for 3 of 5 cases
and badly for the other 2, with no way to tell in advance which a new
target's own case will be.
