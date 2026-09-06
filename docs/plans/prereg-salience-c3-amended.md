# Amendment: C3 tests three state/federal elections in one window

2026-08-27. Amends **C3 only** of `prereg-salience-emergence-gate.md`. That
document is left unedited; this is a visible addition, per the rule that an
amendment must be additive and must be checked for whether it favours the answer
already seen.

C1 (passed), C2 (failed) and every refusal clause there stand unchanged.

## What changes, and why it is not a rescue

The original C3 named fed2010, 2013, 2016 and 2019 — 8 emergences — and required
chaining three Trends windows, which the pre-registration itself flagged as
untested with instructions to **abandon C3 rather than run it on incomparable
scales**.

Chaining turns out to be avoidable. A single window, **2021-06-01 to
2026-06-01**, returns 262 weekly buckets spanning **fed2022, nsw2023, fed2025
and sa2026** at one normalisation. Verified before this was written: the window
is weekly, not monthly, and all four polling days fall inside it.

| | original C3 | amended C3 |
|---|---|---|
| test elections | fed2010/13/16/19 | nsw2023, fed2025, sa2026 |
| held-out emergences | 8 | **9** (nsw2023 5, sa2026 4) |
| election clusters | 4 | **2** |
| comparability | 3 chained windows, untested | one window, exact |
| abandon risk | chain drift | none |

**Does this favour the answer already seen? Two ways it is HARDER, one easier.**

- Harder: the model is fitted on **federal** candidates and now tested on **state**
  ones. Cross-jurisdiction transfer is a hurdle the original test did not
  impose — state candidates have lower search volume and less national coverage.
- Harder: sa2026's four One Nation winners are the seats that began this whole
  investigation, and One Nation is a *party* emergence rather than a personal
  one. A name-search signal has no obvious reason to detect it.
- Easier: **2 clusters instead of 4.** This is the real cost and it is stated
  plainly below.

## Criterion, resized

Mean absolute error on the 9 held-out emergences must improve by at least
**9.7 points**.

Sized: sd of base error on emergences is 4.9 (measured on fed2022). Clustered on
**2 elections**, SE of the mean is 4.9/√2 = 3.46, so the MDE at 80% power is
2.80 × 3.46 = **9.7**. The observed fed2022 effect was 18.29 points, so the test
can resolve — but only because the effect is large. **Two clusters is weak and
no smaller effect could be claimed from it.**

The do-no-harm half of C1 extends to the new elections: RMSE over all non-major
rows in nsw2023 and sa2026 must not worsen by more than 0.30 points.

## Dry-run: what the criteria must say about cases already known

Required by `CLAUDE.md` after C2 shipped a criterion that scored win/lose for a
vote-share model. Three cases, verdicts stated before running:

| case | gated? | criterion must say |
|---|---|---|
| **Sarah Game**, SA One Nation, won 2026 from a low prior | yes | counted as an emergence; credit for raising her |
| **Alex Greenwich**, NSW independent, sitting, prior ~50% | **no** | untouched — any movement is a leak, and fails a refusal clause |
| a Greens candidate polling 2% with no search presence | yes | near-zero change; must not be counted as a "false firing" — the C2 error |

If the scoring code disagrees with any row of that table, the code is wrong, not
the case.

## Refusal — additions to those already standing

- **If it works on nsw2023 but not sa2026, or vice versa.** With 2 clusters, one
  election carrying the result is indistinguishable from chance.
- **If the One Nation emergences drive the whole gain.** They are a party
  emergence, not a personal one, and a personal-name signal detecting them would
  more likely indicate leakage than skill. Report the two subsets separately.
- **If any ungated candidate moves at all** in the new elections.

## What this still cannot see

- **Two clusters.** Named twice because it is the weakest part.
- Single Trends pull; no replicates.
- **vic2022 has no winners file**, so Victoria — the live target — contributes
  nothing to this test.
- State candidate names come from a different builder path than federal ones,
  so a name-matching failure would present as "no salience" rather than as an
  error. Coverage must be reported per election before any result is read.
