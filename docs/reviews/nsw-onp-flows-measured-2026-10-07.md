# NSW One Nation and Greens preference flows, measured from our own data

2026-10-07. Analysis only: no model code, `published_flags.R` or anchor file was changed. Every number below is printed by `scripts/measure_nsw_flows.R` (run `powershell.exe -Command 'Rscript "scripts/measure_nsw_flows.R"'` from the repo root).

## Headline

- **Our 2027 One Nation (ONP) exhaust assumption (57.0%) is right on 2023 and low on 2019 and on Antony Green.** Measured exhaust: 56.9% (2023, 16 seats, SE 1.2), 64.3% (2019, 12 seats, SE 1.5), 59.8% pooled (28 seats). Green: 62.2%.
- **Our 2027 ONP flow to Labor (25.5% of non-exhausted) is too low, by about 10 points on the anchor's own convention.** Measured Labor share of (Labor + Coalition): 35.1% (2023, SE 1.8), 38.1% (2019, SE 3.3), 36.0% pooled (28 seats, SE 1.6). Green's equivalent is 31.0%. Even the 2019 and Green figures, the lowest, are 5.5 to 6 points above 25.5.
- **Our 2023 Greens row in the anchor (87.1% to Labor, 39.7% exhausted) is the 2019 row copied.** Measured 2023 Greens exhaust is 30.6% to 35.4% depending on definition, never 39.7%. Only the 2019 Greens, followed to final destination, gets near it (39.9%).
- **No definition we can build from the distribution-of-preferences pages reproduces Green's Greens figures exactly.** Closest: Greens excluded when only two candidates remain (final-two), 60.3 / 9.2 / 30.6 against his 59.5 / 7.3 / 33.2.

## Data and method

Source: the 186 cached NSWEC distribution-of-preferences (DOP) pages in `external/reference/nsw/dop` (`SG1901-*` 2019, `SG2301-*` 2023, 93 seats each; registry lists them under the NSW cache). I did **not** use `external/elections/nswec-nsw-transfers.csv`: it collapses parties into classes (`OTH`, `OTH_RIGHT`) and drops the exhausted row, and exhaustion is the quantity in question. First-preference counts come from `sge2019/2023-la-final-votes.xlsx` (formal votes summed over venues).

For each exclusion the page prints how many votes went to each continuing candidate and how many exhausted. The script sums them to "votes distributed". Integrity check passed: candidate transfers plus exhausted equal the printed votes distributed on 758 of 758 exclusions (zero difference). The last exclusion in every seat is the one that leaves two candidates.

Definitions used throughout:
- **Labor** = ALP (2023), LAB (2019 label for Labor) and CLP (Country Labor, 2019 only, a Labor brand in rural seats).
- **Coalition** = LIB or NAT. **One Nation** = ON (2023 code) or PHON (2019 code).
- **Votes distributed** includes ballots the excluded candidate received from earlier exclusions, not only their own first preferences.
- **Pooled** = sum of votes across seats, not the mean of seat shares. **SE** = standard error of the pooled ratio with the seat as the independent unit (ratio estimator). It is not computed for single-seat groups.
- "Other" = votes to any continuing candidate who is neither Labor nor Coalition (Greens, independents, Shooters, Country Labor aside).

## 1. One Nation

ONP stood in 17 seats in 2023 and 12 in 2019. In 2023 it was excluded in 16; in Cessnock (8,059 first preferences) it reached the final two against Labor, so nothing was distributed there. In 2019 it was excluded in all 12.

### Per seat, 2023

Each row is one ONP exclusion: votes distributed, then where they went as a percentage of votes distributed (the four percentages sum to 100). "Others left" shows who else was still in the count; final-two means only Labor and the Coalition remained.

