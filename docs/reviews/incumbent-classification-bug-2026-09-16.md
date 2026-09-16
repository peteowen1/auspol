# Fixed a real bug in is_incumbent_party; it does not explain the big misses

2026-09-16, chasing item 1 from the overnight NSW departed-member queue
(`docs/NEXT-STEPS.md`): why did the primary model miss the eventual winner by
30-50 points in four safe nsw2019 seats whose member had left (Barwon, Orange,
Murray, Wagga Wagga)? Dumped `fit_xgb_primary_v6.R`'s own primary-share point
estimate (not just the simulator's win probability) for these seats and found
the model's mean prediction itself was 30-40 points off, not just its width --
so no amount of widening `seat_sd` (the item-1/item-3 framing) could have
fixed these four. That ruled out a width fix for this group and sent the
investigation into the primary model's feature matrix instead.

## The bug, found and fixed

`fit_xgb_primary_v6.R:112` mapped the seat file's `incumbent` column through a
hand-rolled `to_class()` that only translated the three Coalition spellings
(LIB/NAT/LNP -> LNP). Every other party's incumbent stayed as the commission's
raw code, which never equals one of our classified party labels (ALP, LNP,
GRN, ONP, OTH_RIGHT, OTH, IND) -- so `is_incumbent_party` was **silently FALSE
on every seat held by a minor party**, no matter who actually held it.
Audited across all 6 regions and every available year: 8 (region, year)
combos affected, naming 9 seat-elections --

| seat | pair(s) | code | our class |
|---|---|---|---|
| Kennedy | fed2019, fed2022, fed2025 | KAP | OTH_RIGHT |
| Mayo | fed2019, fed2022, fed2025 | CA | IND |
| Hill, Hinchinbrook, Mirani, Traeger | qld2024 | KAP | OTH_RIGHT |
| Orange | nsw2019 | SFF | OTH_RIGHT |

Fix: `INCUMBENT_CODE_CLASS`, a named lookup covering all four codes.
SFF -> OTH_RIGHT reuses `classify_party()`'s own code rule (`R/parties.R:44`).
KAP is unambiguous everywhere it appears, so hardcoded directly. CA is
genuinely ambiguous in general (Centre Alliance federally since 2018 vs.
"Carers Alliance", fed2010, which also codes to "CA" in
`candidacies.csv$party_ab`) -- but an *incumbent* is by definition a party
that already won a seat, and Carers Alliance never did, so "CA" as an
incumbent code can only mean Centre Alliance. That reasoning is specific to
this field; it is not safe to add to `classify_party()` itself, which also
classifies losing candidates.

## What it moved, targeted first per CLAUDE.md

Named the 9 seat-elections before running anything, isolated the fix by
diffing OOF predictions with the code change stashed out vs. in (same seed,
same CV folds):

| | mean abs error, 9 targets | pooled OOF RMSE, all pairs |
|---|--:|--:|
| before | 8.398 | 3.8217 |
| after | 8.433 | **3.8078** |

**Pooled RMSE improved (-0.4%), the 9 named targets did not (+0.4%, noise).**
Orange -- the seat that started this -- moved from predicting OTH_RIGHT at
6.4% to 7.8%, against an actual 56.2%. `is_incumbent_party_i` ranks 15th of
20 features by gain even after the fix (0.00085), so the model was never
going to lean on it hard enough to close a 40-50 point miss.

## What this establishes and what it does not

**Established:** the bug was real (a genuine label mismatch, not a modelling
choice), the fix is correct, and it is a small uniform improvement with no
measured downside on any of the 9 named seats or the pooled corpus. Kept.

**Not established, and this is the actual finding:** why these seats miss by
30-50 points. It is not primarily an incumbency-labelling problem. These are
seats where a minor party or independent holds an enormous, idiosyncratic
personal vote share that nothing in the current feature set anchors to --
`is_incumbent_party` is a weak lever generically in this model, and fixing its
correctness for 9 rows out of thousands was never going to move gain much.
The open question is what WOULD: possibly the incumbent's own previous primary
share as a continuous feature rather than a binary flag (own_prev_pcv exists
in the feature list already -- worth checking whether it's populated and used
for these rows specifically), possibly these seats need a materially
different treatment altogether.

## Where this leaves items 1 and 3

Item 1 ("widen whoever could plausibly win") is dead for the nsw2019 four --
confirmed a location problem, not a width problem, for reasons unrelated to
the incumbent bug. Item 3 (per-seat `seat_sd`, C++ change) is unaffected by
tonight's work either way.

Kept: `scripts/fit_xgb_primary_v6.R`'s `INCUMBENT_CODE_CLASS` fix, since it is
a correctness fix with a measured small net-positive effect and no measured
harm. `output/xgb-primary-v6-oof-predictions.csv` regenerated with it; every
harness reading `AUSPOL_XGB_PRIMARY_LIVE=1` picks it up on its next run.
