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

## Dress rehearsal 1, projection layer only, 2026-09-19 22:05

Built: `scripts/fetch_booths_vic2022.R` (2022 from the results site's
HTML voting-centre pages, 87 districts, 1,729 ordinary booths; 2018 from the
historical-results blob, 87 districts, 1,837 booths; Ripon 2018 publishes
booth rows as zeros after its recount and is skipped) and
`scripts/booth_replay_vic2022.R`. Two source traps found on the way: the
per-district `.xls` blob is not versioned by election (Nepean's was the
2026 by-election), and the 2CP pages count slightly more declaration votes
than the first-preference pages in 14 districts (later vintage; up to 2.2%
in Werribee). First preferences are the projection's source.

Reference 2018, live 2022, booths matched by name in-district (1,314) then
by unique name statewide across the redistribution (586): **78.3% of the
2022 vote matched**. Simulated report order (small ordinary booths first,
then early votes, then postals). No forecast prior. Error is on the final
ALP/LNP/GRN first-preference share, points, lower is better; leader = the
seat's first-preference leader called correctly, of 87.

| night vote counted | share of ALL votes | leader correct | major MAE | major RMSE |
|--:|--:|--:|--:|--:|
| 10% | 8.6% | 86 | 2.01 | 2.63 |
| 25% | 22.4% | 85 | 1.55 | 1.93 |
| 50% | 34.6% | 87 | 1.45 | 1.77 |
| 75% | 34.6% | 87 | 1.45 | 1.77 |
| 100% | 95.0% | 87 | 0.20 | 0.26 |

The 50% and 75% rows are identical because early votes are one unit per
district (49.5% of the vote) and land all at once in this ordering; the
VEC feed may report early-vote centres separately, which would smooth
that. With every unit counted the projection equals the final in every
seat and class (the parser and matching identity check).

Worst seats at 50%: Richmond (Greens 39.4 projected vs 34.7; the Liberals
did not stand in 2018 so their 2022 vote has no booth swing to follow),
Werribee and Tarneit (Labor under by 4 to 5, outer-west early votes ran
differently from the ordinary booths), Melbourne, Berwick. These are the
cases the prior is for.

**Next**: the prior/posterior layer (`scripts/booth_update_vic.R`), using
the shipped vic2022 backtest's predicted primaries as the prior in
rehearsal 2, and the afternoon forecast on the night.

## Dress rehearsal 2, prior + projection, 2026-09-19 22:15

`R/booth_projection.R` now holds the matching, the projection and the
precision-weighted combination (`combine_prior_projection()`, projection sd
from `booth_projection_sd()`, interpolated through rehearsal 1's RMSEs).
`scripts/booth_rehearsal2_vic2022.R`: prior = the shipped vic2022 backtest's
predicted primaries (the forecast recipe as-at the day before, 78 seats),
prior sd = that backtest's residual sd by class (ALP 4.4, LNP 4.4, GRN 2.5).
Error on the final ALP/LNP/GRN share, points, lower is better; leader = the
seat's first-preference leader called correctly, of the 78 seats with a prior.

| night vote counted | prior alone | projection alone | posterior |
|--:|--:|--:|--:|
| 0% | 68 / 3.12 | | 68 / 3.12 |
| 10% | 68 / 3.12 | 76 / 2.06 | 75 / 1.72 |
| 25% | 68 / 3.12 | 75 / 1.60 | 75 / 1.36 |
| 50% | 68 / 3.12 | 77 / 1.48 | 77 / 1.25 |
| 100% | 68 / 3.12 | 77 / 0.20 | 77 / 0.19 |

Cells are `leaders correct / major-share MAE`. The posterior beats the
projection on share error at every fraction and matches it on leaders; both
beat the afternoon prior from the first 10% of the night vote. That is the
plan's second hard requirement, met on shares (the log-loss form needs win
probabilities, which need the preference re-simulation, next).

**Next**: re-simulate each seat's preference count from the posterior
primaries with the shipped flow model (win probabilities and 2CP), then the
chamber aggregation with the forecast's statewide correlation, then the
feed parser once VEC publishes the 2026 configuration.

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

## Dress rehearsal 3: win probabilities and chamber totals through the shipped simulator (2026-10-28, issue #153)

`AUSPOL_NIGHT_REPLAY_FRAC` (`R/night_update.R`, hooked into `scripts/backtest_candidate_vic.R` before the final
`simulate_seat_contests()`): the harness's own afternoon vic2022 forecast is the prior; booths counted by that
fraction of the night update each seat's primaries cell by cell (rehearsal 2's projection and precision weighting),
the posterior sds replace the per-cell spread, and the statewide draws shrink around their centre by the mean share
of spread resolved. The shipped flows, Coalition split and simulator then give win probabilities and chamber totals.
Scored with `quick_arm.R --pairs=vic2022` (1,000 sims; baseline = the afternoon forecast, same seed).

Seat-winner log loss over 88 seats, lower is better (afternoon forecast 0.2643):

| night vote counted | 0 | 10% | 25% | 50% | 75% | 100% |
|---|---:|---:|---:|---:|---:|---:|
| log loss | 0.2643 (byte-identical) | 0.1556 | 0.1395 | 0.1112 | 0.1112 | 0.0897 |

