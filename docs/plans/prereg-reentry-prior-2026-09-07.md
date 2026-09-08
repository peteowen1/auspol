# Pre-registration: a prior for a party that did not contest the seat last time

Written and committed **before** the arm was run, 2026-09-07.

## The defect

When a party contests a seat at election `t` but did not contest it at `t-1`,
the model has no prior share for them. It swings zero forward and they start at
approximately zero.

**Kimberley 2001 is the case.** Labor did not stand in Kimberley in 1996 — the
seat was Bridge (independent) 33.8%, Martin (independent) 29.3%, Liberal 28.1%.
Carol Martin then won it for Labor with **42.2%**. The model projected Labor at
**2.1%** and gave the actual winner a probability of 0.000000. It is one of the
five worst-scored seats in the entire 2,050-seat corpus.

## What the data says the prior should be

Measured over all 22 pairs, comparing a re-entering party's realised vote to its
own statewide share at the same election:

| party | re-entry rows | mean vote | statewide | **ratio** |
|---|--:|--:|--:|--:|
| ALP / LNP | 8 | 34.1 | 40.6 | **0.84** |
| GRN | 29 | 6.0 | 7.6 | **0.79** |
| OTH_RIGHT | 232 | 3.8 | 4.6 | **0.84** |
| IND | 415 | 6.0 | 4.4 | **1.36** |
| ONP | 342 | 6.4 | 5.2 | **1.24** |

**1,026 seat-party rows** across the corpus currently get approximately zero
where the evidence says 0.8 to 1.4 times statewide.

Two facts worth stating separately. The majors and the Greens come in BELOW
their statewide share, which is what you would expect of a party contesting
somewhere it has been absent. Independents and One Nation come in ABOVE it —
they do not choose seats at random, they appear where they have a reason to,
and treating a fresh independent as a zero is wrong in the opposite direction.

## The rule

For a (seat, class) with no prior-election vote, where a candidate of that class
IS standing at the target election, set the base share to
`ratio_class * projected_statewide_share`.

`ratio_class` is fitted **leave-one-election-out**, like everything else here.

**This is leakage-free and the model already relies on the same fact.** Whether
a class is standing comes from the nomination list, which closes before polling
day, and `backtest_candidate_*.R` already reads exactly that to ZERO an
independent column in seats where nobody nominated. This is the same
information used in the opposite direction: the existing rule removes a party
that is not standing, and this one gives a base to a party that is.

## The criterion

Primary: **PB3f, pooled seat log loss excluding floor seats** (currently 0.3056
over 2,045 seat-elections), and the **floor count** (currently 5). Both are
first-class results, because this change exists to move a seat off the floor.

Co-primary: **pooled seat-share RMSE.** This is a change to the projected VOTE,
so a change that improves probabilities while degrading the point estimate is
not a win. Log loss alone cannot see that.

Guards: per-jurisdiction log loss (all six), and accuracy.

**Decision rule.** Adopt if PB3f improves or is unchanged within 0.001 while the
floor count falls, AND pooled RMSE does not worsen by more than 0.05, AND no
jurisdiction's log loss worsens by more than 0.01.

### Dry-run of the criterion on known cases

1. **Kimberley 2001** (ALP re-entry, actual 42.2%, projected 2.1%). The rule
   gives 0.84 × 37.2 statewide ≈ **31%**. Still nine points short, and
   twenty-nine points closer. The criterion should see this through the floor
   count. If Kimberley does not move, the arm has not fired and that is a bug
   to find before reading any pooled number.
2. **A minor party contesting a hopeless seat for the first time.** The rule
   gives them 0.84 × a small statewide number, so a point or two — not zero,
   not much. If such seats move a lot, the ratio is being applied to the wrong
   base.
3. **Pilbara 2001.** Should be UNCHANGED: every class there contested in 1996,
   so no cell qualifies. A move in Pilbara means the rule is firing where it
   should not.

## Refusal section — what disqualifies an apparent win

1. **Losers inflated.** 1,026 rows get a non-zero prior and most of those
   candidates poll badly. Report the count of re-entry cells given a projected
   share above 15% that finished below 5%. If the RMSE gain is smaller than the
   log-loss gain, the change is buying probability at the cost of the point
   estimate and should be refused on the co-primary.
2. **A gain confined to Western Australia.** WA carries a large share of the
   re-entry rows because it redistributes hard, and its seat set is the least
   comparable. Require the sign to hold in at least three jurisdictions.
3. **The independent ratio driven by a handful of cases.** IND's 1.36 is the
   largest departure from 1.0 and independents are the class the model is worst
   at. Report the ratio's spread and its value with the top five cases removed;
   if it moves below 1.0 the estimate is a few large independents, not a rule.

## What the criterion cannot see

- **Redistributions**, which are the other half of this problem and are NOT
  addressed here. Kalgoorlie 2008 stays broken: Bowler was the sitting member
  for Eyre, redistributed, and a rule keyed on the same seat name cannot reach
  him. That needs boundary correspondences and notional prior votes, which is a
  project rather than a patch. Scoped separately.
- Whether the ratio should depend on WHY the party was absent — a deliberate
  abandonment of a hopeless seat is not the same as a redistribution artefact,
  and this pools them.
