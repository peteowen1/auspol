# Worst over-calls in the as-at forecasts (cluster C), 2026-10-05

Read-only investigation. No code, harness or fit script was run; throwaway R scripts
in the session scratchpad called package functions (`candidate_returns`, `personal_prior_vote`,
`fit_defector_discount`, `salience_permit_for`, `surge_hazard_for`) and read CSVs.

Source: `output/forecasts.csv`, 11,905 rows, 18 elections, built 2026-10-02 (predictions file
`output/xgb-primary-asat-predictions.csv` last written 2026-10-02 19:22 +1000). Signed error =
`actual_share - xgb_pred` (negative = model too high). Total squared error over all rows = 194,679
(n = 11,905, RMSE 4.04 points).

## Verdict on the hypothesis

"The biggest over-calls are mostly bugs" is **mostly wrong for the 23 rows below -15**. Two of the
23 are bug-shaped (Narracan, Dobell). Three are a modelling gap about party-switchers. Thirteen are
the other side of a breakout that cluster D covers. The bugs that do exist matter more than their
23-row footprint: they are wider than these rows (sections 3 and 4).

## 1. Every row with signed error below -15 (n = 23)

What the numbers are: points of first-preference share. `base` is the pre-xgb baseline, `xgb` the
as-at forecast, `act` the result, `err` = act - xgb (more negative = worse over-call). Squared error
`sq` is err squared. Categories: a = matching bug, b = party-switcher, c = personal vote that
collapsed, d = party absent / nomination, e = complement of an under-called breakout in the same seat,
f = other. `a?` means a suspected matching bug whose full size I could not reproduce.

| # | Election | Seat | Class (candidate) | base | xgb | act | err | sq | Cat |
|---|----------|------|-------------------|-----:|----:|----:|----:|---:|-----|
| 1 | fed2016 | Dobell | IND (Gregory F Stephenson) | 26.3 | 27.4 | 2.2 | -25.2 | 635 | a? |
| 2 | vic2022 | Narracan | ALP (none stood) | 30.5 | 23.9 | 0.0 | -23.9 | 570 | d |
| 3 | fed2022 | Hughes | OTH_RIGHT (Craig Kelly, ex-LNP to UAP) | 22.6 | 28.4 | 7.4 | -21.0 | 442 | b |
| 4 | nsw2019 | Murray | LNP (Austin Evans) | 54.8 | 55.3 | 35.2 | -20.1 | 402 | e |
| 5 | nsw2019 | Orange | LNP (Kate Hazelton) | 45.2 | 45.8 | 25.8 | -20.0 | 399 | e |
| 6 | fed2010 | Ryan | IND (Michael Johnson, ex-LNP) | 27.7 | 28.2 | 8.5 | -19.7 | 389 | b |
| 7 | fed2019 | Grey | IND (Andrea Broadfoot, NXT to Centre Alliance) | 25.2 | 25.8 | 6.9 | -18.9 | 359 | c |
| 8 | nsw2023 | Kiama | LNP (Melanie Gibbons) | 29.7 | 30.3 | 12.0 | -18.3 | 335 | e (Ward defected) |
| 9 | vic2018 | South-West Coast | LNP (Roma Britnell) | 50.9 | 49.6 | 32.4 | -17.2 | 296 | e |
| 10 | vic2014 | Shepparton | LNP (Greg Barr) | 52.9 | 52.5 | 35.4 | -17.1 | 293 | e |
| 11 | nsw2019 | Dubbo | LNP (Dugald Saunders) | 53.8 | 53.8 | 37.4 | -16.4 | 269 | e |
| 12 | fed2019 | Hunter | ALP (Joel Fitzgibbon) | 53.6 | 53.9 | 37.6 | -16.3 | 267 | e |
| 13 | fed2019 | Capricornia | ALP (Russell Robertson) | 40.8 | 40.0 | 23.7 | -16.3 | 264 | e |
| 14 | nsw2019 | Barwon | LNP (Andrew Schier) | 46.4 | 46.6 | 30.4 | -16.3 | 264 | e |
| 15 | nsw2019 | Murray | ALP (Alan Purtill) | 25.2 | 25.0 | 8.8 | -16.2 | 263 | e |
| 16 | sa2022 | Stuart | LNP (Dan van Holst Pellekaan) | 43.4 | 44.2 | 28.3 | -15.9 | 252 | e |
| 17 | fed2013 | Lyne | IND (Steve Attkins) | 23.6 | 23.4 | 7.6 | -15.8 | 248 | f |
| 18 | sa2022 | Florey | IND (Tessa Kowaliw) | 22.3 | 21.6 | 6.0 | -15.6 | 244 | f |
| 19 | fed2022 | Goldstein | ALP (Martyn Abbott) | 27.4 | 26.6 | 11.0 | -15.5 | 242 | e |
| 20 | fed2013 | New England | IND (Rob Taber) | 36.0 | 35.7 | 20.4 | -15.3 | 235 | f |
| 21 | sa2026 | Waite | IND (Alec Gargett) | 20.7 | 18.1 | 2.9 | -15.2 | 230 | f |
| 22 | fed2010 | Lyne | LNP (David Gillespie) | 51.1 | 49.5 | 34.4 | -15.1 | 228 | e |
| 23 | fed2016 | Tangney | IND (Dennis Jensen, ex-LNP) | 20.3 | 26.9 | 11.9 | -15.1 | 227 | b |

