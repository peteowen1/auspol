# Plan: score our Victoria 2026 forecast against outside forecasts, frozen before polling day

Written 2026-10-20 (Pete's IDEAS.md row #29, handed over by the DEV session). No model change and no rerun. This
plan is the pre-registration: the sources, freeze dates, seat set and metrics are fixed here before any result
exists, so the comparison cannot be fitted after the count.

Election: Saturday 28 November 2026 (VEC). Writs 3 Nov, early voting from 18 Nov.

## The sources, and what each one actually exposes

Checked means fetched or read on 2026-10-20; unchecked means only the tweet or a search result was seen.

| source | seat-level data | probabilities or calls | capture | status |
|---|---|---|---|---|
| Ours (published daily forecast) | all 88 districts | per-party win probabilities | the forecast release asset as published that day (not a rebuild) | checked (it is ours) |
| AE Forecasts, `2026vic` | all 88: `seatPartyWinFrequencies` (percent per party code), plus `seatFpBands`, `seatTcpScenarios`, candidate names | probabilities | REST API, `https://www.aeforecasts.com/forecast-api/election-summary/2026vic/regular?format=json` (768,550 bytes; report dated 2026-10-17T13:09:51) | **checked** |
| Roy Morgan, finding 10346 (9 Oct; Single Source March-Sept 2026, n=7,708) | the 88-seat list is in images and a downloadable PDF, not HTML text | page text gives a One Nation "winnability" ranking and a chamber total (ALP/GRN 46, L-NP/ONP 42); whether the PDF names a winner per seat is not yet seen | save the page, every image and the PDF; transcribe by hand | **checked 21 Oct: DROPPED.** The PDF's Appendix 1 (page 4, an image) ranks the 88 districts 1-88 by One Nation "winnability" and names no winner in any seat. Per the rule below it is not proxied; only its chamber total (46-42) is reported. A later Roy Morgan release with real seat calls would be captured. |
| Alex Jago, [4PP projections from Senate results](https://abjago.net/4PP-projections-from-senate-results/2026-victoria-districts) | all 88 districts, projected from the 2025 Senate results | a CALCULATOR, not a forecast: you enter statewide GRN/ALP/LNP/ONP four-party-preferred shares and it returns per-district shares and calls; no probabilities | save the page and its scripts; record the default inputs and the per-district grid they produce, then rerun it on our own statewide 4PP (see below) | link and description from Pete's Chrome via the DEV session 20 Oct; capture mechanics **unchecked** |
| Global Election Simulator, [Victoria](https://globalelectionsimulator.com/victoria) (not poliwave) | all 88 districts, computed in the browser: a 2022 per-district baseline (`assets/data-victoria2022-*.js`) moved by statewide polling, drawn on `/victoria-districts.geojson`; the "2026 Polling" view showed L/NP 47 (Lib 40, Nat 7), ALP 22, ONP 13, GRN 6 on primaries L/NP 29.0, ALP 24.4, ONP 22.5, GRN 13.9 (DEV session, 20 Oct) | calls only; no probabilities, and no separate data file of calls | save the page, `assets/index-*.js`, `assets/page-VictoriaApp-*.js`, `assets/data-victoria2022-*.js` and the geojson raw (the content-hashed names change when the site updates, which flags a model or input change); read the per-district calls from the rendered "2026 Polling" view in Chrome | bundles fetched 20 Oct (HTTP 200, 112,107 / 546,234 / 67,104 / 26,153 bytes); where the 2026 polling inputs live in the bundle and how to read per-district calls is **unchecked** |
| **Added 24 Oct (before any result):** The Swing Is On, [VIC 2026 tracker](https://theswingison.com/track-polls/vic26) | all 88 districts: `data/vic/tap-default-result.js` holds `seatWinCounts` per seat per party out of 5,000 simulations (fixed seed 424242, 2022 candidates, Gaussian-kernel poll average), rebuilt daily as a 7-day rolling buffer keyed by date; 24 Oct: Coalition 37.2, Labor 29.8, ONP 14.6, GRN 6.0 seats | probabilities (win counts / 5,000; Ringwood ALP 2,170 = the page's 43.4%) | plain curl of the data file (no browser needed); pick the entry for the freeze date | **checked 24 Oct**, raw in `2026-10-24/theswingison/` |
| **Added 24 Oct (before any result):** Sportsbet, [seat betting](https://www.sportsbet.com.au/betting/politics/vic-politics/victorian-state-election-seat-betting-10944986) | **50 of 88** districts (event 10944986), one market per seat, party selections incl. named independents and "Any Other" | decimal odds; convert to probabilities by removing the bookmaker margin (normalise 1/price within each seat) and report the overround; seats without a market are excluded from its comparisons, with the count printed | unauthenticated JSON, `/apigw/sportsbook-sports/Sportsbook/Sports/Events/10944986/Markets` (ECOSYSTEM.md "Bookmaker odds"); competition 9519 lists the other Victorian markets (seat totals, hung parliament, government) | **checked 24 Oct**, raw in `2026-10-24/sportsbet/`. TAB checked the same day: only a statewide Premier market (Coalition 1.15), no seats; its API did not answer plain curl. **Corrected the same day: wrong.** The politics page shows only featured markets; TAB's feed `api.beta.tab.com.au/v1/tab-info-service/sports/Politics/competitions/Victorian%20Politics` lists **53 seat markets** plus the Premier market (136 KB). It answers only inside a browser session (plain curl hangs), so capture needs headless Chrome. Betfair (exchange) checked the same day: market 1.240828208 (Coalition back 1.27, AUD 134,667 matched) and only 4 seat markets (Caulfield, Bulleen, Brighton, Broadmeadows), all readable without login from `ero.betfair.com.au/www/sports/exchange/readonly/v1/bymarket` |
| **Added 24 Oct (before any result):** TAB, Victorian Politics seat markets | 53 of 88 | decimal odds, margin removed as for Sportsbet | browser-session JSON (above) | checked 24 Oct; raw not yet saved (browser-only) |

**Amendment 2 (24 Oct, before any result).** Bookmaker and exchange capture is `scripts/snapshot_benchmarks.R` through the
`oddsdata` package (`C:/dev/oddsdata`). Three things fixed here, all before a count exists:

- **Margin removal is the power method** (`oddsdata::implied_probs(method = "power")`: find `k` with
  `sum((1/price)^k) = 1`), not the "normalise 1/price" written in the Sportsbet row above. Normalising leaves too much of
  the margin on longshots; the power method takes more of it from them, which is where bookmakers put it. Both rows'
  wording stays as first written.
- **Residual selections** ("Any Other", "Other", "Any Other Result", "Any Other Party or Independent") are class
  `ANY_OTHER`, scored as the winner's probability when the winner is in none of that market's named classes. The Swing
  Is On's three "Other" buckets are `OTH_LEFT`, `OTH_RIGHT`, `OTH_UNALIGNED`, scored the same way.
- **TAB is saved by hand**, not automated: its feed is behind bot protection, and this project does not work around
  one. The snapshot prints the URL and the file name (`tab/Politics-Victorian-Politics.json`) when it is missing, as it
  does for the Global Election Simulator's calls.

Bookmaker comparisons run only on the districts each one prices, with the count printed; Betfair's 4 are reported, not
scored as a source of record.

AE Forecasts' party codes in this payload: -4 LNP, -3 OTH, -2 IND, -1 OTH, 0 ALP, 1 LNP, 2 GRN, 3 IND, 4 ONP,
5 UAP, 6 DEM, 7 NAT. Map them to our classes, with LNP and NAT merged into `LNP` as `classify_party()` does, and assert that
each seat's mapped probabilities sum to 1 within 0.01.

## Jago is a method, not a forecast: two entries

His page projects districts from whatever statewide shares it is given, so "his forecast" exists only once someone
picks the inputs. Score two entries, kept apart in every table:

- **Jago at his defaults: DROPPED 21 Oct.** The page's default inputs are GRN 17.55, ALP 38.72, LNP 34.76,
  ONP 8.97, read in Chrome by the DEV session. That looks like the 2025 Senate baseline, not a 2026 forecast, so
  scoring it would score the Senate result with no swing.
- **Jago on a published poll average (optional, reported):** the calculator fed the same statewide average the Global
  Election Simulator states on that date, if it can be put into his four-party inputs without inventing preferences.
- **Jago on our statewide numbers (the entry that counts):** the same calculator fed our own published statewide four-party-preferred split
  for that date. Against our seat calls, it tests his Senate-based seat projection on equal polling, separating the
  seat method from the statewide estimate. Our forecast gives primaries and a two-party split, not his four-way split.
  The conversion (our simulated four-party-preferred mean, if the forecast output carries one, otherwise derived from
  our primaries and flows) is fixed and written here before the first capture.

The Global Election Simulator's statewide inputs are in `assets/guide-victoria-*.js`: on 21 Oct, ALP 24.4, Coalition
29.0, ONP 22.5, GRN 13.9, IND+OTH 10.2, from polls weighted by the square root of sample size with a 21-day half-life.
When that bundle's file name changes, its polling has been updated. Its district calls are read from the rendered
map: each SVG path's fill colour gives the party, and the paths follow the geojson's feature order (checked by
centroid correlation: 0.997 east-west, -0.981 north-south). The totals match the page (LIB 40, ALP 22, ONP 13, NAT 7,
GRN 6). It has the same shape (statewide polling in, districts out), but its inputs are the
site's own and are frozen as published. It is not rerun on our numbers.

## Snapshots: when, and how they are stored

- **Freeze dates:** weekly from now (Tue 27 Oct, 3, 10 Nov), **Tue 17 Nov** (the day before early voting), and
  **Fri 27 Nov** (the day before polling day). The comparison of record uses the **27 Nov** snapshot of every
  source, and our own forecast published that same day. 17 Nov is reported beside it, because about half the vote
  is cast early.
- **Missing a freeze date:** a source that publishes nothing new carries forward its newest earlier capture, and its
  date is printed beside every number. A source first captured after 27 Nov is excluded, not back-filled.
- **Raw, as received** (CLAUDE.md scraping rule): every response saved byte for byte, one file per request, under
  `external/reference/benchmarks/vic2026/<YYYY-MM-DD>/<source>/`. That covers JSON, HTML, scripts, every image and
  the PDF. Each date gets a `manifest.tsv` with the source, URL, UTC time, HTTP status, byte count, sha256 and file.
  First capture 21 Oct, using the scratch script that becomes `scripts/snapshot_benchmarks.R`. Parse afterwards,
  never at fetch time. Check that the payload parses and carries its expected key, not its size (the 65,536-byte
  lesson). Rerun `scripts/build_data_registry.R` after each capture.
- **AE Forecasts:** a dated fetch, not `fetch_aeforecasts.R`'s cache. The existing script reuses a valid cached
  file, which would silently freeze the first capture. Add a `--snapshot` mode that always fetches into the dated
  folder.
- **Hand-transcribed sources (Roy Morgan, possibly Jago and GES):** transcribe from the saved file, not the live
  page, into `calls.csv` (`district, call_class, prob` with `prob` blank when only a call exists). Enter each one twice,
  separately, and diff the two before the result is known.
- **Frozen means committed:** each snapshot's parsed `calls.csv` is committed (small) with its date before 28 Nov.
  The raw files stay out of git with the other external data.

## Metrics: comparable only where the sources overlap

- **Seat set:** the districts every compared source covers, from its 27 Nov snapshot, matched to the VEC's 88 names
  by exact name (assert 88 matched for full-coverage sources). Each comparison prints its seat count.
- **Outcome:** the VEC's declared winner, classed by `classify_party()`. Score only after the distribution of
  preferences is complete for every district. A district still in doubt is held out and counted, not guessed.
- **Probability sources (ours, AE Forecasts, any other that publishes them):** seat-winner log loss on the
  actual winner's probability, clamped at 1e-6, with the 1e-4 floor reported beside it (CLAUDE.md: the floor moves
  pooled numbers). Brier is second. Lower is better for both. The headline is the paired per-seat difference against
  ours, with its SE over seats.
- **Every source:** accuracy of the favourite or call (ties excluded and counted), and the seat total per class
  against the actual.
- **The SE is for one election:** seats in one election share one statewide error. The SE over 88 seats overstates
  the precision, and the write-up says so; no "significant" claim from one election.
- **n beside every number:** for example, "log loss 0.27 (n=88 seats, 27 Nov snapshots)", and "accuracy 79/88" in
  place of a bare 90%.
- **Reported, not decisive:** the 17 Nov snapshot; Roy Morgan's chamber total against the actual; AE Forecasts'
  first-preference bands against the VEC primaries (it is the only outside source with primaries; Bonham notes Roy
  Morgan publishes none).

## Named in advance

- Our own entry is what the site showed on 27 Nov. A later rerun, or a fix made after the result, is not scored here.
- Sources that give only calls are compared with ours on accuracy alone, never on log loss.
- A source that turns out to expose no per-seat data (Roy Morgan's PDF may be a winnability score only) is dropped
  with that reason written here. It is not proxied.

## Steps

1. Fix the conversion from our forecast to Jago's four-party-preferred inputs (above), and find how to read the
   Global Election Simulator's per-district calls (the rendered view, or the bundle's polling inputs).
2. Add `--snapshot` to `scripts/fetch_aeforecasts.R` and write a small `scripts/snapshot_benchmarks.R` that
   captures every source raw into the dated folders (Chrome network capture where there is no API).
3. First capture now (27 Oct at the latest). Add the freeze dates as reminders in the Daily Eight.
4. After the VEC declares: `scripts/score_benchmarks_vic2026.R` reads only the committed `calls.csv` files plus the
   VEC results and prints the tables above.

## Amendment 1 (2026-10-22, before the first capture that counts): how the capture is done, and Jago's inputs

Added, not edited: the clauses above stand as written.

- **Jago's inputs from our forecast.** The clause above allowed "derived from our primaries and flows". Fixed now as
  primaries only, with no flows: his calculator's inputs are the four parties' first-preference shares with every
  other vote shared among them in proportion (his `calculator.js` builds his own defaults that way, from "None"), so
  the same quantity from our forecast is each party's mean first-preference share across the 88 districts in that
  day's published `seat-shares-vic-2026.csv`, the four renormalised to 100. Equal weight per district. Using flows
  would feed him a quantity his model does not take. 22 Oct: GRN 16.33, ALP 28.30, LNP 31.83, ONP 23.54 (the four
  are 90.5% of our vote).
- **His calculator is run, not ported.** `scripts/jago_calc.js` runs his saved `calculator.js` unmodified in Node.
  Checked 22 Oct against his live page at two inputs: same seat tallies (defaults: Lab 68, Lnp 19, Grn 1; ours: Lab
  41, Lnp 39, Grn 6, Phn 2) and the same winner in four sampled districts.
- **Capture:** `Rscript scripts/snapshot_benchmarks.R` on each freeze date (the plan's step 2). It fetches raw into
  the dated folder with a manifest, accepts a file only when its content checks pass, resumes, and writes the
  committed calls to `docs/benchmarks/vic2026/<date>/<source>-calls.csv` (exits 1 if any source is missing). The AE
  Forecasts fetch is in this script, always fresh, rather than a `--snapshot` mode in `fetch_aeforecasts.R`; same
  effect, one script.
- **GES needs one Chrome step per date**: run `scripts/ges_read_calls.js` in the page, paste its rows into the dated
  `ges/ges-district-calls-read-from-page.csv`, and save the `guide-victoria-*.js` bundle it names (that bundle is
  not linked from any file the script can fetch). 22 Oct: calls identical to 21 Oct district for district (47/22/13/6)
  although both its app and polling bundles changed hash.
- **Not done:** the optional "Jago on a published poll average" entry.
