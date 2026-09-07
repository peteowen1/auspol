# auspol — work queue

## SESSION 2026-09-07: New South Wales 2019 scored, and four findings

**Coverage is now 21 pairs and 1,957 seat-elections**, up from 19 and 1,791.
Pooled seat log loss **0.3444**, Brier 0.0944, accuracy 87.1%. All six harnesses
were re-run the same day, so every row of that table describes one model.

Two elections were added: **nsw2019** (93 seats) and **vic2014** (73 of 88, the
2013 redistribution renamed 15 districts). vic2014 became possible when the
archived VEC result pages were parsed -- the eight spreadsheets recorded here as
the 2010 Assembly results are the Legislative Council.
Full write-up: `docs/reviews/nsw2019-and-seat-turnover-2026-09-07.md`.

`scripts/pool_backtests.R` is new and produces the pooled table on demand. It
prints each source file's timestamp and code tag beside its numbers, so a stale
row shows up in the output instead of having to be remembered.

nsw2019 scores 92.5% accuracy, Brier 0.0695, log loss 0.3966, RMSE 5.552. The
NSW harness now takes `AUSPOL_NSW_PAIR` (2019 or 2023, default 2023); the 2023
pair reproduces its previous output byte-for-byte, which is what accepted the
refactor.

### Open, in the order I would do them

1. **Seats that changed hands between elections are nearly invisible.**
   19 of 893, and the damage is concentrated: Orange and Wagga Wagga in nsw2019
   score 5.705 against 0.280 elsewhere, Morwell 2.175 against 0.224. Both NSW
   seats were won at by-elections. Worth about **0.007 of pooled log loss**,
   roughly 2%. The field that fixes it is already loaded — `load_seats()`
   returns Orange as Shooters-held — and is known before polling day, so it is
   leakage-free. Targeted fix, so the named seats are the primary metric and the
   election-wide number is a do-no-harm guard.
2. **The statewide covariance is fitted in sample and on ten of twenty pairs.**
   `scripts/estimate_statewide_cov.R` builds one matrix from a hardcoded list
   and every harness reads it, including when scoring a pair inside the fit.
   Missing: qld2024, all seven WA pairs, nsw2019. Fix is leave-one-election-out
   plus widening, in one change, and it moves the published model.
3. **Western Australia has no surge-v2 hazard at all.** The other five harnesses
   do. A published switch a harness cannot honour is the failure recorded in
   `CLAUDE.md` for the missing SA `shrink`, and its numbers describe a different
   model from the rest of the table.
4. **Three elections still unscored** — qld2017, sa2018, and fed2004 as a
   scored target rather than only a prior. Parsers are the remaining work; the sources were located.

### Closed this session

- Queensland's surge training list had `sa2026` replaced by `qld2024` in the
  copy that created the harness, so it trained without the four One Nation
  winners. Fixed; effect is **neutral** (log loss 0.3350 either way).
- Adding nsw2019 to the leave-one-out slope panel moved the fitted `also_ran`
  slopes by up to 0.092 and changed no harness output at all, because only
  `member` is consumed and nsw2019 contributes no returning members. `also_ran`
  is read by nothing outside its own fitting script.


## SESSION 2026-09-05/06: the AEF gap closed, and the reason was a cap

**fed2025 seat log loss 0.3663 -> 0.2886 against AE Forecasts' 0.3025.** Ahead
by ~0.014 on a three-seed mean (0.2891 / 0.2899 / 0.2867), with Brier 0.0877
against their 0.0996 and accuracy 86.7-87.3% against 86.0%.

**What it was.** `shrink` is a per-draw coin toss, so a scalar caps EVERY seat
at `1 - shrink/2`. At the shipped 0.10 no seat could be called above 0.95 —
measured max p 0.9505, with 19 of 150 federal seats against that ceiling, each
paying `-log(0.95) = 0.051` where `-log(0.99) = 0.010` was available. About
0.006 of mean log loss on the cap alone, fifteen times the gap being chased.

`AUSPOL_SHRINK` default is now **0.01** (`fit_seats_full.R`). Six federal pairs,
seed 42:

| shrink | mean log loss | mean Brier |
|---|--:|--:|
| 0.10 | 0.4154 | 0.1000 |
| 0.02 | **0.4047** | 0.0983 |
| **0.01 (shipped)** | 0.4096 | **0.0982** |
| 0.00 | 0.4282 | 0.0983 |

0.01 rather than 0.02 because Pete's standing rule is that this is a hack and
should sit at the lowest value the evidence allows, rising only for a benefit
that is significant — 0.02's 0.005 edge is one seed on six pairs and is not.

**It must NOT go to zero**, which is the one thing the evidence refuses: 0.00
costs 0.0235 of mean log loss, concentrated in fed2013 (+0.0975) and fed2022
(+0.0243). That risk is invisible on fed2025, so tuning on fed2025 alone would
have switched it off and taken the fed2013 blow-up unseen.

Published Victoria forecast barely moves: ALP 34, LNP 36, GRN 6 medians
unchanged, ONP 10 -> 9. This is calibration, not a different forecast.

### Also shipped

- **`scripts/fit_mp_slope.R`** (new). The sitting-member slope tier was fitted
  on ten election pairs and then scored on fed2025, one of them. Refitted
  leave-one-election-out over 18 pairs and 6 jurisdictions the tier is REAL —
  member/also-ran gap positive in 18 of 18 folds — but three of its four shipped
  values were wrong: IND 0.954 against 0.896, GRN carried a value where its
  member and also-ran slopes are indistinguishable, and **ONP's 0.610 was the
  also-ran slope written into the member row over ZERO member observations**.
  All five harnesses and `fit_seats_full.R` now read fitted values from
  `output/mp-slope-by-target.csv` / `-by-class.csv`. Worth 0.5083 -> 0.4062 on
  NSW; the leaked value had cost Victoria 0.0029 for nothing.
- **`fit_seats_full.R` now passes `same_mp` and `major_discount`.** It called
  `personal_prior_vote()` / `screened_slopes()` / `conditional_slopes()` without
  either, so what the harnesses measured was not what was published.
- **`AUSPOL_SEAT_SD_MULT` fixed — it had been INERT since 2026-08-27.**
  `sd_cell` is computed from `level_sd` and ignores `seat_sd` entirely whenever
  `level_sd` is given, and `level_sd` is on by default, so every sweep of the
  multiplier since then measured a parameter with no path to the output while
  the harness printed "seat_sd multiplier applied". It now scales whichever
  spread is in force and says which.

### Measured NULLS — do not re-run these

The recorded diagnosis in `fed2025-closing-the-aef-gap-2026-09-04.md` that the
residual is "One Nation preference drift, and nothing else" is **FALSIFIED**.

