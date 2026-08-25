# Census at SED: acquired, joined, and the signal is strong — but it may explain nothing new

2026-08-25. **Descriptive scoping only. No model fitted, no improvement
claimed.** The question was whether seat-level Census demographics carry any
association with vote — if not, Path A is not worth pre-registering.

## Acquired

ABS 2021 General Community Profile at **State Electoral Division** for VIC, NSW
and SA. `scripts/fetch_census_sed.R`. 234 divisions, 121 columns: full age/sex
breakdowns plus medians for age, personal/family/household income, rent,
mortgage repayment, household size and persons per bedroom.

**78 of 87 Victorian seats join to a 2022 result.** The nine that do not
(Ashwood, Berwick, Eureka, Glen Waverley, Greenvale, Kalkallo, Laverton,
Pakenham, Point Cook) were created or renamed by the post-2021 redistribution
and have no 2021 Census geography. That is asserted against a named list, so a
tenth unmatched seat would stop the run rather than silently shrink the corpus.

## The association is real and substantial

Correlation with each party's 2022 first-preference share, 78 seats:

| variable | ALP | LNP | GRN | OTH_RIGHT |
|---|---:|---:|---:|---:|
| median age | −0.45 | **+0.69** | −0.32 | −0.13 |
| median personal income | −0.14 | −0.10 | **+0.64** | **−0.50** |
| median family income | −0.08 | −0.08 | **+0.54** | **−0.52** |
| average household size | +0.44 | −0.18 | **−0.53** | **+0.50** |
| persons per bedroom | +0.31 | **−0.56** | +0.48 | −0.09 |
| median rent | +0.25 | −0.27 | +0.39 | −0.33 |

Older seats vote Coalition (+0.69). Greens concentrate in high-income,
small-household seats. **The minor right runs opposite on income (−0.50, −0.52)
and with household size (+0.50)** — which is the profile of the seats where One
Nation actually won in South Australia.

## The caveat that decides whether this is worth anything

**These are associations with the LEVEL of the vote, and our model already
knows the level.** Each seat enters the simulation as its 2022 first
preferences. Demographics correlating with where parties are strong is
therefore **not new information** — the baseline already encodes it, more
precisely, because it is the actual result rather than a demographic proxy for
it.

**Nothing above shows demographics predict the SWING**, which is the quantity a
swing model actually needs and the only place a demographic term could add
value on top of the baseline.

This is the same distinction that made six of today's ten hypotheses fail:
explaining a cross-sectional pattern is not the same as improving a
forecast.

## Where the value could still be, stated precisely

MRP's advantage is not that demographics predict swing. It is that MRP **does
not need the baseline at all**. When a seat breaks from its own history —
MacKillop's Coalition 67.0 → 26.9 — the baseline is actively misleading, and
demographics are the only remaining guide.

So the testable claim is narrow and specific:

> **In seats where the previous result is a poor guide, does a demographic
> model beat baseline-plus-uniform-swing?**

Not "do demographics correlate with vote" — they plainly do, and it does not
follow that they help.

## What must be pre-registered before anything is fitted

- The criterion is **out-of-sample seat accuracy against uniform swing**, which
  has survived six alternatives this session and is not waived for being a more
  sophisticated technique.
- **The comparison must include the baseline.** A demographic model that beats
  *nothing* is uninteresting; it has to beat *the 2022 result plus a swing*.
- Validation on the historical corpus — Victoria 2014/2018/2022, plus the
  federal and state data already held — never on Victoria 2026, which has no
  result.
- **The nine redistributed seats must be handled or excluded explicitly**, not
  silently dropped, since excluding seats correlated with the outcome under
  test is exactly the trap `backtest_candidate_sa.R` documents for Ngadjuri.

## Honest status

Path A now has all three inputs — booth results, Census demographics, seat
results — and a real association to work with. **It has not been shown to add
anything over the model we ship**, and the descriptive result above does not
argue that it will. That is the next experiment, not this one.
