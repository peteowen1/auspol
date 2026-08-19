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
