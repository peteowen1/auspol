# One Nation in seats with no state history: live v harness parity (2026-10-25)

Asked by Pete, 2026-10-25: the live forecast allocates One Nation's statewide share across Victorian seats
by rank on the federal House One Nation vote (Senate under `AUSPOL_ONP_ORDER=senate_rank`), but the
backtests mostly start each seat from One Nation's previous STATE result, and only SA (BS1c) uses a
federal-rank rule. So the method Victoria 2026 depends on is barely tested. The method has to apply to
every election.

Status: the audit below is of the code at `origin/dev` 1399813 plus this commit. The parity switch is
BUILT and OFF (`AUSPOL_ONP_NEWSEAT_RULE="0"`); nothing has been run through a harness. Pre-registration:
`docs/plans/prereg-onp-newseat-rule-2026-10-25.md`.

## Audit: how each harness forms One Nation's seat shares

Line numbers are of this commit. "Swing" is `dev_slope(x, level_prev, level_now, slope)` =
`max(0, level_now + slope * (x - level_prev))` (`R/dev_slope.R:45`), `x` the seat's own (or the
candidate's personal, `own_prev_substitute()`) previous share.

| Entry point | Seat matrix built from | (a) seat where One Nation stood last time | (b) seat where it did not (column exists) | (c) One Nation absent from the previous election entirely | One Nation-specific step | Elections with little or no prior presence |
|---|---|---|---|---|---|---|
| `fit_seats_full.R` (live vic2026) | n/a: One Nation has no swing path | n/a | **every seat**: rank on the federal House vote (`:773`, Senate under `senate_rank` `:782`), SA 2026 sorted ratios by quantile (`onp_rank_ratio()` `:801`), forced to CV 0.365 (`onp_cv_force()` `:852`), times the statewide level, cap 80 (`:1348-1349`), other classes fill in proportion | same (vic2022: 4 seats, 0.28%) | the whole allocation is One Nation-specific | vic2026: 79 One Nation candidacies in `output/candidacies.csv` |
| `backtest_candidate_sa.R` | previous result only (`dcast(fa)` `:474`) | swing from own share (`:725-731`) | swing from 0: `level_now - slope * level_prev`, the SAME number in every such seat | **no ONP column, so One Nation is predicted 0 everywhere** | BS1c (`AUSPOL_ONP_CONC_SD=auto`, shipped): re-allocates ALL seats, history or not, by House rank, normal quantiles, SD from the leave-one-out curve (`:845-918`); skipped when the House file lacks seats | sa2022 (prev sa2018, One Nation absent): **0 in all 19 seats it contested** (published mean 0.00 v actual 2.66 over 47 seats); BS1c skipped (House file has 5 of 47). sa2026: 28 seats from zero, then BS1c on all 47 |
| `backtest_candidate_qld.R` | previous result only (`:438`) | swing (`:687-693`) | swing from 0, uniform | never happens (One Nation stood in every previous Qld election in the corpus) | none: "concentration arm deliberately not ported" (`:750`) | qld2017 (prev qld2015, 11 seats): 53 target seats all get the same share; qld2012/qld2015 (2 and 6 previous seats) likewise |
| `backtest_candidate_nsw.R` | previous result only (`:430`) | swing (`:739-757`) | swing from 0, uniform | **no ONP column: 0 everywhere** | none | nsw2019 (prev nsw2015, absent): **0 in all 12 seats it contested** (published 0.00 v actual 1.05 statewide, 8.1 where it stood); nsw2023: 11 target seats uniform |
| `backtest_candidate_wa.R` | union of previous and target classes (`:350`) | swing (`:569-581`) | swing from 0, uniform | column exists at zero, swing gives the statewide level everywhere (uniform) | none | wa2001 (One Nation's first WA election, 54 seats) and wa2017 (prev wa2013, absent, 35 seats): every seat the same share (published 4.66 and 4.30 everywhere) |
| `backtest_candidate_vic.R` | previous result only (`:411`) | swing (`:654-660`) | swing from 0, uniform | **no ONP column: 0 everywhere** | none | vic2022 (prev vic2018, absent): **0 in the 4 seats it contested**; vic2010-2018: absent both times |
| `backtest_candidate_fed.R` | previous result only (`:709`) | swing (forecast mode `:1436-1453`) | swing from 0 at the national level, uniform | never happens (One Nation stood federally every time since 1998) | minor-party poll adjustment (`AUSPOL_MINOR_POLL_ADJ`, off) | fed2019 (46 target divisions), fed2022 (91): uniform |
| `backtest_candidate_nt.R` | union (`:385`) | n/a | n/a | One Nation has stood in no NT election in the corpus | none | none |

The xgb layer (`xgb_primary_override()`, all harnesses) replaces a cell only where the as-at prediction file
has a row; it has One Nation rows for fed2010-fed2025, nsw2023, qld2012-qld2024, sa2010, sa2026, wa2021,
wa2025, and **none** for fed2007, nsw2019, sa2022, vic2022, wa2001, wa2005, wa2017. In those seven the
base share is what reaches the simulation. (Read from `output/xgb-primary-asat-predictions.csv` in the main
checkout; not investigated why the rows are missing.)

## Findings

1. **Three elections predict One Nation at 0 in every seat it contested** (nsw2019, sa2022, vic2022),
   because the harness builds its classes from the previous result and One Nation did not stand then.
   Still live at the published default. 35 contested seats in total. Under the new switch the column is
   added (`onp_newseat_prepare()`); at "0" nothing changes.
2. **Outside SA 2026, every seat with no One Nation history gets the same One Nation share**, a uniform
   swing off zero. That is the opposite of the live method, which spends all its information on the
   between-seat spread. 474 seat-elections fit "contested now, no candidate last time" (list below).
3. **The live ordering key has thin coverage outside Victoria.** `federal-transposed-to-state.csv` (the
   live source) covers nsw, sa and vic only. `scripts/build_onp_house.R` (new) rebuilds the House key
   from the AEC booth files for qld2017/2020/2024 too, matching the transposed file at r 0.9997-1.0000 where
   both exist. WA has no House booth vote files on disk at all. And where One Nation did not stand
   federally in a division the House key carries no ordering information: qld2017's 2016 House vote
   covers 37 of 53 target seats, nsw2019's 1 of 12, sa2022's 4 of 19. The Senate key covers every target
   seat in every state election that has a Senate table (all but qld2012, qld2015, wa2021).
4. **Anchor check on the spread.** The time-forward contested-seat curve (`onp_newseat_cv()`, fitted only
   on earlier elections) gives CV 0.363 for sa2026's 29 target seats. The live forecast's pooled CV is
   0.365. Independent routes, same number.
5. **The rule does not fix the level.** It keeps the mean the harness already gives the no-history seats.
   In nsw2019 that mean is the statewide level (1.1%) spread over seats where One Nation polled 8.1% on
   average where it stood; the rule cannot repair that. The level question is `AUSPOL_CONTEST_BASE`
   (xgb layer, needs a retrain), a separate arm.
6. **wa2001 cannot get the rule**: no earlier election has a contested One Nation spread to fit on, and
   the CV is not borrowed from a later one. wa2021 has no Senate table (fed2019 WA is missing from
   `output/senate-by-district-class.csv`). Both print `ONN1!`.
7. **A federal target has no House key by construction**: the previous House vote in a division is that
   division's own history. Only the Senate arm reaches fed pairs (previous federal Senate share by
   division, `output/senate-by-division-class.csv`).

