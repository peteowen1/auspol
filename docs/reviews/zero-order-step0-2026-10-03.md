# Zero-order prereg, STEP 0: baseline and sizing (read-only, 2026-10-03)

Plan: `docs/plans/prereg-zero-order-2026-10-03.md`. Nothing here ran a harness, rebuild,
forecast or R CMD check. Two light R scripts read CSVs under `output/snapshots/`
(scratchpad copies: `step0.R`, `step0c.R`). Every number below is from those files.

## Answer in three lines
1. **The v61 log-loss headline reproduces exactly (0.3434 -> 0.3413, 2,120 seat-elections,
   22 pairs). The v61 primary-RMSE headline does NOT reproduce exactly**: the best available
   "before" gives 1,311 seats, 3.961 -> 3.767, against the registered 1,313 seats,
   3.984 -> 3.774. Close, not equal. I did not move the seat definition to force a match.
2. **Both candidate baselines are the same model.** `20261003-0115-ca788a4-from6` and
   `20261003-0143-48f0233-from6` have byte-identical backtest CSVs (same set of file hashes),
   identical sharedetail by key, identical NZ1 log lines, identical per-pair log loss. They
   differ only in the git tag in the file names and in `shipped/` (0143 was promoted).
   Use 0143 (it is the dev HEAD merge); nothing downstream depends on the choice.
3. **The revival the plan sets out to fix is tiny in the backtests: 2 cells in 2 seats out of
   1,857 zeroed cells.** C1 cannot be powered (|A| = 2); it is direction-only by the plan's
   own rule, so C0 and the guards carry the decision. Details in 0b.

## 0a. Reproducing the v61 headline
The "22-election log loss" in v61 is the **unweighted mean of the 22 per-pair log losses**
(the `PB3 unweighted mean` line of `scripts/pool_backtests.R`; lower is better). The
seat-weighted pooled figure is a different number (0.3283 -> 0.3268). I could not run
`pool_backtests.R` against a snapshot: its input directory is hard-coded to `output/` and it
writes `output/pooled-backtest.csv`, which would touch the working tree. Recomputed from each
snapshot's win files instead (clamp 1e-6), and checked against each snapshot's own
`rebuild-forecasts-logs/s7_pool.log`: all three agree.

Log loss, before (v60) and after (v61), lower is better. n = seat-elections.
| quantity | v60 `20261002-2352-5027780-from6` | v61 0115 | v61 0143 | registered |
|---|---|---|---|---|
| pairs / seat-elections | 22 / 2,120 | 22 / 2,120 | 22 / 2,120 | 22 / - |
| unweighted mean of 22 pairs | 0.3434 | 0.3413 | 0.3413 | 0.3434 -> 0.3413: MATCH |
| seat-weighted pooled (n=2,120) | 0.3283 | 0.3268 | 0.3268 | not registered |
| worst single pair change | - | wa2017 +0.0025 | same | wa2017 +0.0025: MATCH |
| best two pair changes | - | wa2001 -0.0305, nsw2019 -0.0145 | same | same: MATCH |

Primary share RMSE over affected seats (percentage points of primary vote; lower is better).
"Zeroed cell" = a pair-seat-class cell with v60 pred_share > 0 and v61 pred_share == 0;
affected seat = a seat with at least one. Definition fixed before looking; the two variants
below it are sensitivities and are NOT substituted for it.
| definition | seats | cells | RMSE before | RMSE after |
|---|---|---|---|---|
| **registered (v61 prereg)** | 1,313 | not stated | 3.984 | 3.774 |
| **primary: zeroed cell, v60 vs v61 per-pair sharedetail** | **1,311** | 9,042 | **3.961** | **3.767** |
| same, mean of per-seat MSE then sqrt | 1,311 | 9,042 | 3.969 | 3.772 |
| sens: v60 cell with actual == 0 and pred > 0.5 | 1,064 | 7,311 | 3.989 | 3.728 |
| sens: v60 cell with actual == 0 and pred > 0 | 1,366 | 9,400 | 4.025 | 3.825 |

Reading it: the "after" matches to 0.007 and the seat count to 2; the "before" is 0.023
lower than registered. None of the 46 earlier full snapshots tried as "before" (all measured against the
0143 "after") gives exactly 3.984 / 1,313. The nearest "before" values are 3.9877
(`20261002-2149-c49ee12-from6`) and 3.9896 (`20261002-2201-c452887-from6`), both on 1,311
seats with after = 3.767; I did not pick those, because v60 is the registered "before" and
`...2352-5027780-from6` is the promoted v60 (its own MANIFEST gives 0.3434). The script that produced the registered
figures is still not in the repo. Verdict for the plan's Step 0 gate ("must reproduce 3.774
and 0.3413 to within the rounding shown"): **log loss passes; RMSE does not pass to the
rounding shown (3.767 vs 3.774)**. It is a re-statement that lands 0.007 away, so the gate
should be restated as "RMSE 3.767 on 1,311 seats is the early-arm baseline" rather than
carried over silently.

