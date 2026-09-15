# The commissions publish candidate-level counts. We store class-level flows.

2026-09-15. Found while chasing why 28 seats had no two-candidate figure in the
seat ledger, after Pete asked *"where did ABC get the data from then how did
they do it"*.

## The answer to that question

ABC computed nothing. The NSWEC's own distribution-of-preferences page prints
the result outright. `external/reference/nsw/dop/SG2301-port-macquarie.html`,
already on disk:

```
WILLIAMS Leslie (LIB)   21,044  ->  ELECTED 25,372   60.77%
PINSON Peta    (NAT)    13,675  ->          16,379   39.23%
Exhausted Votes              0  ->          11,579
```

Candidate names with party acronyms, round-by-round progressive totals, the
exclusion order, exhausted votes as their own line, and the two-candidate
percentages already calculated.

## What we hold, and what we keep from it

| source | files on disk | what our parser keeps |
|---|--:|---|
| NSWEC distribution pages | **279** (93 seats x 2015/2019/2023) | class-to-class flow rows |
| VEC district pages, vic2022 | **163** cached | class-to-class flow rows |
| AEC, ECQ, ECSA, WAEC | various | class-to-class flow rows |

Every `*-transfers.csv` has the same shape: `election, seat, round, from, to,
votes`. Discarded at parse time:

- **candidate identity** -- who was excluded, who received
- **exhausted votes** -- an explicit line on every source page
- **progressive totals** -- the running count after each round
- **the printed two-candidate percentages**
- **the exclusion order at candidate level**

This is `CLAUDE.md`'s own rule, broken verbatim: *"Never aggregate a source
down to the columns you happen to need -- write every column through and
select later."* It is the same failure the file already records for
`fetch_seat_salience.R`, which cached an 8-week mean and threw away the weekly
series.

## The cost, measured

**Two-candidate coverage.** 348 seats have an official figure (AEC files, ECSA
district file). Deriving the rest from class-level flows needs three different
rules and still leaves 28 blank:

| rule | why it is needed | where it fails |
|---|---|---|
| candidate-count | exact when rounds line up with candidates | collapses on WA |
| last-round recipients | handles a class running two candidates (Mirani) | fails under optional preferential voting |
| never-excluded | crude fallback | fails on multi-candidate classes |

Validated against South Australia, the only state with an official answer: the
pair is right in **43 of 47**, and where right the two-candidate share is
within **0.62** on average. None of that reconstruction would be necessary if
the parser kept what the page prints.

**Port Macquarie cannot be done at all at class level.** It was Liberal against
National -- both `LNP` to us -- so the final two are one class. 1 seat in this
corpus, but the shape recurs wherever two candidates of a class make the final
two.

**Victoria 2022 is worse, and it is the live target's own previous election.**
`vec-2022-vic-transfers.csv` covers 76 of 87 seats, and only **48 are
complete**: 11 seats (Dandenong, Mulgrave, Malvern, Lowan and 7 others) have no
transfer rows at all, and 28 more stop before the count finishes, with 3, 4 or
5 candidates still standing in the final recorded round. The raw pages are
cached; the parser did not finish the job.

## Ideas this opens, in the order I would try them

**1. Fit the exhaust rate from the counts instead of from polls.**
`R/preferences.R` already takes an `exhaust` argument and `R/load_polls.R`
reads a rate off a poll column -- so exhaustion IS modelled, from a polled
estimate, while the measured quantity sits unparsed on disk. Port Macquarie
exhausted 11,579 of 53,330 votes, 22%. An empirical per-class, per-jurisdiction
exhaust rate is a direct substitute for a polled one, and this repo's standing
preference is to estimate a constant from data rather than assume it.

**2. Use the official two-candidate result as a direct target for the flow
half of the model.** Today the primaries are scored per seat and the flows are
validated only through the seat outcome. With a two-candidate figure for nearly
every seat, the flow model can be scored on its own output. That is the half of
the pipeline with no direct metric at present.