| Seat | Votes distributed | To Labor % | To Coalition % | To other % | Exhausted % | Continuing candidates | Final two? |
|---|--:|--:|--:|--:|--:|---|---|
| Badgerys Creek | 4,655 | 13.7 | 32.8 | 0.0 | 53.4 | ALP, LIB | yes |
| Camden | 8,039 | 16.5 | 27.2 | 0.0 | 56.3 | ALP, LIB | yes |
| Campbelltown | 6,292 | 15.9 | 21.0 | 0.0 | 63.2 | ALP, LIB | yes |
| Cronulla | 3,635 | 5.9 | 33.3 | 5.0 | 55.7 | ALP, GRN, LIB | no |
| Hawkesbury | 6,587 | 18.4 | 25.6 | 0.0 | 56.0 | ALP, LIB | yes |
| Holsworthy | 4,683 | 21.5 | 29.4 | 0.0 | 49.1 | ALP, LIB | yes |
| Hornsby | 5,213 | 10.8 | 22.2 | 6.1 | 60.9 | ALP, GRN, LIB | no |
| Leppington | 4,191 | 19.7 | 31.5 | 0.0 | 48.8 | ALP, LIB | yes |
| Londonderry | 4,596 | 15.0 | 29.3 | 0.0 | 55.7 | ALP, LIB | yes |
| Maitland | 5,198 | 15.6 | 30.0 | 0.0 | 54.4 | ALP, LIB | yes |
| Parramatta | 2,613 | 12.3 | 34.0 | 6.7 | 47.0 | ALP, GRN, LIB | no |
| Penrith | 4,719 | 17.8 | 26.0 | 0.0 | 56.2 | ALP, LIB | yes |
| Port Stephens | 7,218 | 11.7 | 22.8 | 0.0 | 65.5 | ALP, LIB | yes |
| Wallsend | 3,738 | 11.9 | 25.7 | 4.7 | 57.7 | ALP, GRN, LIB | no |
| Wollondilly | 6,298 | 4.7 | 22.9 | 15.7 | 56.8 | ALP, IND, LIB | no |
| Wyong | 7,329 | 16.1 | 23.7 | 0.0 | 60.1 | ALP, LIB | yes |

### Per seat, 2019

Same layout. Labor appears as LAB; CLP is Country Labor (counted as Labor).

| Seat | Votes distributed | To Labor % | To Coalition % | To other % | Exhausted % | Continuing candidates | Final two? |
|---|--:|--:|--:|--:|--:|---|---|
| Blacktown | 3,707 | 16.8 | 19.9 | 0.0 | 63.3 | LAB, LIB | yes |
| Camden | 9,003 | 10.0 | 19.5 | 0.0 | 70.4 | LAB, LIB | yes |
| Goulburn | 4,905 | 7.8 | 12.5 | 18.9 | 60.8 | CLP, LIB, SFF | no |
| Holsworthy | 4,223 | 11.6 | 22.6 | 0.0 | 65.8 | LAB, LIB | yes |
| Hornsby | 2,481 | 4.3 | 22.7 | 13.9 | 59.1 | GRN, IND, LAB, LIB | no |
| Kogarah | 2,872 | 9.3 | 16.0 | 9.7 | 65.0 | GRN, LAB, LIB | no |
| Maitland | 6,728 | 18.6 | 14.4 | 0.0 | 67.0 | CLP, LIB | yes |
| Miranda | 3,775 | 12.6 | 27.0 | 0.0 | 60.4 | LAB, LIB | yes |
| Murray | 4,236 | 3.5 | 7.8 | 20.9 | 67.8 | CLP, NAT, SFF | no |
| Oatley | 2,276 | 10.7 | 27.2 | 5.3 | 56.8 | GRN, LAB, LIB | no |
| Penrith | 4,297 | 15.2 | 18.4 | 0.0 | 66.3 | LAB, LIB | yes |
| Wollondilly | 6,634 | 6.1 | 12.4 | 23.3 | 58.2 | CLP, IND, LIB | no |

### Pooled, share of all ballots distributed

