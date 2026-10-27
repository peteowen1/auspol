# Pre-registration: One Nation in seats with no state history, the live method in every harness (`AUSPOL_ONP_NEWSEAT_RULE`)

Written 2026-10-25, before any harness or quick_arm run of the switch. Audit and findings:
`docs/reviews/onp-newseat-parity-2026-10-25.md`. Code: `R/onp_newseat.R`.

## Why

The live Victorian forecast allocates One Nation across every seat by rank on the earlier federal One
Nation vote with a fitted spread. The harnesses give every seat where One Nation did not stand last time
the same share (a uniform swing off zero), and three elections (nsw2019, sa2022, vic2022) give it 0
everywhere. Only SA (BS1c) tests anything like the live method. So the backtests score a different One
Nation model from the one that ships, and the House-v-Senate ordering question
(`prereg-onp-senate-rank-2026-10-25.md`) cannot be screened on the elections where it matters.

**What this decides.** The switch changes the BACKTESTS only: the live forecast already does this in every
seat, and is byte-identical at both values (review doc, "What was built"). Shipping "1" makes the
backtest score the method Victoria uses. Arm B against arm A is the evidence for the live ordering
(`AUSPOL_ONP_ORDER`), which is a separate decision recorded in the senate-rank pre-registration.

## The rule (as built, not to be changed after the first run)

