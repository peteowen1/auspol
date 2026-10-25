# Pre-registration: post-xgb corrections net of the seat-swing port (audit F8, 2026-10-25)

Written before any screen of either arm. The only R run so far is the read-only dry run in "Dry run of the arms"
below. It computed coefficients and netted tables. It scored nothing.

## Why

Audit F8 (`docs/reviews/pipeline-overwrite-audit-2026-10-18.md`; re-checked in
`docs/reviews/audit-f8-f19-status-2026-10-25.md`) says the corrections applied after the trees are each fitted as
though nothing else had been applied. Checked against the code at `37ccddf`:

- **Verified.** The published order is: trees, then `ind_person` final, then the seat-swing port
  (`fit_seats_full.R:1431`), then the seat-poll blend, then the demographic correction, then the leader-seat bonus. Every
  harness uses the same order (vic `:786-817`, nsw `:917-948`, qld `:902-933`, sa `:1081-1112`, wa `:640-671`, nt
  `:670-701`).
- **Verified.** The poll blend, the demographic correction and the leader bonus all learn from
  `current_seat_predictions()` (`R/seat_predictions.R`). So do `departed_fed`, `seat_poll_joint`, `state_poll_pool` and
  `state_deviation`. That function returns the stage-4 as-at xgb prediction and nothing applied after it. So the three
  tables applied after the port are fitted on misses that still contain whatever the port would have fixed.
- **Verified.** The port coefficient is fitted on the seat's WHOLE two-party swing (`seat_swing_port_coef()`, `yy` from
  `seat-tpp-estimates.csv`). The trees already have `fed_swing` as a feature (`output/xgb-primary-v6-final-cols.json`).
  One nuance: the trees' `fed_swing` comes from `load_seats()` (the anchor's transposed federal swing,
  `R/xgb_primary_override.R:390`). The port's comes from our own `fed-swing-transposed.csv`. They are the same
  quantity from two sources. How closely the two agree was NOT checked.
- **Not built, and why.** F8 also lists other overlaps. The demographic correction and the leader bonus are fitted
  without netting each other out. A polled seat is pulled to its poll and then corrected again. And several earlier
  steps (`new_ind_shrink`, `ind_person`, re-entry, `level_recent`) are not in `xgb_pred_seat`. Netting the port is the
  smallest fix, and the audit proposed it. Netting the others in sequence would need each earlier election's
  demographic and poll-blend adjustment rebuilt time-forward. That is a larger change, and it waits for this result.
  Whether those pre-tree steps actually appear in the as-at predictions was NOT checked.

## The arms (both switches default "0"; byte-identical when off)

| Arm | Environment | What it changes |
|---|---|---|
| R | `AUSPOL_SEAT_SWING_PORT_RESID=1` | `seat_swing_port_coef()` regresses each seat's post-tree two-party residual, `((actual ALP - xgb ALP) - (actual LNP - xgb LNP)) / 2`, demeaned per cycle, on the transposed federal swing deviation. Same earlier-cycles-only rule, same shrinkage. Prints `PXR1` with the cycles used. |
| N | `AUSPOL_POSTXGB_RESID_NET=1` | `current_seat_predictions()` adds each state election's own port adjustment (fitted on the cycles before THAT election) into its `xgb_pred_seat`, then renormalises, exactly as `seat_swing_port_apply()` does. Every table fitted after the port then learns from misses net of the port. Federal rows never move. Prints `PXN1`. |
| RN | both | N, with the port adjustment from R's coefficient. |

Both switches are read only in `R/`, which every harness and `fit_seats_full.R` reach. No entry point names them
(`docs/MODEL-REGISTRY.md` rows, regenerated in the same commit).

## Which elections can move (the controls)

The screen scores arm against baseline at the same seed, so an untouched election scores exactly 0.

- **Arm R** moves only targets whose port coefficient is non-zero under the shipped flags: vic2022, nsw2023, qld2020,
  qld2024, sa2022, sa2026, wa2021, wa2025 (8 elections). **The other 27 must be byte-identical.** The poll, demographic
  and leader tables still read un-netted predictions under R alone.
- **Arm N** moves targets whose table fits include an election with a non-zero port. The earliest such election is
  qld2020 (31 Oct 2020). So wa2021, sa2022, fed2022, vic2022, nsw2023, nt2024, qld2024, fed2025, wa2025 and sa2026 can
  move (10 elections). **Every target on or before qld2020 (25 elections) must be byte-identical.** All the table fits
  filter with `elections_before()`, so any movement there is a leak.
- **Arm RN**: the union of the two sets.

## Criteria (standard rule; SE clustered on election)

