# A departing independent keeps 38% of their vote. We assume 100%.

2026-09-15, at Pete's request to look into group E of the AEF-7 triage --
"major reclaims from a departing independent", 4 seats, 3.9% of pooled seat log
loss, labelled *structurally inexpressible today*.

This is the re-measurement that `scripts/published_flags.R` has recorded as
**queued since 2026-09-13** against `AUSPOL_HONOUR_DEPARTED`.

## The history

`docs/plans/prereg-vote-belongs-to-the-person-2026-09-06.md` split into two
rules. **Rule 2 shipped.** **Rule 1 -- "honour departed" -- was refused**, and
the refusal rested on a trade between exactly two seats:

- New England 2013 improved: p(IND) 0.995 -> 0.957
- Wentworth 2022 broke: p(IND) 0.705 -> 0.138

The plan itself flagged the problem with that: rule 1 decays the departed
leader's base correctly, and Wentworth needed a NEW independent to rise in its
place, which is a different mechanism. A rule was judged on two cases.

## The population, selected before the outcome

Every (seat, class) where a non-major class polled 15% or more at the PREVIOUS
election of that jurisdiction. Nothing about the target result enters the
selection -- which matters, because the Greens finding retracted earlier today
died of exactly that.

"Retained" is `mean(now %) / mean(prev %)`, a ratio of means rather than a mean
of ratios, so a seat with a tiny denominator cannot dominate.

| case | n | prev % | now % | retained |
|---|--:|--:|--:|--:|
| sitting member **recontests** | 288 | 48.5 | 49.2 | **1.01** |
| sitting member **departs** | 305 | 46.7 | 17.8 | **0.38** |
| non-winner recontests | 50 | 22.0 | 21.4 | 0.97 |
| non-winner departs | 380 | 22.2 | 12.7 | 0.57 |

**A sitting non-major who stands again keeps essentially all of their vote. One
who departs keeps a bit over a third.** A 2.6x split on 593 winner-cases.

`screened_slopes()` gives a screen-permitted newcomer **slope 1.0** on the
class's whole seat base -- an assumption of full retention. On the 305
departure cases that is wrong by a factor of two and a half.

## Two bugs found while building this, recorded because both were silent

**1. `surname` is empty for three whole jurisdictions.** `output/candidacies.csv`
populates it for `fed` (8,529 rows) and `wa` (2,842) and leaves it blank for
every `nsw` (1,670), `qld` (1,575) and `vic` (2,664) row, plus 628 of 892 `sa`.
Matching a candidate across elections on that column silently makes
`same_person` FALSE everywhere it is blank, which filed every returning member
in NSW, Queensland and Victoria as departed. The `name` column carries it
("KNUTH, Shane"), so it is derivable -- 18,172 of 18,172 rows.

The first run of this analysis reported retention 0.31 for departures and 0.93
for returners on that contaminated split.

**2. A prior-election key mapped to itself.** Recovering the cases where a class
fielded nobody at the target election used
`els[, .(prev = election, election)]`, which sets both columns from the same
field, so those rows were labelled with the PRIOR election and joined to the
prior year's own result. The symptom was visible in the output and is what
caught it: seats printing `prev 43.6` and `actual 43.6`, identical, for Hill,
Traeger, Clark and Lake Macquarie -- all seats a sitting member had plainly
held and retained.

Neither bug threw. Both produced a plausible table.

## What this does NOT establish

- **That rule 1 as written is the right fix.** It decays the base; Wentworth
  shows the departure case also needs a new candidate to be able to rise, and
  the two have to work together.
- **That 0.38 is the number to use.** The spread across departure cases is
  wide, and `CLAUDE.md`'s shrinkage rule applies -- a single pooled retention
  will under-separate seats where an independent tradition persists from those
  where the vote simply goes home. That said, the two groups here are separated
  1.01 against 0.38 on ~300 cases each, which is not the thin-data situation
  the shrinkage caveat was written for.
- **The effect on seat log loss.** Nothing has been run. The last time this was
  measured the pooled federal result was a wash (+0.003, within one SE), and
  that was with rule 1 trading New England for Wentworth.
- **Victoria 2026.** Three of group E's four seats are Victorian (Shepparton,
  Mildura, Morwell), and Victoria has independents holding seats now, so this
  is live for the target -- but no Victorian number is computed here.

## What follows

Re-run the rule-1 arm against this corpus rather than against two seats, with a
retention fitted leave-one-election-out rather than assumed, and paired with
whatever lets a new candidate rise so Wentworth is not traded away again. That
needs its own pre-registration.
