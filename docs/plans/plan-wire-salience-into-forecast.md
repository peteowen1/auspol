# Plan: wire the salience signal into the published forecast

Written 2026-08-25. **A build plan, not an experiment** — the measurement is
already done and passed. This says what to build, when it can run, and what
still needs pre-registering before anything reaches the published numbers.

Pete's steer: use **Google Trends salience** as the external signal rather than
betting odds.

## Where this stands

| | status |
|---|---|
| signal validated | **yes** — AUC **0.823** (2019, n=4), **0.854** (2022, n=10), **0.964** (2025, n=7) |
| fetcher built | `scripts/trends_fetch.R`, with the abort-on-partial-sample guard |
| gate built | `scripts/gate_independent_salience.R`, criterion fixed before any query |
| geography question settled | national vs state tied (0.854 vs 0.846); national is fine |
| responses cached | `external/reference/trends/`, one file per candidacy |
| **used by the forecast** | **NO — `fit_seats_full.R` contains no reference to it** |

**The signal is confirmed, the plumbing exists, and nothing connects them.**
That is the whole gap.

## The hard constraint: we do not know the candidates yet

The signal is **candidate-level** — it needs a name to search. Victorian
nominations close **12 noon, Monday 9 November 2026**. The election is
**28 November**. So the signal cannot be computed for Victoria until **19 days
before polling day**.

That is not a reason to defer the work. It is a reason to have everything built
and tested **before** 9 November so that the run is mechanical on the day. The
same constraint already applies to candidate-count weighting, which
`docs/NEXT-STEPS.md` records as "revisit after nominations close".

## What the signal actually is

Per `gate_independent_salience.R`: the **ratio** of the challenger's search
interest to the sitting member's, within a single paired query. The pairing is
essential — Google Trends normalises 0–100 *within* each query, so two
candidates from two different queries are not comparable. Getting that wrong
would not error; it would silently compare incomparable numbers.

It predicts a **breakout**, defined as **>= 20% of first preferences**.

## Build order

**1. A named-candidate list for Victoria 2026.** Nominations from the VEC on
9 November. `docs/NEXT-STEPS.md` already records the acquisition path: VEC's
site resolves, the 2022 HTML-table parser in `fetch_preferences_vic.R` is
reusable, and the pre-election nomination URL is not discoverable until it
exists. **Build and test the parser against the 2022 page now**, so 9 November
is a fetch and not a development day.

**2. AEC-legal-name to search-form mapping.** Already known to matter: fixing
"Kylea Tink" from "Kylea Jane Tink" lifted the 2022 AUC from 0.830 to 0.854.
The nomination list will carry legal names. This needs a deliberate step, not a
hope.

**3. Run the existing fetcher over the nominated independents.** No new code —
`trends_fetch.R` with its completeness guard, which aborts rather than compute
a statistic over a partial sample. That guard exists because a silent 9-of-22
sample once produced a plausible, wrong answer.

**4. Convert salience to a model input.** This is the only genuinely new
modelling, and it is the part that **must be pre-registered separately**.

## What the pre-registration will have to settle

Not decided here, deliberately:

- **What the signal adjusts.** Options: `IND`'s projected first-preference
  share in that seat, or its win probability post-simulation. The first is
  principled and flows through the count; the second is a post-hoc nudge of the
  kind `ANCHOR-MODEL.md` criticises in AE Forecasts' use of betting odds.
- **The functional form and its cap.** An AUC of 0.85 is a good classifier and
  a *bad* basis for an unbounded adjustment. Whatever the form, it needs a
  ceiling.
- **What happens to seats with no nominated independent.** These should be
  zeroed regardless — that fix is already written and gated in
  `backtest_candidate_fed.R` and would apply here for free.
- **How it is validated before publishing.** There is **no Victorian
  out-of-sample test available**: Victoria has zero independent-held seats, and
  the signal was fitted on federal candidacies. Any adjustment ships on
  federal evidence applied to a state election, and the plan must say so
  plainly rather than imply a validation that does not exist.

## The honest limitation, restated

**The signal does not rescue the regional cases.** Priestly (Nicholls, 23.5%),
Boele and Heise all read near zero at both national and state geography —
tested completely, 22 of 22 candidates. It works for teal-type urban
candidacies and does not work for regional independents.

So this improves a class of seat Victoria may not even have. It is worth
building because it is the only external signal Pete has approved and the
infrastructure is already paid for — **not** because it is expected to move the
Victorian forecast much.

## Timeline

| when | what |
|---|---|
| now | build and test the VEC nomination parser against the 2022 page |
| now | write the pre-registration for step 4 |
| **9 Nov 2026** | fetch nominations, map names, run the fetcher |
| ~10–12 Nov | apply the pre-registered adjustment, re-run the forecast |
| 28 Nov 2026 | election |

**Nineteen days of slack.** The parser and the pre-registration are the two
things that must not be left until November.
