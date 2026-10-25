# Pre-registration: a party that does not stand gives up the level carried forward for it

Written 2026-10-25, with the switch built and before any arm was scored (the screen result is appended
below the criteria as a visible addition). Source: `docs/reviews/wa-nt-seat-layer-trace-2026-10-25.md`
(the nt2024 Territory Alliance finding) and the nt2024 caveat in
`docs/plans/prereg-level-conserve-2026-10-25.md`. Rules: `docs/PRE-REGISTRATION-RULES.md`; CLAUDE.md
"fix the root cause, for everything", leakage, and "a fix to one harness is a fix to all of them".

Status: BUILT, screened (proxy only), no quick_arm or harness run. Switch `AUSPOL_LEVEL_DEAD_PARTY`,
default `"0"` (byte-identical), published `"0"` in `scripts/published_flags.R`.

## The question

The statewide level carries the previous election's result forward wherever polls are silent: every class
in a thin cycle (`R/thin_cycle.R`, nt2016/2020/2024), and the split of the unpolled "others" bucket wherever
the per-candidate model has no row for a class (`bucket_split_ratio()`, the federal harness's own copy, the
live minor-field scaling in `fit_seats_full.R`). Nothing asks whether the party that made up that share is
on the ballot. nt2024: Territory Alliance took 12.9 of nt2020's 14.1 OTH and did not stand; the thin cycle
carried OTH at 14.8 with no polls; no OTH candidate stood, so the 14.8 was dropped at the level and handed
out pro rata by the seats' row renormalisation.

Does removing a non-standing party's share from what is carried forward, and giving it to the classes that
stand by preference flows (or pro rata), predict the level and the seats better?

## Time-forward

Which parties stand is nomination data (nominations close about two to three weeks before polling day).
The harnesses read it as the target's candidacies with votes > 0 or pcv > 0, the proxy
`zero_unnominated()` already uses. The live forecast reads only the FINAL nomination list
(`AUSPOL_NOM_LIVE=1`); before that nothing is judged dead (`DPL0!`). Flows are each harness's own
time-forward flow matrix (`fm`, built from earlier elections' transfers).

## The change (as built)

`R/level_dead_party.R`, one set of functions for every entry point:

- `dead_party_table()`: per previous party, the share of it that does not stand. A party contesting a
  fraction f of its previous share of seats (chamber-size adjusted, capped at 1) keeps f of its share.
  ALP, LNP, GRN and ONP are judged as a class; OTH, OTH_RIGHT and IND party by party (independents
  excluded). Names are matched across elections (filler and place words dropped, acronyms), and a party
  standing under a new name is found by its candidates: the same-class label most of its previous
  candidates now stand for, at least 3 people and 5% of that label's candidates (LDP -> Libertarian 15,
  CDP -> Australian Christians 10, UAP -> Trumpet of Patriots 9, AD -> DEM 5).
