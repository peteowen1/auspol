# Every seat simulated, candidate-level — and it fails its anchor checks

Built 2026-08-18 after the ECSA API unblocked the One Nation flow data.
**The machinery works end to end. The output is not publishable, and the
reason is specific and fixable.**

## What now exists

A simulation that, for every one of 87 districts (Narracan excluded, no 2022
first preferences), projects each party's primary vote and then distributes
preferences the way the count actually runs — lowest excluded, transferred at
rates estimated from real counts, conditional on who is still standing, until
two remain.

Flow rates come from two matrices, each used for what it is good at:

| source | exclusions | covers | limitation |
|---|---:|---|---|
| Victoria 2022 (VEC) | 452 | Greens, independents, minor-right, general OTH | One Nation contested 5 of 88 seats — no ONP data |
| SA 2026 (ECSA API) | 294 | One Nation throughout | different state, one election |

## The first run had a bug worth recording

One Nation "won" Richmond and Melbourne outright. Cause: when Labor is excluded
with the Greens and One Nation standing, no such cell exists in the SA data —
Labor was rarely excluded with the Greens still in. The fallback used the
pooled Labor row, which shows **GRN 0.0%** because that configuration never
arose. Renormalising a sparse row over the survivors then handed **100% of
Labor's preferences to One Nation**.

Absence of evidence became certainty of zero. Fixed by mixing every row with a
uniform over the survivors (weight 0.15), and by preferring Victorian cells
wherever One Nation is not involved.

## It still fails, and this is the real finding

| anchor check | result |
|---|---|
| Greens hold their 4 seats | **FAIL** — median 1 |
| One Nation does not win inner-city Green seats | **FAIL** — Melbourne 63%, Richmond 60% |
| Brunswick stays Green | pass — 74% |

**Root cause: the One Nation seat allocation does not transfer to Victoria.**

The form fitted on SA 2026 is `ONP_seat = 14.71 + 1.21 x minor_right_2022`.
Its intercept means One Nation cannot fall below about 15% in any seat:

| seat | 2022 minor-right | allocated ONP |
|---|---:|---:|
| Richmond | 1.15 | 15.2% |
| Brunswick | 1.22 | 15.3% |
| Prahran | 1.60 | 15.8% |

**South Australia never observed a seat where One Nation polled below 9.1%**,
and its lowest-ONP seats were wealthy inner Adelaide (Bragg, Unley), not
Green-held inner-city seats. Victoria's Brunswick has the Greens on 43.6% and
Richmond on 34.7% — a seat **type** South Australia does not contain.

So this is not extrapolation past the edge of a fitted range. It is applying a
relationship to a kind of seat the fitting data had no example of. One Nation
on 15% in Richmond is not a plausible number, and everything downstream of it
is wrong.

## What this does and does not settle

**Settled:** the pipeline exists, runs, and surfaces its own failure rather
than hiding it. The preference machinery is sound — Brunswick behaving
correctly at 74% Green is evidence of that, since it depends on the same
elimination logic.

**Not settled, and not to be quoted:** any seat count from this run. ALP 44,
LNP 37, ONP 4, GRN 1 are artefacts of a broken allocation, not a forecast.

**Directly answers the standing question for Pete** about transferring SA's
allocation slope to Victoria: measured, it does not transfer, and the failure
is concentrated exactly where Victoria differs from South Australia.

## What would fix it

The allocation needs a predictor that can distinguish an inner-city
progressive seat from an ordinary low-minor-right one. The Greens' own vote
share is the obvious candidate and is available per seat. **That is a new
specification and must be pre-registered and validated before use** — fitted on
SA it cannot be tested, because SA has no seats of the type in question, which
is the whole problem.

The honest alternative, if no validated form exists: carry One Nation's
seat-level allocation with explicitly wide uncertainty and report seat
probabilities as ranges, rather than shipping a point estimate built on a
relationship known to break in a fifth of the chamber.
