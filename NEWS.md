# auspol 0.4.18

**Western Australia is fetched, measured against a pre-registration, and
REFUSED.** Eight Legislative Assembly elections now sit in `external/elections/`,
validated against the WAEC's own declared seat counts -- all 20 election-class
pairs agree exactly. Their transfers were then measured into the flow matrix and
turned down: **-1.57 SE** across nine elections, with the pre-registered
fallback worse still at **-2.23 SE**, and refusal W2 firing at 36.4% against a
30% bar written in advance. `AUSPOL_WA_FLOWS` defaults off, so the published
forecast is unchanged.

The reason is worth more than the data. Western Australia runs Liberal *against*
National in rural seats, so the pair surviving the late rounds is frequently two
Coalition candidates and almost every transfer resolves to LNP by construction:
`ALP -> LNP` is 68.0% there against Victoria's 23.8%. **A difference in the
shape of the contest, not in voter behaviour** -- which is precisely what
pooling flows across jurisdictions assumes away. Queensland passed the same test
at +1.55 SE, so this is the first time that assumption has been measured and
found to cost something.

The first pass ran on a transfer pool missing 42 exclusion rounds and on federal
data predating the classification fix below; all twelve arms were re-run on one
vintage and the conclusion held. Both sets of numbers are recorded in
`docs/reviews/wa-flows-2026-08-21.md` rather than tidied away.

**A bare party code no longer means OTH.** The WAEC publishes a code and no
party name, and `classify_party()` works mostly on names, so bare codes reached
no rule and landed in OTH -- a real class, so nothing failed. The first run
reported "OTH won 6 seats" for what were the Nationals. Codes are now expanded
to names before classification, an unknown code aborts, and three checks make a
repeat visible: names must be the commission's own, our winners must reproduce
its declared seat counts, and the code-to-class table prints every run.

**`Palmer United Party` was classified OTH while `United Australia Party` -- the
same movement under the same man -- was classified OTH_RIGHT.** Word order was
the only difference. That is 5.56% of the 2013 federal vote, and Fairfax is a
seat whose winner read as "OTH". Fixed with Rise Up Australia; fed2013's OTH
share falls **6.86% to 0.99%**. Three further classifier gaps went with it:
codes `IND`/`SFF`/`NATS` reached no name rule, "Liberals For Climate" matched
the `liberal` rule and became Coalition, and the DLP word boundary was written
``, which in an R string is the BACKSPACE character -- an alternative that
could never fire.

**A diagnostic run can no longer overwrite the published forecast.**
`fit_seats_full.R`'s publish guard listed six environment flags by hand and
missed six, so `AUSPOL_SHRINK=0` wrote over `output/seat-probs-vic-2026.csv`
with a materially different, over-confident forecast while the check printed
PASS. `AUSPOL_PARTY_COR=off` was worse: the only line that would have revealed
it sits inside a branch skipped exactly when the flag is off. The list is now
derived from a table, the run prints which flags differ, and a non-default run
**refuses to write the published filenames** rather than reporting after the
fact.

**One date filter, tested, instead of four copies.** The rule that a backtest
may only use data that existed before the election it predicts lived in four
byte-identical copies across the harnesses; one had rotted into a gate that was
defined and never called while still writing under a `-qld` filename, so that
arm was byte-identical to its baseline and would have read as "Queensland makes
no difference to New South Wales". Now `pool_external_flows()` and
`pool_configured_flows()` in `R/external_flows.R`, with tests, proven by
reproducing the pre-refactor federal run byte-for-byte.

Also fixed: `AUSPOL_PARTY_COR=raw` and `=shrunk` both tagged `-cor` so one arm
overwrote the other; `AUSPOL_FLOW_UNC` reached no filename at all and could
never complete; the WA fetcher dropped 42 exclusion rounds behind a collector
variable whose comment claimed it was reported; `score_wa_flows.R` reported
"the same run scored twice" when neither arm existed; and the seat count
reaching the simulation is now a floor rather than a printed line. Seven
constants missing from `docs/CONSTANTS.md` are inventoried, two of them on the
published path.

# auspol 0.4.17

**The published seat forecast is now the candidate-level model.** The two-party
model becomes a cross-check only: it cannot elect a minor party, which is the
whole reason the candidate model exists, yet it was still driving the headline
seat total and the pendulum. Its outputs are now required rather than optional,
so a run without them stops instead of publishing a different model's number
under the same label.

The candidate model covers **87 seats, not 88**. Narracan has no ordinary first
preferences to swing -- its 2022 election failed when a candidate died and the
January 2023 supplementary went uncontested by Labor -- so it is assigned to the
Coalition, stated on the page, and guarded so a second missing seat stops the
build. The pendulum's position (2022 two-party vote) and its shading
(probability against whoever actually runs second) now answer different
questions, which the caption says rather than leaving the chart looking broken.

**ADOPTED: `FP_EXTRA_SD = 2.419`**, a first-preference variance correction added
in quadrature, replacing a multiplicative inflation the residuals directly
refuted (`cor(|error|, posterior sd) = -0.036, p = 0.68`). Published effect:
ALP 90% range 24-51 to **23-51**, One Nation 0-7 to **0-8**, Labor majority
29.7% to **28.7%**; medians unchanged. The directional check was not a
formality -- a similar change was refused hours earlier for raising One Nation's
win probability in 71 of 87 seats, and this one *lowers* its probability of
winning any seat, 0.926 to 0.897.

**CLOSED as a non-defect: the One Nation lag.** Following recent polls instead
of the trend would have been no better (MAE 1.755 against 1.862, a 1.03
clustered-SE difference). The one case in the record shaped like Victoria 2026 --
WA 2017, prior 0.00, polls 10.3, fitted 7.8, actual 4.9 -- had the trend lag the
polls and still finish 2.9 too high. This also retires the theory `ANCHOR_K` was
built and refused on: the day-0 anchor was never the mechanism.

