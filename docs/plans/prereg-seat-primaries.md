# Pre-registration: simulate every seat from primary votes

Written 2026-08-17, before any data is fetched or any code is changed.
Committed before any result.

## The question

`simulate_seats()` (`R/seats.R:145`) simulates only the 83 seats where both
`sIncumbent` and `sChallenger` are majors. The `classic` flag that decides this
(`R/seats.R:55-56`) is derived from **who contested the previous election**.

That was defensible when the third-party vote was small. It is not now: the
Victorian trend has One Nation on **20.9%** of the statewide first preference.
The current structure asserts, seat by seat, that One Nation cannot finish in
the top two anywhere — not as a finding, but as a consequence of reading 2022's
final-two pairs forward.

Pete's direction (2026-08-17): simulate each seat's **primary votes**, then
distribute preferences to a final two, then a winner. That is what AE Forecasts
and theswingison both do.

## What the current model would do if the five non-classic seats were simply
## included

It would fabricate four Labor gains, silently.

`fTppMargin` is **Labor's notional two-party margin in every seat**, including
seats where Labor is not in the final two (contract at `R/seats.R:22-26`).
Prahran's 11.1 is ALP-notional-TPP 61.1, not an LNP-vs-GRN margin. The win test
is `result > 50` on Labor two-party share (`R/seats.R:173`). So Brunswick
(34.1), Melbourne (25.0), Richmond (24.1) and Prahran (11.1) would all score as
safe ALP wins. Nothing would error.

This corrects `docs/reviews/who-contests-2026-08-16.md:69-71`, which claims
"their two-candidate margins are known". They are not in the anchor's data:
`sTcpChange` appears in `2022vic.txt` for 8 seats and **zero times** in
`2026vic.txt`.

## What scoping found (2026-08-17)

**The VEC publishes what is needed, per district, for 2022:**

- First preferences by candidate with party affiliation. Verified on Prahran:
  GRN 36.40, LIB 31.08, ALP 26.56, AJP 3.22, FFV 1.60, IND 1.14.
- Two-candidate-preferred with the actual final two. Prahran 2022: GRN 62.01
  vs LIB 37.99 — i.e. a real GRN margin of 12.01, a different quantity from the
  11.1 in `2026vic.txt`.
- Distribution of preferences.
- Booth-level ("Recheck results by voting centre").
- A per-district Excel download.

URL pattern:
`vec.vic.gov.au/results/state-election-results/2022-state-election-results/results-by-district/{district}-district-results`

**Format cost.** There is no bulk CSV and no open-data portal. The only
all-districts download on the 2022 index page is two-party-preferred
(`a8466a1794024583a2128ed431ca24f3.xlsx`), which is the quantity we already
have. Per-district first preferences require 88 page fetches or 88 Excel
downloads. The anchor solved this with Selenium against an iframe
(`analysis/fetch_election_data_vic.py`), which is fragile; the 2022 pages
render as plain HTML to a simple fetch, so scraping should be simpler than his
script implies. **To verify before building: whether the Excel download is
reachable by a stable URL pattern, which would remove the scrape entirely.**

**Licence: unresolved, and this is a gap rather than permission.** No copyright,
Creative Commons or terms-of-use statement appears on the results index, the
results-by-district page, or the district pages. `vec.vic.gov.au/copyright`
returns 404. Australian electoral results are ordinarily treated as public
record, but "no statement found" is not a licence. **Resolve before publishing
anything derived from it**, by the same standard already applied to the
anchor's poll data (`docs/NEXT-STEPS.md`, "Poll data licensing").

**Party mapping is clean.** VEC affiliations map to the five modelled parties
without ambiguity: Labor → ALP; Liberal and The Nationals → LNP; Australian
Greens → GRN; Pauline Hanson's One Nation → ONP; everything else and
independents → OTH.

## The blocker, and it is the whole point of the exercise

**One Nation polled 0.28% in Victoria in 2022 — 10,323 votes statewide.**

The forecast has them on 20.9% in 2026. That is not a swing applied to a
baseline; it is a party appearing where there was none. Confirming this is
structural, not a data-loading artifact: the string `ONP` appears **zero times**
in `2022vic.txt`, and `sRunningParties` there carries only five coarse
categories (`ALP,LNP,GRN,OTH,IND`, in just two combinations across 86 seats) —
so the anchor's own file cannot say where One Nation ran either.

