# Prereg: night projection sd refit from the real nights (2026-11-27, written before any arm runs)

**Change.** `booth_projection_sd()` (`R/booth_projection.R:200`) gives a seat's booth projection an sd that is held at
3.5 points below 5% counted, the same for every class. It was calibrated on one rehearsal, majors only, 8.6%+ counted.
Arm `--proj-sd=fitted`: an sd fitted from projection errors on the three real replayed nights (fed2022, fed2025,
vic2022; `scripts/fit_night_projection_sd.R`), smooth in counted share, by class group if the data separate them.

**Why.** Mildura vic2022: independent 0.99 at 7pm on 0.9% counted (Nationals won). Fowler fed2022: Labor 0.993 at
0.3% counted (an independent won). Both are one or two booths given the weight of a twentieth of the count.

**Runs.** Base = tonight's live night settings (class split on, the fitted pair_cal, `cand_ref` as each source's live
default) on each night's saved state, the same as the arm except `--proj-sd`. Same seeds. Snapshots: every one.

**Primary (the targeted window).** Seat-winner log loss over snapshots where the seat's counted share is under 15%,
pooled over the three nights, SE clustered on seat. PASS: arm minus base below 0, by more than 1 SE.

**Guards (each must hold).**
1. Night-average seat-winner log loss (all snapshots) on EACH night: arm no worse than base by more than 1 SE.
2. Wrong calls under the live rule (leader >= 0.99 with 10%+ counted, `night-called-rule-real-nights-2026-11-17.md`):
   no more than base on any night.
3. Seats right at the last snapshot: no fewer than base on any night.

**Unacceptable even if it passes.** The fitted sd is fitted on the same three nights it is scored on. So the deciding
number is the leave-one-night-out version: fit on two nights, score the third, for each night. If only the in-sample
fit passes, it does not ship.

**Ship gate.** A pass ships behind the flag with the flag ON in `scripts/night_vic2026.sh` (one argument to revert on
the night), merged to `main` (the GitHub backup runs from `main`) after `scripts/check_like_ci.R` and the review gate,
then `--dry-2022 --max-cycles=1`. Cutoff noon Sat 28 Nov: past it the model runs as it is today.

## RESULT

(not run)
