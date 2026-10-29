# Pre-registration: AEF-7 screen of the time-forward departed-rate refit (`AUSPOL_DEPARTED_RATE`)

Written in the 25 Oct night session (calendar date 26 Oct), before any run of this switch. Pete chose (25 Oct):
pre-register and screen all four built-but-off experiment branches. Branch `departed-rate-refit`, commits `369b271`
(2026-10-03, the switch) and `256f328` (2026-10-04, review fixes). Rules: `docs/PRE-REGISTRATION-RULES.md` (standard
decision rule of 2026-10-18), `CLAUDE.md` leakage and shrinkage rules. Nothing in `R/` or `scripts/` is edited by this
plan and the branch is not merged by it.

**This file does not replace `docs/plans/prereg-departed-rate-refit-2026-10-03.md`** (on `origin/dev`, identical to
the branch's copy), which registered the estimand, the arms A to E, the dry-run cases and the refusal list, with a
2026-10-04 addendum. That file is left unedited. This one registers the fast SCREEN that comes before its deciding
run, and records what has changed underneath it since 4 Oct.

## NEEDS PETE (not decided here)

1. **The fallback when a target has fewer than 3 informative earlier elections.** The 10-03 prereg (section 3)
   registered the time-forward `new` IND slope as the fallback and said explicitly that it is NOT 0.38, "which is
   itself fitted on all elections and would reintroduce the leak". The 10-04 addendum, written overnight by Claude
   without Pete, changed it to the shipped 0.38, because the code's `fit_conditional_slopes()$new[["IND"]]` returns
   1.0 (no decay) for thin early targets under `AUSPOL_SHIP_TIME_FORWARD=1`. Options:
   - (a) 0.38, as built: a thin target keeps exactly the shipped behaviour, so the arm cannot make it worse, but it
     also keeps the in-sample constant the refit exists to remove;
   - (b) the time-forward `new` slope, as registered: 1.0 for thin targets, judged worse than 0.38 in the addendum
     (reasoned, not measured);
   - (c) some other time-forward value (for example the time-forward rate from `scripts/fit_departed_rate_asat.R`,
     `output/departed-rate-by-target.csv`, 0.17 to 0.34 by target, `docs/reviews/departed-rate-provenance-2026-10-07.md`).
   Context: the SHIPPED successor rates (`AUSPOL_DEPARTED_SUCCESSOR=1`, `output/departed-successor-rates.csv`) also
   fall back to 0.38 for thin early targets (fed2007 rows carry `fallback = TRUE`), so (a) matches what already
   ships there. My recommendation, labelled mine: screen as built (a). The AEF-7 targets are all 2022 or later, so
   the fallback should rarely fire in the screen; the `DR0` lines say how many targets fell back, and if none of
   the seven did, the choice does not touch the screen, only the early elections of the deciding run. The choice must
   be Pete's before any deciding run.
2. **Which rows the rate is fitted on, now that successor rates ship** (new since 10-07, see the next section). The
   fit uses every departed-branch IND row of earlier elections, including the cells that the shipped successor table
   now governs. Under the shipped config the fitted rate is applied only to departed cells the successor table does
   NOT name. Fitting on one population and applying to another is the estimand mismatch the 10-03 prereg found in
   0.38 itself (section 1). Options: fit on all departed rows (as built), or only on cells the successor table does
   not name for that earlier election (needs a code change). Not decided; screened as built.
3. **Which decision rule governs the deciding run.** The 10-03 rule (primary P1 = paired squared share error on the
   departed-branch rows, one-sided t <= -1.28; guard pooled log loss within +0.5 SE) predates the 2026-10-18 standard
   rule (seat log loss on the change's targets, 1 SE; leave-one-election-out; no election worse by 2 SE of its own
   seats). This screen uses the standard rule. Recommendation (mine): report both on the deciding run and, where they
   disagree, show Pete the split (standard clause 9).

## What changed underneath the 10-03 plan

- **`AUSPOL_DEPARTED_SUCCESSOR=1` SHIPPED 2026-10-07** (`docs/plans/prereg-departed-successor-flag-2026-10-07.md`,
  `docs/reviews/departed-successor-flag-result-2026-10-07.md`): a time-forward, held departed-IND rate per seat for
  the successor population (previous leading IND at 10% or more did not stand, another IND did), passed to
  `screened_slopes(successor_rate=)`. In `screened_slopes()` (`R/dev_slope.R:359-371`) a seat the successor table
  names takes its successor rate INSTEAD of `departed_rate`; every other departed seat keeps `departed_rate` (0.38).
  So `AUSPOL_DEPARTED_RATE` can now move only departed-branch IND cells the successor table does not name.
- Cells the successor table names in AEF-7 elections (read from the main checkout's
  `output/departed-successor-rates.csv`, 13 Oct): fed2022 Braddon, Cowper, Farrer, Flinders, Mackellar, Wentworth;
  fed2025 Hume; sa2026 Flinders, Kavel, Mount Gambier, Waite; vic2022 Morwell; wa2025 Nedlands. nsw2023 and qld2024
  have none. **These are negative controls: the arm must leave these seats byte-identical.** `departed_rate` carries
  IND only (other classes take their unchanged `new` rate), and a seat has one IND cell, so nothing else in a named
  seat can move.
- What it still reaches: departed cells outside the successor table, which by the successor build's definition are
  prior IND leaders under 10%, the 39 cells the successor coding left "unknown" (no pre-election text; not named in
  the rates file), and the 4 sitting or former MPs excluded there. Pascoe Vale vic2022 (the 10-03 prereg's first
  dry-run case) is NOT named for vic2022, so it should still be reachable; inferred from the file, not confirmed.
- `docs/reviews/departed-rate-provenance-2026-10-07.md`: the 0.38 rests on 15 cells (SE 0.078), not 305; the
  time-forward rate is lower for every earlier target (0.17 to 0.34). That supports the direction of the refit; the
  refit's own estimand (gap slope through the origin on departed-branch rows) is different again, so its value is
  read from `DR0`, not assumed.

## Merge state and cached files

- **Does NOT merge cleanly onto `origin/dev`**: `git merge-tree` reports conflicts in ten files: `NAMESPACE`,
  `docs/CONSTANTS.md`, `docs/MODEL-REGISTRY.md`, `scripts/published_flags.R`, `scripts/fit_seats_full.R` and all five
  wired harnesses (`backtest_candidate_{fed,nsw,qld,sa,vic}.R`). The harness and live conflicts are the
  `screened_slopes()` call: dev now passes `with_flags = .departed_hold, successor_rate = .SUCC_RATE`, the branch
  adds `departed_rate = ...`; the resolution keeps all three. In `fit_seats_full.R` dev generalised the live target
  (`salience_permit_for(TGT, PREV, REGION, surge_levels = ...)`), so the branch's `departed_rate_for_harness("vic2026",
  ...)` must become `departed_rate_for_harness(TGT, ...)`. `NAMESPACE` and `MODEL-REGISTRY.md` are regenerated
  (`devtools::document()`, `scripts/build_model_registry.R`), not hand-merged; `CONSTANTS.md` is merged by hand
  (both sides edited the `departed_rate` row region). 877 commits behind `origin/dev`; screened merged only. The
  merge is a code change and gets the review gate before any PR.
- **No xgb retrain is needed for the screen.** The rate changes `base_pred`; in the harnesses `AUSPOL_XGB_BASE_DELTA=1`
  (shipped) re-predicts every cell whose base moved with the frozen as-at trees (`base_margin` = the new base), which
  is how the published forecast takes a `base_pred` change too. This supersedes the 10-03 plan's step 3 retrain of
  the old OOF cache (`output/xgb-primary-v6-oof-predictions.csv` is no longer what the harnesses read; they read
  `output/xgb-primary-asat-predictions.csv`). If the arm ships, the next full rebuild trains the trees on the new
  base, and stage 1 must then run with it on (it is a `base_pred` change, not a post-xgb switch).
- `backtest_candidate_wa.R` has no `screened_slopes()` call: wa2025 must come back byte-identical (negative control).

## Arm

| arm | switch | IND rate in the departed branch (cells the successor table does not name) |
|---|---|---|
| A, shipped | `AUSPOL_DEPARTED_RATE=0` | 0.38 |
| B | `AUSPOL_DEPARTED_RATE=fit` | DerSimonian-Laird pooled rate over earlier informative elections (>= 2 rows each), clipped to [0, 1]; fallback per NEEDS PETE item 1, as built 0.38 |

Arm D (`new`) is registered in the 10-03 plan and may be screened as a report-only second arm; it is not decisive.
**Arms `fit_juris` and `fit_all` must NOT be screened**: they are not implemented, `departed_rate_for_harness()`
catches the error, prints `BF0d!` and keeps 0.38, so the run would come back byte-identical and read as "no effect".

## Screen and criterion

Instrument: `scripts/quick_arm.R` from a scratch worktree holding `origin/dev` with this branch merged, AEF-7
default pairs (681 seats), `--sims=1000`, baseline the shipped configuration, common random numbers.

Before reading any number, from the harness logs in the quick_arm scratch directory: one `DR0` line per target with
the rate used, the informative-election count and whether the fallback fired; no `BF0d!` and no `DR1!` line (a
`DR1!` means an earlier pair was dropped from the fit; reported with the count). A target whose `DR0` says "fallback
to control" is scored as byte-identical by construction and counted separately.

- **Primary**: Q3, pooled seat-winner log loss on AEF-7, SE clustered on election, better by more than 1 SE.
- **Targeted**: the seats holding a changed IND cell (|share moved| > 0.05 points), chosen from predictions:
  seat-winner log loss on those seats from the cached `allprobs`, and Q2 squared share error on the changed cells.
  This is the change's own target set (10-03 section 6 scoped it the same way); the 10-03 reconstruction put it at
  about 20 rows in 10 elections before the successor table took some of them, so expect a handful per election.
- **Guards**: G1 Q3 not worse by more than 1 SE; G2 no AEF-7 election worse by more than 1 SE of its own paired
  seat differences (stricter than standard clause 4, set by tonight's brief; a G2-only refusal of an otherwise
  passing arm goes to Pete); G3 leave-one-election-out for a passing arm; G4 the two largest-gain seats removed, the
  gain keeps its sign (10-03 refusal 6, the three high-gap rows, is the same worry).

**Decision rule.** Passes the screen if the primary is better by more than 1 SE, or the primary is within 1 SE and the
targeted seat log loss is better by more than 1 SE (a change to a few seats needs `n/k` times the effect to show
pooled), with G1 to G4 and the unacceptable list holding. Worse by more than 1 SE: STOPPED. Otherwise "not shown at
the screen" (the 10-03 power analysis expected about 50% power even on the targeted rows), stays off, numbers to Pete.
A pass earns the deciding run (`scripts/deciding_run.ps1 -Arm "AUSPOL_DEPARTED_RATE=fit" -Label deprate`, all
elections, 20,000 simulations), and only after NEEDS PETE items 1 to 3 are settled.

### What would make an apparent win unacceptable (named now)

The 10-03 refusal list (section 10, items 1 to 7) applies unchanged. Added for the screen:

- Any successor-named cell above (Kavel, Morwell, Hume, the six fed2022 seats, the sa2026 four) moving. It means the
  rate reached a cell the successor table governs, i.e. the merge resolved the call site wrongly.
- Any change in wa2025, or in nsw2023 or qld2024 if their `DR0` lines say the branch is not active there.
- A `DR0` rate above 0.38 for any AEF-7 target. Every earlier measurement put the departed retention below 0.38
  (0.17 to 0.34 time-forward, 0.20 to 0.24 median gap slope in the 10-03 sizing); a rate above it means the fit is
  reading a different population than registered, and the result is reported, not adopted.
- The gain coming from moved IND cells whose outcomes contradict the direction (lowered, and the realised IND share
  was above the old prediction), standard clause 6, counted and shown.

### What the criterion cannot see

- The 10-03 list (vote carried by the person, permitted rows, vic2026 outcomes), plus: anything in the successor-named
  cells, now governed by a different rate.
- Seats whose winner sits under the 0.5/N floor (5e-4 at 1,000 simulations).

## Dry run on known cases (prose, before any screen)

- **Switch off** (`=0`): byte-identical everywhere; `DR0 ... arm 0: shipped constant` on every target.
- **The 10-03 broken input**: with the departed branch switched off on BOTH sides
  (`quick_arm.R "AUSPOL_DEPARTED_RATE=fit" --base="AUSPOL_HONOUR_DEPARTED=0"` plus `AUSPOL_HONOUR_DEPARTED=0` in the
  arm string, `--pairs=vic2022`), the arm must be byte-identical to its baseline with a `DR0 ... departed branch not
  active` line. Run it before the screen; if anything moves, the wiring is wrong and the screen waits.
- **Kavel sa2026** (successor-named, weak, rate 0.506): byte-identical under B. **Pascoe Vale vic2022** (the 10-03
  first case, not successor-named): if the harness puts its IND cell in the departed branch, its IND share must FALL
  under B whenever the fitted rate is below 0.38; if it is unmoved, either it is not in the branch (say so from the
  log) or the arm did not reach it.
- **wa2025**: byte-identical (no wiring).

## Leakage

`fit_departed_rate()` uses `fit_pairs_for(target)` (strictly earlier elections) and stops under
`AUSPOL_TIME_FORWARD_FITS=0`; every `DR0` line lists the elections used, and any election dated on or after the
target in that list voids the run (10-03 refusal 5).

## Amendments

(none yet; any change is added below this line with the text above left as is)

### Amendment 1 (2026-10-29, before any run): Pete's answers to NEEDS PETE 1-3

1. Fallback: **(a) 0.38, as built.**
2. Fit rows: **only the departed cells the successor table does not name for that earlier election.** Needs a
   code change before the screen; the "screened as built" line in item 2 no longer holds.
3. Decision rule: **the 2026-10-18 standard rule decides; the 10-03 rule is reported beside it**, and any
   disagreement goes to Pete (standard clause 9).
