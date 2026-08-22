# Gate 1 passes, and it is not the Coalition

Against `docs/plans/prereg-survivor-multiplicity.md`. Gate 1 is a measurement
with no arms: it asks whether the mechanism touches enough of the evidence to
justify a three-fetcher data change, and it stops the work under 10%.

## The number

Exclusion rounds where a surviving **class** fielded more than one candidate:

| jurisdiction | rounds | with multiplicity > 1 | share |
|---|---:|---:|---:|
| **Victoria** | 452 | 201 | **44.5%** |
| South Australia | 294 | 60 | 20.4% |
| Queensland | 750 | 44 | 5.9% |
| **pooled** | **1,496** | **305** | **20.4%** |

**Gate 1 passes**, on a threshold of 10% fixed before the measurement.

Two things make it stronger than the pooled figure suggests:

- **Victoria — the jurisdiction being forecast — is the most exposed at 44.5%**,
  and carries **20.0% of its transferred votes** in such rounds.
- **Queensland is the least exposed at 5.9%, for a structural reason**: its
  Coalition is a single merged party, so it cannot have the Liberal-versus-
  National contests that this line of enquiry started from. Had Queensland been
  measured alone, the gate would have stopped the work.

## The reframing, which matters more than the gate

The mechanism was reached through Western Australia's Liberal-versus-National
contests, so the expectation was that Coalition doubling would dominate. It does
not. Which classes actually field more than one surviving candidate:

| class | Victorian rounds | SA rounds |
|---|---:|---:|
| OTH_RIGHT | 133 | 22 |
| OTH | 67 | 24 |
| IND | 47 | 26 |
| LNP | 34 | 8 |

**It is the catch-all buckets.** `OTH_RIGHT` aggregates every minor-right party;
`OTH` aggregates everything unclassified; `IND` aggregates every independent. A
seat with three minor-right candidates gives `OTH_RIGHT` a multiplicity of
three, and the cell key records it identically to a seat with one.

So a class that happens to be a **bucket** captures several candidates' worth of
preferences, and the matrix reads that as the bucket being popular. The
Coalition case that led here is the fourth-largest contributor, not the first.

## What this changes about the earlier work

It does **not** rehabilitate Western Australia. Those three arms were refused on
a criterion, and nothing here revisits them.

It does say the line of enquiry was aimed slightly wrong. `ALP → LNP` at 68% in
WA was a real artefact, but the general form of it is not about Coalition
three-corners at all — it is about **how many candidates sit inside a class**,
and our classes are deliberately coarse. That is a property of our own
classification scheme, present in Victoria at 44.5% of rounds, and it is in the
published model today.

## What has NOT been shown

**That fixing it improves the forecast.** Gate 1 sizes exposure, not effect. A
mechanism touching 44.5% of Victorian rounds can still be worth nothing if the
splits it induces are small or if the resulting cells are too thin to use —
which is exactly what refusal M2 of the plan exists to detect, and why the plan
requires reporting cell coverage before and after.

Nor does it show the direction. Splitting `OTH_RIGHT|…` by multiplicity could
easily make the matrix worse by starving every cell.

## Next, per the plan

Gate 1 having passed, the work it authorises is emitting per-round, per-class
candidate multiplicity from the Victorian, South Australian and Queensland
fetchers, then scoring the arm against the pre-registered 2 SE bar with Western
Australia excluded entirely.

That is a real data change across three parsers, and the plan's refusals — M1
(byte-identical control), M2 (cell thinning), M3 (live forecast), M4 (no WA),
M5 (One Nation direction) — all stand as written.

## Method note

The three measurements were taken by copying each fetcher into a scratch
directory and inserting a dump **before** its candidate-level table is
aggregated to `(election, seat, round, from, to)`. No fetcher in the repo was
modified, which is the point of a gate: it must be answerable without doing the
work it is deciding whether to authorise.
