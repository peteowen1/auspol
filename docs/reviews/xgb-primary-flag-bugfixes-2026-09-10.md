# Two flag bugs from the followup review — one fixed, one is not a bug — 2026-09-10

Continuation of `docs/reviews/xgb-primary-challenger-followup-2026-09-10.md`,
which named two population-building defects blocking a fair retest of the
deterministic-override blend. Both investigated; only one was real. **No
`backtest_candidate_*.R` file touched**, per the explicit boundary (a sibling
task is wiring `sa2018` into `backtest_candidate_sa.R` concurrently — see
"SA2026 measurement blocked" below, which is that collision actually
happening). Fixes are scoped to `scripts/fit_xgb_primary_v4.R` only, matching
where the flag is actually built. `published_flags.R` untouched
(`AUSPOL_XGB_PRIMARY_LIVE` stays `"0"`).

## Bug 1 (surge-recipient misattribution): investigated, NOT a bug — did not fix it

The followup review's own framing was wrong. `R/party_surge.R`'s docstring
(read in full this session, not just the function signature) uses **SA2026
One Nation as its own motivating example** for why `governed_population()`
must exclude a class whose *statewide* vote is itself surging: "A candidate
of such a class with no prior seat vote is riding a party surge, not
emerging personally, and the salience screen makes no claim about them...
asking [a name-search signal] to explain [a party emergence] is what made
South Australia look like a failure of the signal." `surging_parties("sa",
2022, 2026)` correctly includes ONP (swing 19.9, threshold 5). Because
`surge_hazard_for()`'s target population is gated to `governed==TRUE`
(`R/salience_surge.R`, via `surge_training_population()`), ONP is
structurally excluded from ever appearing in `seat_party_hazard` /
`seat_recipient` for its own election — and that is correct, deliberate,
already-reasoned behaviour, not a defect. `seat_recipient` also feeds the
**live published forecast** (`fit_seats_full.R:692`, plus all six backtest
harnesses via `AUSPOL_SURGE_RECIPIENT`, default on) through
`simulate_seat_contests(surge_party = ...)`. Mutating it to also fire on
surging classes would risk reintroducing exactly the failure this code was
already fixed once to avoid (the docstring's own history: "the simulator
paid the Greens in every teal seat" was an earlier version of this same
bug-in-reverse). **`R/salience_surge.R` and `R/party_surge.R` are unchanged.**

**What actually serves Pete's goal without touching the live mechanism**:
`surging_parties()` is already exported for exactly this. Added a `surging`
column to the flag-building code (`scripts/fit_xgb_primary_v4.R`), computed
directly per pair/region — a party-level-surge flag, independent of
`is_recipient`. For SA2026: `surging` covers 47 of 47 ONP rows (100%).

## Bug 2 (NA-default): real, fixed — and much bigger than it looked

`scripts/fit_xgb_primary_v4.R`'s SAL merge (`ALL[, permit := ifelse(is.na(permit), 0L, permit)]`)
defaulted an unmatched cell (no salience-corpus row at all for this
candidate/class) to `permit = 0`, i.e. "not flagged, safe for xgb." That
inverts `salience_screen()`'s own convention elsewhere in this codebase — no
claim about a candidate means `permit = TRUE` (protect), not `FALSE`. Fixed:
`NA -> 1L`.

**The scale was not what either of us expected.** This isn't a few edge-case
rows:

| | rows | % of 13,314 |
|---|--:|--:|
| `permit` OLD (NA -> 0) | 3,268 | 24.5% |
| `permit` FIXED (NA -> 1) | 11,366 | **85.4%** |
| `is_recipient` (unchanged) | 906 | 6.8% |
| `surging` (new) | 1,223 | 9.2% |
| **combined flag, OLD** (`permit_OLD \| is_recipient`) | 3,724 | 28.0% |
| **combined flag, FIXED** (`permit_FIXED \| is_recipient \| surging`) | 11,822 | **88.8%** |

85% of the xgb feature matrix has no matching row in the salience corpus at
all. That's a genuine, large-scale data-coverage fact about
`output/salience-v6.csv` (built for other purposes, not sized to cover every
candidate in this feature matrix), not something introduced by the fix — but
it means the "correct" default, applied literally, makes almost the whole
population "flagged." **SA2026 ONP goes from 19/47 to 47/47 protected**
(`permit_FIXED`; `surging` independently also gives 47/47). That part works
exactly as intended.

**vic2014 has zero surging classes** — `surging_parties("vic", 2010, 2014)`
returns `character(0)`. Its regression was never a party-surge case, so the
new `surging` flag does nothing there; only the NA-default fix touches it.

## Effect on the deterministic-override blend, measured via the real harnesses (5,000 sims, one seed)

**Victoria — all three pairs run** (`backtest_candidate_vic.R`, read-only):

| pair | shipped | xgb v1 (pure) | blend (OLD flag) | blend (FIXED flag) |
|---|--:|--:|--:|--:|
| vic2014 | 0.2798 | 0.3543 | 0.2902 | **0.2814** |
| vic2018 | 0.2670 | 0.2765 | 0.2899 | **0.2641** |
| vic2022 | 0.2474 | 0.2050 | 0.2199 | **0.2530** |

**vic2014, the named flagship regression, is nearly fully closed**: gap to
shipped shrinks from 0.0104 (old blend) to 0.0016 (fixed blend) — within
seed noise of shipped itself. **vic2018 flips to slightly better than
shipped** (0.2641 vs 0.2670). But **vic2022 gives back nearly all of xgb's
real gain and turns into a small net regression** (0.2530 vs shipped's
0.2474, where pure xgb had been 0.2050 — a genuine win). This is the direct
consequence of the flag now covering 88.8% of rows: the blend has moved
most of the way back toward "trust the shipped model almost everywhere,"
which fixes what was broken but also gives back most of what xgb was
contributing, including on the one pair (vic2022) where it was genuinely
better.

**SA2026 — measurement BLOCKED, not completed.** `scripts/backtest_candidate_sa.R`
is mid-edit by the sibling task wiring in `sa2018` (per Pete's own warning):
confirmed live, `TGT` is referenced at line 183 (`PARTY_COR <-
statewide_cor(TGT, ...)`, reachable because `AUSPOL_PARTY_COR` defaults to
`"shrunk"`) before it is ever assigned, at line 311 — a script that ran
cleanly earlier this same session now errors `object 'TGT' not found` on
every invocation. This is the exact collision Pete named, actually
happening, not hypothetical. **Did not touch the file.** Retried twice more
(15s apart) — still broken both times. Flag-level evidence is strong
(`permit_FIXED` and `surging` each independently give 47/47 SA2026 ONP rows
protected, against 19/47 before), so the harness-level result would very
likely show the SA2026 log-loss gap close the same way vic2014's did — but
that is an expectation, not a measurement, and this review does not claim
otherwise. **Needs a re-run once the sibling task's edit lands and the file
is stable again** — a 5-minute follow-up, not a new investigation.

## Where this leaves the blend

Not a clean answer. The fix genuinely closes the SA2026/vic2014 gap (vic2014
confirmed, SA2026 expected but unmeasured) — but at the cost of handing back
most of xgb's real benefit elsewhere (vic2022 now a net regression instead
of a win). An 88.8%-flagged blend is close to "mostly the shipped model with
an 11% xgb patch," which may or may not be what Pete wants — that's a
judgement call on the trade-off, not something this round of measurement
resolves on its own. The federal/NSW/QLD/WA numbers from the 22-pair table
(previous message) were built on the OLD, buggy flag and have **not** been
re-measured against the fixed one; if a ship decision gets close, that
re-run is the next thing to do, not an assumption to carry forward.

## Repo state as of this write-up

- `scripts/fit_xgb_primary_v4.R` modified (the two fixes above, both
  comments explaining why). Still uncommitted, still exploratory, never
  called by any harness or the published forecast.
- No other tracked file changed. `output/xgb-primary-oof-predictions.csv`
  restored to the plain v1 (pure xgb) content it held before this round of
  measurement — matches the state described in the previous two review docs.
  `output/xgb-primary-flags-fixed.csv` and
  `output/xgb-primary-oof-predictions-BLEND-FIXED.csv` are new, gitignored,
  on disk for a re-run without rebuilding.
- `published_flags.R`: unchanged from the earlier revert this session
  (`AUSPOL_XGB_PRIMARY_LIVE = "0"`).
