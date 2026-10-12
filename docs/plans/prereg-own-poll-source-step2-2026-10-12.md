# Pre-registration: the poll trend reads our own poll source, layered over AE's (step 2)

Written 2026-10-12, before anything is built. Pete chose this ("Go straight to own source", 2026-10-12) over a
one-row correction, after AE's file was found carrying RedBridge's 2-8 Oct 2026 Victorian poll with the Greens
and One Nation swapped (GRN 24 / ON 16; the AFR report and Wikipedia have ON 24 / GRN 16), and missing Resolve
6-10 Oct. Both have been in the live Victorian forecast since 12 Oct 07:00. Step 1:
`docs/reviews/own-poll-source-step1-2026-10-11.md`.

## The question

Does a poll file built from our Wikipedia scrape, with AE's file filling only what Wikipedia lacks, forecast at
least as well as AE's file alone, over all 22 scored elections? If so, the trend reads it.

## What gets built: `load_polls(region, source = "layered")`

Switch `AUSPOL_POLL_SOURCE`: `"ae"` (today, default until shipped) or `"layered"`. Same output shape as today
(`date`, `firm`, `tpp_published`, one column per party, the `parties` and `region` attributes), so nothing
downstream changes.

1. **Our rows.** `statewide_polls_wiki.csv` rows with `row_type == "poll"` in a voting-intention table
   (`table_type == "primary"`), state-level pages only for a state, the national tables only for federal.
   Dropped: exit polls, seat polls, sub-national breakdowns, hypothetical scenarios, and aggregates spanning more
   than 45 days of fieldwork (Newspoll quarterlies: the trend reads single polls).
2. **Date** = fieldwork midpoint (AE's `MidDate` is a midpoint).
3. **Parties**: each page's party columns mapped to our classes with `classify_party()`; a party the region's
   AE file does not carry goes to OTH. WA's Liberals and Nationals as `load_polls()` already treats them.
4. **Undecided**: where a poll reports an undecided share, it is divided out (primaries rescaled to sum to the
   decided total), which is AE's rule. Written into `docs/CONSTANTS.md`.
5. **Firm labels**: one alias table (`firm_alias.csv`, already in the scrape folder) maps our labels onto AE's
   (`RedBridge/Accent` to `Redbridge`, ...), so a firm keeps one house effect across the join.
6. **Layering, per poll**: an AE row and one of ours are the same poll when the firm matches after aliasing and
   the midpoints are within 4 days. A matched pair keeps OURS (it carries the source's own numbers). An AE row
   with no match is kept (AE has polls Wikipedia lacks: fed2007, fed2010, WA quarterlies, thin state pages). One
   of ours with no match is kept.
7. Every load prints: rows from ours, from AE, matched; and for matched pairs, how many differ by more than 2
   points on any major party (each such row listed for the live cycles).

## Criterion and rule, fixed now

- **Screen:** day-before level RMSE (ALP, LNP, GRN; 66 cells; `scripts/screen_level_share.R`-style, shipped blend
  on top), layered vs AE, SE by delete-one-election jackknife. Report; the screen cannot refuse a data fix on its
  own, but a worse point estimate by more than 1 SE goes to Pete before the deciding run.
- **Ship (deciding):** all 22 at 20,000 sims from stage 1 (the trend reaches base_pred and every feature built
  from it). Ships if pooled seat log loss is no worse than +1 SE (non-inferiority: the layered file is the
  source's own numbers, so ties go to it).
- **Guard:** no election's seat log loss worse by more than 0.02 (about 2 SE of a typical election). One that
  is goes to Pete with its matched-row diff before shipping.

## Dry runs (known answers; the loader is wrong if any fails)

- vic2026: the RedBridge 2-8 Oct row reads ON 24, GRN 16; Resolve 6-10 Oct is present.
- fed2007 and wa2001 (no Wikipedia tables): byte-identical to AE's rows.
- A matched pair count above 50% of AE's final-30-day polls over the 22 elections (step 1 found 119 of 233
  the same poll).

## Known limits

- Wikipedia pages are current revisions, not those standing before each election; a later correction to an old
  poll could leak. Poll numbers are rarely revised after the fact, so this is accepted and stated.
- Live freshness: the daily job refetches the live Victorian and NSW pages already (leader refresh); the layered
  trend will read the same fresh parse.

## Amendments

(any change is added below this line with the original text left as is)

### Amendment 1 (2026-10-12, before the screen): disagreeing copies of one poll

Pete chose a tie-break over "ours always wins" after the first dry run showed both sources carry errors: AE has
swapped rows (vic2026 RedBridge, qld2014 ReachTEL, fed2011-12 Essential) and our parser has some (the 2026
federal tables split the Coalition into Liberal and National sub-columns). Rule: a matched pair that differs by
more than 2 points on a major party keeps the row whose primaries better fit the poll's own published two-party
figure (implied ALP two-party = ALP + 0.83 GRN + 0.35 ONP + 0.45 rest), by at least 1 point; otherwise AE's
row. Also: duplicate rows of one poll on a page are counted once, and a small second "L/NP" cell is added as the
Nationals only when it brings the row's primaries closer to 100.

## RESULT, screen (2026-10-12)

`scripts/screen_poll_source.R`, both sources in separate processes, blend refitted on each. Day-before level
RMSE, 66 cells, 22 elections, lower is better: AE 2.319, layered **2.071** (-0.248, SE 0.360); trend alone -0.289
(SE 0.307). Not worse, so it goes to the deciding run. Largest moves: wa2005 GRN 1.26 -> 6.49 (actual 7.57; AE's
file has the WA Greens near 1), wa2005 LNP 47.66 -> 44.24 (39.33), sa2026 ALP 38.38 -> 36.90 (37.62). vic2022 moves
the wrong way by 0.3-0.5 on all three classes. Two-party tie-break: kept ours on 6 disagreeing pairs (every AE
swap above), AE's on 23.
