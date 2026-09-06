# Google Trends: method notes

Written 2026-08-26 after four separate measurement errors produced null results
that were then interpreted as findings. Read this before touching
`scripts/trends_fetch.R` or anything that consumes its output.

## What the literature says, and what it cost us to ignore

**1. Zero does not mean zero. It means insufficient data.** Google publishes
only above an undisclosed volume threshold, and on the 0–100 scale a 0 marks
insufficient data rather than absence of searching. Historical zeros are
documented sampling artefacts when the sample falls below reliability
thresholds.

*What it cost:* every 2010 query returned 0.000 and was read as "no salience".
Both groups had a median of 0, so the AUC was substantially computed over
missingness. **Treat 0 as `NA`, not as a low value.**

**2. Trends returns a SAMPLE, so a single pull is not authoritative.** The
standard methodological failure is trusting one query as if it were the whole
search corpus. Best practice is replicate queries on different days, aggregated.
The number of replicates needed is unsettled in the literature.

*What it cost:* every number collected so far is a single pull.

**3. Long windows are heavily normalised and lose resolution; short windows hit
sampling thresholds.** Both ends of the trade-off are documented.

*What it cost:* a 7-day window was chosen for leakage safety and sits near the
threshold, which is where the zeros cluster.

**4. Topics resolve entities across spellings and languages; search terms are
literal.** This is the literature's recommendation.

**WE DELIBERATELY DO NOT USE TOPICS.** Pete's call, and the leakage found on
2026-08-26 supports it: every candidate entity resolved through Trends'
autocomplete is typed *"Member of the Australian House of Representatives"* — a
status conferred by **winning**. Selecting a topic by that type selects on the
outcome. Worse, the *existence* of a Knowledge Graph entity is itself partly a
consequence of becoming notable — Kylea Tink resolves to three entities, Dai Le
to none, and Tink won. A backtest keyed on entity existence would score
beautifully and be measuring the result. For the live Victorian forecast the
problem inverts: an unelected candidate may have no entity at all on
9 November, which is precisely when the signal is needed.

So: **literal strings, normalised.** The cost is real — Max Chandler-Mather
returns 0.000 as a string in every geo and window tried, and 15 as a topic — and
it is accepted rather than hidden.

## Query construction rules

- **Search form, not legal form.** The AEC records "Kylea Jane Tink"; people
  search "Kylea Tink". The legal form returned **0.000**; the search form
  returned **1.750** against the same incumbent. That one fix turned the
  corpus's most awkward case into its strongest signal.
- **Drop middle names** — use the first given name plus the surname, taken from
  the `given`/`surname` FIELDS, never by stripping the middle word, which turns
  "Dominic WY KANAK" into "Dominic Kanak".
- **Strip hyphens, apostrophes, titles and post-nominals.** Measured: hyphenated
  and unhyphenated forms of Chandler-Mather both return 0.000, so the hyphen was
  not the cause there — but normalising costs nothing and removes a variable.
- **State `geo`, not national.** A local candidate's volume divided by the whole
  country's traffic falls under the threshold. Effect measured as second-order
  next to the name fix (Steggall 0.290 → 0.347), but free.
- **The window must end the day BEFORE polling day.** Non-negotiable.

## Granularity: the API does not behave like the UI

The browser shows weekly buckets for a February-to-May span. `gtrendsR` returns
**109 daily points** for the same span. So a longer window does **not** buy
weekly data through the API.

Aggregate to weekly **after** fetching instead. Same noise reduction, and the
bucketing is ours rather than an undocumented Google threshold.

## The anchor

Pair every candidate against the **re-contesting incumbent** — the person they
are actually running against, which is the comparison a voter makes.

- A candidate anchored on **themselves** is a self-comparison and returns 1.000
  by construction. That happens when the sitting member IS the non-major
  (Wilkie 2013, Katter 2013). Exclude them: that is incumbency, not emergence.
- Where the incumbent is not re-contesting there is no such person. Fall back to
  the prime minister of the day and **flag it** — never pool the two anchor
  types, because the fallback fires on retirements, which is also when these
  seats fall.
- A national-figure anchor distorts badly: Steggall against Tony Abbott, a
  former PM, scores 0.60 and reads as a quiet challenger.

## Standing warning

Four interpretations were built on this data before the measurement was sound:
"the signal doesn't transfer to the states" (AUC 0.560), "Greens wins are
party-driven not candidate-driven", "Tink won with no signal", and "the hyphen
is the problem". **All four were measurement artefacts.** Validate against a
hand-checked case before interpreting anything from this pipeline.