Why each group is what it is, by walking the inputs (source of every number: `output/candidacies.csv`,
`output/xgb-primary-v6-features.csv`, `output/forecasts.csv`):

- **e, 13 rows.** In each seat an independent, Shooters or One Nation candidate took 17 to 48 points
  that the model had given the major party. Examples: Murray, Helen Dalton (IND 18.2 in 2015) stood
  for the Shooters and got 40.3, forecast 6.0; Orange, Philip Donato (Shooters) 56.2 vs 20.9; Dubbo,
  Dickerson IND 28.4 vs 5.0; Shepparton, Suzanna Sheed IND 35.2 vs 5.5; Hunter, ONP 21.6 vs 4.0;
  Goldstein, Zoe Daniel IND 34.5 vs 11.4; Stuart, Geoff Brock IND 48.5 vs 25.5 (sitting member for
  neighbouring Frome, see `cross-seat-personal-vote-2026-10-05.md`). The major-party rows here are
  not wrong in their own right; they are the complement. They are fixed by predicting the breakout
  (cluster D, `breakout-signals-2026-10-05.md`), not by touching the major-party prior.
  Lyne 2010 (row 22) is the same shape with Oakeshott (by-election winner, cluster A).
- **b, 3 rows (+ Kiama).** Sitting members who left their party. Hughes: Kelly's 53.2 as a Liberal
  became 22.6 as UAP in base_pred (53.2 x the fitted 0.435, `fit_defector_discount("fed2022")$discount_mp`).
  Tangney: Jensen 57.2 x 0.355 = 20.3 (exact match to base). Ryan: Johnson 49.5 -> 27.7. Realised
  carry was 0.14, 0.21 and 0.17. Across every major-party sitting member in the corpus who stood again
  under a different class (n = 18 cases, `candidacies.csv`) the realised carry is median 0.27, range
  0.02 to 0.86; the seven federal cases (adding Jensen) are 0.09 to 0.50, median 0.21. The xgb layer then moved Hughes up by 5.8 and
  Tangney by 6.7 points over base_pred (Kiama IND +6.2, Ryan +0.6): the feature set (see the header of
  `xgb-primary-v6-features.csv`) has no "changed party" column, so the trees see a returning sitting
  member with a big base and treat him as a returning sitting independent (those retain about 0.95).
- **c, 1 row.** Grey: Broadfoot got 27.7 in 2016 under the Nick Xenophon Team label. `classify_party()`
  files that label as IND (`R/parties.R:59`), so a party-brand vote reads as a personal independent
  vote with the returning-member slope. She polled 5.1 under Centre Alliance in 2019. This is
  legitimate-looking uncertainty from the data's point of view, but the classification is the cause.
- **f, 4 rows.** A sitting or leading independent did not stand again and the class base was carried
  to an unknown. Lyne 2013: Oakeshott's 47.8 carried at the departed rate, 23.6 predicted for Attkins
  (got 7.6). New England 2013: Windsor's 61.9, 36.0 predicted for Taber. Florey 2022: Bedford's 30.6,
  22.3 predicted. Waite 2026: Duluk 19.7 + Holmes-Ross 14.6, 20.7 predicted. `AUSPOL_HONOUR_DEPARTED=1`
  decays the base toward a retention of 0.38 (`R/dev_slope.R:355-357`); at 0.38 a 47-point base still
  leaves 17 points. This is the known "retiring sitting independent" problem; the departed-hold
  attempt was refused 2026-10-05 (`departed-hold-sweep-2026-10-05.md`). Not a bug.
