# Pre-registration: the emergence surge as a LEVEL, not a gain (2026-10-25)

Committed BEFORE any harness, screen or forecast run of the arm. Motivating trace:
`docs/reviews/mildura-benambra-trace-2026-10-25.md` (cause 1). Switch `AUSPOL_SURGE_LEVEL`, default `"0"`.

## The finding, and the premise checked in code

When the emergence surge fires in a draw, the simulator ADDS a draw from `N(surge_mu, surge_sd)` to the
recipient and takes the same amount pro rata from everyone else (`src/seat_sim_core.cpp`, the
"insurgency surge" block; the R engine in `R/seat_sim.R` the same).

**Premise verified.** In the published configuration `surge_mu`/`surge_sd` come from `surge_hazard_for()`
(`R/salience_surge.R`, the return list): `surge_mu = mean(winners$pcv)`, `surge_sd = sd(winners$pcv)`, where
`winners` are the governed training candidates with `elected == TRUE` and `pcv` is the candidate's own
first-preference percentage from `output/candidacies.csv` (`surge_training_population()`). That is the vote
a winner ENDED on, a level. The trace measured the 23 training winners' mean prior vote at 1.06, so in
training a level and a gain agreed. Live in vic2026, 26 of 31 surge-recipient seats are One Nation with a mean
point share of 29.3 already, and a fired surge lifts Mildura's One Nation from 33.75 to about 68.

