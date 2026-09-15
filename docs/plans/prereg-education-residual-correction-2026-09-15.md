# Pre-registration: education as a residual correction on the primary prediction

Written 2026-09-15. **I have already measured this on primary RMSE.** Every
number from that run is stated below before the criterion, so the criterion
cannot be chosen to fit it. The criterion is deliberately a metric I have NOT
measured.

## The mechanism

One coefficient, fitted out of fold on the residual:

```
residual = actual - prediction
fit   residual ~ b * z(yr12_pct)   on the OTHER pairs
apply prediction + b * z(yr12_pct) to the held-out pair
```

`z` is standardised WITHIN pair, because mean Year 12 completion drifts 51.4 to
60.8 across the corpus and a raw value would carry that drift between
elections -- the fault `reviews/xgb-primary-sd-and-census-2026-09-12.md`
identified when census was tried as a feature.

## What is already tested and is NOT this

- **Census as model features**: failed. sa2026 ONP RMSE 8.658 -> 9.544, and the
  ranking correlation collapsed +0.362 -> +0.057.
- **Education as a wholesale reallocator**: failed. Pooled RMSE roughly
  doubled, and a `born_aus_pct` placebo matched it
  (`prereg-class-concentration-v2-2026-09-15.md`).

This is neither. It leaves the existing prediction intact and adds a fitted
offset.

## WHAT I ALREADY KNOW, stated before the criterion

Per-seat primary RMSE, leave-one-pair-out, fixed coefficient:

| class | arm | cells | before | after | move | pairs better |
|---|---|---|---|---|---|---|
| ONP | xgb_pred | 1,006 | 3.1000 | 3.0086 | **-0.0914** | 8/10 |
| ONP | base_pred | 1,006 | 3.7216 | 3.7160 | -0.0055 | 7/10 |
| GRN | xgb_pred | 1,989 | 2.5101 | 2.4491 | -0.0610 | 16/23 |
| GRN | base_pred | 1,989 | 2.5082 | 2.4713 | -0.0369 | 15/23 |
| OTH_RIGHT | xgb_pred | 1,722 | 3.2732 | 3.2161 | -0.0571 | 8/16 |
| OTH_RIGHT | base_pred | 1,722 | 3.7305 | 3.7017 | -0.0289 | 7/16 |

All six improve. **And the two most important pairs get WORSE**: sa2026
+0.636 and qld2020 +0.203 on ONP -- the two elections where One Nation is
largest, and the two most relevant to Victoria. A level-scaled coefficient was
tried and made ONP on base_pred worse still (+0.0455).

It helps `xgb_pred` far more than `base_pred` (-0.091 against -0.006 for ONP),
which says base_pred has already absorbed most of this signal and the override
discards it.

## The criterion: seat log loss, which I have NOT measured

Primary RMSE is a secondary metric in this repo, and everything above is
primary RMSE. **The decision metric is pooled seat log loss across all 23
pairs**, run through the six harnesses, which has not been computed for this
mechanism.

**Adopt if pooled seat log loss improves.** Fixed coefficient, the form
measured above. No level interaction: I have seen two forms and picking a third
now would be choosing after the fact.

**Report and do not decide on:** per-seat primary RMSE (already known), Brier,
per-class and per-pair breakdowns.

## Refusal: what would make an apparent win unacceptable

- **If sa2026 or qld2020 seat log loss worsens.** Both already regress on
  primary RMSE. If that carries through, the mechanism fails on exactly the
  elections Victoria resembles, and a pooled win elsewhere does not redeem it.
  I expect this to fire.
- **Placebo: `born_aus_pct` in place of `yr12_pct`.** It matched education
  exactly in the reallocation test. If it matches again, this is "correct
  toward any correlated variable", not education.
- **If the gain is only on `xgb_pred`.** That would make it a patch on the
  override rather than a model improvement, and the cheaper honest answer is
  the one already recorded: the override discards signal base_pred already had.
- **If it needs any class dropped after the run.** The classes are ONP,
  OTH_RIGHT and GRN, named now. IND is excluded in advance: its education
  correlation is inconsistent in sign across elections (-0.357 to +0.240).

## What this cannot see

- Victoria. No Victorian pair has a right-minor party above 6.5%, so the
  coefficient reaching vic2026 is fitted entirely on elections unlike it --
  which is the same extrapolation that has defeated three mechanisms today.
- Whether education proxies income, industry or urbanity.
- Whether the correction is stable under a refit of the underlying model. It is
  fitted against predictions from one fitted model.

## Prediction, written before running

Pooled seat log loss improves slightly, 0.001-0.004, driven by GRN and
OTH_RIGHT where the corpus is large. **sa2026 worsens and the first refusal
condition fires**, making the honest answer NO despite a pooled gain. If that
happens the finding is not "education corrections work" but "education
corrections work where the party is small, and the large-party case needs an
interaction nobody has specified correctly yet".

---

## Amendment, 2026-09-15, before running: scored on the AEF-7, not all 23

Pete's call, for turnaround. The original clause above is left unedited.

**Does this favour the answer I want? No -- it makes the test harder.** The
AEF-7 are fed2022, fed2025, vic2022, nsw2023, qld2024, wa2025 and sa2026. The
pair I have written down as expected to fail, sa2026, is **1 of 7 here against
1 of 23** in the original, so it carries over three times the weight. qld2020,
the other regressing pair, drops out -- but sa2026 is the larger regression
(+0.636 against +0.203) and it stays.

**Interim results are a SMOKE TEST, not a stopping rule.** Each pair is checked
as it lands, to confirm the mechanism is wired and running, not to decide. All
seven run regardless of what the first ones show. Stopping when the numbers
look good is optional stopping and would invalidate the criterion more
thoroughly than any of the faults this plan was written to avoid.

The criterion is otherwise unchanged: pooled seat log loss, the four refusal
conditions, the classes named in advance.