| arm | fed2025 log loss |
|---|--:|
| baseline | 0.3042 |
| per-source flow uncertainty, k=0.25 / 0.50 | 0.3043 / 0.3051 |
| trend-extrapolated flow cells, w=0.25 / 0.50 / 1.0 | 0.3040 / 0.3045 / 0.3065 |
| **flow trend, ONP only, w=1.0** | **0.3105** |
| spread (level_sd) x1.20 | 0.3142 |

The trend arm lands the cell almost exactly — `ONP|ALP+LNP` 63.8 -> 72.2 against
an actual 71.4 — and still scores WORSE. Under a 0.95 cap the model cannot
express confidence, so a more accurate component has nowhere to go. Both
mechanisms are kept (`R/flow_trend.R`, per-source `flow_sd` in `R/seat_sim.R`),
correct and **off by default**, because the finding is the point.

Decomposition worth keeping: of One Nation's 47.6 -> 61.6 swing to the
Coalition, cell-mix explains 47.6 -> 51.1 and the remaining +10.5 is genuine
within-cell drift, positive in all four major cells.

## THE OBJECTIVE, set by Pete 2026-09-06 evening

**Every model change is decided by overall seat log loss AND seat-share RMSE
pooled across ALL the elections we forecast** — every 21st-century state and
federal election in the harnesses — never one election or one harness. The
harnesses now print the RMSE line (`BF3r`/`BV2r`/`BT5r`/`BS2r`/`BW2r`,
`seat_share_rmse()` on the point estimate) beside log loss.

**Coverage today: 17 elections, ~1,570 seat-elections** — fed 2010, 2013,
2016, 2019, 2022, 2025; vic 2018, 2022; nsw 2023; sa 2026; wa 2001, 2005,
2008, 2013, 2017, 2021, 2025. **Buildable now**: qld2024 (2020 prior and
transfers on disk; also one of AEF's archived elections). **One prior fetch
each**: fed2007 (needs fed2004), vic2014 (vic2010), nsw2019 (nsw2015), sa2022
(sa2018). Those five would make 22.

## P4b SHIPPED 2026-09-07 01:00: the surge reaches the candidate it was fitted for

`plans/prereg-surge-recipient-2026-09-06.md`, stage 2. Recipient ON at scale
x1, all 17 elections at 20,000 draws: **pooled seat log loss 0.3631 ->
0.3422, 1.9 SE**, RMSE unchanged, fed2022 0.4819 -> 0.3862, fed2010 0.4047 ->
0.3281, fed2016 0.3566 -> 0.3154; x2 refused. Named cost: Clark 2022 and
Melbourne 2013 fall 0.024/0.025 because the hazard there names a Green.
`AUSPOL_SURGE_RECIPIENT=1` is published. The teals now sit at 0.02-0.05, off
zero and an order of magnitude short of AEF's 0.3-0.5: **the remaining gap is
the hazard's calibration** (ridge lambda 20 on ~13 winners), which is the
next pre-registration — a calibration map from hazard rank to probability,
or a lower lambda, scored the same way.

## DATA HUNT 2026-09-07: all five missing elections FOUND, one already forecast

Pete's instruction was to take no election as unavailable. None of the five is.

| election | source | status |
|---|---|---|
| **fed2004** | AEC, `results.aec.gov.au/12246/**results**/Downloads/` | **DONE.** First preferences, full distribution of preferences and two-candidate file, all fetched and wired in. **fed2007 now forecasts: log loss 0.2858, accuracy 88.6%, our second-best election.** |
| **nsw2015** | NSWEC archived tally room, `pastvtr.elections.nsw.gov.au/SGE2015/data/la/state/` | Spreadsheet downloaded (1.46 MB), same format as the 2019/2023 files the fetcher already reads, plus a per-district distribution of preferences. Needs the parser wired. |
| **vic2010** | Internet Archive, `/Results/state2010result<District>District.html`, 88 pages | **CORRECTED 2026-09-07.** The eight `state2010*RegionFPVbyVC.xls` workbooks recorded here earlier are the LEGISLATIVE COUNCIL: each is one Council region, its eleven sheets are the eleven Assembly districts inside it, and every sheet lists GROUP A/B/C with no candidate names. Checked across all eleven sheets of one workbook. The Assembly results are the old VEC site's per-district result pages, which the archive has: candidate, party, first preferences, elected member, and a Note mapping each abbreviation to its registered name. `scripts/fetch_preferences_vic2010.R`. |
| **qld2017** | Wikipedia, `Results_of_the_2017_Queensland_state_election` | 93 district tables, exactly the chamber size, with party/candidate/votes/share. The ECQ publishes only two-candidate booth PDFs for 2017 and its data portal starts at 2020. |
| **sa2018** | Wikipedia, `Results_of_the_2018_South_Australian_state_election_(House_of_Assembly)` | 47 district tables, exactly the chamber size. The ECSA API answers 2018 with an empty body; it holds only 2022 and 2026. |

**The 2004 find is worth naming**: the AEC serves it from `/results/Downloads/`
where every later election uses `/Website/Downloads/`, and the wrong path
returns a 404 PAGE rather than an error, so it read as "not published" for a
year. The 2004 file also has no `Elected` column -- it carries
`SittingMemberFl`, who held the seat BEFORE -- so the winner is derived from
the final count and cross-checked against the AEC's own two-candidate file,
which agreed in all 150 divisions.

**Wikipedia is a secondary source and is treated as one**: any harness built
on it must verify its statewide totals against the anchor's
`eventual-results.csv`, which holds qld2017 and sa2018, before the numbers
are used.

**Next**: parsers for nsw2015, vic2010, qld2017, sa2018, then their pairs.
That would take coverage from 19 elections to 23.

## Standing item found 2026-09-07: package functions read BARE RELATIVE paths

`surge_hazard_for()` and `surge_training_population()` read
`"output/candidacies.csv"` relative to the working directory. That is the
package root for everything in `scripts/`, and `tests/testthat` for the
suite -- so two tests of those functions guarded on `file.exists("output/...")`
and skipped **unconditionally, on every machine, including the ones that have
the corpus**. Found by review 2026-09-07; the tests now resolve from the root
(`skip_if_no_salience_corpus()`) and run their bodies there
(`with_package_root()`), both in `tests/testthat/helper-anchor.R`. The
underlying smell is unfixed: package functions should resolve through
`getOption("auspol.root")` the way `election_data_path()` does.

## SESSION 2026-09-07: a sixth harness, two refusals, and the salience gap named

**Queensland exists and beats the benchmark.** `backtest_candidate_qld.R`
(qld2020 -> qld2024, 93 seats): accuracy 82.8%, Brier 0.1087, **log loss
0.3351 against AE Forecasts' 0.3578**, seat-share RMSE 3.259. Built from the
SA harness with four differences named in its header, the largest being that
its flows come from Queensland's OWN 2020 distribution rather than a federal
election. Coverage is now **18 elections, ~1,640 seat-elections**, and a
second AEF-benchmarked state election.

**The salience point estimate reaches the published forecast at last.**
`blend_salience_shares()` was inline in the federal harness alone; the three
state harnesses and `fit_seats_full.R` never blended. Ported: pooled RMSE
4.697 -> 4.689 (-1.8 SE), federal byte-identical.

**Two changes refused, both by their own criteria:**
- **P5** (the point estimate is an expected vote, not a win probability):
  Pete's finding, and the category error was real. Fixed the projection
  (Goldstein 2.3 -> 10.4, pooled RMSE better in 4 of 6 federal), but pooled
  log loss did not move, so the pre-registration refuses it. The salience
  signal now predicts the VOTE well and the SEAT badly.
- **P6** (no surge against a returning sitting member): refused by its own
  dry run BEFORE any code, because emergences do beat sitting members --
  MacKillop and Narungga, SA 2026, both One Nation over a sitting
  independent.

**From the two reviews** (now in `reviews/code-simplification-2026-09-06.md`
and `reviews/performance-2026-09-06.md`, each with a status header):
SA and QLD were zeroing 30 seats and naming 22; dead code removed from
`R/flow_matrix.R`; `seat_shrink_vector()` documented as uncalled. Five
duplicated harness blocks remain, and memoising `governed_population()`
across the pair loop remains.

**The open question, and it is Pete's:** the six fed2022 teals polled 25-40%
and the model projects 2-14%. The hazard is calibrated, the size (35.1) is
right, the ranking is right; what is missing is that 2022 was a wave and
nothing in the model can see one.

**The wave term is BLOCKED, diagnosed, and no arm should be run**:
[reviews/wave-term-blocked-2026-09-07.md](reviews/wave-term-blocked-2026-09-07.md).
It needs an ABSOLUTE salience bar (the percentile is within-election by
construction, so a wave and a quiet year look identical), and the raw measure
is not comparable across elections: every Trends batch is anchored to
**Anthony Albanese**, who was a little-known minister in 2008 and Prime
Minister in 2026. fed2022, the wave, has the SECOND FEWEST candidates over an
absolute bar and the most winners; the correlation between count and win rate
is NEGATIVE. The cache holds only per-keyword means, not the weekly series,
so nothing can be re-derived -- the "cache the series, derive the statistic"
lesson landing a second time on a different question.

The one unblocking route available before November is a different proxy
entirely: the count of non-major candidates NOMINATED per seat, a commission
fact rather than a search statistic, which the candidate-count work already
needs after Victorian nominations close on 9 November 2026. It measures
crowding rather than prominence and must be pre-registered as that.

## P4c REFUSED and the calibration question ANSWERED, 2026-09-07

`plans/prereg-recipient-at-zero-2026-09-07.md`. Letting a named recipient
surge from zero share removes every demotion (275,205 → 0 on fed2022) and
moves the targets only as far as their hazard allows (Goldstein 0.017 →
0.022): **a seat's win probability now equals its hazard.** Pooled 0.3422 →
0.3444, refused; the entire loss is Fairfax 2013, where Palmer's party won
and the default rule had been rescuing it by accident.

**The hazard is already calibrated** — out of fold, 1,920 seat-classes, the
top 2% band predicts 0.173 and wins 0.158, and every band matches. So
rescaling cannot help (x2/x4/x8 all lost), and Goldstein's 0.025 is not an
under-estimate: seats that looked like that won ~5% of the time. **The gap to
AE Forecasts is information, not calibration.** Next: a wave term (how many
high-salience challengers a cycle carries, knowable before polling day), then
Pete's call on seat polls or market odds.

**Found by the review gate's new diagnostic line on its first run (fed2022,
`BF3e`)**: in **275,205 of 3,000,000 seat-draws** the named recipient was at
zero share after noise and the surge fell back to the largest non-major — a
1.3% independent class clamps to zero in most draws, so Goldstein still hands
its surge to the Greens most of the time. That is the floor case the P4
pre-registration named, now measured. **P4c**: a named recipient at zero
share should still receive the surge (an emergence from nothing is the
case), pre-registered and scored the same way.

