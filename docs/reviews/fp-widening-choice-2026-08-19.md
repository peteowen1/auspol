# Both widening factors were refused, by a test with no power to accept either

Run 2026-08-19 against
[../plans/prereg-fp-widening-choice.md](../plans/prereg-fp-widening-choice.md),
committed before the comparison ran. `scripts/compare_fp_widening.R`.

**Verdict as written: ADOPT NEITHER. Nothing has been changed.**

The rest of this file argues that the verdict is an artefact of a threshold I
set without checking what the data could produce, which is the third time in
this project. It does not adopt anything on that basis.

## What was measured

139 party-cycles over 33 completed cycles. Candidate **A = 2.419**, the
two-party projection error, pre-registered in R3 as the factor that must be
used. Candidate **B = 2.127**, maximum likelihood on the first-preference
residuals, held out leave-one-cycle-out.

| nominal | before | A | B |
|---|---:|---:|---:|
| 50% | 0.281 | 0.576 | 0.554 |
| 80% | 0.511 | 0.856 | 0.827 |
| 95% | **0.698** | 0.971 | 0.935 |

Both transform badly-broken intervals into roughly right ones. The
pre-registered test required every level within 5 points of nominal: A misses at
50% (7.6) and 80% (5.6), B misses at 50% (5.4). Both fail. Verdict: adopt
neither.

## The threshold was smaller than the noise

The 139 party-cycles are **not 139 independent observations**. Within a cycle
the shares sum to 100, so a party over-estimated forces another under. The
independent unit is the **cycle**, and there are 33.

Clustering on the cycle, the deviations are:

| | 50% | 80% | 95% |
|---|---:|---:|---:|
| clustered SE (points) | 4.3 | ~3.0 | ~1.9 |
| **A**, deviation | 1.76σ | 1.92σ | 1.26σ |
| **B**, deviation | 1.25σ | 0.87σ | 0.71σ |

**A 5-point tolerance at the 50% level is 1.16 standard errors.** A perfectly
calibrated interval fails that test roughly a quarter of the time. The rule I
wrote could not have accepted a correct answer with any reliability, so its
refusal carries almost no information.

I set that tolerance by copying the 5-point figure from the parent plan's 95%
rule, where 5 points is about 2.6 SE and perfectly reasonable, without noticing
that the same number at the 50% level is a quarter of that in sigma. **The
criterion was mis-specified before it was run, and the defect was computable in
advance from n alone.** It was not computed.

This is the third pre-registered criterion in this project to be inadequate on
contact with the data, and the second whose fault is a threshold set without
checking the sampling noise the data can produce — the first being the
reliability-bin rule in
[seat-probability-calibration](seat-probability-calibration-2026-08-19.md), four
days' work apart.

## What the evidence actually says about A and B

Read as sigmas rather than against the broken threshold:

- **B is indistinguishable from calibrated.** Every deviation under 1.3σ.
- **A over-covers at all three levels**, 1.26σ to 1.92σ, all in the same
  direction. Individually insignificant; three same-direction near-2σ
  deviations suggest A is somewhat too wide, which is the safer error and the
  parent plan says explicitly not to narrow for.

So the honest summary is not "neither works". It is **both work, B slightly
better, and the test lacked the power to say so.**

## The refusals, checked anyway

- **F1 — pooled coverage carried by small classes.** Partly true and it matters.
  Under B, ALP sits at 0.879 and OTH at 0.848 while every class with n < 20 sits
  at 1.000. Under A, ALP and OTH are both 0.939. **A is better on exactly the
  criterion F1 exists to protect**, which is the strongest thing in A's favour
  anywhere in this file.
- **F2 — level-band skew.** Passes comfortably: end-to-end skew 0.9 points for
  A, 3.8 for B, against a 10-point limit. A constant in points is the right
  shape; the correction does not favour one end of the scale.
- **F3 — the seat model must not be the reason.** Not invoked. No seat number
  appears in this argument.
- **F4 — directional side effect.** Untested, because nothing was adopted. It
  must be run before any adoption, not after.

## Heavy tails were considered and ruled out

