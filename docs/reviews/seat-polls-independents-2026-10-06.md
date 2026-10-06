# Seat polls and strong independents (2026-10-06)

Read-only measurement and design. Nothing in R/, scripts/ or output/ was edited; no harness or rebuild was run.
Scripts: session scratchpad `seatpolls/a1..a7.R`. Signed error = `actual_share - xgb_pred` (as-at, pre-blend,
current `output/forecasts.csv`, built 2026-10-06 00:42Z). Note the current build's pre-blend numbers differ from
`breakout-signals-2026-10-05.md` (Curtin 7.8 now vs 9.6 there; Warringah 2019 11.6 vs 20.4), so quote this file's
numbers for this build. "IND" is the model class `IND`, one row per seat.

## 1. Seat-poll inventory

What the numbers are: counts from `external/reference/polls/seat-polls/seat_polls.csv` (row_type = poll,
"Senate" pseudo-seat dropped). "MRP" = a release covering 20+ seats or named MRP (the blend's own rule).
Higher counts are better coverage. Data registry has no seat-poll section; the file is in `docs/DATA-DICTIONARY.md:115`.

| Election | Polls | Seats | MRP polls | Direct polls | Direct seats | Seats with any primary | Seats with an IND primary | Sponsored polls | Days before polling day (median, range) |
|---|---|---|---|---|---|---|---|---|---|
| fed2016 | 87 | 48 | 23 | 64 | 40 | 0 (TCP only) | 0 | 0 | not computed (dates in file, see note) |
| fed2019 | 20 | 12 | 0 | 20 | 12 | 9 | 2 (Warringah, Kooyong) | 4 | 17 (5-158) |
| fed2022 | 193 | 151 | 151 | 42 | 25 | 151 | 8 | 0 recorded | n/a (dates in fieldwork_end) |
| fed2025 | 870 | 150 | 788 | 82 | 42 | 150 | 150 (MRP carries an IND column everywhere) | 29 | n/a |
| nsw2023 | 16 | 11 | 0 | 16 | 11 | 0 (TCP only) | 0 | 0 | 24 (23-83) |
| qld2020 | 4 | 4 | 0 | 4 | 4 | 0 | 0 | 0 | 7 |
| sa2026 | 1 | 1 | 0 | 1 | 1 | 1 | 1 (Mount Gambier, uComms 19 Jan: Fatchen 23.1, Scholes 7.7) | 0 | out of scope (live) |

Facts that shape everything below:
- **fed2022 and fed2025 are covered in every seat by a YouGov MRP**, so "was a seat polled at all" is uninformative
  there. The usable selection signal is "a direct (non-MRP) poll exists".
- Sponsors recorded (direct polls, fed2025): Australian Energy Producers 8, Advance 6, Australia Institute 4, Climate 200 3,
  Forest Products 2, others 1 each. fed2019: Greens 2, GetUp 1, CFMEU 1. fed2022 records no sponsor at all (uComms,
  Utting, RedBridge, Compass, KJC are mostly campaign or advocate commissioned in practice, **not confirmed**).
- Only 2 elections have a before-the-election independent poll set big enough to say anything (fed2022: 7 seats, fed2025: 23).
- fed2022 YouGov MRP leaves the IND column blank and puts the independent in `OTH` (Goldstein OTH 24, Mackellar 23,
  Nicholls 19, Cowper 17, Calare 11, Bradfield 5). See section 4.

Worst-miss independents and whether their seat was polled (pre-blend pred, actual, IND figure in any poll with a primary):

What it is: points of primary vote. Smaller miss is better.

| Seat / candidate | pred | actual | Polled? | IND poll figure (days out, pollster) |
|---|---|---|---|---|
| fed2019 Warringah / Steggall | 11.6 | 44.7 | yes, direct | 22.3 (98 days, ReachTEL for GetUp); outside the 90-day window and fed2019 w = 0 |
| fed2022 Goldstein / Daniel | 4.4 | 34.5 | yes, direct | 33.1 (19d), 35.3 (5d) uComms |
| fed2022 Mackellar / Scamps | 12.3 | 38.1 | yes, direct | 23.9 (44d) uComms |
| fed2022 Kooyong / Ryan | 13.1 | 40.5 | yes, direct | 31.8 (39d) uComms |
| fed2022 Curtin / Chaney | 7.8 | 29.5 | yes, direct | 32.0 (5d), 24.0 (68d) Utting |
| fed2022 North Sydney / Tink | 5.1 | 25.2 | yes, direct | 13.6 (15d Compass), 23.5 (7d RedBridge), 19.4 (39d Community Engagement) |
| fed2022 Wentworth / Spender | 27.1 | 35.8 | yes, direct | 24.3, 33.3 RedBridge, 27.0 KJC |
| fed2022 Nicholls (Priestly), Cowper (Heise), Calare (Hook), Bradfield (Boele), Fowler (Le) | 4.1-14.5 | 20.4-29.5 | MRP only | none (the number is under `OTH`, 5-19) |
| fed2016 Mayo / Sharkie | not in this build's top list | 34.9 (prior review) | yes, 3 polls, TCP only | primary 23.5 exists (section 5) |
| nsw2023 Wakehurst / Regan | prior review 10.1 | 35.9 | yes, Sky News 1 Mar, TCP only in file | 37 exists (section 5) |
| nsw2019 Butler, vic2014 Sheed, sa2022 Habermann, vic2018 Yildiz | 1.5-9.9 | 27-40 | **no poll of any kind in the file** (no seat polls scraped for those state elections) | none |

Whether the state elections were unpolled or just not scraped is **not confirmed**: the fetcher has raw pages for nsw2019,
vic2014/2018/2022, sa2018/2022 (`raw/*.html`) and the file has zero rows for them, which is consistent with Wikipedia
carrying no seat-poll table for those elections.

## 2. Selection signal: does "a direct seat poll exists" predict independents beyond the model?

What it is: rows of class IND (or all non-major: IND, OTH, OTH_RIGHT, ONP). Actual and error are primary vote points;
error = actual - xgb_pred (pre-blend; positive means the model was too low). SE clustered on seat-election. Time-forward
by construction: the flag is known before polling day and the prediction is the as-at model, so each election stands alone.
The question is the difference column: polled error minus unpolled error. Zero is no information. For fed2022/fed2025
"polled" = a direct poll exists (every seat has an MRP).

| Election | Class | Direct-polled rows (seats) | Actual mean, polled / unpolled | Actual >=20%, polled / unpolled | Error polled (SE) | Error unpolled (SE) | Difference (SE) |
|---|---|---|---|---|---|---|---|
| fed2016 | IND | 40 | 7.4 / 3.6 | 17.5% / 2.7% | +2.41 (1.38) | +0.35 (0.35) | +1.70 (1.42) |
| fed2019 | IND | 12 | 7.3 / 3.4 | 8.3% / 5.8% | +3.27 (2.82) | -0.54 (0.30) | +3.81 (2.83) |
| fed2022 | IND | 25 | 11.8 / 4.3 | 28.0% / 7.1% | +6.16 (2.07) | +0.85 (0.34) | **+5.31 (2.10)** |
| fed2025 | IND | 42 | 13.9 / 5.1 | 31.0% / 7.4% | -2.60 (0.52) | -0.76 (0.30) | **-1.84 (0.61)** |
| nsw2023 | IND | 11 | 9.8 / 8.7 | 27.3% / 14.6% | +2.03 (2.79) | -0.43 (0.42) | +2.46 (2.83) |
| Pooled (5 elections) | IND | 134 | 10.3 / 4.4 | 23.1% / 6.4% | +1.47 (0.72) | -0.05 (0.14) | +1.52 (0.74) |
| Pooled, xgb_pred >= 3 only | IND | 82 | 15.7 / 9.5 | 36.6% / 13.9% | +1.66 (1.09) | -0.16 (0.30) | +1.82 (1.13) |
| Pooled, all non-major | all | 536 (134 seats) | 5.1 / 4.1 | 5.8% / 2.0% | -0.01 (0.18) | -0.08 (0.06) | +0.07 (0.19) |

Reading it:
- Polled independents win a lot more often (actual mean 10.3 vs 4.4, 23% vs 6% at >=20%), so the flag is a strong
  signal about the **outcome**. The model already knows most of that (pooled error difference only +1.5, 2 SE).
- The signal is **not stable**: +5.3 (2.1 SE) in fed2022, **-1.8 (3 SE) in the opposite direction in fed2025**, where the
  model over-called polled independents. A rule fitted on fed2016-19 and applied to fed2022 would have helped; applied to
  fed2025 it would have hurt. fed2022 was the first teal wave, which no earlier training set contained.
- On all non-major classes together the flag carries nothing (+0.07, SE 0.19). The selection effect is IND-specific.
- Caveats: fed2016 and fed2019 "polled" seats are mostly TCP-only (the independent was polled, not the primary);
  fed2019 covers 12 seats only (the scrape is incomplete for 2019, not confirmed); fed2025 direct polls include 29
  sponsored ones (Climate 200 etc.).

## 3. Poll accuracy for independents

What it is: poll IND primary minus actual IND class share, per poll within 90 days before polling day, with a primary
published. Positive = poll overstates. "Model" columns are the same rows' pre-blend xgb_pred. SE clustered on seat.
Lower RMSE is better.

| Election, type | Polls | Seats | Actual IND mean | Poll minus actual (SE) | Poll RMSE | Model minus actual | Model RMSE |
|---|---|---|---|---|---|---|---|
| fed2019, direct | 1 | 1 | 10.2 | -1.20 | 1.20 | -1.50 | 1.50 |
| fed2022, direct | 13 | 7 | 30.5 | **-5.16 (1.55)** | 7.36 | -18.77 | 20.71 |
| fed2025, direct | 31 | 23 | 20.3 | +0.68 (1.56) | 7.57 | +3.40 | 4.86 |
| fed2025, MRP | 350 | 150 | 8.6 | +1.34 (0.59) | 7.57 | +1.34 | 3.62 |
| fed2025 direct, actual IND >= 10 | 20 | 12 | 29.6 | -2.60 (1.05) | 5.03 | +4.71 | 5.75 |
| fed2025 MRP, actual IND >= 10 | 96 | 37 | 25.7 | **-6.82 (1.30)** | 11.12 | +1.65 | 5.76 |
| fed2022 direct, actual IND >= 10 | 12 | 6 | 32.5 | -5.69 (1.60) | 7.65 | -20.20 | 21.55 |
| fed2025 direct, unsponsored | 22 | 20 | 20.3 | +1.19 (1.84) | 8.28 | +3.20 | 4.89 |
| fed2025 direct, sponsored | 9 | 8 | 20.5 | -0.56 (2.08) | 5.44 | +3.89 | 4.79 |

Reading it: polls **understate** strong independents (fed2022 direct by 5.2; fed2025 MRP by 6.8 on seats where the
independent got >= 10) but are far closer than the model was in 2022 (RMSE 7.4 vs 20.7). In fed2025 the model is better
than the polls (4.9 vs 7.6) because by then it had three years of teal results. Sponsored vs unsponsored: no difference
distinguishable from zero (n = 9 / 22). Anchor: the MRP "IND" column in fed2025 is populated in every seat including
seats where no independent stood (actual IND 0), so unconditional MRP accuracy mixes in phantom cells (see the
`pred = 0` rows in section 6).

## 4. What the blend does today on these rows

Replicated by hand from `R/seat_poll_blend.R` mode 1 (AUSPOL_SEAT_POLL_BLEND=1, source "all", class match) using
`xgb_pred_seat` for the pre-blend share and the weights in the rebuild logs. Anchor check: my mean absolute change over
polled seats is 0.72 (fed2022) and 0.57 (fed2025) against the logs' 0.78 and 0.72, and applied cells 867/765 against
850 (fed2025) in the log, so the replication is close but not exact (it uses `xgb_pred_seat`, not the live `shares`
matrix). Weights from `output/rebuild-forecasts-logs`: **fed2019 0.000, fed2022 0.266 (fitted on 29 cells from one
earlier election), fed2025 0.256 (917 cells, 2 elections)**. The earlier review assumed 0.45 for fed2022; that is not
what the current logs say.

What it is: IND class primary, points. Pre = xgb_pred_seat; post = my replicated blend (renormalised to 100);
miss = actual minus the column. Smaller is better.

| Seat (fed2022) | Pre | IND poll cell (n polls) | Post | Actual | Miss pre | Miss post |
|---|---|---|---|---|---|---|
| Goldstein / Daniel | 4.4 | 34.2 (2) | 12.1 | 34.5 | 30.0 | 22.4 |
| Kooyong / Ryan | 13.1 | 31.8 (1) | 16.8 | 40.5 | 27.5 | 23.7 |
| Mackellar / Scamps | 12.3 | 23.9 (1) | 14.7 | 38.1 | 25.8 | 23.4 |
| Curtin / Chaney | 7.8 | 28.0 (2) | 12.7 | 29.5 | 21.7 | 16.7 |
| North Sydney / Tink | 5.1 | 18.8 (3) | 8.6 | 25.2 | 20.1 | 16.6 |
| Nicholls, Cowper, Calare, Bradfield, Fowler | 4.1-14.5 | none (number is under OTH) | 4.2-14.2 | 20.4-29.5 | 15.0-18.4 | 15.3-19.2 |
| fed2019 Warringah / Steggall | 11.6 | none in window | 11.6 | 44.7 | 33.1 | 33.1 (w = 0) |

Why the teals stay low, in order of size:
1. **One class-blind weight.** w = 0.266 is one least-squares slope over every polled (seat, class) cell of every class
   (ALP and LNP dominate), fitted on 29 cells from fed2019. For independents with a large gap it is the wrong number: the
   least-squares weight on the five fed2022 large-gap direct IND cells is **1.23** (poll minus pred >= 10, n = 5, miss 25.0
   mean, poll RMSE 8.0 vs model 25.3). A weight of 0.27 on a 30-point gap closes 8 points of it, which is exactly what the table shows.
2. **The poll is not in the right class.** The fed2022 YouGov MRP puts the independent in `OTH`, and the blend maps `OTH`
   to class `OTH`. For Goldstein and Mackellar that pulls the (non-winning) OTH candidate up (OTH pre 3.5, 3.4 against
   actual 1.1, 0.6; arithmetic: +0.266 x (24 - 3.5) = +5.5 points to the wrong class); for Nicholls, Cowper, Calare,
   Bradfield, Fowler our `OTH` share is 0 so the cell is skipped ("no phantom candidates") and the 5-19 point poll figure
   is silently dropped. `AUSPOL_SEAT_POLL_MATCH=perpoll` (testing, off) is built for exactly this and is not shipped.
3. **Seats with no IND primary at all** (fed2016 Mayo, nsw2023 Wakehurst: TCP only; fed2019: weight 0 and Warringah 98
   days out) get no blend.
4. **Too old / outside the window** is minor: 90 days drops only the Warringah 2019 ReachTEL and an Utting Curtin poll at 68 days is kept.
5. Renormalisation to 100 after the pull spreads part of the gain back over other classes (Goldstein pulled +7.7 points
   toward 34.2 raw, ends +7.7 net so small here; not a major cause).

fed2025 is different: pre-blend, strong IND rows were already well called (mean error +0.93 on 30 seats with a poll cell
and actual >= 15), and the blend moves them **away** (post +2.91, RMSE 5.3 -> 5.8). The same single weight is too big
for 2025 independents (least-squares 0.20 on direct IND cells, n = 23) and too small for 2022 (1.23, n = 7).

## 5. Missing primaries, sourced

All three sit in `external/reference/polls/seat-polls/seat_polls.csv` (columns: election, seat, pollster, client,
fieldwork_start/end, date_raw, party, fp, tcp_*, source_url, row_type, seat_name), one row per party. The file is built by
`scripts/fetch_seat_polls.R` from Wikipedia raw pages in `raw/`; those pages carry TCP only for these polls, so the
primaries have to be added as a hand-keyed supplement merged by the fetcher (NOT by editing the generated CSV).

| Poll | Figures | Source | Row format |
|---|---|---|---|
| fed2016 Mayo, ReachTEL for GetUp, 16 May 2016, n = 681 | Liberal (Briggs) 40, NXT (Sharkie) 23.5, ALP 18, Greens 10 | [Poll Bludger, 3 Jun 2016](https://www.pollbludger.net/2016/06/03/private-polling-round-bass-sturt-mayo-cowan/) (page opened) | rows `fed2016, Mayo, ReachTEL, GetUp, 2016-05-16`, party `L/NP` 40, `NXT` 23.5, `ALP` 18, `GRN` 10. Matches the existing TCP-only 16 May row (48.5). Class: `NXT` maps to OTH in `seat_poll_shares`, but Sharkie's forecast class is IND, so the party-to-class map must treat NXT in Mayo as IND or the blend misses it. |
| nsw2023 Wakehurst, Sky News, ~1 Mar 2023 (date from existing file row) | Liberal 41, Regan (IND) 37, Labor 11, Greens 3, others 8; 50-50 TCP | [Kevin Bonham, NSW Lower House 2023 final days](https://kevinbonham.blogspot.com/2023/03/nsw-lower-house-2023-final-days-rolling.html) (page opened; pollster, date and sample not stated there) | rows `nsw2023, Wakehurst, Sky News, 2023-03-01`, `L/NP` 41, `IND` 37, `ALP` 11, `GRN` 3, `OTH` 8. Regan's actual primary was 35.9, so this poll was close to the result. |
| fed2019 Warringah | **Already on disk**: ReachTEL for GetUp 9 Feb 2019, IND (Steggall) 22.3, LIB 37.7, ALP 15.0, GRN 9.6, OTH 5.7, TCP 54-46. | file rows 10-16; source Wikipedia electorate polling page | No new row needed. It is excluded only by the 90-day window (98 days) and by w = 0 in 2019. A later 2019 Warringah poll (Lonergan/GetUp) is mentioned in the prior review but **I could not find the primary figures**: a search returned only election results. Actual: Steggall 43.5 on the AEC page, 44.7 in our data (difference not reconciled). |

## 6. Recommendation (one design, not built)

**Predict the independent's primary directly, as its own small stage for IND rows, from the poll, the selection flag and
salience, with shrinkage and time-forward fitting.** Not a breakout probability, not a mixture.

Inputs, per (seat, IND candidate row), all known before polling day:
1. `poll_ind`: the IND-class figure from seat polls within 90 days, taking a **named independent's figure wherever the
   poll supplies one in any column** (fix the `OTH`-to-IND mapping for MRP releases whose IND column is blank, i.e.
   per-poll matching, `AUSPOL_SEAT_POLL_MATCH=perpoll`, plus Mayo/NXT).
2. `gap = poll_ind - xgb_pred_seat` and `direct_flag` (a non-MRP poll exists), plus `n_direct`.
3. Salience level and rise (`jump`, already computed).

Rule, in shrinkage form (Pete's "shrinkage over thresholds"): `post = pred + w(gap, direct_flag) * gap`, with `w`
partial-pooled between an IND-specific least-squares slope and the existing pooled 0.26-0.27, by how precisely the
IND slope is estimated: `w = k * w_ind + (1-k) * w_pooled`, `k = tau2 / (tau2 + se^2)`. Only rows with a real named IND
candidate and `pred > 0`, so MRP phantom cells (Boothby, Hughes, Mallee, Nicholls 2025: poll 11.6-22.9, pred 0, actual 0)
are never pulled up.

Where it goes: **a rebuilt blend weight for IND rows in `seat_poll_blend_apply()` first** (the effect sits after xgb, where
the poll lives, and the fed2022 evidence is an error of 20+ points that no xgb feature moved: v59 endorsement, salience
`jump` and council features contributed about zero to those rows). Add `gap` and `direct_flag` as xgb features only as a
second stage, and test both layers per the `base_pred` rule in CLAUDE.md before claiming it ships.

Evidence for and against, honestly sized:
- For: fed2022, five direct large-gap IND cells, miss 25.0 mean pre, poll miss 6.4, least-squares weight 1.23. With w = 1.0
  on those five the mean error falls from 22.2 to about -6.4 (the poll's own error: understate, so sign is the poll's);
  with a shrunk w of 0.6 I estimate the miss falls by about 55 percent (Goldstein 30.0 to 12, Daniel's 34.2 poll; Curtin
  21.7 to 8.7; Mackellar 25.8 to 10.3; my arithmetic, not a run).
- Against / unresolved: this can be fitted **time-forward only from fed2019 for fed2022** (Warringah 22.3 vs 44.7 and
  Kooyong 9.0 vs 10.2: two cells, one of them outside the window), which is why the fed2022 gain relies on the shrunk prior
  rather than a learned slope; and fed2025 shows the opposite sign (-1.84 selection difference, least-squares 0.20), so a
  weight fitted on fed2022 alone would hurt fed2025 (poll RMSE 7.6 vs model 4.9). That is only safe if the weight is
  gated on a **large positive gap with a real candidate**, which in fed2025 occurred in zero real-candidate cases (all 4 were
  phantoms). Whether this survives in the next wave is untestable on disk; 2022 is one election.
- Not recoverable by any version of this: Butler, Sheed, Habermann, Yildiz, Dalton, Hawkins (no poll of any kind). For those
  the earlier verdict stands (wider uncertainty, not a higher mean).

Estimated effect on the named rows, if built as above (not run): Goldstein, Mackellar, Curtin, North Sydney, Kooyong
2022 miss reduced from 20-30 to roughly 8-15 each; Mayo 2016 and Wakehurst 2023 become correctable once their primaries
are keyed (23.5 and 37 against actuals 34.9 and 35.9); Steggall 2019 only if the window is relaxed for IND-only cells (22.3,
miss 33 to about 20 at w = 0.5). Pooled-RMSE effect is bounded by the previous review: the whole cluster is 5.2 percent of
squared error.

Pre-registration needed before any run: criterion on the named large-gap rows primary, pooled log loss and share RMSE
across all elections as the do-no-harm guard, the fed2025 over-pull as the named unacceptable outcome, and a dry-run on
Warringah 2019 and Goldstein 2022 where the answer is known.

## Unconfirmed, and where I looked

- Blend replication is by hand from `xgb_pred_seat`, not the live shares matrix; anchors agree within 7 percent
  (fed2022 mean absolute change 0.72 vs 0.78 logged) but fed2025 applied cells 765 vs 850 logged.
- The 0.45 fed2022 weight in the prior review does not match the logged 0.266; I did not find where 0.45 came from.
- `forecasts.csv` pre-blend numbers moved vs the 2026-10-05 review (rebuilt 2026-10-06); I did not reconcile.
- Sponsors: `client` is blank for all fed2022 and nsw2023 polls, so public vs campaign-commissioned there is unknown.
- fed2016 and fed2019 seat-poll coverage (48 and 12 seats, 0 and 9 with primaries) looks incomplete versus what existed; not checked against Poll Bludger.
- Wakehurst: pollster, date and sample not confirmed (the Sky News label and 1 Mar date come from our file; the numbers
  from Kevin Bonham). Mayo figures confirmed on the Poll Bludger page; the page did not give the party-by-party TCP.
- State seat polls for nsw2019, vic2014/2018/2022, sa2018/2022: zero rows; whether none existed or Wikipedia never listed them is unchecked.
- The selection table's fed2016 and fed2019 "polled" seats are TCP-only polls; I did not check whether the independent in each was the named subject of the poll.
