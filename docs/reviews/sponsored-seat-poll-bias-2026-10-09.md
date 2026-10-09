# Do sponsored seat polls lean toward the sponsor? (2026-10-09)

Status: finding, not shipped. No model file was changed. Python only (R was not started). Everything below comes from `external/reference/polls/seat-polls/seat_polls.csv`, `hand_keyed_primaries.csv` and `output/candidacies.csv`; the analysis script lived in the session scratchpad and is not committed.

## Short answer

With the data we have, **no sponsor-lean adjustment is supportable.** Across 11 sponsored polls where the sponsor's class, an actual result and a same-election unsponsored comparison all exist, the sponsor's class is over-stated by a mean of +1.2 points (standard error 1.9, clustered on poll, 2 elections). That is indistinguishable from zero, and it hides opposite signs by sponsor: Advance polls over-state the Liberal/National vote (+1.0 to +11.2), while Climate 200 polls under-state independents (-6.6, -6.7) and the National Party poll in Bullwinkel under-stated the Coalition (-8.9, but 255 days out). A common "sponsors lean toward themselves" term would be fitted to noise.

## What was counted

- Polls: one poll = (election, seat, pollster, date_raw), `row_type == "poll"`, only polls with a published primary (`fp` not empty). `hand_keyed_primaries.csv` rows were added (9 rows, 3 polls; only the Mayo GetUp poll is sponsored).
- MRP excluded from the control group: a release covering 20 or more seats, or "MRP" in the pollster name. That flagged 939 poll-seats (fed2022 151, fed2025 788). All 30 sponsored polls are direct polls.
- Class mapping: ALP; LIB/NAT/LNP/L/NP/CLP/L/NP to LNP; GRN; ON/ONP to ONP; IND or names ending "(IND)" to IND; UAP/KAP to OTH_RIGHT; everything else OTH.
- Actual = sum of `pcv` in `candidacies.csv` by (election, seat, class). If the seat exists and no candidate of that class stood, actual is 0 (a poll giving "OTH 8" in a seat with no OTH candidate is an 8 point error, not an unmatched row).
- Error = poll share minus actual share, in percentage points. Positive means the poll over-stated the class. Polls publish only some parties, so a class a poll did not publish is skipped, not treated as 0.
- Sanity check on the known example: fed2019 Higgins ER&C (Greens client, n=400, 5 days out) reproduces: LNP 36 vs 47.9 actual (-11.9), ALP 30 vs 25.4 (+4.6), GRN 29 vs 22.5 (+6.5). The unsponsored YouGov Galaxy Higgins poll (n=500, 17 days out) also had GRN 29, the same +6.5 error, direct evidence that the Greens figure there was not a sponsor effect.

## 1. Every sponsored poll

One row per sponsored poll with a published primary (n=30 polls; 29 have a result). The poll/actual column gives each class as poll percent / actual percent. Days is days before polling day (vic2026 uses 28 Nov 2026 and has no result yet). Sponsor-class error is poll minus actual for the mapped class; positive means the poll flattered the sponsor; closer to 0 is better.


