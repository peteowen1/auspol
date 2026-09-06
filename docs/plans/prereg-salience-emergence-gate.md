# Pre-registration: salience, gated to candidates with no prior vote

Written 2026-08-27, **before any test is run against `output/salience-v5.csv`.**
The corpus was fetched first and its coverage checked (758 rows, 692 keywords on
one scale, 0 unreached, all six fed2022 emergences present), but no model has
been fitted to it and no criterion below was chosen with a result in view.

## What this supersedes

`prereg-nonmajor-vote-regression.md` applied salience to **every** non-major
candidate and was refused: fed2025 winners RMSE 2.99 for prior vote alone
against 8.55 with salience added. The diagnosis, in
`docs/reviews/salience-scale-blocker-2026-08-26.md`, was that fed2025 contains
**zero emergences** — all 13 non-major winners had a prior party vote of 15% or
more — so salience had nothing to detect and every point it moved was noise.

Pete's proposal, made three times before it was acted on: **salience is for
emerging candidates, so gate it to them.**

## The gate

A candidate is **gated in** when their own party's share in that seat at the
previous election was **below 15%**. Outside the gate the model is unchanged.

- **15% is fixed here, in advance.** It is the same threshold used to define
  "emergence" throughout the preceding reviews, chosen before this corpus
  existed. It is not tuned in this document and must not be tuned later.
- **The gate keys on prior VOTE, not party class.** The two worst
  over-predictions under the previous design were Katter (OTH_RIGHT, prior 41.7,
  predicted 55.2) and Bandt (GRN, prior 49.6, predicted 66.2). A
  "sitting independent" rule misses both.
- **Leak-free**: the previous election's result was published years earlier.

## The model

For gated rows only, fitted on fed2022:

```
pcv ~ base + log1p(max(jump, 0))
```

where `base` is the projection the model already makes for that candidate.
Ungated rows keep `base` untouched. One extra parameter, fitted on all 332
gated fed2022 rows rather than on the 6 emergences alone.

## Criteria

### C1 — PRIMARY, and the one the previous design failed

**fed2025, all 390 rows. Out-of-sample: the model is fitted on fed2022 only.**

fed2025 has **zero emergences**, so a correct gate should be nearly silent
there. RMSE against the ungated base must not worsen by more than **0.30
points**.

Sized: the clustered SE of an RMSE difference over ~150 seats was measured at
**0.080** on this data, so 0.30 is **3.75 SE**. The previous design failed this
by +5.56 on winners, which is 70 SE. A gate that cannot pass a do-no-harm test
on an election with nothing to detect is not worth measuring further.

### C2 — precision

Across both test elections, the gate may fire — `jump` above the fitted model's
median gated value — on **no more than 3 non-emergent candidates for every true
emergence**. This exists because a rule that fires on everyone will pass C1 by
being weak and pass C3 by luck.

### C3 — the positive test, and it needs data not yet fetched

**fed2010, 2013, 2016 and 2019: 8 emergences over 4 elections.** Mean absolute
error on those 8 rows must improve by at least **6.9 points**.

Sized: sd of base error on emergences is 4.9; clustered on 4 elections the SE of
the mean is 2.47, so the MDE at 80% power is 2.80 × 2.47 = **6.9**. Any smaller
improvement is not detectable with 4 clusters and must not be claimed.

**This is why the previous design was never run**: its in-sample upper bound was
4.8 points, below the 6.9 floor. If the gated model's fed2022 leave-one-out gain
is also below 6.9, **C3 is unrunnable and must be reported as such rather than
attempted.**

### Reported but NOT decisive

fed2022 leave-one-out. It is the fitting election; it cannot also be the test.

## Refusal — what disqualifies a winner

- **If the 15% threshold is changed after seeing any result.** The threshold is
  the whole hypothesis. Moving it converts this into a search.
- **If any candidate outside the gate moves at all.** The gate is a hard switch;
  a non-zero change for a sitting member means it has leaked.
- **If fed2025's 13 non-major winners move by more than 0.5 points in aggregate.**
  They are all ungated, so the correct answer is exactly zero, and this catches
  an implementation error the RMSE would absorb.
- **If C1 passes only because the fitted salience coefficient is near zero.**
  That is the model declining to act, not a gate working. Report the coefficient
  and its SE alongside C1.
- **If precision (C2) is bought by a threshold so high the gate fires on fewer
  than 4 of fed2022's 6 emergences.** Recall below two thirds is not a detector.

## What the criteria cannot see

- **Every salience figure is a single Trends pull.** No replicates.
- **Nothing here tests a state election, and Victoria is the live target**, 28
  November 2026. Victorian candidate names for 2026 are not yet nominated.
- **fed2010–2019 cannot share a window with fed2022–2025.** Google switches to
  monthly buckets above roughly five years, which destroys an 8-week campaign
  measurement, so the earlier elections need their own window and the two are
  not directly comparable. Chaining them in TIME on candidates present in both
  windows is the intended fix and is itself untested. **C3 cannot be run until
  that works**, and if the chain proves unreliable C3 must be abandoned rather
  than run on incomparable scales — which is exactly the fault that killed the
  previous design.
- **The gate excludes Nicolette Boele** (prior 20.9%, won Bradfield on 27.0%),
  the one genuine near-emergence in fed2025. A candidate emerging from a
  moderate base is invisible to a hard 15% cut. This is a known cost of fixing
  the threshold in advance and is preferred to tuning it.
- **6 emergences fitted, 8 held out.** Small either way.

## Decision

Ship only if **C1 and C2 pass, and C3 either passes or is honestly reported as
unrunnable.** C3 unrunnable plus C1 and C2 passing licenses shipping the gate as
a **do-no-harm change with an unproven upside**, and that must be stated in the
commit rather than described as a measured improvement.