**Fixed, from review.** `run_all.R` keeps only check-code lines from each stage
and discards the rest, so the env-var switches on `fit_seats_full.R` were
invisible in the pipeline log, the Actions summary and the artifacts -- a
leftover `AUSPOL_FP_SD_MODE=growth` would have changed the published forecast
silently. Now emitted as check code `S6`. Also closed: a vacuous `all()` over an
empty class set, and a staleness guard that watched only the driver script and
not the `R/` library it loads.

# auspol 0.4.16

Documentation and tooling; no model change.

**Third attempt at One Nation's seat-allocation uncertainty, refused.** Putting
the noise in WHICH seat gets which share -- rather than in the shares -- keeps
the multiset identical in 200 of 200 draws and the statewide total exact. All
four acceptance criteria passed. It was refused on the pre-registered
one-sidedness bar: the party's win probability rose in 57 seats and fell in 13
(4.4x against a 3x bar), a large improvement on the previous 71:1 and still not
symmetric.

**Why, confirmed empirically rather than argued:** seats that lost probability
had a mean central win probability of 0.154 and share 28.6%; seats that gained
had 0.017 and 19.1%. Gains land on long shots in the convex region of the
win-probability curve, losses on the competitive seats. Preserving the statewide
total does not make a reassignment neutral, because the curve is not linear.

`simulate_seat_contests()` gains `party_draws`, per-draw seat shares for one
party. Inert unless passed; byte-identical output when omitted.

Withdrawn from the previous write-up: a reported +0.108 rise in One Nation's
mean seat count does not reproduce (-0.065 on re-derivation, ranging -0.095 to
+0.498). It was Monte Carlo noise. The refusal rested on the one-sidedness
ratio, which is robust.

# auspol 0.4.15

**One Nation's seat allocation is measured for the first time.** Scored against
South Australia 2026's 47 districts it has an RMSE of 5.045 points (r = +0.779,
beating a flat allocation by 2.5). The code has always said "trust the ONP
TOTAL, not any one seat"; now there is a number.

**Giving it a matching seat sd was NOT adopted.** One Nation's win probability
rose in 71 of 87 seats and fell in 1: adding symmetric noise to a party that is
behind almost everywhere is a one-way ratchet, since upside crosses the winning
threshold and downside costs nothing where it was already losing. The
pre-registered criteria did not catch this -- B3 measured seat-count width,
which does not track per-seat share uncertainty across 88 seats.

`simulate_seat_contests()` gains a per-party `seat_sd`, inert by default and
byte-identical for scalar callers. A named vector that does not cover every
party is refused rather than broadcast -- the first version silently applied
`c(ONP = 5.5)` to all parties with the name discarded.

`CLAUDE.md` now requires every pre-registration to name, in advance, the
directional side effects that would disqualify an apparent win. Twice in three
experiments the real decision came from something found after the results.

# auspol 0.4.14

Two pre-registered experiments, both ending in **do not adopt**, and a guard
that could not fail.

**The independents fix failed its own acceptance criterion and was reverted.**
Exempting a live independent's seat from the `OTH` scaling lifted South-West
Coast's independent from 16.3% to 23.1% -- the category error is real -- but
One Nation is projected at 26.7% in that seat, so the independent is still third
and still excluded. A1 required 10% win probability and got 0.06%. The binding
constraint is the One Nation seat allocation, not the scaling.

**NSW's red build is diagnosed.** `fit_nsw.R:132` gives per-cycle volatility
only to parties with 15+ polls in the cycle; One Nation has 8, so it is fitted
with the generic default random walk while every other party gets its own. Its
fitted 19.52 sits below every poll since February. Victoria's One Nation has 19
polls, clears the floor, and its gap closed on its own to 2.39 -- same party,
same surge, opposite outcomes, decided by a threshold. `NL3` is not relaxed.

**`build_page.R`'s staleness guard now checks the producing script**, not just
the poll data. A reverted experiment left a seat-probability CSV that was newer
than the polls and so passed the old guard, and publishing it would have shown a
0.06% independent chance the code cannot produce.

# auspol 0.4.13

Documentation only; no model change.

**Independents cannot win a seat, and it is a construction defect.** Across
20,000 draws they win in 6, across 3 of the 87 seats the model covers.
`fit_seats_full.R` scales `IND` to the forecast `OTH` total because it is one of
the two classes the trend does not model, while One Nation is projected
separately from 0.22% to ~20%. In Mildura that turns an independent's 41.2% into
25.2% and One Nation's nothing into 31.1%, so the independent falls to third and
is excluded during the count -- the seat reads LNP 0.991 / ONP 0.009 with no
`IND` entry. A personal, seat-specific vote is not a statewide minor-party
bucket.

Zero independents is a defensible forecast for 2026, since the Mildura and
Shepparton members both lost in 2022. Zero by construction is not. A fix needs
pre-registering, and the obvious repair -- carrying the vote forward unscaled --
would over-call seats where the independent has retired.

Also recorded: primaries use a uniform additive swing under `pmax(0, ...)`, so
Labor's ~12-point fall projects exactly 0.0% in Mildura and Shepparton.

# auspol 0.4.12

**"Others" now means one thing per cycle.** When a party is polled but not
fitted, `refold_unfitted()` adds its reported share back into `OTH` on the rows
that break it out, so the column stops mixing two definitions within a cycle.
Total first-preference MAE 1.8617 -> 1.8246 against a pre-registered 0.02 bar.
Not just inflation: where the fit was already above the actual it made things
worse, which is what a definition fix does and an artefact does not. The
published Victorian forecast is unchanged.

**The party-inclusion floor was tested and stays at 8.** Lowering it is
monotonically worse. Raising it to 15 beat the bar and was refused because it
would drop One Nation from NSW 2027 at 21.0% -- a refusal criterion added AFTER
the result and NOT pre-registered, so that outcome is flagged as provisional
rather than settled.