**3. Candidate-level flows.** A Green preference to a teal independent and to a
Labor-aligned independent are not the same transfer, and at class level they
are indistinguishable. Keeping candidate identity lets the flow model condition
on candidate attributes -- incumbency, party of origin, whether they are the
excluded candidate's successor.

**4. Repair the Victorian distributions before anything else uses them.** The
truncated file is not only a gap in a ledger column: these rows feed the
preference-flow model, and Victoria is the election being forecast. A third of
its distributions being partial is a defect in the live path, not a cosmetic
one. Not yet measured.

**5. The exclusion order as an emergence signal.** Which candidates survived to
late rounds says who was genuinely in contention, which is exactly the quantity
the surge work has been trying to infer from priors.

## On ABC as a source

We have never used it: every entry in `docs/DATA-REGISTRY.md` is a commission,
and Antony Green appears only as a method (booth respreading for notional
margins). **That should not change.** ABC is a secondary presentation of the
same commission counts, and adopting their data means adopting their party
classification -- the trap `CLAUDE.md` already records from the anchor clone,
where the Shooters were filed as `IND` against our `OTH_RIGHT` and silently
corrupted a check.

**As a cross-check they have already earned their place twice today.** The ABC
Mirani page would have exposed the two-candidates-per-class bug immediately,
and the Port Macquarie page makes the class-level limitation obvious at a
glance. Validate against them; do not store them.

## Not established

- **What the truncated Victorian flows actually cost.** Named, not measured.
- **That an empirical exhaust rate beats the polled one.** It is better
  sourced; it is not yet better measured.
- **That candidate-level flows improve anything.** More detail is not
  automatically more signal, and the class aggregation may be doing useful
  smoothing.

---

## Addendum: what the truncated Victorian flows actually cost (idea 4, measured)

**vic2022 is the only election affected.** Every other jurisdiction's
distributions are essentially complete:

| election | seats with rows | complete counts |
|---|--:|--:|
| qld2024 | 93 | 93 |
| sa2026 | 47 | 47 |
| nsw2023 | 93 | 92 |
| wa2025 | 59 | 57 |
| **vic2022** | **76** | **48** |

**The truncation drops the LAST exclusions, which are the biggest transfers.**
A truncated seat is short by a median of one round, and the final excluded
candidate is the one holding everything handed down before them.

| vic2022 seats | n | share of formal vote that moves | mean rounds |
|---|--:|--:|--:|
| complete | 48 | **39.7%** | 6.5 |
| truncated | 28 | **19.2%** | 5.0 |
| no rows at all | 11 | 0% | -- |

We record 1,016,053 transferred votes against roughly 1,436,197 implied by the
complete seats' rate: about **420,000 missing, 29% of Victoria's transfers**.

**And the loss is compositional, not just volumetric.** The class excluded in
the final RECORDED round:

| excluded last | complete counts | truncated counts |
|---|--:|--:|
| GRN | 56 | 18 |
| LNP | 22 | **0** |
| ALP | 6 | **0** |
| IND / OTH / OTH_RIGHT | 12 | **74** |

**In a truncated seat we never observe a major-party exclusion.** The Victorian
flow estimates are therefore built disproportionately from micro-party and
independent transfers and under-weight the Green and major transfers that
decide seats.

**This reaches the model.** `scripts/fit_xgb_flows_v1.R:24` globs
`vec-[0-9]{4}-vic-transfers.csv` into the training corpus alongside every other
jurisdiction, so the biased rows are training data, not just a ledger gap.

### What follows, and what I am NOT claiming

Repairing this is a **data repair with a measured directional defect**, which
is a different and stronger class of change than the mechanisms refused
earlier today -- those added a term and hoped; this removes a known bias from
existing training data. The raw pages are already cached in
`external/elections/cache/vec-2022-vic/` (163 files), so it is a parser job,
not a fetch.

But "bound to improve" is the expectation that failed four times today
(education residual, demographic axis, Greens concentration, seat correlation).
The honest statement is: the input is wrong in a known direction, fixing it is
cheap, and the effect on seat log loss is **unmeasured**. It gets a
pre-registration like anything else.