Clean-contrast check (supports using v60 per-pair files as "before"): of the 809 seats with no
zeroed cell, only 2 differ at all between v60 and v61 (Narracan vic2022 and Giles sa2022, the
two revived cells below). So v60 -> v61 changed nothing except the zeroing.

**Trap found: `pooled-sharedetail.csv` is the wrong file for this.** In every `from6`
snapshot (and `output/`) it is the stage-2 xgb-off training pool, md5 `d8d536b1...`, written
2026-10-01 23:38 and copied unchanged into the v60 and v61 `shipped/` folders. It does not equal
the per-pair `backtest-*-sharedetail-*.csv` files (the scored stage-6 output, 14,487 rows in
both). The plan's 0a and the compare step must read the per-pair files. Using the pooled file
as "before" gives a spurious 1,433 seats and 4.248 -> 3.796 (my first, wrong, attempt).

## 0b. Zeroed cells per pair, and what was revived
Source for "zeroed" is the NZ1 line in `s6_*.log` (identical in 0115 and 0143). "Zero at
final" is derived from sharedetail (v60 > 0, v61 == 0). Cells are pair-seat-class cells;
points are percentage points of share summed over the zeroed cells.
| pair | NZ1 zeroed | pts | zero at final | revived (NZ1 minus final) | ghost cells left in final | seats with a zeroed cell | seats in pair |
|---|---|---|---|---|---|---|---|
| fed2007 | 217 | 179.8 | 217 | 0 | 0 | 134 | 149 |
| fed2010 | 325 | 297.7 | 325 | 0 | 0 | 147 | 150 |
| fed2013 | 139 | 226.5 | 139 | 0 | 0 | 107 | 150 |
| fed2016 | 131 | 266.5 | 131 | 0 | 0 | 101 | 150 |
| fed2019 | 200 | 278.5 | 200 | 0 | 0 | 135 | 151 |
| fed2022 | 100 | 80.1 | 100 | 0 | 0 | 89 | 151 |
| fed2025 | 106 | 226.8 | 106 | 0 | 0 | 90 | 150 |
| nsw2019 | 51 | 73.2 | 51 | 0 | 0 | 47 | 93 |
| nsw2023 | 137 | 112.7 | 137 | 0 | 0 | 91 | 93 |
| qld2020 | 63 | 41.1 | 63 | 0 | 0 | 51 | 93 |
| qld2024 | 56 | 46.9 | 56 | 0 | 0 | 48 | 93 |
| sa2022 | 35 | 51.1 | 34 | **1** | 1 (Giles IND 0.43) | 27 | 47 |
| sa2026 | 6 | 7.2 | 6 | 0 | 0 | 6 | 47 |
| vic2014 | 67 | 85.1 | 67 | 0 | 0 | 60 | 88 |
| vic2018 | 66 | 95.5 | 66 | 0 | 0 | 51 | 88 |
| vic2022 | 1 | 32.3 | 0 | **1** | 1 (Narracan ALP 0.65) | 0 | 88 |
| wa2001 | 62 | 108.3 | 62 | 0 | 0 | 47 | 57 |
| wa2005 | 1 | 0.0 | 1 | 0 | 27 (OTH, absent class) | 1 | 46 |
| wa2008 | 7 | 39.7 | 7 | 0 | 30 (ONP, absent class) | 6 | 59 |
| wa2013 | 9 | 10.7 | 9 | 0 | 0 | 9 | 59 |
| wa2017 | 37 | 230.9 | 37 | 0 | 0 | 35 | 59 |
| wa2025 | 41 | 119.6 | 41 | 0 | 0 | 29 | 59 |
| **total** | **1,857** | | **1,855** | **2** | 59 | **1,311** | 2,120 |

