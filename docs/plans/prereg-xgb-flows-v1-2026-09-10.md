# Pre-registration: xgb flows v1

Built same session as `docs/plans/xgb-flows-variable-inventory-2026-09-10.md`
(read that first — the design, the three worked examples, and the rationale
for the row shape below all live there).

## What's being tested

Replace `build_flow_matrix()`'s empirical lookup (conditional/pooled rate +
fixed 15% uniform smoothing) with an xgboost model, one row per
(excluded party, destination party, survivor-set), predicting that
destination's share of the excluded pot. Renormalised across the row's own
survivor set at inference, mirroring `fit_xgb_primary_final.R`'s shape.

## Primary metric and criterion

Pooled seat log loss across whatever backtest pairs the model can train and
score on (report exact coverage — some jurisdictions, notably South
Australia, have thin or zero native flow history; this is a known,
pre-existing gap, not a v1 defect).

**Adopt only if xgb flows beats the CURRENT shipped flow mechanism
(conditional/pooled + fixed 15% smoothing) on pooled seat log loss, measured
through the real seat simulator** — not a standalone RMSE-on-flow-shares
proxy, which cannot see how an error interacts with the primary-vote draw.

## Refusal conditions, named in advance

1. Pooled seat log loss worse than shipped → refused, same standard as the
   flow-cell-shrinkage experiment this session already ran through.
2. A regression concentrated in one or two jurisdictions that swamps a real
   gain elsewhere (same shape as the earlier shrinkage refusal: federal/WA
   dominated the pooled aggregate) → named explicitly, not averaged away.
3. If the model's predictions for **Ballarat's cell** (`GRN|ALP+LNP`,
   672 historical events, current lookup already nails it at 21.3/78.7 vs
   actual 21.4/78.6) move materially away from the already-correct answer —
   this is the dry-run check per CLAUDE.md's "test your criterion on a case
   whose answer you already know" rule. A model that breaks Ballarat to fix
   Kiama is not an improvement, it's a trade.

## Dry-run cases (checked before trusting any pooled number)

- **Ballarat, fed2007** — well-measured, ordinary. Model should barely move
  from the existing lookup's answer.
- **Kiama, nsw2023** — Gareth Ward's personal-vote effect (68.1% IND vs
  31.9% ALP on LNP's exclusion). Current lookup has no way to see this;
  model has `same_mp`/personal-vote features and should move toward the
  real answer, though a single case is not proof of a general fix.
- **MacKillop, sa2026** — flows barely matter here (ONP wins on first-
  preference lead despite losing the final exclusion pot 1454 to LNP's
  3776). A flows model correctly getting this cell "wrong" relative to the
  final seat outcome is not evidence against it — the primary model already
  carries the real signal here.

## Scope, v1

Given the size of the full feature set in the variable inventory and the
time available this session, v1 intentionally includes a SUBSET, chosen for
highest expected value: excluded/destination party class, survivor-set
composition, survivors' own current primary shares, the historical
conditional/pooled rate AND its event count `n` as features (not just a
fallback), `same_mp`/`same` (identity/personal-vote signal for the excluded
party specifically, since that's what Kiama needs), and region dummies.
Explicitly deferred to v2: salience/emergence features (jump/governed/
surge_h), demographics, `to_n` multiplicity (inconsistently available
across jurisdictions — see variable inventory). Named here so a v2 attempt
starts from what's known missing, not from scratch.