**`fit_federal.R` could not run at all**, and the pipeline reported the crash as
a routine check failure. Stage failures are now classified by
`classify_stage_failure()` on positive evidence, returning "unclassified" rather
than guessing -- the two previous versions guessed and were wrong in opposite
directions, the second of which would have labelled S5, G2, G3 and G7 as
crashes.

Victoria 2026's One Nation poll-tracking gap has fallen to 2.39 against a bound
of 2.5 on fresher polling, so the published cycle no longer breaches. NSW 2027
still does, at 5.15.

# auspol 0.4.11

**The endpoint-sum check is replaced by a per-party one.** `L3`/`FL3`/`NL3`
required each cycle's fitted first preferences to sum to 100 +/- 5; NSW failed
at 94.1 and kept the scheduled job red. The sum was the wrong question -- the
model fits parties independently with shrinkage, forcing the shares to sum was
measured at 0.33 MAE, and a sum cannot say which party is off or by how much.
They now assert each party's fitted endpoint sits within 2.5 points of its own
last 90 days of polling, a bound derived by a rule committed before it was
computed (`docs/plans/prereg-per-party-poll-check.md`).

Every breach is One Nation, and the size orders by how many polls name the
party: federal passes at 0.85 on 45 polls, Victoria breaches at 2.78 on 10, NSW
at 5.15 on 3. Federal is the control -- the model tracks the party fine when it
has data.

The check also caught something that had been true all along with nothing
reporting it: **NSW 2023 polls One Nation at 5.67 and never fits it.** A party
under a script's inclusion floor used to have no row in either check, so it was
absent rather than flagged. `poll_tracking_check()` now iterates the union of
fitted and polled parties.

`fit_vic.R` reports its breach rather than halting, because it is the target
stage and halting publishes nothing -- but it now records the breach to
`output/L3-BREACH.txt` and `run_all.R` fails on that after the page is built.
Previously the run went red only because NSW happened to breach the same check;
that dependency is gone. The page's One Nation note is rendered from the check's
own output rather than hand-typed.

# auspol 0.4.10

**The "Others" bias is a fifth the size it was reported to be.** The −3.60 that
motivated `docs/plans/prereg-others-bias.md` does not reproduce: on the 33 past
cycles whose recorded results actually sum to 100 it is **−1.02**. The rest
came from cycles averaging 111, which double-count parties into the listed
Others row. `scripts/test_others_bias.R` checks this reproduction FIRST and
refuses to read T1-T3 as answers when it fails, which is what caught it.

Of the three pre-registered causes, only the shared-pollster-miss test points
anywhere: the fit lands 0.87 points from the final month of polling while that
polling is 2.11 points from the result. Its 0.5 firing bar was not
pre-registered and the measured 0.41 clears it narrowly, so the ratio is the
result rather than the verdict -- but both branches of the decision rule leave
the trend model untouched, so the action does not depend on it. The page gains
a caveat beside the Others figure; the model is unchanged.

`load_eventual_results()` now drops identical duplicate rows and refuses rows
that share a key while disagreeing. `eventual-results.csv` carried WA 1993
twice, all six rows duplicated verbatim, double-counting that cycle in every
mean over the table -- something the loader's row-count floor could never
catch, since duplicates push the count up.

# auspol 0.4.9

**The duplicate-check-code guard was passing vacuously.** Codes were given
region prefixes (`L3` Victoria, `FL3` federal, `NL3` NSW) so no two scripts
claim the same one, but `run_all.R`'s filter still matched a single letter and
a digit, dropping every renamed code before the extractor and the registry saw
it. A failing stage also returned before registration, so its codes never
registered at all -- which is why NSW's `N1`-`N3` and `NF1` were invisible.
Both fixed, and proven by injecting a real collision rather than assumed.

A validation stage that fails no longer halts the run, so a broken 2027 NSW
cycle does not block the 2026 Victorian forecast. The run still exits
non-zero, the failure now carries its cause into the summary, and a stage that
crashes before reaching its checks is labelled differently from one whose
pre-registered check failed on the merits.

`ARCHITECTURE.md`'s check registry listed `V1`-`V4`, `H1`-`H4`, `B2` and `B3`,
which no script emits, and omitted `FF1`, `FO1` and `N1`-`N3`, which do.
Replaced with a per-script table of codes actually emitted.

`docs/plans/prereg-others-bias.md` replaces the planned trend-coupling work:
the sum-to-100 failure was measured to be an Others bias, not a coupling
problem.

# auspol 0.4.8

**The candidate-level model is now the published seat forecast.** The two-party
seat step is kept as a running cross-check rather than archived.

## The page

Two new blocks:

- **Seats by party** — bars with 90% ranges and a majority line. ALP 41
  (24–51), LNP 38 (29–54), GRN 5 (3–7), ONP 3 (0–7).
- **Seats in play** — 29 seats where the favourite is under 80% or a minor
  party has a real chance.

Every bar is directly labelled. The palette validator puts One Nation orange
against Greens green at ΔE 6.1 under protanopia — inside the band legal only
with secondary encoding — and One Nation's contrast against the surface at
2.97:1. Labels discharge both, so nothing on either chart depends on telling
two hues apart. Red against green is fine; orange against green is the risky
pair, which is the opposite of the intuition.

## S5, a check that is proven to fail

The two-party model cannot represent a non-major winner, which is why it no
longer publishes, but it is the only independent estimate of Labor's seat
count and costs seconds. S5 compares the two every run: median gap at most 5
seats, ratio of 90% widths between 0.7 and 1.4.

Verified against the real before-and-after: the pre-fix run gives a width ratio
of 0.57 and FAILS; the corrected run gives 0.96 and PASSES. The medians agreed
in both, so a median-only check would have passed the broken run.

## Fixes