**Next, in order** (each its own pre-registration, each a minutes-long sweep
now): (0) P4c above; (1) hazard calibration; (2) the hazard must not fire against a
returning sitting member of the same seat (Clark, Melbourne); (3) the
transfer fraction for minor-party switchers (Hunter's One Nation at 0); (4) a
retention model for a departed leader's base (Wentworth vs New England);
(5) a Queensland harness (data on disk); (6) the two reviews' refactors.

**Harness note**: a run launched while `src/` is compiling collides with the
build (six stage 2 runs died at load_all on `seat_sim_core.o`). Launch one
run first after any change to `src/`, then the rest.

## THE SIMULATOR IS COMPILED, 2026-09-07 00:45 — a sweep is minutes, not an hour

`src/seat_sim_core.cpp` is the per-draw core of `simulate_seat_contests()`,
ported with every random draw taken from R's generator in the R loop's order
and every sum in long double as R's `sum()` does. **Proven byte-identical**:
`expect_identical()` against the R engine on the synthetic fixture with every
mechanism on (three shift modes, level variance, surge with a named
recipient, shrink, flow uncertainty), and a full fed2022 run at 20,000 draws
whose per-seat, per-party and totals files are byte-for-byte the rule-2
baseline's. **45 seconds against about 11 minutes.** `AUSPOL_SIM_ENGINE=cpp`
is the published value; `=r` forces the reference loop, which stays in the
file so the identity can be re-proven. The core does not cover
`party_draws` or more than the dense cell tables allow; both fall back to R.

## P4 STAGE 1, 2026-09-06 23:30: the surge pays the wrong candidate

`plans/prereg-surge-hazard-scale-2026-09-06.md`, stage 1 result. Scaling the
surge-v2 hazard x8 moves Goldstein 0.000 -> 0.001 and Kooyong 0.007 -> 0.021
while Cowper (lost) goes 0.47 -> 0.80. **The simulator awards the surge to
the LARGEST non-major class in the seat** (`surge_parties = NULL` in
`R/seat_sim.R`), which in every teal seat is the Greens, and the 2% floor
bars a 1.3% base outright. A week of salience work fitted a hazard for a
named independent and wired it to pay the Greens. **P4b, next**: carry the
salient candidate's class per seat out of `surge_hazard_for()`, direct the
surge at it, exempt it from the floor, then re-run the scale grid. Its own
pre-registration, before any code.

Also tonight: the two simulator hoists are proven byte-identical on a full
fed2022 run (per-seat and per-party tables) and shipped.

## P1 RESULT 2026-09-06 late: rule 2 ships, rule 1 refused

`plans/prereg-vote-belongs-to-the-person-2026-09-06.md`, results section.
A switcher's vote now leaves the class it came from (`remove_transferred_votes()`,
called from four harnesses and `fit_seats_full.R`): Kennedy 2013 and Hunter
2022 fixed, SA 0.3865 -> 0.3516, NSW 0.3251 -> 0.2980, vic2022 0.2466 ->
0.2348. The departed-leader rule fixed New England 2013 and broke Wentworth
2022 (0.705 -> 0.138), a wash on the six federal pairs; refused, kept behind
`honour_departed = TRUE`. **The rule-2-only run at published defaults is the
new baseline** (in progress at the time of writing; numbers go in the plan
file's section 2 when it lands). Two follow-ups recorded there: a minor
party keeps some of a departed candidate's vote (the transfer fraction
should be fitted, not 1.0), and the output fingerprint now carries the git
commit (`-g<sha>`, `x` when dirty) so a code change cannot overwrite a
baseline's files again.

