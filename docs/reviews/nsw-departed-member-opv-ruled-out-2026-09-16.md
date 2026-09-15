# OPV/exhaustion is ruled out as the departed-member variance mechanism

2026-09-16, resolving the open question from
`docs/reviews/nsw-departed-member-2026-09-15.md`: is the departed-member
variance blowup (held party's primary sd 5.17 to 8.81 when their member
leaves) a regional artifact, or specific to optional preferential voting,
NSW's distinguishing feature among the corpus's jurisdictions?

## What was built

`scripts/build_nsw_exhaustion.R`. The exhausted-votes line is printed on every
NSWEC distribution-of-preferences page and was being discarded at parse time
(`docs/reviews/unparsed-preference-detail-2026-09-15.md`). Parsed the final
progressive exhausted-vote total off all 186 cached nsw2019/nsw2023 pages,
divided by each seat's formal vote to get an exhaustion rate, and joined to
`output/retirement-derived.csv`. All 186 seats ran a full distribution (NSW
runs distributions through regardless of an early majority, unlike Victoria).

## The result

| member | n | mean exhaustion | sd |
|---|--:|--:|--:|
| stood again | 134 | 11.0% | 4.01pp |
| gone | 47 | **13.3%** | 5.36pp |

t = -2.64, p = 0.010. Real and in the direction OPV predicts, but a 2.3-point
move against a variance effect that needed sd to move by 70%.

**And it does not discriminate the failures.** Within the departed cohort, the
eleven safe seats the review called wrong exhaust at 13.24%, the 36 it called
right at 13.30% — indistinguishable (n=11 vs 36). Whatever separates a
departed seat we get right from one we get wrong, it is not how much of that
seat's vote exhausts.

## Why exhaustion cannot be the mechanism, not just weakly correlated with it

The measured variance blowup is in the **held party's first-preference
share** — the primary vote, settled at the count of first preferences, before
any preference distribution happens. Exhaustion is a property of LATER
rounds: a ballot exhausts when a voter's expressed preferences run out during
redistribution. It cannot retroactively cause variance in a count that
finished before redistribution started. The correlation above is real (OPV
seats probably do get a bit rowdier when the incumbent leaves) but it cannot
be the causal channel for the specific number the model needs to fix.

## What this leaves

Mechanism 2 stands: **NSW state members carry a bigger personal vote than
federal ones**, and OPV is not why. That means the correction from last
night's open item 1 (`docs/plans/prereg-departed-member-width-2026-09-16.md`'s
successor) should key on **region** (or a member-type signal, not yet built),
not on voting system — there is no reason to expect the effect in a
hypothetical second OPV state, and no reason to withhold it from a
compulsory-preferential state whose personal votes turn out to be similarly
large. The federal (1.06x) vs other-states (1.22x) split already in the
2026-09-15 review supports a continuous, region-scoped multiplier over a
NSW-only cliff, per `CLAUDE.md`'s shrinkage rule.

Output: `output/nsw-exhaustion-by-departure.csv`, 181 seat-elections, columns
`election, seat, exhausted, formal, exhaust_rate, retire_derived, in_eleven`.
