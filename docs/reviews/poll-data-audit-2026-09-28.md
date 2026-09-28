# Poll data audit — 2026-09-28

**Most valuable thing we don't have yet:** DemosAU publishes a full crosstab PDF with
every monthly Victorian poll (region metro/regional, age×gender, education, income,
housing tenure, 2025 federal vote, left-right self-ID) — we currently keep only the
topline primary-vote numbers from that same poll. This is free, already being
published on a schedule we could scrape today, and speaks directly to the "demos and
state splits" half of the question. Seat-level polls and federal-poll state-breakdowns
were also checked (sections 2 and 3) — both already have an answer on record, not a
gap needing a decision.

Everything below states what I checked directly (repo files, computed row counts,
live web fetches of named URLs) versus what I inferred from a general web search
without opening the source. Where I could not confirm something, I say so.

## 1. Freshness — is our poll data up to date?

Polls load from the hand-maintained anchor clone `external/aus-polling-analyser`
(`R/load_polls.R` reads `analysis/Data/poll-data-<region>.csv`). **Verified**: that
clone's own git log shows its last commit was `2026-09-25`, three days before this
audit, pulled from `github.com/d-j-hirst/aus-polling-analyser`.

Row counts and date ranges below are computed directly from the six CSV files
(one row = one poll; "firms" = distinct pollster brand strings in the `Firm` column).

| region | rows | earliest | latest in our data | distinct firms |
|---|---:|---|---|---:|
| fed | 4,003 | 1943-06-01 | 2026-09-18 (YouGov2) | 32 |
| vic | 609 | 1985-12-01 | 2026-09-09 (ResolvePM) | 25 |
| nsw | 472 | 1985-12-01 | 2026-09-01 (ResolvePM) | 21 |
| qld | 399 | 1985-12-15 | 2026-08-28 (DemosAU) | 19 |
| sa | 292 | 1985-11-17 | 2026-08-16 (DemosAU) | 18 |
| wa | 318 | 1986-01-25 | 2026-08-16 (DemosAU) | 17 |

SA's own election was already held 2026-03-21 (results are in the candidate corpus as
`sa2026`); QLD's next election is fixed for 2028; NSW next is 2027; WA last held
2025. Victoria (28 Nov 2026) is the only region where "are we missing a poll from the
last two weeks" actually matters right now.

### Victoria — last 12 polls in our data, oldest to newest

Primary vote %, `TPP` is the published Coalition-to-Labor two-party figure where given
(`#N/A` = not published for that poll).

| date | firm | TPP | LNP | ALP | GRN | ONP | OTH |
|---|---|---:|---:|---:|---:|---:|---:|
| 2026-06-09 | DemosAU | 45 | 30 | 21 | 15 | 23 | 11 |
| 2026-06-23 | Redbridge | 46 | 26 | 26 | 13 | 27 | 8 |
| 2026-06-28 | YouGov2 | 46.2 | 26 | 23 | 13 | 24 | 14 |
| 2026-07-06 | ResolvePM | N/A | 27 | 27 | 12 | 22 | 12 |
| 2026-07-25 | Newspoll3 | N/A | 31 | 28 | 13 | 19 | 9 |
| 2026-07-30 | Redbridge | 43 | 30 | 23 | 14 | 22 | 11 |
| 2026-08-02 | Freshwater | 48 | 30 | 25 | 14 | 22 | 8 |
| 2026-08-06 | SMS Morgan | 49 | 26 | 26 | 12.5 | 23.5 | 12 |
| 2026-08-08 | DemosAU | 45 | 32 | 23 | 13 | 22 | 10 |
| 2026-08-12 | ResolvePM | N/A | 27 | 25 | 12 | 23 | 13 |
| 2026-09-08 | Redbridge | 44 | 29 | 24 | 15 | 25 | 7 |
| 2026-09-09 | ResolvePM | N/A | 28 | 25 | 12 | 23 | 13 |

### Checked against the public record — verdict: not stale

