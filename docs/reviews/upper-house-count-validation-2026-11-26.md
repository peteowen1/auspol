# Upper-house count from real ballots: results (26 Nov 2026)

## Needs Pete: how a party that is not standing is replaced

A Senate voter who numbered a party not on a 2026 region's ballot (Trumpet of Patriots stands nowhere; Family First
is missing from two regions) has to be given a substitute. The rule moves the chamber more than anything else here.
Same 4,000 vote draws (16 Nov inputs), only this rule changes. Mean seats of 40; majority = 21 seats.

| Rule (`AUSPOL_UPPER_HOUSE_ABSENT`) | Coalition | One Nation | Greens | Labour DLP (all regions) | Coalition + One Nation reach 21 |
|---|---|---|---|---|---|
| current `count()` (switch off), for reference | 12.46 | 8.75 | 6.68 | 0.49 | 67% |
| "pool": the region's right-wing or left-wing small-party group first (pre-registered) | 11.99 | 8.34 | 7.63 | 0.85 | 46% |
| "bloc": any group of the same side, equally likely, big parties included | 12.40 | 8.78 | 7.57 | 0.15 | 65% |
| "skip": drop the mark, use the voter's next one | 12.03 | 8.82 | 7.78 | 0.08 | 57% |

Under "pool" most of those right-wing votes land on Labour DLP, which is on no Senate ballot, so its 0.85 seats are
mostly this rule, not DLP voters. Recommendation (mine, not decided): "bloc", because it keeps every ballot at the
5-box minimum without handing one small party every stray right-wing mark. The pattern-bank sampling is not what
moves these: a different seed, or 600 + 600 patterns per group instead of 150 + 150, moves no group by more than
0.06 seats and the majority chance by under 1 point.

Plan, written and committed before fitting: [plans/upper-house-count-model-2026-11-26.md](../plans/upper-house-count-model-2026-11-26.md).
Reproduce: `python -I scripts/parse_senate_formal_prefs.py <zip> <prefix>` for each year, then
`Rscript scripts/validate_upper_house_count.R` (set `AUSPOL_SENATE_PREFS_DIR` from a worktree). Code:
`R/upper_house_count.R`, tests `tests/testthat/test-upper-house-count.R`. Switch `AUSPOL_UPPER_HOUSE_COUNT_MODEL`
(published `"0"`).

## The rule being modelled