### Allocation-only check (exploratory, not a criterion)

`onp_newseat_apply()` on real keys and real time-forward CVs, given each election's TRUE mean over its
target seats so only the geography is scored (the same design as `onp_order_loo.R`). RMSE in points of
One Nation share over the target seats, lower is better; "uniform" is what the harnesses do now (with the
true mean); Spearman of the rule's allocation with the actual shares, higher is better. Rows only where
the rule applies. Script: scratch only (`alloc_check.R`, not committed), inputs from the main checkout.

| election | key | n | uniform RMSE | rule RMSE | Spearman |
|---|---|---:|---:|---:|---:|
| fed2007 | Senate | 3 | 0.11 | 0.39 | -0.50 |
| fed2013 | Senate | 11 | 0.77 | 1.22 | -0.35 |
| fed2016 | Senate | 12 | 4.83 | 6.97 | 0.10 |
| fed2019 | Senate | 46 | 3.94 | 2.35 | 0.86 |
| fed2022 | Senate | 91 | 2.12 | 1.21 | 0.85 |
| vic2022 | House / Senate | 4 | 1.21 | 0.98 | 0.80 |
| nsw2019 | Senate | 12 | 2.55 | 2.09 | 0.85 |
| nsw2023 | House / Senate | 11 | 3.31 | 1.35 | 0.96 |
| sa2022 | Senate | 19 | 2.25 | 2.35 | 0.65 |
| sa2026 | House | 29 | 6.90 | 2.38 | 0.95 |
| sa2026 | Senate | 29 | 6.90 | 2.16 | 0.96 |
| qld2017 | Senate | 53 | 5.63 | 4.31 | 0.76 |
| qld2020 | House | 30 | 3.01 | 1.80 | 0.91 |
| qld2020 | Senate | 30 | 3.01 | 1.75 | 0.92 |
| qld2024 | Senate | 3 | 4.24 | 2.21 | 0.50 |
| wa2005 | Senate | 10 | 0.99 | 1.37 | 0.61 |
| wa2017 | Senate | 35 | 2.44 | 2.20 | 0.82 |
| wa2025 | Senate | 12 | 2.11 | 1.63 | 0.73 |

