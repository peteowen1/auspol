# The seat model and the candidate corpus disagree about who is an independent

2026-09-05. Found while fitting a national IND-level model: the predictor
(salience, keyed to `output/candidacies.csv`) and the target (national IND
level, read from `aec-fed-firstprefs.csv`) were measuring **different
populations**. Pete asked for a consistency sweep; this is it.

## The disagreement

National first-preference share by class, same elections, two sources:

| year | IND (candidacies.csv) | IND (aec-fed-firstprefs.csv) | diff |
|---|--:|--:|--:|
| 2016 | 4.66 | 2.81 | **+1.85** |
| 2019 | 3.70 | 3.37 | +0.33 |
| 2022 | 5.54 | 5.30 | +0.25 |
| 2025 | 7.52 | 7.28 | +0.24 |

**The bloc total is not in dispute.** Every IND surplus is exactly offset by
an OTH deficit (2016: IND +1.85, OTH −1.85). No votes are lost; they are
filed under different classes.

## It is NOT a classify_party() bug

The obvious suspect is the classifier being called differently in the two
pipelines. It is not:

```
Nick Xenophon Team  ab=XEN  -> name-only: IND   name+ab: IND
Centre Alliance     ab=XEN  -> name-only: IND   name+ab: IND
```

Both call sites pass the full party NAME
(`fetch_preferences_fed.R:78`, `build_candidacies.R`), and both get IND.

## It is a STALE ARTIFACT

Re-classifying the raw AEC 2016 download with today's `classify_party()`:

| source | IND 2016 |
|---|--:|
| raw AEC, classified fresh today | **4.45** |
| `output/candidacies.csv` | 4.66 |
| `external/elections/aec-fed-firstprefs.csv` (cached, what the seat model reads) | **2.81** |

The cached extract was written before `classify_party()` learned
"Nick Xenophon Team", and `fetch_preferences_fed.R`'s `grab()` skips any file
that already exists, so it has never been rebuilt. The seat model has been
reading a party classification that the rest of the repo abandoned.

This is `CLAUDE.md`'s release-artifact hazard in reverse: there, a data
vintage moved ahead of the code; here, the code moved ahead of the data
vintage and nothing re-derived it.

## One genuine landmine in classify_party() itself

Separately worth recording:

```
"IND"  name-only: OTH     name+ab: IND
```

A bare `"IND"` string classifies as **OTH** when passed as a name alone, and
as **IND** when the abbreviation is also supplied. Both call conventions are
in use across `build_candidacies.R` (`classify_party(party_raw, NULL)` in
four places, `(party_raw, party_ab)` in two, `(party_raw, party_raw)` in one).
No current caller passes a bare `"IND"` as the name, so nothing is wrong
today — but any source that abbreviates independents in its name field would
be silently misfiled.

## What it cost, concretely

Fitting `ind_nat ~ n_seats + sum_jump` on the candidacies basis and applying
it to the FP basis predicted **5.62%** for fed2025. Fitting on candidacies
and applying the predicted-to-pinned RATIO (basis-invariant) gives **6.37%**
against an actual 7.28-7.52%. The mismatch alone was worth about 0.75 points
of national IND level.

## What is NOT yet decided

**Regenerating `aec-fed-firstprefs.csv` is not done here.** It would change
the seat model's class levels for every federal election (2016 IND 2.81 ->
~4.45, with OTH falling correspondingly), which moves every backtest number
this repo has published. That is a deliberate act needing its own validation,
not a side effect of a consistency sweep.

The raw AEC downloads are already cached, so a rebuild is a re-classification
rather than a re-fetch — cheap to do, expensive to verify.
