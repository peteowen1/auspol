# Source scour for Victoria 2026: what else we could use (2026-10-11)

Pete asked for a sweep of Kevin Bonham, The Poll Bludger, the ABC Victorian guide, Antony Green's blog
and the Wikipedia 2026 Victorian election pages "for anything else we can and should use".
Five research agents read them. Haiku agents died on the large pages (3 of 4 retried on Sonnet).
Everything was read through page summaries, so a figure here is **unverified unless marked CHECKED**:
CHECKED means verified in this session against our own data or the primary source.

## Act on these

1. **The newest Victorian poll is missing from the live forecast. CHECKED.** RedBridge/Accent for the AFR,
   fieldwork 2-8 Oct 2026, n=1,008: Coalition 30, Labor 24, One Nation 24, Greens 16; 2PP Coalition 56-44 v
   Labor, Labor 55-45 v One Nation. It is in neither AE's `poll-data-vic.csv` (last row Freshwater 2026-09-26,
   clone 39cb2c0 pulled 2026-10-11 01:12) nor our Wikipedia cache of 2026-10-09 (last Freshwater 2026-09-28).
   Wikipedia lists it now. Source: https://www.pollbludger.net/2026/10/10/victorian-election-minus-seven-weeks/
2. **Preference flows from real counts, the main lever on One Nation's seat count.** Published seat
   projections at about the same One Nation primary run from 12 to 25 seats on the flow assumption alone
   (Bonham, 17 Jul).
   - Nepean by-election, 2 May 2026 (Antony Green): One Nation excluded 77.5% to Liberal, 22.5% to the
     independent; Greens excluded 70.1% to the independent, 20.6% Liberal, 9.3% One Nation. The Liberal
     how-to-vote card recommended One Nation, and One Nation's recommended Liberal.
     https://antonygreen.com.au/2026-nepean-by-election-result-commentary/
   - Secret Harbour WA by-election, Aug 2026: Liberal to One Nation 59.3% on the official count (Bonham),
     70.2% on Green's early sample (upper bound 74.3%); Greens about 90% Labor, 10% One Nation.
     https://antonygreen.com.au/preference-flows-at-the-secret-harbour-by-election/
   - Bonham: pollsters' One Nation v Labor 2PPs use respondent-stated preferences (Redbridge, Morgan, YouGov,
     Spectre, Fox&Hedgehog), which probably understate the Coalition-to-One Nation flow because about half of
     Coalition voters follow the card. https://kevinbonham.blogspot.com/2026/09/the-flat-field-another-polls-are-wrong.html
   - Liberal statewide preference order: not published. The Nine papers report One Nation above Labor by
     default; Wilson's office denied it was discussed. SA Liberals did put One Nation above Labor in March 2026.
   - **Next check:** print the Liberal-to-One Nation and One Nation-to-Liberal flows the published Victorian
     forecast actually uses, against these ranges.
3. **Nomination close is 9 November 2026, 12 noon. CHECKED** on the VEC's amendments page
   (https://www.vec.vic.gov.au/about-us/legislation/electoral-act-amendments-2026). The roll closes 8 pm on
   3 November. Wikipedia's "13 November" comes from the VEC's 2025 draft service plan, which the 2026
   amendments superseded.

## Cross-checks that passed (CHECKED against `output/candidacies.csv`)

- Present: Warren Pickering (One Nation, Pakenham; One Nation's leader), Ali Cupper (IND, Mildura),
  Shima Ibuki (IND, Hawthorn), a Greens candidate in Brunswick (Adam Pulford).
- Correctly absent: Jacqui Hawkins (Benambra, not running), Andrew Kilmartin (Liberal, Ripon, withdrew Dec 2025).
- One Nation has 79 vic2026 rows in our list; Hanson said in July that 74-76 seats were locked in.
- ABC's directory has about 503 candidates (the fetch tool's own tally) against our 501: diff by name on
  nomination day, when the VEC list replaces both anyway.
- Not yet checked: withdrawals on Wikipedia's candidates page (Gourisetty, Cosgriff, Deeming moved to Family
  First, Johannes, Hansford). Most are Legislative Council candidates, which our model does not use.

## Benchmarks (other people's numbers, for comparison only)

| Who, when | Coalition | Labor | One Nation | Greens |
|---|---|---|---|---|
| Bonham aggregate, 17 Jul (primary %) | 27.3 | 26.0 | 23.7 | 12.8 |
| AE nowcast (seats) | 37 | 30 | 13 | 5 |
| The Swing Is On (seats) | 37 | 33 | 13 | 5 |
| Redbridge MRP median, Jun (seats) | 39 | 35 | 12 | 2 |
| Poll Bludger model, Sep update (seats) | 38 | | | |

Numbers are primary vote in percent (first row) or seats won out of 88 (other rows); none is better or
worse, they are other forecasters' outputs. Poll Bludger's model uses the federal-to-state relationship,
the Voice result, outright home ownership and Coalition incumbency. Roy Morgan has a seat "winnability"
page that may hold per-seat numbers (not fetched; terms unknown):
https://www.roymorgan.com/findings/10346-victorian-state-voting-intention-by-seat-winnability-september-2026

## Seat lists (opinion and press leaks; low weight, useful as a check list for close seats)

- Bonham (17 Jul, Redbridge primaries): One Nation within 2 points of Labor or ahead in Greenvale,
  Kalkallo, Mill Park, Cranbourne, Narre Warren North, Sydenham, Lara, Macedon, Frankston, Carrum.
- One Nation "hit list" (AFR, 8 Oct, via Poll Bludger), Labor-held: Lara, Bendigo West, Bendigo East, Eureka,
  Sunbury, Melton, Yan Yean, Ripon, Hastings, Pakenham, Bass. Liberal: Evelyn, Berwick, Benambra.
  Nationals: Gippsland East, Gippsland South, Murray Plains, Euroa, Morwell, Mildura.
- ABC key seats with margins: https://www.abc.net.au/news/elections/vic/2026/guide/key-seats

## Context facts (unverified)

- Ben Carroll succeeded Jacinta Allan as Premier in July 2026; Jess Wilson leads the Liberals.
- Tim Read (Greens, Brunswick, not recontesting) died around 20 Sep 2026; no by-election.
- By-elections this term: Warrandyte (Aug 2023), Mulgrave (Nov 2023), Werribee (Feb 2025), Prahran
  (Feb 2025, Liberal gain from the Greens), Nepean (May 2026).
- Retiring Assembly members include Bill Tilley (Benambra). Wikipedia lists 18 retiring Assembly seats,
  inconsistently with its own count; check against `candidate_returns()` on nomination day.
- No new redistribution: margins are on the 2021 boundaries (ABC, Green, Wikipedia agree).
- 18 parties registered with the VEC, new ones including Free Palestine Party and The West Party.

## Not found anywhere

Published Victorian seat polls (only one, Hawthorn, Aug 2025, already in our scrape); the Liberal statewide
how-to-vote order; a machine-readable Poll Bludger feed for 2026 (BludgerTrack is JavaScript-rendered and
would need a browser capture); Kevin Bonham on X (HTTP 402 to logged-out readers).