- **d, 1 row.** Narracan, section 2b.
- **a?, 1 row.** Dobell, section 2a.

## 2. Bugs, with code paths and live/fixed status

### 2a. Dobell fed2016 IND (rows: 27.4 forecast, 2.2 actual): suspected, partly traced

What I can show:

1. Gregory F Stephenson is a new, unknown candidate (1.2% in 2016, 3.1% in 2019). His forecast is
   not his own prior. It is the independent class's 2013 base in Dobell, 11.7 points (notional) =
   Nathan Bracken 8.2 + Craig Thomson 4.0, neither of whom stood in 2016.
2. `candidate_returns("fed2013","fed2016")` gives Dobell IND `same = FALSE`,
   `prior_leader_returns = FALSE`. So the shipped rule would send it to the departed rate (0.38) or
   the new-candidate slope (0.326): `screened_slopes()` at `R/dev_slope.R:355-357`.
3. It is instead sent to slope 1.0 (uniform swing) because the salience screen permits it. The screen
   keys on a Google Trends keyword "Gregory Stephenson" with `jump = 0.2208`
   (`output/salience-v6.csv`). That is a name-only series. Whether it is a namesake is **unconfirmed**
   (the weekly series is not in the repo; `output/salience-corpus.csv` has no such row).
4. **Duplicate-key lookup.** `salience_permit_for()` (`R/salience_screen.R:378-390`) returns one row per
   candidate, not per class. Dobell IND has two rows, Stephenson `TRUE` and Paul Baker `FALSE`. The
   harness turns it into a lookup with `stats::setNames(as.logical(pv$permit), pv$seat)[seats]`
   (`scripts/backtest_candidate_fed.R:944`, same line in `_nsw.R:686`, `_qld.R:601`, `_sa.R:645`,
   `_vic.R:606` and `fit_seats_full.R:1048`). A named-vector lookup with a repeated name returns the
   FIRST row, so the class is permitted or not by row order. Counted over all 22 pairs: 1,085 (seat,
   class) keys have more than one row and **239 hold a `TRUE` beside a `FALSE`/`NA`**
   (fed2016 22, fed2019 30, fed2022 18, fed2025 33, vic2022 17, ...).

What I could NOT reproduce: at slope 1.0 and the poll level in the features file
(IND level 1.40 last time, 5.08 forecast) the Dobell IND cell is 5.08 + (12.2 - 1.40) = 15.9, and the
surge-v2 point-estimate blend adds under 0.5 (p_hat 0.025, `blend_salience_shares`,
`R/salience_surge.R:394-443`). The recorded `base_pred` is 26.3. About 10 points are unaccounted for.
Other permitted new independents show the same unexplained lift over slope 1.0 (Barker +7.8,
Wakefield +2.7, Barton +2.6, Wills +2.3 in fed2016), so it is a real feature of the path, not a
Dobell accident. Finding it needs one harness run with `AUSPOL_DUMP_SHARES=1` and a print of the
cell after each step; I was told not to run the harness.

Status: **LIVE.** `R/salience_screen.R` and the `lut` lines are unchanged since 2026-09-20
(`git log`). The xgb layer did not fix it (27.4).

### 2b. Narracan vic2022 ALP (23.9 forecast, 0.0 actual): fixed in the harness, still present in this table

- Labor did not contest the supplementary election (`docs/plans/prereg-nomination-zero-2026-10-03.md`).
  `output/candidacies.csv` has no vic2022 Narracan rows at all (all candidate names are NA in
  `forecasts.csv`), so no nomination list could have zeroed it from that file; the harness zeroes from
  the results table (`R/nomination_zero.R:27`, `zero_unnominated()`).
- v61 zeroing (`AUSPOL_NOM_ZERO=2`) and the "late" order (`AUSPOL_NOM_ZERO_ORDER=late`, shipped
  2026-10-04) are in the six harnesses and `fit_seats_full.R:1237`. DECISIONS.md says a bare vic run
  reproduces the scored zero in 1,672 of 1,672 cells. I did not re-run it.
