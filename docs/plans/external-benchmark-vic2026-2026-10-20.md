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