So fetching 2022 per-seat first preferences does **not** on its own let us
simulate primaries. Every other party has a usable 2022 base. The one party
that motivates the change does not.

Per-seat ONP allocation therefore needs its own baseline, and choosing it is
the real modelling decision. Three candidates:

1. **Uniform** — every seat gets the statewide ONP share. This is the null. It
   is almost certainly wrong (the ONP vote is geographically structured, heavier
   in outer-suburban and regional seats), but it must be beaten, not assumed
   beaten.
2. **2022 minor-right proxy** — per-seat sum of One Nation, Family First,
   Liberal Democrats, DLP and comparable parties, normalised to the statewide
   ONP total. Cheap: it comes free with the same VEC fetch.
3. **Transposed federal ONP** — 2025 federal ONP first preferences by division,
   mapped onto state districts. Better geography, same voters, recent. Costs a
   division-to-district correspondence, which is the booth-level work already
   queued.

## The pre-registered test

**Victoria 2026 cannot test this** — there is no outcome yet. The test runs on
an analogue where ONP actually surged from near-zero, and one exists:
**South Australia**. SA 2026 delivered ONP 22.9% of the primary vote (already
recorded in `docs/NEXT-STEPS.md` as the source of the 36.15 observed flow),
against a negligible SA 2022 ONP vote. That is the Victorian situation, already
resolved.

**Criterion.** Mean absolute error of predicted per-seat ONP first preference
across all South Australian House of Assembly seats in 2026, with the
**statewide ONP total taken as known**. Taking the level as given is
deliberate: this tests *allocation across seats*, which is the open question,
and not the statewide trend, which the existing model already handles.

**Comparison.** The three baselines above, each fitted using only information
available before the SA 2026 election.

**Decision rule, fixed now:**

- Adopt the baseline with the lowest MAE.
- It must beat **uniform** by **at least 1.0 percentage point** of MAE. If no
  candidate clears that, adopt uniform and say so on the page — a structured
  allocation that cannot outperform a flat one is a decoration.
- If (2) and (3) are within 0.5 points of each other, adopt (2), because it is
  free and (3) costs a correspondence build.

**Second criterion, on the machinery rather than the ONP question.** Rebuild
2022 Victorian two-candidate-preferred results from 2022 first preferences plus
our estimated flows, per seat. Compare against the actual VEC two-candidate
figures. This measures how much error the primary-plus-preferences path
introduces relative to a directly measured margin — the thing that would
degrade the 83 seats the current model already handles well.

**Anchoring, to prevent that degradation.** Per-seat residual = (actual 2022
TCP) − (TCP reconstructed from 2022 primaries and estimated flows), carried
forward as a fixed per-seat offset. This makes 2022 reproduce exactly by
construction and cancels flow-estimation error in seats whose final two is
unchanged. Our flow estimator's backtested MAE is 4.815 points on the flow rate
(`scripts/backtest_flows.R`); without anchoring that error is injected into all
88 seats including safe ones, where `fTppMargin` was already the better
measurement.

**Acceptance for the change as a whole:** the anchored primary simulation must
reproduce the current seat distribution on the 83 classic seats to within
**1 seat on the median and 2 seats on each 90% bound**, while giving non-zero
probability to at least one non-major win. Failing the first half means the
rebuild lost information; failing the second means it did not do the one thing
it was built for.

## What this plan does not decide

- Whether per-seat swing is forecastable. It is not — seat type failed out of
  sample, region failed, region effects correlate 0.27 between elections. A
  uniform statewide primary swing plus a noise draw remains the correct seat
  model. This change is about **who is in the final two**, not about predicting
  seat-level deviation.
- Whether to acquire booth-level data. Baseline (3) would need it; baselines
  (1) and (2) would not. The test decides.

## Unrelated defect found while scoping

`scripts/fit_seats.R:173-175` adds `alp_extra` (ALP-held non-classic seats) to
the seat total; `scripts/build_page.R:242-244` publishes `sim$seats_won` with
no such term. They agree today only because `alp_extra` evaluates to 0. Any
non-classic seat with an ALP incumbent would make the published page
under-count by one, silently. Fix independently of this plan.