- **Not in `forecasts.csv`, by construction.** That table is `output/xgb-primary-asat-predictions.csv`
  (built by `scripts/fit_xgb_primary_asat.R`) joined by `scripts/build_forecasts_table.R`. Neither
  file calls `zero_unnominated` (grep: no match). The as-at models are trained on the pre-zero base
  (DECISIONS.md 2026-10-04: "trained on the early order"). So the table's vintage (2026-10-02) predates
  the fix AND a rebuild would not apply it. Status: **fixed for the ledger/harness, STILL LIVE in
  `forecasts.csv`.**
- Wider footprint: 95 cells in the table have `actual_share == 0` and `xgb_pred >= 3`, together 1.45%
  of total squared error (fed2016 30, wa2025 18, fed2013 9, fed2010 7, vic2018 7, ...). Part of that
  is the WA label problem in section 3, part is real "party did not stand".

## 3. Adjacent bug found on the way: WA party classes disagree between two files

`scripts/build_candidacies.R:485` classifies Western Australian parties with
`classify_party(party_raw, party_raw)`, where `party_raw` is the commission's bare code. The result
files are built by `scripts/fetch_preferences_wa.R:50-100`, which first expands each code to a name
(`WA_PARTY`: `AC` = Australian Christians, `PHO` = One Nation, `CDP`, `FFP`, `SFFP` ...) and so
classifies them OTH_RIGHT or ONP. Candidacies leaves them as OTH. Examples in `candidacies.csv`:
wa2001 `PHO` (One Nation, 54 candidates, 98,321 votes) = OTH; wa2025 `AC` (54 candidates, 48,406
votes) = OTH; wa2017/2013/2021 `ACP`, `CDP`, `FFP`, `SFFP` = OTH. Landsdale wa2025: candidacies says
Parsons (AC) is OTH with 5.06%; `external/elections/waec-2025-wa-firstprefs.csv` says OTH_RIGHT 1,398
votes.

Effect in `forecasts.csv`: the wa2013 and wa2025 tables have no OTH_RIGHT rows at all (its 2.41% and
3.97% of the vote are absent from `actual_share`; wa2025 seats sum to as little as 90.9), and wa2025
OTH is forecast 6.82 on average against 3.07 actual (59 seats). This creates fake over-calls in OTH
and hides the real size of the under-call in OTH_RIGHT. 138 seats across wa2013, wa2017, wa2025,
sa2022, nsw2019 and vic2022 have actual shares summing below 97, and those seats carry 7.8% of all
squared error; I have not split that between this label bug and other missing classes. Status:
**LIVE** (candidacies.csv was rebuilt 2026-10-05 and still shows AC as OTH).
CLAUDE.md names the rule this breaks: party classification comes from one source.

## 4. Sizing by category

What the numbers are: squared error `sq` summed over the rows in each category, as a share of the
total 194,679 over all 11,905 rows. Lower is better; all of these are slices of one tail.

| Cat | What | n | Sum of sq | Share of total |
|-----|------|--:|----------:|---------------:|
| e | complement of an under-called breakout | 13 | 3,774 | 1.94% |
| b | party-switcher (sitting member left party) | 3 | 1,058 | 0.54% |
| f | departed independent's base carried to a newcomer | 4 | 957 | 0.49% |
| a? | suspected matching / screen bug | 1 | 635 | 0.33% |
| d | party absent / nomination | 1 | 570 | 0.29% |
| c | party-brand vote collapsed | 1 | 359 | 0.18% |
| | **All rows below -15** | **23** | **7,354** | **3.78%** |

For scale: rows below -10 are n = 108, 10.0% of squared error; all over-calls (err < 0) are n = 6,120,
37.8%; rows above +15 (under-calls) are n = 72, 16.8%, so the under-call tail is the bigger prize
(cluster D). Within the 23, the bug-shaped rows (a?, d) are 1,205 or 0.62% of total error.

## 5. Proposed fixes (not implemented)

