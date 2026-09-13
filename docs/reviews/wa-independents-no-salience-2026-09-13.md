# wa2001 and wa2008 are the worst pairs in the corrected corpus, and it's four seats

2026-09-13, continuing straight from the circularity fix
(`docs/reviews/xgb-primary-circularity-2026-09-13.md`). Once the true, clean
pooled numbers were in, wa2001 (0.6819) and wa2008 (0.6840) were the two
worst pairs in the 23-pair corpus — well past sa2026 (0.4597), which had
been the standout all night.

## The diagnosis, walked on the actual seats

Seat log loss, lower is better, per WA pair:

| pair | seats | mean log loss | catastrophic seats (prob < 1%) | share of that pair's loss |
|---|---|---|---|---|
| wa2008 | 38 | 0.684 | 1 | 53% |
| wa2001 | 57 | 0.682 | 3 | 41% |
| wa2013 | 55 | 0.370 | 0 | 0% |
| wa2017 | 54 | 0.311 | 0 | 0% |
| wa2005 | 46 | 0.224 | 0 | 0% |
| wa2025 | 53 | 0.198 | 0 | 0% |
| wa2021 | 58 | 0.101 | 0 | 0% |

Five of seven WA pairs score 0.10–0.37, in line with the rest of the corpus.
The two bad pairs are bad because of **four specific seats**, not a general
WA weakness:

| pair | seat | actual winner | probability given | log-loss contribution |
|---|---|---|---|---|
| wa2008 | Kalgoorlie | IND | **0.0000** | 13.82 |
| wa2001 | Alfred Cove | IND | 0.0031 | 5.79 |
| wa2001 | Kimberley | ALP | 0.0038 | 5.57 |
| wa2001 | Pilbara | IND | 0.0090 | 4.72 |

Kalgoorlie alone is more than half of wa2008's entire pair total.

Independents are wildly over-represented among these misses. Across all seven
WA pairs, independents win 9 of 361 seat-elections; **3 of those 9 (33%) are
catastrophic misses**, against 0% for both ALP and LNP.

## Why this happens, and why it isn't a modelling bug

`fit_xgb_primary_v6.R`'s own comment already states the gap: *"Salience/surge
population is NOT available for WA (no seat-level salience corpus built
there -- same gap already found for v1-v4)."* An independent candidate
anywhere else in the corpus gets a jump/governed/permit/surge_h signal from
Google Trends search interest; in WA that signal simply does not exist, so
the model has nothing to distinguish a genuine emergent independent from
statistical noise. Kimberley's ALP loss is likely the same mechanism from
the other side — a seat-swing the salience-adjacent machinery elsewhere would
have caught.

This is consistent with the two oldest WA pairs (2001, 2008) being the ones
affected: whatever search-interest data exists is denser and more reliable
for recent elections, and 2001 in particular predates Google Trends entirely.

## What this is not

Not a general "WA is badly modelled" finding — the other five pairs are fine.
Not something a feature-engineering tweak fixes — there is no signal to
engineer a feature from. Not the same failure mode as sa2026's ONP ranking
(which had a genuine feature, `x`, that simply didn't transfer out of
sample) — here there is no candidate feature to try in the first place.

## Recommended next step

Build a WA salience corpus, the same shape as the fetchers that already exist
for federal/NSW/QLD/SA/VIC (`scripts/fetch_seat_salience*.R`), covering WA
state candidates back to 2001 where Google Trends coverage allows. This is
data-acquisition work, not a same-session model change, and is the concrete,
scoped next step rather than a vague "WA is bad" note.

## Also resolved tonight, same session

`all_election_pairs()` in `R/reentry_prior.R` now includes `sa2022`
(commit 7826543). Measured cleanly this time — with the training-data
circularity from `docs/reviews/xgb-primary-circularity-2026-09-13.md` fixed,
`v6` could be held fixed and the six harnesses run once under default flags.
Result: **every one of the 23 pairs scored bit-for-bit identical** to the
pre-change baseline. Verified the change actually loaded before trusting a
result that clean-looking. The null makes sense: `reentry_fit()` needs >= 40
rows to fit a class's own coefficients (>= 20 for even a flat ratio), and
sa2022 contributes at most 47 seats across six classes with no One Nation
candidacies at all — not enough to move any class past either threshold.
Kept anyway since it costs nothing and fixes a "23 pairs... 22 known pairs"
inconsistency `pool_sharedetail.R` was printing.

fed2016 (0.3428) was the item-3 candidate from earlier in the night (the SD
arm's largest regression) but is no longer notable in the corrected numbers —
it is simply the worst of an otherwise unremarkable federal set (0.19-0.34),
not an outlier. Deprioritised in favour of this finding.
