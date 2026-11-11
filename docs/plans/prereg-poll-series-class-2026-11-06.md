# Pre-registration: statewide poll columns classified by full party name (`AUSPOL_POLL_SERIES_CLASS=name`)

Written 2026-11-06 12:50am, overnight (Pete asleep; decisions saved for the morning), before any screen of this switch.

## What it changes

`statewide_draws_as_at()` folds a fitted poll series that is not a simulation class into its class with
`classify_party(name = q, code = q)`, where `q` is the poll file's column code. By code alone KAP, UAP and FF classify as
OTH and SAB as OTH, so they are skipped and their share is dropped before the level is rescaled to 100; their
candidates are classified by full name as OTH_RIGHT (KAP, UAP, FF) and IND (SA-Best). `name` classifies the column by
the party's full name (`.POLL_SERIES_NAME`), so the statewide class level and the seats count a party in the same class.

Measured statewide level moves, day before polling day (`psc.R`, 6 Nov 12:47am; arm minus off, points):
sa2018 IND +21.25, ALP -7.93, LNP -9.05, GRN -2.14; qld2015 OTH_RIGHT +7.48, ALP -2.94, LNP -3.22; sa2010 OTH_RIGHT +3.08;
fed2019 OTH_RIGHT +2.85; fed2022 OTH_RIGHT +2.99; fed2025 OTH_RIGHT +1.79; qld2024 OTH_RIGHT +1.39. 14 other targets unchanged.
(qld2017 is unchanged because its Katter series ends before the newest poll and so never reaches the fold: the interaction
with `AUSPOL_STATEWIDE_ENDPOINT` is not tested here.)

## Known answer, stated before the screen

