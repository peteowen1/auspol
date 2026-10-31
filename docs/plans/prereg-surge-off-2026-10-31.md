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

## RESULT (2026-10-31, deciding run `deciding-runs/20261031-1346-surge-off`, code 8702ae31, 20k sims, 35 elections)

Amendment, visible: step 1 (the AEF-7 screen) was skipped after Pete said he wanted the surge off; it could only
have stopped the run early, not changed the rule. "All 22" in step 2 is now 35 elections (2,931 seats).

- Pooled seat-winner log loss +0.0002 (SE 0.0028): within 1 SE. PASS.
- Acted seats (1,587): +0.0003 (SE 0.0053): within 1 SE. PASS.
- No election worse by more than 2 SE (worst qld2017 +0.032, SE 0.024; nsw2019 +0.048, SE 0.055). PASS.
- Every WA pair byte-identical. PASS.
- AEF-7 ledger -0.0076 (SE 0.0073); vic2022 -0.0221 (SE 0.0050); fed2025 -0.0270 (SE 0.0052); fed2022 +0.0139 (SE 0.0153).
- Unacceptable-pass clause, for Pete: winners pushed below 0.01 by surge-off: Murray nsw2019 0.0163 -> 0.0001,
  Shepparton vic2014 0.0360 -> 0.0009, Noosa qld2017 0.0423 -> 0.0100, Mirani qld2017 0.0102 -> 0.0063.
- Named fed2022 seats, IND win: Wentworth 0.649 -> 0.370, Warringah 0.736 -> 0.945, Kooyong 0.695 -> 0.588,
  Curtin 0.516 -> 0.374, Mackellar 0.276 -> 0.116.
Scorer: `python scripts/score_surge_off.py deciding-runs/20261031-1346-surge-off`. Decision: Pete (below).
