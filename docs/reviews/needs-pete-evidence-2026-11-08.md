# NEEDS PETE evidence, moved verbatim from NEXT-STEPS.md (2026-11-08 hub slimming)

Immutable. Each block is the queue entry as it stood on 8 Nov; the live parts are named in the stub left in NEXT-STEPS.md.

## Contested-seat research and value-odds page (28 Oct)

- 28 Oct: value-odds page https://claude.ai/artifact/GdrpxSB7zkY1xEvJvU3TKx (readiness, seat click-through, our
  probabilities against Sportsbet/TAB/Betfair). Built from scratchpad scripts, not the repo: it does not refresh.
  Contested-seat research, all committed: `reviews/contested-seats-vic2026-2026-10-28.md` (hub),
  `new-party-fill-proportional-vs-uniform-2026-10-28.md` (proportional One Nation fill supported, 4 elections),
  `contested-seats-light-checks-2026-10-28.md` (agent's sign error corrected at the top; other-right lead pooled over
  20 elections is -0.040, SE 0.015: small), `live-walk-contested-seats-2026-10-28.md` (xgb cut to the eastern Liberals
  0.1-1.6, not 3). Branch checks `ind-overcall-1025` and `mp-slope-shrink-1025`: both PASS `check_like_ci.R` 28 Oct.
  Still open from it: One Nation spread pooling (needs code: spread fixed to SA 2026 by the `sa_ratio` quantile map in `fit_seats_full.R`);
  Hastings/Cranbourne recheck after nominations (9 Nov); re-entry inflated bases (other classes over-called -2.9,
  SE 0.84, where a party re-entered; Narracan Greens is the live case).

## Estimated-flow Greens bias (narrowed 4 Nov)

- NARROWED 4 Nov, FLOWS: `output/flows-estimated.csv` putting Greens -> Labor 3-7 points above the AEC's official federal
  flow (fed2019 86.16 v 82.21, fed2022 89.07 v 85.66, fed2025 95.06 v 88.19) is the estimator's KNOWN bias: it failed
  its own bar on 13 Oct (Greens 3-16 points above the answer key; `reviews/flow-estimation-validation-2026-10-13.md`).
  Federal rows reach nothing: federal flows come from the AEC's official table, and only `output/flows-state-blend.csv`
  (via `state_blend_flows()`, the QLD and SA backtest harnesses) reads the estimates, for QLD 2001-2017, SA 2002-2022,
  NSW 2003/2007, Vic 2002 and WA 2001, blended at w 0.5-0.79 with earlier published flows (sa2022 Greens 81.3).
  OPEN, small: whether the estimator's Greens bias also shifts those state blends; a backtest-only question.

## WA 2017 seat layer and fed2019 walks (30 Oct, traced 4 Nov)

- OPEN from the 30 Oct walks (https://claude.ai/artifact/USv8sffhF1zbYagBGwjdQ3, `reviews/walks-wa2017-fed2019-2026-10-30.md`):
  WA seat layer ~5 pts above the statewide Labor level (36.4 -> 41.2) yet 5-15 short in the swing seats. PARTLY TRACED
  4 Nov (wa2017 seat means over 59 seats, actual ALP 41.9): level-pred 36.4 -> base_pred 38.9 (+2.5) -> xgb_pred_seat
  41.7 (+2.8; partly `forecasts.csv` rescaling five classes to 100 with no One Nation rows, sums 95.1 -> 100.1) ->
  published 41.3, One Nation's seat mean 4.2 vs its 7.7 level (actual 5.1). So the seat layer recovers most of a 5.8-point
  statewide miss ON AVERAGE. By previous Labor share there is no band bias (prev <30: our swing +13.0 v actual +14.0,
  n 29; 30-40: +6.6 v +8.4, n 11; >=40: +9.2 v +8.5, n 19); the misses are seat-specific: Southern River +8.3 v +20.7,
  Geraldton +4.1 v +16.6, Bunbury +7.1 v +15.4, Wanneroo +5.5 v +14.7, Kimberley +8.9 v +18.1. Next: what those five share;
  fed2019 shared miss (38% of margin error): is the correlated statewide draw wide enough? (4 Nov: needs each harness to
  write its statewide draw quantiles per election; then coverage of the 35 actual levels is one table. `output/fp-coverage.csv`
  is from 19 Aug and predates the shipped `AUSPOL_LEVEL_SD`.) Idea only: a per-person
  trend for Cupper (under-called every time). Closed Mildura checks (tree cut, swing floor refused, One Nation fill
  proportional; recheck the fill after vic2026 counts) are in DECISIONS 30 Oct and `backlog/journal-2026-10-30-to-31.md`.
