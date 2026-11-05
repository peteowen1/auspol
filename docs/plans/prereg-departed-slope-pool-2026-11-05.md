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