Percent of the votes distributed at ONP exclusions (sum of votes across seats), with the seat count and the SE across seats (percentage points). Compare with Green's 11.7 / 26.1 / 62.2 for 2023. Exhausted is the share of ballots that carry no further preference, so higher means fewer reach any candidate.

| Set | Seats | Votes distributed | To Labor | SE | To Coalition | SE | To other | Exhausted | SE |
|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|
| 2023, all ONP exclusions | 16 | 85,004 | 14.4 | 1.1 | 26.6 | 1.0 | 2.2 | 56.9 | 1.2 |
| 2023, ONP excluded with others left | 5 | 21,497 | 8.5 | 1.7 | 26.3 | 2.3 | 8.6 | 56.6 | 1.8 |
| 2023, final-two (only Labor and Coalition left) | 11 | 63,507 | 16.3 | 0.8 | 26.7 | 1.1 | 0.0 | 57.0 | 1.6 |
| 2019, all ONP exclusions | 12 | 55,137 | 10.8 | 1.5 | 17.5 | 1.6 | 7.4 | 64.3 | 1.5 |
| 2019, ONP excluded with others left | 6 | 23,404 | 6.6 | 0.9 | 14.6 | 2.3 | 17.5 | 61.3 | 1.8 |
| 2019, final-two | 6 | 31,733 | 13.8 | 1.7 | 19.6 | 1.6 | 0.0 | 66.5 | 1.5 |
| 2019 + 2023, all | 28 | 140,141 | 13.0 | 1.0 | 23.0 | 1.2 | 4.2 | 59.8 | 1.2 |
| 2019 + 2023, final-two | 17 | 95,240 | 15.5 | 0.8 | 24.3 | 1.2 | 0.0 | 60.2 | 1.6 |

### Pooled, share of non-exhausted ballots

Percent of the ballots that went to a candidate (exhausted removed), pooled over seats. "Labor / (Labor + Coalition)" is the anchor's convention (its `preference-estimates.csv` has a Labor flow and an exhaust rate, and the rest goes to the Coalition; there is no "other"), so it is the row to compare with 25.5. Higher means more help to Labor. Seat range is the lowest and highest single-seat value.

| Set | Seats | Labor of non-exhausted | SE | Coalition of non-exhausted | Other of non-exhausted | Labor / (Labor + Coalition) | SE | Seat min | Seat median | Seat max |
|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|
| 2023, all | 16 | 33.3 | 2.5 | 61.7 | 5.0 | 35.1 | 1.8 | 15.1 | 34.1 | 43.1 |
| 2023, final-two | 11 | 38.0 | 1.2 | 62.0 | 0.0 | 38.0 | 1.2 | 29.4 | 38.5 | 43.1 |
| 2019, all | 12 | 30.2 | 4.7 | 49.0 | 20.8 | 38.1 | 3.3 | 15.8 | 33.9 | 56.4 |
| 2019, final-two | 6 | 41.4 | 4.5 | 58.6 | 0.0 | 41.4 | 4.5 | 31.8 | 39.6 | 56.4 |
| 2019 + 2023, all | 28 | 32.2 | 2.3 | 57.2 | 10.5 | 36.0 | 1.6 | 15.1 | 33.9 | 56.4 |
| 2019 + 2023, final-two | 17 | 38.9 | 1.5 | 61.1 | 0.0 | 38.9 | 1.5 | 29.4 | 38.5 | 56.4 |

Observations:
- In all 11 final-two seats in 2023 (and 6 in 2019) "to other" is 0 by construction. Where other candidates remained (5 seats in 2023, 6 in 2019) 9% to 17.5% of ballots went to them, and Labor's share falls (8.5% in 2023, 6.6% in 2019) because Greens, independents and Shooters candidates take ONP ballots that would otherwise reach Labor or the Coalition. That is why the anchor's convention (no "other") understates the Labor share if applied naively to the full distribution; the Labor / (Labor + Coalition) row removes this.
- Exhaust is stable across final-two and non-final-two seats in 2023 (56.6% to 57.0%) but ranges 47.0% to 65.5% across seats.