## Reviews done while the runs went (2026-09-06 evening), reports in the session scratchpad — bring into `docs/reviews/` next session

- **Simplification**: seven blocks copied across the five harnesses (the
  level-sd/multiplier header is ~100 lines x 5), one real drift (SA zeroes an
  absent independent at `> 0.5`, the others at `> 0`), `seat_shrink_vector()`
  exported with no caller, `avail` dead in `R/flow_matrix.R`, 45 one-off
  scripts nothing references. Top refactor: one function for the seat-spread
  resolution, proven by byte-identical WA output.
- **Performance** (line profiler, true default path): `R/seat_sim.R:687` the
  per-cell `sd_cell` recomputed 20,000x per seat when invariant across draws
  (23% of time), and `ss_lookup()`'s string cache key at `R/seat_sim.R:570`
  (16%) — both byte-identical hoists; `surge_hazard_for()` recomputes the
  same four training pairs per federal pair (~15-25 s/run). TCP writes and
  positional indexing measured negligible.

## NEXT, as of 2026-09-06 afternoon: what ships was not what was measured, and where the misses are

Pete asked which elections we forecast, how we score against AE Forecasts,
and whether the big misses are polling or the model. Full answer with the
evidence and a ranked plan:
[plans/plan-miss-patterns-2026-09-06.md](plans/plan-miss-patterns-2026-09-06.md).
The two facts that change what to do next:

- **The harness "shipped config" is not the published config.** It ran with
  the v1 national salience ratio (`AUSPOL_IND_SALIENCE=1`, which
  `fit_seats_full.R` never reads) and surge-v2 OFF (which the forecast has ON).
  With surge-v2 on: fed2022 0.6065 -> 0.4804, fed2025 0.2898 -> 0.3017 (AEF
  0.3025 — a tie, not the win reported above), fed2019 0.2619 -> 0.2643,
  fed2016 0.4080 -> 0.3924, fed2013 0.4386 -> 0.3817, fed2010 0.4525 -> 0.3963:
  six-pair mean 0.4096 -> 0.3695 on log loss and WORSE on Brier in all six.
  Surge-v2's gain is the log-loss clamp on seats moving 0.000 -> 0.004; it
  hedges, it does not forecast.
  **P0 DONE 2026-09-06 evening: `scripts/published_flags.R` is the one registry;
  `fit_seats_full.R` and all five harnesses apply it to unset switches** (the
  forecast's outputs are byte-identical before and after, so the registry
  equals the code defaults). Re-baseline at published defaults: see the table
  in `plans/plan-miss-patterns-2026-09-06.md` section 2: six-pair federal
  mean **0.3717** (Brier 0.0976); fed2022 0.4960 / fed2025 0.3103 against AEF
  0.2353 / 0.3025; vic2022 0.2466, nsw2023 0.3251, sa2026 0.3865, wa2025
  0.2787. **Every number after this is measured against that column.**
- **The misses have a shape.** 80% of the fed2022 gap to AEF is 11 seats a
  first-time independent won; the false independent calls trace to three
  specific mechanisms (a national IND multiplier applied uniformly, a
  personal-vote double count on a class switch, three independents summed
  into one); Tasmania and WA swings are a state term the federal simulator
  does not have; 2016 redistributions have no notional baseline. Poll error
  (2–3 points in four of six elections) is the part no model change fixes.

Also found: the federal statewide draws carry duplicate `IND` and `OTH_RIGHT`
columns (the simulator takes the first), and `dump-shares-fed*.csv` had not
been written since 2026-08-28. The federal harness now writes the full
per-party table (`backtest-fed-allprobs*.csv`), which is what made the trace
possible.

## NEXT: per-seat shrink (the top item)

`AUSPOL_INSURGENCY_SHRINK=1` already exists and gives each seat its OWN fitted
risk from `output/fed-insurgency-risk.csv`, so most seats get ~0 and only seats
with a non-major in reach pay anything — the outcome the scalar approximates
badly, and the one Pete actually wants.

All six pairs now measured, scalar shrink 0, seed 42:

| pair | 0.01 scalar (shipped) | 0.02 scalar | per-seat |
|---|--:|--:|--:|
| fed2010 | 0.4525 | 0.4290 | 0.4564 |
| fed2013 | 0.4386 | 0.4543 | **0.4092** |
| fed2016 | 0.4080 | 0.4096 | 0.4144 |
| fed2019 | 0.2619 | 0.2636 | 0.2718 |
| fed2022 | 0.6065 | 0.5828 | 0.6099 |
| fed2025 | 0.2898 | 0.2891 | 0.2929 |
| **mean** | **0.4096** | **0.4047** | **0.4091** |

**IT DOES NOT YET HOLD.** Per-seat ties the shipped 0.01 on the mean and is
worse in **5 of 6 pairs** — the whole advantage is fed2013, and one election
carrying a mean is the shape that does not replicate. Both scalars beat it on
fed2025.

Why it is still the top item: the mechanism is right (most seats get ~0,
insurance only where a non-major is in reach) and it is the only arm that fixes
fed2013, the election a zero scalar blows up on. What it plausibly needs is a
SCALE parameter on the fitted risk — the current vector has median 0.012-0.038
and max 0.200 per election, which is both flatter and more extreme than any
scalar, so a single multiplier sweep (say 0.5x, 0.75x, 1.5x) is the obvious
next experiment and was not run. Pre-register it: this is a general change, so
the primary metric is election-wide mean log loss over all six pairs with the
per-pair table as the guard against another fed2013-only result.