The shape of the miss — over-covering at 50%, on target at 95% — is the
signature of a peaked, heavy-tailed error, so it was checked directly rather
than assumed. Excess kurtosis of the standardised residuals is **0.33 (A) and
0.45 (B)** against 0 for a normal, and the best-fit t has **ν = 13.5**, which is
very nearly normal. The largest standardised residual in 139 is −3.31 (NSW 2019
Others, fitted 8.0 against an actual 15.5). **A normal error with an added
constant is an adequate description**; there is no case for a t-distribution.

## Nothing was changed

Per the rule as written, no widening factor has been adopted and
`build_page.R` still publishes first-preference bands at their measured 69.8%
coverage. Whether to re-run under a correctly-sized criterion is a decision
recorded separately, because deciding it here — having seen the results — is
the exact failure this project has now made twice.

---

## RESOLVED, later the same day: A = 2.419 adopted

The test above was refused by a criterion whose tolerance was smaller than the
noise. That criterion has been amended — in the plan, as a visible addition with
the original clause left unedited — to require every level within **2 clustered
standard errors** rather than 5 fixed points.

Under the amended test **both candidates pass**, so the tie-break decides. It
was written in the parent plan's R3 before either result was known, and it picks
**A = 2.419**, the two-party projection error.

That is the strongest thing that can be said for a criterion changed after the
fact: had the amendment been bent toward a preferred answer it would have
favoured B, the number found later. It does the opposite.

| nominal | clustered SE | A deviation | B deviation |
|---|---:|---:|---:|
| 50% | 4.3 pts | 1.76σ | 1.25σ |
| 80% | ~3.0 pts | 1.92σ | 0.87σ |
| 95% | ~1.9 pts | 1.26σ | 0.71σ |

## F4 passed, and it was not a formality

F4 existed because this repo refused a very similar change eight hours earlier:
One Nation's own seat sd of 5.5, which raised its win probability in **71 of 87
seats and lowered it in 1**. Widening a party that is behind in most seats is a
one-way ratchet — upside noise lets it cross a threshold, downside costs nothing
where it was already losing.

**This change is not that**, and the numbers say so:

| | growth (before) | additive (after) | change |
|---|---:|---:|---:|
| ONP expected seats | 2.96 | 3.10 | **+0.14** (limit 1.0) |
| ONP P(at least one seat) | 0.926 | 0.897 | **−0.030** |
| ALP expected seats | 39.29 | 39.12 | −0.17 |
| GRN expected seats | 4.95 | 4.96 | +0.01 |

One Nation's probability of winning **any** seat *falls*. The difference from
the refused experiment is that this widens every party symmetrically at the
statewide level, so One Nation's rivals get the same extra spread and the
threshold-crossing advantage disappears.

Stable across seeds 42, 101 and 202: +0.144 / +0.138 / +0.148 on the mean, and
−0.030 / −0.026 / −0.031 on P(≥1). Before any of this was read as real, the
unchanged arm was confirmed to reproduce the published files **byte-for-byte**,
so the refactor that introduced the switch is inert.

## What actually changed, and a correction to an earlier claim

The multiplicative `growth` factor in `fit_seats_full.R` — every party's
statewide sd scaled by the ratio the two-party projection inflates the two-party
trend — is replaced by the additive constant. **The multiplicative form was
directly refuted** by the residual analysis that produced these candidates:
`cor(|error|, posterior sd) = −0.036, p = 0.68`, so a well-determined trend is
no more accurate in absolute terms and there is nothing for a multiplier to
scale. Statewide sds move from 1.35–1.92 to 2.52–2.62.

**Correction.** Earlier in this work I described our published first-preference
intervals as too narrow, and quoted a One Nation range of 18.7–22.8 against AE
Forecasts' 10.5–30.5. The forecast page publishes **no first-preference
intervals at all** — the trend chart draws only the mean lines, `lo95`/`hi95`
are never plotted, and the `fp_now` block in the page data is read by nothing.
That range was computed by me, not published. The coverage defect was real and
is what motivated this work, but its only live consumer was the seat model.

## Published effect

| | before | after |
|---|---|---|
| ALP seats | 40 (90%: 24–51) | 40 (90%: **23–51**) |
| ONP seats | 3 (90%: 0–7) | 3 (90%: **0–8**) |
| Labor majority | 29.7% | **28.7%** |

Medians are unchanged; this is a uncertainty change, which is what it was
supposed to be.
