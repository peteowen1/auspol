# ABC News Victorian election 2026 coverage: data we can use or validate against (2026-10-03)

Method: WebFetch/WebSearch only, 2026-10-03. Every ABC page was summarised by WebFetch's small model, not read raw,
so every extracted name/number below is **unverified against the page itself** (see "Could not load or confirm").
Compared with `output/candidacies.csv` vic2026 rows (file dated 2026-09-28; 379 rows, 88 seats; ALP 74, LNP 67, GRN 76, ONP 30 (30 seats),
IND 18, OTH_RIGHT 14, OTH 100). No R run, nothing under R/, scripts/ or output/ touched.

## Sources (all fetched 2026-10-03; ABC pages carry no visible page date, ABC guide index shows articles dated 2026-08-03 to 2026-10-03)

| What | URL |
|---|---|
| Announcement tweet (Casey Briggs) | https://x.com/caseybriggs/status/2105897329664389394 : HTTP 403, NOT loaded |
| Guide index | https://www.abc.net.au/news/elections/vic/2026/guide |
| Candidates A-Z (all seats) | https://www.abc.net.au/news/elections/vic/2026/guide/candidates |
| Electorates A-Z (party, margin, 88 seats, seat codes) | https://www.abc.net.au/news/elections/vic/2026/guide/electorates |
| Pendulum (56 ALP / 29 Coalition / 3 other) | https://www.abc.net.au/news/elections/vic/2026/guide/pendulum |
| Key seats (Casey Briggs) | https://www.abc.net.au/news/elections/vic/2026/guide/key-seats |
| Per-seat pages, pattern `.../guide/<4-letter code>` | e.g. /shep, /pasc, /nort, /morn, /nidd, /nepe, /oakl |
| Coalition path to victory | https://www.abc.net.au/news/2026-08-22/coalition-path-to-victory-victoria-state-election-2026/107063196 |
| One Nation leader + upper house candidates | https://www.abc.net.au/news/2026-08-03/one-nation-victoria-candiates-revealed/106989410 |
| Labor upper house tickets | https://www.abc.net.au/news/2026-10-01/victoria-labor-upper-house-ticket-mp/107215764 (search snippet only, not opened) |

## Is a full candidate list available? (matters for the nomination-zeroing gate)

**No, not final.** Each per-seat page carries the caveat "Candidates are added as announced and this list may be incomplete until
nominations close" (seen verbatim on Shepparton and Pascoe Vale pages). The A-Z candidates page is live and was updated as recently
as 2026-10-03 (per the index, unverified), but it has no stated "as at" date and ABC does not say when nominations close (not stated on any
page I loaded; check VEC). ABC's list therefore cannot serve as the post-close ALP and LNP all-88 check; use the VEC nomination list.

Per ABC at fetch time, seats with **no Labor candidate listed**: Benambra, Euroa, Malvern, Mildura, Mornington, Nepean, Ovens Valley, Warrandyte
(8; Mornington and Nepean confirmed on their own seat pages, the rest only from the A-Z extraction). Seats with **no Liberal/National candidate
listed** (of seats extracted): Brunswick, Dandenong, Lara, Pascoe Vale, Preston, Richmond, Thomastown, Wendouree (8) plus Cranbourne and Narre Warren North
not extracted. Pendulum seats ABC calls Coalition-held show a Nationals candidate in Shepparton (Shane Sali) which our file lacks.

## Coverage of the A-Z extraction

WebFetch returned rows for 75 of 88 seats (three chunked calls). Missing from the extraction: Cranbourne, Eildon, Eltham, Essendon, Mornington, Narracan,
Narre Warren North, Narre Warren South, Nepean, Niddrie, Northcote, Oakleigh, Pascoe Vale. I then fetched seat pages for Pascoe Vale, Northcote, Mornington,
Niddrie, Nepean, Oakleigh (6 of the 13); Cranbourne, Eildon, Eltham, Essendon, Narracan, Narre Warren North/South not checked.
The tool also invented a seat ("Braybrook") and printed row totals (357/333/318) that I do not trust; Lara showed Alison Marchant (ALP) and Mitch Pope (GRN),
who are Bellarine candidates, so the Lara rows are suspect. Treat all as leads to verify, not data.