- **The page had been shipping mojibake.** Every en-dash rendered as `â€"`
  because the document declared no character set. The declaration must be the
  **first line** — it is only honoured within the first 1024 bytes and this
  document has no `<head>`. Placed at line 116 it was ignored, the page rebuilt
  and `G1` passed with the mojibake unchanged. Nothing automated catches this:
  `G1` verifies blocks drew, `R CMD check` never reads HTML, and a parser
  accepts mojibake happily. Found by opening the built page and reading it.
- **A poisoned CI cache could have disabled the candidate model and S5
  silently.** The combined `actions/cache` saves in a post step that runs even
  after an earlier step fails, so a partway fetch failure would cache the
  partial directory under a key that does not change until the fetch scripts
  do. Split into restore and save gated on success, and the skip message now
  carries its check code so it reaches the run summary.
- **S5 was comparing different seat universes**, 87 against 88 — Narracan has
  no ordinary 2022 first preferences. A real divergence could have hidden
  behind the offset.
- **The new seat outputs bypassed `build_page.R`'s staleness guard**, so a
  leftover from an earlier run could have published old probabilities under
  today's date. Present-but-stale is now an error.
- The duplicate `pull_request` CI trigger is removed. It fired on the same
  commit as `push` three seconds apart and hung 4 times out of 4, once for 37
  minutes, while `push` succeeded 4 times out of 4.

# auspol 0.4.7

The candidate-level seat simulation moves from a session scratchpad into the
package. **No published number changes**: `simulate_seats()` and the page are
untouched.

## New exported functions

- **`build_flow_matrix()`** — turns observed transfers into preference rates
  keyed on the excluded party **and the set of survivors**, because where a
  party's preferences go depends on who is still standing. Cells below `min_n`
  are withheld rather than returned, and every cell appears in a coverage
  table with its event count, so a rate resting on two exclusions is
  distinguishable from one resting on fifty.
- **`distribute_preferences()`** — runs a single seat's count: exclude the
  lowest, transfer at the estimated rate, repeat to a final two.
- **`simulate_seat_contests()`** — simulates every seat many times and returns
  a per-seat win probability by party.

Together these let a Green, an independent or One Nation win a seat. The
published two-party model gives those outcomes probability exactly zero, not
because they are unlikely but because a two-party margin is the only thing it
knows about a seat.

**None of the three needs external data.** The VEC and ECSA election data
cannot be committed pending the licence question, so the functions were
designed to take a plain transfers table and be fully testable without it.
55 tests across the three files; 300 in the suite.

Performance: 87 seats × 2,000 simulations in **9.7 seconds**, so a
20,000-simulation run is about 100 seconds. Parties are held as integer indices
and the survivor set as a bitmask; seven million named-vector lookups would
have made this slow enough that nobody re-runs it.

## Fixes

Two defects found by the pre-PR review of this same code, both reproduced
before fixing and both covered by tests verified to fail against the pre-fix
version:

- **`simulate_seat_contests()` crashed** on any flow cell naming a party that
  does not contest the seats being projected. `pidx` is an atomic vector, so
  `pidx[["missing"]]` throws rather than returning `NULL`, which made the
  adjacent `is.null()` guard dead code. Historical transfer data routinely
  contains exclusions of parties absent from a given seat set.
- **`distribute_preferences()` silently lost votes** when `shares` carried a
  duplicate name. Exclusion removes by name, so two entries labelled `IND` were
  deleted in one pass while only the smaller was redistributed — 15 of 100
  votes vanished and the count terminated a round early. Duplicates are now
  refused with the offending names reported.

## Deliberately not included

The One Nation seat allocation. Its ordering beats a uniform allocation by only
0.12 MAE and its magnitude is borrowed from South Australia's observed spread,
making it the weakest link in the prototype result. It needs its own
pre-registered treatment before anything publishes.

# auspol 0.4.6

A working seat-by-seat simulation in which minor parties can win, plus a
labelling fix to the marginal-seats output.

## The headline

The published model cannot represent a minor party winning a seat: it
simulates 83 of 88 as Labor-versus-Coalition and assumes the other five are
held, with no uncertainty. A prototype simulation now covers **87 districts
candidate-level**, distributing preferences the way the count runs — lowest
excluded, transferred at rates measured from real counts conditional on who
remains, until two are left.

| party | median seats | 90% range |
|---|---:|---|
| ALP | 41 | 32–48 |
| LNP | 35 | 29–42 |
| GRN | 5 | 4–7 |
| ONP | 5 | 1–12 |

25 seats have a minor party above 10%. The Greens hold their four and gain
Pascoe Vale at 55%; One Nation's best is Melton at 86%. Yan Yean is the
tossup, a genuine three-way at LNP 44 / ALP 31 / ONP 25.

> **Superseded.** These probabilities came from a run that rebuilt the
> statewide distribution instead of inheriting the projection, making it about
> 40% too confident. Corrected figures are in
> `docs/reviews/seat-sim-working-2026-08-18.md`; Melton is 57%, not 86%.

**Not published**, and not a replacement for the two-party model. It runs from
data fetched into a scratchpad and the VEC licence question is unresolved.

## Data

**ECSA has a public JSON API** — no key, no browser. The acquisition plan
written before checking had assumed the Angular results site required browser
automation and deprioritised South Australia for it. Reading the app's own JS
bundle found the endpoint in minutes; `HAChange/2026-03-21/0` returns 2.3 MB
carrying `finalDistribution` for all 47 districts. **294 exclusion events**,
against 97 across 16 districts from the Wikipedia sample the work had been
stuck on.

## Fixes

- **`simulate_seats()` now returns `alp_tpp_proj`**, the seat's 2022 two-party
  share plus the projected statewide swing, and `scripts/fit_seats.R` prints
  `alp_2022` and `alp_proj` with the swing stated above the table. The single
  unlabelled column made a seat on 57.2 beside a 50.2% win probability look
  like a bug; on a −7.0 point swing it is exactly right.
