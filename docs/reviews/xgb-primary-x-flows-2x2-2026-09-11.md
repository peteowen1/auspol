# XGBoost primaries x XGBoost flows: the 2x2

**Date**: 2026-09-11
**Asked for**: Pete, overnight — "compare xgb primary table flows to xgb primary
xgb flows". Extended to the full 2x2 so the follow-on question (do the two
challengers add, overlap, or interfere?) can be answered from the same run.

**Status of the numbers below**: all four cells come from ONE code state, run
after three defects were found and fixed. The previously banked 0.3332 / 0.3283
flow-arm numbers are superseded and should not be quoted.

> ## ⚠️ EVERY ABSOLUTE NUMBER IN THIS FILE WAS MEASURED WITH A LEAK
>
> Later on 2026-09-11 the backtest was found to be feeding the xgb primary
> model `level_now` — the target election's **own actual statewide result**.
> Every pooled figure below (0.3332, 0.3069, 0.3001, and the AE Forecasts
> comparison) carries it.
>
> **The honest number is 0.3117** (22 pairs, 3 seeds, sd 0.0015). The leak was
> worth **+0.0116**, about 8x the seed noise, concentrated in sa2026 — the One
> Nation surge election, where `level_now` amounted to telling the model the
> answer.
>
> **What still stands**: every RELATIVE comparison in this file. Both sides of
> each arm carried the same leak, so the 2x2, the interaction, the per-pair
> deltas and the shipping decisions for the xgb primary and xgb flows are all
> unaffected.
>
> **What does not**: the absolute pooled figures, and the AEF gap — which is
> wider than reported here.
>
> Left unedited rather than restated, because the reasoning is what makes the
> relative conclusions readable. See `scripts/published_flags.R`'s
> `AUSPOL_LEVEL_MODE` entry for the current numbers.

---

## Three defects found before any number was quoted

### 1. The flow arm was leaked

`scripts/fit_xgb_flows_v1.R` runs `xgb.cv()` with folds grouped by election and
prints an honest leave-one-election-out RMSE. It then runs
`xgb.train(data = dtrain)` on **every** row and saves that as
`output/xgb-flows-v1-final.model`. `xgb_flow_conditional_override_for()` loaded
*that* model at inference — so every backtest arm ever run under
`AUSPOL_XGB_FLOWS` predicted an election with a model trained on that
election's own transfer results.

What made it read as safe: the function does hold the target election out of
its rate features (`hist <- TR[TR$election != target_election]`). Features held
out, weights not.

**Size of the leak, measured**: on nsw2023 the all-data model scores flow RMSE
**0.0765** on rows it trained on, against **0.0873** genuinely held out — 14%
optimism, invisible in every printed diagnostic.

**Fix**: `scripts/fit_xgb_flows_loo.R` trains and saves one model per held-out
election (25 of them). `xgb_flow_conditional_override_for()` and
`xgb_flow_conditional_for()` now prefer
`output/xgb-flows-v1-loo-<election>.model` and print a loud LEAKED warning if
they ever fall back to the all-data model.

This is the fourth leakage instance in this repo and the same shape as the
others: the diagnostic printed during fitting was clean, the artifact used at
inference was not.

### 2. The primary arm was measuring v1, not v6

`xgb_primary_override()` read `output/xgb-primary-oof-predictions.csv`, which
`scripts/fit_xgb_primary_cv.R` writes — that is **v1's** out-of-fold file. v6
is what `AUSPOL_XGB_PRIMARY_LIVE` ships. So the backtest arm and the live
forecast were never describing the same model.

**Fix**: the override now defaults to
`output/xgb-primary-v6-oof-predictions.csv`, with `AUSPOL_XGB_PRIMARY_OOF` to
name a different file. Both carry the same 22 pairs and 13,314 (seat, party)
rows; v6's is a column superset, so it is a drop-in.

The v6 out-of-fold predictions are genuinely leave-one-pair-out
(`folds = split(seq_len(nrow(X)), fold_id)`, fold = pair) — verified, not
assumed.

### 3. WA applied a different flow treatment from the other five harnesses