I fetched Wikipedia's ["Opinion polling for the 2026 Victorian state
election"](https://en.wikipedia.org/wiki/Opinion_polling_for_the_2026_Victorian_state_election)
directly and cross-checked every poll it lists from August 2026 onward, plus a
[Poll Bludger article from 2026-09-16](https://www.pollbludger.net/2026/09/16/victorian-polls-redbridge-group-and-resolve-strategic/)
(the most recent Victorian item on that site) and a live [Roy
Morgan](https://www.roymorgan.com/findings/10353-federal-voting-intention-september-21-2026)
release. Every public poll found matches a row already in our data, once you allow for
the anchor's habit of recording a poll's estimated **mid-fieldwork date** rather than
its **publication date** (e.g. Wikipedia's "Resolve, published 13 Sept" = our
`2026-09-09 ResolvePM`; Wikipedia's "RedBridge/Accent, fielded 1-14 Sept" = our
`2026-09-08 Redbridge`):

| poll (Wikipedia/Poll Bludger) | Coalition/Lab/Grn/ONP/Oth | matches our row |
|---|---|---|
| Roy Morgan, 5-7 Aug | 26/26/12.5/23.5/12, TPP 51/49 | `2026-08-06 SMS Morgan` — exact |
| DemosAU/Premier National, 6-11 Aug | 32/23/13/22/10, TPP 55/45 | `2026-08-08 DemosAU` — exact |
| Resolve, 16 Aug | 27/25/12/23/13 | `2026-08-12 ResolvePM` — exact |
| RedBridge/Accent, 1-14 Sept | 29/24/15/25/7, TPP 56/44 | `2026-09-08 Redbridge` — exact |
| Resolve, 13 Sept | 28/25/12/23/13 | `2026-09-09 ResolvePM` — exact |

**No Victorian poll published after 13 September 2026 exists in the public record as
of this check** (Wikipedia's table and the 16 Sept Poll Bludger roundup both stop
there) — so nothing is missing, not even a not-yet-scraped one. Nothing needs
scraping right now; re-check this weekly given DemosAU's monthly and Resolve's
roughly-monthly Victorian cadence.

Federal is similarly current: our latest row (`2026-09-18 YouGov2`) and the row
before it (`2026-09-17 Morgan multi-mode`, TPP 53/47) match a live [Roy Morgan
release fielded 14-20 Sept, published 21
Sept](https://www.roymorgan.com/findings/10353-federal-voting-intention-september-21-2026)
(ALP 25/Coalition 21.5/Grn 15.5/ONP 25.5/Oth 12.5, TPP 53/47) almost to the point —
again the anchor recorded the mid-fieldwork date, not the publish date. I did not
individually re-verify NSW/QLD/WA against a live source (lower priority — none is the
live forecast target) but their most recent rows match the cadence of DemosAU's
monthly state releases, which is a real, named, findable source (not silence).

## 2. Seat-level (electorate) polls

**HAVE: no.** `grep -rniE "seat.?poll|electorate poll|marginal.*poll"` across `R/`,
`scripts/`, and `docs/` turns up no seat-poll data file and no code that reads one —
only prose. `docs/ANCHOR-MODEL.md` documents that the *third-party anchor model*
(Kevin Bonham's, which we compare against, not our own) uses seat polls as one input
("Prominent candidates, heavily discounted... Hand-entered (`Seat polling.xlsx`,
`Regional/*-polls`)") — that file lives in his private workspace, not ours, and we
never fetch it.

**This is a decision already on record, not an oversight.** `docs/NEXT-STEPS.md`
("Awaiting Pete"): *"Market odds or seat polls as an exogenous input for new
independents: a different kind of input, Pete's call."* The same line recurs in
`docs/plans/plan-miss-patterns-2026-09-06.md`, `docs/reviews/independent-federal-*.md`
and three other review docs — always framed as open, never as "tried and rejected".

**AVAILABLE TO SCRAPE:**
- **Victoria 2026 seat-level MRP**: RedBridge/Accent ran one for the Victorian Trades
  Hall Council (June 2026, seat-by-seat probabilities, reported as Labor 35 / One
  Nation 12 seats); YouGov ran one for "Common Threads" (June-July, One Nation 17
  seats). Both are third-party MRP outputs (modelled seat estimates), reported via
  Poll Bludger/news coverage, not raw polls — I have not found the underlying seat
  tables, only aggregate seat counts quoted in articles.
- **Roy Morgan's 3-seat aggregate** (Melbourne, Brunswick, Richmond; Greens 41/Labor
  35/Liberal 14/ONP 2, annual) — a small, real seat-cluster poll, publicly reported.
- **DemosAU's own Monte Carlo seat projection** (bundled with their federal poll PDFs
  — e.g. the June 2026 release gives 20,000-simulation seat ranges) is seat-level
  output derived from *their own topline poll plus their own model*, not an
  independent seat poll — still worth having as a comparison point.
- **Historical**: Wikipedia maintains "Electorate opinion polling for the 2022
  Australian federal election" and a "...for the next Australian federal election"
  page (i.e. fed2025) — scrapeable seat-by-seat polling tables, all public, for
  building/back-testing a seat-poll feature if the model gets one.

**Recommendation, ranked:** low priority to fetch right now given it is explicitly
Pete's open call rather than a data gap — but if the answer becomes "yes", the RedBridge/
YouGov MRP seat counts and Wikipedia's per-seat federal tables are the cheapest first
fetch (already tabulated by others), not Bonham's private hand-entered file (which we
don't have access to and would have to rebuild from scratch anyway).

## 3. State-level breakdowns of federal polls

**HAVE and USED — but the underlying source file is stale.** Two files in the anchor
clone carry state-level federal data: `region-polls-fed.csv` (state-level federal poll
readings) and `tpp-fed-regions.csv` (actual state-level TPP results and swings), both
consumed by `scripts/build_state_deviation_features.R` to build the `state_poll_dev`
and `state_elec_dev` features behind the **`AUSPOL_STATE_DEV`** switch — shipped,
adopted 2026-09-15, federal-only (`docs/published_flags.R` sets it to `"1"`;
`docs/MODEL-REGISTRY.md` confirms it reaches every federal harness but, correctly,
none of the state ones or the published Victorian forecast, since a state election has
no separate "state" to deviate from). Measured effect on adoption: pooled federal seat
log loss 0.2584 → 0.2539 over 1,052 seat-elections (`docs/MODEL-REGISTRY.md:162`).

**The gap I found**: both source files stop at the **2022** federal election —
verified directly (`cut -d, -f1 ... | sort -n | uniq -c` on both files: last year is
2022, nothing for 2025). So for the fed2025 pair specifically, `state_poll_dev` and
the "actual" state swing have no 2025 row to compute from; the build script's own
comment flags this exact symptom for the actual-result side ("the anchor's results
table stops at 2022, so an all.x merge... silently dropped every fed2025 state-year"
— already patched to an outer join so it doesn't crash, but the underlying 2025 STATE-
LEVEL FEDERAL POLLING data itself was never added, only the merge logic that tolerates
its absence). This doesn't touch the published Victorian forecast (feature is
federal-only) but does mean the feature is running one election blind on the most
recent federal contest.

**AVAILABLE TO SCRAPE**: I could **not** confirm a specific, comparably-structured
public source giving 2023-2026 state-level breakdowns of *federal* poll results (as
opposed to each state's own state-election polling, which is a different series and
is already captured in `poll-data-{nsw,qld,vic,sa,wa}.csv`). Newspoll and Resolve have
historically published occasional state-breakdown tables inside their federal
releases; I found general mentions of Resolve's federal polling in 2025-2026 but did
not locate a page with the same year/state/TPP shape as `tpp-fed-regions.csv` to
extend it from. This needs a dedicated search/scrape pass, not a quick web check.

**Recommendation:** medium priority — the machinery and the win are already proven
(0.0045 log-loss drop, real). Extending `region-polls-fed.csv`/`tpp-fed-regions.csv`
with 2023-2025 state-level federal figures (wherever Newspoll/Resolve/Morgan published
them) is a data-entry job on an existing pipeline, not new modelling work, and is
cheaper than either of the other two items here.

## 4. Poll crosstabs / demographics

**HAVE and USED for demographics: only ABS Census, not poll crosstabs.**
`R/demographic_residual.R` and `scripts/build_census_features.R` correct primary-vote
predictions using **ABS Census** data at CED/SED level (age, education, income,
etc. of each *seat's population*) — this is Census, not poll respondent data.

**Poll crosstabs specifically: confirmed absent, and confirmed why.**
`docs/plans/plan-mrp-scoping.md` states directly: *"Checked directly. Our poll data
is: `MidDate, Firm, Brand, @TPP, LNP FP, ALP FP, GRN FP, ONP FP, UAP FP, DEM FP, OTH
FP, GLApp, GLDis, Comments`. Published toplines only. No respondent records, no
crosstabs, no demographics."* `docs/ANCHOR-MODEL.md:142` repeats this: *"No MRP / no
raw crosstab usage — polls enter as topline numbers only."* This was scoped as an MRP
blocker, but it is exactly the same missing input the crosstab question is asking
about, whether or not full MRP is attempted.

**AVAILABLE TO SCRAPE, and larger than the existing docs suggested**: DemosAU
publishes a full crosstab PDF alongside *every* Victorian and federal poll it runs —
verified by finding and listing several directly (e.g.
[`DemosAU-Vic-Poll-June-2026.pdf`](https://demosau.com/wp-content/uploads/2026/06/DemosAU-Vic-Poll-June-2026.pdf),
[`DemosAU-Report-Victoria-Poll-August-2026.pdf`](https://demosau.com/wp-content/uploads/2026/08/DemosAU-Report-Victoria-Poll-August-2026.pdf),
a September 2026 federal equivalent). The June 2026 Victorian PDF's crosstabs (per a
web summary, not yet opened by me directly — flagged as unverified detail) break
results down by **age×gender, education, personal income, residential tenure,
region (metro/regional), 2025 federal vote, and left-right self-identification**.
Resolve's Victorian releases were reported as containing at least regional
(metro-vs-regional) and age splits in commentary, though a full crosstab table was not
found for their most recent release — DemosAU looks like the more complete and more
regularly-published source for Victoria specifically.

**None of this is respondent-level microdata** (that would need a commercial
arrangement, per `plan-mrp-scoping.md`) — it is published cross-tabulated summary
tables, i.e. exactly the kind of aggregate-but-more-granular-than-topline input that
could feed a seat-level regional/demographic correction without needing full MRP.

**Recommendation:** highest near-term value of the three, and the one Pete's question
was most directly pointing at ("crosstabs in polls to help with demos and state
splits"). First fetch: DemosAU's Victorian PDFs (monthly since at least Sept 2025,
consistent format, direct URLs discoverable under
`demosau.com/wp-content/uploads/<year>/<month>/`) — parse the region (metro/regional)
and age×gender tables into a new small CSV keyed by poll date, and let the primary-
vote model (which already ingests DemosAU's topline row) decide whether the regional
split adds anything once it exists as a feature, per Pete's stated approach of letting
the modelling decide what's useful rather than pre-judging it.

## What I verified directly vs. inferred

**Verified by opening the file or fetching the named URL myself**: all row
counts/date ranges/firm lists in section 1; the anchor clone's last-commit date; every
row in the Victoria "last 12 polls" table; the Wikipedia Victorian polling page
content; the Poll Bludger 16 Sept article; the two Roy Morgan release pages; the
DemosAU June-2026-poll seat-projection numbers; the `AUSPOL_STATE_DEV` code path and
its year-2022 ceiling in `region-polls-fed.csv`/`tpp-fed-regions.csv`; the exact wording
in `plan-mrp-scoping.md` and `ANCHOR-MODEL.md` on crosstabs and seat polls.

**Not independently verified, taken from a web-search summary only**: the exact
column list inside the DemosAU June-2026 Victorian crosstab PDF (I found and confirmed
the PDF exists and is publicly downloadable, but did not open and read its tables
myself); whether Resolve's Victorian releases carry a full crosstab table versus just
commentary quoting a subset; whether any 2023-2026 federal-poll state-breakdown source
exists to extend `tpp-fed-regions.csv` — this one came back genuinely inconclusive
from search rather than confirmed absent.
