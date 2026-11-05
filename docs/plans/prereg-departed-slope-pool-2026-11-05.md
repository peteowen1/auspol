# Pre-registration: the ALP/LNP departed-member slope pooled toward the two-party slope (2026-11-05)

Written before any screen. Pete's decision 27 Oct ("tau^2 arm toward the pooled slope", DECISIONS) and his go on
option B on 5 Nov (`docs/reviews/departed-slope-pooling-walk-2026-11-05.md`, which has the rows in plain words).

## What the arm changes

`AUSPOL_DEPARTED_POOL=1` (default `"0"`), read in `fit_major_departed_slope()` (`R/split_slope.R`), which every harness
and `fit_seats_full.R` call, so live and backtests get the same rule. It changes the **departed** cells only (a Labor or
Coalition seat whose sitting member is not standing again). The present-member cells are untouched.

Today below 40 departed seats a party's slope is thrown away and set to 1 (the seat's old lean carries in full); at 40
or more its own estimate is believed outright. Under the arm, with no seat-count floor:

- `mu`: the slope through the origin over both parties' departed seats together;
- each party's own slope and its standard error (the larger of the cluster-by-election and ordinary SE, as in
  `.shrunk_slope()`);
- `tau^2`, the between-party variance, from EARLIER ELECTIONS' gaps: per earlier election with departed seats for both
  parties, the ALP-minus-LNP slope gap `g` and its sampling variance `v`; `tau^2 = max(0, weighted mean(g^2 - v)) / 4`,
  weights `1 / (v + 4 tau^2)^2`, iterated;
- each party's slope = `mu + tau^2 / (tau^2 + se^2) * (own - mu)`.

A party with no departed rows takes `mu`; no rows at all keeps 1 (wa2001). If `AUSPOL_SLOPE_SHRINK=1` is also set, the
pool decides the departed cells. Everything is time-forward: rows come only from pairs before the target.

## The cells it produces (computed before any screen; slope multipliers, 1 = old lean carried in full)

Shipped = what ships today. Own (SE) = the party's own estimate. Pooled = the arm.

| target | shipped ALP / LNP (n) | own ALP / LNP (SE) | mu | tau^2 (gap elections) | pooled ALP / LNP |
|---|---|---|---|---|---|
| fed2007 | 1 / 1 (6 / 14) | 0.303 (0.240) / 0.874 (0.314) | 0.689 | 0.0033 (1) | 0.668 / 0.695 |
| fed2010 | 1 / 1 (27 / 38) | 0.555 (0.153) / 0.800 (0.135) | 0.713 | 0.0164 (4) | 0.648 / 0.754 |
| sa2010 | 1 / 1 (20 / 30) | 0.502 (0.180) / 0.794 (0.198) | 0.682 | 0.0234 (3) | 0.607 / 0.724 |
| wa2001 | 1 / 1 (0 / 0) | no rows | - | - | 1 / 1 |
| wa2005 | 1 / 1 (5 / 5) | 0.252 (0.284) / 0.581 (0.120) | 0.439 | 0.0033 (1) | 0.432 / 0.466 |
| wa2008 | 1 / 1 (17 / 26) | 0.486 (0.207) / 0.844 (0.216) | 0.709 | 0.0000 (2) | 0.709 / 0.709 |
| nsw2011, vic2010 | 0.554 / 0.777 (40 / 52) | same | 0.688 | 0.0119 (5) | 0.620 / 0.730 |
| fed2022 | 0.675 / 0.663 | same | 0.668 | 0.0042 (22) | 0.673 / 0.666 |
| fed2025 | 0.635 / 0.659 | same | 0.648 | 0.0078 (27) | 0.637 / 0.656 |
| nsw2023 | 0.653 / 0.664 | same | 0.659 | 0.0052 (24) | 0.654 / 0.662 |
| qld2024 | 0.647 / 0.649 | same | 0.648 | 0.0048 (25) | 0.647 / 0.648 |
| sa2026 | 0.632 / 0.655 | same | 0.644 | 0.0074 (28) | 0.633 / 0.651 |
| vic2022 | 0.664 / 0.663 | same | 0.663 | 0.0039 (23) | 0.664 / 0.663 |
| wa2025 | 0.642 / 0.652 | same | 0.647 | 0.0050 (26) | 0.643 / 0.650 |
| vic2026 (live) | 0.618 / 0.641 (250 / 270) | same | 0.630 | 0.0069 (29) | 0.620 / 0.638 |

So the arm is two different changes: in the eight early elections it replaces 1.0 (or an at-the-floor estimate) with
0.43-0.75; everywhere recent it moves a slope by at most 0.004. Unlike `AUSPOL_SLOPE_SHRINK` (refused 29 Sep: it pulled
recent, well-measured slopes toward 1), it should leave the recent elections nearly untouched. wa2008's tau^2 is 0 from
two gap elections, so both parties take the same slope there; that is shrinkage working from a thin variance, noted, not
adjusted.

## Criterion (seat log loss = minus log of the probability given to the actual winner; lower is better)