**Two bugs were found and fixed getting it to run, both now VERIFIED:**

1. It aborted the entire arm on fed2025 because **Bullwinkel is new at the 2025
   redistribution**, so its upset features cannot exist (not staleness —
   regenerating `build_upset_features.R` / `fit_insurgency_risk.R` did not help).
   New seats now take the election's median risk and are NAMED in the output; a
   non-new missing seat still aborts. Verified: "fed2025 1 seat(s) new at this
   redistribution ... given the election median risk 0.048: Bullwinkel".
2. Indexing a named vector by a name it does not carry returns an element whose
   NAME is NA, so filling the value alone left the seat absent and
   `simulate_seat_contests()` rejected the vector. Names are reasserted from the
   seat order with a `stopifnot`. Verified: fed2025 now scores 0.2929.

### RUN 2026-09-06: per-seat AND a 0.01 floor — REFUSED

Pete's question answered. `AUSPOL_INSURGENCY_SHRINK=1 AUSPOL_SHRINK=0.01`,
seed 42, all six pairs, one launch per pair:

| pair | 0.01 scalar (shipped) | 0.02 scalar | per-seat | per-seat + 0.01 floor |
|---|--:|--:|--:|--:|
| fed2010 | 0.4525 | 0.4290 | 0.4564 | 0.4570 |
| fed2013 | 0.4386 | 0.4543 | **0.4092** | 0.4171 |
| fed2016 | 0.4080 | 0.4096 | 0.4144 | 0.4149 |
| fed2019 | 0.2619 | 0.2636 | 0.2718 | 0.2720 |
| fed2022 | 0.6065 | 0.5828 | 0.6099 | 0.5831 |
| fed2025 | 0.2898 | 0.2891 | 0.2929 | 0.2930 |
| **mean** | 0.4096 | **0.4047** | 0.4091 | 0.4062 |

Bar was 0.4047; the floor arm lands at **0.4062** and misses it. Against the
shipped 0.01 scalar it is 0.003 better on the mean and worse in **4 of 6**
pairs, the same one-election shape the pure per-seat arm had. The floor does
its work in fed2022 alone (0.6099 -> 0.5831, matching the 0.02 scalar there)
and costs 0.008 in fed2013. **Shipped default stays the 0.01 scalar.**

Still unrun and still the obvious next experiment: a SCALE on the fitted
per-seat risk (0.5x / 0.75x / 1.5x). Pre-register before running.

### Harness fix found on the way: early pairs could not run alone

`AUSPOL_FED_PAIRS=2010`, `2013` or `2016` aborted with "No federal seat file
yielded a within-region seat-swing spread" because the `seat_sd` fallback was a
median over only the pairs IN the run, and those three have no seat file. The
per-pair launches the 10-minute cap forces could not cover half the harness.
`sd_within` subtracts the statewide swing as a constant, so the fallback is now
`spread_for(k$to, 0)` over `PAIRS_ALL` and prints 3.233 for a single early pair,
the value the full run has always used. (That fallback is a median over LATER
elections' spreads for those pairs — noted as a hyperparameter with no pre-2010
seat file to draw on, not fixed.)

### The other four harnesses at shrink 0.01: indifferent, and the reason matters

Re-measured at the value that ships (`DEV_SLOPE_MODE=screened
DEFECT_DISCOUNT=1 MP_SLOPE=1`, the set fingerprint `a5003a` was run with):

| harness | 0.02 | 0.01 | move | what moved |
|---|--:|--:|--:|---|
| Victoria (166) | 0.3039 | 0.2764 | -0.028 | Morwell 2018: 0 -> 2 draws |
| NSW (88) | 0.3822 | 0.4252 | +0.043 | Wakehurst: 2 -> 0 draws |
| SA (47) | 0.3857 | 0.3867 | +0.001 | nothing |
| WA (361) | 0.4026 | 0.4047 | +0.002 | Churchlands 2013: 26 -> 10 draws |

**Every move over 0.005 is ONE seat an independent won at first attempt, where
the model holds ~0 mass and the only question is whether 0, 1 or 2 of 20,000
draws happened to land.** At the harness's `eps = 1e-6` clamp, zero draws costs
13.8 and two draws 9.2, and that single seat is worth 0.04 of a 88-seat mean.
So the state harnesses cannot see 0.01 against 0.02 at all; the federal
harness, with 886 seats and ~20 such seats, is the only one with power here.

Two things follow, neither done: the clamp is below the simulation's own
resolution (1/20,000 = 5e-5), so a seat at zero draws is charged for a
confidence the simulation never expressed — worth aligning `eps` with
`1/N_SIMS` across all five harnesses in one change, pre-registered as a metric
change; and the "cannot elect a new independent" hole (Awaiting Pete, below)
is what these seats are.

### Review gate 2026-09-06, before the dev -> main PR: what it caught

Three Sonnet reviewers over the two-week diff (package + tests; forecast script
+ five harnesses; silent-failure pass). Fixed in the same commit, each with a
test or a proof that fails on the old code:

- **`party_swing()` region filter was inert — the EIGHTH data.table NSE
  instance.** `C[C$region == region & ...]` bound `region` to the column, so
  every jurisdiction was pooled: with the bug Victoria 2022 reports ALP
  surging, NSW 2023 LNP, SA 2026 ONP and LNP; fixed, only SA's ONP. The
  spurious entries are all majors, which `governed_population()` already
  excludes, so no published or harness number moves. Test added with a region
  that does not exist and one whose swing differs.
- **`AUSPOL_SEAT_SD_MULT` was inert in Victoria, NSW, SA and WA** — the
  2026-09-05 federal fix had not been ported. Ported; proven on SA at 1.15
  (log 0.3867 -> 0.3853, slope 1.010 -> 1.133, the CAL line names LEVEL_SD).
- **A NAMED length-1 `shrink` or `surge_h` broadcast to every seat** instead
  of hitting the missing-seat error the roxygen promises. Names now checked
  before length. Test added.
- **Every caught fallback in `fit_seats_full.R` now prints WHY** (`DS2`,
  `DS2o`, `DS3` carry the error message), and the personal-prior-vote step,
  which had no disclosure at all, has a `DS2o` line either way. Once
  nominations close a real bug can no longer read as the pre-nomination gap.
- **`governed_population()`**: a missing corpus is a disclosed skip, an
  unreadable one is an error (it was a silent `tryCatch` for both); a failing
  `surging_parties()` says so.
- **`fit_mp_slope.R`** names any pair whose `candidate_returns()` fails and
  stops, instead of silently shrinking the panel behind `stopifnot(nrow > 0)`.

