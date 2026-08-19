# No, we do not have those seats near 50/50 — and the reason is a 13.7% spread loss we inflict on ourselves

Run 2026-08-20. `scripts/onp_tcp_vs_yougov.R`, `output/onp-tcp-comparison.csv`.

## The question

Of the 17 seats YouGov gives One Nation, three are ones where we assign the
party a probability of **0.000** — two of which YouGov calls at 50.3 and 50.7.
Pete asked the right question: **what two-candidate-preferred does our model
actually give One Nation there?**

A win probability alone cannot separate two opposite failures. If our central
One Nation TCP is ~30% against their ~50%, a probability near zero is
*consistent* and the disagreement is about the central estimate. If our TCP were
~47% and we still said zero, our **spread** would be far too tight.

## The answer: our centre, not our spread

One Nation reaches our final two in **5** of their 17 seats. Where it does:

| seat | YouGov ONP 2pp | **our ONP TCP** | our ONP first pref | YouGov ONP first pref |
|---|---:|---:|---:|---:|
| Melton | 54.3 | **33.7** | 29.7 | 33 |
| Greenvale | 52.3 | **31.9** | 28.4 | 32 |
| Lowan | 50.3 | **29.2** | 27.2 | **44** |
| Thomastown | 50.8 | **26.6** | 23.7 | 33 |
| Ovens Valley | 50.7 | **23.4** | 20.8 | **44** |

Our TCP mean is **29.0%** against their **53.3%** — a gap of **+22.7 points**.
In the other 12 seats One Nation does not even reach our final two.

**So the 0.000 probabilities are consistent with our own central estimate.** My
earlier framing — that a zero against their 50.3 was "a claim we have not
earned" and pointed at our uncertainty being too tight — **was the wrong
diagnosis, and I withdraw it.** Nothing about our spread is implicated by these
three seats. Our centre is 20 points away.

## And it is not preferences either

Both models agree One Nation attracts preferences badly. In Lowan YouGov take it
from a 44% primary to a 50.3% two-party — a gain of 6.3 points across the whole
distribution. We take 27.2% to 29.2%, a gain of 2.0. Their own report says the
party loses 13 seats it leads on primaries "as One Nation struggles to attract
preferences".

The entire disagreement is in the **first preferences**.

## Where it really is: we compress One Nation's seat-level spread

Across 87 comparable seats:

| | mean | sd | range | CV (sd/mean) |
|---|---:|---:|---:|---:|
| ours | 20.4 | 5.8 | 9.3 – 31.1 | **0.283** |
| YouGov | 25.0 | 8.3 | 8.0 – 44.0 | **0.331** |
| **SA 2026, actual result** | 23.0 | 7.7 | 9.1 – 37.5 | **0.334** |

Our allocations **correlate +0.663** with theirs, so we broadly agree about
*where* One Nation is strong. We disagree about *how* strong: their top seats
reach 44%, and our maximum anywhere in Victoria is 31.1%.

The statewide gap is only 4.5 points (20.4 against 24.9). The seat-level gaps are
three to five times that: Ovens Valley +23.2, Eildon +18.2, Lowan +16.8,
Polwarth +15.8, Murray Plains +15.8. And we are *higher* than them in affluent
inner-metro seats — Kew 22.8 against their 12, Hawthorn 19.0 against 9.

## The defect, with its mechanism

**This is not a disagreement with YouGov. It is our method failing its own
stated intent**, and the anchor is South Australia's actual result, not
YouGov's model.

The allocation quantile-maps One Nation's seat ordering onto **SA 2026's
observed spread**. So the output's CV should come out at SA's 0.334. Traced
through:

| stage | CV |
|---|---:|
| SA 2026 actual, the thing being copied | 0.334 |
| `onp_ratio` as constructed | 0.327 |
| **our published ONP shares** | **0.283** |

The mapping works. Then `shares <- 100 * shares / rowSums(shares)` **destroys
13.7% of the spread.** Seats allocated a high One Nation share get a larger row
total, so dividing by that total shrinks the high values harder than the low
ones. The compression is systematic and in one direction.

YouGov's MRP, built from demographics by an entirely different method, lands at
**0.331 against SA's 0.334** — so two independent sources agree on the spread
and we are the outlier, by exactly the amount the renormalisation removes.

## What happens next, and what must not

A fix is **not** being made here. It needs its own pre-registration, because:

- the criterion must be **our own intent** — reproduce SA's CV — with SA's
  actual result as the anchor. Agreement with YouGov is corroboration, never the
  target;
- concentrating a losing party's vote is a **one-way ratchet** on seat counts.
  Two changes have already been refused in this repo for exactly that, and a
  directional check on One Nation's expected seats is mandatory before anything
  ships;
- and the honest measurement still needs an out-of-sample test, which is blocked
  on the NSW data.

What this does change immediately is the priority. The One Nation seat gap is
**not** a statewide-level problem and **not** a preference-flow problem. It is
seat-level allocation, and there is a 13.7% arithmetic loss sitting inside it
that nobody put there on purpose.
