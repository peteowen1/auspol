# Pre-registration: refit `departed_rate` by partial pooling, time-forward

Written 2026-10-03 BEFORE any run under the new switch. Nothing in `R/` or `scripts/`
was edited and no harness was run to write this; every number below was read from
existing files in `output/` with a short Python pass (no R, memory was tight) and is
marked as a reconstruction where it is one. **Status: draft for Pete. Not committed
as a plan until he has read section 1 and the refusal section.**

Triggered by: `docs/reviews/overcalled-independents-walk-2026-10-03.md` and
`docs/reviews/pascoe-vale-base-pred-trace-2026-10-03.md` (Pascoe Vale 2022: Sue Bolton
called 18.4, actual 4.19; the 2018 IND class base of 32.9 was three people, none of
whom stood again).

## 1. Provenance of 0.38: what it is, and what it is not

Plain statement: **0.38 is a hardcoded constant with no committed fitting script. It
was measured once, in-sample, on every election, as a ratio of means of raw class
share, and then used as a slope on a different quantity.** Evidence:

- It is the default `departed_rate = c(IND = 0.38)` at `R/dev_slope.R:288`, added in
  commit `8cfb132` (2026-09-18, "AUSPOL_HONOUR_DEPARTED"). No harness or
  `fit_seats_full.R` call passes `departed_rate` (checked: the six `screened_slopes(`
  call sites at `backtest_candidate_{fed,nsw,qld,sa,vic}.R` and `fit_seats_full.R:1048`
  pass `honour_departed` but not `departed_rate`), so every backtest has used 0.38 for
  every target. `docs/CONSTANTS.md:452` lists it as "ESTIMATED".
- The estimate is in `docs/reviews/departed-leader-retention-2026-09-15.md`
  (commit `bc40733`): "sitting member departs, n = 305, prev 46.7%, now 17.8%,
  retained 0.38", `mean(now) / mean(prev)`. **No script that produced it is in git.**
  `grep -rl "departed-leader-cases\|departure-cases" scripts R docs` finds only the
  walk review. The nearest artefact, `output/departed-leader-cases.csv` (550 rows,
  mtime 2026-09-15 22:20, gitignored under `output/*`), does NOT reproduce the table:
  it holds 28 rows with `prev_won = TRUE` and `same_person = FALSE` (ratio of means
  0.264, prev 40.5 to now 10.7), not 305. Whether the 305 includes major-party
  members, all classes, or an earlier extraction is **unconfirmed**.
- **Not time-forward.** It pools all 24 elections including the ones it is then scored
  on. `CLAUDE.md` calls this a leak ("leave-one-out is NOT time-forward"); the repo's
  own fix for slopes is `fit_pairs_for()` (`R/time_forward.R:14`, default on via
  `AUSPOL_TIME_FORWARD_FITS=1`), which `departed_rate` never went through. Same family
  as the `SHIP_*` constants fixed 2026-09-29 (`AUSPOL_SHIP_TIME_FORWARD`).
- **Wrong estimand for how it is used.** 0.38 is retention of the class's raw share
  (46.7 to 17.8). `screened_slopes()` uses it as the slope on the GAP above the
  statewide level, `sb + slope * (x - sa)` (`R/dev_slope.R:45-52`). If the statewide IND
  level is about 6 points (reconstruction, not computed), gap retention is
  (17.8 - 6) / (46.7 - 6) = 0.29, not 0.38. The realised gap slope on the rows where
  the branch applies is of that order (section 2).
- **Population mismatch.** The 0.38 is for a departing SITTING MEMBER; the branch fires
  for any class leader who did not return (`prior_leader_returns == FALSE`) with no
  permitted successor, including non-winners such as Pascoe Vale's Yildiz (23.5%, lost).
  The 2026-09-15 table itself gives 0.57 for non-winner departures; the saved file gives
  0.287 (n = 96) for IND non-winner departures. Three different numbers for the group
  the branch mostly hits.
