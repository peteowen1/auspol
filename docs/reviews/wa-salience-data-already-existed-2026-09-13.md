# The WA salience corpus already existed. It was just never connected.

2026-09-13, immediately after `docs/reviews/wa-independents-no-salience-2026-09-13.md`
recommended building one from scratch. That recommendation was wrong, and
this corrects it before anyone acts on it.

## The mistake

That doc's diagnosis was sound — wa2001 and wa2008 are the worst pairs in the
corrected corpus, and independents carry the loss (33% of WA independent
wins given near-zero probability, versus 0% for both majors). But it
concluded *"there is no candidate feature to try in the first place"* and
recommended a new fetch project. A `grep` for `"wa"` and `region == .wa.`
across the fetcher scripts returned nothing, and that was taken as proof.

The grep was wrong, not the absence. `scripts/fetch_salience_v6.R:142-157`
lists every WA election from 1996 to 2025 with verified anchors (Richard
Court, Geoff Gallop, Alan Carpenter, Colin Barnett twice, Mark McGowan, Roger
Cook), added 2026-08-27 specifically *"to scrape the remaining elections
`candidacies.csv` already has results for."* The pattern that would have
found it is `AU-WA`, not `"wa"` or `region == .wa.`.

`output/salience-v6.csv` (mtime 2026-09-10, well after the fetcher was
extended) already carries wa2005/2008/2013/2017/2021/2025 — 40 to 100
candidates per election with a non-zero search jump, max jumps 3.9 to 31.3.
Only wa2001 (10 Feb 2001) has none, and it never will: Google Trends' own
public data starts around 2004.

Meanwhile `fit_xgb_primary_v6.R` still excluded the entire WA region from
salience/surge features with a comment that was accurate for v1-v4 and
became stale the day the fetcher was extended:

> *"Salience/surge population is NOT available for WA (no seat-level
> salience corpus built there -- same gap already found for v1-v4)."*

This is the exact trap `CLAUDE.md` names: *"ask what the system already has
before accepting a limitation."* The data was fetched three weeks before it
was needed and nobody connected it, because the comment excluding it was
never revisited.

## The fix

`SAL_PAIRS <- Filter(function(p) p$region != "wa", PAIRS)` became
`Filter(function(p) !identical(p$election, "wa2001"), PAIRS)` — excluding
only the one pair with no data, not the whole region.

Verified `governed_population("wa2008", "wa2005", "wa")` directly before
touching the pipeline: 245 rows, correct seat names, Kalgoorlie present.
Kalgoorlie's own winner (Bowler) has `jump = 0` — he was a sitting member who
had already publicly quit his party months before the campaign window this
statistic measures against, so his search interest was a sustained,
elevated story rather than a last-8-weeks spike. Flagged **before** running
the harnesses, not used to explain away a bad result afterward.

No sharedetail rebuild needed: this changes `v6`'s feature set, not
`pred_share`, so the existing clean `pooled-sharedetail.csv`
(`docs/reviews/xgb-primary-circularity-2026-09-13.md`) stayed valid. `v6`
refit once; harnesses run once under default flags, per that doc's four-step
procedure.

## Measured result: small, real, net positive

`v6`'s own leave-one-pair-out RMSE: 3.8781 -> 3.8582.

Pooled seat log loss, all 23 pairs (do-no-harm guard, since this is a
general change to a shared model, not a targeted single-seat fix):

| | before | after | move |
|---|---|---|---|
| pooled (seat-weighted) | 0.2926 | **0.2915** | −0.0011 |
| unweighted mean over pairs | 0.3098 | 0.3087 | −0.0011 |
| pairs improved / worse / unchanged | — | — | 11 / 9 / 3 |

WA alone: 0.3563 -> 0.3538 (−0.0025).

| pair | before | after | move |
|---|---|---|---|
| wa2001 | 0.6819 | 0.6643 | **−0.0176** (best mover) |
| wa2017 | 0.3105 | 0.2948 | −0.0157 |
| sa2026 | 0.4597 | 0.4523 | −0.0074 |
| wa2008 | 0.6840 | 0.7000 | **+0.0160** (worst mover) |

wa2001 improving the most is notable given it has *no* salience data of its
own — the shared model shifted via the other WA pairs' now-real features,
not via anything specific to 2001. wa2008 — the actual target, containing
Kalgoorlie — got slightly worse, consistent with the caveat above: the one
seat this was aimed at has no real signal to give it.

## Verdict

Small but genuine improvement, no catastrophic regression anywhere, and it
corrects a stale exclusion rather than adding a new mechanism. Shipped.

## The lesson, stated plainly since it cost real time tonight

A `grep` returning nothing is evidence the search term was wrong at least as
often as it is evidence the thing doesn't exist. `"wa"` and `region == .wa.`
missed `geo = "AU-WA"` and `wa2001 = list(...)` in the exact file that would
have answered the question. Before concluding "no fetcher touches this
region," grep the actual value used in the code (a geo code, a region
abbreviation as it is spelled elsewhere), not a guess at the pattern.
