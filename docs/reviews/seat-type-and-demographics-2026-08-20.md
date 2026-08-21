# Seat type predicts swing, and adds nothing once the federal swing is in — which undercuts the demographics plan

Run 2026-08-20. No model change. This is a negative result that redirects the
next piece of work, including one I had recommended.

## What was tested

The anchor ships `Data/seat-types.csv` — **857 seats across federal, NSW,
Victoria, Queensland, WA and SA**, classified into inner-metro, outer-metro,
provincial and rural. It is a **consistent cross-jurisdiction** taxonomy, unlike
the per-state `seat_region` labels (12 in NSW, 14 in Victoria) that were
rejected as untransferable during the independent-emergence work.

It is their classification. It is used here as **input data**, like the margins
and `fed_swing` already taken from their seat files, with any coefficient fitted
on our own data — not as a fitted parameter.

## Seat type is a real predictor on its own

629 seats across five elections, predicting each seat's deviation from its own
election's statewide swing:

| type | seats | mean deviation | sd |
|---|---:|---:|---:|
| **inner-metro** | 181 | **+1.68** | 3.74 |
| outer-metro | 196 | −0.12 | 4.31 |
| provincial | 113 | −1.17 | 3.98 |
| rural | 139 | −1.07 | 4.52 |

**F = 16.07, p < 0.0001, 7.2% of the variance.** Inner-metro seats swing about
2.8 points further to Labor than provincial ones. This is not a marginal effect.

## And it is entirely redundant

Added on top of `fed_swing`:

```
Model 1: dev ~ fed_c
Model 2: dev ~ fed_c + stype
  Df  Sum of Sq       F   Pr(>F)
   3     20.181  0.3608   0.7814
```

**F = 0.36, p = 0.78.** Nothing. The federal swing already contains everything
seat type knows about geography — which stands to reason, because a seat's
federal swing *is* its geography, measured directly rather than proxied by a
label.

Power caveat: this comparison has 180 seats, because `fed_swing` is empty for
federal elections. But F = 0.36 is not a borderline miss.

## CORRECTION, same day: this does not test demographics

**The section below overreached and is corrected here rather than rewritten.**

What was tested is **one four-level categorical variable** on **180 seats** —
the only seats with a `fed_swing` to test against, since it is empty federally.
Three extra degrees of freedom on 180 observations is weak, and F = 0.36 is not
evidence of absence.

Real demographic data is dozens of **continuous** variables: median income,
education, age profile, occupation mix, country of birth, housing tenure,
mortgage stress. Any of them can carry signal a four-way rural/metro label
cannot. Generalising from one coarse proxy to an entire data source is not
supported by this test.

**What stands:** seat type specifically is redundant to `fed_swing` on the
evidence available, and the *hypothesis* that a direct measurement beats a
correlate is worth taking seriously — the One Nation result (+0.814 against
+0.331) is real evidence for it.

**What does not stand:** the claim that demographics are therefore low-value.
That was asserted, not shown.

**The real constraint this exposes** is not about demographics at all: **only
180 seats have a `fed_swing` to test anything against.** Any feature proposed as
an addition to it faces the same weak test, seat type included. That is the
binding limit, and transposing `fed_swing` onto more state cycles — which
`transpose_federal_to_state.R` can now do — would lift it for every future
feature test, not just this one.

## Why this matters more than the result itself

**It raises a question about the ABS Census demographics plan — it does not
settle it.** (See the correction above.)

The argument for demographics was that they identify where a party is strong
before anyone announces — the "teal profile", One Nation's regional base. But
seat type is a coarse demographic proxy, and it adds nothing on top of a direct
measurement of how those same voters actually behaved.

The same logic already showed up in the One Nation work and I did not connect
it: the transposed federal One Nation vote beat the Greens-share proxy
(+0.814 against +0.331) precisely because it **measures the thing rather than
correlating with it**. Demographics correlate with voting; transposed federal
results *are* voting, in the same booths, from the same people.

So the honest expectation for demographics is **uncertain**, where I had given
it as high this morning and then as low an hour later. Neither was earned. What
is earned: a direct measurement beat a correlate once, decisively, and that is a
reason to test demographics against the transposed federal data rather than
against the old proxy.

**This does not mean demographics are worthless.** It means the case for them
should be made against the transposed federal data as the baseline, not against
the old Greens-share proxy, and that is a much higher bar than the one I quoted.

## What is not tested here

- **Independent emergence.** Seat type is exactly what the anchor uses there
  (rural and provincial raise its base rate), and it was never tested with this
  taxonomy because the work concluded before the file was found. That line was
  closed on its own criterion after four pre-registrations, and this does not
  reopen it — but if it is ever reopened, seat type is the feature to try first.
- **The One Nation allocation.** With 17 scorable districts there is no power to
  add a four-level factor.