`backtest_candidate_wa.R` called the statewide `xgb_flow_conditional_for()` to
replace `fm$conditional` **and** the per-seat
`xgb_flow_conditional_override_for()`. The other five harnesses call only the
per-seat one. WA's log showed 6 statewide rebuilds plus 7 per-seat overrides;
fed/nsw/qld/sa/vic showed 0 statewide.

So the pooled flow arm was mixing two treatments, and WA — seven of the 22
pairs — was the one carrying the odd one.

**Fix**: WA's statewide call removed. The per-seat version supersedes it (it
feeds each seat's own primary shares rather than a statewide average).

This is CLAUDE.md's "a fix to one harness is a fix to ALL of them" read
backwards: an EXTRA parameter in one harness rather than a missing one, and it
produces numbers that look like findings just the same.

### Also fixed, not a defect in the comparison: two dead features

`xgb_flow_conditional_override_for()` hardcoded `dest_same = 0L` and
`dest_same_mp = 0L` for every inference row, while the model was **trained** on
real values for both. These are the personal-vote features the pre-registration
named as the reason Kiama should work, and they were dead at the only point
they mattered. They are now populated from
`candidate_returns(prev_election, target_election)` via a `match()` key lookup
(never `merge()`-then-positional-assign — `data.table::merge()` sorts by
default). Coverage is printed on every call: 22.8% of rows on nsw2023, 30.1% on
fed2007, in line with the training corpus's own 15-26%.

Not leakage: nominations close before polling day, so who is re-standing where
is knowable in advance, and the training script derives them the same way.

---

## Method

Four arms, all 22 canonical pairs (2,050 seat-elections), 3 seeds,
`AUSPOL_N_SIMS=5000`, compiled engine, everything else at published defaults:

| arm | primaries | flows |
|---|---|---|
| `p0f0` | shipped | table (`build_flow_matrix()`) |
| `p0f1` | shipped | xgb, leave-one-election-out |
| `p1f0` | xgb v6, leave-one-pair-out | table |
| `p1f1` | xgb v6, leave-one-pair-out | xgb, leave-one-election-out |

Run by `scripts/_run_pf_arm.sh`, pooled by `scripts/pool_pf_arms.R`. The pooler
reads each arm's own harness logs — which name the file each run wrote — rather
than globbing `output/`, because four arms of the same pair exist at once and a
glob would silently mix them. It asserts pair coverage per (arm, seed) and
refuses to compare arms that saw different pairs.

Metric order per CLAUDE.md: **pooled seat log loss** first (lower is better),
then Brier, then accuracy. Seeds are simulation noise and are averaged inside
each cell; **pairs** are the clustering unit for any standard error.

## Results

All 22 pairs, 2,050 seat-elections per seed, every cell complete.

**Pooled seat log loss, averaged over seeds. LOWER IS BETTER.** `delta` is
against `p0f0`, what currently ships; negative means better than shipped.

| arm | what it is | log loss | sd over seeds | delta | Brier | accuracy |
|---|---|---|---|---|---|---|
| `p0f0` | shipped primaries + table flows | 0.3332 | 0.0019 | — | 0.0951 | 0.8717 |
| `p0f1` | shipped primaries + xgb flows | 0.3294 | 0.0006 | −0.0037 | 0.0945 | 0.8715 |
| `p1f0` | **xgb primaries + table flows** | **0.3069** | 0.0010 | **−0.0263** | 0.0887 | 0.8816 |
| `p1f1` | **xgb primaries + xgb flows** | **0.3001** | 0.0015 | **−0.0331** | 0.0874 | 0.8857 |

Brier and accuracy move the same way as log loss on every arm, which is worth
noting because they usually do not — Brier caps the overconfident tail that log
loss punishes, so agreement here means the gain is broad rather than a handful
of floor seats.

### The comparison Pete asked for

**xgb primaries + xgb flows (0.3001) beats xgb primaries + table flows (0.3069)
by 0.0068 pooled.** Per pair the mean difference is −0.0096 over 22 pairs,
**t = −1.67, p = 0.111**, better in **12 of 22** pairs and worse in 10.

So: the flows help on top of the primaries, but the effect does **not** clear a
conventional bar once clustered on pairs, which is the right unit. It is a
real-looking but not-yet-established improvement.

