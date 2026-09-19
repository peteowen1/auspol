# Plan: the election-night booth model (Victoria, 28 November 2026)

Opened 2026-09-19 21:40 after Pete chose it over pre-election seat-type work
("option b"). The forecast on the afternoon of 28 November is the prior;
from 6:30 pm every booth that reports updates the seats, and the chamber
odds move live on inthegame.blog/politics/.

## What VEC publishes on the night (2022 media handbook, p.37; expect 2026 to match)

- Provisional results start on the VEC website "from around 6:30 pm".
- Counted on the night: ordinary votes by voting centre, **own-district early
  votes**, and district postal votes at the central site: "an estimated 75%
  of the enrolled electors". Absents, late postals and preference
  distributions follow over two weeks; declarations from the Friday after.
- A **2CP results summary** per district on the night (indicative, on the
  VEC's own chosen pairing).
- **"The XML feed drills down to the provisional results at individual
  voting centres within each district."** Configuration files and
  instructions are published at vec.vic.gov.au/Media before the election;
  enquiries to communication@vec.vic.gov.au. Nothing is on that page yet
  (checked 19 Sep). The VEC results site itself updates every five minutes.
- After the count, per district: `<District>-Results by Voting Centre.xls`
  (first preferences per booth, one sheet, header rows then a booth-by-
  candidate grid; readable with `readxl`) and a "2CP results by voting
  centre" HTML page (booth rows, two candidate columns). Both exist for
  2022 at the URLs linked from the cached `*-results.html` pages.

## Data to fetch now (October)

1. `scripts/fetch_booths_vic2022.R`: for the 88 districts, the FP-by-voting-
   centre `.xls` and the 2CP-by-voting-centre page, into
   `external/reference/vec/2022/booths/`. Parse to
   `output/booths-vic2022.csv` (district, booth, booth_type
   [ordinary/early/postal/absent/provisional], candidate, party, votes) and
   `output/booths-vic2022-2cp.csv`. Registry regenerated in the same commit.
2. The 2026 boundaries are the 2022 boundaries (no redistribution between),
   so booth matching is by district plus booth name. Booths that opened or
   closed get no match and fall back to the district's ordinary-vote swing.
3. When VEC publishes the 2026 feed configuration: a parser for the XML and
   a poller (five-minute cadence, store every raw response: the raw-scrape
   rule).

## The model

Per seat, the afternoon forecast gives each party's primary and the seat's
win probabilities from 20,000 draws. On the night:

- **Booth swing**: for each reporting booth with a 2022 match, the change in
  each party's share versus its 2022 share at that booth. Candidate identity
  matters here exactly as in the forecast: a party whose 2022 candidate has
  gone is matched by party class with the departed-member discount already
  in the prior, not re-derived.
- **Seat estimate**: the seat's projected final primary for each party is
  the counted votes plus the uncounted votes projected as (2022 share at
  those booths + the seat's counted swing), with the swing pooled by booth
  type (ordinary, early, postal behave differently; 2022 own-district early
  votes were a large share of the night count).
- **Prior and update**: the afternoon distribution of each party's seat
  primary is the prior (mean and sd from the sims). The night's projected
  primary has a sampling sd that falls with the counted fraction, plus a
  floor for the booth-type mix. Precision-weighted combination gives the
  posterior primary; the seat's preference count is re-simulated from the
  posterior primaries with the same flow model, so win probabilities and
  the 2CP move consistently. No new preference machinery.
- **Chamber**: re-aggregate the 88 posterior seat distributions with the
  same statewide correlation the forecast uses, so an early swing in ten
  seats moves the other 78 through the shared component.
- **Output**: the same `forecast-vic2026.json` shape, written every cycle to
  R2 with `built_at` and `counted_pct`, so the blog page needs only a poll
  loop and a "counted" column.

## Dress rehearsal (the test, before any code is trusted)

Replay vic2022 in time order from the booth files (booth report order is
not recorded in the final files; use a plausible order: small rural booths
first, early-vote centres late, postals last) and score, at 25%, 50%, 75%
and 100% counted, (a) seat log loss against the final winners and (b) the
projected chamber totals against the final 56/28/4. Two hard requirements
set now: at 100% counted the projection must equal the final count in every
seat (a correctness check on the parser and the matching), and at 50%
counted the log loss must beat the afternoon forecast's (otherwise the
update is adding noise, not information).

## Timeline

- October: fetch and parse 2022 booths; matching; replay harness; first
  rehearsal. Write to VEC for the 2026 feed configuration.
- Early November: feed parser once the configuration is published; blog
  page poll loop; second rehearsal against the live-site HTML as a fallback
  feed.
- 28 November: run.

## Email to VEC (for Pete to send; drafted, not sent)

To: communication@vec.vic.gov.au
Subject: 2026 State election results feed

Hi,

I run inthegame.blog, which publishes an election forecast for the 2026
State election. I would like to use the VEC's election-night results feed
(the XML feed of provisional results by voting centre described in the 2022
media handbook) to update the forecast live on the night.

Could you let me know when the 2026 feed configuration and instructions
will be published, and whether there is anything I need to register for?

Thanks,
Pete Owen
