# Pre-registration: the xgb layer's salience feature `surge_h`, time-forward (2026-10-18)

Committed BEFORE anything is built or run. Found overnight 18-19 Oct while fixing NEXT-STEPS F21 (Pete asleep; standing
instruction "keep working through next steps").

## The defect (two, one root)

`scripts/fit_xgb_primary_v6.R:555-567` builds the training feature `surge_h` (each seat's chance of an independent
surge, from search interest) for each election in `SURGE_CANON` from a model fitted on EVERY OTHER canon election:
`train_pairs <- Filter(function(p) !identical(p$election, pr$election), SURGE_CANON)`. That is leave-one-out, so
fed2016's feature was learned partly from fed2019, fed2022, vic2022, nsw2023 and sa2026 (CLAUDE.md: leave-one-out is
not time-forward). Every other election (fed2025 among them, salience cached for 613 candidates) is skipped and filled
with 0 (F21), a constant within an election, which the trees can read as a label. The harnesses' own calls are
time-forward (`elections_before`), as is the live forecast's, so training and serving disagree as well.

## The fix (`AUSPOL_SURGE_H_TF=1`)

For every election with salience (`SAL_PAIRS`), `surge_h` comes from `surge_hazard_for()` fitted on the canon elections
strictly BEFORE it (`elections_before`). An election with no earlier canon election keeps 0 (no information), printed.

## Measurement

Isolated copies (copies, never junctions) of the checkout at the commit that adds the switch: arm (`=1`) and baseline
(`=0`), each rebuilt from stage 3 (the xgb models retrain). Scored with `scripts/score_ratio_feats.R`-style comparison:
seat log loss on every seat of all 35 elections (SE clustered on election), minor-class seat share RMSE, AEF-7.

## Decision rule

A leak fix ships whatever its score does (CLAUDE.md: anything in the backtest must use only what was knowable before the
election). Reported to Pete: the change in every metric, per election, and the fed2025 independents' predictions. Only
a break (an election worse by more than 2 SE of its own seats) goes to Pete before shipping; otherwise the switch is set
"1" in `published_flags.R` and he publishes.

## RESULT (2026-10-19 03:30; isolated stage-3 rebuilds, deciding-runs/surge-h-tf-rebuilds/, arm 7859810 vs baseline
## b6e1acc with AUSPOL_SURGE_H_TF=0) -- leak fixed, measured; one clause fires, so it goes to Pete

The fix landed: every fed2025 row now has a real surge_h (was a filler 0 on all 1,050): Goldstein 0.177, Curtin 0.169,
Warringah 0.190, McMahon 0.036; qld2024 gets values for the first time.
- Seat log loss, 2,931 seats in 35 elections: 0.3262 -> 0.3267, +0.0005 (SE 0.0009), within noise.
- Minor-class seat share RMSE: 3.519 -> 3.513, -0.0067 (SE 0.0084); OTH_RIGHT better by >1 SE.
- Surge elections (sa2026, wa2025, qld2017) -0.0195 (SE 0.0153); collapse elections (wa2021, qld2020) +0.1267 (SE 0.0748).
- Per election (seat-winner log loss, z = change / that election's own seat SE): worse by >2 SE: qld2012 +0.0026 (z 2.22),
  qld2020 +0.0084 (2.14), fed2013 +0.0051 (2.14); better: fed2019 -0.0076 (z -4.06), wa2013 -0.0130 (-1.92).
  With 31 scored elections ~0.7 would cross 2 SE by chance.

**PETE'S DECISION (2026-10-19): KEEP.** The clause is overridden on his call; the switch stays "1" and ships with the
next PR to main.
**The no-election-worse clause fires on three, so this goes to Pete.** The switch stays "1" on dev (a leak fix should not
be reverted for its score); not merged to main, not published, until he decides.