Two other surge sources DO supply a gain, and the switch refuses to combine with them (`surge_level_on()`
stops): `AUSPOL_IND_MIXTURE=1` (`gain = m2 - typical`, `R/ind_mixture.R`) and `AUSPOL_XGB_SURGE=1` (the
emergence model's predicted `rise`, `scripts/fit_xgb_emergence_v5.R`). Both are `"0"` as published. The flat
fallback (`surge_mu = 15.6`, used when no salience corpus exists) is untouched by this question because the
harnesses that use it also run `AUSPOL_SURGE_H = "0"`, so it never fires.

## Arm

| Arm | Switch | Rule when the surge fires |
|---|---|---|
| A (shipped) | `AUSPOL_SURGE_LEVEL=0` | recipient `v_j + g`, `g ~ N(mu, sd)`; others scaled to give up `g`. |
| L | `AUSPOL_SURGE_LEVEL=1` | draw `L ~ N(mu, sd)`; recipient becomes `max(v_j, L/100 * S)` (`S` = that draw's total); the difference comes from the others pro rata. A recipient already at or above `L` is unchanged. |

The same random number is drawn in both arms, so every draw that does not fire, and every seat with no
hazard, is identical between them (tested both engines, `tests/testthat/test-surge-level.R`). `"0"` is
byte-identical to the engine at `37ccddf` (fixture `tests/testthat/fixtures/surge-level-off-ref.csv`).
Inside `simulate_seat_contests()` (default `surge_level = surge_level_on()`), so the published forecast
(`fit_seats_full.R`), the six harnesses and NT all get it with no call-site change. Under `"1"` every call
prints `SLV1`: seat-draws raised, seats raised, and seat-draws that fired with the recipient already at or
above its level. **Read that line before any score**: an arm with zero raised draws did not run.

Where it can act: only where a salience hazard exists, which is the fed, vic, nsw, qld and sa harnesses
(the WA and NT harnesses fit no salience hazard; published `AUSPOL_SURGE_H = "0"`), and the live forecast.

## Target seats (fixed by rule, list frozen before any score)

Every (election, seat) whose recipient has a point share of at least 10 before the simulation and a hazard
of at least 0.02, because that is where a level and a gain differ by more than 10 points in a fired draw.

Frozen in `docs/plans/prereg-surge-level-targets-2026-10-25.csv` by
`scripts/surge_level_targets.R list` (run from the main checkout, reads `output/` only). The hazard and
recipient are `surge_hazard_for()` fitted on the earlier elections of the nine-pair list in
`scripts/fit_salience_surge_v2.R`; the point share is the newest harness sharedetail `pred_share`.
**196 target seats in 17 elections** (of 314 seat-elections with hazard >= 0.02); 87 of them in AEF-7
(fed2022 20, fed2025 36, nsw2023 11, qld2024 2, sa2026 4, vic2022 14; wa2025 none). Recipients: IND 149,
ALP 18, LNP 14, GRN 9, OTH_RIGHT 4, ONP 1, OTH 1. vic2022 Mildura is on it (IND, hazard 0.219, share 38.7),
matching the trace. Every seat with a hazard above 0 is frozen alongside
(`prereg-surge-level-hazards-2026-10-25.csv`) for clause U2.

**Known approximation, stated now:** the frozen hazards are the canonical-list fit, not each harness's own
call (the harness pair lists differ slightly, and the fed harness builds its own). The list is the
definition for scoring regardless; a target the harness gives no hazard simply scores zero change.

The target set is NOT small (196 seats over 17 elections), so "not measurable" does not apply. Few targets
have a recipient as high as Mildura's One Nation (mean target share 18.5 to 47.9 by election), so the
backtest tests the rule mostly where it moves draws modestly; the vic2026 walk is where it moves most.

## Criterion

Scored by `scripts/surge_level_targets.R score` on the cached `allprobs.csv` of baseline and arm (see
"Commands"). Seat-winner log loss throughout; change = arm minus shipped, lower is better.

1. **Primary (SLS2):** log loss over the 196 target seats lower than shipped by **more than 1 SE**, SE
   clustered on election.
2. **Guard, every seat of every election (SLS3):** not worse by more than 1 SE, clustered on election.
3. **No election materially worse (SLS4):** no election worse on its own seats by more than 2 SE of its own
   paired seat differences.
4. **Leave-one-election-out (SLS5):** the primary keeps its sign with each election dropped.
5. **Not one seat's quirk (SLS6):** the primary keeps its sign with the two largest-gain target seats removed.

**Unacceptable win, named in advance:**

- **U1 (SLS7):** any target-seat recipient who actually WON loses more than 0.10 win probability.
- **U2 (SLS8):** any seat with no hazard (absent from the frozen hazard table) moves by more than 0.001.
  It must not; the engine draws the same numbers there.

**Reported, not decisive:** Brier and reliability by band on the targets; the `SLV1` counts per election;
the vic2026 walk (Mildura and the One Nation recipient seats, expected seats by party before and after).

**Ship rule:** ships if the primary passes and clauses 2-5 and U1-U2 hold. A clause refusing an otherwise
passing result goes to Pete with the split shown, not decided here.

## The scorer was shown to fail before it is trusted

Run on an unrelated cached arm (`deciding-runs/20261020-0831-class-conserve-1k`, `AUSPOL_CLASS_CONSERVE=1`,
which moves seats with no surge at all), `SLS8` flags 135 hazard-0 seats as UNACCEPTABLE. That is the
clause catching an arm that acts outside the surge, which is what it exists to do.

## Commands

Floor: `quick_arm.R` floors winner probabilities at `0.5 / N`. The targets have hazards from 0.02, and U1
needs a 0.10 move resolved, so the screen runs at **`--sims=5000`** (floor 1e-4, well below the smallest
hazard); 1,000 (floor 5e-4) is too coarse for seats whose winner sits near the hazard. Deciding run 20,000.

1. Screen, AEF-7 first:
   `Rscript scripts/quick_arm.R "AUSPOL_SURGE_LEVEL=1" --sims=5000`
2. Then every election:
   `Rscript scripts/quick_arm.R "AUSPOL_SURGE_LEVEL=1" --pairs=all --sims=5000`
3. Score the targets, from the main checkout, with the cache keys `quick_arm.R` prints ("baseline cache
   <key>", "arm cache <key>"; directories under `%TEMP%/auspol-quickarm/cache/`):
   `Rscript scripts/surge_level_targets.R score --base=<qd>/cache/<base key> --arm=<qd>/cache/<arm key> --sims=5000`
4. Deciding run (detached, all elections, 20,000 sims):
   `powershell.exe -File scripts\deciding_run.ps1 -Arm "AUSPOL_SURGE_LEVEL=1" -Label surge-level`
   then step 3 on its cache with `--sims=20000`.

## Not covered here

Arm B of the trace (holding a personally-returning candidate's cell through the live One Nation fill) is a
separate switch with its own decision; it is live-only and cannot be backtested.

## RESULT, AEF-7 screen (2026-10-25; appended, nothing above edited)

`quick_arm.R "AUSPOL_SURGE_LEVEL=1" --sims=5000 --no-reuse --slots=1` ran 17:56-18:17 (launched with 8,161 MB
available) at the code after 5dd64ec. Baseline cache c534f351c292, arm cache 5766a1ac4800. Log
`deciding-runs/quickarm-20261025-surge-level-aef7.log`, score `...-aef7-score.txt`. 7 elections, 681 seats, floor 1e-4.

SLV1 read first. The arm ran: 17,565 / 19,759 / 4,782 / 1,799 / 2,794 / 8,295 seat-draws were raised in the six
harnesses with a hazard, and wa2025 had 0 seats with a hazard. Seat-winner log loss change, arm minus shipped (lower is
better), SE clustered on election:

| clause | scope | n | change | SE | result |
|---|---|--:|--:|--:|---|
| 1 primary (SLS2) | AEF-7 targets | 87 of 196 frozen, 6 el. | -0.0056 | 0.0075 | within 1 SE: NOT PASSED |
| 2 guard (SLS3) | all seats | 681 / 7 el. | -0.0016 | 0.0011 | holds (better by more than 1 SE) |
| 3 per election (SLS4) | | | worst fed2022 +0.0011 (SE 0.0018) | | none worse by 2 SE |
| 4 LOO (SLS5) | | | -0.0125 to -0.0009 | | sign kept |
| 5 without Mildura, Wannon (SLS6) | | | -0.0029 | | sign kept |
| U1 (SLS7) | 29 winning recipients | | 0 lose > 0.10 | | ok |
| U2 (SLS8) | hazard-0 seats | | 0 move > 0.001 | | ok |

Per election: vic2022 -0.0064, fed2025 -0.0035, nsw2023 -0.0018, sa2026 -0.0005, wa2025 0, qld2024 +0.0000,
fed2022 +0.0011. Reading: on AEF-7 the primary points the right way but is within 1 SE. Only 87 of the 196 targets are
in AEF-7. This is NOT a refusal: "within 1 SE" stops nothing, and the prereg's own primary is over all 196 targets.
The `--pairs=all` step was held, because the coordinator's queue said "only if AEF-7 passes"; that decision has been
referred back.

## RESULT, all elections (2026-10-25 21:24-22:50; appended)

`quick_arm.R "AUSPOL_SURGE_LEVEL=1" --pairs=all --sims=5000 --no-reuse --slots=1` at code t181ee5f (58e6740 plus
ef09ee5). Baseline cache 6e4cb6a8d04e, arm cache 05a0e9e05752. Log `deciding-runs/quickarm-20261025-surge-level-all.log`,
score `...-all-score.txt`. 35 elections, 2,931 seats, floor 1e-4. SLV1 shows seat-draws raised in the 17 elections
with a hazard and 0 everywhere else.

| clause | scope | n | change (lower is better) | SE | result |
|---|---|--:|--:|--:|---|
| 1 primary (SLS2) | target seats | 196 / 17 el. | -0.0016 | 0.0036 | within 1 SE: NOT PASSED |
| 2 guard (SLS3) | all seats | 2,931 / 35 el. | -0.0000 | 0.0007 | holds |
| 3 per election (SLS4) | | | worst qld2017 +0.0181 (SE 0.0184) | | none worse by 2 SE |
| 4 LOO (SLS5) | | | -0.0038 to +0.0006 | | sign LOST |
| 5 without Mildura, Wannon (SLS6) | | | -0.0004 | | sign kept |
| U1 (SLS7) | 75 winning recipients | | 0 lose > 0.10 | | ok |
| U2 (SLS8) | hazard-0 seats | | 0 move > 0.001 | | ok |

Elections that gain: vic2022 -0.0064, fed2025 -0.0035, qld2015 -0.0019, qld2020 -0.0019, nsw2023 -0.0018. Elections
that lose: qld2017 +0.0181, nsw2019 +0.0014, fed2022 +0.0011. quick_arm's AEF-7 subset is -0.0016 (SE 0.0011), the
same as the AEF-7 screen.

**Verdict: NOT SHIPPED.** The primary is within 1 SE and leave-one-out loses its sign, so the rule does not clear it.
This is not a headline-positive result refused by a clause: the primary itself did not pass. Mildura and Wannon carry
most of what gain there is (-0.0016 -> -0.0004 without them). The AEF-7 gain does not hold up across all 35
elections, mainly because of qld2017.