50% and 75% are identical because 2022 early votes are one unit per district (rehearsal 1); in 2026 every early
voting centre is its own booth row, which will smooth the curve. Chamber at 50% counted, 90% range (median), against
the 2022 result: Labor 51-57 (55), actual 56; Coalition 22-29 (26), actual 28; Greens 4-5 (5), actual 4: all covered.
**Independents 1-6 (3), actual 0: not covered.** The seats are close independent contests decided on preferences
(Mildura IND 0.92 at 50% counted, lost on preferences; Mornington 0.31, Hawthorn 0.24), plus South-West Coast, which
is missing from the 2022 booth file and so never updates. That is the preference model, not the count update.

Caveats (review of #153): (1) **not held out**: `booth_projection_sd()` and the report-order seed were fitted on this
same 2018 -> 2022 replay; (2) **not all knowable on the night**: "fraction of the night vote" and `counted_share` use
final totals as the denominator; live, they need a turnout estimate; (3) the statewide shrink is a heuristic (mean of
1 - posterior sd / prior sd); (4) breakout, surge and error-quantile components keep their afternoon strength after
the update. Replay outputs carry `-nightNNN` in their names and `scripts/pool_backtests.R` skips them (PB0).

## Dress rehearsal 4: the VEC's two-candidate count as evidence on the preference flow (2026-10-28, issue #161)

`AUSPOL_NIGHT_TCP=1` with a replay fraction (`night_tcp_obs()`, `night_apply_tcp()`): in the counted booths, the flow
of the other parties' votes to each of the VEC's pair is measured against the same booths' first preferences, with a
standard error from the spread between booths; each simulated draw with that final two shifts by the change in flow;
a pair in under 20% of draws is ignored and flagged. Replayed on the FINAL 2022 pairs (`output/booths/vic2022-booth-tcp.csv`),
2CP assumed to arrive with each booth's first preferences: a best case (on the night the VEC's first pair can be
wrong and 2CP lags).

Seat-winner log loss, 88 seats, lower is better: first-preference update alone -> plus 2CP flow, same seed:
10% counted 0.1556 -> **0.1133**; 25% 0.1395 -> **0.0968**; 50% 0.1112 -> **0.0929** (after the review fix: unbiased between-booth
flow SE, held at 0.25 under 3 counted booths; before it, 0.1146 / 0.0994 / 0.0970 with the flow over-trusted). At 50%: Mildura (Nationals won)
0.08 -> 0.78, Morwell 0.43 -> 0.95, Berwick 0.48 -> 0.92; worse: Northcote (Labor v Greens) 0.32 -> 0.05. Independents at
50% counted: 90% range 1-6 -> 0-5 seats (actual 0). Two designs failed first and are recorded so they are not retried:
the raw counted 2CP share (0.1661: early booths are not a random sample), and combining 2CP shares with the draws
(0.1313: counts the first preferences twice and over-sharpens close seats, Mornington 0.69 -> 0.04).

## Dress rehearsal 5: vote-type gaps, new candidates, and a fast replay (2026-10-28, issue #160)

**Fast replay.** `AUSPOL_NIGHT_DUMP=<file.rds>` (run through `quick_arm.R`, so nothing lands in `output/`) saves the vic
harness's pre-simulation state; `scripts/night_replay.R --state=...` sweeps fractions and settings from it: ~10 s a
fraction instead of ~80 s. It reproduces quick_arm exactly (0.2643 at nothing counted, 0.0929 at 50% with 2CP).

**Vote-type gap** (`night_booth_update(gap_k =)`): for each non-ordinary booth type and class, the gap between that type's
counted swing and the same seat's ordinary swing, pooled over the seats where it is counted and shrunk by n/(n+k), is
added to the all-types swing of a seat whose votes of that type are not yet in. With 2022's ordering (each district's
early lump, ~half its night vote, after all booths) it can never act below 100%, so it was tested with early lumps
interleaved among the booths (`early = "interleaved"`, U(0.3, 1.0)). Seat log loss, 88 seats, 2CP on:

| counted | no gap | k = 5 | k = 20 |
|---|---:|---:|---:|
| 25% | 0.1079 | 0.1079 | 0.1079 |
| 50% | 0.1074 | 0.1074 | 0.1074 |
| 75% | 0.0833 | **0.0712** | 0.0750 |

It acts only once early lumps are in (~65% counted in 2022); in 2026 each early centre is its own smaller booth, so
earlier. Pooled early-vs-ordinary gap at 75% counted (44 districts): Labor +3.8, Greens -2.7, Coalition +0.2 points.
k = 5 chosen (the first value tried; k = 20 worse); not tuned further on one election.

**New candidates** (`new_sd_mult`): holding a no-history class's projection 1.5x or 2x looser was slightly WORSE at
10-50% counted (0.1108 -> 0.1117 / 0.1123 at 10%) and flat at 75%. Left at 1. A weak test: 2022 had few candidates with
no 2018 votes; the case it is for (One Nation 2026) cannot be replayed on Victoria.

Bug found on the way, fixed: the gap was first added with `merge()`, which re-sorted the projection grid and
misaligned a row-ordered vector (`has_ref`), returning NA projections in 28 of 88 seats; now an update join, with a
test that a gapped projection has no NA.