| Election | Seat | Pollster | Client | Days out | n | Poll / actual by class | Sponsor class | Sponsor-class error |
|---|---|---|---|---|---|---|---|---|
| fed2016 | Mayo | ReachTEL | GetUp | 47 | 681 | ALP 18/14 GRN 10/8 IND 24/35 LNP 40/38 | IND | -11.4 |
| fed2019 | Higgins | ER&C | Greens | 5 | 400 | ALP 30/25 GRN 29/22 LNP 36/48 | GRN | +6.5 |
| fed2019 | Kooyong | ER&C | Greens | 5 | 1741 | ALP 16/17 GRN 21/21 IND 9/10 LNP 41/49 OTH 8/1 | GRN | -0.2 |
| fed2019 | Kooyong | ReachTEL | CFMEU | 158 | 816 | ALP 29/17 GRN 16/21 LNP 40/49 OTH 8/1 | ALP | +12.2 |
| fed2019 | Warringah | ReachTEL | GetUp | 98 | 618 | ALP 15/7 GRN 10/6 IND 27/45 LNP 38/39 OTH 6/2 | IND | -17.5 |
| fed2025 | Brisbane | Insightfully | Advance | 48 | 600 | ALP 30/32 GRN 18/26 IND 10/0 LNP 36/34 OTH 6/3 | LNP | +2.1 |
| fed2025 | Brisbane | uComms | Liberals against Nuclear | 44 | 1184 | ALP 23/32 GRN 24/26 LNP 32/34 OTH 20/3 | nan |  |
| fed2025 | Bullwinkel | JWS Research | Australian Energy Producers | 80 | 830 | ALP 15/32 LNP 63/40 | nan |  |
| fed2025 | Bullwinkel | Unnamed | National Party | 255 | 800 | ALP 23/32 GRN 10/11 IND 10/0 LNP 32/40 | LNP | -8.1 |
| fed2025 | Curtin | JWS Research | Australian Energy Producers | 80 | 830 | IND 28/32 LNP 56/40 | nan |  |
| fed2025 | Dickson | uComms | CFMEU | 23 | 854 | ALP 24/34 GRN 11/8 IND 12/12 LNP 38/35 OTH 5/4 | nan |  |
| fed2025 | Goldstein | JWS Research | Australian Energy Producers | 51 | 800 | ALP 21/14 GRN 5/7 IND 24/31 LNP 44/43 OTH 6/0 | nan |  |
| fed2025 | Goldstein | uComms | Climate 200 | 39 | 1225 | ONP 4/2 | IND |  |
| fed2025 | Griffith | Insightfully | Advance | 48 | 600 | ALP 23/35 GRN 31/32 IND 2/0 LNP 39/27 OTH 6/2 | LNP | +12.0 |
| fed2025 | Kooyong | JWS Research | Australian Energy Producers | 51 | 800 | ALP 11/12 GRN 9/8 IND 32/34 LNP 40/43 OTH 8/0 | nan |  |
| fed2025 | Kooyong | uComms | Australia Institute | 648 | 821 | ALP 12/12 GRN 6/8 IND 32/34 LNP 40/43 OTH 3/0 | nan |  |
| fed2025 | Kooyong | uComms | Australia Institute | 453 | 647 | ALP 12/12 GRN 7/8 IND 32/34 LNP 37/43 OTH 2/0 | nan |  |
| fed2025 | Lyons | uComms | CFMEU | 23 | 712 | ALP 27/43 GRN 15/11 LNP 30/26 ONP 4/7 OTH 6/0 | nan |  |
| fed2025 | Mackellar | uComms | Australia Institute | 453 | 602 | ALP 13/12 GRN 6/6 IND 30/41 LNP 35/35 OTH 4/0 | nan |  |
| fed2025 | Macnamara | Insightfully | Advance | 48 | 600 | ALP 26/36 GRN 28/25 LNP 38/32 | LNP | +5.1 |
| fed2025 | Melbourne | Insightfully | Advance | 48 | 600 | ALP 19/31 GRN 50/39 LNP 22/20 OTH 9/2 | LNP | +1.8 |
| fed2025 | Ryan | Insightfully | Advance | 48 | 600 | ALP 22/28 GRN 27/29 IND 7/0 LNP 40/35 OTH 4/3 | LNP | +5.0 |
| fed2025 | Ryan | JWS Research | Australian Energy Producers | 16 | 800 | GRN 13/29 LNP 45/35 | nan |  |
| fed2025 | Sydney | uComms | Australia Institute | 46 | 860 | ALP 41/55 GRN 19/22 LNP 16/18 OTH 11/2 | nan |  |
| fed2025 | Tangney | JWS Research | Australian Energy Producers | 80 | 830 | ALP 35/43 LNP 41/34 | nan |  |
| fed2025 | Wentworth | uComms | Climate 200 | 80 | 1068 | ALP 15/13 GRN 11/10 IND 33/38 LNP 35/36 | IND | -5.1 |
| fed2025 | Wentworth | uComms | Australia Institute | 453 | 643 | ALP 13/13 GRN 10/10 IND 32/38 LNP 36/36 OTH 3/0 | nan |  |
| fed2025 | Wentworth | uComms | Climate 200 | 24 | 1015 | ALP 12/13 IND 32/38 LNP 33/36 | IND | -5.2 |
| fed2025 | Wills | Insightfully | Advance | 48 | 600 | GRN 33/35 | LNP |  |
| vic2026 | Hawthorn | Freshwater | Liberal Party | 469 | 1147 | LNP 41/0 | LNP |  |

## 2. Sponsor to class mapping

Which party class each sponsor is assumed to favour, with the number of sponsored polls (n). Unmapped sponsors are excluded from every bias figure because the repo does not tell me which party they favour.