**(a) Matching.**
1. Collapse the salience permit table to one row per (seat, class) before the lookup, and assert
   uniqueness in `salience_permit_for()` so the six `lut` copies cannot see duplicates. Decide the
   collapse on purpose, not by row order. Worked example, Dobell IND: two rows (Stephenson TRUE,
   Baker FALSE). The right unit is the candidate, so keep the class base separate from the
   newcomer: the departed leaders' 11.7 decays at 0.38 (5.08 + 0.38 x 10.8 = 9.2) and a permitted
   newcomer adds their own salience-band expectation on top, instead of the whole base moving to
   slope 1.0. Rough result: nearer 10 to 12 than 27 (the uncounted 10 points in 2a must be found
   first, so treat this number as unconfirmed).
2. Make the Trends keyword carry a place term or reject a jump whose peak week does not sit in the
   campaign window; check "Gregory Stephenson" against the raw weekly series first (not in the repo).
3. Build WA classes in `build_candidacies.R:485` from the same `WA_PARTY` map as
   `fetch_preferences_wa.R` (single source), then rebuild candidacies and the features file. Worked
   example: Landsdale wa2025 Parsons (AC) goes from OTH 5.06 to OTH_RIGHT 5.06, and the forecast row
   gets an OTH_RIGHT cell to score against instead of dropping 5 points.

**(b) Party-switchers.**
1. Add a "changed class since last election" flag and the person's prior percentage as xgb features,
   so the trees stop treating a defector as a returning independent. The xgb currently adds 5.8
   (Hughes) and 6.7 (Tangney) points to a baseline that is already high.
2. Re-check the carry used in `fit_defector_discount()`: the sitting-member rate is 0.435 for fed2022
   and 0.355 for fed2016 (n = 22 and 13 cases pooled across states and decades), while the seven
   federal cases realise 0.09 to 0.50 (median 0.21, n = 7 incl. Jensen, Calare 0.50 the high end). Partial-pool a federal rate toward the all-case median
   0.27 rather than using the raw pooled median (CLAUDE.md: shrinkage, not cliffs). Worked example,
   Hughes: 53.2 x 0.27 = 14.4 instead of 23.1, and the LNP row keeps the rest (Ware actually got
   43.5 against a forecast 23.4). Kiama goes the other way (Ward kept 0.72), so this will not fix
   every case; n = 18 is thin and a held-out check is required before adopting it.

**(d) Party absent.**
1. Apply `zero_unnominated(late)` to the as-at rows when `build_forecasts_table.R` joins them, using
   the same result table the harnesses use, or train and predict the as-at models on the zeroed base.
   Worked example, Narracan vic2022: ALP xgb 23.9 -> 0, freed share follows the flow matrix to LNP,
   GRN, IND; the row's error goes from -23.9 to 0 and the others move by under 5 points each (the
   harness result in DECISIONS.md). Also add Narracan's candidates to `candidacies.csv` (it has none
   for vic2022) so the cell is checkable from the nomination list.
2. After the fix, rerun the actual==0 & xgb>=3 sweep (95 cells); anything left after zeroing and the
   WA relabel is a true miss.

## 6. Unconfirmed items and where I looked

- Dobell: the roughly 10 points between 15.9 (my reconstruction) and 26.3 (recorded base_pred) are
  unexplained. Looked at: `R/dev_slope.R`, `R/salience_surge.R`, `R/reentry_prior.R`, harness lines
  720-1470 and 1700-1800, features file, pooled sharedetail. Did not run the harness (told not to).
- Whether "Gregory Stephenson" is a namesake in Google Trends: raw weekly series not in the repo.
- That the harness reproduces the Narracan zero today: taken from DECISIONS.md 2026-10-04, not re-run.
- Which WA class-label cells account for the 7.8% of error in short-sum seats: only WA2025/2013 OTH
  and OTH_RIGHT checked; sa2022, nsw2019 and vic2022 short sums have other causes I did not trace.
- The 18-case defector-carry table matches names exactly within seat and region, so spelling variants
  (e.g. Jensen "Dennis JENSEN" vs "Dennis Geoffrey JENSEN") drop out of it; the model's own matching
  (surname plus initial) does pick Jensen up. Jensen's 0.21 is added by hand.
- Real-world facts (Labor not standing in Narracan; Bedford retiring in Florey; Dalton's switch) come
  from the repo's docs and data, not from outside sources.
- Some trained-in thresholds in the proposals (0.38 retention, 0.27 carry) are existing repo values
  or my medians over a small n; none has been tested out of sample.
