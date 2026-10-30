# Pre-registration: direction-aware swing in the base (`AUSPOL_SWING_FORM=hybrid`), 2026-10-30

Written BEFORE any arm ran. Starts from the standard decision rule (`docs/PRE-REGISTRATION-RULES.md`, 2026-10-18);
departures are stated where they apply. Pete chose to build and screen it on 30 Oct (DECISIONS).

## Why

`docs/reviews/small-share-swing-floor-2026-10-30.md`. The base (`dev_slope()`, `R/dev_slope.R`) is
`level_now + slope x (x - level_prev)`, floored at 0: a seat moves by the statewide change in POINTS. When a class
falls, that takes small seats below zero. Mildura vic2026: Labor 6.51 in 2022, the statewide level 36.66 -> 24.47,
slope 0.922, base 0.00; the trees put 4.32 back. Over the published backtest the floor bites 179 of 13,286 stood cells
(1.3%; 152 OTH, 10 IND, 8 ALP), and the trees repair part (RMSE 4.31 -> 3.27; mean actual 3.18, xgb 1.04). On the
TRUE statewide levels (an oracle: the swing form alone, slope 1), points-when-rising and logit-when-falling beat
points-only in 30 of 35 elections (pooled RMSE 5.27 -> 5.08); the gain shrank at slope 0.9 (+1.60) and 0.8 (+0.59).
The earlier refusals (growth-ratio xgb features 2026-10-18, one-formula swing-shape tests) never split by direction,
so they do not close this.

## The change (`AUSPOL_SWING_FORM`, default `"points"` = byte-identical)

`"hybrid"`, inside `dev_slope()` so every caller gets it (the base in all seven harnesses and `fit_seats_full.R`,
and the rules that build a base through it):

1. `x' = level_prev + slope x (x - level_prev)`: the existing shrink toward the class level, unchanged.
2. Class level RISING or flat (`level_now >= level_prev`): `x' + (level_now - level_prev)`, exactly today's form.
3. Class level FALLING: `100 x invlogit(logit(x'/100) + logit(level_now/100) - logit(level_prev/100))`, so the seat
   loses in proportion on the log-odds scale and cannot go below 0.

Continuous where the level is unchanged (both give `x'`); identical to today at every rising class. Shares are
clamped to [0.01, 99.99] points before the logit. No new fitted constant: the slope tables are unchanged, and the clamp
is a numerical guard (CONSTANTS row).

POST-XGB like `AUSPOL_IND_GAP_RESTAND`: listed in `post_xgb_switches()`, run `"points"` in stage 1 of
`rebuild_forecasts.sh`, measured through the frozen as-at trees re-predicted on the changed base
(`AUSPOL_XGB_BASE_DELTA`) in the harnesses and through `base_margin` live. NOT measured here: trees retrained on the
hybrid base (a stage 1-3 rebuild). If the screen is promising but the delta form is small, that retrain is the
strongest version and must run before a refusal is final (CLAUDE.md, negative results).

## Arm

- **H**: `AUSPOL_SWING_FORM=hybrid`, everything else shipped. Screen: `scripts/quick_arm.R "AUSPOL_SWING_FORM=hybrid"`
  (AEF-7, 1,000 sims), then `--pairs=all` if clauses 1-4 hold.

## Criteria (SE clustered on election)

Targets: every seat with a cell whose base moves by more than 0.05 points (falling classes only, by construction).

1. **Primary:** seat-winner log loss over the target seats, better than shipped by more than 1 SE.
2. **Guard:** pooled seat log loss on every scored seat, not worse by more than 1 SE.
3. **Leave-one-election-out:** clause 1 stays better by more than 1 SE with each election dropped; shares reported.
4. **No election worse** by more than 2 SE of its own paired seat differences.
5. **Not one seat's quirk:** clause 1 keeps its sign with the two largest-gain seats removed.
6. **Direction:** report the count of moved cells raised vs lowered (expected: small shares raised, large shares of a
   falling class lowered) and the squared share error on moved cells; refuse only if the moved cells score worse.
7. **Floor count:** report base cells under 0.05 points with votes cast, shipped vs arm (expected: most gone).
8. **Unacceptable win (named in advance):** a pass whose gain comes from LARGE shares of a falling class (last-time
   share over 40) while the small-share cells it was built for (under 10) score worse. That would be the logit form
   pulling big seats down for a reason unrelated to the floor.

Ship rule: clauses 1-2 pass and 3-5 hold on all elections, 8 does not fire; any clause refusing an otherwise passing
result goes to Pete with the split shown. Amendments below, this text unedited.

## Dry run on known cases (prose)

- **Mildura vic2026 Labor** (the case it is built for): x 6.51, slope 0.922, x' = 36.66 + 0.922 x (6.51 - 36.66) =
  8.86; falling: logit(0.0886) shifted by logit(0.2447) - logit(0.3666) gives 5.16. Today 0.00. The base should
  print as 5.16 with the arm on (`AUSPOL_TRACE_SEAT=Mildura`, TRS0 ALP line).
- **A rising class** (Greens vic2026, 11.50 -> 14.27): every Greens cell byte-identical to today. Any change is a bug.
- **A class whose level is unchanged**: byte-identical (x' + 0).

## Known reason it may fail

The trees already repair part of the floor, and the oracle's gain shrank as the slope fell below 1; at the shipped
slopes (0.3-0.99) the base change is smaller than the oracle's. A null here is a plausible outcome and, per the rule
above, is final only after the retrained-trees version if the delta screen is promising.

## Screen result (appended 2026-10-30; nothing above edited)

**AEF-7, 1,000 sims (code at 46bd2fb6): REFUSED, stays "points".**

- Dry run passed first: Mildura vic2026 Labor base 0.00 -> 5.16 (`AUSPOL_TRACE_SEAT`), as written above. It also showed
  the side effect the screen then measured: IND is a falling class too (5.55 -> 3.28), so Cupper's base fell
  28.96 -> 20.78 and her point forecast 21.34 -> 15.97.
- Clause 2 guard FAILS: pooled seat log loss 0.2636 -> 0.2672 (+0.0036, SE 0.0028), worse by more than 1 SE.
- Clause 1 primary fails: the 393 target seats +0.0015 per seat (SE 0.0014); vic2022 +0.0052, wa2025 +0.0032, fed2022
  +0.0003, fed2025 -0.0008. Clause 3: every leave-one-out drop stays worse (+0.0004 to +0.0025). Clause 5: +0.0021
  without Monash and Morwell.
- Clause 6: 1,920 cells moved (838 raised, 1,082 lowered); squared share error 28,604 -> 29,019 (+414, SE 408).
- Clause 8 and the target band: worse in EVERY band of last-time share, including the small shares the change was
  built for (under 10: 3,800 -> 3,900; 10-40: 12,210 -> 12,363; over 40: 9,930 -> 10,165). By class only ALP, GRN and
  OTH_RIGHT improve, slightly. Largest moves: Noosa qld2024 IND 42.4 -> 36.1 (actual 43.2); the sa2026 Liberal seats
  rise 4-5 points, about half of them toward the actual.

The oracle's gain (true levels, slope 1) does not survive the real slopes and the trees: the slope's shrink already
pulls small seats toward the level, and the logit then over-shrinks the large shares of a falling minor class (IND,
ONP), where personal votes sit. Not run, by the rule above: the retrained-trees version. The delta screen is not
promising (worse in every band), so it is not owed; it would cost a stage 1-3 rebuild.