| Sponsor | Polls (n) | Mapped class | Basis |
|---|---|---|---|
| Greens | 2 | GRN | Party itself |
| CFMEU (Construction, Forestry, Mining, Maritime and Energy Union) | 1 | ALP | Union, Labor-affiliated |
| GetUp | 2 | IND | My choice: GetUp campaigned for the independent challenger in Mayo 2016 (Sharkie) and Warringah 2019 (Steggall). From memory, not checked in the repo. These two polls have no unsponsored IND comparison in their election, so they enter only comparison (b) below. |
| Climate 200 | 3 | IND | Funds teal independents. Only the two Wentworth polls published an IND figure; the Goldstein poll published only ONP. |
| Advance | 6 | LNP | Low confidence: a conservative lobby that polled Labor/Greens-held inner-city seats. The Wills poll published only the Greens. Sensitivity without it below. |
| National Party | 1 | LNP | Party itself |
| Liberal Party | 1 | LNP | Party itself (Hawthorn, vic2026; no result) |
| Australia Institute | 5 | unmapped | Think tank, no party |
| Australian Energy Producers | 6 | unmapped | Industry, no clear party |
| Australian Forest Products Association | 1 | unmapped | Industry |
| Liberals against Nuclear | 1 | unmapped | Moderate-Liberal faction, could be LNP or IND |
| Queensland Conservation Council | 1 | unmapped | Environmental group |

## 3. Measured bias

Three measures per mapped poll, in percentage points; positive means the sponsor's class was over-stated (zero is unbiased).

- Raw: sponsor-class error (poll minus actual).
- (a) vs control: raw error minus the mean error for the same class in unsponsored direct polls of the same election. This removes that year's general polling error. This is the estimate I would use. Control sizes (polls): fed2019 GRN 8, ALP 7, LNP 8, IND none; fed2025 LNP 47, IND 24, GRN 28, ALP 29. fed2016 has no unsponsored poll with a primary, and fed2019 has no IND one, so GetUp Mayo and Warringah drop out of (a).
- (b) vs other classes: raw error minus the mean error of the other named classes (ALP, LNP, GRN, IND, ONP) in the same poll. Weakness: polls and results both sum to about 100, so an over-stated sponsor class pushes the others negative. (b) overstates lean by construction; shown for completeness.

Per-poll values (mapped polls with a measurable sponsor class). Control mean is the unsponsored direct-poll mean error for that class and election, with the number of polls in brackets.


| Election | Seat | Client | Days out | Raw | Control mean (n polls) | (a) vs control | (b) vs other classes |
|---|---|---|---|---|---|---|---|
| fed2016 | Mayo | GetUp | 47 | -11.4 |  |  | -14.2 |
| fed2019 | Higgins | Greens | 5 | +6.5 | +0.0 (8) | +6.5 | +10.2 |
| fed2019 | Kooyong | Greens | 5 | -0.2 | +0.0 (8) | -0.3 | +3.2 |
| fed2019 | Kooyong | Construction | 158 | +12.2 | +5.1 (7) | +7.1 | +19.5 |
| fed2019 | Warringah | GetUp | 98 | -17.5 |  |  | -20.9 |
| fed2025 | Brisbane | Advance | 48 | +2.1 | +0.8 (47) | +1.3 | +2.4 |
| fed2025 | Bullwinkel | National Par | 255 | -8.1 | +0.8 (47) | -8.9 | -8.0 |
| fed2025 | Griffith | Advance | 48 | +12.0 | +0.8 (47) | +11.2 | +15.6 |
| fed2025 | Macnamara | Advance | 48 | +5.1 | +0.8 (47) | +4.3 | +9.0 |
| fed2025 | Melbourne | Advance | 48 | +1.8 | +0.8 (47) | +1.0 | +2.6 |
| fed2025 | Ryan | Advance | 48 | +5.0 | +0.8 (47) | +4.2 | +5.3 |
| fed2025 | Wentworth | Climate 200 | 80 | -5.1 | +1.5 (24) | -6.6 | -5.3 |
| fed2025 | Wentworth | Climate 200 | 24 | -5.2 | +1.5 (24) | -6.7 | -2.9 |

Mean of each measure with its standard error clustered on poll (each poll contributes one value, so se = sd / sqrt(n polls)); positive means the sponsor's class was over-stated; zero is unbiased. Repeats in one seat (Kooyong twice in 2019, Wentworth twice in 2025) and five Advance polls from one pollster-day are not independent, so the true standard errors are larger than shown.

