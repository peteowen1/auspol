# The sum-to-100 shortfall is One Nation, not Others — and the shrinkage causing it has historically been right

Measured 2026-08-18, chasing `NL3` (NSW 2027 fitted first preferences sum to
94.1 against a required 100 ± 5), which keeps the scheduled job red.

**Nothing was changed.** The finding is that the obvious fix is not supported by
the record, and that the check may be asserting a property the model does not
promise. Both of those are decisions for Pete, not for this session.

## Where the missing points are

Fitted endpoint against the mean of the last 90 days of polls, per party:

**Victoria 2026 — the cycle that is published**

| party | fitted | polls (90d) | gap | prior | polls in cycle |
|---|---:|---:|---:|---:|---:|
| LNP | 28.38 | 27.90 | +0.48 | 34.48 | 53 |
| ALP | 24.87 | 24.80 | +0.07 | 36.66 | 53 |
| **ONP** | **20.00** | **23.15** | **−3.15** | **0.28** | 18 |
| GRN | 13.12 | 13.25 | −0.13 | 11.50 | 53 |
| OTH | 10.95 | 10.80 | +0.15 | 17.36 | 53 |
| | **97.31** | 99.90 | −2.58 | | |

**NSW 2027 — the cycle that fails NL3**

| party | fitted | polls (90d) | gap | prior | polls in cycle |
|---|---:|---:|---:|---:|---:|
| ALP | 31.21 | 31.00 | +0.21 | 36.97 | 28 |
| LNP | 23.70 | 23.00 | +0.70 | 35.37 | 28 |
| **ONP** | **20.26** | **24.67** | **−4.41** | **1.80** | 8 |
| GRN | 11.05 | 11.33 | −0.28 | 9.70 | 28 |
| OTH | 11.01 | 10.00 | +1.01 | 17.98 | 28 |
| | **97.23** | 100.00 | −2.77 | | |

In both cycles the polls themselves sum to essentially 100, every party except
One Nation tracks its polling within about a point, and **One Nation alone
accounts for more than the entire shortfall.**

## This corrects the earlier diagnosis, without contradicting its measurement

[couple-party-trends-2026-08-18.md](couple-party-trends-2026-08-18.md) concluded
the drifting sum was "a symptom of an Others bias". Others is not where the
current shortfall is: OTH is +0.15 in Victoria and +1.01 in NSW.

Both can be true, because they measure different things. That review measured
**fitted endpoint against the eventual result** across historical cycles, and
Others does carry a bias there (−1.02, see
[others-bias-2026-08-18.md](others-bias-2026-08-18.md)). This measures **fitted
endpoint against the polls it was fitted to**, in the two live cycles. The
first is about the polls being wrong; the second is about the fit not following
them. Only the second explains a sum computed from the fit.

## The obvious fix is not supported

One Nation is anchored to a prior of 0.28 in Victoria and 1.80 in NSW while
polling in the low twenties, so "the prior is dragging a surging party down"
is the natural explanation. Tested against 137 (cycle, party) rows over 33
cycles with complete actuals, using the table `test_others_bias.R` already
emits:

| \|prior − final polls\| | n | mean (fit − polls) |
|---|---:|---:|
| < 2 | 55 | −0.18 |
| 2–5 | 45 | −0.30 |
| 5–10 | 29 | −0.13 |
| **> 10** | **8** | **−0.02** |

Regression slope −0.034 per point of gap (se 0.017, p=0.050). Real, but far too
small: at Victoria's 22.9-point gap it predicts −0.78 of drag, not −3.15. **And
in the bucket that should show it most, the drag is zero.**

Worse for the fix, where the gap is largest the shrinkage has *earned* its
keep:

- mean |fit − actual| **2.43** against mean |polls − actual| **2.79**

The single historical precedent for One Nation surging from nothing is WA 2017:
prior 0.0, final polls **9.2**, fitted **7.8**, actual **4.9**. The polls
over-called it by nearly double and the fit's undershoot moved toward the
truth. One case proves little, but it points the opposite way from the fix.

**So: do not raise One Nation's fitted level to meet its polling.** The record
says that would make the forecast worse, not better.

## What explains the rest: One Nation has no history to fit

The prior-drag mechanism accounts for −0.78 of Victoria's −3.15. Two candidates
were tested for the remaining ~2.4.

**The unfolding imputation — REFUTED.** One Nation is named in only 18 of 53
Victorian polls, so an imputation landing low would depress the level exactly
like this. It does not. Refitting on the 18 polls that name One Nation, with no
imputed rows at all, puts the endpoint at **20.00** — identical to the full
fit's 20.00 to two decimals. Only one row was ever fold-corrected. The
imputation is not the cause.

**The cause is that the series barely exists.** Splitting the polls by whether
they name One Nation looks like a methodology split and is not — it is a date
split:

| group | n | date range | LNP | OTH | ONP |
|---|---:|---|---:|---:|---:|
| names ONP | 18 | 2026-01-28 → 2026-08-06 | 27.64 | 11.36 | 22.36 |
| does not | 8 | 2025-09-01 → 2025-12-01 | 37.12 | 20.25 | — |

The same firms appear in both groups — Redbridge, DemosAU, ResolvePM,
Newspoll3, Freshwater — so nothing methodological separates them. **They began
breaking One Nation out in January 2026.** Its rise came out of the Coalition
(−9.5) and Others (−8.9), which together account for its 22.4.

So the fitted series runs from the 2022 election, where the prior is 0.28, to
today, with **no observation at all for the first three years** and roughly
seven months of data at the end. The endpoint is the tail of a walk that spent
most of its length anchored near zero. That is not a bug in the imputation or a
mis-set constant; it is what fitting a party that did not previously exist
looks like.

Whether 20.00 or 23.15 is the better forecast is genuinely open, and the one
precedent (WA 2017, above) favours the lower number.

## The question this raises about NL3 itself

`NL3` requires fitted first preferences to sum to 100 ± 5. The model fits each
party independently with shrinkage toward its previous result, so nothing makes
them sum — and the coupling work already measured that **forcing** them to sum
costs 0.33 points of first-preference MAE, so the untidiness is bought
deliberately.

A cycle containing a party surging from near zero is exactly the case where
independent shrinkage will not sum, and the evidence above says that shrinkage
is doing its job. On that reading `NL3` is asserting a property the model does
not promise and should not be made to.

**Not acted on.** Relaxing a pre-registered check to clear a red build is the
move this repo's own rules exist to prevent, and the case for it rests on eight
rows in one bucket. Options, for Pete:

1. **Leave `NL3` as it is** and accept a red scheduled job until the remaining
   2.4 points are explained. Costs: a permanently red job trains everyone to
   ignore it.
2. **Re-scope `NL3`** to assert what the model does promise — e.g. that each
   party's fit stays within some distance of its own recent polls, which would
   have caught this One Nation gap directly and is a stronger check than the
   sum. Requires a pre-registration before it is written.

Option 2 is the better check on its merits, but it must not be adopted because
it happens to make the build green.