## Discrepancies: ABC lists, our vic2026 rows lack (columns: seat | candidate and party per ABC | what ours has | confidence)

Higher is not better here; each row is a gap to check against VEC. "ours" = candidacies.csv party class.

| Seat | ABC lists | Ours | Confidence |
|---|---|---|---|
| Bendigo East | Tim Rickwood ALP; Liz Wright IND | no ALP | extraction only |
| Bendigo West | Brenton Baldwin ALP; David Hutchings NAT; Ellen Morgan ONP | no ALP, no LNP, no ONP | extraction only |
| Bulleen | Timothy Dale ALP; Mahdi Athari ONP; Greg Rublee IND | no ALP, ONP, IND | extraction only |
| Gippsland South | Amy Barry-Macaulay ALP | no ALP | extraction only |
| Lowan | Sue Pavlovich ALP; Jeff Moran GRN | no ALP, no GRN | extraction only |
| Murray Plains | Christine Grundy ALP | no ALP | extraction only |
| Albert Park | Andrew Cook LIB; Georgie Dragwidge IND; Daniel O'Neill AJP | no LNP, no IND | extraction only |
| Broadmeadows | Baris Duzova LIB; Ethan Keirs ONP | no LNP, no ONP | extraction only |
| Clarinda | John Paganis LIB; Gavin Bain ONP | no LNP, no ONP | extraction only |
| Footscray | Tim Chang LIB | no LNP | extraction only |
| Kalkallo | Eddie Dadisho LIB; Troy Steans ONP; Payal Tiwari GRN | no LNP, ONP, GRN | extraction only |
| Kororoit | Jack Chakoma LIB; Seva Melnikov ONP | no LNP, no ONP | extraction only |
| Melbourne | Rafael Camillo LIB; Matthew Collins ONP | no LNP, no ONP | extraction only |
| St Albans | Rob Dunstan LIB; John Cowell ONP | no LNP, no ONP | extraction only |
| Tarneit | Venkat Ram Upparlapalle LIB; Walter Villagonzalo ONP | no LNP, no ONP | extraction only |
| Shepparton | Shane Sali NAT; Lou Costa IND; Karen Hocking VS | no LNP/NAT, no IND, VS not matched | seat page, same list as A-Z |
| Hawthorn | Shima Ibuki IND (also in ours) | agrees | extraction + key-seats page |
| Ripon | Jo Armstrong NAT and Megan Read LIB as two candidates | one garbled row "READ, Jo Armstrong (N)Megan" | likely a parse bug on our side, extraction only |
| Preston | Peita Collard AJP | ours has Rachel Unicomb OTH; ABC puts Unicomb in Broadmeadows | possible mislabel on one side |
| Broadmeadows | Rachel Unicomb AJP | ours has Candace Feild OTH, no Unicomb | extraction only |
| Niddrie | Samantha Byrne LIB; Lana Nguyen GRN; Jason Taverna ONP; Brendan Laws VS; Salomae Haselgrove AJP | ours has Carroll, Byrne, Laws, Celata OTH; lacks Nguyen GRN, Taverna ONP | seat page |
| Northcote | Theophanous ALP, Gome GRN, Lynda Awad LIB, Kath Larkin VS | ours same four plus Jim Penman OTH_RIGHT | seat page; ours has one extra |
| Pascoe Vale | Cianflone, Panopoulos GRN, Shamsili VS, Andrewartha IND, Katherine Ashton Family First | ours same five, Andrewartha as OTH not IND | seat page; agrees except class |
| Mornington | Crewther LIB, Ashli Beards ONP, Kai Titcher GRN | lacks Titcher GRN | seat page |
| Nepean | Marsh LIB, Hercus ONP, Healy GRN, Seth Willcocks VS, Mike Brown FFP, Tamara Champion AJP | lacks VS, FFP, AJP | seat page |
| Oakleigh | Dimopoulos, Jung, Hsiang-Han Hsieh GRN, Brooke Carter ONP, Rowdy Bugter VS | lacks Carter ONP | seat page |
| One Nation overall | ONP listed in most of the 75 extracted seats (roughly 60+, counted by eye, not computed) | ONP in 30 of 88 seats | the biggest gap; extraction only |