(Percentage of zeroed cells revived: 2 of 1,857 = 0.1%. Seats containing a zeroed cell:
1,311 of 2,120 = 61.8%. The 1,857 here is the cells at the zero call; the v59 figure "2,125
above 0.5%" in the prereg used a different definition and is not comparable.)

The 59 ghost cells (actual_share == 0 and pred_share > 0) in the v61 final output split as:
57 are the "classes absent from the result table, untouched by design" cells that NZ1 itself
logs (wa2005 OTH 27 cells, wa2008 ONP 30 cells), and 2 are revivals:
- **Narracan vic2022 ALP: 33.37 (v60) -> 0.645 in v61.** NZ1 zeroed 32.3 points there and a
  later step put 0.645 back. Positive control D1 is valid: the `early` arm has ALP > 0.
- **Giles sa2022 IND: 2.03 (v60) -> 0.426 in v61** (35 zeroed at NZ1, 34 zero at final).
  A second, unlisted revival; the plan's D1 fallback ("first ghost cell in the early arm") is
  this cell.

What this settles from the plan's UNCONFIRMED list (derived from final sharedetail, not from
a pre-zero dump, so it shows revivals that survive to the output):
- Federal: 0 ghost cells in all 7 pairs, so no salience-blend revival is visible.
- wa: 0 ghost cells besides the two by-design absent classes.
- vic/nsw/qld/sa: the port, demographic and leader steps revived only 2 cells. The reason is
  that the port moves only ALP and LNP and those almost never have zeroed cells (Narracan is
  the one case). The table in the plan labelled these harnesses "YES"; the data says "yes in
  principle, 2 cells in practice".
- D3 (nothing can be revived, arms must be byte-identical): 20 of 22 pairs qualify. Only
  vic2022 and sa2022 can differ between arms. wa2005 and wa2008 keep 57 absent-class ghost
  cells in both arms by design; do not read them as C0 failures.

## MDE blanks
Per-seat difference d_i = v61 minus v60 mean squared share error (squared percentage points,
mean over the seat's classes), and per-seat log-loss difference. Proxy = the v60 -> v61
contrast, as the plan specified. SE clustered on seat-election (one row per seat). Election
clustering (22 clusters) not computed here.
| quantity | value |
|---|---|
| \|A\| (zeroed cells later revived), cells | **2** (Narracan vic2022 ALP, Giles sa2022 IND) |
| \|A\| seats | **2** |
| proxy sd(d), MSE units, over the 1,311 zeroed seats | 11.449 |
| proxy sd(d), log-loss units, same seats | 0.0489 |
| mean d over the 1,311 seats (v61's whole effect, per seat) | -1.527 MSE; -0.0014 log loss |
| SE for \|A\| = 2 using the proxy sd | 11.449 / sqrt(2) = 8.10 |
| MDE (2.8 x SE), MSE units, \|A\| = 2 | 22.7 |
| for comparison: MDE over all 1,311 seats | 0.885 MSE; 0.0038 log loss |
| plausible effect on A, upper bound (revived share 0.65 and 0.43 points, over ~7 classes) | about 0.06 MSE per seat |

Reading it: MDE (22.7) is about 400 times the plausible effect (0.06), so **C1 is direction
only, by the plan's own rule**, and no run can change that: detecting 0.06 at this sd needs
about (2.8 x 11.449 / 0.06)^2 = 285,000 seats. The proxy sd overstates the real sd of the
late-minus-early contrast (it includes v61's large zeroing effect, whereas late vs early
changes at most 2 cells), so the true MDE is smaller, but it would have to be below 0.06 to
help and sd(d) for 2 seats cannot be estimated. **Unfillable honestly:** the sd of the
late-minus-early difference does not exist before the run. Consequence for the decision rule:
ship-or-not rests on C0 (zero ghost cells outside the 57 by-design ones), C4, R1-R7 and the
guards. The guards are also nearly unfalsifiable: with 2 changed seats the pooled log-loss
change can only come from those seats plus simulation noise from the statewide anchoring
(the plan already warns about this under D2), so C2/C3 "pass" mostly tests that nothing else
broke.

Also worth Pete's attention: late-order is a **correctness and live-path-parity change, not
an accuracy change**, on the 22-pair evidence. It is still the right thing to do (the
published script already does it, PR #89), but it should not be described as improving the
backtest.

## What I could not confirm
- The registered 3.984 / 1,313: no script and no snapshot reproduces it exactly (best 3.961 /
  1,311 for "before"; 3.767 / 1,311 for "after" vs 3.774).
- Which revival step fired for Narracan and Giles. Needs a pre-zero dump or a trace; the final
  files only show that something after the zero call put share back. Not run (no model runs).
- Whether other revivals exist that left no ghost footprint, for example a revived share in a
  cell whose class also appears in the result table. By the zeroing rule those classes did not
  qualify for zeroing, so I expect none, but the check used final shares only.
- Whether `pool_backtests.R` could run read-only against a snapshot: it cannot as written
  (hard-coded `output/`, writes `output/pooled-backtest.csv`); I did not modify it.
- Election-clustered SE and per-pair R4 (port SP2 shape) inputs: not derivable from existing
  files here.