Biggest winners: vic2014 −0.0679, wa2005 −0.0600, nsw2019 −0.0435,
vic2018 −0.0369, fed2013 −0.0355, sa2026 −0.0293.
Biggest losers: wa2001 +0.0483, fed2016 +0.0353, vic2022 +0.0091.

**Victoria, the live target, is split**: vic2014 and vic2018 are two of the six
best pairs, vic2022 is mildly worse. That is not a reason to ship or refuse on
its own, but it means Victoria does not settle the question either way.

### Do the two challengers add, overlap, or interfere?

| effect | on pooled log loss |
|---|---|
| xgb primary alone | −0.0263 |
| xgb flows alone | −0.0037 |
| sum if they were independent | −0.0300 |
| both together, measured | −0.0331 |
| **interaction** | **−0.0030** |

**They add, and very slightly help each other.** The interaction is negative
(better than additive) but is the same size as the flows-alone effect and
smaller than the seed-to-seed spread on some arms, so read it as "no
interference" rather than as synergy.

The honest summary is that **the primary challenger is carrying nearly all of
it**: −0.0263 of the −0.0331 total. Against the published baseline, both
challengers together give mean −0.0395 per pair, **t = −4.08, p = 0.001**,
better in **17 of 22** pairs — that one is solid.

### What this says about the flow model

The flow model is genuinely better at predicting flows: out-of-fold row-level
RMSE 0.0979 against the table's 0.1064, **8.0% better, and better in 22 of 25
elections**. The weak seat-log-loss result is therefore not a bad flow model —
it is that better preference flows translate weakly into better seat calls,
because most seats are not decided by the preference distribution.

## Recommendation — SUPERSEDED 2026-09-11 by the diagnosis below

Left unedited. The original recommendation was to hold the flows; after
diagnosing the two regressing pairs and refusing the bias correction on its own
dry run, the recommendation changed to ship. The revised version is at the end
of the diagnosis section.

**Keep `AUSPOL_XGB_FLOWS` off for now; the xgb primary stays shipped.** The
flows are worth 0.0068 on top, which is real money in this metric, but at
p = 0.111 and 12-of-22 pairs it has not earned a place in the published
forecast yet, and it costs roughly 3x the runtime per pair.

More seeds will NOT settle it: sd over seeds is 0.0006-0.0019 against an effect
of 0.0068, so seed noise is already an order of magnitude below the effect.
**Pair-to-pair variance is the binding constraint** — the per-pair differences
run from −0.068 (vic2014) to +0.048 (wa2001). Only more pairs, or a real
reduction in per-pair variance, moves p = 0.111. Spending compute on seeds 4-10
would be measuring the wrong thing.

Two candidates worth trying before revisiting the flag, in order:

1. **Find out why wa2001 and fed2016 get worse.** They are +0.048 and +0.035
   against a −0.0096 mean, so between them they account for most of the reason
   this misses significance. wa2001 has no transfers of its own (flows fall
   back to pooled), which makes it a plausible mechanism rather than noise.
2. **Re-measure both challengers with time-forward folds**, per the caveat
   below. That changes the absolute numbers for every arm here and could change
   the ranking.

---

# Diagnosis of the two regressing pairs (2026-09-11, Pete's follow-up)

They are **two different failures**, not one.

## wa2001: two seats, both independents

57 seats, 27 worse and 25 better — a coin flip — but **the worst 5 carry 86% of
the damage** and the top two are both independent winners:

| seat | winner | p(winner), table flows | p(winner), xgb flows | log-loss cost |
|---|---|---|---|---|
| Alfred Cove | IND | 0.1877 | 0.0373 | +1.62 |
| Pilbara | IND | 0.0169 | 0.0038 | +1.49 |

No seat crossed the log-loss floor in either arm, so this is not a floor
artifact. Accuracy 44/57 → 43/57.

The mechanism, from the key the simulator actually consults in Alfred Cove:

| key `ALP\|IND+LNP` | table | xgb |
|---|---|---|
| → IND | **90.8%** | **72.8%** |
| → LNP | 9.2% | 27.2% |

Janet Woollard won Alfred Cove on ALP preferences. Cutting that flow by 18
points is what removes her.

**wa2001 is structurally the worst possible case for this model**, for reasons
that predate the experiment and are already in CLAUDE.md:

