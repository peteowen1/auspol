# ABC Victorian election coverage vs our forecast (2026-10-03)

Result in one line: ABC publishes NO forecast, probabilities, poll average or calculator that we could find. Its coverage is qualitative seat guides plus a pendulum. There is nothing numeric to validate against, only claims to sanity-check. Nothing of ABC's was reimplemented.

## What ABC published (all fetched via WebFetch, 2026-10-03; summaries are from a small model reading each page, so quotes are paraphrase-grade, not verbatim-verified)

- Analysis by Casey Briggs, dated Sat 2026-10-03: https://www.abc.net.au/news/2026-10-03/victorian-state-election-unpredictable-casey-briggs-analysis/107216078 ("One Nation may end up with the balance of power after Victoria's election").
- Election Preview: https://www.abc.net.au/news/elections/vic/2026/guide/preview
- Key Seats: https://www.abc.net.au/news/elections/vic/2026/guide/key-seats (15 Labor-held and 6 Coalition-held seats, with margins)
- Guides index: https://www.abc.net.au/news/elections/vic/2026/guides (Preview, Electorates, Candidates, Legislative Council Preview, Key Seats, Retiring MPs, Pendulum)
- Also found in search, not fetched: .../guide/electorates, .../guide/lc-preview, per-seat pages (e.g. .../guide/ashw, .../guide/beea), 2026-10-01 Labor upper house ticket story.

## (a) Statewide figures, ABC vs ours

Numbers are seat counts (of 88, 45 to govern), vote shares and probabilities. Higher is not good or bad; the question is only whether the two sources agree.

| Quantity | ABC | Ours (forecast-vic2026.json, built 2026-09-30 13:00 UTC, file mtime 2026-09-30 23:22, git 5b06a41, 20,000 sims) |
|---|---|---|
| Notional seats now | ALP 56, Lib/Nat 29, Greens 3 | Same baseline (Antony Green's pendulum, 25 Jul 2026, gives the same) |
| Seats to govern | Coalition needs 16 more | majority = 45 (agrees) |
| Expected seats | none published | ALP 36.28, LNP 36.24, ONP 10.61, GRN 4.86, IND 0.01 |
| P(majority) / P(most seats) | none published | ALP 16.0% / 54.0%; LNP 15.1% / 48.5% (the two overlap; ties) |
| P(hung parliament), P(ONP balance of power) | qualitative only ("may end up with the balance of power") | 68.95%, 67.04% |
| Vote shares | "Labor >10 points below 2022"; "split roughly four ways: Labor, Coalition, One Nation, everyone else"; no percentages | our vic-page-data.json (as_of 2026-09-19, mtime 2026-09-19, STALE) had LNP 28.6, ALP 25.0, ONP 20.6, GRN 12.9, OTH 11.0 |
| Poll average | none | n/a |
| Methodology | key-seats page: 2022 results, 2021 Census, 2023 by-election, 2025 federal by-election comparisons | ours in ARCHITECTURE.md |

Our qualitative read agrees on direction: ALP and LNP level, One Nation holding the balance. Not a numeric validation.

Caveat on our file: it sits in `output/.unrestored/20261001-130418-783840/`, not in `output/` proper; I could not find a newer forecast-vic2026.json. NEXT-STEPS mentions v56 live on 09-30 (ALP 36.3, Coalition 36.2), which matches this file. Whether anything newer was published since is not confirmed.

## (b) Seats where ABC's description and our probabilities diverge most

ABC gives words, not numbers, so "differ" means our probability sits awkwardly against ABC's description. ABC margins are from its key-seats page (unverified beyond that one read).

| Seat | ABC says | Our favourite (win prob) | Gap |
|---|---|---|---|
| Bass (ALP 0.2%) | most marginal Labor seat, ONP competitive | LNP 81.9%, ONP 13.5%, ALP 4.6% | we are far more confident than a 0.2% margin implies |
| Pakenham (ALP 0.4%) | Labor retention "almost inconceivable"; ONP leader Pickering standing | LNP 43.2%, ONP 39.8%, ALP 17.0% | agrees on Labor losing; we split LNP vs ONP, ABC does not say which |
| Mulgrave (ALP 10.8%) | a test of depth of anti-Labor feeling | ALP 99.3% | we treat it as safe |
| Lara (ALP 15.9%) | ONP rise changes arithmetic; similar to SA's Light | ONP 65.9%, ALP 33.6% | ours is bolder than ABC's wording; worth a look |
| Eureka (ALP 7.2%) | ONP "may be positioned to win" | ONP 67.7% | consistent |
| Sunbury (ALP 6.4%) | suits ONP demographics | ONP 65.2% | consistent |
| Niddrie (ALP 6.7%, Premier Carroll) | loss would be first sitting major-party leader to lose seat since 1945 | ALP 44.8%, ONP 36.1%, LNP 19.1% (Labor favoured only narrowly) | we put his loss at ~55%; ABC gives no number |
| Evelyn (LIB 5.4%) | ONP is a threat | LNP 98.9% | we see almost no threat |
| Hawthorn (LIB 1.7%) | Climate 200 independent Shima Ibuki stronger than predecessor | LNP 96.9%, no independent shown above 3% | possible gap on the independent; check our candidate list |
| Preston (ALP 2.1%) | Greens best placed | ALP 88.6%, ONP 9.4%, Greens under 3% | clear disagreement |
| Albert Park (ALP 11.2%) | Greens possible | ALP 78.3%, GRN 15.1% | roughly consistent |
| Morwell (NAT 4.4%) | ONP biggest threat to Nationals | LNP 54.5%, ONP 45.4% | consistent |
| Mildura (NAT 14.1%) | independent Ali Cupper running again | LNP 87.9%, ONP 11.3% | we show no Cupper chance; check |

Biggest flags: Preston (ABC says Greens best placed, we give Greens under 3%), Hawthorn and Mildura (independents not visible in our probabilities), Evelyn (ONP threat vs our 1%). Read the Preston, Hawthorn and Mildura rows as "inspect our candidate lists", not as ABC being right.

## (c) Could not load or confirm

- The X post (https://x.com/caseybriggs/status/2105897329664389394): HTTP 403. Its text is unknown. The ABC link above was found via search instead.
- ABC Pendulum page, Electorates A-Z, Candidates, Retiring MPs, Legislative Council Preview and per-seat pages: not fetched or only seen in search titles. A seat-level swing calculator or probability tool could exist there; the guides index showed none, but the extraction was by a small model and may have missed interactive widgets (unverified).
- Any ABC poll average or "who is favoured" call: none found on the pages fetched; absence is not proven site-wide. ABC may add a forecast closer to the election.
- Verbatim quotes: the fetch tool returns model summaries, so all figures above should be re-read on the live pages before being quoted publicly.
- Our seat probabilities are from the 2026-09-30 build. Preston/Mulgrave/Lara outputs above were not diagnosed here (Lara ONP at 66% and Mulgrave ALP at 99.3% look unusual; not investigated).
- Antony Green's pendulum post (https://antonygreen.com.au/2026-victorian-election-pendulum/, 2026-07-25, updated 07-28) is not ABC-hosted: Redbridge poll ALP 26, Coalition 26, ONP 27, Greens 13; Coalition needs 7.6% uniform swing (unverified small-model read).
