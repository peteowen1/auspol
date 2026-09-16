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

---

# RESULT, 2026-09-15: REFUSED

The criterion passed and the second refusal condition fired. The refusal
condition wins, as it is meant to.

## The criterion: pooled seat log loss over the AEF-7

Lower is better. `ran?` records whether the mechanism was applied at all.

| pair | seats | baseline | corrected | move | ran? |
|---|--:|--:|--:|--:|---|
| sa2026 | 47 | 0.3577 | 0.3464 | **-0.0113** | yes |
| vic2022 | 78 | 0.2494 | 0.2477 | -0.0017 | yes |
| qld2024 | 93 | 0.3106 | 0.3089 | -0.0017 | yes |
| nsw2023 | 88 | 0.2694 | 0.2694 | 0.0000 | no |
| wa2025 | 53 | 0.2027 | 0.2027 | 0.0000 | no |
| fed2022 | 151 | 0.2629 | 0.2629 | 0.0000 | no |
| fed2025 | 150 | 0.2600 | 0.2600 | 0.0000 | no |
| **pooled** | **660** | **0.2702** | **0.2689** | **-0.0012** | 3 of 7 |

**The pre-registered prediction was wrong in its specifics and right in its
size.** I wrote "improves slightly, 0.001-0.004" and the answer is 0.0012. I
also wrote "sa2026 worsens and the first refusal condition fires" -- sa2026
improved the most of the seven. Primary RMSE said sa2026 got 0.636 WORSE;
seat log loss says it got 0.0113 better. The two metrics disagree in sign on
the same arm, which is the clearest evidence yet for this repo's rule that
primary RMSE is secondary and seat log loss decides.

## Refusal condition 2 fired: the placebo matches

`born_aus_pct` substituted for `yr12_pct`, everything else identical.

| pair | seats | baseline | education | placebo | edu move | placebo move | placebo recovers |
|---|--:|--:|--:|--:|--:|--:|--:|
| sa2026 | 47 | 0.3577 | 0.3464 | 0.3485 | -0.0113 | -0.0092 | 81% |
| qld2024 | 93 | 0.3106 | 0.3089 | 0.3089 | -0.0017 | -0.0017 | **100%** |
| vic2022 | 78 | 0.2494 | 0.2477 | 0.2495 | -0.0017 | +0.0001 | -6% |
| **pooled** | **218** | **0.2989** | **0.2951** | **0.2962** | **-0.0038** | **-0.0027** | **71%** |

On qld2024 the placebo is identical to four decimals. On sa2026 -- the pair
this whole line of work was built for, One Nation in South Australia -- it
recovers 81%. **The two pairs with a real One Nation vote are exactly the two
where the placebo is indistinguishable from education.** Only Victoria, where
no right-minor party clears 6.5%, separates them, and there the education gain
is 0.0017 on 78 seats, which is noise.

## The placebo was mis-specified, and that is a fault in this plan

r(`yr12_pct`, `born_aus_pct`) = **-0.706** pooled over 1,989 seats
(-0.694 sa2026, -0.656 qld2024, -0.677 vic2022, -0.727 fed2022, -0.813
nsw2023). The fitted coefficients are mirror images: ONP `b=-0.63` on
education, `b=+0.44` on birthplace.

So the two variables are one latent class-and-urbanity axis measured from
opposite ends, and a check built on them **cannot distinguish "education
specifically" from "this demographic axis"** -- which is what it was written to
do. That correlation was computable from a file already on disk before this
plan was committed, and checking it would have shown the check was not ready.
Same fault as the C2 criterion recorded in `CLAUDE.md`: a measuring instrument
shipped without being dry-run.

**The verdict stands anyway, and deliberately.** The condition as written says
a matching placebo means refuse. Rewriting it now -- to "a placebo on a
different axis" -- would be choosing the rule after seeing the result, and
would convert a refusal into an adoption. That is the exact move
`CLAUDE.md` records going wrong twice in three experiments.

## Refusal condition 3: not separately measured, and why