- it has **no transfer file of its own**, so it is absent from the flow
  training corpus entirely — no leave-one-out model exists for it, and the
  all-data model has genuinely never seen it (that is not leakage, and the
  warning now says so rather than crying wolf);
- its table comes from **wa1996** — five years and a One Nation realignment
  earlier;
- the override supplies **118 keys for this seat where the table had 13**, so
  105 of them replace the shipped model's fallback rather than a measurement.

## fed2016: a broad drift, and a small ALP bias

The opposite shape. 83 seats worse, 58 better, and the worst 5 carry only 37% —
no single seat to blame. The losers are almost all **ALP-won marginals the
model already had below 0.20** (Herbert, Cowan, Paterson, Longman, Macarthur,
Macquarie, Braddon); the winners are the minor-party seats (Indi, Melbourne,
Kennedy, Mayo). Accuracy is unchanged at 129/147.

### Two hypotheses tested and killed

**"The table holds a local signal xgb washes out."** No. Scored against the
table the harness *actually* builds — `build_flow_matrix()` on the immediately
preceding election, not the pooled `base_pred` every previous comparison used —
**xgb beats the real table in 7 of 8 elections**, and on fed2016 by 19%
(RMSE 0.0848 vs 0.1049). fed2016 gets *more accurate flows* and *worse seat
calls*.

Worth recording separately: every earlier "xgb vs the table" number in this
repo was scored against `base_pred`, a pooled-over-all-elections lookup, which
is **not** what the simulator uses. `scripts/diag_flow_vs_real_table.R` is the
apples-to-apples version.

**"A better flow exposes a bad primary pot."** Also no, and this one was my
best guess. If the table's flow error had been compensating for primary error,
flow damage should track primary RMSE. It does not: **r = 0.129, p = 0.567**
over 22 pairs, and the median split runs the *wrong* way (worse primaries →
flows helped more, −0.0119 vs −0.0072).

### What does explain it

A per-destination bias. Pooled over all 25 elections, signed error
(prediction − truth) on ALP as a destination:

| | table | xgb |
|---|---|---|
| ALP bias | +0.0002 | **−0.0022** |
| ALP RMSE | 0.0874 | 0.0777 |

The xgb model is **more accurate but slightly less well-centred on ALP** — the
table was almost exactly unbiased there. Net two-party effect for fed2016:
the model shifts preferences **1.35 points away from ALP** relative to the
table. In an election decided by ALP marginals, a systematic 1.35-point shift
moves every one of them the same way — which is precisely the 83-seat drift.

That looked like a fixable defect, and I recommended fixing it before shipping.
**The dry run killed it.** See the next section — the conclusion below is
superseded and is left in place so the reasoning is visible.

### The bias correction, proposed and REFUSED before any simulation ran

Proposed: `bias(c, e) = mean(xgb_pred - y)` over out-of-fold rows with
destination class `c`, excluding election `e`; subtract, floor at zero,
renormalise per event. Leave-one-election-out twice over.

Dry-run first, per CLAUDE.md, because a seat-sim arm is 40 minutes and this is
seconds. Results (`scripts/diag_flow_bias_correction.R`):

- It does exactly what it says on its direct target: per-class pooled bias goes
  to ~0.000 for all seven classes, row RMSE 0.0979 → 0.0972.
- **And it makes the quantity that actually matters worse.** Net two-party bias
  shrank in only **4 of 25** elections; mean |bias| went **0.0275 → 0.0302**.
- **The named case got worse**: fed2016 −0.0195 → −0.0216.

**Why**: the global per-class bias is tiny (−0.0022 on ALP) while the
*per-election* net two-party bias is an order of magnitude larger, ±0.03 to
±0.07, and **swings in sign** — vic2014 −0.068, wa2025 +0.071. Correcting a
global mean cannot touch an election-specific swing, and subtracting a constant
from a quantity whose sign varies pushes half the cases further out.

**And the swing is not predictable, so no correction fitted on history can
remove it:**

- against the previous election in the same jurisdiction, **r = 0.282,
  p = 0.242** (n = 19 consecutive pairs);
- as a stable per-region offset, within-region sd **0.0315** against an overall
  sd of **0.0352** — almost no reduction.

So fed2016's regression is **variance, not a defect**. There is nothing to fix.

### Which also disposes of the reason not to ship

