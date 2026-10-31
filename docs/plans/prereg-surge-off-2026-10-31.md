# Prereg: switch the surge mixture off (AUSPOL_SALIENCE_SURGE_V2=0) now that independents have their own spread

Written 2026-10-31, before any run.

## Why

Pete, 31 Oct, on the Wentworth fed2022 trace: the forecast is two-humped. With surge-v2 on, 32.7% of Wentworth's
draws add N(36.3, 13.4) points to Spender (average primaries IND 65.8 / Lib 19.5 / ALP 7.0 / GRN 4.5) and the rest sit
at the point forecast (29.4 / 40.1 / 14.5 / 9.2); she got 35.8. He had taken the 17 Oct change, a wider and skewed
spread in personal-vote seats (`AUSPOL_COMPOSITION_SD=1` + `AUSPOL_ERROR_DIST=1`), to be the replacement for this, but
the surge was never switched off and nothing has tested whether it still earns its place on top of that spread.
It is also the root of the election-night Wentworth defect (`docs/reviews/night-replay-real-feed-2026-10-31.md`).

## Arm

`AUSPOL_SALIENCE_SURGE_V2=0`, everything else at the published configuration (`scripts/published_flags.R`).
WA has no surge-v2 hazard, so every WA pair must be byte-identical (a built-in check that the arm does only this).

## Prediction (before running)

Worse in seats an outsider took from far behind that the spread alone cannot reach (the September cases the surge
was built for: federal seats called at 99.9% that a non-major won). Better in seats with a high hazard where the
independent fell short or won narrowly (the second hump puts mass where nothing happened). Net sign unknown.

## Measurement and decision rule

1. Screen: `scripts/quick_arm.R "AUSPOL_SALIENCE_SURGE_V2=0"` on AEF-7, 1,000 sims. A reason to stop only if WORSE
   by more than 2 SE pooled. The surge acts in the tails, which a 1k screen floors at 0.5/N, so a pass does not clear it.
2. Deciding run: all 22 at 20,000 sims (`scripts/deciding_run.ps1 -Arm "AUSPOL_SALIENCE_SURGE_V2=0" -Label surge-off`).
3. Ship surge-off if, on the deciding run:
   - pooled seat-winner log loss over all seats (lower is better, SE clustered on election) is better or within 1 SE;
   - log loss on the ACTED seats (seats whose win probabilities move by more than 0.001) is better or within 1 SE;
   - no election is worse by more than 2 SE. A refusal by this clause alone goes to Pete with the split.
   Removal is a simplification and removes a known night-model defect, so "no worse" is the bar, not "better".
4. Whatever the result, list the ten seats whose log loss moves most each way, and Wentworth / Warringah /
   Kooyong / Curtin / Mackellar fed2022 win probabilities with and without, before any decision.

What would make an apparent pass unacceptable: any WA pair moving; seats that did fall to a far-back outsider
(called above 0.99 for a major and lost) going to a floor probability they did not have before. Those get listed,
and Pete decides.