Spelling variants only (same person): Fuery/Fruery (Benambra), Coombes/Coombs (Bayswater), Hsieh/Han-Hsieh (Oakleigh).
Disagreements of substance: none found on ALP/LNP incumbents in seats where both sides have a row. Seat-page and A-Z lists agreed on Shepparton and Pascoe Vale.
Net effect on the gate if ABC is right: ALP seats 74 to about 80 of 88 (+6 from extraction), LNP/NAT 67 to about 78 (+11), before VEC confirmation.

## Margins and 2022 results (88 seats)

ABC's electorates page and pendulum give a party and margin for all 88 seats (56 ALP, 29 Coalition incl. 9 Nationals-held, 3 Greens: Richmond 7.3 vs ALP,
Melbourne 10.2 vs ALP, Brunswick 13.5 vs ALP). Those margins are new-boundary notional margins (Shepparton 24.3 NAT; Hawthorn LIB 1.7; Kew LIB 4.0;
Pascoe Vale ALP 2.0 vs GRN; Northcote ALP 0.2 vs GRN; Mornington LIB 0.7 vs IND; Prahran LIB 1.3 vs GRN). The pendulum states no boundary basis, so "notional" is
my inference. Per-seat 2022 results shown on seat pages appear to be old-boundary (Nepean page shows 2022 margin 15.5 points but classification 6.4; Shepparton
2022 result 2.7 points against 24.3 notional), so do not mix them with the notional margins. Not compared line by line with our margins file; that is a follow-up.

## Retirements and by-elections (ABC key-seats page, unverified)

Retiring: Jackson Taylor (Bayswater ALP), Gary Maas (Narre Warren South ALP), Bill Tilley (Benambra LIB), Kim O'Keeffe (Shepparton NAT, announced July), Pakenham ALP member
(unnamed, "retiring", seat 0.4%). Independent Jacqui Hawkins not re-running in Benambra. Ali Cupper (IND) recontesting Mildura. Mulgrave and Werribee had by-elections
(Mulgrave 2023: further 5.5% swing; Werribee by-election 10%+ swing against Labor). Nepean: Anthony Marsh (LIB) elected at a May 2026 by-election (seat page). Theophanous
appointed parliamentary secretary Aug 2026. Premier is named as Ben Carroll on the search summary (Niddrie). Check these against our retirement flags; not done.

## Seat profile facts requested

- Hawthorn: LIB 1.7; Shima Ibuki (IND, "teal") challenging; John Pesutto LIB; Labor weak (Clive Crosby).
- Kew: LIB 4.0; Jess Wilson LIB, David Sun ALP, Jackie Carter GRN, Sophie Torney IND, VS and FFP also; matches ours (ours has Seeley as OTH_RIGHT).
- Richmond: GRN 7.3 vs ALP; Gabrielle de Vietri GRN, Sarah McKenzie ALP, David Meyer IND, Harrison Rindfleish ONP, Chris Dite VS. Ours lacks Meyer IND (has no IND row).
- Pascoe Vale: ALP 2.0 vs GRN, no retirement noted.
- Shepparton: NAT 24.3 notional; Kim O'Keeffe not recontesting; candidates above; 2022 independent runner-up Suzanna Sheed (not listed as 2026 candidate).
- Independents elsewhere: Mildura Ali Cupper; Mornington none listed (2022 Kate Lardner IND not listed); Williamstown Tony Briffa IND (ours has him).

## Could not load or confirm

- The tweet (HTTP 403); its date and wording are unknown.
- Raw ABC pages: only small-model summaries obtained, which fabricated at least one seat and unreliable row totals. Nothing here is verified against the page.
- A-Z extraction misses 13 seats; 7 of those (Cranbourne, Eildon, Eltham, Essendon, Narracan, Narre Warren North, Narre Warren South) were never checked.
- Nomination close date, VEC list, publication date of the candidate list (none shown by ABC).
- Whether margins are new-boundary notional (inferred, not stated) and whether ABC and our margins agree.
- Our file is dated 2026-09-28; ABC has likely added candidates since, so some gaps are just timing.
- Labor upper-house article not opened. Recommended next step: re-pull the A-Z page raw (curl via Bash, parse HTML) in a session that may run it, then diff programmatically.