### Followed to final destination (model, not a measurement)

A DOP page shows where an excluded candidate's whole pile goes at one step; some of it goes to a candidate excluded later. Following ONP's own first-preference ballots to the end, assuming each candidate's pile is evenly mixed (a ballot that arrived by transfer behaves like every other ballot in that pile), gives, as percent of ONP first preferences: 2023 (16 seats, 76,624 ballots) Labor 14.5, Coalition 26.7, other 1.4, exhausted 57.4; 2019 (12 seats, 49,948 ballots) Labor 10.7, Coalition 18.2, other 4.7, exhausted 66.4. These are within 1 point of the pooled DOP figures above on Labor, Coalition and exhaust, except 2019 "other" (4.7 against 7.4) and 2023 other (1.4 against 2.2). Real routing needs ballot-level data, which we do not hold, so these are a robustness check only.

## 2. Greens, NSW 2023 and what produces Green's figures

Antony Green: Greens 2023 are 59.5% to Labor, 7.3% to Coalition, 33.2% exhausted (sums to 100, so no "other"). Anchor 2023 row: 87.1% to Labor of non-exhausted, 39.7% exhausted. Greens stood in 93 seats and were excluded in 89 (in four they reached the final two).

Percent of the Greens votes distributed. Each row is a definition. Labor / (Labor + Coalition) is in the last column (Green's 59.5 / 66.8 = 89.1; the anchor's 2023 value is 87.1).

| Definition (Greens 2023) | Seats | Votes distributed | To Labor | To Coalition | To other | Exhausted | Labor / (Labor + Coalition) |
|---|--:|--:|--:|--:|--:|--:|--:|
| A. Every Greens exclusion, pooled | 89 | 422,973 | 52.3 | 8.2 | 7.5 | 32.1 | 86.4 |
| B. Greens excluded at the final-two count only | 43 | 262,607 | 60.3 | 9.2 | 0.0 | 30.6 | 86.8 |
| D. Greens exclusions that were not final-two | 46 | 160,366 | 39.2 | 6.6 | 19.7 | 34.5 | 85.6 |
| Greens first-preference ballots followed to final destination (model) | 89 | 379,574 | 49.6 | 9.1 | 5.9 | 35.4 | 84.5 |
| Green's published figure | n/a | n/a | 59.5 | 7.3 | 0 | 33.2 | 89.1 |

Finding: **B reproduces his shape (no "other", Labor near 60, exhaust near a third) and is the closest, but not equal: 0.8 points low on Labor, 1.9 high on Coalition, 2.6 low on exhaust.** Mean of seat shares in B is 59.1 / 9.5 / 31.3. A is closest on exhaust (32.1 against 33.2) but has 7.5% going to "other", which his figures do not. The inference that he used final-two exclusions or ballot-level end-of-count destinations is plausible but unconfirmed: I could not reproduce 7.3% Coalition or 33.2% exhausted under any single definition tested, and ballot-level data is needed to say more. Standard errors on A are 1.5 (Labor) and 0.7 (exhaust); on B 1.1 and 0.9, so his 33.2 exhaust is about 3 SE above B and 1.6 SE above A.

Per-seat Greens exhaust under definition A: median 33.7%, mean 33.5%, range 19.0% to 50.5% (SD 5.9). The 2023 range shows how much one seat set can move the figure.

### Where does 39.7% come from?

Not 2023. Greens 2019, same method:

| Greens 2019 | Seats | To Labor | To Coalition | To other | Exhausted | Labor / (Labor + Coalition) |
|---|--:|--:|--:|--:|--:|--:|
| A. Every Greens exclusion, pooled | 86 | 48.7 | 8.7 | 4.7 | 37.9 | 84.8 |
| B. Final-two exclusion only | 52 | 52.8 | 9.3 | 0.0 | 36.3 | 85.0 |
| Greens first-preference ballots followed to final destination (model) | 86 | 47.9 | 9.1 | 3.1 | 39.9 | 84.0 |

