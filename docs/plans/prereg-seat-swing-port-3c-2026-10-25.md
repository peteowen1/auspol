# Pre-registration: the seat-swing port cleaned for Coalition line-up changes (`AUSPOL_SEAT_SWING_PORT_3C`, 2026-10-25)

Written before any screen. The only R runs so far are read-only dry runs (tables below) against the main checkout's
`output/` and `external/`. They computed shares, weights and coefficients. They scored nothing.

## Why

`docs/reviews/market-disagreement-vic2026-2026-10-25.md` (Bendigo West): we give the Nationals 0.551 in Bendigo West,
the market 0.119. The port moves Bendigo West 5.14 points from Labor to the Coalition because federal Bendigo swung
10.7 points two-party against Labor in 2025. That swing is mostly a candidate change, not a mood: in 2022 federal
Bendigo had one Coalition candidate (a Liberal); in 2025 the Nationals stood beside the Liberals for the first time.
The port's coefficient was fitted as if every federal swing were a general mood the state seat shares.

The same thing happens wherever the federal Coalition line-up changed between the two federal elections the swing
compares: Liberal replaced by National or the reverse, or a three-cornered contest appearing or going away.

The review's fix 3 also proposed "or the Coalition primary moved more than k standard errors". **Not built, and why:**
that rule would flag big genuine swings as well as candidate effects, and its k would be a cut. The line-up change is
the named mechanism, it can be read from the candidate list without looking at the result, and so it cannot select on
the outcome. The review also says only the federal and Victorian harnesses carry the port. That is wrong: the federal
harness has no port, and the nsw, sa, qld, wa and nt harnesses do (the table below has affected divisions in five
states).

## What the switch does

Data: `output/candidacies.csv` (Coalition candidates per division per federal election, `party == "LNP"`, by
`party_ab`), `external/elections/fed-booth-map.csv` (booth to state district, the join the transposition used; WA from
the `external/reference/correspondences/booths-*wa*.csv` files `transpose_fed_swing.R` reads), and the AEC booth files
`external/reference/aec/booths/tpp-fed<year>.csv` (division and votes per booth; `pp-fed2004.csv` for 2004, which has no
two-party booth file). All of these are in `docs/DATA-REGISTRY.md`.

For each booth the transposition used, compare the Coalition line-up of its division at the federal election being
transposed with the line-up of ITS OWN division at the federal election before (matched by `PollingPlaceID`, so a
redistributed booth is compared with the contest its earlier vote came from). A change is a different number of
Coalition candidates, or a different party when there is one on each side. The Queensland merged party (`LNQ`/`LNP`)
alone matches any Coalition line-up (Liberal, National or both), because it replaced them by merger, not by a
candidate choice. A seat's affected
share `frac` is the vote share of its booths that are affected.

| Value | What it changes |
|---|---|
| `"0"` (default) | Nothing. Byte-identical (tests prove it on a synthetic disk). |
| `"1"` | Each seat's federal swing becomes `m + (1 - (1 - w) frac) (fed_swing - m)`, `m` the cycle's mean. `w = AUSPOL_SEAT_SWING_PORT_3C_W`, default `"0"`: the affected share of the seat's deviation is removed. |
| `"2"` | `w` is fitted time-forward for each target, on the same earlier cycles the coefficient uses: the raw deviation is split into `(1 - frac) dev` and `frac dev`, the two slopes are fitted through the origin (error: larger of cycle-clustered and ordinary), and `w = clamp(b_a / b_u, 0, 1) * b_a^2 / (b_a^2 + se_a^2)`. So the default is exclusion unless the affected part is measured to carry over. Then the fit and the target are cleaned at that `w`. |

Both modes clean the earlier cycles the coefficient is FITTED on and the target it is APPLIED to. Everything is in
`R/seat_swing_port_3c.R`, called from `seat_swing_port_fs()` / `seat_swing_port_coef()` in `R/seat_swing_port.R`.
Every harness that applies the port (vic, nsw, sa, wa, qld, nt) and `fit_seats_full.R` reach it through
`seat_swing_port_apply()`. The federal harness has no port. The shipped table `output/seat-swing-port-<target>.csv`
carries `lineup3c` and `w3c` under the arm, and a table written under another setting is refused.

Check codes: `S3C1` (per cycle: the changed divisions with both line-ups, seats touched, largest shares, and coverage)
and `S3C2` (mode 2: the fitted slopes and `w`).