The concern that blocked shipping was that a systematic ALP shift would distort
the live Victorian forecast. It will not, and the flow model is **better**
centred than the thing it replaces:

| net two-party flow bias, mean \|bias\| over 25 elections | |
|---|---|
| pooled-lookup baseline | 0.0407 |
| **xgb flow model** | **0.0275** |

xgb is better centred in **16 of 25** elections. It reduces two-party flow bias
on average; fed2016 is one of the nine where it overshoots past zero.

## Sensitivity — reported because it changes the verdict

| pairs included | mean per-pair | t | p | better in |
|---|---|---|---|---|
| **all 22 (the headline)** | −0.0096 | −1.67 | **0.111** | 12/22 |
| excluding wa2001 | −0.0122 | −2.30 | **0.032** | 12/21 |
| excluding fed2016 | −0.0117 | −2.10 | 0.048 | 12/21 |
| excluding both | −0.0147 | −2.93 | 0.009 | 12/20 |

**wa2001 alone is what holds this below significance.** Excluding it takes
p from 0.111 to 0.032 and the pooled gain from −0.0068 to −0.0083.

**This is a sensitivity check, not the headline, and it must not become one.**
Dropping the pair that regressed is exactly the after-the-fact rationalisation
CLAUDE.md warns about, twice, with worked examples. The only thing that makes
it worth printing is that wa2001's special status was documented **before** this
experiment — it is excluded from the transfer corpus upstream, and CLAUDE.md
already carries "the wa2001 pair has no transfers of its own so its flows fall
back to pooled" as a standing caveat on how WA numbers read. The honest
statement is: **the headline is p = 0.111**, and there is a principled reason to
think one pair is unrepresentative.

## Where it got better, and where it got worse — the summary

- **Better**: minor-party and independent seats where the survivor set is
  large and the table has no measurement. vic2014 −0.0664, wa2005 −0.0595,
  nsw2019 −0.0435, vic2018 −0.0369, fed2013 −0.0355, sa2026 −0.0293.
- **Worse**: (a) an election with no flow data of its own at all (wa2001), and
  (b) two-party marginals in an election decided by them, via a ~1.35-point
  systematic shift away from ALP (fed2016).

Diagnostics: `scripts/diag_flow_regressions.R`, `diag_flow_one_seat.R`,
`diag_flow_by_evidence.R`, `diag_flow_vs_real_table.R`,
`diag_flow_gain_vs_primary.R`, `diag_flow_bias.R`,
`diag_flow_bias_correction.R`.

## REVISED recommendation

**Ship it.** Set `AUSPOL_XGB_FLOWS = "1"`.

What changed from the original "hold": the only concrete reason to hold was a
suspected systematic ALP bias that would reach the live Victorian forecast.
That is disproven — the flow model is *better* centred on two-party flow bias
than the mechanism it replaces (0.0275 vs 0.0407, better in 16 of 25), and the
residual swing is unpredictable, so no correction can remove it.

What remains is: a model that predicts flows better than the shipped table in
**7 of 8 elections**, worth **−0.0068** pooled seat log loss on top of the xgb
primary (0.3069 → 0.3001), better in 12 of 22 pairs, with two named
regressions — one an election with no flow data of its own, one variance.

That is exactly the situation Pete's standing rule covers: if the overall model
keeps getting better, one or two regressions are acceptable. The honest caveats
that go with shipping it:

- the headline is **p = 0.111**, not significant, and it should be described
  that way rather than as a proven gain;
- it costs ~3x runtime per pair;
- **wa2001 will regress, and that is expected, not a surprise to investigate
  later** — it has no transfer file of its own.

Not blockers, but queued: re-measure with time-forward folds (below), and
`AUSPOL_XGB_FLOWS` needs adding to `published_flags.R` at its shipped value in
the same commit that flips it.

## Caveat that applies to every number here

Both challengers are validated **leave-one-group-out, not leave-future-out**.
fed2007's prediction comes from a model trained on fed2025. That answers "how
well does this model generalise across elections", not "could we have made this
call in 2007". Both arms share the protocol, so the head-to-head is fair, but
the absolute gains against the shipped baseline are optimistic by an unmeasured
amount. Re-measuring both with time-forward folds is queued, not done.
