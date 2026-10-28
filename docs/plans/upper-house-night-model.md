# Victorian upper-house (Legislative Council) election-night model: design

Written 2026-10-28 for [#148](https://github.com/peteowen1/auspol/issues/148). Design only, no code shipped.
Assembly first, upper house second: nothing here may take time the Assembly path needs.

Rules in force (from the resolutions on #152 and #157): group voting tickets are gone for 2026; voters number at least 5
groups above the line or at least 5 candidates below it; 8 regions x 5 members; quota floor(formal/6)+1; count assumed to
be unweighted inclusive Gregory (the Act touches no counting clause; section 114A itself was not read, so this is
**unconfirmed**).

Everything numeric below was measured from `output/council-*.csv` and `external/elections/vec-{2018,2022}-vic-firstprefs.csv`
with throwaway R scripts (not committed). n is given on every figure. Scripts live only in the author's scratchpad;
the design for a committed script is in section 6.

## Summary of answers

| Question | Answer in one line |
|---|---|
| 1. Prior | Council share = Assembly share x state ratio for ALP (about 0.90), Liberal/National (about 0.85), Greens (about 0.90); everything else is the remainder (about 27% of the vote, 10 points above the Assembly's non-major share). Out of sample 2018 to 2022 error 0.75 to 2.4 points per major. |
| 2. Preferences | No Victorian data and none for the Senate on disk. Borrow the Senate and NSW shape (sourced from the web, not quantified here). Plan: model it as a small number of explicit flow parameters with wide priors, and expect them to matter only for seats decided inside about 0.2 quota. |
| 3. Count | Naive R inclusive Gregory: 19 to 40 ms per draw. The "quotas from first preferences" shortcut gets the group seat split exactly right in 4 of 16 past region-elections and 64 of 80 seats, but every miss is a ticket-driven micro-party win that the 2026 rules remove. Use the shortcut to find contested regions, the full count only there. |
| 4. Night update | Same matched-booth swing machinery as the Assembly, per group, at region level, with vote-type pooling. Ordinary-booth-only counts understate the majors by about 2.5 points. |
| 5. Minimum viable | First preferences by group and region, afternoon prior, shortcut seat odds with a Gregory check on the last seat, only if rehearsed by 25 November. See section 6. |

## 1. Afternoon prior per group per region

**What was measured.** For each of 2018 and 2022: Council first preferences per district (the `district_total` rows of
`council-fp-*.csv`, 88 districts per year) grouped into four classes (ALP; Liberal plus Liberal/National groups; Greens;
every other group), against the Assembly first preferences in the same districts (`vec-*-vic-firstprefs.csv`; "other"
includes independents and all minor parties). Narracan is dropped from 2022 (no Assembly result: supplementary election).
Districts where the Assembly had no "other" candidate count as 0. n = 175 district-years, 16 region-years.

Statewide, Council share against Assembly share (the ratio is Council share divided by Assembly share; the gap is
Council minus Assembly in percentage points; for the "other" class a bigger number means more people voted minor in the
upper house):

| Class | 2018 ratio | 2018 gap | 2022 ratio | 2022 gap |
|---|---:|---:|---:|---:|
| ALP | 0.915 | -3.6 | 0.894 | -3.9 |
| Liberal / National | 0.836 | -5.8 | 0.854 | -5.0 |
| Greens | 0.864 | -1.5 | 0.902 | -1.1 |
| All other groups | 1.967 | +10.9 | 1.589 | +10.1 |

Council "other groups" pool was 22.1% (n = 791,595 of 3,584,448 formal) in 2018 and 27.2% (n = 1,007,054 of 3,708,699,
Narracan excluded) in 2022.

**Which form is stable.** The gap in points is stable for the "other" pool (+10.9 then +10.1; the ratio swings 1.97 to
1.59 because the Assembly's other share rose from 11.2% to 17.1%). For the majors the ratio is the steadier form.

Out-of-sample test: fit on 2018, predict 2022 region Council share from the 2022 Assembly share. n = 8 regions per class;
2018 "Eastern Metropolitan" is paired with 2022 "North-Eastern Metropolitan" although the 2022 redistribution changed
region footprints (so this test is harsher than a like-for-like one). Error is root-mean-square, in percentage points of
region vote (lower is better):

| Method | ALP | Greens | Liberal/Nat | Other pool |
|---|---:|---:|---:|---:|
| Assembly share unchanged | 4.73 | 1.34 | 5.62 | 10.35 |
| Statewide 2018 ratio | 2.36 | 0.75 | 1.80 | 8.39 |
| Statewide 2018 gap | 2.66 | 0.83 | 2.71 | 2.72 |
| Region-specific 2018 ratio | 1.96 | 0.95 | 2.14 | 23.3 (breaks: one 2018 region had Assembly other = 2.2%) |
| Region-specific 2018 gap | 2.07 | 0.95 | 2.33 | 3.50 |

Region-level persistence of the gap between 2018 and 2022 (correlation across 8 regions): ALP 0.71, Greens 0.55,
Liberal/National 0.86, other 0.49. Spread of the gap across regions within a year (sd, points): ALP 2.8 to 2.9, Greens
0.8 to 1.1, Liberal/National 2.8 to 4.3, other 2.8 to 4.1. Within a region the district-to-district sd of the gap is
larger (ALP 5.1, Liberal/National 4.2 to 6.1), so the region total averages district noise away.

**Proposed prior.**

1. Region-level Assembly primaries per class from the forecast's seat-level numbers, summed over the region's 11 districts
   using each district's expected formal votes (district map: `external/reference/vec/vic-district-regions.csv`). I did
   not open `forecast-vic2026.json` (not downloaded in this session), so its field names and whether it carries "other"
   shares per seat are **unconfirmed**.
2. ALP, Liberal/National and Greens Council share = Assembly share x ratio, ratio = the mean of 2018 and 2022 statewide
   ratios (ALP 0.905, Liberal/National 0.845, Greens 0.883), with half-weight toward the region's own past ratio for ALP
   only (the one class where region-specific beat statewide, 1.96 vs 2.36, on n = 8; weak evidence).
3. "Other groups" pool = 1 minus the three majors. The measured accuracy of this remainder was **not** computed; the
   statewide-gap result (2.72) is the nearest proxy. Plan to check it in the build.
4. Uncertainty (one sd, points of region vote): ALP 2.4, Liberal/National 2.0, Greens 0.8, pool 2.7, each inflated by 25%
   because there is one out-of-sample pair, then correlated through the sum-to-one constraint (draw the four from a
   Dirichlet-style logistic normal, not independently).

**Splitting the pool across groups.** Groups per region: 18 to 25 (15 to 17 of them minor in 2018, 18 to 22 in 2022).
Largest minor group takes 14 to 29% of the pool, the top three 41 to 54%. Eleven minor groups ran in both years, and
across 87 group-region pairs their share of the pool correlates 0.67 between 2018 and 2022 (rmse 5.4 points of the pool),
but they made up only 56.3% of the 2022 pool (n = 1.01M); the other 44% went to groups that were new that year (Legalise
Cannabis alone polled 153,184, One Nation 76,790). Per group, region pattern persists (corr: Shooters 0.97, Sustainable
Australia 0.95, Reason 0.95, Victorian Socialists 0.81, DLP 0.66, Animal Justice 0.60, Liberal Democrats 0.53) or does
not (Health Australia 0.13, Hinch 0.17, Transport Matters -0.02), and levels move a lot (Hinch's pool share 16.6% to
5.6%; Shooters 12.2% to 7.2%). Proposal: for a group that ran in 2022, take its 2022 regional pool-share pattern, shrink the
level toward 1/(groups) by an amount fitted on 2018 to 2022; for groups with no history, an equal share of a "new group"
mass of about 40% of the pool. Wide Dirichlet (effective n about 30). The group list is not known until registration
closes on 9 November, so none of this can be finalised before then. The prior matters only until the first booths report:
group first preferences are then observed directly.

## 2. Preferences under the new rules

**What is on disk.** Nothing for the Senate or the NSW Legislative Council: `external/reference/aec/` holds House first
preferences and distributions only, and `output/council-results-*.csv` are local-government council results. Victorian
2018 and 2022 distributions (`council-dist-*.csv`) were counted under group voting tickets, so their transfers show ticket
deals, not voter choice, and cannot be used as flows.

**What the old Victorian data does give (n shown).** 2022 ballots below the line: 9.4% of 3,752,539 formal (2018: 8.8% of
3,584,448); by group type in 2022, 17.4% of minor-group voters went below the line against 6.5% of major-group voters
(2018: 13.6% and 7.5%). Under the new rules a below-the-line vote needs 5 candidates, which will probably cut that share
somewhat (**my guess, unconfirmed**).

**Sourced from the web (secondary, not verified against primary tables, treat as direction only).**

- A University of Melbourne commentary on the 2016 Senate change (via the search page
  <https://findanexpert.unimelb.edu.au/news/5472-poor-reachtel-for-labor--but-essential-better>) says tickets were
  removed, at least 6 boxes above or 12 below were required, and that micro parties would need roughly half a quota to
  have a reasonable chance; preferences were unlikely to change results unless the gap between candidates was under 0.2 quota.
- A Parliament of Australia research paper, as summarised in the same search: above-the-line preference use was
  complex, often not along party lines, and frequently at odds with how-to-vote cards.
- AEC Senate Ballot Paper Study 2016, "numbers of preferences": <https://www.aec.gov.au/About_AEC/research/files/sbps-numbers-of-preferences.pdf>.
  The PDF could not be text-extracted in this session, so **the exhaustion rate and the number-of-preferences
  distribution are not read**. First task of the build.
- Pappu Bahry's per-state above-the-line preference tables for 2016: <https://pappubahry.com/pseph/aus_2016/> (not opened).
- NSW (optional preferential, 1 box enough): a City Hub piece (undated snippet, <https://cityhub.com.au/why-your-preferences-matter/>)
  says above-the-line ballots with more than one preference rose from 15% to 28% at the latest upper-house election
  and that preferences exhaust quickly. Antony Green's 2023 NSW analysis (<https://www.parliament.nsw.gov.au/researchpapers/Documents/2023-NSW-election-Analysis-of-results.pdf>)
  has the exhaustion table; not read.

**Design consequence.** Victoria's rule is closer to the Senate's than to NSW's (at least 5, not at least 1), so few
ballots should exhaust before 5 groups are used up; after 5 they can. Model a ballot as: first group, then up to 4 or 5
more groups (a high fraction run to the end of their list, "at least 5" is a minimum, not a typical length: unconfirmed
what share stop at exactly 5), then exhaustion, followed by the within-group candidate order for the ATL part. For flows
use three explicit parameters with wide priors, because no Victorian data exists:
(a) share of a group's voters who follow its own how-to-vote card (card order is unknown before registration, so the model
    treats it as the group's "allied" set);
(b) the within-bloc affinity (Labor/Greens/progressive minors; Liberal/National/right minors; cross-bloc leakage); and
(c) the share who number in ballot-paper order (donkey-style).
Draw these per simulation, not per region, so that preference uncertainty is common across regions, as it would be in reality.
Expected effect: preferences decide only seats where the contest is inside about 0.2 quota (secondary source above);
checked on 2022 first preferences in section 3, that is roughly the last-seat contest.

## 3. The count

**Data.** `council-dist-2022.csv` and `-2018.csv`: every count of every region, with the order electors were declared in
`elected_note`. Candidates mapped to groups via `council-fp-cand-*.csv` (all 80 winners mapped; 454 and 380 candidates, 0
duplicates). This is the 2018 and 2022 tickets era. n = 16 region-elections, 80 seats.

**What won.** By the winning group's rank on first preferences: rank 1 won 34 seats, rank 2 won 24, ranks 3 to 6 won 17,
ranks 7 to 12 won 5. Seats won by groups polling under half a quota on first preferences: 17 of 80 (2018: 10, 2022: 7);
under 0.3 quota: 14. Lowest winner per region-election ranged from 0.04 quota (Transport Matters, Eastern Metropolitan 2018)
to 0.92 (Greens, Southern Metropolitan 2022). That is the ticket era: the 2026 rules remove the mechanism that carried
0.04 quota to a seat.

**Shortcut tested.** Rule: each group takes floor(first-preference votes / Droop quota) seats, remaining seats to the
largest remainders. Compared with the actual seats per group:

| Rule | Regions with exactly the right group tally (of 16) | Seats given to the wrong group (of 80) |
|---|---:|---:|
| Full quotas then largest remainder | 4 | 16 |
| D'Hondt on first preferences | 1 | 19 |
| Sainte-Lague on first preferences | 3 | 17 |

In all 12 misses the actual 5th (sometimes 4th and 5th) seat went to a group with a small first-preference vote while the
shortcut gave it to the second-or-third-place major's extra seat or the Greens. Those are ticket outcomes. The test cannot
say how the shortcut does under 2026 rules; it only bounds it: where the shortcut is wrong now, it was wrong by ticket
deals and not by a close contest. **Unconfirmed for 2026**: a Senate post-2016 style result suggests micro-party wins need
roughly half a quota, which would make the shortcut fail only where a minor group is within 0.5 quota of the leaders for
the last seat.

**Cost of the real count (a prototype, not committed).** Inclusive Gregory on weighted ballot profiles: each profile is a full
preference order over candidates (groups x 5 positions, about 110 candidates in Western Metropolitan 2022, 22 groups),
weights re-scaled each draw to the drawn first-preference shares, surplus transferred at surplus/papers, one exclusion at a
time (the VEC may batch exclusions: unconfirmed). Timings, plain R, one core, 30 draws:

| Ballot profiles | ms per draw | counts per draw |
|---|---:|---:|
| 1,000 | 19 | 124 |
| 4,000 | 40 | 124 |

8 regions x 4,000 draws x 40 ms is about 21 minutes in R, too slow for a 5-minute cycle; an Rcpp port (the repo has
`src/seat_sim_core.cpp`) should give 50 to 100 times that (**estimated, not measured**). The prototype was checked only for
running to 5 winners with sensible output on random preferences; it has **not** been validated against any real count
(no 2026-rules data exist; ticket-era distributions are not comparable). It needs a toy unit test with a hand-worked
inclusive Gregory example before it is trusted.

**Recommendation.** Two-stage count per draw: (1) classify each region's seats from the quota shortcut with an
uncertainty band; (2) only when the 5th seat is within a margin (start at 0.5 quota between the last seat's group and the
first loser) run the full count on that region. Report seat probabilities per group per region.

## 4. The night update

Same feed as the Assembly (`Senate` results block in the VEC XML, per voting centre; set-up files arrive 10 November, so
the field names and whether it is counted per group or per candidate are **unconfirmed**). The 2022 files give the voting
centre detail by group (`council-fp-2022.csv`: 2,124 voting centres, with vote type), which is the history to match to.

Carry-over of the Assembly booth-swing update (`R/booth_projection.R`):

1. Match each 2026 voting centre to its 2022 Council row using the same district + booth-name matching as the Assembly;
   the Council has its own early and postal blocks per district.
2. Work at region level, per group: counted share at matched booths against the same booths' 2022 share gives a swing
   (additive on the share scale for the three majors, ratio for minor groups, then renormalise to sum to 1). Project to the
   uncounted booths using their 2022 shares, as the Assembly code does.
3. Pool vote types. In 2022 (n = 3,752,539) ordinary 34.6%, early 49.6%, postal 10.7%, absent 4.6%; the three majors'
   combined share was 71.2% on ordinary, 73.7% early, 77.0% postal, 65.4% absent. So a count made of ordinary booths only
   understates the majors by about 2.5 points and overstates the minor pool by the same: the vote-type pooled swing that
   was added for the Assembly (#160) is required, not optional, for the Council. 2018 split was 48.0 / 37.0 / 7.7 /
   6.7 (ordinary / early / postal / absent), so the mix itself moved: do not use a fixed 2022 mix.
4. Minor groups: counted data per group per region is thin early on. Shrink each group's projected share toward its
   prior by a weight that grows with counted votes (n/(n+k)), not a cutoff (repo rule). A group new in 2026 has no 2022 row:
   use counted share plus the prior pool share.
5. Prior and count combine as the Assembly does (`docs/plans/election-night-booth-model.md`).

Known difference from the Assembly: the Council count goes by region, so one region is 11 districts of booths, and 2022
night counts were only about 20 to 30% of enrolment (from the research on #152, weak evidence), with the full distribution
1.5 to 2.5 weeks later. The night model can only ever give seat probabilities; no declaration.

## 5. What cannot be known on the night

- Preference flows under the new rules (no data). Flows stay a prior; a post-election tally of the distribution of
  preferences would be the first real calibration.
- The group order on the ballot and the how-to-vote cards (after 9 November).
- Whether the VEC's `Senate` feed carries 2CP-like preference data; the Assembly feed carries 2CP, the Council has no
  such concept before the distribution.

## 6. Minimum viable version for 28 November

Goal: shipped only if rehearsed by 25 November (the map's gate). In priority order; stop when time runs out:

1. **Group list and region map** (after 9 November): the 2026 candidate list per region into a tidy table, with ballot-paper
   order and group names mapped to the 2022 names by hand (about 25 groups).
2. **Afternoon prior** (section 1): ALP / Liberal-National / Greens by ratio, pool by remainder, pool split by the
   2022-pattern Dirichlet. One CSV per region.
3. **Quota-shortcut seat odds** with the draws from the prior: the per-group seat probability is the share of draws in which
   the group wins k seats. About a day's work, no new C++.
4. **Night update, first preferences only** (section 4), reusing the Assembly projection; group seats re-derived from
   the updated draws.
5. **Gregory check on the last seat**, only if the Rcpp port and a hand-worked unit test exist; otherwise label the
   fifth seat "too close to call" when within 0.5 quota.

Leave out: below-the-line modelling (9.4% of votes in 2022; treat as the same as above-the-line for the group), within-group
candidate order (show groups, not named members), weighted draws on preference flows beyond the three parameters, batch
exclusion rules, the AEC Senate data pipeline, and anything for the VEC distribution day. Do not feed AE Forecasts' numbers.

Rehearsal: replay 2022 using `council-fp-2022.csv` voting-centre rows in the same way `scripts/night_replay.R` replays the
Assembly, scored on group first-preference share error against final. Seat-odds rehearsal is not possible under the 2026
rules (2022 had tickets); check only that the shortcut reproduces the 4 of 16 and that probabilities are calibrated against
first-preference outcomes.

## Open items and where I looked

- Commencement and Royal Assent: see #157; section 114A and any ticket-era leftovers in the count: unread.
- `forecast-vic2026.json` not read (see section 1).
- AEC Senate Ballot Paper Study table and NSW exhaustion table: found by link, not read.
- No test of the remainder-pool error; no check of Council quotas on Eastern Metropolitan boundaries against the 2022
  footprint (2018 to 2022 region pairing is approximate).
- Looked in: `output/council-*.csv`, `docs/DATA-REGISTRY.md`, `external/reference/aec/` (House only),
  `external/elections/vec-*-vic-firstprefs.csv`, `external/reference/vec/vic-district-regions.csv`, web search (two queries).
