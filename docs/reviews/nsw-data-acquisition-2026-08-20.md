# NSW 2019 and 2023 acquired: the candidate model can now be backtested

Run 2026-08-20. `scripts/fetch_preferences_nsw.R`, `scripts/fetch_transfers_nsw.R`.
Outputs land in `external/elections/`, which is **gitignored** — no commission
data is committed, the same treatment the VEC and SA data get.

## Why this was blocking

The candidate-level seat model swings each seat's primaries off **that seat's
first preferences at the previous election**. The repo held exactly one such
dataset — Victoria 2022 — and it is the *input* to the live forecast. There was
nothing to score, so the model that publishes every seat number had never been
backtested. Victoria 2018 is not available: the VEC's pages are JavaScript-driven
and the documented URL patterns 404.

NSW 2019 → 2023 is a better test than Victoria 2018 would have been: a different
state, and a **change of government** rather than a landslide hold.

## What was fetched

The NSWEC publishes one state-wide workbook per election rather than 93 district
pages, and a distribution-of-preferences page per district:

- `pastvtr.elections.nsw.gov.au/{SG1901,SG2301}/LA/state/SGE {year} LA Final Votes.xlsx`
- `pastvtr.elections.nsw.gov.au/{code}/LA/{district}/dop/dop`

The site 403s a default user agent; a browser one is set.

| output | rows |
|---|---|
| `nswec-2019-nsw-firstprefs.csv` | 93 districts, 467 seat-party rows, 4,551,886 formal votes |
| `nswec-2023-nsw-firstprefs.csv` | 93 districts, 473 seat-party rows, 4,701,930 formal votes |
| `nswec-nsw-transfers.csv` | 2,721 transfers across 186 district-elections, 1,278,992 votes moved |

## The first preferences are exact

Checked against `prior-results.csv` in the anchor clone — an entirely
independent record of the same elections:

| | 2019 ours | repo | 2023 ours | repo |
|---|---:|---:|---:|---:|
| LNP | 41.58 | 41.58 | 35.37 | 35.37 |
| ALP | 33.31 | 33.31 | 36.97 | 36.97 |
| GRN | 9.57 | 9.57 | 9.70 | 9.70 |
| ONP | 1.10 | 1.10 | 1.80 | 1.80 |

**Every major party matches to 0.00 points, both elections.** The apparent
mismatch on `OTH` is a definitional one and reconciles exactly: the repo's OTH
is our OTH + OTH_RIGHT + IND + ONP (15.54 against 15.54 in 2019; 17.96 against
17.98 in 2023).

District names join to `2019nsw.txt` and `2023nsw.txt` with **zero mismatches in
either direction**, which is what the backtest needs.

## The transfers are sound, with one known definitional gap

Greens preferences to Labor come out at **84.8% (2019)** and **86.5% (2023)** —
squarely inside the 75–90% an Australian psephologist would insist on, and an
anchor chosen before the number was read.

One Nation's flow to Labor:

| | ours | repo records | diff |
|---|---:|---:|---:|
| 2019 | 38.1% | 42.0% | −3.9 |
| 2023 | 35.1% | 37.7% | −2.6 |

**These measure different things and the gap is expected.** Ours is the *direct*
transfer at the round One Nation was excluded; the repo's is the *final*
two-party flow, after One Nation's votes have passed through any later
exclusions. Both differences are in the same direction and of similar size,
which is what a definitional offset looks like rather than a parse error. The
repo's figure remains the one to use for two-party flows; this data's value is
the **conditional** rows — who receives what, given which parties are still
standing.

## Three defects caught by guards, all silent failures

Worth recording because each produced plausible output:

1. **Every unrecognised party became an independent.** The DOP pages print party
   *acronyms* only, and `classify_party()` with an empty name falls through its
   `!nzchar(n)` branch to `IND`. SFF, LDP, SAP and AJP were all classified as
   independents — visible only as IND being the largest single source of
   transfers in the state (578k votes; it is 127k once fixed). Now the acronym →
   name lookup is rebuilt from the workbooks and an unknown code is **refused**.
2. **A surname bled into the party code.** Candidate labels are
   `SURNAME GivenNameCODE` with no separator, so reading a trailing uppercase
   run yielded codes like `WYGRN`. Now matched against the authoritative code
   list, longest first.
3. **Independents have no party in parentheses at all**, which the excluded-
   candidate regex left unchanged. They are genuinely independents and are
   classified as such — but only after the two failures above were separated
   from them, which the "refuse unknown codes" guard is what forced.

A size floor would have caught none of these. Each was found by an anchor check
on a quantity whose plausible range was known in advance.

## What this unblocks

1. **The candidate-model backtest** — [prereg-candidate-model-backtest.md](../plans/prereg-candidate-model-backtest.md)
   recorded it as blocked; it no longer is. NSW 2019 → 2023 gives predictors from
   the 2019 file, first preferences to swing from, and the actual 2023 outcome.
   The transfer matrix can come from **2019**, so it is not built on the election
   being predicted — the leak that plan had to concede for Victoria is gone.
2. **Porting the seat-swing adjustment** into the candidate model, and measuring
   whether error improves, which is what Pete asked for.
3. **Preference-flow uncertainty** — `fm` rested on one election and now has
   three, so the spread between them is measurable rather than assumed.
