# Pre-registration: evidence-tiered breakout for new independents (2026-11-01)

**Status: OPEN, design chosen by Pete 1 Nov ("Evidence-tiered"), nothing built.** Replaces the switched-off
surge mixture (`AUSPOL_SALIENCE_SURGE_V2 = "0"` since 31 Oct), which added about 36 points to sitting members.

## What Pete chose, from these cases

Independents who won seats they had no record in (actual / our share, our win probability, from
`output/published-predictions.csv` 1 Nov):

| case | data before polling day | actual / ours, p_win |
|---|---|---|
| Goldstein fed2022 | 32 seat-poll rows | 34.5 / 21.3, 0.25 |
| Noosa qld2017 | search rise 0.138, no polls | 34.4 / 8.9, 0.004 |
| Mayo fed2016 | search rise 0.39, no polls | 34.9 / 17.9, 0.043 |
| Johnston nt2024 | nothing | 30.3 / 4.3, 0.002 |

Base rates in `output/salience-v6.csv` (independents, prior class share under 10): reached 25%+ in 18 of 129
with a search rise above 0.05, against 37 of 1,665 without. Most large rises are namesakes (WA surname-only
keywords; Drysdale nt2020 rise 12.5, actual 4.6).

## The rule

1. **Who:** an independent candidate who is not the sitting member and not a defecting member (those are
   already handled: Lambley, Donato, Dalton, Butler at 0.50 to 0.98). Seat-polled seats keep the seat-poll blend.
2. **Breakout chance by evidence tier:** no evidence, or a search rise. Fitted TIME-FORWARD (only elections
   before the one predicted) and partially pooled toward the overall rate (CLAUDE.md shrinkage rule), never a
   hard cut-off. The search rise enters through the already-fixed non-zero percentile (`R/salience_surge.R`),
   with namesake keywords (surname only) treated as no evidence.
3. **Breakout size:** when a draw breaks out, the candidate's primary comes from the empirical distribution of
   earlier breakouts (time-forward), and the other classes give up votes in proportion (the shipped fill rule).
4. **Both layers:** applied in the seat simulation of `fit_seats_full.R` and all harnesses (one function in `R/`),
   checked on named seats end to end (CLAUDE.md "base_pred AND the xgb layer").

## Decision, fixed before any run

- **Primary (targeted):** seat-winner log loss on the new-independent seats (every seat where a candidate in
  scope ran), all 35 elections, SE clustered on election. Must improve by more than 1 SE.
- **Do-no-harm:** pooled seat log loss over all 35 elections no worse than +1 SE; every election worse by more
  than 0.02 is explained and goes to Pete (no automatic refusal).
- **Unacceptable even if it passes:** any sitting member's win probability moving by more than 0.01; any seat
  where a namesake keyword drives the tier; a gain that comes from one election alone (leave-one-election-out
  must keep the sign).
- **Dry run first** on Johnston, Noosa and Drysdale: Johnston and Noosa must rise, Drysdale must not.

Screen with `scripts/quick_arm.R --pairs=all`; the deciding 20,000-simulation run detached
(`scripts/deciding_run.ps1`), then Pete decides.