In each harness, over seats where One Nation had NO vote in the previous-election matrix, stands at the
target (nomination data, the same proxy as the harness's nomination zeroing) and has a positive share
after the swing:

- keep the mean of those seats' current One Nation shares;
- rank them on the federal One Nation vote of the most recent federal election dated strictly before the
  target (`onp_federal_key()`): House (`AUSPOL_ONP_ORDER=federal`) from
  `external/elections/federal-transposed-to-state.csv`, else `output/house-onp-by-district.csv`; Senate
  (`senate_rank`) from `output/senate-onp-by-district.csv` / `senate-by-district-class.csv`, and for a
  federal target the previous federal Senate share by division. A House share of 0 (no federal One Nation
  candidate) is no information. A table dated on or after the target is an error;
- spread by normal quantiles to the CV `a * level^(k - 1)` of `SD = a * level^k`, fitted on every earlier
  election in `output/candidacies.csv` where One Nation contested 10+ seats (mean and SD over contested
  seats), `k` pooled toward 0.5 with weight `df/(df+3)` (`onp_newseat_cv()`). Never fitted on the target;
- rows renormalised as each harness already does (NSW: the other classes give way in proportion).

Seats with history keep their own path (SA: BS1c's House-ranked spread, then the rule on the no-history
seats). Applicability, fixed now: at least 3 such seats and at most 10% without a key, else `ONN1!` and
the election is untouched. When One Nation has no column (nsw2019, sa2022, vic2022) one is added at zero
with a previous level of 0, so the swing gives those seats the statewide level before the rule spreads it.
Under the rule the `senate_rank` re-rank of every contested seat (`ONR1`) is skipped, so B differs from A
in the no-history ordering only.

Where each arm can apply (review doc table): **A (House)**: vic2022, nsw2023, sa2026, qld2020. **B
(Senate)**: fed2007, fed2013, fed2016, fed2019, fed2022, vic2022, nsw2019, nsw2023, sa2022, sa2026,
qld2017, qld2020, qld2024, wa2005, wa2017, wa2025. Neither: fed2010, fed2025, qld2012, qld2015, wa2001,
wa2021 (reasons in the review doc).

## Target seats, fixed by rule before scoring

`docs/plans/onp-newseat-target-seats-2026-10-25.csv` (`scripts/onp_newseat_targets.R`): every seat where One
Nation stood at the target (`candidacies.csv`, pcv > 0) and had no candidate at the previous election of
that jurisdiction, by normalised seat name. **474 seat-elections, 22 elections; 465 scorable** (9 renamed
wa2005 seats are not in that harness's output).

| election | fed2007 | fed2010 | fed2013 | fed2016 | fed2019 | fed2022 | fed2025 | vic2022 | nsw2019 | nsw2023 | sa2022 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| target seats | 3 | 8 | 11 | 12 | 46 | 91 | 2 | 4 | 12 | 11 | 19 |

| election | sa2026 | qld2012 | qld2015 | qld2017 | qld2020 | qld2024 | wa2001 | wa2005 | wa2017 | wa2021 | wa2025 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| target seats | 29 | 6 | 10 | 53 | 30 | 3 | 54 | 10 | 35 | 13 | 12 |

The list is the scoring set for every arm, including elections where an arm does not apply (there the arm
equals the baseline and contributes zero difference, which is the honest weight of an arm that cannot act).

## Step 0 (in the main checkout, after merge; not done here)

```
powershell.exe -Command 'Rscript scripts/build_onp_house.R'
powershell.exe -Command 'Rscript scripts/build_data_registry.R'
```

The first writes `output/house-onp-by-district.csv`, which quick_arm copies into its slots; without it arm A
cannot reach Queensland and prints `ONN1!` there. Built to the scratchpad for this file: 916 rows, 11
elections, anchor r >= 0.9997 against the transposed file.

## Arms and exact commands

Pairs: every election with target seats (this includes all of AEF-7):

```
P=fed2007,fed2010,fed2013,fed2016,fed2019,fed2022,fed2025,vic2022,nsw2019,nsw2023,sa2022,sa2026,qld2012,qld2015,qld2017,qld2020,qld2024,wa2001,wa2005,wa2017,wa2021,wa2025
```

- **A** (House ordering): `Rscript scripts/quick_arm.R "AUSPOL_ONP_NEWSEAT_RULE=1" --pairs=$P`
- **B** (Senate ordering): `Rscript scripts/quick_arm.R "AUSPOL_ONP_NEWSEAT_RULE=1 AUSPOL_ONP_ORDER=senate_rank" --pairs=$P`
- **B v A** (the Senate question): `Rscript scripts/quick_arm.R "AUSPOL_ONP_ORDER=senate_rank" --base="AUSPOL_ONP_NEWSEAT_RULE=1" --pairs=$P`
- Guard, each of A and B: the same command with `--pairs=all`.
- Primary metric for each: `Rscript scripts/score_onp_newseat.R <baseline key> <arm key>` with the two cache
  keys quick_arm prints ("baseline cache ..." / "arm cache ...").

All at quick_arm's default 1,000 simulations. The deciding run (`scripts/deciding_run.ps1 -Arm "<arm>"
-Label onp-newseat-<A|B>`, 20,000 sims, all elections) only for an arm that passes.

### Dry run, BEFORE reading any metric

1. `score_onp_newseat.R K K` (same key twice) prints +0.0000 everywhere. Checked while writing this file on
   an existing cache: 465 of 474 seats, all differences exactly 0.
2. Every election outside the list (vic2010/2014/2018, nsw2011/2015, sa2010/2014/2018, wa2008/2013,
   nt2016/2020/2024) scores exactly 0 in the `--pairs=all` guard runs. A non-zero one means the switch leaks.
3. Each listed election prints one `ONN1` line; it is `ONN1!` exactly where the applicability list above says
   the arm cannot act (a mismatch is a wiring or data fault: stop and trace). nsw2019, sa2022 and vic2022
   also print the "ONP column added" line.
4. Under B, every SA/Qld/NSW/WA run prints "ONR1  skipped".
5. For A, the elections where it does not apply are byte-identical to the baseline (quick_arm's
   per-election "max diff 0"), EXCEPT nsw2019 and sa2022: there the One Nation column is added and the
   House key then refuses, so those two rows measure the column fix alone (uniform statewide level in the
   seats One Nation contests). That is the split clause 4(c) needs.

### Criteria (SE clustered on election throughout)

1. **Primary**: target-seat seat log loss (`SNS3`), arm minus baseline, falls by more than 1 SE.
   Co-primary, must hold too: target-seat One Nation squared error (`SNS3`, reported with both RMSEs) does
   not rise by more than 1 SE. Noise scale for reference: an unrelated pair of cached runs scored -0.0033
   (SE 0.0022) on these 465 seats, so an effect under ~0.004 cannot be resolved here.
2. **Guard**: all-elections seat log loss (`--pairs=all`) not worse by more than 1 SE, and no election worse
   by more than 2 SE of its own paired seat differences.
3. **Leave-one-election-out** (`SNS5`): the primary keeps its sign with each election dropped. No refusal
   because one election carries most of the gain.
4. **Unacceptable win, named now**: (a) the primary passes but sa2026 or qld2020 all-seat log loss rises by
   more than 1 SE; (b) any seat One Nation won loses more than 0.10 of its One Nation win probability; (c)
   the gain comes from the three no-column elections alone (nsw2019, sa2022, vic2022) while the
   uniform-to-ranked elections are worse: that would be the column fix, not the rule, and the two get
   separated before anything ships.
5. **Reported, not decisive**: AEF-7 ledger subset (quick_arm prints it), Brier, base_pred One Nation RMSE
   (`AUSPOL_XGB_PRIMARY=0` run of the same arm, for the elections whose One Nation cells the xgb file
   covers: fed2010-2025, nsw2023, qld2012-2024, sa2026, wa2021, wa2025), per-election tables (`SNS2`).

**B v A** (the Senate question), on the elections where both apply (vic2022, nsw2023, sa2026, qld2020) and
separately on all listed elections: the B-v-A command's `SNS3` target-seat log loss, same 1 SE rule. B-only
elections measure "Senate rule v nothing", not House v Senate, and are reported apart.

Ship rule for the switch: criterion 1 passes, 2-3 hold, 4 does not fire, then the deciding run. A clause
refusing an otherwise-passing result goes to Pete with the split shown. Shipping "1" does not change the
Victorian forecast; the ordering for Victoria is decided under the senate-rank pre-registration, with B v A
as its harness evidence.

## RESULT, arm A (2026-10-25 screen; appended, nothing above edited)

`quick_arm.R "AUSPOL_ONP_NEWSEAT_RULE=1" --pairs=<the 22 listed> --no-reuse --slots=1` ran 19:15-20:04 at 1,000
sims, code 58e6740 (launched with 8,273 MB available). Baseline cache 050d4221173d, arm cache 8190e146012a. Log
`deciding-runs/quickarm-20261025-onp-newseat-A.log`, score `...-A-score.txt`.

Dry runs: (1) `score_onp_newseat.R` on the same key twice gives +0.0000. (3) The `ONN1` lines match the applicability
list. The rule allocated in vic2022, nsw2023, sa2026 and qld2020. nsw2019 and sa2022 added the column, then the House
key refused (11 of 12 and 15 of 19 seats have no key), so those two measure the column fix alone. Every other election
printed `ONN1!` or "needs 3". (5) Changed cells: 456 of 15,003, in exactly those 6 elections.

| measure (arm minus baseline, lower is better; SE clustered on election) | n | change | SE |
|---|--:|--:|--:|
| 1. primary, target-seat log loss (SNS3) | 465 seats / 22 el. | **+0.0007** | 0.0004 |
| 1. co-primary, target-seat One Nation squared error (RMSE 5.629 -> 5.540) | 465 | -0.990 | 0.739 |
| 2. guard over the 22 listed elections (SNS4) | 2,156 seats | +0.0002 | 0.0001 |
| AEF-7 (reported) | 681 | +0.0004 | 0.0003 |

Leave-one-election-out on the primary ranges from +0.0005 to +0.0009 and is positive in every drop. All-seat change per
election: sa2022 +0.0047 (own SE 0.0049), vic2022 +0.0020 (0.0041), sa2026 +0.0015 (0.0013), qld2020 0.0000, nsw2023
0.0000, nsw2019 -0.0004. Clause 4a would fire (sa2026 more than 1 SE worse). Clause 4b does not fire: no One Nation
winner moves by more than 0.001.

**Verdict: REFUSED.** The primary is worse by more than 1 SE, not better. The One Nation shares themselves improve, but
seat log loss on the target seats gets slightly worse. The `--pairs=all` guard for A was not run: WORSE stops.

## RESULT, arm B (2026-10-25 screen; appended)

`quick_arm.R "AUSPOL_ONP_NEWSEAT_RULE=1 AUSPOL_ONP_ORDER=senate_rank" --pairs=<the 22 listed> --no-reuse --slots=1`
ran 20:04-20:30, 1,000 sims, code 58e6740, against the same baseline 050d4221173d. Arm cache d8938e03307e. Log
`deciding-runs/quickarm-20261025-onp-newseat-B.log`, score `...-B-score.txt`. Changed cells: 1,373 of 15,003, in 15
of 22 elections.

| measure (arm minus baseline, lower is better; SE clustered on election) | n | change | SE |
|---|--:|--:|--:|
| 1. primary, target-seat log loss (SNS3) | 465 seats / 22 el. | -0.0088 | 0.0090 |
| 1. co-primary, target-seat One Nation squared error (RMSE 5.629 -> 5.212) | 465 | -4.525 | 2.270 |
| 2. guard over the 22 listed elections (SNS4) | 2,156 seats | -0.0018 | 0.0020 |
| AEF-7 (reported) | 681 | +0.0005 | 0.0004 |

- Clause 1: the primary is within 1 SE, so it is NOT passed. The co-primary holds (One Nation share error is better by
  about 2 SE).
- Clause 3, leave-one-election-out: FAILS. Without qld2017 the primary is +0.0006 (SE 0.0007). Every other drop stays
  between -0.0111 and -0.0088. The whole log-loss gain is qld2017, which moves -0.0465 (own SE 0.0422) on all seats and
  0.560 -> 0.478 on its 53 targets.
- Clause 4a fires: sa2026 all-seat log loss is +0.0036 (own SE 0.0019, 1.9 SE). qld2024 is 0.0000.
- Clause 4b does not fire: no One Nation winner loses (Ngadjuri 0.887, Mirani qld2020 0.624).
- Per election, all seats: qld2017 -0.0465, fed2019 -0.0011, wa2017 -0.0007, wa2025 -0.0004, nsw2019 -0.0003;
  sa2022 +0.0046, sa2026 +0.0036, vic2022 +0.0020, fed2022 +0.0004. Every other election is 0.

**Verdict: NOT PASSED.** The primary is within 1 SE, the leave-one-out sign is lost without qld2017, and clause 4a
fires on sa2026. It goes to Pete with this split, because the One Nation shares improve clearly while seat log loss
does not. Arm B's `--pairs=all` guard and the B-v-A run are next in the queue.

## RESULT, B v A (the Senate question; 2026-10-25, appended)

`quick_arm.R "AUSPOL_ONP_ORDER=senate_rank" --base="AUSPOL_ONP_NEWSEAT_RULE=1" --pairs=<22>`. Both caches were already
built (base 8190e146012a = arm A, arm d8938e03307e = arm B), so no harness was re-run. Score in
`deciding-runs/quickarm-20261025-onp-newseat-BvA-score.txt`.

| scope (Senate minus House ordering, lower is better; SE clustered on election) | n | target-seat log loss | One Nation squared error |
|---|--:|--:|--:|
| all 22 listed elections | 465 seats | -0.0095 (SE 0.0089) | -3.535 (SE 2.216); RMSE 5.540 -> 5.212 |
| without qld2017 (SNS5) | | -0.0002 (SE 0.0005) | |
| where both rules apply (vic2022, nsw2023, sa2026, qld2020) | 74 seats / 4 el. | **+0.0012 (SE 0.0012)** | -0.193 (SE 0.112) |
| guard, all seats of the 22 | 2,156 | -0.0020 (SE 0.0020) | |
| AEF-7 (quick_arm Q4) | 681 | +0.0002 (SE 0.0002) | |

Reading: no measurable House-v-Senate difference on log loss on the elections where both rules apply (+0.0012, within
1 SE, pointing toward House), though One Nation shares are slightly better there under the Senate ordering (-0.193,
1.7 SE). The all-22 figure is qld2017 alone, and qld2017 is a B-only election, which measures "Senate rule v nothing",
not House v Senate.

## RESULT, arm B `--pairs=all` guard (2026-10-25 20:56-21:24; appended)

`deciding-runs/quickarm-20261025-onp-newseat-B-all.log`, baseline 050d4221173d (now 35 elections), arm d8938e03307e.
Dry run 2 passes: 15 of 35 elections changed, the same 15 as on the listed run, and every election outside the list
scores exactly 0. Seat-winner log loss over all 2,931 seats in 35 elections: 0.3085 -> 0.3071, **-0.0014 (SE
0.0015)**, within 1 SE, so the guard holds. The worst single election is sa2026 at 1.89 of its own SE, under the 2 SE
bar. AEF-7 is +0.0005 (SE 0.0004). This leaves arm B's verdict unchanged: NOT PASSED on the primary and on clause 3
(qld2017 carries the whole gain), and clause 4a fires. Pete has the split.

## SHIPPED (2026-10-26; appended, nothing above edited)

Arm B shipped in 38d96a5: `AUSPOL_ONP_NEWSEAT_RULE=1` with `AUSPOL_ONP_ORDER=senate_rank`, on Pete's rule "Wait for B-v-A,
then ship" (ship if B v A is not worse by more than 1 SE: it was -0.0095, SE 0.0089). This is **Pete's override** of
clause 3 (leave-one-out: qld2017 carries the gain) and of clause 4a (sa2026 +1.89 SE), recorded here as such. Both
switches are post-xgb: stage 1 of `rebuild_forecasts.sh` pins them to `0` / `federal`. Bendigo East's 0.69 was traced
before shipping and found not a defect of the rule (`docs/reviews/bendigo-east-onp-2026-10-25.md`). A fitted Senate /
House / previous-state blend tied with Senate alone and was not built (`docs/DECISIONS.md`, 2026-10-26).