**Deferred, not fixed** (none on the published path; each needs its own
measurement or plan):

- **WA harness lacks the screened slope mode and `personal_prior_vote()`.**
  `_wa.R` supports only `conditional`, so a five-harness comparison of
  `AUSPOL_DEV_SLOPE_MODE=screened` measures WA without the base-value fix.
  Its file banner disclaims `DEFECT_DISCOUNT` but not this.
- **`AUSPOL_NOTIONAL` (notional baselines for redistributed seats) exists only
  in `_fed.R`**, and WA is the harness that redistributes hardest.
- **`pairwise` flow cells have no `min_n` floor** (`R/flow_matrix.R`) and sit
  ahead of the fully-pooled rate in the simulator's lookup chain, so a
  one-round cell can be preferred over a well-supported one. Same shape as
  the Richmond zero. A statistical change; pre-register before touching.
- **`leading_candidate_returns()` / `personal_prior_vote()`** drop a
  seat-class whose leading candidate has no parseable name, with no coverage
  count; fails safe to the class-level base.
- `ridge_logistic()` returns the current beta on a singular Hessian with no
  diagnostic; `avail` in `R/flow_matrix.R:122` is dead code.
- The harness `eps = 1e-6` clamp sits below the simulation's own resolution
  (see the state re-measurement above).

## Then

1. ~~Re-measure the other four harnesses at `shrink=0.01`~~ — done above.
2. ~~Push `dev` and take it through the review gate to `main`~~ — **PR #27
   merged 2026-09-06** after the review gate above; CI green in 2m04s. `main`
   is current with `dev` for the first time since PR #26 (2026-08-23).
3. **Data threads, Pete's call**: One Nation how-to-vote cards (the ONP drift is
   a published pre-election decision this repo does not hold), and seat-level
   polling.

## Known gap

`output/` is gitignored, so `output/mp-slope-by-target.csv` and
`-by-class.csv` are NOT in the repo. A fresh clone must run
`scripts/fit_mp_slope.R` before `AUSPOL_MP_SLOPE=1` will work, and
`fit_seats_full.R` now needs `-by-class.csv` to run at all unless
`AUSPOL_MP_SLOPE=0`. Both error rather than falling back, deliberately — a
silent fallback to a constant is how the leaked value survived.

## ACTIVE PLAN: candidate-level seat model

[plans/plan-candidate-level-model.md](plans/plan-candidate-level-model.md) —
opened 2026-08-27, and it is the working checklist. The seat model is party-class
based, so "IND" is a residual bucket and a returning independent is
indistinguishable from a stranger. Measured across 17 election pairs, that one
fact moves a 30% seat to 30.3% or to 12.1%.

**Section A is CLOSED.** Both tickets resolved 2026-08-27, the day before this
line first claimed they were next:

- **A1 SHIPPED** as level-dependent variance, on by default at `1.10,8.67`.
  `reviews/level-variance-2026-08-27.md` refuses it on calibration and then
  **amends the same day to ship it** on log loss — read that file to its end,
  because the headline says the opposite of the verdict.
- **A2 REFUSED** — arm C does not ship, and by its own terms **A3 never runs**
  (`reviews/arm-c-conditional-slopes-2026-08-27.md`).

**Class-specific variance: CLOSED, refused twice, and section A is now fully
done.** Pre-registered in `plans/prereg-class-specific-variance.md`, scored in
`reviews/class-variance-stage1-2026-09-03.md` (refused on a bar mis-sized 10x
too high, borrowed from a differently-scaled experiment), re-registered in
`plans/prereg-class-specific-variance-v2.md` with a t-statistic/materiality
split instead, scored in `reviews/class-variance-v2-2026-09-03.md`.

**v2 refused too, on stronger grounds than v1.** The effect is real and
negative in all 20 harness x arm cells (p < 0.02 throughout), but too small
relative to its own noise, and pushing the multiplier higher makes it WORSE:
the t-statistic peaks at m_IND 2-3 (2.98) then falls to 2.60-2.65 at m_IND 4-5
even as the raw effect keeps growing, because variance outpaces the mean past
that point. That is a reason NOT to re-register a wider grid -- the mechanism
argues against an undiscovered sweet spot past the edge, not for one.

Honest summary: per-class variance is a real but minor refinement, nowhere
near the 29% log-loss gain A1 already delivered. Not worth its own parameter.


Updated 2026-08-28. Remote: github.com/peteowen1/auspol (private, default
branch `dev`; `main` exists and is reached only through a reviewed PR).

Completed stage write-ups live in
[backlog/journal-2026-08.md](backlog/journal-2026-08.md) — this file holds
open state, not the narrative of how it got here.

**Hub-slimming passes: 2026-09-04 and 2026-09-06.** Sections older than about
two weeks roll into `backlog/journal-*.md` verbatim; live items get pulled
forward, never cut by line range (`hub-slimming` skill).

## DONE 2026-09-04: the seat simulator's hot loop, profiled 2026-09-03

**Shipped.** Measured 36-38% faster in fresh-process wall clock (204→132 us
per seat-sim at n_sims=500, 217→136 at n_sims=4000) — better than the ~25-30%
Rprof self-time estimate below predicted. `as.character`, `mostattributes<-`
and `exists` all disappeared from the post-fix profile.

The string-keyed environment (`key <- as.character(from * 2^K + mask)`,
`exists()` then `get()`) is now a preallocated list indexed by the integer key
directly, for any party count where that stays cheap (`CELLS_DENSE_CAP =
2^18` slots, ~262k — every real dataset here uses K≤8, giving ~2,300 slots).
Past the cap it falls back to the original environment, so K up to the
function's own hard limit of 20 stays correct without a ~1.2GB preallocation.
`base_v` drops its party names once, right after the one place that still
needs them (`party_draws` substitution), removing the attribute-copying cost
from everything downstream.

**Proof, not argument.** `output/seat-probs-vic-2026.csv` and
`-sims-full-vic-2026.csv` are BYTE-IDENTICAL before and after, same seed —
expected, since no RNG call changed, but proven rather than assumed. All 145
seat-sim/flow tests pass, including two new ones added because the sparse
(large-K) fallback had never been exercised: a K=17 contest forcing that path,
and a deterministic K=17-vs-K=3 same-outcome check (padded with zero-share,
zero-variance parties so the real 3-party contest is unaffected).

One dead end recorded rather than hidden: the first version of the K=17
cross-check tried to compare a padded 17-party run against the unpadded
3-party baseline for numeric equality. Both failed — `win_prob` lists only
parties that actually won at least once (not all K), and `rnorm(K, ...)`
consumes a different number of draws per seat at different K, so the two runs
are not RNG-comparable even with the same seed. Neither was a code bug; both
were wrong assumptions about what the test was allowed to expect, caught by
running it rather than trusting the design on paper.

