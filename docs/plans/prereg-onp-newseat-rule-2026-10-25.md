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