Electoral Amendment (Miscellaneous Matters) Act 2026 (Act 28/2026, assent 18 Aug 2026; the text passed unamended
from the bill as introduced, https://content.legislation.vic.gov.au/sites/default/files/2026-08/601335bs1.DOCX):

- Group voting tickets removed (ss 6-9).
- New s 93A(2), (3): number at least 1 to 5 above the line (all groups if 5 or fewer), or at least 1 to 5 below.
- New s 112A(2): an above-the-line ballot with fewer than 5 numbers starting at 1 is formal up to the first break;
  a lone 1 is formal. s 112A(3): a tick or cross counts as 1. New s 112B: marked both ways, below the line wins if
  formal.
- The count itself, Electoral Act 2002 s 114A (version 071, in force 19 Aug 2026,
  https://content.legislation.vic.gov.au/sites/default/files/2026-08/02-23aa071-authorised.pdf): quota =
  first preferences / (vacancies + 1), rounded down, + 1; a surplus moves at transfer value = surplus / the elected
  candidate's first-preference votes (s 114A(7)), so papers with no next preference stay in the divisor and their
  share of the surplus is lost. That is what our count does (every paper scaled by (votes - quota) / votes, the
  exhausted ones then dropped). The Act never uses the word "exhaust": papers with no continuing preference simply
  do not move. Not confirmed: the exact divisor for a candidate elected on transfers (s 114A(9), (11)), and whether
  a below-the-line ballot with fewer than 5 numbers is saved.

## The data

AEC formal-preference files for Victoria, one row per ballot paper, saved raw with a manifest (URL, UTC time,
bytes, sha256) in `external/reference/aec/senate-prefs/` (gitignored; 34 MB and 36 MB zipped). Ballot counts equal
the AEC distribution of preferences' formal totals: 4,101,762 (2025) and 3,821,539 (2022).

## How many boxes above-the-line voters number

Share of above-the-line ballots, by the length of the valid run 1, 2, 3, ...; the Senate instruction is at least 6.

| Boxes numbered | 2022 | 2025 |
|---|---|---|
| 1 only | 2.2% | 2.0% |
| 2 to 5 | 3.5% | 3.0% |
| exactly 6 | 87.6% | 87.7% |
| 7 or more | 6.7% | 7.3% |
| every box | 0.3% (26 groups) | 0.5% (20 groups) |

Below the line: 5.2% and 5.0% of all ballots. Nearly nine in ten voters number exactly the instructed minimum, so the
model assumes those voters number exactly 5 in Victoria.

## Where the next preference goes

Full matrices with n per cell and the shrunk share: `external/reference/aec/senate-flows/vic-senate-{2022,2025}-flow-matrix.csv`.
Top four next preferences, 2025, by first-preference party (share of that party's ballots; EXH = numbered nothing
after it):

| First preference | Ballots | Next preference (top 4) | EXH |
|---|---|---|---|
| Labor | 1,422,364 | Legalise Cannabis 27.3%, Greens 27.1%, Liberal 12.7%, Family First 7.5% | 2.6% |
| Liberal / Nationals | 1,288,356 | Family First 35.8%, One Nation 16.7%, Labor 10.6%, Legalise Cannabis 9.5% | 2.1% |
| Greens | 510,835 | Labor 42.5%, Victorian Socialists 24.6%, Legalise Cannabis 7.5%, Animal Justice 4.8% | 0.9% |
| One Nation | 182,228 | Liberal 18.8%, Trumpet of Patriots 17.4%, Family First 15.4%, Libertarian 11.0% | 1.9% |
| Legalise Cannabis | 148,739 | Animal Justice 22.6%, Labor 16.3%, Greens 13.1%, Liberal 9.2% | 2.3% |
| Victorian Socialists | 63,093 | Greens 64.3%, Legalise Cannabis 6.9%, Labor 6.5%, centre pool 5.7% | 0.8% |

The 2022 rows differ a lot where the how-to-vote cards differed (2022 Labor: Greens 54.5%, Liberal 9.5%; 2022
Liberal: United Australia 40.3%). That is the main limit of the method, measured below.

## Validation (all three pre-registered checks pass)

Group letters in the order elected; actual from the AEC distribution of preferences.

| Check | 2022 (actual D K D K U L: Lib, Lab, Lib, Lab, Thorpe GRN, Babet UAP) | 2025 (actual I A I A Q I: Lab, Lib, Lab, Lib, GRN, Lab) |
|---|---|---|
| V0, real ballots through our count | match | match |
| V1, model with the same year's flows, 3 seeds | match x3 | match x3 |
| V2, model with 2022 flows (time-forward) | | match x3 |
| current `count()` (bloc 2.5, exhaust 17.5%) | match (73% of its own random draws) | match (100%) |

Seats by party cannot tell good flows from bad here: four of six seats are whole quotas, and a flow set with every
party's ballots shuffled to another party still elects the actual six. So the sharper test follows the REAL count's
path (its order of elections and exclusions) and measures, after each step, how much of a quota sits with the wrong
group compared with the real ballots. Lower is better; quotas.

| Ballot model | 2022: wrong-group mean / final | 2022: exhausted error final | 2025: wrong-group mean / final | 2025: exhausted error final |
|---|---|---|---|---|
| measured flows, same year | 0.011 / 0.013 | 0.003 | 0.007 / 0.005 | 0.008 |
| measured flows, 2022 for 2025 (time-forward) | | | 0.028 / 0.031 | 0.090 |
| 2022 flows with parties shuffled (should be bad) | 0.032 / 0.018 | 0.104 | | |
| current `count()` | 0.030 / 0.034 | 0.024 | 0.025 / 0.028 | 0.039 |

Reading: with the right year's ballots the model is three to four times closer than the assumed rule. Carried to a
different election (2022 flows on 2025) it is only as good as the assumed rule on where votes go, and worse on
exhaustion, because how-to-vote cards changed. For Victoria 2026 the flows come from the 2025 Senate, a federal
election with different cards from a state one, so expect the time-forward accuracy, not the in-sample one.

Exhaustion through our count on real ballots is 174,096 at the last decision in 2025 against the AEC's 185,736, and
246,795 against 261,868 in 2022: about 6% low. The cause is not established (counting by group rather than by
candidate, and the Senate's own transfer rules, are both candidates).

Other upper houses (reported, not a pass condition; statewide first preferences from branch `other-upper-houses`;
actual results from Wikipedia, ECSA and NSWEC not checked):

- NSW LC 2023, 21 seats, flows from the 2022 Senate (actual Labor 8, Coalition 7, Greens 2, One Nation 1, Legalise
  Cannabis 1, Liberal Democrats 1, Shooters 1). With NSW's 1-box minimum applied (Senate ballots that stopped at 6
  stop at 1): match on both seeds. Without it: match on one seed, Animal Justice instead of the Shooters on the other.
- SA LC 2026, 11 seats, flows from the 2025 Senate (actual Labor 5, One Nation 3, Liberal 2, Greens 1): match on all
  four runs.
- The current `count()` also matches both. As with the Senate, seats by party is a weak test.

## The forecast with the switch on

Same 4,000 simulations of the vote (the aff / ex draws still run, so the vote draws are identical), only the count
differs. Inputs: the main checkout's `output/` (lower-house run of 16 Nov), so the levels are not today's; the
difference between the two counts is the point.

Mean seats of 40, and the chance of a majority (21):

| | count() (now) | measured (switch 1) |
|---|---|---|
| Labor | 9.98 | 10.17 |
| Coalition | 12.46 | 11.99 |
| One Nation | 8.75 | 8.34 |
| Greens | 6.68 | 7.63 |
| Minor groups | 2.13 | 1.87 |
| Coalition + One Nation reach 21 | 67% | 46% |
| Labor + Greens reach 21 | 1% | 6% |

The Greens gain most (Labor voters' second choices, 27%, and Socialist voters', 64%, reach them), the Victorian
Socialists lose (Northern Metropolitan 0.31 to 0.10 seats: Labor voters give them 1.4%, not the bloc-level favour the
old rule assumed), and Labour DLP gains (Eastern Victoria 0.05 to 0.18). The DLP gain is partly an artefact of the
mapping: DLP is on no Senate ballot, and a right-wing party a Senate voter numbered that is not standing in a region
(Trumpet of Patriots everywhere, Family First in two regions) is replaced by the region's right-wing pool group
first, which is usually DLP. Worth a look before shipping.

These numbers use the "pool" rule; see the top for the other two. Run time: 1 min 44 s for the whole script at 4,000 simulations x 8 regions (about 90 s of it the count), against
15 s with `count()`.

## What is approximated

- Group-level count: a group's votes stay with it until it is excluded or out of candidates; every ballot in an
  elected group's pile is reduced by the same factor (inclusive Gregory). On real ballots this reproduced both
  Senate results exactly, with exhaustion about 6% low.
- Ballot patterns per group: the 150 most common class sequences exactly plus 150 weighted draws for the rest
  (seeded per region). Seed-to-seed exhaustion varies by about 0.02 quotas.
- Party mapping: a party a Senate voter numbered that is not on a region's ballot is replaced by a group of the same
  bloc there (left / right / centre), else dropped. Ballots that stopped at the minimum still number 4.93 to 5.00
  boxes on average after mapping, so exhaustion is not inflated by dropped parties.
- Shrinkage toward the bloc (K = 200 ballots) barely binds: the smallest named party has 9,810 first preferences.
  Groups on no Senate ballot (Labour DLP, Socialist Alliance in 2025, The Republican, The West Party, Christian
  Alliance, unnamed and ungrouped) use their bloc's pooled voters entirely.
