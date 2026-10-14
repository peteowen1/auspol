# Leaders file backfill, 2026-10-13

Pete's decision: older elections run the full published model, so the leaders input has to reach back to 2001.
Proposed rows: `deciding-runs/leaders-backfill-proposed-2026-10-13.csv` (45 rows, 21 elections). Nothing under
`R/`, `scripts/`, `tests/`, `.github/` and not `external/reference/leaders/leaders.csv` was touched.

## What the file is and how the model uses it

`external/reference/leaders/leaders.csv` is built by `scripts/fetch_leaders.R` from each Wikipedia election
article's infobox: one row per (election, infobox slot), 33 columns, every infobox field kept raw. The columns that
matter are `election`, `slot`, `leader_clean`, `party_clean`, `leaders_seat_clean` and `head_of_govt` (the infobox
`before_election`, the sitting premier or PM). `R/leader_seat.R::leader_seats()` turns it into
`pair, seat, party (class), leader, role`:

- party class from `party_clean` text: Labor = ALP, Greens = GRN, Katter/Palmer = OTH_RIGHT, One Nation = ONP,
  Liberal/Coalition (not "Forests") = LNP; anything else (a Nationals-only label, SA-BEST) becomes NA and is dropped;
- role: `gov` if `leader_clean == head_of_govt`, else `opp` for ALP/LNP, `minor` for the rest;
- rows kept only with a non-empty seat that is not Senate/Legislative Council/"Did not stand"; the text after "(" is
  stripped from the seat, so "Ashgrove (contesting; not a member)" reads as Ashgrove.

`leader_seat_bonus()` fits a time-forward, partially pooled bonus per role (gov / opp / minor) from the as-at seat
misses at earlier elections' leader seats; `leader_seat_table()` ships it for the target election. It is also a
feature in the xgb primary layer. A pair with no rows gets no bonus and no training signal.

## Current coverage (rows with a named leader, `No leader`/`N/A` excluded)

Fed 2007-2025 (2 to 6 per election), NSW 2019/2023/2027 (2-3), Qld 2020/2024, SA 2022/2026, Vic 2014/2018/2022/2026,
WA 2001-2025 (3 each). 25 elections, 89 named leaders. Everything else in the scope is missing.

## Missing and proposed (count of proposed rows)

| jurisdiction | elections missing | proposed rows |
|---|---|---|
| Fed | 2001, 2004 | 2 each |
| NSW | 2003, 2007, 2011, 2015 | 2 each |
| Vic | 2002, 2006, 2010 | 2 each |
| Qld | 2001, 2004, 2006, 2009, 2012, 2015 / 2017 | 2 each / 4 |
| SA | 2002, 2006, 2010, 2014 / 2018 | 2 each / 3 |

Total 45. Fed 2007-2025, NSW 2019+, Qld 2020+, SA 2022+, Vic 2014+ and all WA already exist. Nothing is missing for
WA. Every election 2001-2026 in the six jurisdictions now has a gov and an opp row, either existing or proposed.

## Sources

Each row's `source_url` is a permalink (`oldid`) to the Wikipedia election article revision last saved before
polling day (found by the revisions API with `rvstart` the day before). 15 of the 21 have one; `source_date` is the
revision date. Pre-2012 articles carry leaders in older infobox formats with no seat, so those seats are from my
memory of the member's electorate (flagged in `note`). Six elections have no revision before polling day
(fed2001, nsw2003, qld2001, qld2004, sa2002, vic2002): the article was created later. Their `source_url` is the
earliest revision (2004-2007, after the election) and `source_date` says so; the leader names there are plain
statements of who led, not outcome-dependent, but the seats are from memory.

## Uncertain, for Pete to check

- **qld2001 opposition leader**: Mike Horan (Nationals, Toowoomba South), from memory only; the earliest revision
  does not name him. Verify before use.
- **Nationals-led oppositions** (qld2001, 2004, 2006): party written as "Liberal/National coalition" so
  `leader_seats()` maps it to LNP; the real party is Nationals. The Liberal leader beside them (Quinn, Flegg) is left
  out, same rule as the existing file.
- **Leaders without a seat when the election was called**: Newman (qld2012, Ashgrove), Foley (nsw2015, Auburn; was an
  MLC), Xenophon (sa2018, Hartley; SA-BEST maps to no class, so the model ignores that row until the class map gains
  it). The existing file's convention keeps the contested seat.
- **Mid-term leader changes**: Kerin replaced Olsen Oct 2001 (sa2002 uses Kerin); Doyle replaced Napthine Mar 2002
  (vic2002 uses Doyle, confirmed by the article text; my first recollection, Napthine, was wrong); Evans for sa2006,
  Redmond for sa2010 (replaced Hamilton-Smith 2009). Leadership as at polling day, not as at the infobox date.
- **Minor-party leaders not added**: Katter's Australian Party in qld2012 and qld2015 (the pre-election infobox lists
  only two leaders; who led the party is unconfirmed), One Nation qld2001, and Greens leaders (all Legislative
  Council or Senate, which the model drops anyway). Qld 2017 includes Katter (Mount Isa) and Dickson (Buderim).
- **By-elections**: not used. A leader who entered by by-election (none found in this range) would need a seat note.
- Nationals leaders beside a Liberal leader (Anderson, Ryan) left out per `leader_seats()` doc.
- Seat spellings are not yet checked against each pair's seat list via `normalise_seat()`; run that join when the
  rows are merged.

## Merge

Append the CSV (drop the three extra columns `source_url`, `source_date`, `note`, or keep them: `fread` tolerates
extras) to `leaders.csv`. `fetch_leaders.R` regenerates the file from raw wikitext and would overwrite hand rows, so
add these as a second file or teach the fetcher a supplement path. Nothing has been run against the model.