**Coverage is printed and bounded, never dropped quietly** (added after review, 2026-10-25). Each `S3C1` line reports,
for its cycle: map booths absent from the federal two-party file (count), booths there with no votes (count), the vote
share in booths with no match at the earlier federal election (compared under their own division's name), the vote
share whose line-up cannot be read (treated unaffected), and the seats with no booth in the share table. The run
STOPS above these limits, set against the largest value seen across all 16 cycles in the dry run:

| Quantity | Limit | Largest seen (cycle) |
|---|---|---|
| map booths absent from the federal two-party file | 2% of booths | 0 in every cycle |
| booths with no votes | 5% of booths | 20 of 831, 2.4% (wa2021) |
| votes in booths new since the earlier election | 30% of votes | 15.3% (wa2025) |
| votes with an unreadable line-up | 5% of votes | 1.5% (sa2022) |
| state seats with no booth in the share table | any | 0 in every cycle |

The Queensland merger is not a change in either direction: one side `LNP` alone against any Coalition line-up on the
other (Liberal, National or both) is unchanged; `LNP` against no Coalition candidate is a change. No cycle the port
reads compares across the 2010 merger, so the tables below are unaffected by that rule. Neither is used anywhere else
(`tests/testthat/test-check-code-collisions.R` passes).

### Why mode "2" is the primary arm, "1" the comparison, `W=0.5` the sensitivity

Pete's rule is shrinkage over a cut. Mode 2 is the weight fitted from data, shrunk toward exclusion by its own
precision. At the live target the data say the affected part does not carry over: pooled over the nine earlier cycles,
the unaffected slope is 0.459 and the affected slope 0.081 (se 0.427), so `w = 0.006`, which is exclusion in practice.
With the WA cycles pooled (`AUSPOL_SEAT_SWING_PORT_WA=1`, not shipped) it is 0.154 (se 0.202), `w = 0.140`. The
earlier targets' weights are noisier (0.31 to 0.79, below), which is what mode 2 is for. Mode 1 at `W=0` is the plain
exclusion; `W=0.5` brackets it.

## Affected divisions, every cycle the port reads

Each row: the state cycle, the federal election whose swing it uses, the number of changed divisions in its booths, the
divisions (booth's earlier division -> its division now, line-up then -> now), and how many state seats have any
affected share (of which how many at least half). Dry run, 2026-10-25, worktree code against the main checkout.

| Cycle | Federal swing | Changed divisions | Which (then -> now) | Seats touched (>= 50%) of all |
|---|---|---|---|---|
| vic2018 | fed2013 -> 2016 | 6 | Ballarat LP -> LP+NP; Corangamite LP+NP -> LP; Indi LP -> LP+NP; Mallee LP+NP -> NP; McEwen LP -> LP+NP; Murray LP -> LP+NP | 21 (14) of 88 |
| nsw2019 | fed2013 -> 2016 | 11 | Throsby -> Cunningham LP+NP -> LP; Riverina -> Eden-Monaro NP -> LP; Riverina -> Farrer NP -> LP; Throsby -> Hume LP+NP -> LP; Charlton -> Hunter LP -> NP; Paterson -> Lyne LP -> NP; Farrer -> Parkes LP -> NP; Hunter -> Paterson NP -> LP; Hume -> Riverina LP -> NP; Farrer -> Riverina LP -> NP; Gilmore -> Whitlam LP -> LP+NP | 15 (3) of 93 |
| vic2022 | fed2019 -> 2022 | 3 | Mallee LP+NP -> NP; Wannon -> Mallee LP -> NP; Nicholls NP -> LP+NP | 8 (4) of 88 |
| nsw2023 | fed2019 -> 2022 | 3 | Eden-Monaro LP+NP -> LP; Gilmore LP+NP -> LP; Whitlam NP -> LP | 10 (5) of 93 |
| sa2018 | fed2013 -> 2016 | 1 | Barker LP+NP -> LP | 6 (5) of 47 |
| sa2022 | fed2016 -> 2019 | 3 | Barker LP -> LP+NP (also booths from Wakefield and Mayo now in Barker) | 6 (5) of 47 |
| qld2020 | fed2016 -> 2019 | 0 | none | 0 of 93 |
| qld2024 | fed2019 -> 2022 | 0 | none | 0 of 93 |
| **vic2026 (live)** | fed2022 -> 2025 | 4 | **Bendigo LP -> LP+NP**; Indi LP+NP -> LP; Nicholls LP+NP -> NP; McEwen -> Nicholls LP -> NP | 9 (6) of 88 |
| sa2026 | fed2022 -> 2025 | 1 | Grey LP -> LP+NP | 5 (5) of 47 |
| nsw2027 (live, later) | fed2022 -> 2025 | 4 | Paterson -> Hunter LP -> NP; Eden-Monaro -> Riverina LP -> NP; Hume -> Riverina LP -> NP; Hunter -> Shortland NP -> LP | 7 (0) of 93 |
| wa2008 | fed2004 -> 2007 | 0 | none | 0 of 59 |
| wa2013 | fed2007 -> 2010 | 6 | Kalgoorlie -> Durack LP -> LP+NP; Forrest LP -> LP+NP; Kalgoorlie -> O'Connor LP -> LP+NP; Forrest -> O'Connor LP -> LP+NP; Pearce -> O'Connor LP -> LP+NP; Pearce LP -> LP+NP | 22 (14) of 59 |
| wa2017 | fed2013 -> 2016 | 6 | Canning -> Burt LP+NP -> LP; Brand -> Canning LP -> LP+NP; Pearce -> Cowan LP+NP -> LP; Pearce -> Hasluck LP+NP -> LP; Cowan -> Pearce LP -> LP+NP; Moore -> Pearce LP -> LP+NP | 10 (2) of 59 |
| wa2021 | fed2016 -> 2019 | 2 | Canning LP+NP -> LP; Forrest LP+NP -> LP | 12 (7) of 59 |
| wa2025 | fed2019 -> 2022 | 5 | Pearce -> Hasluck LP+NP -> LP; O'Connor LP+NP -> LP; Durack -> O'Connor LP+NP -> LP; Pearce -> O'Connor LP+NP -> LP; Pearce LP+NP -> LP | 15 (8) of 59 |

Unreadable line-ups (booth division not in the candidate corpus) were at most 1.51% of votes (sa2022), 0 in most
cycles; those booths count as unaffected and `S3C1` prints the share.

**vic2026 seats touched** (affected vote share): Bendigo West 100%, Benambra 100%, Ovens Valley 100%, Shepparton 100%,
Bendigo East 99%, Euroa 98%, Murray Plains 49%, Eildon 39%, Macedon 15%.

## Dry run: coefficients and weights (published flags: port "2", WA "2", NOCLIFF "0")

Port coefficient after shrinkage (the number the port multiplies the deviation by), shipped against each mode; `w` is
mode 2's fitted weight (0 = exclusion, 1 = no cleaning). `k` = earlier cycles.

| Target | k | coef shipped | coef mode 1 (W=0) | coef mode 2 | w (mode 2) |
|---|---|---|---|---|---|
| vic2022 | 5 | 0.310 | 0.274 | 0.309 | 0.790 |
| nsw2023 | 6 | 0.377 | 0.365 | 0.380 | 0.763 |
| qld2020 | 3 | 0.161 | 0.075 | 0.124 | 0.468 |
| qld2024 | 7 | 0.409 | 0.433 | 0.434 | 0.019 |
| sa2022 | 4 | 0.294 | 0.270 | 0.290 | 0.460 |
| sa2026 | 8 | 0.411 | 0.433 | 0.433 | 0.020 |
| wa2021 | 7 | 0.289 | 0.281 | 0.297 | 0.785 |
| wa2025 | 12 | 0.361 | 0.384 | 0.387 | 0.312 |
| **vic2026 (live)** | 9 | 0.424 | 0.451 | 0.451 | 0.006 |
| vic2018, nsw2019, sa2018, wa2008, wa2013, wa2017 | under 3 | 0 | 0 | 0 | - |

On the targets with the most history the cleaned coefficient is HIGHER (vic2026 0.424 -> 0.451, unshrunk 0.430 ->
0.462): the line-up seats were diluting the slope, which is the claim. So the arm also moves every unaffected seat's
adjustment by about 6% in vic2026.

**vic2026 port adjustment** (points toward Labor; negative is toward the Coalition):

| Seat | shipped | mode 1 | mode 2 |
|---|---|---|---|
| Bendigo West | -5.14 | -0.18 | -0.21 |
| Bendigo East | -5.98 | -0.24 | -0.28 |
| Benambra | -1.46 | -0.18 | -0.19 |
| Eildon | -1.56 | -1.19 | -1.19 |
| Ovens Valley | -0.88 | -0.18 | -0.18 |
| Murray Plains | -0.50 | -0.45 | -0.45 |
| Euroa | -0.24 | -0.18 | -0.18 |
| Shepparton | -0.18 | -0.18 | -0.18 |
| Macedon | -0.18 | -0.34 | -0.34 |

(Every seat's adjustment is re-centred over the state, so a fully affected seat lands at minus the mean, not 0.)

## Which elections can move (the controls)

Under the shipped flags the arm moves only targets whose port coefficient is non-zero: **vic2022, nsw2023, qld2020,
qld2024, sa2022, sa2026, wa2021, wa2025** (8 elections; qld only through the coefficient, it has no affected seats).
**The other 27 of the 35 `quick_units()` elections must be byte-identical**, including all seven federal pairs and
every NT pair (no transposed swing). `AUSPOL_POSTXGB_RESID_NET` is "0", so no post-xgb table reads the port.

## Criteria (standard rule; SE clustered on election)

1. **Primary:** seat-winner log loss pooled over all elections (`--pairs=all`), lower is better; the arm must beat the
   baseline by more than 1 SE. The movable-set figure (8 elections) is reported beside it and must have the same sign.
2. **Targeted (reported, scoped to the change):** seat-winner log loss and Labor/Coalition primary error on the
   affected seats only (frac >= 0.5 in the table above: vic2022 4, nsw2023 5, sa2022 5, sa2026 5, wa2021 7, wa2025 8;
   34 seat-elections). Must have the same sign as 1.
3. **Guard:** primary-vote RMSE over all scored cells is not worse by more than 1 SE.
4. **Controls:** every election listed as untouched shows 0 changed cells. Any change there voids the result.
5. **It ran:** the arm logs print `S3C1` for every movable target and its earlier cycles, with the divisions above; mode
   2 also prints `S3C2` with the `w` in the dry-run table. A missing line or a different division list voids the run.
6. **Leave-one-election-out:** the primary keeps its sign with each movable election dropped in turn. Each election's
   share of the gain is reported; not a refusal clause.
7. **No election materially worse:** no movable election worse by more than 2 SE of its own paired seat differences.
8. **Unacceptable even if it passes (named now):** clause 4 or 5 failing; or a gain that comes entirely from the qld
   pairs (no affected seats, coefficient only) while the six elections with affected seats are flat or worse. That
   would be a coefficient effect, not the claimed mechanism, and goes to Pete as a separate finding.

**Ship rule:** the primary arm (mode 2) ships only if 1 passes and 2-8 hold, then only after the full 20k deciding run
on all elections. Mode 1 and `W=0.5` are reported beside it; if mode 1 passes and mode 2 does not, that goes to Pete.
A clause refusing a headline-positive result goes to Pete with the split shown.

**MDE (stated before the run).** 34 affected seat-elections out of over 2,000 scored, and most of them are safe Coalition
seats where a few points do not change the winner. The pooled effect is likely under 0.002 log loss, below a 1 SE bar
on 8 movable elections. If AEF-7 is within 1 SE either way, that is "no measurable effect at this size", not a refusal;
the targeted clause 2 and the live walk then carry the decision to Pete.

## Commands

From the repo root. Movable elections first (the screen where the affected divisions exist), at the default 1,000 sims:

```
powershell.exe -Command 'Rscript scripts/quick_arm.R "AUSPOL_SEAT_SWING_PORT_3C=2" --pairs=vic2022,nsw2023,qld2020,qld2024,sa2022,sa2026,wa2021,wa2025'
powershell.exe -Command 'Rscript scripts/quick_arm.R "AUSPOL_SEAT_SWING_PORT_3C=1" --pairs=vic2022,nsw2023,qld2020,qld2024,sa2022,sa2026,wa2021,wa2025'
powershell.exe -Command 'Rscript scripts/quick_arm.R "AUSPOL_SEAT_SWING_PORT_3C=1 AUSPOL_SEAT_SWING_PORT_3C_W=0.5" --pairs=vic2022,nsw2023,qld2020,qld2024,sa2022,sa2026,wa2021,wa2025'
```

AEF-7 (the default pair set):

```
powershell.exe -Command 'Rscript scripts/quick_arm.R "AUSPOL_SEAT_SWING_PORT_3C=2"'
powershell.exe -Command 'Rscript scripts/quick_arm.R "AUSPOL_SEAT_SWING_PORT_3C=1"'
```

Every election, where clause 4's controls are checked:

```
powershell.exe -Command 'Rscript scripts/quick_arm.R "AUSPOL_SEAT_SWING_PORT_3C=2" --pairs=all'
powershell.exe -Command 'Rscript scripts/quick_arm.R "AUSPOL_SEAT_SWING_PORT_3C=1" --pairs=all'
```

Deciding run for anything that passes (detached):
`powershell.exe -File scripts\deciding_run.ps1 -Arm "AUSPOL_SEAT_SWING_PORT_3C=2" -Label port-3c`.

## Live walk (reported, not a criterion)

Run `fit_seats_full.R` on vic2026 under each arm against the shipped run. Report the `S3C1`/`S3C2`/`SP2` lines (shipped:
coefficient 0.424, adjustment sd 1.553) and, for **Bendigo West, Bendigo East, Benambra, Ovens Valley, Shepparton,
Euroa, Murray Plains, Eildon and Macedon**: primary shares (Labor, Coalition, One Nation, Greens) and winner
probabilities before and after. Expected direction: Bendigo West's Nationals fall from 0.551 toward the market's 0.119
and Labor rises (market 0.44); Bendigo East's Coalition falls. The Coalition-held northern seats (Benambra, Ovens
Valley, Shepparton, Euroa) should barely move in winner terms. Also list every other seat whose winner probability
moves by more than 0.05, since the higher coefficient moves every seat a little.

The One Nation half of the Bendigo effect (the 2025 House ONP squeeze, House rank 29 against Senate rank 50) is not
touched by this arm; that is the review's fix 1 (`AUSPOL_ONP_ORDER=senate_rank`).

**Prerequisite before shipping:** the daily CI run reads `output/seat-swing-port-vic2026.csv`, written by
`scripts/promote_rebuild.R`. Under the arm that table carries `lineup3c`/`w3c` and is refused under any other setting,
so promote must run with the shipped value set.

## RESULT, mode 2 screen on the 8 movable elections (2026-10-28, quick_arm 1,000 sims, run from `dev` 7299d304)

`quick_arm.R "AUSPOL_SEAT_SWING_PORT_3C=2" --pairs=vic2022,nsw2023,qld2020,qld2024,sa2022,sa2026,wa2021,wa2025`; HD1 confirmed the
switch applied in all 16 runs. Clause 5: `S3C2` printed for all 8 targets with exactly the dry-run weights (vic2022 0.790,
nsw2023 0.763, qld2020 0.468, qld2024 0.019, sa2022 0.460, sa2026 0.020, wa2021 0.785, wa2025 0.312).

Seat-winner log loss, lower is better (SE clustered on election):

| scope | seats | baseline | arm | change (SE) |
|---|---:|---:|---:|---|
| clause 1, the 8 movable elections | 579 | 0.2186 | 0.2185 | −0.0001 (0.0004): within 1 SE, NOT PASSED |
| AEF-7 subset of those | 380 | 0.2423 | 0.2426 | +0.0003 (0.0006) |
| clause 2, affected seats (frac ≥ 0.5) | 31 of 34 | | | mean +0.0077 per seat (worse); ALP+LNP squared share error −73.1 (better) |

Per election (log loss change): sa2026 +0.0024, wa2025 +0.0012, vic2022 +0.0004, nsw2023 +0.0002, sa2022 −0.0002, wa2021
−0.0008, qld2020 −0.0009, qld2024 −0.0013. Share squared error on the 442 changed cells −83.5 (SE 62.7), not clear.

Clause 2 seats come from each `S3C1` line's "largest" list, which prints the top six, so 3 of the 34 are missing (wa2025's
7th-8th and one other); scored from the quick_arm cache (`%TEMP%/auspol-quickarm/cache/91cbf27330cf` arm, `c5e66bdf0fca`
baseline). The targeted log loss is driven by Monaro +0.136, Mildura +0.103, Albany +0.067, Flinders +0.057; South Coast
−0.127 the other way. Shares improve while winner probabilities slightly worsen.

Not yet run: clause 4 controls (`--pairs=all`), mode 1 and `W=0.5` arms, the live walk (queued 28 Oct as a `port3c` run in
the live-walk agent's experiment 1). Per the MDE paragraph this is "no measurable effect at this size, not a refusal";
the decision goes to Pete with the live walk.

### Live walk and Pete's decision (2026-10-28)

Live walk (`reviews/live-walk-contested-seats-2026-10-28.md`, run `port3c`): `S3C2 vic2026 ... w 0.006` as dry-run. Bendigo West
ALP 0.08 -> 0.36, LNP 0.54 -> 0.19, ONP 0.36 -> 0.43 (market 0.44 / 0.12 / 0.41); Bendigo East favourite LNP 0.60 -> ONP 0.64;
no other seat moved more than 0.05 except Carrum ALP -0.05 (untouched; likely noise).

**Pete, 28 Oct: finish the checks, then ship** (clause 1 not passed; his call under the MDE paragraph, recorded here as an
override of clause 1's 1 SE bar). Remaining before shipping: clause 4 controls on `--pairs=all` (27 untouched elections
byte-identical), then the 20k deciding run (`deciding_run.ps1 -Arm "AUSPOL_SEAT_SWING_PORT_3C=2" -Label port-3c`); ship only if
neither shows harm (no election worse by more than 2 SE, clause 7).