1. **Do-no-harm, AEF-7** (`scripts/quick_arm.R`, 1,000 sims, SE clustered on election): pooled seat log loss not
   worse by more than 1 SE. WORSE beyond 1 SE stops the arm.
2. **Targeted: the eight elections** fed2007, fed2010, sa2010, wa2001, wa2005, wa2008, nsw2011, vic2010, pooled over
   their seats, SE clustered on election: better than shipped by more than 1 SE. wa2001 must score exactly 0.
3. **Guard, all pairs** (`--pairs=all`, the deciding run at 20,000 sims): pooled seat log loss not worse by more than
   1 SE; no election worse by more than 2 SE of its own paired seat differences; leave-one-election-out on the
   targeted metric stays better by more than 1 SE with each of the eight dropped in turn; the targeted gain keeps its
   sign with the two largest-gain seats removed.
4. **It ran:** the `BF0m` departed values differ from the baseline in every targeted election except wa2001, and match
   the table above.

**What would make an apparent win unacceptable, in advance:**
- the targeted gain comes with the recent elections worse beyond 1 SE pooled: a trade, to Pete with the split;
- the departed-member seats in the eight score worse on share squared error in most of them (outcomes contradict
  the direction: the arm says a retiring member's seat lean carries less than in full);
- clause 4 fails.

**What the criterion cannot see:** quick_arm's `0.5/N` probability floor at the screen (the deciding run is 20k);
and on AEF-7 the arm moves slopes by at most 0.004, so clause 1 is close to a check that nothing else moved.

## Dry run on cases with a known answer

- Rebuild J, 29 Sep (`AUSPOL_SLOPE_SHRINK`): clause 1 on the AEF-7 elections +0.0056, SE 0.0035, 1.6 SE worse: stops.
  The refusal that was made. Correct.
- wa2001 has no rows under either setting, so clause 2's exact-0 check fails if any other code path moved it.
- Clause 4 against the table: a run where `BF0m` still prints 1.000 for fed2007 has not applied the arm.

## Decision rule

Clause 1 on the screen stops or continues. Clauses 2-4 on the all-pairs deciding run decide: all pass, recommend
shipping. Clause 2 fails while 1 and 3 pass (no gain, no harm): to Pete as "ship on the no-cliff rule, or keep the
cliff", with the split shown, not decided here.

## Commands

```
powershell.exe -Command 'Rscript scripts/quick_arm.R "AUSPOL_DEPARTED_POOL=1"'
powershell.exe -Command 'Rscript scripts/quick_arm.R "AUSPOL_DEPARTED_POOL=1" --pairs=fed2007,fed2010,sa2010,wa2001,wa2005,wa2008,nsw2011,vic2010'
powershell.exe -File scripts\deciding_run.ps1 -Arm "AUSPOL_DEPARTED_POOL=1" -Label departed-slope-pool -At 02:00
```

## Results (added after the runs; clauses above unedited)

### Clause 2, targeted screen (5 Nov, 1,000 sims, code t4bc5e21, 689 seats in 8 elections): PASS

Seat-winner log loss (lower is better) 0.3540 -> 0.3488, change -0.0052, SE 0.0036 clustered on election: better by
1.44 SE. Share squared error on the 410 moved cells 15,857 -> 15,533 (-2%, SE 777: not clear on its own).

Per election (log loss change, lower is better; squared-error change on that election's moved cells, lower is better):

| election | moved cells | log loss change | sq. error change |
|---|---|---|---|
| fed2010 | 87 | -0.0189 | -570.3 |
| nsw2011 | 100 | -0.0063 | -59.8 |
| wa2005 | 47 | -0.0048 | +445.9 |
| fed2007 | 81 | -0.0003 | -117.8 |
| sa2010 | 71 | +0.0007 | +50.7 |
| wa2008 | 24 | +0.0013 | -72.6 |
| wa2001 | 0 | 0 (byte-identical) | 0 |
| vic2010 | 0 | 0 (byte-identical) | 0 |

Clause 4: every `BF0m` departed value in the arm matches the table above; baseline printed 1.000 for the six snapped
elections. **vic2010 got the new slopes but has no departed-member cells to apply them to**: `candidate_returns(vic2006,
vic2010)` flags 0 major departures because `output/candidacies.csv` has `elected` NA on all 459 vic2006 rows. A
pre-existing data gap, not this arm; queued. So the targeted set is effectively seven elections.

Unacceptable-win check: share error on the moved cells is worse in 2 of the 6 elections that moved (sa2010, wa2005),
not most. Passes.

### Prepared for the all-elections run (not applied)

- All clauses pass: ask Pete; on his yes set `AUSPOL_DEPARTED_POOL = "1"` in `scripts/published_flags.R` AND the inline
  default in `.departed_pool_on()` (`R/split_slope.R`, `Sys.getenv("AUSPOL_DEPARTED_POOL", "0")` -> `"1"`), regenerate
  `docs/MODEL-REGISTRY.md`, then a live `fit_seats_full.R` walk with and without it (vic2026 departed slopes 0.618 /
  0.641 -> 0.620 / 0.638; expect small moves) before the PR.
- Clause 2 holds but clause 3 fails: refused; record in DECISIONS with the failing election.
- Clause 2 fails at 20k with 1 and 3 passing: to Pete as "ship on the no-cliff rule, or keep the cliff".

## Amendment 1 (5 Nov, after the targeted screen; the clauses above are unedited)

**What changed:** the sampling variance `v` of each earlier election's ALP-minus-LNP gap now uses ONE residual
variance pooled over every (election, party) cell, `v = s2/sxx_ALP + s2/sxx_LNP`, instead of each cell's own residual
variance. 1-row cells now count too.

**Why, and why it is not chosen to fit the answer:** the pre-PR code review found it, not the results. A cell with 2-3
departed seats can give a near-zero own variance, take almost all the weight (`1/v^2`) and push `tau^2` to 1 or more,
which turns the pooling off. In simulation (true `tau^2` 0, five 30-seat elections plus one 2-seat election) the old
code's worst `tau^2` over 100 draws was 4.22; the new code's stays under 0.05
(`tests/testthat/test-major_departed.R`). The real corpus has these cells everywhere: 19 of the 67 behind vic2026 have
under 5 rows. The direction of the change on the targeted screen was not known when it was made.

**The cells it now produces** (replaces the table above for every run after this amendment):

| target | mu | tau^2 (gap elections) | pooled ALP / LNP | was (original rule) |
|---|---|---|---|---|
| fed2007 | 0.689 | 0.0077 (2) | 0.644 / 0.703 | 0.668 / 0.695 |
| fed2010 | 0.713 | 0.0043 (5) | 0.689 / 0.730 | 0.648 / 0.754 |
| sa2010 | 0.682 | 0.0114 (4) | 0.635 / 0.707 | 0.607 / 0.724 |
| wa2005 | 0.439 | 0.0052 (1) | 0.428 / 0.477 | 0.432 / 0.466 |
| wa2008 | 0.709 | 0.0092 (3) | 0.670 / 0.731 | 0.709 / 0.709 |
| nsw2011, vic2010 | 0.688 | 0.0023 (6) | 0.666 / 0.701 | 0.620 / 0.730 |
| fed2022 | 0.668 | 0.0010 (25) | 0.671 / 0.667 | 0.673 / 0.666 |
| fed2025 | 0.648 | 0.0004 (31) | 0.644 / 0.649 | 0.637 / 0.656 |
| nsw2023 | 0.659 | 0.0018 (27) | 0.656 / 0.660 | 0.654 / 0.662 |
| qld2024 | 0.648 | 0.0000 (29) | 0.648 / 0.648 | 0.647 / 0.648 |
| sa2026 | 0.644 | 0.0004 (32) | 0.641 / 0.645 | 0.633 / 0.651 |
| vic2022 | 0.663 | 0.0012 (26) | 0.664 / 0.663 | 0.664 / 0.663 |
| wa2025 | 0.647 | 0.0000 (30) | 0.647 / 0.647 | 0.643 / 0.650 |
| vic2026 (live) | 0.630 | 0.0000 (33) | 0.630 / 0.630 | 0.620 / 0.638 |

Recent elections now put both parties on nearly one slope (live: 0.618 / 0.641 shipped -> 0.630 / 0.630), so AEF-7
moves a little more than before (up to 0.012) and clause 1 is a real check, not a near no-op.

**Runs:** the targeted screen above (clause 2 PASS) and the first AEF-7 screen (seat log loss 0.2584 -> 0.2584) used the
original rule, and my edit landed while the AEF-7 screen ran, so it counts for nothing. Both screens are re-run on the
amended code and decide clauses 1 and 2. The 2am all-elections run booked on the original code is replaced by one on
the amended code.

### Results on the amended code (5 Nov, 1,000 sims, code tc7a118c)

- **Clause 1, AEF-7 (681 seats): PASS.** Seat log loss 0.2584 -> 0.2583 (-0.0001, SE 0.0001): not worse. 20 cells moved
  by more than 0.05 points (largest 0.13); their share squared error 423.8 -> 427.1 (+3.4, +1%, SE 0.9, 3 elections),
  outside the criterion (log loss decides clause 1) and recorded here.
- **Clause 2, the eight (689 seats): PASS.** Seat log loss 0.3540 -> 0.3478 (-0.0062, SE 0.0040): better by 1.55 SE.
  Share squared error on 425 moved cells -367.7 (-2%, SE 757, not clear on its own). wa2001 and vic2010 byte-identical
  (vic2010: no departed flags, see above). Per election, log loss change: fed2010 -0.0212, nsw2011 -0.0098, wa2005
  -0.0049, fed2007 -0.0008, wa2008 +0.0011, sa2010 +0.0013. Share error worse in 2 of 6 (sa2010 +55.5, wa2005 +431.4).
- **Clause 4: PASS.** Every `BF0m` departed value in the arm cache matches the amendment table, 15 of 15 elections.
- Clause 3 and the deciding numbers: the all-elections run, 6 Nov 2:00am, `deciding-runs/20261105-1252-departed-slope-pool-a1/`.