**There is no O(n^2).** Measured in FRESH processes at 88 seats x 8 parties:

| n_sims | time | us per seat-sim |
|--:|--:|--:|
| 500 | 8.99s | 204.4 |
| 1000 | 17.85s | 202.9 |
| 2000 | 37.19s | 211.3 |
| 4000 | 76.40s | 217.0 |

Clean linear scaling; the target is the ~210 us constant, not the complexity.
**Measure in a fresh process.** Reusing one R session made 4000 sims look 1.04x
the cost of 2000 — a warm-heap artefact that reads exactly like sublinear
scaling, and it nearly became a finding.

Rprof self-time on that unit, ranked:

| | self % | what |
|---|--:|---|
| `simulate_seat_contests` | 49.2 | the loop body itself |
| `as.character` | 13.3 | **builds a string hash key per elimination round, per seat, per sim** |
| `mostattributes<-` | 6.3 | attribute copying, because `pmin`/`pmax` run on NAMED vectors |
| `vapply` | 5.3 | |
| `exists` | 4.0 | **then a second `get()` looks up the same key again** |
| `bitwShiftL` | 3.4 | the bitmask feeding that key |

The fix is `key <- as.character(from * 2^K + mask)` plus `exists()` plus `get()`
replaced by one integer index into a preallocated list. With K around 8, `K * 2^K`
is about 2,048 slots, so the table is trivially small. Dropping names in the hot
path removes `mostattributes<-`. Note `[[` on a missing name in an environment
THROWS rather than returning NULL — the CLAUDE.md trap — which is why a list
indexed by integer is the right shape, not an environment.

Also observed: runtime RISES with `m_IND` (137s at 1.00 to 175s at 1.75 on South
Australia), because a wider non-major keeps more parties alive through more
elimination rounds. Arm cost is not flat across a grid.

## Google Trends and the 2026-08-28 session — moved out

Both moved verbatim to
[backlog/journal-2026-08-26-and-28.md](backlog/journal-2026-08-26-and-28.md)
on 2026-09-06; every open item in them was closed by 2026-09-04 and the
Trends finding ships as arm CS. One line stays live:

**Hard date:** Victorian nominations close 12 noon 9 November 2026. The
salience signal is candidate-level so it cannot run before then;
`scripts/victoria_salience_dryrun.R` tests everything downstream against
Victoria 2022 — two lines change on the day.

## Four "we don't have it" claims that were wrong (2026-08-25/26)

Booth results, electoral boundaries, candidate-level federal first preferences
for all seven elections, and the AEC's own seat-level `Swing` column. All four
were on disk. The last two were being downloaded and **aggregated away** by
`fetch_preferences_fed.R`, and a whole plan was written around acquiring data
we already had.

Now: `docs/DATA-REGISTRY.md` (does the file exist) and
`docs/DATA-DICTIONARY.md` (does the field exist), both **generated from disk**.
`build_candidacies.R` carries every column through — 23 against 13. The rule is
in CLAUDE.md: never aggregate a source down to the columns you happen to need.

## Resolved this session

- **`party_sd`: TIE**, 11 of 17 pairs, p = 0.332
  ([reviews/party-sd-tie-2026-08-26.md](reviews/party-sd-tie-2026-08-26.md)).
  Stays at 1.50 — not because 1.50 is right, but because changing it buys
  nothing measurable. **It caught a false positive**: 4-of-4 on federal alone,
  a coin flip across seventeen.
- **WA harness added** — seven pairs, 361 seat-elections, from data already on
  disk. Took the repo from 10 election clusters to 17, which is what made the
  `party_sd` question decidable at all. CLAUDE.md now says five harnesses.
- **Federal seat-swing analogue: measured and NOT wired.** The prior
  departure predicts the next at slope **−0.264** (t = −8.0), negative in all
  six elections, where `SEAT_SWING_COEF` is **+0.7452**. Importing the
  state-fitted coefficient would have applied it with the wrong sign. Worth
  3.5% of seat-level error even correctly signed.
- **Candidate corpus**: 24 elections, 14,959 candidacies, 338 non-major
  breakouts, tracked and reproducible (was 21, untracked, no builder).

## One Nation wins the WRONG SEAT TYPE in our model (2026-08-25)

[reviews/onp-seat-type-asymmetry-2026-08-25.md](reviews/onp-seat-type-asymmetry-2026-08-25.md).
**Nothing changed; this needs a pre-registered test.** Found by asking why our
ONP seats differ from YouGov's — YouGov raised the question, SA 2026 answers
it, and YouGov is not treated as truth anywhere in the review.

Our model gives One Nation **6 of 6 seats in ALP-leaning territory and 0 of 6
in LNP-leaning**. SA 2026 — the only election where the party won at this
scale — was **0 of 5 and 5 of 5**, the exact opposite.

The innocent explanation is ruled out. Among the 20 Victorian seats with the
highest federal ONP vote (our own ordering input) the split is exactly 10/10
by lean, yet mean ONP probability is **0.143 in ALP-leaning seats against
0.036 in LNP-leaning ones**. Gippsland East carries more federal ONP vote than
any seat we give the party except Morwell and scores **0.048**; Melton carries
less than all of them and scores **0.561**.

Mechanism: `shares` adds each party's statewide swing and renormalises, which
takes One Nation's gain **proportionally from everyone**. Where the Coalition
holds 58.9% it stays dominant. SA says otherwise — in the top decile of ONP
gain the Coalition fell **17.69** against Labor's **4.96**, and MacKillop's
Liberal vote collapsed 67.0 → 26.8 as One Nation took the seat.

**Why it matters even if the TOTAL is right**: the same 9.25 expected seats
taken from the Coalition rather than from Labor is a different parliament, and
a total that is right for the wrong reason will not stay right.

Caveats are in the review and are real (n=5, one state, no Nationals in SA, and
the marginal gradient is weaker than the group means). Next step is a
pre-registered test of source-weighted allocation against SA 2026 / WA 2017 /
QLD 2020+2024 / NSW 2019 — a real corpus, unlike the two experiments that
aborted for lack of power on 2026-08-25.

## Awaiting Pete

- **PRs #5–#12 merged** (2026-08-17/18). Every one reviewed before opening,
  and every review caught something the tests could not: stale published
  figures, roxygen under the wrong argument, a correction pass that missed its
  own targets, a crash on a party absent from a seat, and a CI cache that could
  have switched the seat model off behind a green build. **Do not skip the
  gate, least of all on docs-only diffs.**
