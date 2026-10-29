# The eight contested value seats, Victoria 2026: is each a problem, and what would settle it (2026-10-28)

Pete asked: for the top "contested" rows of the value table (our probability far above the bookmakers'), what work
would fix them, or would show they are not a problem at all.

Inputs: the published forecast built 27 Oct 05:52 UTC (`forecast-latest`, git `d1c52e8`); Sportsbet and Betfair
prices fetched 28 Oct, TAB from the 27 Oct 05:03 UTC capture; `output/backtest-vs-market-seats.csv`;
`output/published-predictions.csv` (vic2022, sa2026, qld2017 rows); `output/seat-swing-port-vic2026.csv`;
`output/onp-senate-vic2026.csv`. Earlier review of the same disagreement: `market-disagreement-vic2026-2026-10-25.md`.
Nothing here was re-run through the model; every model number is read from a published file. Read-only.

## What the history says before any seat

When we and the bookmakers disagreed by more than 0.3 on the actual winner's probability (fed2022, fed2025, qld2020,
sa2022; Pete's saved odds), **we were closer in 61 of 69 seats**; mean log loss 0.168 against the market's 0.648
(lower is better). Above 0.5 disagreement: 4 of 5. The worst cases for us were fed2025 independents and Coalition
holds (Monash, Wannon, Flinders, Berowra). These elections were tuned on, so this flatters us, and none had a One
Nation vote near 21.8%.

## Group 1: eastern-suburbs Labor (Box Hill, Glen Waverley, Ashwood, Bayswater)

| Seat | Back | Ours | Bookies | Labor sitting? | 2025 federal swing in its booths, points to Labor | vic2022 backtest Labor miss (ours − actual) |
|---|---|---:|---:|---|---:|---:|
| Box Hill | Labor | 0.88 | 0.26 | yes (Hamer) | +2.96 | −4.9 |
| Glen Waverley | Labor | 0.50 | 0.12 | yes (Mullahy) | +4.53 | −2.6 |
| Ashwood | Labor | 0.70 | 0.21 | yes (Fregon) | +2.54 | −5.1 |
| Bayswater | Labor | 0.22 | 0.05 | no, departing | +5.63 | −4.4 |

Probabilities are win probabilities (0 to 1). Negative miss = we under-called Labor in 2022.

**For us:** these booths swung TO Labor federally in 2025 while the state swung away, and in 2022 we under-called
Labor in all four. **For the bookies:** Labor's statewide two-party vote falls about 6.9 points in our own forecast
and every one of these has a Labor margin under 8. **One analog leans their way a little:** in sa2026, in the third of
seats where we predicted One Nation lowest (n 15), we under-called the Liberals by 3.5 points and Labor by 2.2, so the
majors kept more where One Nation was weak, the Liberals slightly more. That is about 1.3 points relative, from one
election.

**Update, same day: the uniform-swing reading is not supported** (`new-party-fill-proportional-vs-uniform-2026-10-28.md`,
Sonnet agent; sa2026 Labor slope recomputed independently: b −1.17, n 46). In sa2026, qld2017, qld2024 and sa2018
each major's seat loss scaled with the new party's seat share (pooled b −0.81 Labor, −0.68 Coalition, where −1 is
exactly proportional and 0 is uniform; SE clustered on election, 4 elections). Proportional beat uniform on error in
all 8 election-by-major cells, and our backtests do not over-call the majors in low-new-party seats. So work item 2
below is DONE and favours us. What it cannot judge: the statewide One Nation level, candidates, the xgb cut.

**Is it a problem? Narrower now.** The 25 Oct review's ~3 point xgb cut to the Liberal is inferred by subtraction, never
traced.

Work, in order:
1. **Stage walk for these four seats** (base swing, One Nation fill, xgb, port, seat polls), so the xgb figure is
   measured. About 15 minutes of R. Settles whether one stage is doing all the work.
2. **Test the mechanism on the analog elections**: in sa2026, qld2017 and sa2018 (SA-Best), regress each major's
   seat-level loss on the new party's seat share. Proportional fill (ours) predicts the loss scales with the new
   party's share; a uniform swing (the market) predicts it does not. This is the decisive research and needs no new
   data. Related prereg already queued: `plans/prereg-level-conserve-2026-10-25.md`.
3. **Check the implied statewide two-party vote**: sum our seat two-candidate results into a statewide Labor figure and
   compare with the polls. If the seats imply a Labor two-party well above the statewide level, the seats are
   inconsistent with our own level.

## Group 2: One Nation allocation (Hastings, Narracan, Eureka, Cranbourne)

| Seat | Back | Ours | Bookies | One Nation candidate named? | 2025 Senate One Nation % | Our ONP primary |
|---|---|---:|---:|---|---:|---:|
| Hastings | One Nation | 0.62 | 0.25 | no | 6.60 | 29.8 |
| Narracan | One Nation | 0.53 | 0.20 | yes (Ben Lucas) | 9.16 | 34.4 |
| Eureka | One Nation | 0.87 | 0.46 | yes (Paul Ballinger) | 7.39 | 31.4 |
| Cranbourne | Labor (bookies favour One Nation 0.45; ours 0.22) | 0.76 | 0.38 | no | 5.52 | 26.0 |

**History runs against the bookies here too.** In sa2026, our One Nation win probabilities were calibrated (34 seats
under 10%: 0 won, 0.7 expected; 10 seats at 10-30%: 2 won, 2.0 expected; 3 above 30%: 2 won, 1.9 expected), and we
UNDER-called One Nation's vote in every third of seats (by 2.5 to 3.8 points). qld2017: under by 4.6 to 6.2. So our
errors in the one live analog ran the opposite way to the bookies' disagreement in Hastings, Narracan and Eureka.
n is small: one election, five winners.

Per seat:
- **Hastings, Cranbourne: no One Nation candidate named yet.** We simulate a generic One Nation candidate; the
  bookies may be pricing the chance of a weak or absent one. Resolves at nominations, 9 Nov 12 noon. Work: none
  before then; recheck these two the day nominations land.
- **Narracan: NOT the defect first suspected (corrected the same day, after tracing).** Its 2022 baseline is the
  28 Jan 2023 supplementary election (`scripts/fit_seats_full.R:345`), which Labor did not contest: LNP 45.0, other
  right 19.6, independent 15.9, Greens 11.1, One Nation 6.0, Labor none. The first draft said Labor and Greens were
  "both exactly 10.11, a fill value". They are 10.1148 and 10.1145 (`seat-shares-vic-2026.csv`): equal to two
  decimals by coincidence. Labor comes from the majors re-entry carry (`AUSPOL_REENTRY="majors"`: its own 2018 share,
  35.5, carried forward by the statewide change), and 10.1 is plausible: in the 2025 federal election Labor took only
  17.3% in Narracan's booths (`external/elections/federal-transposed-to-state.csv`).
  - **A smaller, real issue (inferred, not traced):** the Greens' 2023 base (11.1) was inflated by Labor's absence.
    They took 6.0 in 2018, 9.0 in 2014, and 4.4 federally in 2025, so 10.1 is probably 4 to 5 points high. That
    excess is taken back from every other party in proportion, so it barely moves One Nation against the Liberal.
    General form, for every election: a class's base from a contest a major skipped carries that major's absent
    vote. Work: measure it on backtest seat-elections where a major re-entered (the re-entry prior's fit rows) before
    building anything.
  - **What actually drives Narracan:** One Nation's 2025 Senate vote there is 9.16%, rank 3 of 88, so it lands near
    the top of SA 2026's spread. That is the same question as Eureka (below), not a Narracan-specific defect.
- **Eureka: likely too confident.** Both sides favour One Nation; our 0.87 comes from Eureka sitting near the top of
  the Senate ranking, mapped onto the top of SA 2026's spread. Work: rerun the live forecast with the spread taken
  from sa2026 and qld2017 pooled instead of sa2026 alone, and report Eureka's probability under each.
- **Cranbourne: we are LOWER on One Nation than the bookies.** In 2022 the other-right vote there was 14.9 (our 2022
  backtest had 6.3). Work: check whether the 2022 other-right vote is carried into One Nation's 2026 allocation;
  the Senate ranking alone puts Cranbourne mid-table.

## Recommended order

1. Stage walk for the four eastern seats (measures the inferred number).
2. Proportional-vs-uniform test on sa2026 / qld2017 / sa2018 (decides Group 1).
3. One Nation spread sensitivity (Eureka and Narracan: Senate ranks near the top).
4. After 9 Nov: recheck Hastings and Cranbourne with real candidates.
5. Re-entry inflated-base measurement (Narracan Greens is the live case; small effect on winners).
