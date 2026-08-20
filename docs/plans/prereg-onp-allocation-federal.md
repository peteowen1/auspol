# Pre-registration: replace the One Nation allocation's ORDERING with a direct federal measurement

Written 2026-08-20, **before anything is fitted or scored**. Committed before running.

## The defect

The published One Nation seat allocation orders Victorian districts by their
**Greens share** (coefficient −0.0968) and quantile-maps the magnitudes onto
**South Australia 2026's** observed spread. Two measured problems:

- It is **22 points below YouGov** in Lowan and Ovens Valley, and the whole
  17-versus-3 seat disagreement traces to seat-level allocation rather than the
  statewide level or preference flows
  ([onp-tcp-and-spread](../reviews/onp-tcp-and-spread-2026-08-20.md)).
- A **13.7% spread compression**: the quantile map produces a CV of 0.327,
  matching SA's 0.334 as intended, and then `shares / rowSums(shares)` shrinks
  it to 0.283. High-allocation seats have larger row totals, so renormalising
  cuts them hardest.

## What is now available that was not

Each Victorian district's **federal One Nation vote, measured in its own
booths** — 5.28% mean, CV 0.553, correlating with YouGov at **+0.683** where
the current allocation manages +0.663
(`scripts/transpose_federal_to_state.R`).

## What this proposal does and does not change

**Changes the ORDERING**: which districts are One Nation's strongest, taken
from where the party actually polled rather than inferred from the Greens vote.

**Does not change the LEVEL**: the statewide One Nation forecast is untouched.
Federal 2025 One Nation was 5.3% in Victoria against a state forecast near 20%,
so only shape transfers.

**Separately fixes the renormalisation compression**, which is arithmetic rather
than modelling: the allocation is computed so the CV survives normalisation
instead of being reduced by it.

## What the data can and cannot support

Thin, and stated up front. One Nation **contests only a minority of districts**:

| election | districts with ONP | mean where they stood |
|---|---:|---:|
| VIC 2014 | 0 of 88 | — |
| VIC 2018 | 0 of 88 | — |
| VIC 2022 | 4 of 87 | 4.7% |
| NSW 2019 | 12 of 93 | 8.1% |
| NSW 2023 | 17 of 93 | 9.7% |

So **33 observations, all conditioned on the party choosing to stand.** That is
enough to compare two ORDERINGS and nowhere near enough to fit a level or a
spread. This plan therefore refuses to fit either.

## The test

**NSW 2023 (17 districts) and NSW 2019 (12).** For each, rank districts three
ways and compare against where One Nation actually polled:

- **A** — current: by Greens share, coefficient as shipped.
- **B** — proposed: by transposed federal One Nation vote from the preceding
  federal election.
- **C** — a floor: uniform, no ordering at all.

Measured by **Spearman rank correlation** with the actual state One Nation
share, and by MAE after scaling each ordering to the actual statewide total.

Victoria cannot be tested: One Nation contested no seats in 2014 or 2018 and
four in 2022.

## Decision rule, fixed now

- **Adopt B** if its rank correlation beats A in **both** NSW elections and its
  MAE is no worse in either.
- **Keep A** otherwise.
- **If both A and B fail to beat C**, adopt C — a uniform allocation — and say
  plainly that the ordering has never been worth anything. The repo already
  records that A beats uniform by only 0.122 MAE.

## Refusals

- **N1 — no fitting a level or a spread on 33 observations.** Only the ordering
  is under test. A coefficient fitted on this many points, selected on this many
  elections, is the kind of thing that reversed today when the sample grew.
- **N2 — agreement with YouGov is not the criterion.** B correlating better with
  YouGov is what motivated this, and it is **not** evidence B is right. Only the
  NSW test decides. If B wins on YouGov agreement and loses on NSW, A stays.
- **N3 — the compression fix is separate and must be reported separately.** It
  is arithmetic, it applies whichever ordering wins, and it must not be bundled
  so that a spread increase gets credited to the new ordering.
- **N4 — the one-way ratchet.** Concentrating a losing party's vote raises its
  seat count through the convexity of the share-to-seat map, and two changes
  have already been refused here for that. Report the effect on Victoria's One
  Nation expected seats; if it rises by more than **2.0**, stop and report
  rather than ship.
- **N5 — contest selection is not modelled and must be admitted.** Every
  observation above is a district One Nation chose to contest. The Victorian
  model gives them a vote in all 88 seats. That assumption is unchanged here and
  untested by anything in this plan; it is plausible for 2026 given they poll
  near 20% statewide, and it would be badly wrong in a cycle where they stood in
  twelve seats.

## What the criteria cannot see

Whether One Nation's Victorian statewide level is right. This is entirely about
distributing a given total across districts, and a better distribution of a
wrong total is still wrong.