The anchor holds the identical pair (87.1, 39.7) for 2019 and 2023, which `docs/reviews/flow-record-integrity-2026-08-18.md` already lists as a carried-forward duplicate. The only measure that lands near 39.7 is the 2019 final-destination model (39.9), so the likeliest reading is that 39.7 is a 2019-era exhaustion figure copied into 2023, not a 2023 measurement. That is an inference: I did not find the source of the number (searched `external/aus-polling-analyser` analysis scripts and `provenance.json`, which only describe the file, not how each value was derived). The 87.1 matches none of our definitions (our Labor / (Labor + Coalition) is 84 to 87 for Greens 2019 and 2023).

Direction: our 2023 anchor exhaust (39.7) is **too high by 4.3 to 9.1 points** against the 2023 measurements above (35.4 and 30.6), and the 2027 value (33.2, taken from Green) sits inside the 2023 measured range (30.6 to 35.4).

## 3. Comparison with Green's One Nation 2023 and the 2027 anchor assumption

Percent of ONP ballots. "Anchor 2027" is the file's ONP row (25.5 to Labor of non-exhausted, 57.0 exhausted; coalition share is the remainder, no "other"), converted to shares of all ballots: Labor 11.0, Coalition 32.0, exhausted 57.0. The last column says whether the 2027 assumption is above or below the measurement.

| Measure | Green 2023 (17 seats) | Ours 2023 (16 seats) | Ours 2019 (12 seats) | Ours pooled (28 seats) | Anchor 2027 | 2027 against our 2023 measurement |
|---|--:|--:|--:|--:|--:|---|
| To Labor, % of all ballots | 11.7 | 14.4 (SE 1.1) | 10.8 (SE 1.5) | 13.0 (SE 1.0) | 11.0 | 3.4 low (about 3 SE) |
| To Coalition, % of all ballots | 26.1 | 26.6 (SE 1.0) | 17.5 (SE 1.6) | 23.0 (SE 1.2) | 32.0 | 5.4 high (about 5 SE) |
| Exhausted, % of all ballots | 62.2 | 56.9 (SE 1.2) | 64.3 (SE 1.5) | 59.8 (SE 1.2) | 57.0 | 0.1 (match) |
| Labor / (Labor + Coalition), anchor's convention | 31.0 | 35.1 (SE 1.8; seats 15.1 to 43.1) | 38.1 (SE 3.3; seats 15.8 to 56.4) | 36.0 (SE 1.6) | 25.5 | **9.6 low (about 5 SE)** |

Plain reading:
- **Exhaust: our 2027 57.0% matches our 2023 measurement (56.9%) and is 5.3 below Green's 62.2% and 7.3 below our 2019 (64.3%).** The pooled 2019 and 2023 figure is 59.8%. Against the pooled figure the assumption is 2.8 points low (about 2 SE); against the more recent election it is right. Low exhaust means ONP preferences stay in the count more, which feeds the Coalition (see below), so "too low" is the direction that helps the Coalition.
- **Flow to Labor: too low.** On the anchor's convention, 25.5 against measured 35.1 (2023), 38.1 (2019), 36.0 (pooled): 9.6 to 12.6 points low, outside every seat-pooled interval (95% intervals about 31.6 to 38.6 for 2023, about 31.6 to 44.6 for 2019). Only 3 of the 28 ONP exclusions have a seat value at or below 25.5 (Cronulla 2023 at 15.1, Hornsby 2019 at 15.8, Wollondilly 2023 at 16.9), and all three had Greens or independents still in the count. The file's own comment says 25.5 is the federal rate (federal 2025 is 26.2 in the same file); federal flows are full-preferential, so there is no exhaust and no "other" step, and NSW ONP ballots that stay in the count go to Labor more often than that rate says.
- **Flow to the Coalition: too high in 2027.** The anchor puts 32.0% of all ballots to the Coalition against 26.6% measured in 2023 (17.5% in 2019). This follows from assigning every non-Labor, non-exhausted ballot to the Coalition: it implicitly gives ONP's "other" preferences (2.2% in 2023, 7.4% in 2019, mostly Greens and independents, in the seats where they were still in the count) to the Coalition as well.
- Against Green: his Labor flow is 2.7 points below our 2023 pooled (11.7 against 14.4, about 2.5 SE) and his exhaust is 5.3 above (62.2 against 56.9, about 4 SE); Coalition matches (26.1 against 26.6). **I cannot explain the exhaust gap.** His 58.9% "1-only" ONP ballots in 2023 sets a floor of 58.9% exhaust on ONP first preferences, yet our 16-seat DOP and our final-destination model give 56.9% and 57.4%. Candidate reasons, none confirmed: he includes Cessnock (ONP in the final two, so its 1-only ballots exhaust in his tally but nothing is distributed in ours); he works from ballot-level data we do not hold; he treats the final-two count differently.