- **Per-party statewide uncertainty is taken from the fitted trend** rather
  than a flat assumed 2.0 points, scaled by the factor the two-party sd grows
  by to election day (×1.89 at 102 days out), with draws renormalised so the
  parties trade against each other. The answer barely moved, which says the
  assumption had been fair but underived.

## Two bugs worth recording

- **A sparse fallback row invented an answer.** With no observed cell for Labor
  excluded while the Greens and One Nation stand, the pooled Labor row was used
  — and it shows Greens 0.0%, because that configuration never arose in South
  Australia. Renormalising over the survivors handed every Labor ballot to One
  Nation, which is why the first run had One Nation winning Richmond. Absence
  of evidence had become certainty of zero. Every row is now smoothed toward
  uniform.
- **The SA-fitted One Nation allocation does not transfer to Victoria**, which
  settles a question that had been left open for Pete. Its intercept could not
  put One Nation below about 15% in any seat, and South Australia contains no
  seat resembling Brunswick to fit against. Replaced with ordering from
  Victorian federal 2025 divisions and magnitude from SA's observed spread at a
  comparable statewide level.

# auspol 0.4.5

Measurement and corrections. No model behaviour changes, no forecast number
moves. One new script.

## Added

- **`scripts/audit_flow_record.R`** — reports carried-forward duplicates in the
  observed preference-flow record, under two explicit definitions, with the
  `as_of` date printed. Exists because the first audit of this was ad hoc and a
  later run of the same logic disagreed with figures already written into
  `docs/reviews/`. An audit whose answer depends on when it ran is not an audit.

## Measured

All 88 VEC districts fetched and parsed: **452 exclusion events across 76
districts, every one reconciling exactly** against the excluded candidate's
pile. Candidate-level, so each minor party and independent is excluded
separately. The data is **not committed** — the VEC publishes no licence and
its copyright page 404s, and `R/paths.R` already states this convention for the
anchor's data.

- **The model's Greens preference flow is 4.3 points too generous to Labor**:
  79.2 measured across 29 districts and 211,842 ballots, against 83.5 used.
  Not changed — the estimator producing 83.5 was chosen by pre-registered
  temporal backtest, and substituting one election's observation after the fact
  is what that pre-registration prevents.
- **13.4% of the observed flow record is carried-forward duplicates.** Western
  Australian Nationals sit at exactly 5.0 for ten consecutive elections.
  Victorian Others is 49.25 three times. One is demonstrably wrong: Victorian
  2022 Greens, recorded 81.94, measured 79.2.
- **The estimator survives cleaning.** `mean_last5` wins all three
  pre-registered variants. But `last_in_region` sat 0.048 MAE off the winner on
  the raw target set and fell to 0.727 behind — second place to sixth — once
  carried-forward targets were removed. Its second place was substantially an
  artefact of duplicated data.
- **The OTH bucket blends opposite behaviours**: independents flow to Labor at
  61.1%, minor-right at 35.4%, against a single assumed 48.872. Per-seat implied
  flow ranges 37.1–58.7. This affects nothing published — `simulate_seats()`
  reads the anchor's notional margins, which come from the actual count — but it
  is a prerequisite for any primary-vote rebuild.

## Corrected

Three sizing errors, all found and fixed this cycle:

1. **"Correcting the Victorian flow record is worth 0.564 points of published
   two-party vote."** It is worth **zero**. `estimate_flow()` averages the five
   most recent observed elections pooled across regions, and Victoria 2022 is
   the *seventh* most recent Greens observation — the estimate is built from
   SA 2026, FED 2025, WA 2025, QLD 2024 and NSW 2023.
2. **"Contamination explains why the linear trend ranks sixth."** Tested and
   false: it ranks 6, 5, 7 across the three variants.
3. **The contamination figures themselves, twice** — first counting rows the
   observed-election filter never uses, then counting the 2026 Victorian rows
   (the election being forecast) as observed.

## Withdrawn earlier, recorded here

The claim that this project's preference handling beats AE Forecasts and
theswingison. The comparison was made on the wrong axis: ours estimates a
scalar share to Labor, theirs is keyed on who has been excluded and who
remains. Measured flows swing by tens of points with that configuration.

# auspol 0.4.4

Corrections only. No code behaviour changes, no forecast number moves.

## Claims withdrawn

Prompted by Pete, 2026-08-18: this project claimed to beat its two reference
implementations while not simulating seats at all.

- **"Our preference flows beat AE Forecasts and theswingison."** Withdrawn from
  `docs/NEXT-STEPS.md`, `docs/reviews/seat-methodology-critique-2026-08-16.md`
  and the package source at the top of `R/flow_model.R`. The comparison was
  made on the wrong axis: what we estimate is a **scalar per party, its share
  to Labor** — a two-party quantity — while theswingison's twelve rules are
  keyed on who has been excluded and who remains, which is how a seat is
  decided. A hand-authored rule modelling the right mechanism beats a
  well-estimated number for the wrong one. What survives is narrower and true:
  ours is the best estimator *of the scalar*, and the scalar is the
  approximation.

- **"Simulating every seat changes the seat count by almost nothing."**
  Withdrawn, along with the "correctness work, not accuracy work" framing that
  followed from it. It rested on an invented 50/50 split of Liberal preferences
  between One Nation and Labor — the transfer deciding every ONP-vs-ALP seat,
  and never measured. Measured from SA 2026 distributions it is **62.7% to One
  Nation**. The seat-count effect is now recorded as **unknown**.

- **"Their poll aggregation is weaker than ours."** Downgraded to its parts.
  We do remove systematic house effects, via a poll-count-weighted soft
  sum-to-zero prior (`R/trend.R:119-124`) — real and shipped. That theirs does
  not remove them rests on a reading of their published method that was never
  independently verified. And **our accuracy has never been compared against
  either reference, on any output.** Every comparison in these docs was a
  mechanism argument promoted to a verdict with no measurement in between.

## Evidence added

