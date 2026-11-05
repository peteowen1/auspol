# Pre-registration: backtest statewide level read per party (`AUSPOL_STATEWIDE_ENDPOINT=party`)

Written 2026-11-06 ~12:20am, overnight (Pete asleep; he said to keep fixing and save decisions for the morning), before
any screen of this switch. Arm built `8cf24ad2`, off by default.

## What it changes

`statewide_draws_as_at()` (`R/forecast_mode.R`) read every party's statewide trend at the single latest series date. Each
party's trend ends at its own last poll, so a party absent from the newest poll had no row there and was folded into OTH.
`party` reads each party at its own last date, which is what the live forecast does (`scripts/fit_seats_full.R:566`).

Affected targets, day before polling day (`fold_count.R`, 6 Nov; party, trend share, days its series ends early):
fed2007 ONP 0.6, DEM 1.0 (13); fed2016 NXT 3.0 (1), UAP 0.6 (28), OTH 12.1 (1); fed2019 NXT 1.3 (221); nsw2019 ONP 3.9 (6);
nsw2023 ONP 4.6 (12), SFF 1.5 (25); vic2014 UAP 2.8 (43); vic2022 UAP 0.9 (13); qld2017 KAP 1.8 (4); wa2008 ONP 0.5 (1);
wa2017 UAP 1.2 (331); sa2018 FF 5.2 (548). 11 of 32; every other target is byte-identical by construction (asserted below).

## Known answer, stated before the screen

nsw2023: off gives ONP 0.00, on gives 4.53; the actual was about 1.8. So on nsw2023 the fix moves One Nation's level
AWAY from the result (|4.5 - 1.8| > |0 - 1.8|). The switch is a consistency fix (backtests should build the level the
way live does), not a claimed accuracy gain. The screen measures the cost or gain; the case for it does not depend on a gain.

## Screen

`scripts/quick_arm.R "AUSPOL_STATEWIDE_ENDPOINT=party" --pairs=<the 11 affected targets that are scored pairs> --sims=1000`,
baseline the shipped configuration, common random numbers. Before reading numbers: the SWE1 lines name what was read at
its own date in each affected pair, and every unaffected pair is byte-identical.

- Primary: pooled seat-winner log loss over the scored affected pairs, SE clustered on election.
- Guard: no election worse by more than 2 SE of its own paired seat differences.
- Reported: share squared error on moved cells; One Nation's statewide level error on nsw2019/nsw2023.

## Decision rule (standard rule, `docs/PRE-REGISTRATION-RULES.md`)

- Better by more than 1 SE: recommend shipping (with a level-pred rebuild and tree retrain, since the trees train on these levels).
- Within 1 SE: a TIE. It goes to Pete as a consistency fix on a tie (the poll-date precedent, 5 Nov: shipped as correctness).
- Worse by more than 1 SE: goes to Pete with the split. Consistency with live is an argument, but not one to ship over a
  measured loss without his call.

Nothing ships overnight under any outcome: shipping changes the published path's training inputs.

## RESULT (2026-11-06 12:29am, 1,000 sims, the 11 affected targets): PASSES the primary. Recommend shipping, with the level-pred rebuild and tree retrain. Pete decides.

- Applied: SWE1 lines in the affected harness logs; 5 of 11 byte-identical (vic2014, vic2022, qld2017, sa2018, wa2017). qld2017 CHECKED 12:50am:
  the arm reads Katter (SWE1 "KAP 1.8") but no FM1 line follows, so KAP is not folded into any simulated class and its share stays
  in the OTH remainder either way (both arms: "folded into OTH: IND, OTH_RIGHT"). The other four not traced.
- Primary, pooled seat-winner log loss, 1,063 seats: 0.3071 -> 0.3065, -0.0007 (SE 0.0004, clustered on election): better by more than 1 SE.
- AEF-7 subset (181 seats): 0.2171 -> 0.2152, -0.0019 (SE 0.0019).
- Per election: nsw2023 -0.0038, fed2016 -0.0018, nsw2019 -0.0009, fed2007 -0.0008, fed2019 +0.0003, wa2008 +0.0009. Guard (no
  election worse by 2 SE of its own seats) not computed per election by quick_arm; the two worse ones are the smallest moves.
- Share squared error on 2,781 moved cells: -1% (SE 1.4%): not clear.
- The known-answer note held for the LEVEL (nsw2023 One Nation 4.53 vs ~1.8 actual) but the SEATS still improved there (-0.0038).
- Not done overnight: the 20,000-sim run on all pairs, and the level-pred rebuild + tree retrain the trees need to see the fix.

## Amendments

(none)

### Confirmation at 20,000 sims (6 Nov 3:26am, same 11 pairs, fresh baseline)

Seat log loss 0.3149 -> 0.3140, -0.0009 (SE 0.0004): better by more than 1 SE, as at the screen. nsw2023 -0.0034, fed2016
-0.0022, fed2007 -0.0019, nsw2019 -0.0011; fed2019 +0.0003, wa2008 +0.0006. Share squared error -1% (SE 1.4%).