"If the gain is only on `xgb_pred`." The evidence recorded BEFORE the run
already leans this way -- ONP -0.0914 on `xgb_pred` against -0.0055 on
`base_pred`, a factor of 17. It was not re-measured on seat log loss because
condition 2 had already fired, and a refusal condition that fires is
sufficient; further arms could only have confirmed the refusal, never lifted it.

## The finding that outlived the test: it cannot reach Victoria

Four of the seven AEF pairs never ran the mechanism, and the reason is the same
in all four. `build_census_features.R:201` joins census onto the cells in
`output/xgb-primary-v6-features.csv`, so **a seat created at a redistribution
has no prior-election row, therefore no feature row, therefore no census row**,
and `education_residual_apply()` skips the whole election rather than
part-applying it.

| pair | seats with no census row | what they are |
|---|---|---|
| nsw2023 | 5 of 93 | Badgerys Creek, Kellyville, Leppington, Wahroonga, Winston Hills -- all new in the 2021 NSW redistribution |
| wa2025 | 9 of 59 | WA redistributes hard; seat names do not survive between elections |
| fed2022 | 2 of 152 | includes Hawke, created 2021 |
| fed2025 | 3 of 152 | same cause |

> **CORRECTION added 2026-09-17. The table above is left unedited; read it
> with this.** Re-measured against `output/census-features.csv`, the two
> federal rows are wrong and the column is mislabelled.
>
> The counts are of rows flagged **non-exact** — a seat matched to an older
> boundary vintage — not of seats with *no* census row. Those are different
> things, and against the file on disk today no pair has a chamber seat
> missing a census row at all. Actual figures:
>
> | pair | non-exact | rows with a missing census value | this table said |
> |---|---|---|---|
> | nsw2023 | 5 | 0 | 5 — right |
> | wa2025 | 9 | 3 | 9 — right |
> | fed2022 | 1 | 0 | 2 — wrong |
> | fed2025 | 1 | 1 (**Bullwinkel**, created 2021) | 3 — wrong |
>
> The denominators are census-file row counts, not chamber sizes: fed2025's
> chamber is 150 and fed2022's is 151, neither is 152.
>
> This matters because `R/demographic_residual.R:136` cites the *other* plan's
> "fed2025 over ONE seat out of 152", and that one is correct — Bullwinkel is
> the single row. The sibling plan's "13 of 23 pairs" is also correct: 13
> pairs carry a row with a missing census value. Nothing downstream was
> computed from the wrong numbers; they sat in prose.

**And this blocks the live target twice over.** `output/census-features.csv`
carries `vic2014`, `vic2018` and `vic2022` and **no `vic2026` rows at all**; 10
of the 88 vic2026 seats (Ashwood, Berwick, Eureka, Glen Waverley, Greenvale,
Kalkallo, Laverton, Narracan, Pakenham, Point Cook) have no vic2022 row either.
Separately, `fit_seats_full.R` -- the published forecast -- **has no call site
for this function**; it reached the six backtest harnesses only. So a win here
would have bought nothing for 28 November 2026 without further work.

## What is actually established

- There is a real signal in the residual worth **0.0113 seat log loss on
  sa2026**, readable through at least two different census columns.
- It is a **class-and-urbanity** signal, not an education signal. Nothing here
  supports the narrower claim.
- It is concentrated where a right-minor party is large, and absent in Victoria
  at its current levels.
- The model does not use it, and the current census join cannot deliver it to
  any election with new seats -- including the one being forecast.

## What follows, in order

1. **Fix the census join** so it keys on the seat list the forecast simulates,
   not on the prior-election feature corpus. Without this nothing in this
   family can ever reach vic2026, whatever its merits.
2. Only then re-open the demographic axis, as a **model feature with a proper
   placebo on an unrelated column**, not as a post-hoc offset with a placebo
   correlated -0.71 with the thing it is testing.

`AUSPOL_EDU_RESID` stays at `0` in `scripts/published_flags.R`.