## What I could not measure

- **Ballot-level routing.** We hold DOP totals only, not ballot files. The 1-only rates (ONP 58.9%, Coalition 73.0% and 75.2%) cannot be reproduced from our data, and the final-destination rows are a mixing model.
- **Green's exact seat set and denominators.** His "17 contested seats" matches ONP candidates in 2023 (17 in the first-preference workbook), but only 16 have an ONP exclusion in the DOP. Whether his 11.7 / 26.1 / 62.2 use ballots, first preferences or votes distributed is not stated in what we hold.
- **The origin of the anchor's 87.1 / 39.7 and 37.7 / 71.1 (ONP 2023) values.** Our own 2023 ONP measurement (33.3 of non-exhausted, 56.9 exhausted) does not reproduce the anchor's 2023 ONP row (37.7 to Labor, 71.1 exhausted) either: 71.1 is 14.2 points above our 2023 ONP exhaust and above the highest single ONP seat (65.5; 2019 reaches 70.4 in Camden). The 2019 ONP anchor row (42.0 / 60.4) is also not reproduced (30.2 / 64.3 all exclusions; 41.4 final-two only, which does match 42.0 within 0.6).
- **Only 28 ONP exclusions exist across both elections.** The seat-to-seat SD of Labor / (Labor + Coalition) is 9.1 points, so any seat-specific 2027 flow carries a wide range even if the pooled mean is well measured.

## Next step for the model (not done here)

Replace 25.5 with a shrunk estimate pooled over 2019 and 2023 (about 36, SE about 1.6, 28 seats) and split the flow into Labor, Coalition and "other" rather than forcing "other" into the Coalition. The exhaust rate of 57.0% can stay for 2027 on the 2023 evidence; the pooled 59.8% is the conservative alternative. Changing the anchor's carried-forward 2023 Greens and ONP rows (87.1 / 39.7 and 37.7 / 71.1) should go through the anchor's owner, since we do not edit that clone.

## Leakage check on how the backtests read these flows (2026-10-07)

- **Shipped path is clean.** `R/forecast_mode.R:110-113` reads flows with `as_of` = the cycle start;
  at that date the target is not held, so `estimate_flows_for()` re-estimates every flow from earlier
  elections only. A row measured at the target election (e.g. the anchor's nsw2023 row) is not used.
- **Latent leak, OFF and unregistered:** `scripts/backtest_candidate_nsw.R:1058` (the
  `AUSPOL_NSW_EXHAUST=1` arm) calls `flows_for(year = TO, estimate = FALSE)`, which takes the row
  recorded AT the target election (`flows$year <= year` keeps it). The switch is not in
  `scripts/published_flags.R`, so nothing that ships uses it, but any NSW result produced with it on
  used post-election exhaustion rates. Fix before using it: read with `as_of` = cycle start as
  forecast_mode does, and register the switch.