The estimated preference flow matrix now lives in
`docs/reviews/onp-allocation-sa-2026-08-17.md` with provenance: 97 exclusion
events from 16 SA 2026 districts, 28 conditional cells with event counts and
vote totals, and the arithmetic behind the 62.7% figure. Those numbers had been
quoted in two files with the derivation recorded in neither.

Measured conditional flows, against the model's fixed values:

| transfer | to Labor | model's fixed value |
|---|---:|---:|
| GRN excluded, ALP vs LNP remain | 74.5% | 83.5 |
| GRN excluded, ALP vs ONP remain | 81.5% | 83.5 |
| ONP excluded, ALP vs LNP remain | 57.0% | 33.7 |
| ONP excluded, ALP/GRN/LNP remain | 19.3% | 33.7 |

The same section records what the matrix cannot settle: most cells are n ≤ 2,
49 transfers in an 88-seat trial run resolved to no observed cell at all, OTH
is still collapsed to one bucket rather than the separate candidates a real
ballot carries, and everything is estimated from a single state and a single
election. Settling the seat count needs distribution-of-preferences data across
many elections — the real blocker on the rebuild.

# auspol 0.4.3

One fix. No forecast number moves — the defect was latent, not active.

## Fixes

- **The published seat total and the diagnostic seat total could diverge.**
  `scripts/fit_seats.R` added a non-classic Labor-held term to the seat count
  and `scripts/build_page.R` did not, so the published page would have
  under-counted Labor by one for every non-classic seat it held. The two
  agreed only because no non-classic seat is Labor-held in 2026 and the
  constant evaluates to zero.

  Fixed by moving the arithmetic into `simulate_seats()` rather than adding
  the missing line to the second caller — duplicating it across sister scripts
  is what allowed the drift. The function now returns **`alp_total`** (the
  publishable figure) and `alp_nonclassic` alongside `seats_won`, which keeps
  its old meaning of classic seats only and is retained for the S1/S4
  calibration and R2/R3 regional-layer diagnostics that genuinely want it.

  The regression test was verified to **fail on the pre-fix code** — 4
  failures, confined to the new test — and asserts the reverse case as well,
  so the correction cannot inflate a seat count where no non-classic seat is
  Labor-held.

  `fit_seats.R` output is unchanged: median 39, 50% 33–45, 90% 23–51,
  P(majority) 26.0%.

- **`?simulate_seats` documented the new field under the wrong argument.** The
  roxygen paragraph saying which of the two totals to publish sat directly
  under `@param region_sd` with no separating tag, so roxygen folded it into
  that argument's description. `R CMD check` cannot detect this — it is not a
  signature or default mismatch — so it would have shipped as documentation
  describing `alp_total` as though it explained regional effects. Caught by the
  pre-PR review gate.

# auspol 0.4.2

Docs only. No code changes, no forecast recomputed — but one published figure
was already wrong and is corrected.

## Corrections

- **Four stale seat figures in `docs/NEXT-STEPS.md`.** It read ALP 35 of 88,
  50% 29–41, 90% 19–49, P(majority) 14.2%. The published values are **39,
  33–45, 23–51 and 26%** (`output/vic-page-data.json`, reproducible from
  `scripts/fit_seats.R`). These were the pre-flow-update numbers: when the
  preference-flow estimator moved published two-party 46.8 → 47.8, the TPP line
  was updated and the seat line was not. The queue therefore described a
  materially more pessimistic forecast than the model produces, with
  P(majority) at roughly half its true value. Caught by the pre-PR review gate
  — after the stale figure had already propagated into two new documents,
  because they cited the hub rather than `output/`.

## Measurements recorded

Five pre-registered tests on whether the seat model should simulate every seat
from primary votes, each committed before its run: two adopted, one negative,
one void, one inconclusive. Full evidence in
`docs/reviews/onp-allocation-sa-2026-08-17.md` and
`docs/reviews/oth-flow-composition-2026-08-17.md`.