- A second, unrelated 0.38 exists: `fit_minor_defector_conserve()`
  (`R/candidate_returns.R:1277`, median 0.38, n = 26). Do not conflate them.

## 2. What the data say about who the rate touches (the sizing)

Rows reconstructed from `output/xgb-primary-v6-features.csv` (IND rows) joined to
`output/departure-cases.csv` (`prior_leader_returns`) on `pair, seat, party`. Error is
`base_pred - actual_share`, the stage-1 final primary share (after row renormalisation
and salience blend), positive means overcall.

Table 1 - IND rows where the prior leader did not return and an IND stood this time.
Mean error is in percentage points, positive is overcall, closer to 0 is better. The
realised slope uses `level_pred` as the statewide level now (a proxy; the true level is
not in the file), so read it as approximate.

| subset | n | mean error | per-row sd | SE of mean | median realised slope |
|---|---|---|---|---|---|
| all (the caller's 56-59 rows) | 59 | +2.02 | 10.9 | 1.4 | 0.22 |
| `permit == 0` (screen refuses a successor) | 20 | +4.66 | 8.42 | 1.88 | 0.20 (mean 0.243, sd 0.338) |
| `permit == 1` (screen permits a successor) | 39 | not computed | | | |

**Finding that changes the scope: the departed rate only reaches rows with no
permitted successor, which is 20 of the 59 rows, in 10 elections (1 to 4 rows each).**
`screened_slopes()` returns `departed_rate` only when `honour_departed & !plr &
!permitted` (`R/dev_slope.R:347-351`); a permitted successor gets 1.0 or the "same"
slope. Geelong 2022, Morwell 2022, Mildura 2014, Kavel 2026 and Finniss 2022 are all
`permit == 1` in the features file, so a change to `departed_rate` cannot move them.
Pascoe Vale 2022 (`permit == 0`, gap 26.8) is in the 20. Mean gap on the 20 is 25.4
points (sd 14.6); three rows have gap above 45 (45.3, 59.4, 62.9) and carry most of the
leverage. Caveat: the features file `permit` column may predate the 2026-09-20
`permit %in% TRUE` fix, so which rows are really in the departed branch is
**unconfirmed**; the harness must print the list (section 8, step 0).

Table 2 - what the registered change is expected to do, as an illustrative sizing
(this reads outcomes only to size the effect; it does not choose the candidate). Slope
cut from 0.38 to the value shown, applied to the 20 rows, base_pred shifted by
`(new - 0.38) * gap * 1.1` (1.1 stands in for the row-renormalisation scale). The
metric is per-row squared final-share error, new minus old, so negative is better.

| illustrative rate | RMSE old to new (pts) | mean change in squared error | per-row sd of change | SE (n = 20) | t | MDE at 80% power |
|---|---|---|---|---|---|---|
| 0.30 | 9.44 to 7.97 | -25.5 | 51.3 | 11.5 | -2.23 | 32.1 |
| 0.26 | 9.44 to 7.46 | -33.4 | 71.7 | 16.0 | -2.08 | 44.9 |
| 0.20 | 9.44 to 7.08 | -39.0 | 96.4 | 21.6 | -1.81 | 60.4 |

**The primary metric is borderline powered**: the expected effect is about 0.6 to 0.9
of its own MDE, i.e. roughly 50% power at n = 20. Per `PRE-REGISTRATION-RULES.md`, a
primary whose MDE exceeds the effect "can only ever refuse"; this one can refuse
a real fix about half the time. The decision rule below is written for that: it has an
explicit INCONCLUSIVE outcome that does not close the question, and the exact n comes
from the harness log, not from this reconstruction (named blank in section 8).

## 3. The registered change

One new function and one switch. No edits are made by this document.

- `fit_departed_rate(target_election, corpus, pairs)` in `R/split_slope.R`, modelled on
  `fit_major_departed_slope()` (`R/split_slope.R:719`): leave-nothing-later-in, i.e.
  `pairs <- fit_pairs_for(target_election, pairs)` (strictly earlier elections only).
- Fit rows: (seat, IND) cells in earlier pairs that fell in the departed branch under the
  harness's own screen, i.e. `prior_leader_returns == FALSE`, `permit %in% TRUE` is
  FALSE, IND stood this time. Pairs with no salience screen contribute no rows (the
  harness takes `conditional_slopes()` there and the branch does not exist). Response
  `yy = actual_now - level_now` (actual statewide class level at that election, known
  for any earlier election), regressor `dev = prev - level_prev`, slope through the
  origin per election, exactly as `fit_major_departed_slope()` does.
- Partial pooling, no `min_n` cliff:
  1. Per election g: slope `b_g` and a standard error `se_g` (the larger of the
     within-election OLS and a leave-one-seat-out jackknife, so a 1-row election has a
     huge `se_g` and gets almost no weight; the same "larger of two variances" guard as
     `.shrunk_slope()` at `R/split_slope.R:695`).
  2. Between-election variance `tau^2` by DerSimonian-Laird, floored at a small positive
     value (`tau^2 >= 0.01^2`) so weights are never exactly equal-by-construction.
  3. Pooled mean `mu = sum(w_g b_g) / sum(w_g)`, `w_g = 1 / (tau^2 + se_g^2)`.
  4. Per-election shrunk value `b_g* = mu + tau^2 / (tau^2 + se_g^2) * (b_g - mu)`.
     This is the partial-pooling form the repo asks for; `b_g*` is reported, `mu` is
     what the target election uses.
  5. Fewer than 3 earlier elections with a departed-branch row: return the fallback
     (below), not an estimate. 3 is the repo's existing floor (`.shrunk_slope`).
  6. Result clipped to [0, 1].
- Fallback when under-supported, and the shrinkage target for thin classes: the
  time-forward `new[["IND"]]` of that same run (`AUSPOL_SHIP_TIME_FORWARD=1`), i.e. the
  rate the departed branch used before 2026-09-18. It is NOT 0.38, which is itself
  fitted on all elections and would reintroduce the leak.
- Switch `AUSPOL_DEPARTED_RATE`: `"0"` (default, off) keeps `c(IND = 0.38)`; arms below
  set `"fit"`, `"fit_juris"`, `"new"`, `"fit_all"`.
- Every run prints one line per target: `DR0 <target> IND rate <value> (n rows, G
  elections, tau, mu) [arm]`, and the count of rows that took the departed branch. A
  run that prints no `DR0` line did not apply the arm (the "experiment that never ran"
  failure in `CLAUDE.md`).

## 4. Candidates, named before any run

Table 3 - the candidate list. Control is the shipped behaviour. Nothing is added after
seeing a result.

| arm | `AUSPOL_DEPARTED_RATE` | IND rate used | role |
|---|---|---|---|
| A | `0` | 0.38 constant | control (shipped) |
| B | `fit` | `mu` from partial pooling across earlier elections, all jurisdictions | **the one registered primary candidate** |
| C | `fit_juris` | B, then the target jurisdiction's own earlier elections shrunk toward `mu` with weight `tau_j^2 / (tau_j^2 + se_j^2)`, `tau_j^2` the between-jurisdiction variance | replaces B only if it beats B on the primary |
| D | `new` | time-forward `new[["IND"]]` (departure treated as an ordinary new candidate) | ex-ante alternative; tests whether a departed-specific rate is needed at all |
| E | `fit_all` | B for IND, plus GRN, ONP, OTH_RIGHT each shrunk toward its own `new` rate by the same formula | evidence test for other classes (section 5) |

## 5. Do OTH_RIGHT, GRN or ONP deserve a departed rate?

Only if evidence exists, and today it does not. Saved `output/departed-leader-cases.csv`
(550 rows, all elections, in-sample, ratio of means of raw share, so the same estimand
caveat as section 1) shows departures of the class leader for these classes retaining:
GRN 0.842 (n = 212), ONP 0.466 (n = 58), OTH_RIGHT 0.371 (n = 19), OTH 0.105 (n = 14),
against the existing generic `new` rates GRN 0.880, ONP 0.545, OTH_RIGHT 0.325. GRN and
ONP are within noise of what `new` already gives; OTH_RIGHT has n = 19 and sits near its
`new`. Winner-departs are only 5, 1 and 4 rows for GRN, ONP, OTH_RIGHT. So no
class-specific departed rate is justified, and `screened_slopes()` already falls back to
`new[[cls]]` for them. Arm E exists so that claim is measured rather than asserted:
because each class shrinks toward its own `new` rate, a class with no signal costs
nothing, and one with signal is picked up. A non-IND class is adopted only if arm E's
departed-branch rows for that class show the same paired improvement criterion as
section 6 on that class's own rows, with at least 3 earlier elections feeding the fit.
Otherwise it stays at `new`.

## 6. Metrics and decision rule

**Scope (per `PRE-REGISTRATION-RULES.md`): this is a targeted change, so the primary
metric is on the rows it touches; election-wide is a do-no-harm guard.**

Primary (arm B vs A, then C vs B), on the rows the harness logs as having taken the
departed branch (n from the `DR0` log, reconstruction says about 20, section 2):

- P1: paired per-row change in squared final-share error (new minus old), mean and
  paired standard error, SE CLUSTERED ON SEAT-ELECTION (one row per seat-election here,
  so cluster = row, but computed as a cluster SE so a seat appearing twice cannot be
  double counted). Final share means the harness's primary share after renormalisation
  and salience blend (the `pooled-sharedetail` `pred_share`), not the raw slope: the
  trace shows renormalisation alone adds about 2 points to Pascoe Vale IND.
- P2: RMSE and mean signed error (points) on the same rows, old and new, reported with
  n. Signed error is the direction check: the arm must reduce the overcall, not flip it.

Guard (all 22 pairs, 2,050 seat-elections, `scripts/pool_backtests.R`), metric order
fixed by the repo: pooled seat log loss (probabilities clamped at `eps = 1e-6` before the
log), then Brier, then reliability by band at 0.9, 0.95, 0.99, 0.999 with COUNTS
(`scripts/compare_arms.R`). Calibration slope reported, never decisive.
SE for the guard: per-pair paired log-loss difference, clustered on pair (G = 22).
The guard's per-pair sd is a named blank (section 8): it cannot be read from existing
files without running the harnesses. The guard cannot see the gain, only gross harm:
about 20 of 2,050 seat-elections move, a factor of about 100 (`n/k`), which is why it is
not the primary.

Decision rule, in order:

1. **Adopt B** if ALL hold: (a) P1 mean change is negative with t <= -1.28 (one-sided
   10%, chosen because n is about 20 and a stricter bar would refuse a fix at roughly
   50% power); (b) P2 signed error moves toward zero and does not cross to an
   undercall larger than +1 SE of the arm-A signed error (about 1.9 points on the
   reconstruction); (c) guard: pooled log loss change <= +0.5 SE of the paired
   per-pair difference; (d) Brier point estimate not worse than +1 SE; (e) no refusal
   condition below fires; (f) the dry-run checks in section 7 pass.
2. **Replace B by C** only if C beats B on P1 by at least 1 SE of the paired B-C
   difference and also passes (b) to (f).
3. **INCONCLUSIVE** if P1's |t| < 1.0 and the guard and refusals are clean: ship
   nothing, keep 0.38, record plainly in `docs/CONSTANTS.md` that it is an unfitted,
   in-sample constant, and queue the question for Pete. This is not a refusal of the
   idea. The power analysis above predicts it about half the time.
4. **Refuse** if P1 t >= +1.0 (the arm is worse on its own targets) or any guard or
   refusal condition fires. Per the 2026-09-19 rule `clause-refusals-go-to-pete`: if a
   clause refuses a headline-positive result, show Pete the split and let him decide;
   record any override visibly.
5. Arms D and E are reported. D beating B on P1 by 1 SE or more means the departed
   branch is unnecessary and the finding is to route departed leaders to `new`
   (a separate registration, not an automatic swap). E's non-IND classes follow
   section 5.

## 7. Dry-run of the criteria on known cases, BEFORE committing

Per `PRE-REGISTRATION-RULES.md`, name cases whose answer is known and state what the
criteria must say. Not yet run; they are the first thing to run (section 8, step 1).

| case | known fact | what the criteria must say |
|---|---|---|
| Pascoe Vale 2022 IND | `permit = 0`, gap 26.8, base_pred 19.01 (stage-1 final), actual 4.19 | Final IND share must FALL under B and C by at least 2.0 points (0.12 x 26.8 x 1.12 is 3.6 if the rate drops by 0.12; the 2.0 floor is generous). If it does not move, the arm did not reach the row |
| Kavel 2026 IND (Schultz) | features `permit = 1` (so out of branch), gap 43.1, base 29.7, actual 21.4, realised slope about 0.36 | If the harness log shows it NOT in the departed branch: final share byte-identical to A (to 1e-9). If it IS in the branch (the screen is silent for sa2026, per `SEAT-REGISTRY.md`): error must not rise by more than X (below) |
| Tamworth 2018/2019 (nsw2019) | `permit = 0`, gap 30.7, base 19.46, actual 16.38, realised slope about 0.37, so a successor genuinely inherited | Currently overcalled by 3.1, so a lower rate should not worsen it until the rate is below about 0.22; absolute error must not rise by more than X |
| Finniss sa2022 IND | `permit = 1`, gap 8.2, base 21.4, actual 19.6 | out of branch if the log agrees: byte-identical |
| a negative control: any ALP/LNP/GRN/ONP row | the departed IND rate cannot reach them | Final share changes only through row renormalisation in seats whose IND changed; arm E excepted |
| a deliberately broken input | set `AUSPOL_DEPARTED_RATE=fit` with `AUSPOL_HONOUR_DEPARTED=0` | Must be a no-op (branch off), byte-identical to A. If it moves anything, the switch is wired wrong |

**X, in standard errors: a successor-inherits row may worsen by at most 0.25 of the
per-row sd of final error, i.e. 2.1 points (sd 8.42, n = 20), which is 1.1 SE of the
group mean error (1.88).** It is written in SE so it cannot be silently rescaled.
Tamworth and Kavel are the two named successor-inherits cases; breaching X on either
is a refusal condition, not a deduction.

## 8. Commands (listed, NOT executed)

All with the memory rules in `CLAUDE.md`: one arm per launch, `AUSPOL_N_SIMS=5000` for
exploration and 20000 only for the deciding run, never edit a script while a run of it
is in flight, never run the rebuild and `R CMD check` together. Use
`powershell.exe -Command 'Rscript "scripts/<file>.R"'` for anything touching parquet.

Step 0 - settle the unconfirmed facts first (cheap, no model change): add the `DR0`
print and a per-row `DR1 branch rows` dump (seat, class, gap, rate used) under the
existing harness `BF0` area, run vic2022 only at stage 1 with
`AUSPOL_XGB_PRIMARY=0` and everything else left to `scripts/harness_defaults.R`
(`powershell.exe -Command 'Rscript "scripts/backtest_candidate_vic.R"'`); do not
hand-set the other flags, so the run measures what ships.
Read: (i) is `permit` NA/FALSE for Kavel, Finniss, Tamworth, Pascoe Vale; (ii) the exact
departed-branch n per pair (fills the blank in section 6).

Step 1 - dry-run section 7 before committing this plan: base_pred only, vic2022 and
sa2026 and nsw2019, arm A vs a hand-set `AUSPOL_DEPARTED_RATE=new`.

Step 2 - base_pred layer (`AUSPOL_XGB_PRIMARY=0`), one arm per launch, all six
harnesses (WA is the negative control, section 9), then
`scripts/pool_backtests.R`:

```
AUSPOL_DEPARTED_RATE=0   AUSPOL_XGB_PRIMARY=0  # arm A, each harness
AUSPOL_DEPARTED_RATE=fit AUSPOL_XGB_PRIMARY=0  # arm B
AUSPOL_DEPARTED_RATE=fit_juris AUSPOL_XGB_PRIMARY=0
AUSPOL_DEPARTED_RATE=new AUSPOL_XGB_PRIMARY=0
AUSPOL_DEPARTED_RATE=fit_all AUSPOL_XGB_PRIMARY=0
```
Federal a pair at a time with `AUSPOL_FED_PAIRS` (it exceeds the 10 minute cap
otherwise).

Step 3 - xgb layer. `CLAUDE.md`: a primary-vote fix must be tested in `base_pred` AND
the xgb layer. Two different mechanisms, do not conflate:
- Backtests under `AUSPOL_XGB_PRIMARY=1` read the frozen
  `output/xgb-primary-v6-oof-predictions.csv`, which does not see a `base_pred` change
  until it is regenerated. Run the 4-step non-circular retrain
  (`docs/reviews/xgb-primary-circularity-2026-09-13.md`) for the winning arm: all six
  harnesses at `AUSPOL_XGB_PRIMARY=0`, pool, refit v6 once, rerun all six at published
  defaults. The retrain is for the arm that passed step 2 only, not every arm.
- The published forecast (`fit_seats_full.R`, `xgb_primary_predict_live()`,
  `AUSPOL_XGB_PRIMARY_LIVE=1`) takes `base_margin` from the run's own fresh `shares`, so
  it reflects the change on its next run. Walk the live forecast with and without the
  switch and diff Pascoe-Vale-shaped departed independents in vic2026 (memory
  `walk-the-live-forecast`); the as-at models were trained on old `base_pred`, so check
  the shift is not partly undone by `dev_prev` and `base_pred` trees (Table 4 of the
  walk review shows both push IND down about 0.7 to 0.9 already).
- Repeat P1, P2 and the guard on the xgb-layer final shares. The change is judged
  passed only if both layers pass; one layer improving while the other worsens is a
  finding to show Pete, not a pass.

Step 4 - `Rscript scripts/check_like_ci.R` before any push (`powershell.exe -Command
'Rscript "scripts/check_like_ci.R"'`), never `--tests-only` before a push to a branch
with an open PR. New exported `fit_departed_rate` needs `devtools::document()` and a
`_pkgdown.yml` entry in the same commit.

## 9. Harness parity (all six plus the published script)

`grep` result at the time of writing: `screened_slopes(` is called in
`backtest_candidate_fed.R:952`, `_nsw.R:687`, `_qld.R:601`, `_sa.R:645`, `_vic.R:606` and
`fit_seats_full.R:1048`. None passes `departed_rate`; the function default is read in
all of them. Plan: in each, next to the `.MAJDEP` block (`_vic.R:574-587` is the
pattern), build `.DEPRATE <- NULL` and, when `AUSPOL_DEPARTED_RATE != "0"`, set it from
`fit_departed_rate(.eb)` wrapped in `tryCatch` that prints a `BF0d!` failure line and
leaves the default; pass `departed_rate = if (is.null(.DEPRATE)) formals(screened_
slopes)$departed_rate else .DEPRATE` at every call site. **`backtest_candidate_wa.R`
has no `screened_slopes()` wiring** (it runs conditional-only; header lines
359-367), so the departed branch does not exist there. The switch cannot reach WA and WA
must come back byte-identical; it is run as a negative control, and the reason is
recorded in the commit, per the "say why in the commit" rule. Also in the same commit:
add `AUSPOL_DEPARTED_RATE = "0"` to `scripts/published_flags.R` (default off until the
decision rule adopts it), update `docs/CONSTANTS.md:452`, and regenerate
`docs/MODEL-REGISTRY.md` with `scripts/build_model_registry.R`. A switch missing from
`CAL_TAG` is not a filename-collision bug (`.arm_fingerprint` hashes every set
`AUSPOL_*` variable). Check by function-name grep, not the registry table, that
`fit_seats_full.R` actually reaches the new code (the registry's grep is substring based).

## 10. REFUSAL section: what disqualifies a winner, named in advance

A passing P1 is refused if any of these fires:

1. **Successor-inherits rows worsen beyond X** (section 7): Tamworth, Kavel 2026 (if in
   branch), or any row where the realised gap slope is at or above 0.35 and the final
   absolute error rises by more than 2.1 points. Independents under-called where a
   successor genuinely inherits is the expected directional side effect.
2. **Per-class signed bias**: renormalisation sends the freed IND share pro rata to the
   other classes in the same seat. Mean signed error for ALP, LNP, GRN, ONP, OTH_RIGHT,
   OTH in the changed seats must not move away from zero by more than 1 SE of that
   class's arm-A mean. ONP and OTH_RIGHT are overcalled in Kavel 2026 (+2.75, +5.88)
   and a pro-rata rise would worsen them: this is the specific case to read.
3. **Floor events**: the count of seat-elections where the winner received probability
   at or below the `1e-6` clamp must not rise (a seat at exactly zero contributes
   -log(1e-6) alone, which is how vic2014 moved 0.4662 to 0.5608 with no model change).
   The count of independent winners whose probability falls below 0.05 in
   departed-branch seats is reported by seat.
4. **Direction-of-change count (the One Nation lesson)**: report in how many
   departed-branch seats P(IND wins) fell and in how many it rose. A change that moves
   it the same way in almost every row (the One Nation rule refused on 71 up, 1 down)
   is refused unless the realised outcomes in those seats justify the direction;
   realised IND wins in the branch rows are counted and shown beside it.
5. **Leakage check**: the `DR0` rate for each target must be reproducible from earlier
   elections only. Print the elections used. Any later election in that list
   disqualifies the run (leave-one-out is not time-forward).
6. **Leverage**: three of the 20 rows have gap above 45. If dropping those three
   reverses the sign of P1, the result is the leverage of three seats, not a rate, and
   is refused as evidence (reported, shown to Pete).
7. **A run that did not apply**: no `DR0` line, or arm B byte-identical to A on a
   target where the log shows a departed-branch row. Reported as "did not run", never as
   "no effect".

**What the criteria cannot see**: they cannot see whether the vote that left was
carried by the person rather than the class (the walk review's actual diagnosis;
"carry the vote by person" is untested, section 5 of that review). They cannot see rows
the screen permits (39 of 59), where the large Geelong, Morwell and Mildura overcalls
sit, and where this change does nothing. Refitting 0.38 is therefore not a fix for the
overcalled-independents list as a whole, only for its no-permitted-successor part.
They also cannot see anything about the 2026 Victorian seats themselves: no
vic2026 outcome exists.

## 11. What I could not confirm (carry into the run)

- The script and exact population behind the n = 305 / 0.38 table; the saved CSV
  disagrees (28 sitting-member departures). Searched: git history for
  `departed-leader-cases`, `departure-cases`, `non-winner departs`; `scripts/`, `R/`,
  `docs/`. Only the `bc40733` doc and the gitignored CSVs exist.
- The statewide IND level used to turn 0.38 into a gap retention (0.29 used 6 points,
  an assumption).
- Which rows are in the departed branch in the real harness (features-file `permit` may
  be stale); the exact n per election; the per-pair sd for the guard.
- Whether `salience_permit_for()` returns a usable screen for the earlier elections a
  time-forward fit would need. If few earlier pairs have a screen, G < 3 for most
  targets and B degrades to the fallback, which makes B equal D by construction. Print
  G per target and report how many targets actually received a fitted rate.
- Pascoe Vale's `p_hat` for the blend and the `candidate_returns()` object for vic2018
  to vic2022 (open item in the trace review).
- The caller's "56 rows, median 0.261, mean 0.199, mean overcall 2.65 (SE 1.46)": my
  reconstruction gets 56 to 59 rows with mean overcall 2.0 to 2.2 (SE 1.4 to 1.5); the
  gap is selection and which file's final share was used, unreconciled.