sa2018 actual: ALP 32.8, LNP 38.0, SA-Best 14.2, GRN 6.7 (approx., from the commission's totals). The current backtest gives
SA-Best's ~21 polled points to nobody and rescales the rest up, so its IND level is far below 14 and its majors above
their results; the arm should move IND toward 14 and the majors down. If the screen shows sa2018 WORSE on seats, look for
a second mechanism before reading it as "the fix hurts".

## Screen

`quick_arm.R "AUSPOL_POLL_SERIES_CLASS=name" --pairs=fed2019,fed2022,fed2025,sa2010,sa2018,qld2015,qld2024 --sims=1000`,
baseline the shipped configuration. Before reading numbers: PSC1 lines name each reclassified series, and the moved
pairs are exactly these seven.

- Primary: pooled seat-winner log loss over the seven, SE clustered on election.
- Reported: share squared error on moved cells; sa2018 and qld2015 separately.

## Decision rule (standard rule)

- Better by more than 1 SE: recommend shipping (with a level-pred rebuild and tree retrain).
- Within 1 SE: goes to Pete as a correctness fix on a tie (same class at statewide and seat level is the
  one-source-of-truth rule in CLAUDE.md).
- Worse by more than 1 SE: to Pete with the split.

Nothing ships overnight.

## RESULT (2026-11-06 12:58am, 1,000 sims, 7 pairs): a TIE that leans worse; NOT recommended alone. To Pete.

- Applied: PSC1 lines (sa2018: "SAB classed by name as IND (by code: OTH)"); all 7 pairs moved.
- Primary, pooled seat-winner log loss, 721 seats: 0.2874 -> 0.2890, +0.0016 (SE 0.0024): within 1 SE.
- Per election: qld2015 +0.0120, sa2018 +0.0067, sa2010 +0.0031, fed2022 +0.0026, fed2019 +0.0015, qld2024 +0.0008; fed2025 -0.0070.
  Six of seven worse. Share squared error on 3,495 moved cells +1% (SE 2.7%).
- The known answer FAILED (sa2018 worse), so the second mechanism was looked for (seat means from the cached sharedetail, points,
  base / arm / actual): IND 11.42 / 12.32 / 17.89; ALP 32.68 / 31.63 / 32.43; LNP 36.18 / 35.00 / 38.04; OTH 5.14 / 5.80 / 2.01;
  OTH_RIGHT 5.39 / 6.22 / 2.86. The statewide IND level rose 21 points but the seats' IND rose 0.9: the seat layer does not carry
  a statewide IND rise into the seats, and the share taken from the majors went to OTH and OTH_RIGHT, which were already over.
  Not traced in code; the likely place is how a class level reaches seats with no candidate of that class (SA-Best stood in
  some seats only). Morphett is the largest loss (LNP winner 0.110 -> 0.073).
- Reading: the classification fix is right (one class per party at both levels) but cannot ship until the seat layer passes a
  class level through to the seats that have that class's candidates. Shipping it alone would move share to the wrong classes.

## Amendments

### Amendment 1 (2026-11-06 1:15am, AFTER the first result; post hoc, so read the rerun with that in mind)

The first screen's sa2018 trace found the second mechanism: a class with no poll series of its own (IND) is in `folded`, and
`forecast_statewide_for()` (R/forecast_statewide.R ~92-131) sums every folded class into the others bucket and re-splits the
bucket by fixed prior-election ratios. So SA-Best's share, correctly given to IND, went back into the bucket and mostly to
OTH and OTH_RIGHT (seat IND +0.9 against a statewide +21). The arm now also removes a class that received a folded-in series
from `folded` (prints PSC2), so its level is the polls' rather than a ratio of the bucket. Same switch, same 7 pairs, same
rule. Because this change was made after seeing a result, a pass on the rerun is evidence for the mechanism, not a clean
confirmatory test: the deciding run on all pairs is the one that counts.

### Amendment 1 RESULT (1:23am, same 7 pairs, 1,000 sims): pooled a TIE, AEF-7 subset better; sa2018 much worse on seats, better on shares.

- Pooled seat-winner log loss, 721 seats: 0.2874 -> 0.2848, -0.0026 (SE 0.0040): within 1 SE. AEF-7 subset (394 seats): -0.0074 (SE 0.0016).
- Per election (first version in brackets): fed2019 -0.0074 (+0.0015), fed2022 -0.0075 (+0.0026), fed2025 -0.0097 (-0.0070),
  sa2010 -0.0116 (+0.0031), qld2024 -0.0033 (+0.0008), qld2015 +0.0120 (+0.0120), sa2018 +0.0402 (+0.0067).
- sa2018: share squared error on its moved cells -2,350 (much better) while seat log loss is +0.040: SA-Best took ~14% and won no
  seat, so a correct IND level raises IND win chances that did not convert. qld2015 unchanged by the amendment.
- Reading: the class fix plus the bucket fix is right on shares and helps the federal and AEF-7 seats; it costs sa2018 seats.
  Post hoc (Amendment 1), so the all-pairs deciding run decides. To Pete.

### Amendment 1 at 20,000 sims (6 Nov 3:26am, same 7 pairs)

Seat log loss 0.2905 -> 0.2877, -0.0028 (SE 0.0038): a tie, the same pattern as at 1,000 sims. fed2022 -0.0088, fed2025
-0.0082, fed2019 -0.0067, sa2010 -0.0142, qld2024 -0.0037; sa2018 +0.0370, qld2015 +0.0122. Share squared error -2% (SE 6%).

### Where the sa2018 loss comes from (6 Nov 8:45am, read-only, the 20k caches above)

Not an amendment; nothing rerun. sa2018 +0.0370 per seat, of which Morphett alone is +0.0311; the other 39 seats +0.0060
(14 better, 26 worse). Morphett: sitting Liberal Duncan McFetridge (57.7% in 2014) ran as an independent and got 14.2%; SA-Best's
Simon Jones got 12.1%; Liberal Stephen Patterson won with 41.4%. The baseline ALREADY gave IND 0.742 there (Liberal 0.104); the arm
raised it to 0.928 (Liberal 0.030). So most of the cost is a pre-existing over-call of a defecting sitting member, which the
correct SA-Best level amplifies (two IND candidates in one seat). Next 4 worst: Hartley +0.233 (IND 0.026 -> 0.166; Xenophon
himself stood and lost), Davenport +0.231, Elder +0.149, Kavel +0.126.

Reading: the class fix is not the problem in sa2018; the defector's carried personal vote is. Worth a look at how a sitting member
who loses preselection and runs as IND keeps his vote (`docs/plans/prereg-defector-pooling-2026-09-09.md`) before deciding this switch.

## DECIDING RUN RESULT (all 35 elections, 20,000 sims, code t6602e46 at 89dda002; run 11 Nov 11pm, read 12 Nov)

- Primary, pooled seat-winner log loss, 2,931 seats: 0.3089 -> 0.3114, +0.0025 (SE 0.0016, clustered on election): WORSE by more than 1 SE.
- Share squared error on 6,807 changed cells (14 of 35 elections moved; 21 byte-identical): +15% (SE 8%).
- AEF-7 ledger subset, 681 seats: 0.2523 -> 0.2514, -0.0009 (SE 0.0031): within 1 SE.
- Per election (log loss change): sa2018 +0.0756, fed2013 +0.0158, vic2022 +0.0158, qld2017 +0.0116, fed2016 +0.0085,
  fed2019 +0.0083, qld2015 +0.0035, nsw2023 +0.0014; wa2017 -0.0015, qld2024 -0.0022, fed2025 -0.0048, vic2014 -0.0069,
  fed2022 -0.0082, sa2010 -0.0132.
- Standard rule: worse by more than 1 SE, to Pete with the split. Pete, 12 Nov: do not ship. `AUSPOL_POLL_SERIES_CLASS` stays "code".
