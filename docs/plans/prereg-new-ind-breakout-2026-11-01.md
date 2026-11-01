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

## Amendment 1 (1 Nov, before any build or run; Pete's correction)

The clause "any sitting member's win probability moving by more than 0.01" is WRONG and is withdrawn (left above,
unedited). Pete: "surely if a new independent enters a seat the incumbent SHOULD drop? As they're being
challenged?" Correct: a breakout draw takes its votes from every other class in the seat, so the incumbent's win
probability SHOULD fall there. What stays excluded is a sitting member RECEIVING a breakout (the old surge's
fault). Replacement unacceptable-if-it-passes clause: a breakout fired for a sitting member or defector, or an
incumbent's win probability moving in a seat with no new independent standing.

Also found before building: `R/breakout_mix.R` (`AUSPOL_BREAKOUT_MIX`, built 6 Oct) already is this mechanism
with a 47-feature time-forward classifier for IND/OTH/OTH_RIGHT/ONP under 15%, and was REFUSED 6 Oct
(`prereg-breakout-mix-gated-2026-10-06.md`: 22 elections +0.0018, fed2025 +0.023 from Voices-style
independents flagged who did not win). The decision on how to proceed went to Pete.

## Result (1 Nov 5:47pm; screen, NOT the deciding run) -- goes to Pete

Arm: the existing breakout mixture limited to new independents (`AUSPOL_BREAKOUT_MIX=1`,
`AUSPOL_BREAKOUT_MIX_CLASSES=IND`, `AUSPOL_BREAKOUT_MIX_NEW_ONLY=1`), `scripts/quick_arm.R --pairs=all --sims=2000`,
70 runs, scope confirmed in every arm run (HD1; BO2s). Seat-winner log loss, lower is better:

| seats | n | baseline | arm | change |
|---|--:|--:|--:|--:|
| an independent won | 99 | 1.2836 | 1.1460 | -0.1375 |
| anyone else won | 2,832 | 0.2767 | 0.2843 | +0.0075 |
| all 35 elections | 2,931 | 0.3107 | 0.3134 | +0.0026 (SE 0.0029), within 1 SE |
| AEF-7 subset | 681 | 0.2600 | 0.2708 | +0.0107 (SE 0.0023), worse beyond 1 SE |

- Dry run: Johnston 0.0005 -> 0.0415, Noosa 0.0030 -> 0.0400 (both rise); Drysdale 0.0325 -> 0.0310 (does not). PASS.
- Primary as written (seats where a candidate in scope STOOD) was not computed; the IND-won row above is a
  narrower stand-in. Do-no-harm pooled: within 1 SE. Elections worse by more than 0.02: vic2010 +0.035,
  nsw2011 +0.030, nt2020 +0.030, vic2022 +0.020; best nt2024 -0.167, vic2014 -0.029, fed2013 -0.024, qld2017 -0.018.
- Reading: the same leak as the 6 Oct refusal, smaller: many small breakout chances in safe seats each take a
  little from the real winner. Switches stay OFF.

## Amendment 2 (1 Nov, Pete chose "Screen a gated version"; written before that run)

One arm: the arm above plus `AUSPOL_BREAKOUT_MIX_MIN_P=0.05` (only cells whose time-forward breakout probability is
at least 0.05 carry the mixture). The cut-off is fixed here and not tuned after the run. Same criteria: pooled
35-election log loss no worse than +1 SE AND better on the seats an independent won; AEF-7 subset reported;
every election worse by more than 0.02 explained to Pete. Dry run: Johnston and Noosa must still rise. If the
gate removes them (their p below 0.05), that is reported as the gate failing its own dry run, not tuned around.

## Result, gated arm (1 Nov 6:47pm; screen) -- goes to Pete

`AUSPOL_BREAKOUT_MIX_MIN_P=0.05` added; 70 runs, switches confirmed (HD1). Seat log loss, lower is better:
independent-won seats (n 99) 1.2836 -> 1.2107 (-0.0728); all other seats (n 2,832) 0.2767 -> 0.2816 (+0.0049);
all 35 elections 0.3107 -> 0.3130 (+0.0023, SE 0.0024, within 1 SE); AEF-7 0.2600 -> 0.2679 (+0.0079, SE 0.0017,
worse beyond 1 SE). Dry run: Johnston 0.0005 -> 0.0430, Noosa 0.0030 -> 0.0405 (rise), Drysdale 0.0325 -> 0.0340.
The gate halves the leak and halves the gain. By the letter of amendment 2 it passes (pooled within 1 SE, IND-won
seats better); the pooled point estimate is still worse and AEF-7 is worse beyond 1 SE. Recommendation: do not ship.
