# DemosAU federal MRP acquisition, 2026-10-13: BLOCKED, nothing fetched

Status: not done. demosau.com answered HTTP 403 ("403 - Forbidden", nginx) to every
request from this machine: the 11 Oct article, the Aug-Sep 2026 report PDF and the
home page, using both a descriptive user agent and the browser-style one that
`scripts/fetch_demosau_crosstabs.R` used successfully earlier. Four requests, one
second apart, then stopped. Not worked around.

On disk: nothing new. Existing crosstabs are at `external/reference/polls/demosau/`
(the brief said `external/reference/demosau/`, which does not exist).
`external/reference/polls/demosau/raw/mrp/` is created and empty.

## Needs a real browser (Pete or Chrome extension)
1. Save the report PDF as `external/reference/polls/demosau/raw/mrp/mrp-2026-08-09.pdf`
   (URL in the brief).
2. Open the article, find the electorate search, and with devtools Network record any
   JSON endpoint it calls; save the raw response. Not inspected: the page never loaded.
3. List earlier MRP posts (May-July 2026 and any 2025) from demosau.com/news and save them.

## Not done, and why
No `mrp-seats.csv`, `mrp-national.csv`, parse checks, 150-division or seat-total checks,
and no method notes: all need the PDF. Nothing here is from the report; I did not
fill in method details from memory. `scripts/fetch_demosau_mrp.R` is a fetch-only
script (skips files on disk, checks PDF magic bytes, stops on 403). Write the parser
after the PDF exists.

## Resolved the same day (orchestrator): the data is in the Flourish embeds

demosau.com blocks scripts (403), but its charts are Flourish embeds hosted on flo.uri.sh, which serve the full data
in the page. Opened the article in Pete's browser to find them (visualisations 30532149 primary vote, 30532135 two-
candidate vote with notional leader and safety, 30532169 likelihood of winning, 30508517 One Nation across the four MRP
releases since Oct-Nov 2025), then fetched each embed raw with curl into `external/reference/polls/demosau/raw/mrp/`.
`scripts/parse_demosau_mrp_flourish.py` extracts each table; `scripts/build_demosau_mrp_seats.py` joins them into
`external/reference/polls/demosau/mrp-seats.csv` (150 divisions; every primary row sums to 100). Check against the
report headline: notional leaders Labor 84, Coalition 34, One Nation 24, Other 8 (exact match). Summed win
probabilities give a different picture: Labor 78.7, Coalition 34.2, One Nation 28.5, Others 7.5, Greens 1.1 expected
seats. The report PDF itself was not fetched (blocked); earlier releases' seat tables need their own embed ids.