- **Adopted:** a One Nation surge is allocated across seats by a *linear* form
  on the prior minor-right vote (leave-one-seat-out MAE 4.171 against uniform
  allocation's 6.306, validated on SA 2026). The *proportional* form
  pre-registered first failed outright at 9.298 — the predictor correlates
  0.735 with the truth and the link function destroyed it.
- **Negative:** prior LNP share predicts nothing at seat level (LOO correlation
  −0.006), despite the One Nation surge genuinely coming out of the Liberal
  vote statewide.
- **Sized:** the `classic` flag (`R/seats.R:55-56`) reads 2022's final-two
  pairs forward. On a first-pass simulation One Nation reaches the final two in
  39–44 of 88 seats and Labor fails to in 23–24. But minor-right voters send
  only 0.348 of their non-Labor preferences to One Nation against a threshold
  near 0.5, so it contends in half the chamber and loses on preferences. The
  rebuild is **correctness work, not accuracy work**.
- **Inconclusive:** whether the single OTH flow suits a bucket One Nation has
  been pulled out of. Both registered estimands proved void and disagreed by
  4.2 points in opposite directions; aggregate distribution tables carry no
  vote provenance, so the quantity is not recoverable from them at all. The
  concern stands, unevaluated.

## Incidental

- Victoria did not redistribute — all 88 district names in `2026vic.txt` match
  the 2022 results — so seat-level first preferences apply directly and the
  previously queued booth-level acquisition is not needed for this work.
- First independent check of two preference flows, from a different state and
  data path: GRN 86.7% against the model's 83.5%, ONP 32.4% against 33.7%.
- Recorded unfixed: `scripts/fit_seats.R:173-175` adds `alp_extra` to the seat
  total while `scripts/build_page.R:242-244` does not. They agree only because
  it currently evaluates to 0.

# auspol 0.4.1

No forecast numbers change. Every fix here closes a gap between what the model
does and what the machinery around it claimed it does.

## Fixes

- **`G7`: the published fit is now checked.** `fit_vic.R`'s `L2`/`L3`
  structural checks run on `fit_vic.R`'s own fit, which uses per-cycle sigmas
  and per-pollster noise factors the published one does not. Since the page
  moved to its own fit, those checks were guarding a model nobody publishes:
  the published fit could have had a band below zero or first preferences
  summing to 80 with every L-check still reporting PASS. `G7` applies the same
  test where the published fit is made, and is verified to fail on both.
- `G7` itself shipped unable to fail, and was fixed: an `| is.na(lo95)` clause
  meant an *unverifiable* band counted as a pass.
- **Two binomial reference sample sizes, deliberately.** `BINOMIAL_REF_N`
  (2500) wherever a check halts a run or the page makes a claim about a named
  firm; `BINOMIAL_SENSITIVE_N` (1500) where a signal is only reported. The
  scorecard previously used the sensitive value for a **published** claim about
  named polling companies, which is the aggressive setting on the one output
  where a false positive costs someone else. No literal survives outside the
  definitions, including in printed messages — one said "n=1500" while
  computing with 2500.
- **Scorecard prose.** *Variability* was described as scatter against sampling
  error; it is a relative peer comparison where 1.00 is the average firm. The
  absolute measure exists but writes to a file the page never reads.
- The page now states which pollster figures the forecast uses: it separates
  lean from the trend, and does **not** weight polls by variability.
- `ARCHITECTURE.md` records the `G`-code registry, since three separate greps
  for those codes came back incomplete and one of those misses is why `B1`
  meant two different things.

# auspol 0.4.0

Every hard-coded number in the model is now inventoried, and the ones that
could be estimated have been.

## Constants

- `docs/CONSTANTS.md` -- the complete inventory: every constant in `R/` and
  `scripts/`, what it does, whether it *can* come from data, and its status.
  A constant missing from that file is a bug in that file.
- **`szc_sd_pts` 0.3 -> 1.5** -- how far the polling industry as a whole may
  sit from the truth. Two independent lines agree: the consensus of final
  polls against the result across 147 party-elections gives sd 1.61, and
  held-out error over a pre-registered grid falls 2.0850 to 2.0588.
- **`sigma_house_pts` stays at 3** -- the outright minimum of a smooth U, so
  the hand-set value was right. Tested rather than assumed.
- `tune_prior()` / `report_tuning()` -- shared machinery for moving a constant
  from asserted to estimated, so each new one costs a grid and a
  pre-registration rather than a copied script.
- Three constants (`k0` twice, `clip`) **cannot** be judged by forecast error,
  because none of them reaches the forecast. Recorded with what they need
  instead.

## Measured negative results

- **The fuller trend model does not forecast better.** Per-cycle volatility
  gained 0.0041 held-out MAE against a 0.02 bar, for 33x the runtime, with
  alternating signs by horizon. The published forecast loses nothing by using
  the simpler model.

## Performance

- The backtest computed the full posterior variance ~200 times and read only
  the means. `fit_trend(want_var = )` makes that optional: **40% faster on the
  hot path, identical to machine precision**; the pipeline drops 122 s to 96 s.

## Fixes

- The page drew its chart from one model fit and its headline from another --
  first preferences up to 0.54 points from the fit the headline was built on,
  so a reader adding them up could not reproduce the result. One fit now feeds
  the chart, the first preferences and the headline.
- `overrides` passed through the new `...` plumbing raised an argument-matching
  error that `tryCatch` swallowed into a `NULL`, which the backtest recorded as
  "too few polls" -- a bug removing election-horizon pairs with a reassuring
  reason attached.
- `house_effects$sd` was silently dropped rather than set to `NA` when the
  variance solve was skipped; `data.table` removes a column assigned `NULL`.
- `scale_breaches()` returned `NA` on a band-less fit, so its caller's length
  check did not short-circuit and the validity guard was silently disabled.
- `tune_prior()` accepted a parameter name belonging to a different function,
  which would have tuned the wrong quantity and reported a confident verdict
  about an unintended experiment.

# auspol 0.3.0

The forecast's assumptions are now estimated from the record rather than taken
as given.

## Preference flows are estimated, not assumed

- `estimate_flow()` / `estimate_flows_for()` / `is_observed_election()` —
  where a minor party's preferences go is the largest lever on a two-party
  figure (at 21% of the vote, one point of flow moves it 0.21), and it was a
  constant read from a hand-maintained file. It is now the mean of the party's
  five most recent observed elections, pooled across regions, and it moves as
  elections are held.
- **The estimator was chosen by strict temporal backtest**, every election
  predicted using only elections held strictly earlier, across 103 elections.
  Eleven candidates. A linear trend — the obvious choice, and the one this was
  first built around — came sixth (MAE 5.282 against 4.815). Leave-one-out had
  endorsed it, wrongly: it lets a later election inform an earlier prediction. Every recency-weighted
  scheme also lost, and monotonically in the half-life, because exponential
  decay never fully discards a 1998 flow of 54% while behaviour has drifted to
  26%.
- `scripts/backtest_flows.R` re-runs that comparison on every pipeline run and
  fails as check **G3** if the adopted estimator stops winning. The choice is
  itself made from data, so it needs re-testing as new elections land rather
  than being correct once and unexamined after.
- Victoria: One Nation 25.5 → 33.7, Greens 81.9 → 83.5, Others 49.3 → 48.9.
  Labor's published two-party moves 46.8 → 47.8.
- A state-versus-federal difference in One Nation flows was tested and
  rejected: +1.10 points, se 1.90, p = 0.57, and worse out of sample.

## Fixes

- Preference-flow leakage in the historical backtest, arriving through a new
  door: estimation counts elections that have "already happened", which
  defaulted to *today*, so backtesting 2018 used flows informed by 2022 and
  2025. Caught because the fitted mix weight moved when recorded historical
  flows cannot. `as_of` is now pinned to each cycle's start.
- data.table NSE shadowing, for the third time here: a filter written
  `flows[flows$party == party, ]` binds the bare name to the column, matches
  every row, and hands every party the pooled mean of all 202 estimates.

# auspol 0.2.1

## Publishing

- The page now names a recent change of government leader, the date, and how
  many polls have been taken since — computed from the data, so it cannot go
  stale, and shown only while the change is recent enough to be
  under-observed. Victoria changed premier on 2026-07-28, four months out,
  and the forecast had three polls covering it while saying nothing about
  that. The model has no leader term by measurement, not oversight: one
  tested as a fundamentals predictor across 56 elections came back at
  p = 0.52.
- `tools/check-page.js` runs the published page's own JavaScript against a
  stub DOM and fails the build if any block did not draw, reported as check
  `B1`. The page had no test at all, having once shipped with three of four
  charts silently missing; the per-block guards added afterwards stopped one
  failure cascading and thereby made a single missing chart quieter still.
  Validated against a page corrupted into the exact shape that caused the
  original incident.

## Running it

- The forecast refreshes daily on a schedule and deliberately does not
  publish: it runs, checks, reports the numbers and every pre-registered
  check, and uploads the page for a human to look at.

# auspol 0.2.0

The forecast is published, the pipeline runs in one command, and both are
checked on every push.

## Publishing

- `scripts/build_page.R` + `scripts/page-template.html` produce a
  self-contained `output/victoria-2026.html`: no external requests, so it
  renders offline and under a strict content-security policy. It leads with
  the pendulum and publishes the calibration record, the four rejected
  improvements, the pollster scorecard and five caveats alongside the
  headline numbers.

## Running it

- `scripts/run_all.R` runs every stage in the one order that works, each in
  its own R process, echoing every pre-registered check and stopping on the
  first failure. `--quick` skips the two slowest cycles; `--stale-ok`
  proceeds on old data. About five minutes.
- `check_poll_freshness()` / `poll_data_age()` — every poll comes from a
  third party's hand-maintained CSVs, and nothing previously noticed if that
  clone stopped being updated. Warns past 21 days, stops past 60, and
  distinguishes "our copy is old" from "no new polls published" using the
  source file's own modification time.

## Checking it

- CI runs `R CMD check` (`--as-cran`, warnings are errors) and the tests on
  every push, with a floor on assertions executed so an all-skipped run
  cannot pass silently.
- `ARCHITECTURE.md` records the load-bearing decisions and the five hazard
  classes that have bitten this codebase.

## Fixes

- The page shipped with three of four charts silently not drawing: jsonlite
  serialises a data.table as an array of row objects and the template read
  them as column arrays, so one throw took out the rest. Drawing blocks are
  now isolated and a failed one says so visibly.
- A missing projection would have rendered a fabricated "0% chance of a Labor
  majority", because JavaScript coerces `null` to `0` in arithmetic. Missing
  values now render as an em dash, and the build asserts finiteness first.
- A region whose poll dates fail to parse was silently exempt from the
  stale-data gate, since `which()` drops `NA` rather than matching it.
- `run_all.R` dropped every stage `warning()` — the mechanism this package
  uses for "a human should look".
- `skip_if_no_anchor()` rebuilt a path by hand instead of resolving through
  `anchor_data_path()`, so a CI dry-run reported green while checking a
  different directory.

# auspol 0.1.0

First release with a complete forecast pipeline: **polls → trend → projection
→ seats**, with prediction intervals validated as calibrated. Live target is
Victoria, 28 November 2026.

## Model

- `fit_trend()` — Jackman-style latent voting intention: daily random walk
  plus pollster house effects. All-Gaussian, so the posterior is exact via one
  sparse solve; seconds per cycle, no MCMC.
- Hyperparameters estimated rather than assumed. `estimate_trend_sigmas()`
  maximises the exact log marginal likelihood; `estimate_cycle_sigmas()`
  re-estimates per cycle, shrunk toward the pooled value, because a party's
  volatility belongs to the cycle and not to its whole history.
- Vote shares modelled on a **logit or points scale, chosen per party** by
  comparable log evidence. The transform's Jacobian is included, without which
  the two are densities in different units and not comparable at all.
- `estimate_firm_factors()` — per-pollster noise weighting.
- `unfold_others()` / `fit_cycle_unfolded()` — corrects polls that fold a
  party (typically One Nation) into the "Others" line, detected arithmetically
  and imputed only where that party was actually measured.
- `fit_trend(nu = )` — optional Student-t observation noise by iteratively
  reweighted least squares. Off by default; see below.

## Forecast

- `fit_fundamentals()` — expected result from history alone (previous result,
  long-run average, incumbency, years in office, federal alignment) by ridge
  regression, penalty chosen leave-one-election-out. Two-party MAE 3.05
  against 4.93 for "assume the last result".
- `project_result()` — mixes trend and fundamentals by days-to-election. The
  trend at each horizon is refitted on only the polls available then.
- `simulate_seats()` — statewide draw, regional block effect, per-seat
  residual.
- `pollster_scorecard()` — per-pollster lean, noise against the binomial
  sampling floor, and final-poll accuracy.

## Measured negative results

Four principled additions were built, tested out of sample, and are documented
in `docs/NEXT-STEPS.md` so they are not rebuilt:

- Fat-tailed poll noise: MAE 2.791 against 2.779. Not enabled.
- Asymmetric error distribution: excess kurtosis −0.23, not warranted.
- Per-horizon bias correction: worse at all five horizons. **Removed.**
- Regional swing structure: real, but worth +5% on seat-count spread.

## Notes

- Every stage carries pre-registered checks that halt the fit scripts. They
  caught the majority of real bugs in this release, all of which produced
  plausible output rather than an error.
- Reviewed before release; findings fixed in `8be7750`, including a
  preference-flow leak in the historical backtest.
- `R CMD check` clean with zero notes; 263 tests.