| Subset | Raw | (a) vs control | (b) vs other classes |
|---|---|---|---|
| All mapped sponsors | -0.20 (se 2.46, n=13 polls, 3 elections) | +1.19 (se 1.93, n=11 polls, 2 elections) | +1.26 (se 3.18, n=13 polls, 3 elections) |
| Without Advance | -3.59 (se 3.38, n=8 polls, 3 elections) | -1.48 (se 2.87, n=6 polls, 2 elections) | -2.31 (se 4.61, n=8 polls, 3 elections) |
| Without GetUp | +2.38 (se 2.02, n=11 polls, 2 elections) | +1.19 (se 1.93, n=11 polls, 2 elections) | +4.68 (se 2.55, n=11 polls, 2 elections) |
| fed2019 only | +0.25 (se 6.43, n=4 polls, 1 elections) | +4.44 (se 2.35, n=3 polls, 1 elections) | +3.00 (se 8.63, n=4 polls, 1 elections) |
| fed2025 only | +0.96 (se 2.37, n=8 polls, 1 elections) | -0.03 (se 2.43, n=8 polls, 1 elections) | +2.33 (se 2.74, n=8 polls, 1 elections) |
| Advance only | +5.22 (se 1.84, n=5 polls, 1 elections) | +4.40 (se 1.84, n=5 polls, 1 elections) | +6.97 (se 2.47, n=5 polls, 1 elections) |
| Climate 200 only | -5.15 (se 0.05, n=2 polls, 1 elections) | -6.66 (se 0.05, n=2 polls, 1 elections) | -4.08 (se 1.21, n=2 polls, 1 elections) |

Lead-time check on (a): polls 60 days or less out give +2.7 (se 1.9, n=8); polls more than 60 days out give -2.8 (se 5.0, n=3: CFMEU Kooyong at 158 days, Nationals Bullwinkel at 255 days, and Climate 200 Wentworth at 80 days). Mixed signs by lead time and sponsor mean the pooled +1.2 does not establish a lean.

Reading it:
- **How small n is:** 11 polls for (a), 2 elections, 5 sponsors. Six of the 11 are Advance (5, one pollster-day) or the two near-identical Wentworth Climate 200 polls. There are only 2 Greens-sponsored polls (Higgins and Kooyong, same pollster, same day).
- **Greens:** Higgins +6.5 and Kooyong -0.3 against a 2019 GRN control of 0.0 (8 polls). The Higgins overstatement equals the unsponsored YouGov Galaxy poll's, so it looks like Higgins polling error, not a Greens effect.
- **Advance:** over-stated LNP in all five measurable polls (+1.3, +11.2, +4.3, +1.0, +4.2 against a 2025 LNP control of +0.8). The only pattern in the expected direction, but five polls from one pollster-day (Insightfully, 16 March 2025, n=600 each) are close to one observation, and mapping Advance to LNP is a low-confidence choice.
- **Climate 200:** under-stated independents at Wentworth (-6.6 and -6.7 against an IND control of +1.5), the opposite of flattery.
- **GetUp:** independents under-stated by 11.4 (Mayo, 47 days) and 17.5 (Warringah, 98 days). Independents tend to surge late; this reads as lead time, and no control exists.
- Measure (b) gives +1.3 (se 3.2, n=13 polls): also zero.

## 4. Is an adjustment supportable, and the time-forward version

Not as a single sponsor-lean number: the mean is near zero, signs flip by sponsor, there are two elections, and lead time confounds it. I propose the estimator below so that it exists and switches on by itself if more sponsored polls arrive; it is not implemented.

- Observation per sponsored poll i: d_i = measure (a), sponsor-class error minus the same-election unsponsored direct-poll mean for that class.
- Pooled lean for target election T: mu_T = mean of d_i over polls from elections strictly before T. se_T = sd(d_i) / sqrt(n).
- Prior spread: tau^2 = max(0, mean(d_i^2) - mean(sampling variance_i)), sampling variance_i = 1.5 x 10^4 x p(1-p)/n (design effect 1.5, in points squared) plus the control mean's variance. A second-moment estimate of how far a sponsor lean could sit from zero.
- Shrunk lean = w x mu_T with w = tau^2 / (tau^2 + se_T^2). No minimum n and no cutoff; zero prior polls gives zero lean.
- To apply it to a sponsored poll for T: subtract the shrunk lean from the sponsor-aligned class and add it back to the other classes pro rata. Unmapped sponsors get nothing.