- ~~VEC data licensing~~ — **resolved 2026-08-18.** The fetched results live in
  `external/elections/`, gitignored beside the anchor clone, and nothing of
  either commission's is committed (verified: git reports the directory
  ignored and tracks none of it). The daily job refetches behind a cache. No
  decision needed; the question only existed while the data had no home.
- **Decide whether the repo goes public.** Private on purpose. Two things are
  outward-facing and should be deliberate: `docs/plans/product-features.md`
  carries critical commentary on named competitors (theswingison, DemosAU —
  the latter also a pollster in our own data), and the scorecard publishes
  named firms' house effects and accuracy. Both defensible; neither should
  appear publicly by accident.
- **Poll data licensing.** The anchor's data is gitignored and not committed —
  verified: no `external/`, no CSVs, no outputs are tracked — so nothing of
  his is republished. His repo has no LICENCE and his site invites use of the
  files, but formal permission is worth having before going public.
- **Answer the four improvement-quiz questions** (context in
  [ANCHOR-MODEL.md](ANCHOR-MODEL.md), "Honest assessment"): demographics in the
  seat model, seat-level preference flows, the 2019 herding problem, and the
  trend-versus-simulator scope call. Two of the four now have measured answers
  — see the seat-type and methodology reviews below — so this is smaller than
  it was.
- ~~Decide whether to transfer South Australia's allocation slope~~ —
  **resolved 2026-08-18, it survives.** Both pre-registered checks pass: the
  Greens-share ordering replicates with a negative coefficient in NSW,
  Queensland and WA, and the magnitude transfer sits at 1.41x against a 1.5
  bar. It beats a uniform allocation by only 0.122 MAE, so trust the One
  Nation **total** rather than any individual One Nation seat. See
  [reviews/onp-allocation-checks-2026-08-18.md](reviews/onp-allocation-checks-2026-08-18.md).
- **Find a signal for a first-time regional independent breakout** (Priestly
  in Nicholls, 23.5%, our worst-scoring miss). Search-interest salience is
  confirmed strong for teal-type candidates but does not move Priestly, Boele
  or Heise at either national or state geography — see below. News-article
  mention counts (GDELT) were the other candidate mechanism raised earlier
  this session and are untried.
- **Carried forward from the archived 2026-08-19/22 sessions, 2026-09-04.**
  Three items with a genuine open question in them, pulled out before the
  narrative around them was archived to
  [backlog/journal-2026-08-19-to-23.md](backlog/journal-2026-08-19-to-23.md):
  - **Centre Alliance / Nick Xenophon Team / SA-BEST classify as `OTH`**, so
    Mayo's winner reads "OTH" in 2016/2019/2022/2025. Deliberately left
    unchanged — the alternative is `IND` (Sharkie functions as a community
    independent) and this is a modelling call, not a bug, that should be
    Pete's rather than a default nobody chose.
  - **WA's flow-matrix fault may be in the matrix, not the state**: it is
    keyed on party class and survivor SET, and a contest whose survivors are
    two LNP candidates should occupy its own cell rather than contaminating
    others. Predicted in advance, not run: conditioning on the survivor
    **multiset** should improve the forecast with WA excluded entirely — the
    one form of this test nothing so far can confound. Needs its own plan.
  - **The candidate model still cannot elect a new independent** (federal
    calibration slope 0.260) after the endogenous fixes were tried and
    refused. The next attempt is exogenous — a named list of confirmed
    independents, seat polls, or market odds — and odds specifically need
    Pete's call, since that is a different kind of input to the model than
    anything used so far.

## Sessions of 2026-08-19 to 2026-08-23 — moved out

Two journals hold the verbatim write-ups, conclusions all in `reviews/`,
`CONSTANTS.md` and the code:

- [backlog/journal-2026-08-22-to-23.md](backlog/journal-2026-08-22-to-23.md)
  (moved 2026-09-06): the AE Forecasts benchmark and the measurement gap it
  found in our harnesses, forecast mode refused, calibration knobs refused,
  gate 1 / refusal M2 / bucket narrowing / candidate-count weighting, the four
  independent refusals re-read and re-measured, the salience signal confirmed,
  seat TCP retained (shipped in `R/seat_sim.R`), nomination zeroing of `IND`
  (shipped in every harness).
- [backlog/journal-2026-08-19-to-23.md](backlog/journal-2026-08-19-to-23.md)
  (moved 2026-09-04): the Victoria 2026 target snapshot as of 2026-08-23 and the
  session write-ups from 2026-08-19 (WA fetched, over-confidence fixed, the
  Others-bias diagnosis, NL3, One Nation seat allocation) through 2026-08-22.

Still-live items pulled out of the moved block rather than duplicated:

- **After nominations close (12 noon, Monday 9 November 2026)**: probe VEC for
  the 2026 nomination list (the URL does not exist yet; reuse the HTML-table
  parser from `fetch_preferences_vic.R`), and revisit **candidate-count
  weighting** — the seat's previous count predicts the next one worse than
  assuming one candidate, so the remedy is worth nothing until the count is a
  fact (`reviews/candidate-count-weighting-blocked-2026-08-22.md`).
- **Victoria 2022 seat TCP ground truth is cached but unparsed**:
  `external/elections/cache/vec-2022-vic/*-results.html`, 87 files, two table
  shapes to branch on. Federal TCP truth already exists
  (`external/elections/aec-fed-tcp.csv`). Needed before our seat TCP can be
  scored against AE Forecasts' 3.69pp MAE.
- Two items from 2026-08-22/23 are **stale, not live**: the unattributed change
  to `output/seat-probs-vic-2026.csv` (the file has been regenerated many times
  since) and the overwritten `output/independent-federal-scores.csv` (output is
  gitignored; regenerate if the historical v4 scores are ever wanted).

## Done

Full write-ups moved to [docs/backlog/journal-2026-08.md](backlog/journal-2026-08.md) on 2026-08-15 — 11.5k characters of completed-stage narrative that every session in this repo was re-reading on every turn. Index of what is in there:

- 2026-08-15 (stage 8): Regional swing structure in the seat model
- 2026-08-15 (stage 7): Seat model — the pipeline is end to end
- 2026-08-15 (stage 6): Fundamentals + projection — it is a forecast now
- 2026-08-14 (session 2, stage 5): Parties folded into "Others" corrected
- 2026-08-14 (session 2, stage 4): Per-cycle volatility — the model now reproduces One Nation leading
- 2026-08-14 (session 2, stage 3): Logit-scale modelling — adopted per party, not globally
- 2026-08-14 (session 2): Hyperparameters estimated, not fixed
- 2026-08-14: Anchor model analysed; package skeleton; Jackman trend; federal and NSW cycles fitted

