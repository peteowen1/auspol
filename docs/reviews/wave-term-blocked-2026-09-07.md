# The wave term is blocked, and the cause is the salience anchor

2026-09-07. Measured before pre-registering, per the rule that a criterion is
dry-run on cases whose answer is known before it is committed. **No arm was
run and none should be** until the block below is cleared.

## What the wave term was going to be

Every open salience question reduces to one fact: in 2022 six teal-shaped
candidates won at once, and nothing in the model can see that. The hazard is
calibrated (top 2% band predicts 0.173, wins 0.158), the surge size is right
(35.1 against an actual teal mean of 33.9), the ranking is right (the teals
sit 6th, 7th, 8th, 12th and 19th of 147 seats). What is missing is that the
model treats each as an independent 2.5% draw when they were one event.

The proposed feature: an election-level count of how many high-salience
non-major challengers a cycle carries, computable from the salience corpus
before polling day and therefore leakage-free.

## Why it cannot be built from the data as it stands

The count needs an ABSOLUTE salience bar, because the percentile is
within-election by construction — the top 5% is always 5% of the field, so a
wave and a quiet year look identical. Applying an absolute bar to the raw
`jump`:

| election | candidates above jump 0.10 | emergences that won |
|---|--:|--:|
| fed2016 | 50 | 1 |
| wa2008 | 26 | 3 |
| fed2019 | 9 | 2 |
| **fed2022** | **2** | **7** |
| sa2026, qld2024, nsw2023, fed2010, fed2013 | 0 | 0–2 |

fed2022, the wave, has the SECOND FEWEST candidates over the bar and the most
winners. The correlation between the count and the win rate is **negative**
(−0.10 to −0.33 depending on the bar). The measure is not ranking elections
by how salient their challengers were; it is ranking them by the scale of
their own Trends batch. Per-election maxima make that plain: wa2008 tops out
at 31.29, sa2026 at 0.05, qld2024 at 0.04.

## The root cause, from the cache

Each cached batch (`external/reference/trends/*.rds`, 3,655 of them) is a
5-element numeric array: the MEAN interest for four candidates plus the
anchor, **"Anthony Albanese"**. Two consequences:

1. **The anchor's own prominence is not constant.** Albanese was a
   little-known minister in 2008 and Prime Minister in 2026. A candidate
   scored against him in 2008 looks enormous and the same candidate in 2026
   looks tiny. The ratio is comparable WITHIN an election and meaningless
   ACROSS elections, which is exactly the axis a wave term needs.
2. **The weekly series were not kept, only the mean.** So the scale cannot be
   re-derived from what is on disk — no re-anchoring, no chaining through a
   third keyword, no recovery of the level. This is the cost of the lesson
   `CLAUDE.md` already records under "the same rule applies to anything
   SCRAPED": cache the series, derive the statistic. It was recorded on
   2026-08-26 after the same data cost 259 refetches, and it is landing
   again here on a different question.

## What would unblock it

In increasing order of cost:

1. **A stable anchor present in every batch.** Something whose search
   interest is roughly constant across 18 years — not a politician. If any
   existing batch shares a keyword with batches from another election, the
   two can be chained; nothing in the cache does today.
2. **A re-fetch with a common anchor and the WEEKLY SERIES STORED.** Google
   throttled this repo out entirely on 2026-08-26, so this is not free and
   may not be available on demand.
3. **A different wave proxy that does not use Trends at all** — the count of
   non-major candidates NOMINATED per seat, which is a commission fact rather
   than a search statistic, and which the candidate-count work already needs
   after Victorian nominations close on 9 November 2026.

Option 3 is the cheapest and the only one available before November. It
measures a different thing (how crowded the field is, not how prominent the
challengers are), so it is a weaker proxy, and it should be pre-registered as
such rather than as "the wave term".

## What this does not change

The salience signal itself is confirmed and shipping: it ranks emergences at
AUC 0.82–0.96 and the hazard built on it is calibrated. Nothing here weakens
that. What is blocked is only the cross-election comparison, and only because
the anchor moves.