The rule is better than uniform in 13 of 18 rows and worse in five: fed2007, fed2013 and fed2016 (One
Nation's federal Senate vote before 2016 was a point or two, so the key is mostly noise), wa2005 (its CV
is fitted on two elections, 0.72) and sa2022 (2.35 against 2.25). This says the ordering carries real information where One Nation is a
real force; it says nothing yet about seat log loss after the xgb layer and the simulation, which is
what the pre-registration measures.

## What was built

- `R/onp_newseat.R`: `onp_newseat_rule()`, `onp_rank_ratio()` and `onp_cv_force()` (the live allocation's
  two steps, moved out of `fit_seats_full.R` verbatim), `onp_federal_key()` (House or Senate, time-forward
  guard), `onp_newseat_cv()` (time-forward spread), `onp_newseat_prepare()`, `onp_newseat_apply()`.
- All seven harnesses call it where their no-history seats are formed (after the swing and re-entry,
  before renormalisation; SA after BS1c; NSW after its renormalisation with `refill = "prop"`). Under the
  rule `senate_rank`'s re-rank of every contested seat (`ONR1`) is skipped, so arm B differs from arm A in
  the no-history ordering alone.
- `fit_seats_full.R` calls `onp_rank_ratio()` / `onp_cv_force()` at every setting. **Live output is
  byte-identical at the published default and at "1"**: the two functions are the old inline loop and
  expression character for character (a test runs both on 88 random seats and compares with
  `identical()`), the only new live line is an `ONN1` print, and the switch value is only printed there,
  never branched on.
- `scripts/build_onp_house.R` (House key for qld), `scripts/onp_newseat_targets.R` (target seats and
  per-arm applicability), `scripts/score_onp_newseat.R` (primary metric from two quick_arm cache keys;
  run with the same key twice it prints exactly +0.0000).

## Target seats (fixed by rule, `docs/plans/onp-newseat-target-seats-2026-10-25.csv`)

Seats where One Nation stood at the target and had no candidate at the previous election, by normalised
seat name. 474 seat-elections over 22 elections; 9 wa2005 seats are renamed seats the harness does not
score (`SNS1!` lists them), so 465 are scorable.

| election | target seats | of which name absent last time | House key coverage | Senate key coverage | time-forward CV |
|---|---:|---:|---:|---:|---:|
| fed2007 | 3 | 0 | none (federal) | 1.00 | 1.012 |
| fed2010 | 8 | 0 | none | 0.88 | 0.532 |
| fed2013 | 11 | 0 | none | 1.00 | 0.541 |
| fed2016 | 12 | 0 | none | 1.00 | 0.455 |
| fed2019 | 46 | 2 | none | 0.96 | 0.405 |
| fed2022 | 91 | 1 | none | 0.93 | 0.459 |
| fed2025 | 2 | 1 | none | 0.50 | 0.413 |
| vic2022 | 4 | 1 | 1.00 | 1.00 | 0.455 |
| nsw2019 | 12 | 0 | 0.08 | 1.00 | 0.396 |
| nsw2023 | 11 | 2 | 1.00 | 1.00 | 0.404 |
| sa2022 | 19 | 0 | 0.21 | 1.00 | 0.430 |
| sa2026 | 29 | 1 | 1.00 | 1.00 | 0.363 |
| qld2012 | 6 | 0 | none | none | 0.548 |
| qld2015 | 10 | 0 | none | none | 0.383 |
| qld2017 | 53 | 7 | 0.70 | 1.00 | 0.344 |
| qld2020 | 30 | 0 | 1.00 | 1.00 | 0.456 |
| qld2024 | 3 | 0 | 0.33 | 1.00 | 0.395 |
| wa2001 | 54 | 0 | none | 1.00 | none (nothing earlier) |
| wa2005 | 10 | 9 | none | 1.00 | 0.723 |
| wa2017 | 35 | 3 | none | 1.00 | 0.436 |
| wa2021 | 13 | 0 | none | none | 0.570 |
| wa2025 | 12 | 5 | none | 1.00 | 0.439 |

Coverage is the share of target seats with a key; the rule needs at least 3 seats and at most 10% without
a key, else it prints `ONN1!` and leaves the election alone. By that rule the House arm (A) applies to
vic2022, nsw2023, sa2026 and qld2020 only; the Senate arm (B) to every election above except fed2010
(12% missing), fed2025 (2 seats), qld2012, qld2015, wa2001 and wa2021. These counts are by seat name; the
harness's own "no history" flag is One Nation's share in its previous-election matrix, so its counts can
differ slightly (the `ONN1` line prints them per election).

## Not done here

No harness, `quick_arm.R`, `fit_seats_full.R` or `R CMD check` run (brief). `output/house-onp-by-district.csv`
was built to the scratchpad only; it must be built in the main checkout (step 0 of the pre-registration)
before the House arm can reach Queensland, and `docs/DATA-REGISTRY.md` regenerated then.