1. **Primary:** seat-winner log loss pooled over all elections (`--pairs=all`, the 35 that `quick_units()` defines today;
   CLAUDE.md's "22" predates the NT and early pairs). Lower is better. The arm must beat the baseline by more than
   1 SE. Untouched elections score exactly 0, so this is the movable set's change weighted by its seat share. The
   movable-set figure is reported beside it and must have the same sign.
2. **Guard:** primary-vote RMSE over all scored cells is not worse by more than 1 SE.
3. **Controls:** every election listed as untouched above shows 0 changed cells. **Any change there voids the result.**
   It means a leak or wrong wiring, whatever the score.
4. **It ran:** the arm logs print `PXR1` (R) or `PXN1` (N) for every target. For R, every cycle named in `PXR1` comes
   before its target. For N, `PXN1` names the elections it netted, and they match the dry run below.
5. **Leave-one-election-out:** the primary keeps its sign with each movable election dropped in turn. Each election's
   share of the gain is reported. It is not a refusal clause (memory: no one-election share refusal).
6. **No election materially worse:** no movable election is worse by more than 2 SE of its own paired seat differences.
7. **Unacceptable even if it passes (named now):** clause 3 or 4 failing; or, under N, a pooled gain that comes entirely
   from fed2022 and fed2025 while the eight movable state elections are flat or worse. N exists to fix the tables
   applied after the port in state seats. A gain only in federal seats came through the pooled demographic or leader
   fits, not the claimed mechanism, and goes to Pete as a separate finding.

**Ship rule:** an arm ships only if 1 passes and 2-7 hold, and then only after the full 20k deciding run on all
elections. If R and N both pass, RN must also pass before both ship together. If a clause refuses a result that
otherwise passes on the headline, it goes to Pete with the split shown. It is not decided here.

**MDE (expected size, stated before the run).** The port shipped at ledger 0.2840 -> 0.2756 (-0.0083, SE 0.0040) for
moving the coefficient from 0 to about 0.4. Arm R moves it from about 0.4 to about 0.24. Whether that is better is the
question, and the effect may be a third of the original gain or less. With 8 movable elections a 1 SE bar may not be
reachable. If the AEF-7 screen comes out within 1 SE either way, that is "no measurable effect at this size", not a
refusal of the idea. Arm N's effect on the tables is unknown.

## Commands

Run from the repo root (`quick_arm.R` copies every top-level `output/` file into its scratch slot, including
`xgb-primary-asat-predictions.csv` and `seat-tpp-estimates.csv`, `scripts/quick_arm.R:209-211`; `external/` is a
junction). AEF-7 first:

```
powershell.exe -Command 'Rscript scripts/quick_arm.R "AUSPOL_SEAT_SWING_PORT_RESID=1"'
powershell.exe -Command 'Rscript scripts/quick_arm.R "AUSPOL_POSTXGB_RESID_NET=1"'
powershell.exe -Command 'Rscript scripts/quick_arm.R "AUSPOL_SEAT_SWING_PORT_RESID=1 AUSPOL_POSTXGB_RESID_NET=1"'
```

Then every election, where the controls in clause 3 are checked:

```
powershell.exe -Command 'Rscript scripts/quick_arm.R "AUSPOL_SEAT_SWING_PORT_RESID=1" --pairs=all'
powershell.exe -Command 'Rscript scripts/quick_arm.R "AUSPOL_POSTXGB_RESID_NET=1" --pairs=all'
powershell.exe -Command 'Rscript scripts/quick_arm.R "AUSPOL_SEAT_SWING_PORT_RESID=1 AUSPOL_POSTXGB_RESID_NET=1" --pairs=all'
```

The deciding run for anything that passes is a detached job:
`powershell.exe -File scripts\deciding_run.ps1 -Arm "AUSPOL_SEAT_SWING_PORT_RESID=1" -Label port-resid` (and likewise
for the others).

**Live walk (reported, not a criterion):** run `fit_seats_full.R` on vic2026 with each passing arm and compare it with
the shipped run. Report the `SP2` adjustment spread (shipped sd 1.553, coefficient 0.424, `add.log:165`), the DR1 and
LS1 tables, and every seat whose winner probability moves by more than 0.05.

**Prerequisite before R could ship:** the daily CI run reads `output/seat-swing-port-vic2026.csv`, written by
`scripts/promote_rebuild.R`. Under R that table carries a `resid` column. `seat_swing_port_table()` now refuses a table
written under the other mode, so promote must run with the shipped value set.

**The daily CI runner must not net (arm N).** It has no port sources, and shipped port tables exist only for vic2026
and nsw2027. So `current_seat_predictions(net = TRUE)` would stop on every other election. Before N could ship, the CI
run must keep `AUSPOL_POSTXGB_RESID_NET=0`, or ship the netted tables.

## Dry run of the arms (read-only, 2026-10-25, worktree code against the main checkout's `output/`)

Published flags applied (port "2", WA "2", NOCLIFF "0", time-forward fits "1"). The table shows the port coefficient,
shipped against arm R. `k` is the number of earlier cycles and `n` the number of seats. A coefficient of 0 means too few
earlier cycles.

| Target | k, n (shipped) | coef (shipped) | k, n (R) | coef (R) | se (R) |
|---|---|---|---|---|---|
| vic2022 | 5, 361 | 0.310 | 5, 361 | 0.147 | 0.053 |
| vic2026 (live) | 9, 666 | 0.424 | 9, 682 | 0.238 | 0.038 |
| nsw2023 | 6, 439 | 0.377 | 6, 449 | 0.208 | 0.053 |
| qld2020 | 3, 221 | 0.161 | 3, 221 | 0.157 | 0.083 |
| qld2024 | 7, 527 | 0.409 | 7, 542 | 0.230 | 0.043 |
| sa2022 | 4, 314 | 0.294 | 4, 314 | 0.158 | 0.059 |
| sa2026 | 8, 620 | 0.411 | 8, 635 | 0.238 | 0.039 |
| wa2021 | 7, 461 | 0.289 | 6, 432 | 0.223 | 0.053 |
| wa2025 | 12, 825 | 0.361 | 11, 812 | 0.235 | 0.038 |
| vic2018, nsw2019, sa2018, wa2013, wa2017 | under 3 | 0 | under 3 | 0 | - |

The residual fit gives about 55-60% of the shipped coefficient on every target with enough cycles. That supports F8's
claim that the trees already carry part of the federal swing. Whether the smaller coefficient scores better is what the
screen decides. Arm R has slightly more seats on some targets because it does not need the previous election's TPP
estimate. It loses wa2008, which has no as-at predictions.

Arm N (`PXN1`): 25 state elections checked. The port is non-zero in 8 of them (nsw2023, qld2020, qld2024, sa2022,
sa2026, vic2022, wa2021, wa2025). Mean absolute ALP change per seat: from 0.49 points (qld2020) to 1.19 (nsw2023), max
5.22. Federal rows changed: 0. First call 1.5 s, then 0.4 s once memoised (the port is memoised per session, keyed on
every `AUSPOL_*` variable and each input file's size and mtime).

## Dry run of the criterion on known answers

- **Seat-swing port v2 (shipped as v48; `prereg-seat-swing-port-v2-2026-09-29.md` RESULT).** Ledger -0.0083 (SE
  0.0040) is better by more than 1 SE, so clause 1 passes. All-22 pooled 0.3214 -> 0.3181, same sign. Controls showed 0
  seats moved in all 7 federal, 6 WA, vic2014, vic2018, nsw2019 and qld2020, so clause 3 holds. Verdict: SHIP. That
  matches the recorded decision.
- **AUSPOL_MINOR_ADDITIVE federal screen (`prereg-minor-additive-2026-10-25.md`).** Primary -0.0014 (SE 0.0015), so
  clause 1 fails. fed2007 was worse by 0.481 against a 2 SE bar of 0.450, so clause 6 fires. Verdict: REFUSE. That
  matches the recorded refusal (it later shipped live-only on Pete's override, which these criteria leave to him).

Both known answers come out right, and clause 3 can be checked from the screen's "changed cells" output.

## RESULT, arm R AEF-7 screen (2026-10-25; appended, nothing above edited)

`quick_arm.R "AUSPOL_SEAT_SWING_PORT_RESID=1" --no-reuse --slots=1` ran 18:18-18:38 (launched with 8,372 MB available)
at 1,000 sims, at the code after 5dd64ec. Baseline cache d3f07d6e21f7, arm cache bba16ea61f5e. Log
`deciding-runs/quickarm-20261025-f8-R-aef7.log`. 7 elections, 681 seats, floor 5e-4.

- Clause 4 (it ran): `PXR1` printed for all five movable AEF-7 targets (vic2022 5 cycles / 361 seats, nsw2023 6 / 449,
  qld2024 7 / 542, sa2026 8 / 635, wa2025 11 / 812). Every cycle named comes before its target.
- Clause 3 (controls, AEF-7 part): fed2022 and fed2025 have 0 changed cells. Changed cells: 716 of 4,767, in 5 of 7
  elections.
- Seat-winner log loss (lower is better), SE clustered on election: 0.2644 -> 0.2652, **+0.0008 (SE 0.0021)**, within
  1 SE. Per election: qld2024 +0.0116, sa2026 +0.0027, wa2025 +0.0011, vic2022 +0.0002, nsw2023 -0.0083.
- Changed-cell share squared error: +32.4 (SE 188.3), not clear.

Reading: within 1 SE either way, which is "no measurable effect at this size" (the prereg's MDE note), not a
refusal. The deciding primary is `--pairs=all`, with the 27 controls; that run has not been done yet (queued behind
Pete's One Nation priority).
