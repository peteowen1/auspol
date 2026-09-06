# Salience regression REFUSED on fed2025. The attribution fix survives.

2026-08-26. Scores `docs/plans/prereg-nonmajor-vote-regression.md` against the
election it named as its test. **The proposed model fails criteria 1 and 2 and
the refusal clause fires. It does not ship.**

What does ship, separately, is the attribution fix — and it is not salience.

## The pre-registered result

Fitted on fed2022, applied to fed2025 (150 seats, 13 non-major winners).

| criterion | base `prev_party` | + salience | verdict |
|---|--:|--:|---|
| 1. all seats, RMSE | 5.45 | 5.48 | **FAIL** |
| 2. winners, RMSE | **2.99** | 8.55 | **FAIL** |
| 3. <5% band, ≤ +1.0 tolerance | 15.16 | 11.66 | pass |

Criterion 2 fails by 5.6 points on the rows the whole idea exists to fix.

## It is not the cross-election scale, though that is broken too

The obvious excuse is that `jump` is not on one scale between elections, and it
genuinely is not:

| | max | 90th pct | winners' mean | share > 5 |
|---|--:|--:|--:|--:|
| fed2022 | 57.64 | 3.88 | 17.53 | 7.9% |
| fed2025 | 17.85 | 1.76 | 4.50 | 4.0% |

Each election's chain is anchored on a **different first batch**, so a
coefficient of `+7.556` per log-unit in fed2022 units means nothing in fed2025
units. That is a real construction fault and it is recorded below.

**But it does not explain the failure.** Refitting the whole model *inside*
fed2025, leave-one-out, so scale cannot be the issue:

| | base | + salience |
|---|--:|--:|
| all 150 | 4.54 | 4.57 (+0.03) |
| 13 winners | 4.70 | 5.72 (**+1.03**) |

Salience adds nothing to fed2025 even on its own scale.

## Why: fed2025 contains no emergence to detect

Twelve of the thirteen non-major winners were **sitting members**. Their prior
vote already predicts them, which is why the base model reaches RMSE 2.99 on
winners — better than anything measured on fed2022. Wilkie 45.5 → 48.9, Haines
40.7 → 42.3, Katter 41.7 → 40.4, Scamps 38.1 → 38.0.

The only near-emergence is **Bradfield: Boele 20.9 → 27.0**, and salience does
call it (23.0 base → 26.3 with salience, actual 27.0). One case.

So salience is a detector for a thing that did not happen in 2025, and the model
as specified applies it to everyone unconditionally. On sitting members it is
pure added variance — Kooyong is the clearest case, where Ryan's `jump` of 17.2
pushed the prediction to 44.3 against an actual 33.9 that the base model had at
39.9. **Loud incumbents are loud because they are incumbents.**

## The instrument is fine. The model form is wrong.

Within fed2025 the ranking is as good as fed2022 and the rank correlation with
vote share is *better*:

| | AUC | Spearman(jump, pcv) |
|---|--:|--:|
| fed2022 | 0.971 | +0.229 |
| fed2025 | **0.969** | **+0.438** |

**AUC 0.969 is a genuine out-of-sample replication** — that number was produced
by a fetch of an election the method had never touched, with no fitting of any
kind. The signal is real and it transfers. What does not transfer is a linear
term in `jump` added to every candidate.

## What DOES ship: the attribution fix, tested on both elections

`prev_party` (this party's prior vote in this seat) instead of `prev_seat` (the
seat's best non-major, whoever they were). No salience involved.

| | fed2022 all | fed2022 winners | fed2025 all | fed2025 winners |
|---|--:|--:|--:|--:|
| `prev_seat` — ships today | 8.72 | 17.11 | 5.16 | 5.77 |
| `prev_party` | **6.44** | **16.06** | **4.54** | **4.70** |
| gain | −2.28 | −1.06 | −0.62 | −1.08 |

Better on all four cells. This is refusal clause 3 landing exactly as written:
*"if the published model adopts `prev_party` alone and salience then adds
nothing, salience is not the improvement."* It doesn't, and it isn't.

Concretely, this is the Melbourne bug: the current model put Adam Bandt's 23.7%
under a no-hope independent and predicted him at 34.2% on an actual 1.1%.

## Two construction faults this test exposed

1. **`jump` is not comparable across elections.** Each chain is anchored on its
   own first batch. Any use of salience spanning elections must standardise
   within election, and that is now a known requirement rather than a discovery
   to be made later.
2. **The fed2022 corpus is GRN and IND only** (78 / 73), so `is_ind = 1 −
   is_grn`, `is_grn` was rank-deficient and R **silently dropped it**. The
   pre-registration's "+ party class 4.71 → 4.02" was one estimable term, not
   two. fed2025's corpus is 106 GRN / 21 IND / 17 ONP / 5 OTH_RIGHT / 1 OTH —
   so the fit was applied to 23 rows of party classes it had never seen. The
   `predict.lm` rank-deficiency warning was the only surface signal.

## What was learned that a criterion could not see

The pre-registration's own "what the criterion cannot see" section named the
right worry — *"fed2022 is the teal wave, the most favourable election that
exists"* — and the refusal clause named the right mechanism in advance:
*"a signal that only says 'loud equals winner' will get declining incumbents
wrong."* Both were correct. **Bandt was predicted at 66.2% on an actual 39.5%.**

The hypothesis this suggests — gate salience on seats with little prior
non-major vote, where there is nothing to lean on — is **post-hoc and untested**.
fed2019 is the only remaining untouched federal election and it contains one
emergence (Steggall), which is close to no power. Saying so now, before fetching
it, so that a favourable fed2019 result cannot be read as more than it is.
