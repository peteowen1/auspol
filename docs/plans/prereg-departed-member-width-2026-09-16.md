# Pre-registration: widen the majors only where the previous winner has gone

Written 2026-09-16 overnight, **before the arm is fitted or run**. Follows
`docs/reviews/nsw-departed-member-2026-09-15.md`.

## The claim being tested

Across both NSW pairs, a seat held by 5+ points whose previous general-election
winner is **not on the ballot** is called wrong **26.2%** of the time (11 of 42)
against **1.8%** (2 of 113) when the member stands again.

The review established the mechanism is **variance, not level**: the held
party's own primary error spreads from sd 5.17 to **8.81**, while the level
shift is only 2.77 points. `simulate_seat_contests()` gives every seat in the
chamber the same `seat_sd`, so these seats are simulated with an ordinary
seat's spread.

## WHAT I ALREADY KNOW, stated before the criterion

- **The federal ratio is 1.06x** and the other four states 1.22x, against NSW's
  1.71x. NSW is the only optional-preferential jurisdiction in the corpus, so
  "NSW" and "OPV" cannot be separated here. This arm does **not** claim to tell
  them apart.
- **A per-cell sd model already exists and is OFF**: `AUSPOL_XGB_PRIMARY_SD=0`,
  `R/xgb_primary_sd_override.R`, fitted by `scripts/fit_xgb_primary_sd.R`. Its
  features already include `retirement_i` and `region_nsw`.
- **Turning it on for the majors has already been measured and REFUSED.**
  `published_flags.R` records that setting all 1,050 fed2022 cells cost the 144
  non-teal seats 0.267 → 0.278 of log loss, because the sd model has nothing to
  offer the majors in ordinary seats (Gaussian log-score gain ALP 0.03, LNP 0.09
  against IND 1.50). That is why `AUSPOL_XGB_PRIMARY_SD_CLASSES` lists only
  IND, OTH, OTH_RIGHT, ONP.
- **`retirement_i` is 0.0% populated on eleven of twenty-three pairs**, so the
  sd model has been fitted with it as a partial jurisdiction label. The derived
  replacement covers all 21 pairs at 93% agreement.
- Filling `retirement_i` in as a LEVEL feature was already measured and refused:
  **-0.09 points, t = -0.16** on the eleven uncovered pairs.

## The change

Two parts, and the second is the point:

1. `scripts/build_retirement_derived.py` already writes
   `output/retirement-derived.csv`. Join it into
   `scripts/fit_xgb_primary_sd.R` as `departed_i`, **replacing** `retirement_i`
   in `feat_ctx` rather than sitting beside it, so the partially-populated
   column stops acting as a jurisdiction label.
2. A new switch **`AUSPOL_SD_DEPARTED`**. When `1`, the per-cell sd override is
   applied to **ALP and LNP cells only in seats where `departed_i == 1`**, and
   nowhere else. Ordinary major cells keep the tuned `seat_sd` machinery
   untouched, which is precisely where the earlier refusal found the harm.

**No change to `src/seat_sim_core.cpp`.** This rides the existing per-cell sd
path and needs no per-seat `seat_sd` vector.

## The criterion

**This is a TARGETED change, so the target is primary**, per `CLAUDE.md`'s
scoping rule — an election-wide metric would dilute 42 seats across 181 and
refuse a fix that works.

**Primary: mean seat log loss over the 42 named target seats** — both NSW pairs,
`departed_i == 1`, margin 5 or more. The eleven we currently call wrong are
listed in the review and are named in advance; the other 31 are the do-no-harm
half of the same set.

**Adopt if mean seat log loss over those 42 seats improves by at least 0.05**,
which is roughly a third of the gap between the two groups (0.924 against 0.059
on the 12-point-plus band) and comfortably above the metric's own noise on 42
seats.

### The bar above is NOT sufficient on its own, and the dry run is why

Dry-run before committing, as the rule requires. The target set resolves to
exactly **42 seats, 11 of them currently wrong, split 19 / 23 across nsw2019 and
nsw2023** — the review's numbers reproduce. Baseline mean seat log loss
**0.9293**, and here is the problem:

| subset | n | mean | total |
|---|--:|--:|--:|
| currently WRONG | 11 | 3.3365 | 36.70 |
| currently RIGHT | 31 | 0.0752 | 2.33 |

**The 11 failures carry 36.70 of the 39.03 total.** Any widening whatsoever
improves a seat called at 0.03 that lost, so a 0.05 move on this mean is
arithmetically near-certain and measures nothing. That is exactly the error made
on `AUSPOL_FLOW_FRAG` the previous evening — a criterion that asked only whether
the number moved — and repeating it one day later, having written the lesson
down, would be indefensible.

**So the arm must ALSO beat a dumb-hedge control**, added here before anything
is run:

> **Control: widen the same 42 seats by a flat multiplier**, tuned so its
> reduction on the 11 wrong seats matches the arm's, using no sd model and no
> features. Report both.
>
> **The arm is adopted only if it beats the flat control on the 31 seats we
> currently call RIGHT.** Both approaches buy the same thing on the failures;
> only a real model knows *which* departed seats deserve the width. If the sd
> model cannot separate them, the honest finding is "widen departed seats" —
> a constant, not a model — and it should be shipped as the constant.

This control is the whole test. The headline number is a formality.

**Guard 1, must not worsen by more than 0.005: nsw2019 + nsw2023 election-wide.**
**Guard 2, must not worsen by more than 0.005: pooled across all 22 pairs.**

## Refusal: what makes an apparent win unacceptable

- **If the 31 target seats we currently call RIGHT get worse by more than 0.02
  between them.** Widening always helps a seat you called wrong and always hurts
  one you called right; a "win" that is purely the former is a hedge, not a fix,
  and the honest test is the whole named set, not its failing half.
- **If either guard breaches.** The flow of this repo's past mistakes is a
  targeted fix that quietly degrades everything else.
- **If the gain needs the majors widened outside departed seats.** That is the
  already-refused arm wearing a new name.
- **If the improvement is confined to nsw2023.** nsw2019 was the out-of-sample
  confirmation and must carry its share, or the effect is one election.
- **A directional side effect:** if any seat's win probability moves by more
  than 0.25 in a seat that is NOT in the target set, the override is leaking and
  the arm is refused regardless of the metric.

## What the criterion cannot see

- **Whether the mechanism is OPV or personal vote.** Both predict this widening
  in NSW. A win here does not adjudicate between them, and the doc must not
  claim it does.
- **Victoria 2026.** vic2026 nominations close 9 Nov 2026, so `departed_i` is
  not computable for the live forecast until then. Whatever is adopted here
  cannot reach the published Victorian forecast this year, and the flag must say
  so.
- **The other five jurisdictions**, whose ratio is 1.06x to 1.22x. This arm
  deliberately touches NSW-shaped cases only through the data, not through a
  hardcoded region test — but with 47 NSW departures against 40 federal, the fit
  will be dominated by NSW regardless.

## Prediction, written before running

**The primary improves by 0.05 to 0.25** on the 42 seats, driven almost entirely
by the eleven currently-wrong ones, and **the 31 correct seats get worse by
roughly 0.01 to 0.02 between them** — the hedge cost, which I expect to be real
but smaller than the gain.

**Both guards hold**, because the override reaches only 42 of 2,050 seat-
elections in the pooled corpus.

**The most likely failure is the FIRST refusal condition**: that the whole
apparent gain is the eleven wrong seats being hedged toward 0.5 while the 31
right ones pay for it. If the net over all 42 is positive but the 31 lose more
than 0.02, this is a confidence tax rather than a correction, and it should be
refused even though the headline passes.
