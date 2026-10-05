# Breakout candidates: what signals existed before polling day (2026-10-05)

Scope: Cluster D, 16 first-time breakouts in `output/forecasts.csv` (as-at, honest; 11,905 rows,
18 elections). Signed error = `actual_share - xgb_pred` (`err_xgb` is absolute). Read-only
investigation; scripts in the session scratchpad (`clusterD/a1..a8.R`), nothing in R/, scripts/ or
output/ was edited. `xgb_pred` is BEFORE the seat-poll blend (the blend is applied to shares after
xgb), so poll effects are shown separately below.

## 1. Per-breakout signal table

What it shows: for each breakout, the model's primary-vote call against the result, then each
pre-election signal found and whether the model consumed it for that row. Points are primary vote %.
Win prob = our probability for the class that actually won (or, where the breakout lost, for the
IND class), from `output/forecasts-seats.csv`.

| Election / seat / candidate | pred | actual | err | Seat poll before day (our file) | Endorsement (in data) | Local-government record | Trends jump pctile (consumed as feature `jump`) | IND win prob |
|---|---|---|---|---|---|---|---|---|
| fed2013 Indi McGOWAN | 8.3 | 32.1 | +23.8 | none in file | none (Voices for Indi existed, not in table) | none | 1.00 | 0.00005 (won) |
| fed2016 Mayo SHARKIE (NXT) | 9.2 | 34.9 | +25.7 | 3 polls in file, TCP only, **primary missing**; web: ReachTEL May 2016 NXT 23.5% | none (NXT is a party) | none | 0.97 | 0.019 (won) |
| fed2019 Warringah STEGGALL | 20.4 | 44.7 | +24.3 | ReachTEL/GetUp 9 Feb 2019: IND 22.3 (98 days out, outside the 90-day window; fed2019 blend weight is 0) | `c200=1` but source row is `verified=no` (SBS donations story); no training example before it | none | 0.84 | 0.053 (won) |
| fed2022 Mackellar SCAMPS | 10.8 | 38.1 | +27.3 | uComms 7 Apr: IND 23.9 | c200=1, voices=1 | none | 0.98 | 0.156 (won) |
| fed2022 Goldstein DANIEL | 11.4 | 34.5 | +23.1 | uComms 2 and 16 May: IND 33.1, 35.3 | c200=1, voices=1 | none | 0.99 | 0.251 (won) |
| fed2022 Curtin CHANEY | 9.6 | 29.5 | +19.9 | Utting 14 Mar 24; 16 May 32 | c200=1, voices=1 | none | 0.98 | 0.167 (won) |
| fed2022 Kooyong RYAN | 23.2 | 40.5 | +17.3 | uComms 12 Apr: IND 31.8 | c200=1, voices=1 | none | 1.00 | 0.712 (won) |
| nsw2023 Wakehurst REGAN | 10.1 | 35.9 | +25.8 | Sky News 1 Mar: TCP only, no primary | none | Mayor of Northern Beaches 2017-23 ([Wikipedia](https://en.wikipedia.org/wiki/Michael_Regan_(Australian_politician))); our data: `council_elected`=TRUE, `council_mayor`=FALSE | 1.00 | 0.091 (won) |
| vic2014 Shepparton SHEED | 5.5 | 35.2 | +29.7 | none | none | none in data | no row (state not in salience corpus) | 0.024 (won) |
| nsw2019 Murray DALTON (SFF, class OTH_RIGHT) | 6.0 | 40.3 | +34.3 | none | none | none | no row | 0.0005 (won, as OTH_RIGHT) |
| nsw2019 Barwon BUTLER (SFF, OTH_RIGHT) | 5.3 | 36.4 | +31.1 | none | none | none | no row | 0.0001 (won, as OTH_RIGHT) |
| sa2022 Flinders HABERMANN | 1.5 | 27.2 | +25.7 | none | none | councillor (`council_elected`=TRUE, 1 run) | no row | 0.004 (lost) |
| vic2018 Benambra HAWKINS | 8.0 | 29.2 | +21.2 | none | none (c200 row is vic2022, not 2018) | none | no row | 0.009 (lost) |
| vic2018 Pascoe Vale YILDIZ | 9.9 | 32.9 | +23.0 | none | none | Moreland mayor 2010-11 and 2012-13 ([search result, Merri-bek/Wikipedia](https://en.wikipedia.org/wiki/Electoral_results_for_the_district_of_Pascoe_Vale)); our data: elected TRUE (3 runs, 28.4% council share), mayor FALSE | no row | 0.024 (lost) |
| nsw2019 Dubbo DICKERSON | 5.0 | 28.4 | +23.4 | none | none | Dubbo mayor 2011-16, councillor 2004-16 ([Daily Liberal](https://www.dailyliberal.com.au/story/5421720/dickerson-announces-he-will-stand-as-independent-at-nsw-election)); our data: elected TRUE, mayor FALSE | no row | 0.011 (lost) |
| sa2022 Kavel CREGAN (sitting Liberal turned IND) | 29.7 | 50.5 | +20.8 | none | none | none | no row | 0.882 (won) |

What the model actually used for each row (all 46 features are in every as-at model):
- Seat-poll blend: not in `xgb_pred`. Approximate blended primaries at the fed2022 weight 0.450
  (my arithmetic, not a re-run): Mackellar 10.8 -> 16.7 (actual 38.1), Goldstein 11.4 -> 21.7 (34.5),
  Curtin 9.6 -> 17.9 (29.5), Kooyong 23.2 -> 27.1 (40.5). Every polled breakout stayed 11-21 points low.
- Endorsement (v59), measured as asat prediction v59 minus v58 snapshots
  (`output/snapshots/20261002-1435-0a481f6-from3` vs `...-1930-d7c53b7-from3`): Mackellar +0.2,
  Goldstein 0.0, Curtin +0.2, Kooyong -0.2, Warringah 0.0, Wakehurst -0.6 (not endorsed, retrain noise),
  Mayo +0.8, Indi -0.1. The fed2022 models had exactly one endorsed training row (Steggall 2019, flagged
  `verified=no`), so there was nothing to learn from. The endorsement feature contributed about nothing
  to any Cluster D row; it only helps later teals (Pittwater 2023, Cowper/North Sydney 2022 etc.).
- Council features: Wakehurst, Flinders, Pascoe Vale, Dubbo all have `council_elected`=TRUE yet were
  predicted 1.5-10.1. `council_mayor` is TRUE for only 11 of 6,478 minor-class rows and none of those
  breakouts (see section 3), and three confirmed ex-mayors (Regan, Yildiz, Dickerson) are coded FALSE.
- Trends jump: consumed as `jump` (value 0.05-0.77 for the federal rows), no visible effect.

## 2. Best single signal

Universe: 6,478 minor-class rows (IND, OTH, OTH_RIGHT, ONP), 57 breakouts defined as actual
beat prediction by 15+ points. Counts below are for rows the model gave under 15 (6,275 rows,
48 breakouts; base rate 0.77%). "False" = flagged, not a breakout. Coverage limits apply to every row.

Higher precision is better; recall is the share of the 48 caught.

| Signal | Coverage | Flagged | Hits | False alarms | Precision | Recall | Cluster D hits (of 16) |
|---|---|---|---|---|---|---|---|
| Trends salience jump, within-election pctile >= 0.9 | 9 pairs only (fed2010-22, nsw2023, vic2022, sa2026, wa2008) | 95 | 9 | 86 | 9.5% | 19% | 7 (Indi, Mayo, Mackellar, Goldstein, Curtin, Kooyong, Wakehurst) |
| Trends jump >= 0.05 | same | 51 | 8 | 43 | 15.7% | 17% | similar |
| Council office (elected) | most state/fed pairs | 150 | 11 | 139 | 7.3% | 23% | 4 (Wakehurst, Flinders, Pascoe Vale, Dubbo) |
| Climate 200 / Voices endorsement | fed2022+, nsw2023, vic2022 only | 34 | 5 | 29 | 14.7% | 10% | 3 (Mackellar, Goldstein, Curtin); 4-5 if Kooyong and Warringah (>15 pred) counted |
| Seat poll class >= 20% within 90 days | 879 polled rows, mostly fed2022/2025 | 22 | 3 | 19 | 13.6% | 6% | 4 incl. Kooyong |
| Any of endorsed, poll >= 15, council | | 223 | 16 | 207 | 7.2% | 33% | |

Verdict (stated plainly):
- Fewest false alarms per hit and biggest reach is not a single signal. Trends salience has the most
  recall on Cluster D (7 of 16, all federal plus Wakehurst), but 9 false alarms per hit, and **the model
  already consumes it** (`jump`, `governed`, `permit`) and still called 8-23%.
- Of signals the model does NOT yet use properly, the best value is **correct mayor/councillor coding**:
  3 of the 4 state breakouts with a council record were mayors, and `council_mayor` is effectively dead
  (11 flags, 0 hits) because it is not populated from the mayoral rolls. Acquire: mayoral election
  results and mayor tenure tables for NSW, Vic, SA, Qld, WA councils (we hold `council-results-*.csv`;
  check why mayors are missing before buying anything). Precision after fixing is unknown, so I cannot
  quote hit/false counts for it.
- Second: **seat-poll primaries**. Our file has 7,245 rows but state seat polls are nearly absent
  (nsw2023 12 seats, others 1-14), and Mayo 2016 has TCP only although the 23.5% primary was published.
  Acquire primaries for the 2016 Mayo, 2019 Warringah, nsw2023 Wakehurst polls and any state seat polls.
- Third: **state Trends series are already on disk** (`external/reference/trends/v6_AU_NSW_2018_*`,
  `v6_AU_NSW_2022_*`, `v6_AU_VIC_*`, `v6_AU_SA_2021_*`) but were never built into the salience population,
  contradicting `docs/DATA-REGISTRY.md:184` ("every one is federal. No state candidacy has ever been
  queried"); the registry line is stale and the population has 9 pairs. Readouts I took: Regan 69-88%
  share of his batch in the final 8 weeks, Roy Butler 2019 zero hits (no signal), Dalton and Dickerson
  batches too thin to read. Weak evidence either way.
- Climate 200/Voices cannot be a time-forward fix for the first wave (2022, Warringah 2019, Indi 2013):
  there is no earlier training example. It is already shipped for later waves.

## 3. Size

16 rows of 11,905 (0.13%) carry 10,089.6 of 194,679 total squared error = **5.18%** (4.96% without
Kavel). RMSE 4.044 -> 3.940 without them. All 16 are inside the worst-100 rows by squared error (ranks
3, 5, 6, 8, 9, 10, 11, 15, 18, 19, 20, 21, 25, 29, 36, 57 across the full list of 11,905). Mean signed
error of the 16 is +24.8 points. Fixing the whole cluster would cut pooled RMSE by about 2.6%.

## 4. A mean shift cannot fix the ones with no signal

Dalton, Butler, Shepparton, Benambra, Habermann, Cregan: no seat poll, no endorsement, no usable record in
our data. Four more (Indi, Mayo, Wakehurst, Pascoe Vale/Dubbo) had only weak or miscoded signals. A flagged
rate near 10% with a +25 point jump gives an expected correction of about +2.5 points, not +25, and
pushing the mean for 86 false alarms per 9 hits would hurt the rest (the upset-floor test already
showed blanket and targeted shifts fail Brier, `docs/reviews/upset-signal-2026-10-02.md`).
The honest fix is wider uncertainty for under-expected minor candidates in seats with a weak incumbent
share, not a higher mean. Current behaviour: the IND class win probability for these seats was 0.00005
(Indi), 0.0005 and 0.0001 for the two Shooters winners, 0.004-0.024 for Flinders, Benambra, Pascoe Vale,
Dubbo and Shepparton, 0.02-0.25 for the teals. Each winner at <0.1% costs about 7+ nats of log loss
(floor eps 1e-6). Kavel was well called (0.88).

## Unconfirmed, and where I looked

- Whether `forecasts-seats.csv` win_prob already includes the v50 poll blend: its Goldstein 0.251,
  Curtin 0.167 and Mackellar 0.156 differ from the plan's blended 0.365, 0.246, 0.208, so it may be
  pre-blend or a different vintage. Not resolved. My blended primaries are hand arithmetic.
- Climate 200 announcement dates: almost none in `endorsements.csv`, so "known before polling day" is
  assumed. The Steggall 2019 row is `verified=no`; I did not confirm what that source says.
- Mayo 2016 ReachTEL NXT 23.5% came from a web-search summary of pollbludger/InDaily
  ([InDaily](https://indaily.com.au/news/2016/06/01/xenophon-believes-mayo-could-fall),
  [Poll Bludger](https://www.pollbludger.net/2016/06/03/private-polling-round-bass-sturt-mayo-cowan/)),
  pages not opened. Warringah 2019 Lonergan/GetUp poll (Abbott 38%, Steggall 56-44 TCP) from a search
  summary, primary for Steggall not seen; later 2019 Warringah polls are not in our file.
- Yildiz primary: the search summary said 23.5% ([Wikipedia electoral results](https://en.wikipedia.org/wiki/Electoral_results_for_the_district_of_Pascoe_Vale)), our data says 32.9. Not reconciled. Check
  `candidacies.csv` for that row.
- Indi 2013 "Voices for Indi" as a pre-election group: from my own knowledge, not checked in this session.
- No media, funding or social-volume searches done for Sheed, Dalton, Butler, Habermann, Hawkins.
- Council mayor miscoding cause not diagnosed (read-only); only counts and three web-confirmed examples.
- Breakout cut-off (actual - pred >= 15) is mine; counts shift with it.