- `dead_party_prior()`: where the previous result SPLITS a polled total (the bucket's prior ratio), the
  dead share leaves its class and goes to the standing classes.
- `dead_party_level()`: where the level itself is CARRIED (the thin cycle), each class's level loses its
  dead fraction times the carried part (1 - its weight on polls). Not the thin cycle's starting point: there
  the unpolled classes share what the polled ones leave, so a smaller prior for OTH only hands the residual
  to IND (built that way first; nt2024 IND went to 23.9 against an actual 14.2, so it was changed before
  any scoring).
- `dead_class_keep()`: a class with no candidate anywhere gives its level to the standing classes instead
  of being dropped (and handed out pro rata by the seat renormalisation).

Values: `"flow"` (primary) gives the share by the class's pooled preference flows from the harness's flow
matrix, restricted to the standing classes, pro rata where the class has no flow row (printed); `"pro"`
(sensitivity) pro rata.

Reach: the six state harnesses through `forecast_statewide_or_oracle(flows = fm)`; the federal harness's
bucket split (`dead_party_prior()`, and per-class factors on its prior-ratio path); `fit_seats_full.R` (the
bucket split, the minor-field targets, the draws' bucket means and the level-conserve level, all through
`.a22_lvl`, plus `dead_class_keep()` on `state_mean`). Post-xgb (`post_xgb_switches()`; stage 1 runs it
"0"). NOT reached: `output/level-pred.csv` (the xgb trees' `level_pred` feature, built by
`scripts/build_level_pred.R`), so the arm moves the seats through the base, not the trees' level feature.

## Target elections (fixed by rule, from nominations only, before scoring)

Rule (`scripts/audit_dead_parties.R`, DPA5): the arm can move an election's level when (a) its level is a
thin cycle and some previous party's share is dead, (b) a class with level > 0 stands nowhere, or (c) a
class outside ALP/LNP/GRN with a dead share is split by the previous result (no candidate-model row).

14 of 35 scored elections: nsw2011 [c:OTH]; sa2010 [b:ONP c:OTH]; sa2014 [c:OTH/OTH_RIGHT]; qld2012
[b:OTH]; qld2015 [c:OTH_RIGHT]; wa2001 [c:OTH/OTH_RIGHT]; wa2005 [b:OTH]; wa2008 [b:ONP c:OTH_RIGHT];
wa2013 [c:OTH_RIGHT]; wa2017 [c:OTH_RIGHT]; wa2021 [c:OTH_RIGHT]; nt2016 [a b:OTH]; nt2020 [a
b:OTH_RIGHT]; nt2024 [a b:OTH]. Every other election must score exactly 0 (the unacceptable clause).

## Affected parties (part 1 of the brief)

Parties holding >= 2% statewide at the previous election that stand in under half their previous share of
seats (scored elections; `scripts/audit_dead_parties.R`, DPA1). Points of statewide vote. "level" = what
the level model gave the CLASS at the target (output/level-pred.csv; thin cycles recomputed with
`thin_cycle_statewide()` before the class is dropped); "arm" = `"flow"` (thin cycles; elsewhere the arm
moves the class only through the bucket split, not shown); "actual" = the class's share; closer to actual
is better.

| election | class | party | prev share | seats prev->now | dead share | class level | arm | class actual | where the level comes from |
|---|---|---|---|---|---|---|---|---|---|
| fed2016 | OTH_RIGHT | Palmer United | 5.5 | 150->1 | 5.5 | 8.6 | = | 5.2 | candidate-model split |
| nsw2019 | OTH | No Land Tax | 2.0 | 93->0 | 2.0 | 3.9 | = | 4.7 | candidate-model split |
| nsw2019 | OTH_RIGHT | Christian Democrats | 3.2 | 93->18 | 2.6 | 3.1 | = | 5.0 | candidate-model split |
| sa2010 | OTH | Democrats | 2.9 | 46->8 | 2.4 | 3.2 | = | 1.6 | previous-result split |
| sa2022 | IND | SA-Best | 14.1 | 36->1 | 13.8 | 11.7 | = | 7.4 | candidate-model split |
| sa2022 | OTH_RIGHT | Australian Conservatives | 3.0 | 33->0 | 3.0 | 3.4 | = | 4.1 | candidate-model split |
| qld2015 | OTH_RIGHT | Katter's Australian Party | 11.5 | 76->11 | 9.9 | 10.1 | = | 8.2 | previous-result split |
| qld2017 | OTH_RIGHT | Palmer United | 5.1 | 50->0 | 5.1 | 0.7 | = | 2.3 | candidate-model split |
| wa2005 | OTH | (all OTH) | 2.6 | 38->0 | 2.6 | 1.6 | 0 | 0.0 | candidate-model split |
| nt2016 | OTH | (all OTH) | 3.0 | 12->0 | 3.0 | 8.0 | 0 | 0.0 | thin cycle |
| nt2020 | OTH_RIGHT | (all OTH_RIGHT) | 4.3 | 15->0 | 4.3 | 3.8 | 0 | 0.0 | thin cycle |
| nt2024 | OTH | (all OTH: Territory Alliance 12.9) | 14.1 | 22->0 | 14.1 | 14.8 | 0 | 0.0 | thin cycle |

Renamed, not dead (found by candidates; DPA4): fed2025 UAP -> Trumpet of Patriots, fed2025 Liberal
Democrats -> Libertarian, sa2018 Family First -> Australian Conservatives, wa2001 Democrats (AD -> DEM),
wa2013 CDP -> Australian Christians, wa2025 ACP -> AC. Most large dead shares sit under the candidate-model
split, which already ignores the previous mix, so the arm reaches them only where it has no row.

## Decision

Primary metrics (SE clustered on election):

1. **Level RMSE on the affected classes**: for each target election, the classes the arm moves; arm minus
   off, pooled over target elections. Must fall by more than 1 SE.
2. **Seat-winner log loss on the target elections** (`quick_arm.R --pairs=<the 14>`), arm minus off, below
   0 by more than 1 SE.

Guards: all 35 elections pooled log loss not worse by more than 1 SE; leave-one-election-out worst case of
the primary still below 0 (no one-election share refusal: if nt2024 carries most of the gain, report the
split and it goes to Pete, per the clause-refusal rule); seat primary squared error on ALP/LNP/GRN cells
not worse by more than 1 SE.

Unacceptable even if the primary passes: any non-target election moving at all; any level that does not
sum to its total; any class level negative.

Choice between `"flow"` and `"pro"`: `"flow"` if it passes and is not worse than `"pro"` by more than 1 SE;
`"pro"` is the sensitivity and decides only if `"flow"` fails and `"pro"` passes, which goes to Pete.

Said before any run: for nt2024 the arm is close to a no-op under `"pro"` (the 14.8 was already handed
out pro rata, by the seats instead of the level) and `"flow"` sends about 27% of it to the Greens (the
pooled OTH flows), which the actual result does not support (GRN 8.1). A refusal is a possible and
reportable result.

## Commands (not run here)

```
Rscript scripts/screen_level_share.R --ref=decay:20 --pairs="dead:flow|decay:20,dead:pro|decay:20,dead:flow|dead:pro"
Rscript scripts/quick_arm.R "AUSPOL_LEVEL_DEAD_PARTY=0" --pairs=nsw2011,sa2010,sa2014,qld2012,qld2015,wa2001,wa2005,wa2008,wa2013,wa2017,wa2021,nt2016,nt2020,nt2024   # dry run: every pair exactly 0
Rscript scripts/quick_arm.R "AUSPOL_LEVEL_DEAD_PARTY=flow" --pairs=nsw2011,sa2010,sa2014,qld2012,qld2015,wa2001,wa2005,wa2008,wa2013,wa2017,wa2021,nt2016,nt2020,nt2024
Rscript scripts/quick_arm.R "AUSPOL_LEVEL_DEAD_PARTY=pro"  --pairs=nsw2011,sa2010,sa2014,qld2012,qld2015,wa2001,wa2005,wa2008,wa2013,wa2017,wa2021,nt2016,nt2020,nt2024
Rscript scripts/quick_arm.R "AUSPOL_LEVEL_DEAD_PARTY=flow" --pairs=all   # guard: non-targets exactly 0
```

The deciding run, if the screen and quick_arm pass: `scripts\deciding_run.ps1 -Arm "AUSPOL_LEVEL_DEAD_PARTY=flow" -Label dead-party`.

## Screen result, 2026-10-25 (added after the criteria above; nothing above edited)

`scripts/screen_level_share.R --ref=decay:20 --pairs="dead:flow|decay:20,dead:pro|decay:20,dead:flow|dead:pro"`
(a proxy, not the simulation: level deltas on ALP/LNP/GRN passed through to seats at the fitted BETA 0.135;
blind to moves inside the others bucket; 35 elections, 2,931 seats; controls 1-2 exactly 0, control 3
(broken arm) +0.0182). Seat log loss proxy change, arm minus shipped, negative = better:

| arm | pooled (SE, clustered on election) | elections moved | worst | best | level MAE ALP/LNP/GRN, per-election mean change (pts) |
|---|---|---|---|---|---|
| flow | +0.0005 (0.0004) | 6 of 35 | nt2024 +0.0300 | wa2008 -0.0053 | +0.015 (worst nt2024 +1.36) |
| pro | -0.0000 (0.0000) | 3 of 35 | nt2016 +0.0002 | nt2024 -0.0014 | -0.014 (nt2016 -0.46) |

Elections moved under flow: sa2010, qld2012, wa2008 (a class standing nowhere, given out by flows) and
nt2016/2020/2024. Non-target elections: all exactly 0. The 8 other targets moved only inside the bucket
(invisible to this screen; quick_arm sees them).

Reading: `"flow"` is worse where it matters, because the pooled OTH preference flows send a large share to
the Greens (nt2024: GRN +2.6, LNP -1.9 relative to pro rata; actual CLP 48.9 against a level of 39.6). As
said in advance, `"pro"` is close to a no-op on nt2024: the 14.8 was already given out pro rata, by the
seats. The CLP under-call in nt2024 is the two polls (LNP 39.9 at weight 0.95), not the dead party. The
screen does not clear `"flow"`; `"pro"` passes the screen only by changing almost nothing. The quick_arm
commands above are the next step if Pete wants the bucket-internal moves measured.