Time-forward result, each row using only elections before the target. Lean is in percentage points of the sponsor's class (positive means polls flatter the sponsor, so subtract it); w is the weight on the data (1 is fully trusted, 0 is ignored).

| Target election | Prior polls used (n, elections) | Pooled mean mu | se | tau^2 (second moment) | w | Shrunk lean | Lean if tau fixed at 1 / 2 / 3 points |
|---|---|---|---|---|---|---|---|
| fed2019 | 0 usable (Mayo GetUp has no control) | n/a | n/a | n/a | 0 | 0.00 | 0 / 0 / 0 |
| fed2025 | 3 polls, 1 election (fed2019) | +4.44 | 2.35 | 25.7 | 0.82 | +3.65 | +0.68 / +1.86 / +2.75 |
| vic2026 | 11 polls, 2 elections (fed2019, fed2025) | +1.19 | 1.93 | 33.0 | 0.90 | +1.07 | +0.25 / +0.62 / +0.84 |

(No other target election has sponsored polls with a published primary in the file: fed2022, nsw2023, sa2026 and wa2021 have none.)

Cautions:
- The second-moment tau^2 is large (26 to 33) because individual polls swing 5 to 11 points in both directions, so w is 0.8 to 0.9: barely any shrinkage. With this few polls tau^2 is itself poorly estimated, the case the repo's notes flag for shrinkage. The fixed-tau columns show what a tighter prior gives.
- Back-test of the fed2025 row: the +3.65 lean from fed2019 would have been roughly right for Advance (mean +4.4 in fed2025) and wrong in sign for Climate 200 (-6.6) and the Nationals Bullwinkel poll (-8.9). The fed2025 pooled (a) mean was -0.03 (se 2.43, n=8), so a +3.65 correction would have added error on average.
- vic2026 has one sponsored poll (Liberal Party, Freshwater, Hawthorn, n=1,147, 469 days out) and no result to score.
- I did not test whether adjusting improves seat log loss; at this n it cannot be tested.

## 5. Polls not matched or not measurable

- Unmatched to a seat: 4 fed2022 "Senate" rows (RedBridge, state-wide). They are unsponsored. Every other poll matched a seat in `candidacies.csv`.
- vic2026 Hawthorn (Liberal Party, Freshwater): no result yet (polling day 28 Nov 2026; `pcv` is 0 for all rows). Not measurable.
- Sponsor class not published, so no error: fed2025 Goldstein (Climate 200, only ONP published), fed2025 Wills (Advance, only GRN published).
- Sponsor unmapped (14 polls): Australia Institute (Kooyong x2, Mackellar, Sydney, Wentworth), Australian Energy Producers (Bullwinkel, Curtin, Goldstein, Kooyong, Ryan, Tangney), Australian Forest Products Association (Lyons), Liberals against Nuclear (Brisbane), Queensland Conservation Council (Dickson). Section 1 shows their poll/actual values but they enter no bias figure.
- No control: fed2016 has no unsponsored poll with a published primary; fed2019 has no unsponsored IND poll.
- Not verified: the GetUp and Advance class mappings (from memory); whether `client` is complete (an unsponsored poll could be coded with no client, which would contaminate the control group); whether Bullwinkel was a new 2025 seat (from memory). Polling days used: fed2016 2 Jul 2016, fed2019 18 May 2019, fed2025 3 May 2025, vic2026 28 Nov 2026; days out uses `fieldwork_end`. Poll shares were not renormalised for undecided (poll sums are about 100 for the median poll; some are lower).

## Recommendation

Do not add a sponsor-lean term to the seat-poll weighting now. On 11 usable sponsored polls from 2 elections the sponsor's class is over-stated by +1.2 points with a standard error of 1.9, no larger than noise, and the sign flips by sponsor: Advance flatters the Coalition, Climate 200 polls under-state independents, the Greens polls are mixed. Five of the 11 are one pollster-day. If an adjustment is wanted regardless, use the time-forward partial-pooling estimator above with a fixed prior of tau about 2 points (not the unreliable second-moment tau^2): it gives about +0.6 points for vic2026, applied only to sponsors mapped with confidence. Revisit once the vic2026 and later sponsored polls have results, and consider hand-keying primaries for sponsored polls that publish only two-candidate-preferred figures (not checked how many exist).
