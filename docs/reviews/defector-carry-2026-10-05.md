# Defector carry: shrunk carry, no carry, or does it depend on who they are? (2026-10-05)

Measurement only. No edits to `R/`, `scripts/`, `output/`; no harness, rebuild or fit runs. Scripts and
raw printouts are in the session scratchpad `...\scratchpad\defectors\` (`cases2.R`, `analyse.R`,
`score.R`; final case table `cases_final.rds`).

Pete's question: "model what performs best - is shrunk measure better than no carry? does it matter
based on who they are?"

## Answer first

- **Shrunk pooled carry beats no carry, clearly.** Over 15 time-forward cases, RMSE 14.2 points (SE 2.4)
  against 23.2 (SE 3.7) for no carry. Squared-error gap 337 (SE 139), 2.4 SEs. No carry predicts 0 for a
  man who in fact polled a median 15 points, so it loses wherever a defector keeps a personal vote.
- **But the average carry hides two groups.** Federal cases (n = 7) carry median 0.21, mean 0.23.
  State cases (n = 11) carry median 0.44, mean 0.56. Welch t-test on the carry difference: p = 0.003
  (permutation p = 0.008), in-sample. The model's 0.355 to 0.435 is about the pooled all-case mean
  (0.43), so it is right on average and wrong for federal.
- **On federal cases alone, no carry (RMSE 12.6) beats the pooled shrunk carry (14.2)**, and the
  current model is worse than no carry on the three federal rows where it is scorable.
- **No covariate earns its place under time-forward scoring at n = 15.** Jurisdiction (federal or not)
  is the only candidate: 12.6 vs 14.2 RMSE, squared-error gain 42 with SE 42 = "not separable at n = 15".
  On the six federal cases alone the gain is 111 (SE 59, 1.9 SEs), suggestive, not decisive.
- **Nothing here predicts the survivors** (Cregan 50.5, Ward 38.8, Ellis 32.5, Graham 54.6). Every rule
  puts them at 17 to 29 points. That needs a survival probability, not a carry.

## 1. Case list (n = 18)

Source: `output/candidacies.csv`, all 30 election labels, all six regions. Rule: person flagged
`elected` for an ALP or LNP class at the region's previous election, seat renamed through
`seat_rename_map()`, matched by `match_key(surname_of(), given_of(), "initial")` (the repo helpers),
standing in the same seat at the next election under a non-ALP/LNP class. Realised carry =
new first-preference % divided by old first-preference %. **Lower carry = more of the old vote lost; the
model's current rate is 0.355 to 0.435.** `n_cand` and `xgb` come from `output/forecasts.csv` (post-fix
rebuild): xgb is the model's prediction for the whole class row, so it is only comparable to the
defector when `n_cand` = 1.

| id | election | seat | name | old class, pcv | new class, pcv | carry | won? | n_cand | xgb (class) |
|---|---|---|---|---|---|---|---|---|---|
| 1 | wa2001 | Pilbara | GRAHAM | ALP 63.8 | IND 54.6 | 0.855 | yes | no row | |
| 2 | wa2005 | Vasse | MASTERS | LNP 29.7 | IND 20.6 | 0.693 | no | no row | |
| 3 | fed2007 | Corio | Gavan O'CONNOR | ALP 46.7 | IND 12.7 | 0.272 | no | no row | |
| 4 | wa2008 | Nedlands | WALKER | LNP 51.9 | IND 22.8 | 0.439 | no | no row | |
| 5 | fed2010 | Ryan | Michael JOHNSON | LNP 49.5 | IND 8.5 | 0.172 | no | 1 | 30.7 |
| 6 | fed2013 | Dobell | Craig THOMSON | ALP 46.3 | IND 4.0 | 0.086 | no | 2 (leader Bracken) | 23.1 |
| 7 | fed2016 | Tangney | Dennis Geoffrey JENSEN | LNP 57.2 | IND 11.9 | 0.208 | no | 1 | 24.8 |
| 8 | wa2017 | Hillarys | JOHNSON | LNP 64.3 | IND 20.1 | 0.313 | no | 1 | 21.7 |
| 9 | vic2018 | Morwell | NORTHE, Russell | LNP 44.4 | IND 19.6 | 0.440 | flag says yes (doubtful) | 4 | 29.5 |
| 10 | qld2020 | Whitsunday | COSTIGAN, Jason | LNP 32.2 | OTH (NQ First) 9.4 | 0.291 | no | 2 | 16.0 |
| 11 | sa2022 | Kavel | CREGAN, Dan | LNP 48.1 | IND 50.5 | 1.049 | yes | 1 | 28.4 |
| 12 | sa2022 | Narungga | ELLIS, Fraser | LNP 46.5 | IND 32.5 | 0.700 | yes | 2 | 37.4 |
| 13 | sa2022 | Waite | DULUK, Sam | LNP 45.2 | IND 19.7 | 0.435 | no | 2 | 26.6 |
| 14 | fed2022 | Hughes | Craig KELLY | LNP 53.2 | OTH_RIGHT (UAP) 7.4 | 0.139 | no | 1 | 25.1 |
| 15 | nsw2023 | Kiama | WARD Gareth | LNP 53.6 | IND 38.8 | 0.724 | yes | 1 | 25.9 |
| 16 | fed2025 | Calare | Andrew GEE | LNP 47.7 | IND 23.7 | 0.497 | yes | 2 | 52.1 |
| 17 | fed2025 | Monash | Russell BROADBENT | LNP 37.8 | IND 10.2 | 0.270 | no | 2 (leader Deb Leonard) | 34.1 |
| 18 | sa2026 | MacKillop | MCBRIDE, Nick | LNP 62.3 | IND 14.8 | 0.237 | no | 2 | 26.7 |

Summary of carries (n = 18): median 0.37, mean 0.43, SD 0.27, range 0.09 to 1.05. Federal (n = 7):
0.09 0.14 0.17 0.21 0.27 0.27 0.50. State (n = 11): 0.24 0.29 0.31 0.44 0.44 0.44 0.69 0.70 0.72 0.86 1.05.
By jurisdiction: fed 7, SA 4, WA 4, NSW 1, QLD 1, VIC 1.

### Removed or excluded, and why

- **Casey fed2022, "Trevor Walter SMITH" (Liberal Democrats) removed: false match.** The 2019 winner
  was Tony SMITH. Both key to `smith|t`, so the initial rule joined two different men. Found by reading
  the candidate rows (Tony is Speaker Tony Smith; Trevor is a Liberal Democrats candidate). This also
  explains why the forecast table's Casey LNP row looked unexplained in the earlier plan.
- **Black sa2026, David SPEIRS excluded:** he resigned, a by-election was held (winner Alex Dighton, ALP)
  and the machine's by-election logic already treats him as no longer sitting. Carry would be 0.28.
- **Eden-Monaro fed2019 "Mike KELLY" to Maranoa ONP 11.9:** different seat, name collision, not used.
- **Cross-seat movers excluded by definition (same seat required):** Julia Banks (Chisholm LNP to Flinders
  IND 13.8, fed2019), D'ORAZIO (Ballajura ALP to Morley IND 16.0, wa2008), BOWLER (Murchison-Eyre ALP to
  Kalgoorlie IND 34.0, wa2008). Peta Murphy, Bruce Scott, Robinson, Freeman matches are almost
  certainly name collisions. Not verified individually, not used.
- Surname-only audit (same seat, same surname, no initial match): four hits (Champion, Stuckey, Ryan,
  McNee), all different people or non-defections. No missed nickname cases found within a seat.
- **By-election winners:** `byelection_winner_rows()` works for this (it returns the winner with the
  by-election `pcv`) and I used it. It produced zero by-election-winner defectors. It reported 18
  by-election winners it could not match to a results row (Higgins, Bradfield, North Sydney, Perth,
  Manly, North Shore, Cheltenham, Enfield, Northcote, Gippsland South, Merredin, Nedlands, Murdoch,
  Peel, Victoria Park, Armadale, Willagee, Fremantle; possible double counting across pairs). A
  defecting by-election winner among those would be missed.
- **Untestable:** `vic2010` has `elected` NA for all 502 rows, so every vic2014 defector is unknowable
  from the corpus (and vic2026 has not happened). Nothing else is NA. WA has `elected` populated, so
  WA is testable; I did not guess any winner from vote share.
- **Data fault found in passing (not fixed):** `candidacies.csv` flags Russell Northe `elected = TRUE`
  at vic2018 Morwell with 19.6% first preferences while Mark RICHARDS (ALP, 34.2%) is `FALSE`.
  Unverified; I did not look up the 2018 Morwell result. It affects only the "won?" column here, not
  any carry. If wrong, defectors who won = 5, not 6.

## 2. Covariates

What the columns are: facts known before the election (so usable as predictors). Data columns come from
`candidacies.csv`; hand columns were collected from the web (source in the right column).
"unverified" marks a cell I could not confirm from a source I opened.

| id | seat | years since first elected | why they left | minister? | old party fielded at t | source for hand cells |
|---|---|---|---|---|---|---|
| 1 | Pilbara (Graham) | 12 (first 1989) | lost preselection (search snippet) | no (Wikipedia: shadow roles only) | yes | en.wikipedia.org/wiki/Larry_Graham_(politician); search result on 2000 resignation |
| 2 | Vasse (Masters) | 9 (1996) | lost preselection to Buswell | no (unverified) | yes | en.wikipedia.org/wiki/Bernie_Masters (search result) |
| 3 | Corio (O'Connor) | 14 (1993) | lost preselection to Marles | no (unverified) | yes | en.wikipedia.org/wiki/Gavan_O%27Connor |
| 4 | Nedlands (Walker) | 7 (2001) | resigned after Buswell became leader | no (unverified) | yes | en.wikipedia.org/wiki/Sue_Walker_(politician) |
| 5 | Ryan (Johnson) | 9 (2001) | expelled, disrepute over a coal commission deal | no (unverified) | yes | en.wikipedia.org/wiki/Michael_Johnson_(Australian_politician) |
| 6 | Dobell (Thomson) | 6 (2007) | suspended then resigned, HSU credit card allegations | no (unverified) | yes | en.wikipedia.org/wiki/Craig_Thomson_(politician) |
| 7 | Tangney (Jensen) | 12 (2004, from memory, unverified) | lost preselection 57 to 7 | no (unverified) | yes | thenewdaily.com.au/news/2016/05/09/dumped-liberal-jensen-run-independent |
| 8 | Hillarys (R. Johnson) | 21 (1996) | resigned from party April 2016; reason not found (unverified) | yes, police minister 2008 to 2012 | yes | en.wikipedia.org/wiki/Rob_Johnson_(Australian_politician) |
| 9 | Morwell (Northe) | 12 (2006) | resigned from party Aug 2017 over debts and gambling | yes, energy and small business 2014 | yes | en.wikipedia.org/wiki/Russell_Northe |
| 10 | Whitsunday (Costigan) | 8 (2012) | expelled from LNP Feb 2019 after harassment complaint (later withdrawn) | no (shadow assistant only) | yes | en.wikipedia.org/wiki/Jason_Costigan |
| 11 | Kavel (Cregan) | 4 (2018, unverified) | quit Liberals 2021 over perceived neglect of his seat; then Speaker | no at the time (Speaker; minister only from 2024) | yes | indaily.com.au/news/2021/10/13/speaker-ousted-in-late-night-parliamentary-coup |
| 12 | Narungga (Ellis) | 4 (2018, unverified) | ICAC charge Feb 2021, left party | no | yes | indaily.com.au/news/2021/02/19/marshall-govt-in-minority-after-mps-icac-charge |
| 13 | Waite (Duluk) | 8 (2014, unverified; a snippet said 2015) | assault charge; party refused him back after acquittal | no (unverified) | yes | en.wikipedia.org/wiki/Sam_Duluk |
| 14 | Hughes (Kelly) | 9 (2013 is wrong: first elected 2010, unverified; I used 2013 in the run, see note) | resigned Feb 2021, COVID policy clashes; joined UAP Aug 2021 | no (unverified) | yes | en.wikipedia.org/wiki/Craig_Kelly |
| 15 | Kiama (Ward) | 12 (2011, unverified) | resigned ministry and party May 2021 under police investigation | yes (resigned ministry) | yes | en.wikipedia.org/wiki/Gareth_Ward |
| 16 | Calare (Gee) | 9 (2016, unverified) | quit Nationals Dec 2022 over party opposing the Voice | yes, veterans' affairs | yes | SBS: nationals-mp-quits-over-partys-voice-to-parliament-stance |
| 17 | Monash (Broadbent) | 35 (1990) | lost preselection 161 to 16, left Nov 2023 | no (Wikipedia: no ministry) | yes | en.wikipedia.org/wiki/Russell_Broadbent |
| 18 | MacKillop (McBride) | 8 (2018) | quit July 2023 citing "dark forces" and factionalism | no (unverified) | yes | indaily.com.au/news/2023/07/06/dark-forces-liberal-factional-tensions-erupt-as-mp-turns-independent |

Note on row 14: the script stored Kelly's first-elected year as 2013, which gives 9 years. Craig Kelly
was first elected in 2010 (my memory, unverified), which would be 12. The run used 9. This feeds only
the "years since first elected" covariate, which did not help anyway.

Data-only covariates: **"old party fielded a candidate at t" is TRUE in all 18, so it has no variation
and cannot be tested.** Label: IND 16, minor party 2 (Costigan NQ First 0.29, Kelly UAP 0.14 plus
Casey-type removed). Terms-in-corpus is censored by where each region's corpus starts (SA from 2018,
VIC from 2014), so I show it but treat it as weak.

Descriptive carry by group (all 18, not a prediction, n in the second column):

| group | n | median carry | mean | SD |
|---|---|---|---|---|
| left over preselection | 5 | 0.27 | 0.46 | 0.29 |
| resigned, policy or other | 7 | 0.44 | 0.45 | 0.29 |
| expelled or scandal | 6 | 0.36 | 0.40 | 0.27 |
| minister | 4 | 0.47 | 0.49 | 0.17 |
| not minister | 14 | 0.28 | 0.42 | 0.29 |
| federal | 7 | 0.21 | 0.23 | 0.13 |
| state | 11 | 0.44 | 0.56 | 0.26 |
| IND label | 16 | 0.44 | 0.46 | 0.27 |
| minor-party label | 2 | 0.22 | 0.22 | 0.11 |

Correlation of carry with prior pcv -0.02, with years since first elected -0.25, with terms in corpus
-0.39 (n = 18 each, none clearly nonzero). Only jurisdiction separates cleanly. Defectors who won: 6
flagged (carry 0.86 0.44 1.05 0.70 0.72 0.50), of which 5 are state seats.

## 3. Time-forward scoring

What the numbers are: points of first-preference share, error = predicted minus actual share for the
defector. **Lower is better** for MAE and RMSE. SE is a bootstrap over cases (5,000 resamples). "Gain
vs c" is the mean change in squared error against rule (c) with its paired SE; negative is better, and a
covariate counts only if the gain is larger than its SE.

Design: cases ordered by election date; each case is predicted using only cases from strictly earlier
elections. Burn-in: the first three cases (Graham, Masters, O'Connor) have fewer than three earlier
cases and are not scored, leaving **n = 15**. Predicted vote = carry x old pcv.

Rules: (a) no carry. (b) the model's own forecast row, only where the forecast row is the defector alone
(`n_cand` = 1; n = 6). (c) one pooled carry, empirical-Bayes weighted mean with w = tau^2 / (tau^2 +
se^2); on all 18, tau^2 = 0.073 (SD 0.27) and the sampling noise of a vote share is se about 0.005
(assuming 40,000 votes), so w is about 0.99: **shrinking each earlier case toward the mean does almost
nothing, because between-case spread dwarfs vote-count noise.** (d) carry from a ridge regression on ONE
standardised covariate, penalty 4 (prior SD of the effect = half the residual SD), chosen before
running; penalties 1 and 16 are shown as sensitivity. (f) a pooled mean of the new vote share ignoring
old vote (exploratory). `fixed 0.40` is the model's constant carry as a reference; it is not
time-forward, it was not fitted on these cases, but 0.40 is near the pooled mean so it is lucky here.

| rule (n = 15 scored) | MAE (SE) | RMSE (SE) | gain vs c, penalty 4 (SE) | penalty 1 | penalty 16 |
|---|---|---|---|---|---|
| (a) no carry | 19.6 (3.2) | 23.2 (3.7) | +337 (139), worse | | |
| fixed 0.40, reference | 9.8 (2.0) | 12.5 (2.5) | -46 (19) | | |
| (c) shrunk pooled carry | 11.6 (2.1) | 14.2 (2.4) | 0 | | |
| (f) pooled new share | 11.0 (2.3) | 14.0 (2.4) | -5 (16), not separable | | |
| (d) jurisdiction, federal or not | 10.4 (1.8) | 12.6 (2.1) | -42 (42), not separable | -39 (57) | -30 (22) |
| (d) label IND vs minor | 11.1 (2.1) | 13.7 (2.4) | -13 (13), 1.0 SE | -16 (15) | -8 (8) |
| (d) terms in corpus | 10.9 (2.1) | 13.5 (2.2) | -17 (35), not separable | +4 (46) | -24 (20) |
| (d) prior pcv | 11.8 (2.1) | 14.4 (2.3) | +5 (2.5), worse | +8 (4) | +3 (1.3) |
| (d) minister | 11.8 (2.2) | 14.4 (2.4) | +6 (5.7), not separable | +8 (7) | +3 (3) |
| (d) why they left (2 dummies) | 12.9 (2.2) | 15.4 (2.3) | +35 (32), not separable | +47 (42) | +18 (17) |
| (d) years since first elected | 13.0 (2.2) | 15.5 (2.2) | +38 (14), worse (2.6 SE) | +69 (28) | +13 (6.5) |

Rule (a) vs (c): gain -337 (SE 139) in favour of the shrunk carry.

### Where the model's own row can be scored (n = 6, `n_cand` = 1, scored cases)

What the numbers are: error in points, defector's own share; lower is better; n = 6 so every SE is wide.

| rule (n = 6) | MAE (SE) | RMSE (SE) | gain vs none (SE) |
|---|---|---|---|
| (a) no carry | 22.9 (6.6) | 28.1 (7.1) | 0 |
| (b) model xgb_pred | 14.9 (2.9) | 16.5 (2.3) | -517 (402) |
| fixed 0.40 | 15.1 (3.3) | 17.1 (3.8) | -496 (295) |
| (c) shrunk pooled | 16.9 (3.3) | 18.8 (3.5) | -434 (317) |

The six rows: Ryan 30.7 vs actual 8.5, Tangney 24.8 vs 11.9, Hillarys 21.7 vs 20.1, Kavel 28.4 vs 50.5,
Kelly 25.1 vs 7.4, Kiama 25.9 vs 38.8. (b) is not separable from (c) (gain -82, SE 99). On the three
federal rows of these (Ryan, Tangney, Hughes) the model is off by 22, 13 and 18 points; no carry would
be off by 8.5, 11.9 and 7.4. For the other class rows (`n_cand` of 2 or more) the forecast is for the
whole class and cannot be split out, so they are not scored here.

### Federal only, and state only (scored cases)

| subset | rule | RMSE (SE) | gain vs c (SE) |
|---|---|---|---|
| federal, n = 6 | no carry | 12.6 (3.0) | -43 (136) |
| federal, n = 6 | fixed 0.40 | 10.8 (1.4) | -85 (40) |
| federal, n = 6 | (c) shrunk pooled | 14.2 (2.2) | 0 |
| federal, n = 6 | (d) jurisdiction | 9.5 (1.7) | -111 (59), 1.9 SE |
| state, n = 9 | no carry | 28.1 (4.5) | +589 (169), worse |
| state, n = 9 | fixed 0.40 | 13.4 (3.9) | -20 (15) |
| state, n = 9 | (c) shrunk pooled | 14.2 (3.8) | 0 |
| state, n = 9 | (d) jurisdiction | 14.3 (2.9) | +4 (54) |

A hard split (federal uses only earlier federal cases, at least two) scored n = 14: RMSE 13.5 (2.2)
against 13.7 (2.5) for (c): no better than the shrunk covariate.

### Survivors (actual 30 or more)

What the numbers are: predicted share in points by each time-forward rule for the cases that kept their
vote. **Closer to the actual is better.** All rules miss by 15 to 30 points.

| case | actual | xgb (class) | none | fixed 0.40 | (c) | (d) jurisdiction | (d) label | (d) minister |
|---|---|---|---|---|---|---|---|---|
| Kavel, Cregan | 50.5 | 28.4 | 0 | 19.2 | 18.1 | 22.4 | 17.2 | 18.1 |
| Narungga, Ellis | 32.5 | 37.4 (class of 2) | 0 | 18.6 | 17.5 | 21.6 | 16.6 | 17.5 |
| Kiama, Ward | 38.8 | 25.9 | 0 | 21.4 | 23.3 | 29.2 | 21.5 | 20.9 |
| Pilbara, Graham | 54.6 | no row | 0 | 25.5 | not scored (burn-in) | | | |

The cases split in two: 5 of 11 state defectors held a large share (carry 0.70 to 1.05; 4 if the Northe
flag is wrong) against 1 of 7 federal (Gee 0.50). A mean carry cannot fit a two-humped outcome; the
model needs a chance of surviving, which this sample (6 survivors) cannot yet estimate.

## 4. Recommendation

1. **Do not move to no carry.** Shrunk carry beats it 14.2 vs 23.2 RMSE (gap 2.4 SEs), and on state cases
   no carry is catastrophic (28.1).
2. **Federal defectors need a lower carry than the model uses.** In-sample federal carry is 0.23 (n = 7,
   SD 0.13); on the six scorable federal cases a jurisdiction term cut error from 14.2 to 9.5 RMSE
   (1.9 SEs). The model's 0.355 to 0.435 is the all-jurisdiction average and is about 2 times too high
   federally. Partial-pooling carry by jurisdiction group (shrink the group mean toward the pooled
   0.43 by n / (n + k)) is the shape CLAUDE.md asks for. A federal rate near 0.23, shrunk toward 0.43,
   comes out near 0.27 to 0.30 at n = 7; I have not fitted that weight, so that figure is an
   estimate to be checked, not a result.
3. **Best time-forward rule by RMSE: shrunk pooled carry with the jurisdiction term, 12.6 (SE 2.1)
   against 14.2 (2.4) for pooled and 23.2 (3.7) for none.** It is ahead of pooled by 1.0 SE only, so
   not separable at n = 15. The fixed 0.40 reference (12.5) is as good only by being near the pooled
   mean over this window, and it is not time-forward.
4. **Who they are, apart from jurisdiction, does not earn a place:** why they left, minister, label,
   prior pcv, terms and years since first elected are all not separable at n = 15 or worse than
   no covariate (years since first elected and prior pcv are worse by 2.6 and 2.1 SEs at penalty 4).
   Minister (n = 4) and label (minor party n = 2) are far too thin to test. Re-test when the next
   state elections add cases (vic2026 will add Victorian ones; vic2014 cannot be rebuilt without
   `elected` for vic2010).
5. Not building survival probability here, but the survivor table says it is the missing piece for
   Cregan, Ward and Ellis.

## 5. Unconfirmed, and where I looked

- **Why they left and minister status** are from web search snippets and Wikipedia pages (cited per
  row). Not read in full: Masters, O'Connor, Walker, Johnson (Ryan), Thomson, Kelly, Ward, Cregan,
  Ellis, Duluk, McBride (search snippet only). "No minister" for those is "the sources I read did not
  say so", not a confirmed negative. Hillarys (Rob Johnson) reason for resigning not found.
- **First-elected years** marked unverified: Jensen, Kelly (see note), Gee, Ward, Cregan, Ellis, Duluk.
- **Morwell 2018 `elected` flag:** suspected wrong, not checked against an external result.
- **Cross-seat movers** (Banks, D'Orazio, Bowler) and the 18 unmatched by-election winners: not
  investigated; may hold missed defectors.
- **`xgb_pred` rows:** class-level, taken from `output/forecasts.csv` (built_at 2026-10-05T15:59:58Z). I did
  not check that the defector is the class leader in the model for `n_cand` of 2 or more (Dobell and
  Monash leaders are other people).
- **Sampling se for carries** used an assumed 40,000 votes per seat for the binomial noise; the
  conclusion (w about 0.99) does not depend on it within a factor of 10.
- **Federal vs state split** is in-sample (Welch p = 0.003, permutation p = 0.008, n = 7 vs 11); it is
  confounded with era (federal 2007 to 2025, WA 2001 to 2017) and with what the party did next, so it
  is a pattern to build on, not a settled effect.
- **Penalty strength** for the covariate ridge (4) was set before running; 1 and 16 give the same
  verdicts, listed above.
- I did not check in `R/` how the model's 0.355 to 0.435 is fitted beyond the figures in
  `docs/reviews/worst-overcalls-2026-10-05.md`.
